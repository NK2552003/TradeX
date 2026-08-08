import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Journal cards — every card here is pure presentation and composes UiCard.

/// A single logged trade: ticker, side, P/L, R-multiple, tags.
class AppTradeCard extends StatelessWidget {
  const AppTradeCard({
    super.key,
    required this.trade,
    this.onTap,
    this.dense = false,
    this.trailing,
  });

  final AppTrade trade;
  final VoidCallback? onTap;
  final bool dense;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color plColor = AppTokens.pl(context, trade.pnl);

    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        accentColor: plColor,
        padding: dense
            ? EdgeInsets.all(context.sp(theme.spacing.md))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          trade.ticker,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.subheading
                              .copyWith(color: theme.colors.foreground),
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      UiBadge(
                        label: AppTokens.sideLabel(trade.side),
                        intent: AppTokens.sideIntent(trade.side),
                        icon: AppTokens.sideIcon(trade.side),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: AppCountUp(
                    value: trade.pnl,
                    formatter: (num v) => AppTokens.signedMoney(v),
                    style: context.uiText.title.copyWith(color: plColor),
                  ),
                ),
                UiBadge.delta(trade.pnlPercent),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Wrap(
              spacing: context.sp(theme.spacing.sm),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                _meta(context, 'Entry', AppTokens.money(trade.entry)),
                if (trade.exit != null)
                  _meta(context, 'Exit', AppTokens.money(trade.exit!)),
                if (trade.rMultiple != null)
                  _meta(context, 'R', AppTokens.rr(trade.rMultiple!)),
                _meta(context, 'Size', trade.size.toStringAsFixed(2)),
              ],
            ),
            if (!dense && trade.tags.isNotEmpty) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  if (trade.strategy != null)
                    UiBadge(
                      label: trade.strategy!,
                      intent: UiIntent.primary,
                      icon: Icons.auto_graph,
                    ),
                  ...trade.tags.map((String t) => UiBadge(label: '#$t')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$label ',
            style: context.uiText.caption
                .copyWith(color: context.uiColors.foregroundSubtle),
          ),
          Text(value, style: context.uiText.numeric),
        ],
      );
}

/// Compact P/L summary for a group of trades (day, week, ticker).
class AppPnlSummaryCard extends StatelessWidget {
  const AppPnlSummaryCard({
    super.key,
    required this.title,
    required this.pnl,
    required this.trades,
    this.winRate,
    this.spark = const <double>[],
    this.onTap,
  });

  final String title;
  final double pnl;
  final int trades;
  final double? winRate;
  final List<double> spark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color plColor = AppTokens.pl(context, pnl);
    return UiCard(
      onTap: onTap,
      title: title,
      subtitle: '$trades trades',
      trailing: winRate == null
          ? null
          : UiBadge(
              label: '${winRate!.toStringAsFixed(0)}% win',
              intent: winRate! >= 50 ? UiIntent.bullish : UiIntent.bearish,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppCountUp(
            value: pnl,
            formatter: (num v) => AppTokens.signedMoney(v),
            style: context.uiText.title.copyWith(color: plColor),
          ),
          if (spark.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiSparkChart(values: spark, color: plColor, filled: true),
          ],
        ],
      ),
    );
  }
}

/// Free-form note / lesson learned tied to a trade or tag.
class AppLessonCard extends StatelessWidget {
  const AppLessonCard({
    super.key,
    required this.title,
    required this.body,
    this.tags = const <String>[],
    this.intent = UiIntent.info,
    this.onTap,
  });

  final String title;
  final String body;
  final List<String> tags;
  final UiIntent intent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      accentColor: intent.color(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.lightbulb_outline,
                size: context.sz(theme.sizes.iconMd),
                color: intent.color(context),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.subheading,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            body,
            style: context.uiText.body
                .copyWith(color: theme.colors.foregroundMuted),
          ),
          if (tags.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              children: tags.map((String t) => UiBadge(label: '#$t')).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Drop-zone card for chart screenshots that AI parses into trade fields.
class AppScreenshotImportCard extends StatelessWidget {
  const AppScreenshotImportCard({
    super.key,
    this.imageUrl,
    this.onPick,
    this.parsing = false,
    this.parsedSummary,
  });

  final String? imageUrl;
  final VoidCallback? onPick;
  final bool parsing;
  final String? parsedSummary;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onPick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: AnimatedContainer(
              duration: theme.motion.normal,
              decoration: BoxDecoration(
                borderRadius: context.radius(theme.radii.lg),
                color: theme.colors.surfaceMuted,
                border: Border.all(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
                image: imageUrl == null
                    ? null
                    : DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      ),
              ),
              alignment: Alignment.center,
              child: imageUrl != null
                  ? null
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: context.sz(theme.sizes.iconLg),
                          color: theme.colors.foregroundMuted,
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        Text(
                          'Attach a chart screenshot',
                          style: context.uiText.label
                              .copyWith(color: theme.colors.foregroundMuted),
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          if (parsing)
            Row(
              children: <Widget>[
                SizedBox(
                  width: context.sz(theme.sizes.iconSm),
                  height: context.sz(theme.sizes.iconSm),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colors.primary,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Text('Reading your chart…', style: context.uiText.label),
              ],
            )
          else if (parsedSummary != null)
            UiCallout(
              title: 'Auto-filled from screenshot',
              message: parsedSummary,
              intent: UiIntent.bullish,
              icon: Icons.auto_awesome,
            ),
        ],
      ),
    );
  }
}

/// Pre-trade / post-trade checklist card.
class AppChecklistCard extends StatelessWidget {
  const AppChecklistCard({
    super.key,
    required this.title,
    required this.items,
    this.onToggle,
  });

  final String title;
  final List<AppChecklistItem> items;
  final ValueChanged<AppChecklistItem>? onToggle;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int done = items.where((AppChecklistItem i) => i.done).length;
    return UiCard(
      title: title,
      trailing: UiBadge(
        label: '$done/${items.length}',
        intent: done == items.length ? UiIntent.bullish : UiIntent.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UiProgressBar(
            value: items.isEmpty ? 0 : done / items.length,
            intent: UiIntent.primary,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          ...AppMotion.stagger(
            items
                .map(
                  (AppChecklistItem item) => Padding(
                    padding:
                        EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                    child: UiCheckbox(
                      value: item.done,
                      label: item.label,
                      description: item.description,
                      onChanged: onToggle == null
                          ? null
                          : (_) => onToggle!.call(item),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Psychology / discipline rating for an entry.
class AppPsychologyCard extends StatelessWidget {
  const AppPsychologyCard({
    super.key,
    required this.score,
    this.note,
    this.max = 5,
    this.onTap,
  });

  final int score;
  final String? note;
  final int max;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiIntent intent = score >= max * 0.7
        ? UiIntent.bullish
        : (score >= max * 0.4 ? UiIntent.warning : UiIntent.bearish);
    return UiCard(
      onTap: onTap,
      title: 'Mindset',
      trailing: UiBadge(label: '$score / $max', intent: intent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: List<Widget>.generate(
              max,
              (int i) => Padding(
                padding: EdgeInsets.only(right: context.sp(theme.spacing.xs)),
                child: Icon(
                  i < score ? Icons.circle : Icons.circle_outlined,
                  size: context.sz(theme.sizes.iconMd),
                  color: i < score
                      ? intent.color(context)
                      : theme.colors.borderStrong,
                ),
              ),
            ),
          ),
          if (note != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Text(
              note!,
              style: context.uiText.body
                  .copyWith(color: theme.colors.foregroundMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton placeholder matching [AppTradeCard]'s shape.
class AppTradeCardSkeleton extends StatelessWidget {
  const AppTradeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UiSkeleton(width: context.sz(120), height: context.sz(16)),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSkeleton(width: context.sz(160), height: context.sz(28)),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSkeleton(height: context.sz(12)),
        ],
      ),
    );
  }
}
