import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_instrument_view.dart';
import 'market_layout.dart';
import 'market_visuals.dart';

class MarketScreenersView extends StatefulWidget {
  const MarketScreenersView({
    super.key,
    required this.snapshot,
    required this.onInstrument,
  });
  final MarketSnapshot snapshot;
  final ValueChanged<MarketInstrument> onInstrument;
  @override
  State<MarketScreenersView> createState() => _MarketScreenersViewState();
}

class _MarketScreenersViewState extends State<MarketScreenersView> {
  String _category = 'most_active';
  String _group(String key) {
    if (key.startsWith('Indices')) return 'Global indices';
    if (key.contains('sector')) return 'Sectors';
    if (key.contains('crypto')) return 'Crypto';
    if (key.contains('etf') || key.contains('mutual')) return 'Funds';
    if (key.contains('oversold') || key.contains('overbought')) {
      return 'Technical screens';
    }
    return 'Equities';
  }

  IconData _groupIcon(String group) => switch (group) {
    'Global indices' => Icons.public_outlined,
    'Sectors' => Icons.business_outlined,
    'Crypto' => Icons.currency_bitcoin,
    'Funds' => Icons.account_balance_outlined,
    'Technical screens' => Icons.trending_up_outlined,
    _ => Icons.show_chart_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final screens = widget.snapshot.screeners;
    if (screens.isEmpty) {
      return const UiEmptyState(
        icon: Icons.filter_alt_outlined,
        title: 'No screeners in this snapshot',
        message: 'Screener data is unavailable for this market snapshot.',
      );
    }
    final selected = screens.containsKey(_category)
        ? _category
        : screens.keys.first;
    final quotes = screens[selected]!;
    final payload = widget.snapshot.screenerPayloads[selected];
    final total = payload is Map ? payload['total'] : null;
    final groups = <String, List<String>>{};
    for (final key in screens.keys) {
      (groups[_group(key)] ??= []).add(key);
    }

    final selector = UiCard(
      title: 'Screen library',
      subtitle: '${screens.length} curated screens',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Select Dropdown
          UiSelect<String>(
            value: selected,
            options: [
              for (final key in screens.keys)
                UiOption(label: marketFieldLabel(key), value: key),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          UiGap.v(context.ui.spacing.md),
          const UiDivider(),
          UiGap.v(context.ui.spacing.sm),

          // Grouped Category Browser
          UiAccordion(
            allowMultiple: true,
            items: [
              for (final group in groups.entries)
                UiAccordionItem(
                  title: group.key,
                  leading: Icon(_groupIcon(group.key), size: context.sz(20)),
                  trailing: UiBadge(
                    label: '${group.value.length}',
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                  ),
                  initiallyOpen: group.key == _group(selected),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final key in group.value)
                        UiButton(
                          label: marketFieldLabel(key),
                          variant: key == selected
                              ? UiVariant.soft
                              : UiVariant.ghost,
                          intent: key == selected
                              ? UiIntent.primary
                              : UiIntent.neutral,
                          onPressed: () => setState(() => _category = key),
                          trailing: UiBadge(
                            label: '${screens[key]?.length ?? 0}',
                            variant: UiBadgeVariant.outline,
                            size: UiSize.xs,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          UiGap.v(context.ui.spacing.md),

          // Screen Stats
          const UiDivider(),
          UiGap.v(context.ui.spacing.sm),
          UiStatStrip(
            stats: [
              UiStat(label: 'In snapshot', value: '${quotes.length}'),
              UiStat(label: 'Total matches', value: '${total ?? '—'}'),
            ],
          ),
        ],
      ),
    );

    final table = UiCard(
      accentColor: context.ui.colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Screener Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
                decoration: BoxDecoration(
                  color: context.ui.colors.primary.withValues(alpha: 0.12),
                  borderRadius: context.radius(context.ui.radii.md),
                ),
                child: Icon(
                  Icons.filter_alt,
                  color: context.ui.colors.primary,
                  size: context.sz(20),
                ),
              ),
              UiGap.h(context.ui.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marketFieldLabel(selected),
                      style: context.uiText.title,
                    ),
                    Text(
                      '${quotes.length} results${total != null ? ' of $total total matches' : ''}',
                      style: context.uiText.caption.copyWith(
                        color: context.ui.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          UiGap.v(context.ui.spacing.md),
          const UiDivider(),
          UiGap.v(context.ui.spacing.sm),

          MarketChangeDistribution(instruments: quotes),
          UiGap.v(context.ui.spacing.md),

          // Results Table
          UiTable<MarketInstrument>(
            key: ValueKey(selected),
            rows: quotes,
            pageSize: 30,
            stackOnMobile: true,
            density: UiDensity.comfortable,
            emptyLabel: 'No matching instruments',
            onRowTap: widget.onInstrument,
            expandableWhen: (_) => true,
            expandedBuilder: (c, q) => Padding(
              padding: EdgeInsets.all(c.sp(c.ui.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Raw data fields', style: c.uiText.bodyStrong),
                  UiGap.v(c.ui.spacing.sm),
                  MarketDataFields(data: q.raw),
                ],
              ),
            ),
            columns: [
              UiTableColumn(
                header: 'Symbol',
                cell: (c, q) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.symbol, style: c.uiText.bodyStrong),
                    if (q.market.isNotEmpty)
                      UiBadge(
                        label: q.market,
                        variant: UiBadgeVariant.outline,
                        size: UiSize.xs,
                      ),
                  ],
                ),
                compare: (a, b) => a.symbol.compareTo(b.symbol),
              ),
              UiTableColumn(
                header: 'Company',
                flex: 2,
                cell: (c, q) =>
                    Text(q.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              UiTableColumn(
                header: 'Price',
                numeric: true,
                cell: (c, q) => Text(
                  '${q.currency} ${q.price.toStringAsFixed(2)}',
                  style: c.uiText.bodyStrong,
                ),
                compare: (a, b) => a.price.compareTo(b.price),
              ),
              UiTableColumn(
                header: 'Change %',
                numeric: true,
                cell: (c, q) => UiBadge(
                  label: AppTokens.signedPercent(q.changePercent),
                  intent: AppTokens.plIntent(q.changePercent),
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                compare: (a, b) => a.changePercent.compareTo(b.changePercent),
              ),
              if (quotes.any((q) => q.raw.containsKey('rsi_14')))
                UiTableColumn(
                  header: 'RSI (14)',
                  numeric: true,
                  cell: (c, q) =>
                      Text('${q.raw['rsi_14'] ?? '—'}', style: c.uiText.body),
                ),
            ],
          ),
        ],
      ),
    );

    return MarketTwoPanel(
      secondaryFirstOnMobile: true,
      primary: table,
      secondary: selector,
    );
  }
}
