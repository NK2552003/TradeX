import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';
import 'package:tradex/core/markdown_kit/research/research_answer_tools.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../models/app_models_extra.dart';
import '../theme/app_tokens.dart';
import '../motion/ai_typewriter.dart';
import '../motion/ai_typing_indicator.dart';

/// One AI chat bubble. User messages align right on a filled surface,
/// assistant messages align left with rich markdown (charts, tables,
/// flowcharts, callouts, math, code blocks), smooth streaming typewriter
/// reveal, sources, and copy/retry affordances.
class AppAiMessageBubble extends StatefulWidget {
  const AppAiMessageBubble({
    super.key,
    required this.message,
    this.onCopy,
    this.onRetry,
    this.onShare,
    this.onSourceTap,
    this.onOpenRef,
    this.onFollowUpTap,
    this.actionsBuilder,
    this.minimal = false,
  });

  final AppAiMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final VoidCallback? onShare;
  final ValueChanged<String>? onSourceTap;
  final void Function(AppLinkRef ref)? onOpenRef;
  final ValueChanged<String>? onFollowUpTap;

  /// Optional extra actions rendered beneath a settled (non-pending) answer —
  /// e.g. "Save note", "Log trade". Returns null/empty to add nothing, so
  /// existing call sites that omit it are unaffected.
  final List<Widget>? Function(AppAiMessage message)? actionsBuilder;
  final bool minimal;

  @override
  State<AppAiMessageBubble> createState() => _AppAiMessageBubbleState();
}

class _AppAiMessageBubbleState extends State<AppAiMessageBubble> {
  final AiTypewriter _typewriter = AiTypewriter();
  bool _streamedInSession = false;
  int _answerTab = 0;
  bool? _helpfulVote;
  bool get _isAssistant => widget.message.role == AppAiRole.assistant;

  @override
  void initState() {
    super.initState();
    _streamedInSession = _isAssistant && widget.message.pending;
    _typewriter.reset(widget.message.body, animate: _streamedInSession);
    _typewriter.addListener(_onReveal);
  }

  void _onReveal() {
    if (!mounted) return;
    setState(() {});
    const AiOutputGrowthNotification().dispatch(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _typewriter.reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant AppAiMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.id != oldWidget.message.id) {
      _answerTab = 0;
      _helpfulVote = null;
      _streamedInSession = _isAssistant && widget.message.pending;
      _typewriter.reset(widget.message.body, animate: _streamedInSession);
    } else {
      _streamedInSession =
          _streamedInSession ||
          (_isAssistant &&
              (widget.message.pending || oldWidget.message.pending));
      _typewriter.update(widget.message.body, animate: _streamedInSession);
    }
  }

  @override
  void dispose() {
    _typewriter.removeListener(_onReveal);
    _typewriter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final AppAiMessage message = widget.message;
    final bool mine = message.role == AppAiRole.user;
    final bool isAnimatingStream =
        _isAssistant && (message.pending || _typewriter.isTyping);
    final List<Widget> extraActions =
        (message.pending ? null : widget.actionsBuilder?.call(message)) ??
        const <Widget>[];

    if (message.role == AppAiRole.system) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
        child: Center(
          child: Text(
            message.body,
            textAlign: TextAlign.center,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
            ),
          ),
        ),
      );
    }

    final String displayedBody = _isAssistant
        ? _typewriter.visibleText
        : message.body;

    final PerplexityAnswerMeta? meta = _isAssistant && displayedBody.isNotEmpty
        ? PerplexityAnswerParser.parse(
            displayedBody,
            explicitUrls: message.sources,
            structuredSources: [
              for (final AppAiSource s in message.structuredSources)
                (
                  url: s.url,
                  title: s.title,
                  domain: s.domain,
                  snippet: s.snippet,
                ),
            ],
            externalSteps: message.steps,
            focus: message.focus,
            isStreaming: isAnimatingStream,
          )
        : null;

    final List<String> effectiveFollowUps = <String>[
      ...?meta?.followUps,
      for (final String q in message.followUps)
        if (!(meta?.followUps.contains(q) ?? false)) q,
    ];

    final List<PerplexityCardSummary> structuredCards =
        (meta?.cards ?? const <PerplexityCardSummary>[])
            .where(
              (c) => c.rawSpec.trim().isNotEmpty && c.tag != 'loading_card',
            )
            .toList(growable: false);

    final List<_PerplexityTabKind> availableTabs = <_PerplexityTabKind>[
      _PerplexityTabKind.answer,
      if (meta != null && meta.sources.isNotEmpty) _PerplexityTabKind.sources,
      if (structuredCards.isNotEmpty) _PerplexityTabKind.cards,
      if (meta != null && meta.media.isNotEmpty) _PerplexityTabKind.media,
    ];

    final bool showPerplexityChrome =
        _isAssistant &&
        meta != null &&
        (meta.isRichAnswer || message.mode != null || message.focus != null);

    final int tabIndex = _answerTab.clamp(0, availableTabs.length - 1);
    final _PerplexityTabKind activeTab = availableTabs[tabIndex];

    final Widget bubble = Container(
      constraints: BoxConstraints(
        maxWidth: context.uiRes.isMobile
            ? double.infinity
            : context.sz(widget.minimal ? 840 : 600),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.sm),
      ),
      decoration: BoxDecoration(
        color: widget.minimal
            ? (mine ? theme.colors.surfaceMuted : Colors.transparent)
            : (mine ? theme.colors.primary : theme.colors.surfaceMuted),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(context.sz(theme.radii.lg)),
          topRight: Radius.circular(context.sz(theme.radii.lg)),
          bottomLeft: Radius.circular(
            context.sz(mine ? theme.radii.lg : theme.radii.sm),
          ),
          bottomRight: Radius.circular(
            context.sz(mine ? theme.radii.sm : theme.radii.lg),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (message.pending && displayedBody.isEmpty)
            Text('Preparing your answer…', style: context.uiText.caption)
          else if (mine)
            _buildUserMessageText(context, theme)
          else ...<Widget>[
            if (showPerplexityChrome) ...<Widget>[
              _PerplexityAnswerHeader(
                mode: message.mode,
                focus: message.focus,
                tabs: availableTabs,
                sourcesCount: meta.sources.length,
                cardsCount: structuredCards.length,
                mediaCount: meta.media.length,
                selectedTab: tabIndex,
                onTabChanged: (int i) => setState(() => _answerTab = i),
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (activeTab == _PerplexityTabKind.sources &&
                meta != null &&
                meta.sources.isNotEmpty)
              _PerplexitySourcesListView(
                sources: meta.sources,
                onSourceTap: widget.onSourceTap,
              )
            else if (activeTab == _PerplexityTabKind.cards &&
                structuredCards.isNotEmpty)
              _PerplexityCardsDeckView(
                cards: structuredCards,
                onOpenRef: widget.onOpenRef,
                onTapUrl: widget.onSourceTap,
                onPromptTap: widget.onFollowUpTap,
              )
            else if (activeTab == _PerplexityTabKind.media &&
                meta != null &&
                meta.media.isNotEmpty)
              _PerplexityMediaGalleryView(
                media: meta.media,
                onSourceTap: widget.onSourceTap,
              )
            else ...<Widget>[
              if (meta != null && meta.steps.isNotEmpty) ...<Widget>[
                _PerplexityStepsAccordion(
                  steps: meta.steps,
                  sourcesCount: meta.sources.length,
                  cardsCount: structuredCards.length,
                  isStreaming: isAnimatingStream,
                ),
                UiGap.v(theme.spacing.sm),
              ],
              if (meta != null && meta.sources.isNotEmpty) ...<Widget>[
                _PerplexitySourcesCarousel(
                  sources: meta.sources,
                  onSourceTap: widget.onSourceTap,
                  onViewAll: () {
                    final int idx = availableTabs.indexOf(
                      _PerplexityTabKind.sources,
                    );
                    if (idx >= 0) setState(() => _answerTab = idx);
                  },
                ),
                UiGap.v(theme.spacing.md),
              ],
              RichMarkdownPreview(
                data: meta?.cleanMarkdown ?? displayedBody,
                emptyPlaceholder: '',
                selectable: !isAnimatingStream,
                showTypingCursor:
                    isAnimatingStream &&
                    !MediaQuery.disableAnimationsOf(context),
                onOpenRef: widget.onOpenRef,
                onPromptTap: widget.onFollowUpTap,
                imageResolver: (BuildContext ctx, Uri uri) => ClipRRect(
                  borderRadius: ctx.radius(ctx.ui.radii.md),
                  child: UiRemoteImage(url: uri.toString(), fit: BoxFit.cover),
                ),
                onTapLink: (String text, String? href, String title) {
                  if (href != null &&
                      (href.startsWith('https://') ||
                          href.startsWith('http://'))) {
                    widget.onSourceTap?.call(href);
                  }
                },
              ),
            ],
            if (isAnimatingStream && !MediaQuery.disableAnimationsOf(context))
              Row(
                children: [
                  if (!_typewriter.skipped)
                    UiButton(
                      label: 'Skip',
                      variant: UiVariant.ghost,
                      size: UiSize.xs,
                      onPressed: _typewriter.skip,
                    ),
                ],
              ),
          ],
          if (message.error != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Text(
              message.error!,
              style: context.uiText.caption.copyWith(
                color: theme.colors.destructive,
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          bubble,
          if (!mine && !message.pending && !isAnimatingStream && meta != null)
            ResearchAnswerTools(
              markdown: message.body,
              meta: meta,
              onSourceTap: widget.onSourceTap,
              onPrompt: widget.onFollowUpTap,
              sentAt: message.sentAt,
            ),
          if (!mine && !message.pending && !isAnimatingStream)
            Padding(
              padding: EdgeInsets.only(top: context.sp(theme.spacing.xxs)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (widget.onCopy != null)
                      UiIconButton(
                        icon: Icons.copy_all_outlined,
                        size: UiSize.xs,
                        tooltip: 'Copy',
                        onPressed: widget.onCopy,
                      ),
                    if (widget.onRetry != null)
                      UiIconButton(
                        icon: Icons.refresh,
                        size: UiSize.xs,
                        tooltip: 'Regenerate',
                        onPressed: widget.onRetry,
                      ),
                    if (widget.onShare != null)
                      UiIconButton(
                        icon: Icons.send_outlined,
                        size: UiSize.xs,
                        tooltip: 'Share in message',
                        onPressed: widget.onShare,
                      ),
                    if (widget.onFollowUpTap != null)
                      _PerplexityRewriteMenu(onSelect: widget.onFollowUpTap!),
                    UiIconButton(
                      icon: _helpfulVote == true
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      size: UiSize.xs,
                      tooltip: 'Helpful answer',
                      intent: _helpfulVote == true ? UiIntent.bullish : null,
                      onPressed: () => setState(
                        () => _helpfulVote = _helpfulVote == true ? null : true,
                      ),
                    ),
                    UiIconButton(
                      icon: _helpfulVote == false
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                      size: UiSize.xs,
                      tooltip: 'Needs improvement',
                      intent: _helpfulVote == false ? UiIntent.bearish : null,
                      onPressed: () => setState(
                        () =>
                            _helpfulVote = _helpfulVote == false ? null : false,
                      ),
                    ),
                    if (message.sentAt != null)
                      Padding(
                        padding: EdgeInsets.only(
                          left: context.sp(theme.spacing.xxs),
                          right: context.sp(theme.spacing.xs),
                        ),
                        child: Text(
                          AppTokens.relativeTime(message.sentAt!),
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundSubtle,
                            fontSize: context.fs(11),
                          ),
                        ),
                      ),
                    if (extraActions.isNotEmpty) ...<Widget>[
                      for (int i = 0; i < extraActions.length; i++) ...<Widget>[
                        if (i > 0 ||
                            widget.onCopy != null ||
                            widget.onRetry != null ||
                            message.sentAt != null)
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                        extraActions[i],
                      ],
                    ],
                  ],
                ),
              ),
            ),
          if (!mine &&
              !message.pending &&
              !isAnimatingStream &&
              effectiveFollowUps.isNotEmpty &&
              widget.onFollowUpTap != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.uiRes.isMobile
                    ? double.infinity
                    : context.sz(widget.minimal ? 840 : 600),
              ),
              child: _PerplexityRelatedQuestions(
                questions: effectiveFollowUps,
                onTap: widget.onFollowUpTap!,
              ),
            ),
        ],
      ),
    );
  }

  static final RegExp _tickerRegex = RegExp(
    r'(?<![\$\w])\$([A-Za-z\^][A-Za-z0-9\.\-\_\^\=]{0,9})\b(?!\$)',
  );

  Widget _buildUserMessageText(BuildContext context, UiTheme theme) {
    final TextStyle baseStyle = context.uiText.body.copyWith(
      color: widget.minimal ? theme.colors.foreground : theme.colors.onPrimary,
    );
    final String text = widget.message.body;
    final Iterable<Match> matches = _tickerRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    int lastIndex = 0;
    for (final Match match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }
      final String rawTicker = match.group(0)!;
      final String symbol = match.group(1)!.toUpperCase();
      spans.add(
        TextSpan(
          text: rawTicker,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: theme.colors.onPrimary.withValues(alpha: 0.6),
          ),
          recognizer: widget.onOpenRef == null
              ? null
              : (TapGestureRecognizer()
                  ..onTap = () {
                    widget.onOpenRef!(
                      AppLinkRef(
                        kind: AppLinkKind.ticker,
                        id: symbol,
                        title: symbol,
                      ),
                    );
                  }),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }
    return Text.rich(TextSpan(children: spans), style: baseStyle);
  }
}

/// AI-generated analysis of a trade, strategy or ticker: verdict, confidence
/// meter, key observations and follow-up actions.
class AppAiAnalysisCard extends StatelessWidget {
  const AppAiAnalysisCard({
    super.key,
    required this.insight,
    this.observations = const <String>[],
    this.onAsk,
    this.onDismiss,
    this.onTickerTap,
    this.loading = false,
    this.error,
  });

  final AppAiInsight insight;
  final List<String> observations;
  final VoidCallback? onAsk;
  final VoidCallback? onDismiss;
  final ValueChanged<String>? onTickerTap;

  /// Renders the built-in [UiCard] skeleton instead of the analysis body.
  final bool loading;

  /// When set, shows an inline error callout instead of the analysis body.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double? confidence = insight.confidence;
    return UiCard(
      accentColor: theme.colors.primary,
      title: insight.title,
      loading: loading,
      subtitle: insight.createdAt == null
          ? 'AI analysis'
          : 'AI analysis · ${AppTokens.relativeTime(insight.createdAt!)}',
      trailing: onDismiss == null
          ? null
          : UiIconButton(
              icon: Icons.close,
              size: UiSize.sm,
              tooltip: 'Dismiss',
              onPressed: onDismiss,
            ),
      footer: onAsk == null
          ? null
          : UiButton(
              label: 'Ask a follow-up',
              variant: UiVariant.outline,
              leadingIcon: Icons.chat_bubble_outline,
              onPressed: onAsk,
            ),
      child: error != null
          ? UiCallout(
              title: 'Analysis failed',
              message: error,
              intent: UiIntent.bearish,
              icon: Icons.error_outline,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(insight.body, style: context.uiText.body),
                if (observations.isNotEmpty) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  for (final String o in observations)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.auto_awesome,
                            size: context.sz(theme.sizes.iconSm),
                            color: theme.colors.primary,
                          ),
                          SizedBox(width: context.sp(theme.spacing.sm)),
                          Expanded(child: Text(o, style: context.uiText.body)),
                        ],
                      ),
                    ),
                ],
                if (insight.sentimentScore != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xs),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      UiBadge(
                        label: AppTokens.sentimentLabel(
                          insight.sentimentScore!,
                        ),
                        filled: true,
                        intent: insight.sentimentScore! > 0
                            ? UiIntent.bullish
                            : (insight.sentimentScore! < 0
                                  ? UiIntent.bearish
                                  : UiIntent.neutral),
                      ),
                      for (final String t in insight.tickers)
                        UiBadge(
                          label: '\$$t',
                          intent: UiIntent.primary,
                          onTap: onTickerTap == null
                              ? null
                              : () => onTickerTap!(t),
                        ),
                    ],
                  ),
                ],
                if (confidence != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  UiProgressBar(
                    value: confidence,
                    label: 'Confidence',
                    intent: confidence >= 0.66
                        ? UiIntent.bullish
                        : (confidence >= 0.33
                              ? UiIntent.warning
                              : UiIntent.bearish),
                    valueFormatter: (num v) => AppTokens.percent(v * 100),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Horizontal row of suggested prompts shown above the composer.
class AppAiPromptChips extends StatelessWidget {
  const AppAiPromptChips({
    super.key,
    required this.prompts,
    required this.onSelect,
  });

  final List<AppAiPrompt> prompts;
  final ValueChanged<AppAiPrompt> onSelect;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final AppAiPrompt p in prompts)
            Padding(
              padding: EdgeInsets.only(right: context.sp(theme.spacing.xs)),
              child: UiBadge(
                label: p.label,
                icon: p.icon ?? Icons.bolt_outlined,
                size: UiSize.md,
                intent: UiIntent.primary,
                onTap: () => onSelect(p),
              ),
            ),
        ],
      ),
    );
  }
}

enum _PerplexityTabKind { answer, sources, cards, media }

class _PerplexityAnswerHeader extends StatelessWidget {
  const _PerplexityAnswerHeader({
    this.mode,
    this.focus,
    required this.tabs,
    required this.sourcesCount,
    required this.cardsCount,
    required this.mediaCount,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final String? mode;
  final String? focus;
  final List<_PerplexityTabKind> tabs;
  final int sourcesCount;
  final int cardsCount;
  final int mediaCount;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final String? cleanMode = mode?.trim();
    final String? cleanFocus = focus?.trim();
    final String badgeText = <String>[
      if (cleanMode != null && cleanMode.isNotEmpty) cleanMode,
      if (cleanFocus != null &&
          cleanFocus.isNotEmpty &&
          cleanFocus.toLowerCase() != 'all')
        cleanFocus,
    ].join(' · ');
    final bool hasBadge = badgeText.isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bool wideEnough = availW >= context.sz(390);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasBadge && !wideEnough) ...<Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: UiBadge(
                  label: badgeText,
                  icon: Icons.travel_explore_rounded,
                  size: UiSize.sm,
                  variant: UiBadgeVariant.soft,
                  intent: UiIntent.primary,
                ),
              ),
              UiGap.v(context.ui.spacing.xxs),
            ],
            UiTabs(
              items: <UiTabItem>[
                for (final _PerplexityTabKind tab in tabs)
                  switch (tab) {
                    _PerplexityTabKind.answer => UiTabItem(
                      label: 'Answer',
                      icon: Icons.auto_awesome_outlined,
                      badge:
                          cardsCount > 0 &&
                              !tabs.contains(_PerplexityTabKind.cards)
                          ? '$cardsCount'
                          : null,
                    ),
                    _PerplexityTabKind.sources => UiTabItem(
                      label: 'Sources',
                      icon: Icons.public_outlined,
                      count: sourcesCount,
                    ),
                    _PerplexityTabKind.cards => UiTabItem(
                      label: 'Cards',
                      icon: Icons.dashboard_customize_outlined,
                      count: cardsCount,
                    ),
                    _PerplexityTabKind.media => UiTabItem(
                      label: 'Media',
                      icon: Icons.collections_outlined,
                      count: mediaCount,
                    ),
                  },
              ],
              selectedIndex: selectedTab,
              onChanged: onTabChanged,
              variant: UiTabsVariant.underline,
              size: UiSize.sm,
              density: UiDensity.compact,
              scrollable: true,
              showPanel: false,
              trailing: (hasBadge && wideEnough)
                  ? UiBadge(
                      label: badgeText,
                      icon: Icons.travel_explore_rounded,
                      size: UiSize.sm,
                      variant: UiBadgeVariant.soft,
                      intent: UiIntent.primary,
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _PerplexityStepsAccordion extends StatelessWidget {
  const _PerplexityStepsAccordion({
    required this.steps,
    required this.sourcesCount,
    required this.cardsCount,
    required this.isStreaming,
  });

  final List<PerplexitySearchStep> steps;
  final int sourcesCount;
  final int cardsCount;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final String summary = <String>[
      '${steps.length} ${steps.length == 1 ? 'step' : 'steps'}',
      if (sourcesCount > 0) '$sourcesCount sources',
      if (cardsCount > 0) '$cardsCount cards',
    ].join(' · ');

    return UiAccordion(
      variant: UiAccordionVariant.contained,
      density: UiDensity.compact,
      sections: <UiAccordionSection>[
        UiAccordionSection(
          title: isStreaming ? 'Answer details · Updating' : 'Answer details',
          leadingIcon: isStreaming
              ? Icons.manage_search_rounded
              : Icons.fact_check_outlined,
          subtitle: summary,
          intent: UiIntent.primary,
          initiallyOpen: isStreaming,
          child: UiTimeline(
            entries: <UiTimelineEntry>[
              for (final PerplexitySearchStep s in steps)
                UiTimelineEntry(
                  title: s.title,
                  subtitle: s.detail.isEmpty ? null : s.detail,
                  icon: s.status == 'active'
                      ? Icons.sync_rounded
                      : Icons.check_circle_outline_rounded,
                  intent: s.status == 'active'
                      ? UiIntent.info
                      : UiIntent.bullish,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerplexityCardsDeckView extends StatelessWidget {
  const _PerplexityCardsDeckView({
    required this.cards,
    this.onOpenRef,
    this.onTapUrl,
    this.onPromptTap,
  });

  final List<PerplexityCardSummary> cards;
  final void Function(AppLinkRef ref)? onOpenRef;
  final ValueChanged<String>? onTapUrl;
  final ValueChanged<String>? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < cards.length; i++) ...<Widget>[
          PerplexityCardBlock(
            tag: cards[i].tag,
            spec: cards[i].rawSpec,
            onOpenRef: onOpenRef,
            onTapUrl: onTapUrl,
            onPromptTap: onPromptTap,
          ),
          if (i < cards.length - 1) UiGap.v(theme.spacing.xs),
        ],
      ],
    );
  }
}

class _PerplexityMediaGalleryView extends StatelessWidget {
  const _PerplexityMediaGalleryView({required this.media, this.onSourceTap});

  final List<PerplexityMediaItem> media;
  final ValueChanged<String>? onSourceTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double gap = ctx.sp(theme.spacing.sm);
        final double maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : ctx.sz(520);
        final int cols = maxW >= ctx.sz(520)
            ? 3
            : (maxW >= ctx.sz(340) ? 2 : 1);
        final double cardW = (maxW - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final PerplexityMediaItem item in media)
              SizedBox(
                width: cardW,
                child: UiCard(
                  variant: UiCardVariant.outlined,
                  density: UiDensity.compact,
                  onTap: () => UiLightbox.show(
                    ctx,
                    mediaUrl: item.url,
                    caption: item.caption.isEmpty ? null : item.caption,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: ctx.radius(theme.radii.sm),
                        child: UiRemoteImage(
                          url: item.url,
                          height: ctx.sz(116),
                          width: double.infinity,
                        ),
                      ),
                      if (item.caption.isNotEmpty ||
                          item.domain.isNotEmpty) ...<Widget>[
                        UiGap.v(theme.spacing.xs),
                        if (item.caption.isNotEmpty)
                          Text(
                            item.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ctx.uiText.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (item.domain.isNotEmpty) ...<Widget>[
                          UiGap.v(theme.spacing.xxs),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  item.domain,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ctx.uiText.caption.copyWith(
                                    color: theme.colors.foregroundSubtle,
                                  ),
                                ),
                              ),
                              if (item.sourceUrl.isNotEmpty &&
                                  onSourceTap != null)
                                UiIconButton(
                                  icon: Icons.open_in_new_rounded,
                                  size: UiSize.xs,
                                  tooltip: 'Open source',
                                  onPressed: () => onSourceTap!(item.sourceUrl),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PerplexityRewriteMenu extends StatelessWidget {
  const _PerplexityRewriteMenu({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return UiDropdownMenu(
      semanticLabel: 'Rewrite answer style',
      actions: <UiMenuItem>[
        UiMenuItem(
          label: 'Concise executive brief',
          icon: Icons.short_text_rounded,
          onPressed: () => onSelect(
            'Rewrite your previous answer as a crisp executive brief with key bullets and numbers only.',
          ),
        ),
        UiMenuItem(
          label: 'Deep financial & quant breakdown',
          icon: Icons.analytics_outlined,
          onPressed: () => onSelect(
            'Expand your previous answer into an institutional quantitative analysis with financial statements, valuation multiples, and scenario tables.',
          ),
        ),
        UiMenuItem(
          label: 'Simple explanation (ELI5)',
          icon: Icons.lightbulb_outline_rounded,
          onPressed: () => onSelect(
            'Explain your previous answer simply so anyone can understand it, using clear analogies and a fact box.',
          ),
        ),
        UiMenuItem(
          label: 'Bull vs. Bear debate',
          icon: Icons.compare_arrows_rounded,
          onPressed: () => onSelect(
            'Reframe your previous answer as a structured Bull vs. Bear comparison and key risks checklist.',
          ),
        ),
      ],
      child: UiButton(
        label: 'Rewrite',
        icon: Icons.auto_fix_high_outlined,
        size: UiSize.xs,
        variant: UiVariant.ghost,
        onPressed: () {},
      ),
    );
  }
}

class _PerplexitySourcesCarousel extends StatelessWidget {
  const _PerplexitySourcesCarousel({
    required this.sources,
    this.onSourceTap,
    required this.onViewAll,
  });

  final List<PerplexitySource> sources;
  final ValueChanged<String>? onSourceTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<PerplexitySource> preview = sources.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xxs),
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.library_books_outlined,
                  size: context.sz(14),
                  color: theme.colors.foregroundSubtle,
                ),
                UiGap.h(theme.spacing.xs),
                Text(
                  'Sources',
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            UiButton(
              label: 'View all (${sources.length})',
              variant: UiVariant.link,
              size: UiSize.xs,
              onPressed: onViewAll,
            ),
          ],
        ),
        UiGap.v(theme.spacing.xxs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < preview.length; i++) ...<Widget>[
                SizedBox(
                  width: context.sz(200),
                  child: UiCard(
                    variant: UiCardVariant.outlined,
                    density: UiDensity.compact,
                    onTap: onSourceTap != null
                        ? () => onSourceTap!(preview[i].url)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            UiBadge(
                              label: '${preview[i].index}',
                              size: UiSize.sm,
                              variant: UiBadgeVariant.solid,
                              intent: UiIntent.primary,
                            ),
                            UiGap.h(theme.spacing.xs),
                            Expanded(
                              child: Text(
                                preview[i].domain.isNotEmpty
                                    ? preview[i].domain
                                    : preview[i].url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  color: theme.colors.foregroundSubtle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        UiGap.v(theme.spacing.xxs),
                        Text(
                          preview[i].title.isNotEmpty
                              ? preview[i].title
                              : (preview[i].domain.isNotEmpty
                                    ? preview[i].domain
                                    : preview[i].url),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.label.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < preview.length - 1 || sources.length > preview.length)
                  UiGap.h(theme.spacing.xs),
              ],
              if (sources.length > preview.length)
                SizedBox(
                  width: context.sz(148),
                  child: UiCard(
                    variant: UiCardVariant.subtle,
                    density: UiDensity.compact,
                    onTap: onViewAll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        UiBadge(
                          label: '+${sources.length - preview.length}',
                          size: UiSize.sm,
                          variant: UiBadgeVariant.soft,
                          intent: UiIntent.neutral,
                        ),
                        UiGap.v(theme.spacing.xxs),
                        Text(
                          'See all ${sources.length} sources',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.label.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerplexitySourcesListView extends StatelessWidget {
  const _PerplexitySourcesListView({required this.sources, this.onSourceTap});

  final List<PerplexitySource> sources;
  final ValueChanged<String>? onSourceTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xxs),
          children: <Widget>[
            Text(
              '${sources.length} cited ${sources.length == 1 ? 'source' : 'sources'}',
              style: context.uiText.label.copyWith(
                color: theme.colors.foregroundSubtle,
                fontWeight: FontWeight.w600,
              ),
            ),
            UiButton(
              label: 'Copy citations',
              icon: Icons.copy_all_outlined,
              size: UiSize.xs,
              variant: UiVariant.ghost,
              onPressed: () {
                final String formatted = sources
                    .map((s) => '[${s.index}] ${s.title} - ${s.url}')
                    .join('\n');
                Clipboard.setData(ClipboardData(text: formatted));
                UiToast.success(context, title: 'Citations copied');
              },
            ),
          ],
        ),
        UiGap.v(theme.spacing.xs),
        for (int i = 0; i < sources.length; i++) ...<Widget>[
          UiCard(
            variant: UiCardVariant.outlined,
            density: UiDensity.compact,
            onTap: onSourceTap != null
                ? () => onSourceTap!(sources[i].url)
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                UiBadge(
                  label: '${sources[i].index}',
                  size: UiSize.sm,
                  variant: UiBadgeVariant.soft,
                  intent: UiIntent.primary,
                ),
                UiGap.h(theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        sources[i].title.isNotEmpty
                            ? sources[i].title
                            : sources[i].domain,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.label.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      UiGap.v(theme.spacing.xxs),
                      Text(
                        <String>[
                          if (sources[i].publisher.isNotEmpty)
                            sources[i].publisher,
                          if (sources[i].domain.isNotEmpty) sources[i].domain,
                          if (sources[i].publishedAt.isNotEmpty)
                            sources[i].publishedAt,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundSubtle,
                        ),
                      ),
                      if (sources[i].snippet.isNotEmpty) ...<Widget>[
                        UiGap.v(theme.spacing.xxs),
                        Text(
                          sources[i].snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onSourceTap != null) ...<Widget>[
                  UiGap.h(theme.spacing.xs),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: context.sz(14),
                    color: theme.colors.foregroundSubtle,
                  ),
                ],
              ],
            ),
          ),
          if (i < sources.length - 1) UiGap.v(theme.spacing.xs),
        ],
      ],
    );
  }
}

class _PerplexityRelatedQuestions extends StatelessWidget {
  const _PerplexityRelatedQuestions({
    required this.questions,
    required this.onTap,
  });

  final List<String> questions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.only(top: context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const UiDivider(),
          UiGap.v(theme.spacing.xs),
          Row(
            children: <Widget>[
              Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              UiGap.h(theme.spacing.xs),
              Text(
                'Related',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          UiGap.v(theme.spacing.xs),
          for (int i = 0; i < questions.length; i++) ...<Widget>[
            UiCard(
              variant: UiCardVariant.outlined,
              density: UiDensity.compact,
              onTap: () => onTap(questions[i]),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      questions[i],
                      style: context.uiText.body.copyWith(
                        fontSize: context.fs(13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  UiGap.h(theme.spacing.xs),
                  Icon(
                    Icons.add_rounded,
                    size: context.sz(16),
                    color: theme.colors.primary,
                  ),
                ],
              ),
            ),
            if (i < questions.length - 1) UiGap.v(theme.spacing.xxs),
          ],
        ],
      ),
    );
  }
}
