import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../models/app_models_extra.dart';
import '../theme/app_tokens.dart';

/// One AI chat bubble. User messages align right on a filled surface,
/// assistant messages align left with sources and copy/retry affordances.
class AppAiMessageBubble extends StatelessWidget {
  const AppAiMessageBubble({
    super.key,
    required this.message,
    this.onCopy,
    this.onRetry,
    this.onShare,
    this.onSourceTap,
  });

  final AppAiMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final VoidCallback? onShare;
  final ValueChanged<String>? onSourceTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool mine = message.role == AppAiRole.user;

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

    final Widget bubble = Container(
      constraints: BoxConstraints(
        maxWidth: context.uiRes.isMobile ? double.infinity : context.sz(560),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.sm),
      ),
      decoration: BoxDecoration(
        color: mine ? theme.colors.primary : theme.colors.surfaceMuted,
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
          if (message.pending)
            const UiTypingIndicator(label: 'Thinking…')
          else if (mine)
            Text(
              message.body,
              style: context.uiText.body.copyWith(
                color: mine ? theme.colors.onPrimary : theme.colors.foreground,
              ),
            )
          else
            MarkdownBody(
              data: message.body,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: context.uiText.body.copyWith(
                      color: theme.colors.foreground,
                    ),
                    code: context.uiText.numeric.copyWith(
                      color: theme.colors.foreground,
                      backgroundColor: theme.colors.surface,
                    ),
                    blockquote: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
            ),
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
                    onTap: onSourceTap == null ? null : () => onSourceTap!(s),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  UiIconButton(
                    icon: Icons.copy_all_outlined,
                    size: UiSize.sm,
                    tooltip: 'Copy',
                    onPressed: onCopy,
                  ),
                  UiIconButton(
                    icon: Icons.refresh,
                    size: UiSize.sm,
                    tooltip: 'Regenerate',
                    onPressed: onRetry,
                  ),
                  if (onShare != null)
                    UiIconButton(
                      icon: Icons.send_outlined,
                      size: UiSize.sm,
                      tooltip: 'Share in message',
                      onPressed: onShare,
                    ),
                  if (message.sentAt != null)
                    Text(
                      AppTokens.relativeTime(message.sentAt!),
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
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
