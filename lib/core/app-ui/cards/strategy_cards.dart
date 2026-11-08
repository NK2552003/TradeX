import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Strategy note card: name, category, visibility, AI summary preview.
class AppStrategyCard extends StatelessWidget {
  const AppStrategyCard({
    super.key,
    required this.strategy,
    this.onTap,
    this.onFavorite,
    this.dense = false,
    this.selected = false,
    this.loading = false,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool dense;

  /// Highlights the card as the active/selected strategy.
  final bool selected;

  /// Renders the built-in [UiCard] skeleton instead of the summary body.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        selected: selected,
        loading: loading,
        title: strategy.name,
        subtitle: strategy.category,
        trailing: UiIconButton(
          icon: strategy.isFavorite ? Icons.star : Icons.star_border,
          onPressed: onFavorite,
          size: UiSize.sm,
          tooltip: 'Favorite',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (strategy.summary != null && !dense)
              Text(
                strategy.summary!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: strategy.isPublic ? 'Public' : 'Private',
                  icon: strategy.isPublic ? Icons.public : Icons.lock_outline,
                ),
                UiBadge(
                  label: 'v${strategy.versionCount}',
                  icon: Icons.history,
                ),
                UiBadge(
                  label: '${strategy.trades} trades',
                  intent: UiIntent.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-strategy performance: win rate ring, net P/L, average R, equity spark.
class AppStrategyPerformanceCard extends StatelessWidget {
  const AppStrategyPerformanceCard({
    super.key,
    required this.strategy,
    this.onTap,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color pl = AppTokens.pl(context, strategy.netPnl);
    return UiCard(
      onTap: onTap,
      title: strategy.name,
      subtitle: '${strategy.trades} trades',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool narrow = constraints.maxWidth < 260;
          final Widget circle = UiProgressCircle(
            value: (strategy.winRate / 100).clamp(0, 1),
            size: narrow ? 68 : 76,
            intent: strategy.winRate >= 50
                ? UiIntent.bullish
                : UiIntent.bearish,
            center: Text(
              '${strategy.winRate.toStringAsFixed(0)}%',
              style: context.uiText.bodyStrong,
            ),
          );

          final Widget details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppCountUp(
                value: strategy.netPnl,
                formatter: (num v) => AppTokens.signedMoney(v),
                style: context.uiText.heading.copyWith(color: pl),
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                'Avg ${AppTokens.rr(strategy.avgR)} per trade',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              if (strategy.equityCurve.isNotEmpty) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.xs)),
                UiSparkChart(
                  values: strategy.equityCurve,
                  color: pl,
                  filled: true,
                ),
              ],
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(child: circle),
                SizedBox(height: context.sp(theme.spacing.md)),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              circle,
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

/// One entry in a strategy's version history.
class AppVersionCard extends StatelessWidget {
  const AppVersionCard({
    super.key,
    required this.version,
    this.onRestore,
    this.onTap,
  });

  final AppStrategyVersion version;
  final VoidCallback? onRestore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Row(
        children: <Widget>[
          Container(
            width: context.sz(36),
            height: context.sz(36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Text('v${version.version}', style: context.uiText.caption),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  version.note ?? 'Saved revision',
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
                Text(
                  '${AppTokens.relativeTime(version.savedAt)}'
                  '${version.author == null ? '' : ' · ${version.author}'}',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          if (version.isCurrent)
            const UiBadge(label: 'Current', intent: UiIntent.bullish)
          else if (onRestore != null)
            UiButton(
              label: 'Restore',
              variant: UiVariant.outline,
              size: UiSize.sm,
              expandOnMobile: false,
              onPressed: onRestore,
            ),
        ],
      ),
    );
  }
}

/// Side-by-side comparison of two strategies.
class AppStrategyComparisonCard extends StatelessWidget {
  const AppStrategyComparisonCard({
    super.key,
    required this.a,
    required this.b,
  });

  final AppStrategy a;
  final AppStrategy b;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    Widget column(AppStrategy s, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: <Widget>[
        Text(
          s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.bodyStrong,
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          AppTokens.signedMoney(s.netPnl),
          style: context.uiText.heading.copyWith(
            color: AppTokens.pl(context, s.netPnl),
          ),
        ),
        Text(
          '${s.winRate.toStringAsFixed(0)}% win · ${AppTokens.rr(s.avgR)}',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
      ],
    );

    return UiCard(
      title: 'Head to head',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: column(a, CrossAxisAlignment.start)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                ),
                child: Text(
                  'vs',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
              ),
              Expanded(child: column(b, CrossAxisAlignment.end)),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCategoryBar(
            showLegend: false,
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: a.trades.toDouble(),
                label: a.name,
                color: theme.colors.primary,
              ),
              UiCategorySegment(
                value: b.trades.toDouble(),
                label: b.name,
                color: theme.colors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AI-generated plain-English summary of a strategy document.
class AppStrategySummaryCard extends StatelessWidget {
  const AppStrategySummaryCard({
    super.key,
    required this.summary,
    this.onRegenerate,
    this.loading = false,
  });

  final String summary;
  final VoidCallback? onRegenerate;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'AI summary',
      trailing: UiIconButton(
        icon: Icons.refresh,
        size: UiSize.sm,
        tooltip: 'Regenerate',
        onPressed: onRegenerate,
      ),
      accentColor: theme.colors.primary,
      child: loading
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                UiSkeleton(height: context.sz(12)),
                SizedBox(height: context.sp(theme.spacing.xs)),
                UiSkeleton(height: context.sz(12)),
                SizedBox(height: context.sp(theme.spacing.xs)),
                UiSkeleton(width: context.sz(180), height: context.sz(12)),
              ],
            )
          : Text(
              summary,
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
    );
  }
}

/// The canonical quantitative trading playbook card used across both the
/// Playbooks screen and the Writing Desk strategy section.
class PlaybookCard extends StatelessWidget {
  const PlaybookCard({
    super.key,
    required this.strategy,
    this.onTap,
    this.onToggleFavorite,
    this.onEdit,
    this.onFileTrade,
    this.linkedNoteCount,
    this.footerEngagement,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onFileTrade;
  final int? linkedNoteCount;
  final Widget? footerEngagement;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool untested = strategy.trades == 0;
    final int notes = linkedNoteCount ?? strategy.linkedNoteIds.length;
    final String excerpt = AppMarkdownStats.excerpt(
      strategy.content.trim().isEmpty
          ? (strategy.summary ?? '')
          : strategy.content,
      maxChars: 160,
    );
    final double effectiveWinRate = strategy.winRate > 1
        ? strategy.winRate
        : strategy.winRate * 100;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
            // ── Top Section: Header, Thesis, Metrics, Status Badges ──────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Header: Icon + Title + Favorite star
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                      decoration: BoxDecoration(
                        color: strategy.status.intent
                            .color(context)
                            .withValues(alpha: 0.12),
                        borderRadius: context.radius(theme.radii.sm),
                      ),
                      child: Icon(
                        strategy.status == AppStrategyStatus.draft
                            ? Icons.edit_note_rounded
                            : Icons.play_arrow_rounded,
                        size: context.sz(18),
                        color: strategy.status.intent.color(context),
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Expanded(
                      child: Text(
                        strategy.name,
                        style: context.uiText.heading.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onToggleFavorite != null)
                      UiIconButton(
                        icon: strategy.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: UiSize.xs,
                        intent: strategy.isFavorite
                            ? UiIntent.warning
                            : UiIntent.neutral,
                        tooltip: strategy.isFavorite
                            ? 'Remove from favorites'
                            : 'Mark favorite',
                        onPressed: onToggleFavorite,
                      ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),

                // Thesis description
                if (excerpt.isNotEmpty) ...<Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'Thesis: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.foreground,
                          ),
                        ),
                        TextSpan(
                          text: excerpt,
                          style: TextStyle(color: colors.foregroundMuted),
                        ),
                      ],
                    ),
                    style: context.uiText.caption.copyWith(height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                ],

                // Metrics Highlight Ribbon or Prompt Box
                if (!untested)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.sm),
                      vertical: context.sp(theme.spacing.xs),
                    ),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: context.radius(theme.radii.sm),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: context.sp(theme.spacing.sm),
                      runSpacing: context.sp(theme.spacing.xs),
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              strategy.status == AppStrategyStatus.testing
                                  ? 'SIMULATED P&L'
                                  : 'REALIZED P&L',
                              style: context.uiText.caption.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colors.foregroundSubtle,
                              ),
                            ),
                            Text(
                              AppTokens.signedMoney(
                                strategy.netPnl,
                                decimals: 0,
                              ),
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTokens.pl(context, strategy.netPnl),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'WIN RATE',
                              style: context.uiText.caption.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colors.foregroundSubtle,
                              ),
                            ),
                            Text(
                              '${effectiveWinRate.toStringAsFixed(0)}% (${strategy.trades} trades)',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.foreground,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              'AVG R',
                              style: context.uiText.caption.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colors.foregroundSubtle,
                              ),
                            ),
                            Text(
                              AppTokens.rr(strategy.avgR),
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTokens.pl(context, strategy.avgR),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else if (strategy.status == AppStrategyStatus.draft)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.sm),
                      vertical: context.sp(theme.spacing.xs),
                    ),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: context.radius(theme.radii.sm),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Missing Exit Rule Criteria',
                                style: context.uiText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.foreground,
                                ),
                              ),
                              Text(
                                'Add invalidation & trailing logic',
                                style: context.uiText.caption.copyWith(
                                  fontSize: 10,
                                  color: colors.foregroundSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        UiButton(
                          label: 'Continue →',
                          variant: UiVariant.ghost,
                          size: UiSize.xs,
                          intent: UiIntent.success,
                          onPressed: onEdit ?? onTap,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.sm),
                      vertical: context.sp(theme.spacing.xs),
                    ),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: context.radius(theme.radii.sm),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Untested · No trades filed yet',
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundSubtle,
                            ),
                          ),
                        ),
                        UiButton(
                          label: 'File Trade →',
                          variant: UiVariant.ghost,
                          size: UiSize.xs,
                          intent: UiIntent.primary,
                          onPressed: onFileTrade ?? onTap,
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: context.sp(theme.spacing.sm)),

                // Status Pills & Metadata Badges
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: <Widget>[
                    UiBadge(
                      label: strategy.status.label,
                      size: UiSize.xs,
                      intent: strategy.status.intent,
                      variant: UiBadgeVariant.soft,
                    ),
                    if (notes > 0)
                      UiBadge(
                        label: '$notes note${notes == 1 ? '' : 's'}',
                        size: UiSize.xs,
                        icon: Icons.link_rounded,
                        variant: UiBadgeVariant.outline,
                      ),
                    if (strategy.versionCount > 1)
                      UiBadge(
                        label: '${strategy.versionCount} revisions',
                        size: UiSize.xs,
                        icon: Icons.history_rounded,
                        variant: UiBadgeVariant.outline,
                      ),
                    if (strategy.checklistTotal > 0)
                      UiBadge(
                        label: '${strategy.checklistTotal} rules',
                        size: UiSize.xs,
                        icon: Icons.checklist_rounded,
                        variant: UiBadgeVariant.outline,
                      ),
                  ],
                ),
              ],
            ),

            // ── Bottom Section: Divider Line, Tags, and Arrow ─────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (footerEngagement != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  footerEngagement!,
                ],
                SizedBox(height: context.sp(theme.spacing.sm)),
                // Divider
                Container(
                  height: 1,
                  color: colors.border.withValues(alpha: 0.6),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        children: <Widget>[
                          for (final String t in strategy.tags.take(3))
                            Text(
                              t.startsWith('#') ? t : '#$t',
                              style: context.uiText.caption.copyWith(
                                fontSize: 11,
                                color: colors.foregroundSubtle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: colors.foregroundSubtle,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
  }
}
