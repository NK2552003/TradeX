import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/session_trader.dart';
import 'package:tradex/features/ai_assistant/data/repositories/ai_assistant_repository.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/journal/data/repositories/journal_repository.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/models/billing_models.dart';

/// The three things a trader actually wants from a copilot: a conversation, a
/// standing set of observations about their account, and a verdict on one trade.
enum _CopilotView { chat, insights, review }

String _viewLabel(_CopilotView view) => switch (view) {
  _CopilotView.chat => 'Chat',
  _CopilotView.insights => 'Insights',
  _CopilotView.review => 'Trade review',
};

IconData _viewIcon(_CopilotView view) => switch (view) {
  _CopilotView.chat => Icons.forum_outlined,
  _CopilotView.insights => Icons.auto_awesome_outlined,
  _CopilotView.review => Icons.rate_review_outlined,
};

/// AI copilot: a scoped chat grounded in the trader's own data, the standing
/// insight rail, and a per-trade review.
///
/// Every answer, prompt chip and credit count comes from
/// [AiAssistantRepository]; the page never writes copy of its own beyond
/// labels. Usage is metered per plan, so the composer is replaced by a gate the
/// moment the allowance runs out — the limit is read from the live
/// subscription, never from a compile-time flag.
class AiCopilotPage extends StatefulWidget {
  const AiCopilotPage({
    super.key,
    this.repository,
    this.profileRepository,
    this.billingRepository,
    this.journalRepository,
    this.initialScope,
    this.initialPrompt,
    this.onUpgrade,
    this.onOpenSymbol,
  });

  final AiAssistantRepository? repository;
  final ProfileSettingsRepository? profileRepository;
  final BillingSettingsRepository? billingRepository;
  final JournalRepository? journalRepository;

  /// Lets the shell deep-link into a lens ("review my risk") from elsewhere.
  final AiScope? initialScope;

  /// Question to ask on arrival, so "ask the copilot about this" carries the
  /// instrument or trade it came from instead of dropping the reader into an
  /// empty thread.
  final String? initialPrompt;

  final VoidCallback? onUpgrade;
  final ValueChanged<String>? onOpenSymbol;

  @override
  State<AiCopilotPage> createState() => _AiCopilotPageState();
}

class _AiCopilotPageState extends State<AiCopilotPage> {
  late final AiAssistantRepository _ai =
      widget.repository ?? AiAssistantRepositoryImpl();
  late final ProfileSettingsRepository _profiles =
      widget.profileRepository ?? ProfileSettingsRepositoryImpl();
  late final BillingSettingsRepository _billing =
      widget.billingRepository ?? BillingSettingsRepositoryImpl();
  late final JournalRepository _journal =
      widget.journalRepository ?? JournalRepositoryImpl();

  AppTrader? _me;
  AppTier _tier = AppTier.free;
  AiCredits _credits = const AiCredits(used: 0, limit: 0);
  late AiScope _scope = widget.initialScope ?? AiScope.general;
  _CopilotView _view = _CopilotView.chat;

  List<AppAiMessage> _messages = const <AppAiMessage>[];
  List<AppAiPrompt> _prompts = const <AppAiPrompt>[];
  List<String> _attachments = const <String>[];

  List<AppAiInsight> _insights = const <AppAiInsight>[];
  AppAiInsight? _openInsight;
  List<String> _observations = const <String>[];

  List<AppTrade> _trades = const <AppTrade>[];
  AppOutcome? _outcomeFilter;
  AppTrade? _reviewTrade;
  String? _review;

  bool _loading = true;
  bool _switchingScope = false;
  bool _generating = false;
  bool _loadingInsights = false;
  bool _loadingObservations = false;
  bool _reviewing = false;

  /// Bumped whenever a generation is abandoned so a late reply is dropped
  /// instead of appearing after the trader stopped it.
  int _generation = 0;

  /// The allowance is spent — the composer is swapped for an upgrade gate.
  bool get _blocked => _credits.limit > 0 && _credits.exhausted;

  /// Plan that lifts the current ceiling.
  AppTier get _nextTier =>
      _tier == AppTier.free ? AppTier.premium : AppTier.enterprise;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _profiles.getProfile(),
      _billing.getSubscription(),
      _ai.getHistory(_scope),
      _ai.getPrompts(_scope),
      _ai.getInsights(),
      _journal.getTrades(),
    ]);
    if (!mounted) return;
    final AppTier tier = (results[1]! as SubscriptionSummary).tier;
    final AiCredits credits = await _ai.getCredits(tier);
    if (!mounted) return;
    setState(() {
      _me = appTraderFromProfile(results[0]! as UserProfileModel);
      _tier = tier;
      _messages = results[2]! as List<AppAiMessage>;
      _prompts = results[3]! as List<AppAiPrompt>;
      _insights = results[4]! as List<AppAiInsight>;
      _trades = results[5]! as List<AppTrade>;
      _credits = credits;
      _loading = false;
    });
    final String? ask = widget.initialPrompt?.trim();
    if (ask == null || ask.isEmpty) return;
    // Sent rather than parked in the composer: the caller already phrased the
    // question, and the allowance gate inside [_send] still gets the last word.
    await _send(ask);
  }

  /// Each lens keeps its own thread and prompt set, so switching reloads both.
  Future<void> _setScope(AiScope scope) async {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _switchingScope = true;
      _messages = const <AppAiMessage>[];
      _attachments = const <String>[];
    });
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _ai.getHistory(scope),
      _ai.getPrompts(scope),
    ]);
    if (!mounted || _scope != scope) return;
    setState(() {
      _messages = results[0]! as List<AppAiMessage>;
      _prompts = results[1]! as List<AppAiPrompt>;
      _switchingScope = false;
    });
  }

  Future<void> _refreshCredits() async {
    final AiCredits credits = await _ai.getCredits(_tier);
    if (!mounted) return;
    setState(() => _credits = credits);
  }

  Future<void> _send(String prompt) async {
    if (_blocked || _generating) return;
    final List<String> attachments = _attachments;
    final int token = ++_generation;
    setState(() {
      _generating = true;
      _attachments = const <String>[];
      _messages = <AppAiMessage>[
        ..._messages,
        AppAiMessage(
          id: 'local_${DateTime.now().microsecondsSinceEpoch}',
          role: AppAiRole.user,
          body: prompt,
          sentAt: DateTime.now(),
          attachments: attachments,
        ),
        const AppAiMessage(
          id: 'local_pending',
          role: AppAiRole.assistant,
          body: '',
          pending: true,
        ),
      ];
    });
    await _ai.send(_scope, prompt, attachments: attachments);
    if (!mounted) return;
    if (token != _generation) {
      // Stopped while in flight: keep the stored thread in step with the view.
      await _ai.discardLastReply(_scope);
      await _refreshCredits();
      return;
    }
    final List<AppAiMessage> history = await _ai.getHistory(_scope);
    if (!mounted || token != _generation) return;
    setState(() {
      _messages = history;
      _generating = false;
    });
    await _refreshCredits();
  }

  void _stop() {
    _generation++;
    setState(() {
      _generating = false;
      _messages = <AppAiMessage>[
        ..._messages.where((AppAiMessage m) => !m.pending),
        AppAiMessage(
          id: 'sys_${DateTime.now().microsecondsSinceEpoch}',
          role: AppAiRole.system,
          body: 'Generation stopped — the draft answer was discarded.',
        ),
      ];
    });
  }

  Future<void> _clear() async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Start a new ${aiScopeLabel(_scope).toLowerCase()} chat?',
      description:
          'This clears the thread for this lens. Credits already spent are '
          'not refunded.',
      confirmLabel: 'Clear thread',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    await _ai.clearHistory(_scope);
    if (!mounted) return;
    setState(() {
      _messages = const <AppAiMessage>[];
      _generating = false;
      _generation++;
    });
  }

  Future<void> _copy(AppAiMessage message) => _copyText(message.body);

  Future<void> _copyText(String body) async {
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Copied',
      message: 'The answer is on your clipboard.',
      intent: UiIntent.success,
    );
  }

  /// Regenerating re-asks the last question rather than editing history, so the
  /// trader can compare both answers side by side.
  Future<void> _retry() async {
    final Iterable<AppAiMessage> asks = _messages.where(
      (AppAiMessage m) => m.role == AppAiRole.user,
    );
    if (asks.isEmpty) return;
    await _send(asks.last.body);
  }

  /// Attaches one of the trader's own trades as context for the next question.
  Future<void> _attach() async {
    final AppTrade? trade = await UiDialog.show<AppTrade>(
      context,
      child: _TradePicker(trades: _trades),
    );
    if (trade == null || !mounted) return;
    final String label =
        '${trade.ticker} · ${AppTokens.shortDate(trade.openedAt)} · '
        '${AppTokens.signedMoney(trade.pnl)}';
    if (_attachments.contains(label)) return;
    setState(() => _attachments = <String>[..._attachments, label]);
  }

  void _removeAttachment(String label) => setState(
    () => _attachments = _attachments
        .where((String a) => a != label)
        .toList(growable: false),
  );

  Future<void> _reloadInsights() async {
    setState(() => _loadingInsights = true);
    final List<AppAiInsight> rows = await _ai.getInsights();
    if (!mounted) return;
    setState(() {
      _insights = rows;
      _loadingInsights = false;
      if (_openInsight != null &&
          !rows.any((AppAiInsight i) => i.id == _openInsight!.id)) {
        _openInsight = null;
      }
    });
  }

  /// Observations are computed from the trader's executions, so they load per
  /// insight rather than up front.
  Future<void> _openInsightDetail(AppAiInsight insight) async {
    setState(() {
      _openInsight = insight;
      _observations = const <String>[];
      _loadingObservations = true;
    });
    final List<String> rows = await _ai.getObservations(insight);
    if (!mounted || _openInsight?.id != insight.id) return;
    setState(() {
      _observations = rows;
      _loadingObservations = false;
    });
  }

  void _dismissInsight(AppAiInsight insight) {
    setState(() {
      _insights = _insights
          .where((AppAiInsight i) => i.id != insight.id)
          .toList(growable: false);
      if (_openInsight?.id == insight.id) _openInsight = null;
    });
    UiToast.show(
      context,
      title: 'Insight dismissed',
      message: 'Regenerate the rail to bring it back.',
      intent: UiIntent.neutral,
    );
  }

  /// Hands an insight to the chat so the follow-up keeps the same context.
  Future<void> _askAbout(AppAiInsight insight) async {
    setState(() => _view = _CopilotView.chat);
    await _send(
      'Expand on "${insight.title}"'
      '${insight.tickers.isEmpty ? '' : ' for ${insight.tickers.join(', ')}'}'
      ' — what should I change this week?',
    );
  }

  Future<void> _setOutcomeFilter(AppOutcome? outcome) async {
    setState(() => _outcomeFilter = outcome);
    final List<AppTrade> rows = await _journal.getTrades(
      JournalQuery(outcome: outcome),
    );
    if (!mounted || _outcomeFilter != outcome) return;
    setState(() {
      _trades = rows;
      if (_reviewTrade != null &&
          !rows.any((AppTrade t) => t.id == _reviewTrade!.id)) {
        _reviewTrade = null;
        _review = null;
      }
    });
  }

  Future<void> _openReview(AppTrade trade) async {
    setState(() {
      _reviewTrade = trade;
      _review = null;
      _reviewing = true;
    });
    final String verdict = await _ai.reviewTrade(trade);
    if (!mounted || _reviewTrade?.id != trade.id) return;
    setState(() {
      _review = verdict;
      _reviewing = false;
    });
    await _refreshCredits();
  }

  /// Continues a trade review in the chat, pre-loaded with that execution.
  Future<void> _discussTrade(AppTrade trade) async {
    setState(() {
      _view = _CopilotView.chat;
      _attachments = <String>[
        '${trade.ticker} · ${AppTokens.shortDate(trade.openedAt)} · '
            '${AppTokens.signedMoney(trade.pnl)}',
      ];
    });
    await _send(
      'Walk me through the ${AppTokens.sideLabel(trade.side).toLowerCase()} in '
      '${trade.ticker}: what would you have done differently?',
    );
  }

  String get _subtitle {
    if (_loading) return 'Waking your copilot…';
    if (_blocked) {
      return '${AppTokens.tierLabel(_tier)} allowance used · '
          '${_credits.used} of ${_credits.limit} credits';
    }
    return '${aiScopeLabel(_scope)} · ${_credits.remaining} of '
        '${_credits.limit} credits left · ${AppTokens.tierLabel(_tier)}';
  }

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'AI Assistant',
    subtitle: _subtitle,
    scrollable: false,
    actions: <Widget>[
      if (context.uiRes.isMobile && _view == _CopilotView.chat)
        UiIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Context & credits',
          onPressed: _loading ? null : _openContextSheet,
        ),
      if (_view == _CopilotView.chat)
        UiButton(
          label: 'New chat',
          leadingIcon: Icons.add_comment_outlined,
          variant: UiVariant.outline,
          hideLabelOnMobile: true,
          expandOnMobile: false,
          onPressed: _loading || _messages.isEmpty ? null : _clear,
        ),
      if (_view == _CopilotView.insights)
        UiButton(
          label: 'Regenerate',
          leadingIcon: Icons.refresh_rounded,
          variant: UiVariant.outline,
          hideLabelOnMobile: true,
          expandOnMobile: false,
          loading: _loadingInsights,
          onPressed: _loading ? null : _reloadInsights,
        ),
    ],
    child: Expanded(
      child: _loading
          ? UiCard(child: UiSkeleton(height: context.sz(320)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiToggleGroup<_CopilotView>(
                  options: <UiToggleOption<_CopilotView>>[
                    for (final _CopilotView view in _CopilotView.values)
                      UiToggleOption<_CopilotView>(
                        value: view,
                        label: _viewLabel(view),
                        icon: _viewIcon(view),
                      ),
                  ],
                  value: _view,
                  expand: context.uiRes.isMobile,
                  onChanged: (_CopilotView view) =>
                      setState(() => _view = view),
                ),
                UiGap.v(context.ui.spacing.md),
                Expanded(
                  child: switch (_view) {
                    _CopilotView.chat => _chatView(),
                    _CopilotView.insights => _insightsView(),
                    _CopilotView.review => _reviewView(),
                  },
                ),
              ],
            ),
    ),
  );

  /// The thread scrolls inside [AppAiChatBlock], so the chat needs a bounded
  /// height — hence [UiSplitPane] directly rather than the scrolling workspace
  /// pane. On phones only the chat renders and the rail moves into a sheet.
  Widget _chatView() => UiSplitPane(
    initialRatio: 0.66,
    minRatio: 0.45,
    maxRatio: 0.78,
    primary: Padding(
      padding: EdgeInsets.only(right: context.sp(context.ui.spacing.sm)),
      child: _chatPane(),
    ),
    detail: SingleChildScrollView(child: _contextRail()),
  );

  Widget _chatPane() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (context.uiRes.isMobile) ...<Widget>[
        _scopeSelector(vertical: false),
        UiGap.v(context.ui.spacing.sm),
      ],
      if (_attachments.isNotEmpty) ...<Widget>[
        _attachmentChips(),
        UiGap.v(context.ui.spacing.sm),
      ],
      Expanded(
        child: _blocked
            ? SingleChildScrollView(child: _gateCard())
            : _switchingScope
            ? UiCard(child: UiSkeleton(height: context.sz(240)))
            : UiCard(
                child: AppAiChatBlock(
                  messages: _messages,
                  prompts: _prompts,
                  generating: _generating,
                  onSend: _send,
                  onStop: _stop,
                  onAttach: _trades.isEmpty ? null : _attach,
                  onCopy: _copy,
                  onRetry: (AppAiMessage _) => _retry(),
                  emptyTitle: 'Ask about ${aiScopeLabel(_scope).toLowerCase()}',
                  emptyMessage: aiScopeBlurb(_scope),
                ),
              ),
      ),
    ],
  );

  Widget _attachmentChips() => Wrap(
    spacing: context.sp(context.ui.spacing.xs),
    runSpacing: context.sp(context.ui.spacing.xs),
    children: <Widget>[
      for (final String label in _attachments)
        UiBadge(
          label: label,
          icon: Icons.attach_file_rounded,
          intent: UiIntent.primary,
          onRemove: () => _removeAttachment(label),
        ),
    ],
  );

  Widget _scopeSelector({
    required bool vertical,
    bool dismissOnChange = false,
  }) => UiToggleGroup<AiScope>(
    options: <UiToggleOption<AiScope>>[
      for (final AiScope scope in AiScope.values)
        UiToggleOption<AiScope>(
          value: scope,
          label: aiScopeLabel(scope),
          icon: aiScopeIcon(scope),
          tooltip: aiScopeBlurb(scope),
        ),
    ],
    value: _scope,
    orientation: vertical ? UiOrientation.vertical : UiOrientation.horizontal,
    variant: vertical
        ? UiToggleGroupVariant.pill
        : UiToggleGroupVariant.segmented,
    expand: vertical,
    onChanged: (AiScope scope) {
      // Picking a lens from the mobile sheet closes it, so the trader lands
      // straight back on the thread they just switched to.
      if (dismissOnChange) Navigator.of(context).maybePop();
      _setScope(scope);
    },
  );

  /// Desktop rail: what the copilot is looking at, what it costs, and the
  /// disclaimer that has to travel with every generated answer.
  Widget _contextRail({bool inSheet = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      AppFadeIn(
        child: UiCard(
          title: 'Lens',
          subtitle: aiScopeBlurb(_scope),
          child: _scopeSelector(vertical: true, dismissOnChange: inSheet),
        ),
      ),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(delay: AppMotion.step, child: _creditsCard()),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(delay: AppMotion.step * 2, child: _sourcesCard()),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(delay: AppMotion.step * 3, child: _disclaimer()),
    ],
  );

  Future<void> _openContextSheet() => UiDialog.show<void>(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Copilot context', style: context.uiText.heading),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.lg),
        Flexible(
          child: SingleChildScrollView(child: _contextRail(inSheet: true)),
        ),
      ],
    ),
  );

  Widget _creditsCard() => UiCard(
    title: 'Usage this month',
    subtitle: '${AppTokens.tierLabel(_tier)} plan',
    trailing: UiBadge(
      label: AppTokens.tierLabel(_tier),
      icon: AppTokens.tierIcon(_tier),
      intent: AppTokens.tierIntent(_tier),
      filled: true,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppUsageCard(
          label: 'Copilot answers',
          used: _credits.used,
          limit: _credits.limit,
          icon: Icons.auto_awesome_outlined,
          onUpgrade: widget.onUpgrade,
        ),
        UiGap.v(context.ui.spacing.sm),
        Text(
          _blocked
              ? 'The allowance is spent. Upgrade to keep asking, or wait for '
                    'the next cycle.'
              : '${_credits.remaining} answers left before the cycle resets.',
          style: context.uiText.caption.copyWith(
            color: _blocked
                ? context.uiColors.bearish
                : context.uiColors.foregroundMuted,
          ),
        ),
      ],
    ),
  );

  Widget _sourcesCard() => UiCard(
    title: 'Grounded in',
    subtitle: _me == null
        ? 'Only your own data is read for this lens'
        : 'Only @${_me!.handle} data is read for this lens',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: context.sp(context.ui.spacing.xs),
          runSpacing: context.sp(context.ui.spacing.xs),
          children: <Widget>[
            for (final String source in aiScopeSources(_scope))
              UiBadge(
                label: source,
                icon: Icons.dataset_outlined,
                intent: UiIntent.info,
              ),
          ],
        ),
        if (_trades.isNotEmpty) ...<Widget>[
          UiGap.v(context.ui.spacing.sm),
          Text(
            '${_trades.length} executions and '
            '${_insights.length} standing observations are in scope.',
            style: context.uiText.caption.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _disclaimer() => const UiCallout(
    title: 'Guidance, not advice',
    message:
        'The copilot reads your history and can be wrong. Size positions on '
        'your own plan and verify anything it claims about a market.',
    intent: UiIntent.warning,
    icon: Icons.info_outline_rounded,
  );

  Widget _gateCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      AppFadeIn(
        child: AppTierGateCard(
          requiredTier: _nextTier,
          title: 'Monthly copilot allowance used',
          message:
              'You have used all ${_credits.limit} answers on the '
              '${AppTokens.tierLabel(_tier)} plan. '
              '${AppTokens.tierLabel(_nextTier)} raises the ceiling and keeps '
              'your threads, insights and trade reviews as they are.',
          onUpgrade: widget.onUpgrade,
        ),
      ),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(delay: AppMotion.step, child: _creditsCard()),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(delay: AppMotion.step * 2, child: _disclaimer()),
    ],
  );

  Widget _insightsView() => AppWorkspacePane(
    initialRatio: 0.4,
    listTitle: 'Standing observations',
    detailTitle: 'Analysis',
    hasSelection: _openInsight != null,
    onClearSelection: () => setState(() => _openInsight = null),
    placeholderTitle: 'Open an observation',
    placeholderMessage:
        'Each one is derived from your executions, with the sample it used.',
    placeholderIcon: Icons.auto_awesome_outlined,
    breadcrumbs: <UiCrumb>[
      const UiCrumb(label: 'Copilot'),
      const UiCrumb(label: 'Insights'),
      if (_openInsight != null) UiCrumb(label: _openInsight!.title),
    ],
    list: _loadingInsights
        ? Column(
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(context.ui.spacing.md),
                  ),
                  child: UiCard(child: UiSkeleton(height: context.sz(96))),
                ),
            ],
          )
        : _insights.isEmpty
        ? UiEmptyState(
            title: 'No observations yet',
            message: 'Generate a pass over your recent executions.',
            icon: Icons.auto_awesome_outlined,
            action: UiButton(
              label: 'Generate',
              leadingIcon: Icons.refresh_rounded,
              expandOnMobile: false,
              onPressed: _reloadInsights,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < _insights.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(context.ui.spacing.md),
                  ),
                  child: AppFadeIn(
                    delay: AppMotion.step * i,
                    child: _insightRow(_insights[i]),
                  ),
                ),
            ],
          ),
    detail: _openInsight == null
        ? const SizedBox.shrink()
        : _insightDetail(_openInsight!),
  );

  /// Compact row for the list pane. The full [AppAiAnalysisCard] is reserved
  /// for the detail pane, where the observations have room to breathe.
  Widget _insightRow(AppAiInsight insight) {
    return UiCard(
      variant: UiCardVariant.surface,
      selected: _openInsight?.id == insight.id,
      onTap: () => _openInsightDetail(insight),
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.auto_awesome_rounded,
                size: context.sz(context.ui.sizes.iconSm),
                color: context.uiColors.primary,
              ),
              UiGap.h(context.ui.spacing.xs),
              Expanded(
                child: Text(
                  insight.title,
                  style: context.uiText.bodyStrong,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (insight.confidence != null)
                UiBadge(
                  label: AppTokens.percent(insight.confidence! * 100),
                  intent: _confidenceIntent(insight.confidence!),
                ),
            ],
          ),
          UiGap.v(context.ui.spacing.xs),
          Text(
            insight.body,
            style: context.uiText.caption.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (insight.tickers.isNotEmpty) ...<Widget>[
            UiGap.v(context.ui.spacing.sm),
            Wrap(
              spacing: context.sp(context.ui.spacing.xs),
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                for (final String ticker in insight.tickers)
                  UiBadge(label: '\$$ticker', intent: UiIntent.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Confidence is the only number the copilot asserts about itself, so it is
  /// coloured on the same scale a trader reads P&L on.
  UiIntent _confidenceIntent(double confidence) => confidence >= 0.66
      ? UiIntent.bullish
      : confidence >= 0.33
      ? UiIntent.warning
      : UiIntent.bearish;

  /// Detail pane for an observation: the full analysis, the sample it was
  /// derived from, and a jump into chat so the finding can be interrogated.
  Widget _insightDetail(AppAiInsight insight) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      AppFadeIn(
        child: AppAiAnalysisCard(
          insight: insight,
          observations: _observations,
          loading: _loadingObservations,
          onAsk: () => _askAbout(insight),
          onDismiss: () => _dismissInsight(insight),
          onTickerTap: widget.onOpenSymbol,
        ),
      ),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(delay: AppMotion.step, child: _disclaimer()),
    ],
  );

  // ---------------------------------------------------------------- review

  /// Trade review: pick one execution, get a verdict on it. The outcome filter
  /// exists because "review my losers" is the request that actually gets made.
  Widget _reviewView() => AppWorkspacePane(
    initialRatio: 0.38,
    listTitle: 'Executions',
    detailTitle: 'Verdict',
    hasSelection: _reviewTrade != null,
    onClearSelection: () => setState(() {
      _reviewTrade = null;
      _review = null;
    }),
    placeholderTitle: 'Pick a trade',
    placeholderMessage:
        'The copilot grades the entry, the exit and the sizing, then tells you '
        'which of the three cost you money.',
    placeholderIcon: Icons.rate_review_outlined,
    breadcrumbs: <UiCrumb>[
      const UiCrumb(label: 'Copilot'),
      const UiCrumb(label: 'Trade review'),
      if (_reviewTrade != null) UiCrumb(label: _reviewTrade!.ticker),
    ],
    list: _reviewList(),
    detail: _reviewTrade == null
        ? const SizedBox.shrink()
        : _reviewDetail(_reviewTrade!),
  );
  Widget _reviewList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      UiToggleGroup<AppOutcome?>(
        value: _outcomeFilter,
        onChanged: _setOutcomeFilter,
        expand: context.uiRes.isMobile,
        options: const <UiToggleOption<AppOutcome?>>[
          UiToggleOption<AppOutcome?>(value: null, label: 'All'),
          UiToggleOption<AppOutcome?>(
            value: AppOutcome.win,
            label: 'Wins',
            intent: UiIntent.bullish,
          ),
          UiToggleOption<AppOutcome?>(
            value: AppOutcome.loss,
            label: 'Losses',
            intent: UiIntent.bearish,
          ),
          UiToggleOption<AppOutcome?>(
            value: AppOutcome.open,
            label: 'Open',
            intent: UiIntent.info,
          ),
        ],
      ),
      UiGap.v(context.ui.spacing.md),
      if (_trades.isEmpty)
        UiEmptyState(
          title: 'Nothing to review',
          message: _outcomeFilter == null
              ? 'Log a trade in the journal and the copilot can grade it.'
              : 'No ${AppTokens.outcomeLabel(_outcomeFilter!).toLowerCase()} '
                    'trades in this window — try another filter.',
          icon: Icons.rate_review_outlined,
        )
      else
        for (int i = 0; i < _trades.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.sm)),
            child: AppFadeIn(
              delay: AppMotion.step * (i > 8 ? 8 : i),
              child: AppTradeCard(
                trade: _trades[i],
                dense: true,
                selected: _reviewTrade?.id == _trades[i].id,
                onTap: () => _openReview(_trades[i]),
              ),
            ),
          ),
    ],
  );

  /// Detail pane for a review: the execution itself, then the verdict. The
  /// verdict spends a credit, so an exhausted allowance shows the gate here too
  /// rather than a silently empty card.
  Widget _reviewDetail(AppTrade trade) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      AppFadeIn(child: AppTradeCard(trade: trade)),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(
        delay: AppMotion.step,
        child: _blocked ? _gateCard() : _verdictCard(trade),
      ),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(delay: AppMotion.step * 2, child: _disclaimer()),
    ],
  );

  Widget _verdictCard(AppTrade trade) => UiCard(
    title: 'Copilot verdict',
    subtitle:
        '${AppTokens.sideLabel(trade.side)} · '
        '${AppTokens.outcomeLabel(trade.outcome)} · '
        '${AppTokens.signedMoney(trade.pnl)}',
    accentColor: context.uiColors.primary,
    loading: _reviewing,
    loadingHeight: 140,
    actions: <Widget>[
      UiButton(
        label: 'Discuss in chat',
        leadingIcon: Icons.forum_outlined,
        variant: UiVariant.outline,
        size: UiSize.sm,
        expandOnMobile: false,
        onPressed: _reviewing ? null : () => _discussTrade(trade),
      ),
      UiButton(
        label: 'Re-run',
        leadingIcon: Icons.refresh_rounded,
        variant: UiVariant.ghost,
        size: UiSize.sm,
        expandOnMobile: false,
        onPressed: _reviewing ? null : () => _openReview(trade),
      ),
      UiButton(
        label: 'Copy',
        leadingIcon: Icons.copy_all_rounded,
        variant: UiVariant.ghost,
        size: UiSize.sm,
        expandOnMobile: false,
        onPressed: _review == null ? null : () => _copyText(_review!),
      ),
    ],
    child: Text(_review ?? '', style: context.uiText.body),
  );
}

/// Attachment picker. Grounding an answer in a specific execution is the one
/// thing a trader always wants to do, so the composer's attach action opens the
/// journal rather than a file browser.
class _TradePicker extends StatefulWidget {
  const _TradePicker({required this.trades});

  final List<AppTrade> trades;

  @override
  State<_TradePicker> createState() => _TradePickerState();
}

class _TradePickerState extends State<_TradePicker> {
  String _search = '';

  List<AppTrade> get _rows {
    final String needle = _search.trim().toLowerCase();
    if (needle.isEmpty) return widget.trades;
    return widget.trades
        .where(
          (AppTrade t) =>
              t.ticker.toLowerCase().contains(needle) ||
              (t.strategy ?? '').toLowerCase().contains(needle) ||
              t.tags.any((String tag) => tag.toLowerCase().contains(needle)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<AppTrade> rows = _rows;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Attach a trade', style: context.uiText.heading),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.xs),
        Text(
          'The copilot reads the entry, exit, sizing and notes of whatever you '
          'attach.',
          style: context.uiText.caption.copyWith(
            color: context.uiColors.foregroundMuted,
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        UiInput.search(
          value: _search,
          hintText: 'Search ticker, playbook or tag',
          onChanged: (String value) => setState(() => _search = value),
        ),
        UiGap.v(context.ui.spacing.md),
        Flexible(
          child: rows.isEmpty
              ? UiEmptyState(
                  title: 'No match for "$_search"',
                  message: 'Try a ticker or the playbook name.',
                  icon: Icons.search_off_rounded,
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final AppTrade trade in rows)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: context.sp(context.ui.spacing.sm),
                          ),
                          child: AppTradeCard(
                            trade: trade,
                            dense: true,
                            onTap: () => Navigator.of(context).pop(trade),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
