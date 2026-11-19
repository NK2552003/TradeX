import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'market_index_item.dart';

/// Responsive market group surface used for indices, FX, commodities and rates.
class MarketIndexGroupCard extends StatelessWidget {
  const MarketIndexGroupCard({
    super.key,
    required this.title,
    required this.items,
    this.loading = false,
    this.onItemTap,
  });

  final String title;
  final List<MarketIndexItem> items;
  final bool loading;
  final ValueChanged<MarketIndexItem>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final int liveCount = items
        .where((MarketIndexItem item) => item.hasQuote && item.isLive)
        .length;
    final int quotedCount = items
        .where((MarketIndexItem item) => item.hasQuote)
        .length;
    final bool isUpdating = quotedCount == 0 && loading;

    return UiCard(
      key: ValueKey<String>('market-overview-group-$title'),
      title: title,
      subtitle: isUpdating
          ? 'Updating latest quotes'
          : quotedCount == 0
          ? 'Quotes unavailable'
          : '$quotedCount instruments · Latest available',
      trailing: isUpdating
          ? const UiBadge(
              label: 'Updating',
              intent: UiIntent.info,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
            )
          : quotedCount > 0
          ? UiBadge.status(
              liveCount > 0 ? '$liveCount live' : 'Latest',
              intent: liveCount > 0 ? UiIntent.success : UiIntent.neutral,
              size: UiSize.xs,
              pulse: liveCount > 0,
            )
          : null,
      density: UiDensity.compact,
      semanticLabel: '$title market instruments',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0) UiDivider(),
            _MarketIndexRow(
              key: ValueKey<String>(
                'market-overview-row-$title-${items[index].symbol}',
              ),
              item: items[index],
              loading: loading,
              onTap: onItemTap == null || !items[index].hasQuote
                  ? null
                  : () => onItemTap!(items[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarketIndexRow extends StatelessWidget {
  const _MarketIndexRow({
    super.key,
    required this.item,
    required this.loading,
    this.onTap,
  });

  final MarketIndexItem item;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return UiCard(
      variant: UiCardVariant.ghost,
      borderless: true,
      density: UiDensity.compact,
      padding: EdgeInsets.symmetric(
        vertical: context.sp(theme.spacing.sm),
        horizontal: context.sp(theme.spacing.xxs),
      ),
      onTap: onTap,
      semanticLabel: item.hasQuote
          ? '${item.name}, ${_formatPrice(item.price)}, ${AppTokens.signedPercent(item.changePercent)}'
          : '${item.name}, quote ${loading ? 'updating' : 'unavailable'}',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool showSpark = constraints.maxWidth >= context.sz(330);
          final bool showSymbol = constraints.maxWidth >= context.sz(285);

          return Row(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showSymbol) ...<Widget>[
                      UiGap.v(theme.spacing.xxs),
                      Text(
                        item.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showSpark && item.spark.length > 1) ...<Widget>[
                UiGap.h(theme.spacing.sm),
                SizedBox(
                  width: context.sz(54),
                  height: context.sz(24),
                  child: UiSparkChart(
                    values: item.spark,
                    color: item.isPositive
                        ? theme.colors.bullish
                        : theme.colors.bearish,
                  ),
                ),
              ],
              UiGap.h(theme.spacing.sm),
              SizedBox(
                width: context.sz(76),
                child: item.hasQuote
                    ? Text(
                        _formatPrice(item.price),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.bodyStrong.copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      )
                    : loading
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: UiSkeleton(
                          width: context.sz(58),
                          height: context.sz(14),
                        ),
                      )
                    : const Text('—', textAlign: TextAlign.right),
              ),
              UiGap.h(theme.spacing.sm),
              SizedBox(
                width: context.sz(76),
                child: item.hasQuote
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: UiBadge.delta(
                          item.changePercent,
                          size: UiSize.xs,
                          showIcon: false,
                        ),
                      )
                    : loading
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: UiSkeleton(
                          width: context.sz(52),
                          height: context.sz(20),
                        ),
                      )
                    : const Text('—', textAlign: TextAlign.right),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatPrice(double price) =>
      uiGrouped(price, decimals: price < 10 ? 4 : 2);
}
