import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_create_sheet.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_persona_dialog.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';

/// Contextual bottom sheet overlay for the AI Copilot.
///
/// Can be summoned over ANY feature screen (Notes, Journal, Strategies, Messages,
/// Community, Workspace) with optional pre-populated context (record title,
/// initial prompt, and links). Eliminates blank screens and provides immediate,
/// in-place interactive quantitative AI assistance without navigating away.
class AiAssistantOverlaySheet extends StatefulWidget {
  const AiAssistantOverlaySheet({
    super.key,
    required this.repository,
    this.initialPrompt,
    this.contextTitle,
    this.contextSubtitle,
    this.contextIcon,
    this.contextRef,
    this.onOpenRef,
    this.onOpenFullScreen,
  });

  final AiAssistantRepository repository;
  final String? initialPrompt;
  final String? contextTitle;
  final String? contextSubtitle;
  final IconData? contextIcon;
  final AppLinkRef? contextRef;
  final void Function(AppLinkRef ref)? onOpenRef;
  final VoidCallback? onOpenFullScreen;

  /// Shows the AI Assistant as an interactive bottom sheet over any feature.
  static Future<void> show(
    BuildContext context, {
    required AiAssistantRepository repository,
    String? initialPrompt,
    String? contextTitle,
    String? contextSubtitle,
    IconData? contextIcon,
    AppLinkRef? contextRef,
    void Function(AppLinkRef ref)? onOpenRef,
    VoidCallback? onOpenFullScreen,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AiAssistantOverlaySheet(
        repository: repository,
        initialPrompt: initialPrompt,
        contextTitle: contextTitle,
        contextSubtitle: contextSubtitle,
        contextIcon: contextIcon,
        contextRef: contextRef,
        onOpenRef: onOpenRef,
        onOpenFullScreen: onOpenFullScreen,
      ),
    );
  }

  @override
  State<AiAssistantOverlaySheet> createState() =>
      _AiAssistantOverlaySheetState();
}

class _AiAssistantOverlaySheetState extends State<AiAssistantOverlaySheet> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late final AiAssistantRepository _repo = widget.repository;
  bool _contextDismissed = false;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoChange);

    // If an initial prompt was provided and thread is empty or prompt isn't already sent,
    // execute it immediately so the user sees real answers right away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialPrompt != null &&
          widget.initialPrompt!.trim().isNotEmpty) {
        final String prompt = widget.initialPrompt!.trim();
        final bool alreadySent =
            _repo.messages.isNotEmpty && _repo.messages.last.body == prompt;
        if (!alreadySent) {
          _repo.sendPrompt(prompt);
        }
      }
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChange);
    _promptController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onRepoChange() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _send() {
    final String text = _promptController.text.trim();
    if (text.isEmpty) return;
    _promptController.clear();
    _repo.sendPrompt(text);
    _scrollToBottom();
  }

  void _openPersonaChooser() async {
    final AiPersona? picked = await AiPersonaDialog.show(
      context,
      current: _repo.persona,
    );
    if (picked != null && mounted) {
      _repo.setPersona(picked);
    }
  }

  void _openCreateSheet(AiCreateTarget target, {AiChartSetup? setup}) {
    Navigator.of(context).pop();
    AiCreateSheet.show(
      context,
      repository: _repo,
      target: target,
      setup: setup ??
          AiChartSetup(
            id: 'setup_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Setup: ${widget.contextRef?.title ?? widget.contextTitle ?? "Market Analysis"}',
            symbol: widget.contextRef?.title ?? widget.contextTitle ?? 'NIFTY',
            timeframe: '15m',
            direction: AiTradeDirection.long,
            pattern: 'High Probability Setup',
            entry: 24800,
            stopLoss: 24720,
            target1: 24960,
            target2: 25040,
            confidence: 86,
            rationale: 'Trend continuation & momentum breakout',
          ),
      onOpenRef: widget.onOpenRef,
    );
  }

  void _shareToDm(AppAiMessage message) {
    Navigator.of(context).pop();
    final AppLinkRef ref = AppLinkRef(
      id: message.id,
      kind: AppLinkKind.aiCopilot,
      title: 'AI Copilot Insight',
      subtitle: message.body.length > 60
          ? '${message.body.substring(0, 60)}...'
          : message.body,
      intent: UiIntent.primary,
    );
    ShareToConversationDialog.show(
      context,
      repository: MessagesRepositoryScope.repository,
      reference: ref,
      onShared: (String threadId) {
        UiToastScope.maybeOf(context)?.show(
          UiToastData(
            title: 'Copilot Insight Shared',
            message: 'Analysis shared with conversation.',
            intent: UiIntent.success,
          ),
        );
      },
    );
  }

  List<String> get _contextualChips {
    final String? title = widget.contextTitle?.toLowerCase();
    if (title != null && (title.contains('trade') || title.contains('journal'))) {
      return <String>[
        'Evaluate execution discipline & R:R',
        'Suggest Stop Loss & Take Profit adjustments',
        'Check for emotional trade patterns',
        'How could this trade be managed better?',
      ];
    }
    if (title != null && (title.contains('strategy') || title.contains('playbook'))) {
      return <String>[
        'Stress-test this playbook in high volatility',
        'Calculate optimal position sizing formula',
        'Identify common false breakout traps',
        'Recommend key risk guardrails',
      ];
    }
    if (title != null && title.contains('note')) {
      return <String>[
        'Summarize key insights & action items',
        'Extract high-conviction trade setups',
        'Convert note into a formalized Strategy Playbook',
        'Highlight potential confirmation biases',
      ];
    }
    if (title != null &&
        (title.contains('community') ||
            title.contains('market') ||
            title.contains('alpha') ||
            title.contains('pulse'))) {
      return <String>[
        'Scan community sentiment on BankNifty & Top F&O movers',
        'Generate swing trade setup with entry, stop loss, and targets',
        'Draft an institutional macro thesis post for the community feed',
        'Evaluate peer breakout setups & risk/reward ratio',
        'Check FII / DII net institutional flow bias',
      ];
    }
    return <String>[
      'Analyze current market structure',
      'Review risk-to-reward parameters',
      'Generate trade setup plan',
      'Audit sizing and exposure limits',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final double sheetHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.radius(theme.radii.xl).topLeft.x),
        ),
        border: Border.all(
          color: colors.border,
          width: theme.borders.hairline,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 6),
            const Center(child: AiSheetGrabber()),
            _buildHeader(context, theme, colors),
            UiDivider(spacing: theme.spacing.xxs),
            if (!_contextDismissed && widget.contextTitle != null)
              _buildContextBar(context, theme, colors),
            Expanded(
              child: _buildMessagesList(context, theme, colors),
            ),
            _buildQuickPromptsBar(context, theme, colors),
            _buildComposer(context, theme, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UiTheme theme, UiColors colors) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: context.radius(theme.radii.sm),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.primary,
              size: context.sz(18),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'TradeX AI Copilot',
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(15),
                  ),
                ),
                Text(
                  'Institutional Market Intelligence',
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                    fontSize: context.fs(11),
                  ),
                ),
              ],
            ),
          ),
          UiButton(
            label: _repo.persona.label,
            leadingIcon: _repo.persona.icon,
            size: UiSize.xs,
            variant: UiVariant.soft,
            intent: UiIntent.primary,
            onPressed: _openPersonaChooser,
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          if (widget.onOpenFullScreen != null) ...<Widget>[
            UiIconButton(
              icon: Icons.fullscreen_rounded,
              size: UiSize.sm,
              variant: UiVariant.ghost,
              tooltip: 'Open Full Copilot',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOpenFullScreen!();
              },
            ),
          ],
          UiIconButton(
            icon: Icons.close_rounded,
            size: UiSize.sm,
            variant: UiVariant.ghost,
            tooltip: 'Close Copilot',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBar(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xxs),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xxs),
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
          width: theme.borders.hairline,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            widget.contextIcon ?? Icons.attachment_rounded,
            size: context.sz(14),
            color: colors.primary,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Text(
              'Attached Context: ${widget.contextTitle!}${widget.contextSubtitle != null ? " • ${widget.contextSubtitle}" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          UiIconButton(
            icon: Icons.close_rounded,
            size: UiSize.xs,
            variant: UiVariant.ghost,
            tooltip: 'Detach Context',
            onPressed: () => setState(() => _contextDismissed = true),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    final List<AppAiMessage> msgs = _repo.messages;

    if (msgs.isEmpty && !_repo.generating) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.auto_awesome_rounded,
            title: 'How can Copilot assist you?',
            message:
                'Ask about position sizing, technical structure, execution auditing, or stress-test this setup.',
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      itemCount: msgs.length + (_repo.generating ? 1 : 0),
      itemBuilder: (BuildContext ctx, int index) {
        if (index == msgs.length && _repo.generating) {
          return _buildGeneratingIndicator(context, theme, colors);
        }
        final AppAiMessage m = msgs[index];
        return _buildMessageItem(context, theme, colors, m);
      },
    );
  }

  Widget _buildGeneratingIndicator(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.primary,
              size: context.sz(14),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.lg),
                border: Border.all(
                  color: colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const UiTypingIndicator(),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Text(
                    'Analyzing with ${_repo.persona.label} lens...',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    AppAiMessage msg,
  ) {
    final bool isUser = msg.role == AppAiRole.user;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colors.primary,
                size: context.sz(14),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                  decoration: BoxDecoration(
                    color: isUser ? colors.primary : colors.surfaceMuted,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(
                        context.radius(theme.radii.lg).topLeft.x,
                      ),
                      topRight: Radius.circular(
                        context.radius(theme.radii.lg).topLeft.x,
                      ),
                      bottomLeft: isUser
                          ? Radius.circular(
                              context.radius(theme.radii.lg).topLeft.x,
                            )
                          : Radius.zero,
                      bottomRight: isUser
                          ? Radius.zero
                          : Radius.circular(
                              context.radius(theme.radii.lg).topLeft.x,
                            ),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: colors.border,
                            width: theme.borders.hairline,
                          ),
                  ),
                  child: Text(
                    msg.body,
                    style: context.uiText.body.copyWith(
                      color: isUser ? colors.onPrimary : colors.foreground,
                      height: 1.4,
                      fontSize: context.fs(13.5),
                    ),
                  ),
                ),
                if (!isUser) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  _buildMessageActions(context, theme, colors, msg),
                ],
              ],
            ),
          ),
          if (isUser) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                color: colors.foregroundMuted,
                size: context.sz(14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageActions(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    AppAiMessage msg,
  ) {
    return Wrap(
      spacing: context.sp(theme.spacing.xs),
      runSpacing: 4,
      children: <Widget>[
        UiButton(
          label: 'Copy',
          leadingIcon: Icons.copy_rounded,
          size: UiSize.xs,
          variant: UiVariant.ghost,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: msg.body));
            UiToastScope.maybeOf(context)?.show(
              UiToastData(
                title: 'Copied',
                message: 'Analysis copied to clipboard.',
                intent: UiIntent.info,
              ),
            );
          },
        ),
        UiButton(
          label: 'Save Note',
          leadingIcon: Icons.sticky_note_2_outlined,
          size: UiSize.xs,
          variant: UiVariant.ghost,
          onPressed: () => _openCreateSheet(AiCreateTarget.note),
        ),
        UiButton(
          label: 'Log Trade',
          leadingIcon: Icons.menu_book_outlined,
          size: UiSize.xs,
          variant: UiVariant.ghost,
          onPressed: () => _openCreateSheet(AiCreateTarget.journal),
        ),
        UiButton(
          label: 'Strategy',
          leadingIcon: Icons.account_tree_outlined,
          size: UiSize.xs,
          variant: UiVariant.ghost,
          onPressed: () => _openCreateSheet(AiCreateTarget.strategy),
        ),
        UiButton(
          label: 'Post',
          leadingIcon: Icons.forum_outlined,
          size: UiSize.xs,
          variant: UiVariant.ghost,
          onPressed: () => _openCreateSheet(AiCreateTarget.post),
        ),
        UiButton(
          label: 'Share',
          leadingIcon: Icons.share_outlined,
          size: UiSize.xs,
          variant: UiVariant.ghost,
          onPressed: () => _shareToDm(msg),
        ),
      ],
    );
  }

  Widget _buildQuickPromptsBar(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    final List<String> chips = _contextualChips;

    return Container(
      height: 38,
      margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.md)),
        itemCount: chips.length,
        separatorBuilder: (_, _) =>
            SizedBox(width: context.sp(theme.spacing.xs)),
        itemBuilder: (BuildContext ctx, int i) {
          final String prompt = chips[i];
          return ActionChip(
            label: Text(
              prompt,
              style: context.uiText.caption.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w500,
                fontSize: context.fs(11),
              ),
            ),
            backgroundColor: colors.surfaceMuted,
            side: BorderSide(
              color: colors.border,
              width: theme.borders.hairline,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: context.radius(theme.radii.pill),
            ),
            onPressed: () {
              _repo.sendPrompt(prompt);
              _scrollToBottom();
            },
          );
        },
      ),
    );
  }

  Widget _buildComposer(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xs),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: UiInput(
              controller: _promptController,
              focusNode: _focusNode,
              hintText: 'Ask Copilot about risk, structure, execution...',
              onSubmitted: (_) => _send(),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          if (_repo.generating)
            UiIconButton(
              icon: Icons.stop_rounded,
              size: UiSize.md,
              intent: UiIntent.danger,
              tooltip: 'Stop Generation',
              onPressed: () => _repo.stop(),
            )
          else
            UiIconButton(
              icon: Icons.send_rounded,
              size: UiSize.md,
              intent: UiIntent.primary,
              tooltip: 'Send Prompt',
              onPressed: _send,
            ),
        ],
      ),
    );
  }
}
