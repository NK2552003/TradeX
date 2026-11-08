import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../models/app_models_extra.dart';
import '../theme/app_tokens.dart';

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
    this.actionsBuilder,
    this.minimal = false,
  });

  final AppAiMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final VoidCallback? onShare;
  final ValueChanged<String>? onSourceTap;
  final void Function(AppLinkRef ref)? onOpenRef;

  /// Optional extra actions rendered beneath a settled (non-pending) answer —
  /// e.g. "Save note", "Log trade". Returns null/empty to add nothing, so
  /// existing call sites that omit it are unaffected.
  final List<Widget>? Function(AppAiMessage message)? actionsBuilder;
  final bool minimal;

  @override
  State<AppAiMessageBubble> createState() => _AppAiMessageBubbleState();
}

class _AppAiMessageBubbleState extends State<AppAiMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _streamController;
  int _fromChars = 0;
  int _toChars = 0;
  bool _streamedInSession = false;

  bool get _isAssistant => widget.message.role == AppAiRole.assistant;

  @override
  void initState() {
    super.initState();
    _streamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    final int len = widget.message.body.length;
    if (_isAssistant && widget.message.pending) {
      _streamedInSession = true;
      _fromChars = 0;
      _toChars = len;
      if (len > 0) {
        _animateTo(len);
      }
    } else {
      _fromChars = len;
      _toChars = len;
      _streamController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AppAiMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String newBody = widget.message.body;
    final String oldBody = oldWidget.message.body;

    if (widget.message.id != oldWidget.message.id) {
      _streamedInSession = _isAssistant && widget.message.pending;
      if (_streamedInSession) {
        _fromChars = 0;
        _toChars = newBody.length;
        if (newBody.isNotEmpty) {
          _animateTo(newBody.length);
        } else {
          _streamController.value = 1.0;
        }
      } else {
        _fromChars = newBody.length;
        _toChars = newBody.length;
        _streamController.value = 1.0;
      }
      return;
    }

    if (!_isAssistant) {
      _fromChars = newBody.length;
      _toChars = newBody.length;
      _streamController.value = 1.0;
      return;
    }

    if (widget.message.pending || oldWidget.message.pending) {
      _streamedInSession = true;
    }

    if (_streamedInSession && newBody.length > oldBody.length) {
      _animateTo(newBody.length);
    } else if (newBody != oldBody) {
      _fromChars = newBody.length;
      _toChars = newBody.length;
      _streamController.value = 1.0;
    }
  }

  void _animateTo(int targetLength) {
    final int current = _currentRevealedLength(widget.message.body);
    _fromChars = math.min(current, targetLength);
    _toChars = targetLength;
    final int delta = math.max(1, _toChars - _fromChars);
    final int ms = (delta * 7).clamp(180, 680);
    _streamController.duration = Duration(milliseconds: ms);
    _streamController.forward(from: 0.0);
  }

  int _currentRevealedLength(String fullText) {
    if (fullText.isEmpty) return 0;
    if (!_streamedInSession || !_streamController.isAnimating) {
      return fullText.length;
    }
    final double t = Curves.easeOutCubic.transform(_streamController.value);
    final int raw = (_fromChars + (_toChars - _fromChars) * t).round();
    return raw.clamp(0, fullText.length);
  }

  String _visibleAssistantBody(String fullText) {
    final int count = _currentRevealedLength(fullText);
    if (count >= fullText.length) return fullText;
    if (count <= 0) return '';
    return fullText.substring(0, count);
  }

  @override
  void dispose() {
    _streamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final AppAiMessage message = widget.message;
    final bool mine = message.role == AppAiRole.user;
    final bool isAnimatingStream =
        _isAssistant && (message.pending || _streamController.isAnimating);
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
        ? _visibleAssistantBody(message.body)
        : message.body;

    final Widget bubble = Container(
      constraints: BoxConstraints(
        maxWidth: context.uiRes.isMobile
            ? double.infinity
            : context.sz(widget.minimal ? 780 : 600),
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
            const UiTypingIndicator(label: 'Thinking…')
          else if (mine)
            _buildUserMessageText(context, theme)
          else ...<Widget>[
            RichMarkdownPreview(
              data: displayedBody,
              emptyPlaceholder: '',
              selectable: !isAnimatingStream,
              onOpenRef: widget.onOpenRef,
              imageResolver: (BuildContext ctx, Uri uri) => ClipRRect(
                borderRadius: ctx.radius(ctx.ui.radii.md),
                child: UiRemoteImage(
                  url: uri.toString(),
                  fit: BoxFit.cover,
                ),
              ),
              onTapLink: (String text, String? href, String title) {
                if (href != null &&
                    (href.startsWith('https://') ||
                        href.startsWith('http://'))) {
                  widget.onSourceTap?.call(href);
                }
              },
            ),
            if (isAnimatingStream && displayedBody.isNotEmpty) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              const UiTypingIndicator(),
            ],
          ],
          if (message.sources.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                for (final String s in message.sources)
                  UiBadge(
                    label: s,
                    icon: Icons.link,
                    intent: UiIntent.info,
                    onTap: widget.onSourceTap == null
                        ? null
                        : () => widget.onSourceTap!(s),
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
          if (!mine && !message.pending)
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
                        if (i > 0 || widget.onCopy != null || widget.onRetry != null || message.sentAt != null)
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                        extraActions[i],
                      ],
                    ],
                  ],
                ),
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
