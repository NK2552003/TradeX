import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_instrument_view.dart';
import 'market_layout.dart';

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

  @override
  Widget build(BuildContext context) {
    final screens = widget.snapshot.screeners;
    if (screens.isEmpty) {
      return const UiEmptyState(title: 'No screeners in this snapshot');
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
    final selector = UiAccordion(
      allowMultiple: true,
      items: [
        for (final group in groups.entries)
          UiAccordionItem(
            title: group.key,
            initiallyOpen: group.key == _group(selected),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final key in group.value)
                  UiButton(
                    label: marketFieldLabel(key),
                    variant: key == selected ? UiVariant.soft : UiVariant.ghost,
                    onPressed: () => setState(() => _category = key),
                  ),
              ],
            ),
          ),
      ],
    );
    final table = UiCard(
      title: marketFieldLabel(selected),
      trailing: UiBadge(
        label:
            '${quotes.length} exported${total != null ? ' / $total matches' : ''}',
      ),
      child: UiTable<MarketInstrument>(
        key: ValueKey(selected),
        rows: quotes,
        pageSize: 30,
        stackOnMobile: true,
        emptyLabel: 'No matching instruments',
        onRowTap: widget.onInstrument,
        expandableWhen: (_) => true,
        expandedBuilder: (c, q) => MarketDataFields(data: q.raw),
        columns: [
          UiTableColumn(
            header: 'Symbol',
            cell: (c, q) => Text(q.symbol, style: c.uiText.bodyStrong),
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
            cell: (c, q) => Text('${q.currency} ${q.price.toStringAsFixed(2)}'),
            compare: (a, b) => a.price.compareTo(b.price),
          ),
          UiTableColumn(
            header: 'Change %',
            numeric: true,
            cell: (c, q) => Text(
              '${q.changePercent >= 0 ? '+' : ''}${q.changePercent.toStringAsFixed(2)}%',
              style: c.uiText.body.copyWith(
                color: q.changePercent >= 0
                    ? c.ui.colors.success
                    : c.ui.colors.danger,
              ),
            ),
            compare: (a, b) => a.changePercent.compareTo(b.changePercent),
          ),
          if (quotes.any((q) => q.raw.containsKey('rsi_14')))
            UiTableColumn(
              header: 'RSI (14)',
              numeric: true,
              cell: (c, q) => Text('${q.raw['rsi_14'] ?? '—'}'),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MarketPageHeading(
          title: 'Market screeners',
          description:
              'Discover opportunities across equities, funds, crypto and global indices.',
        ),
        MarketTwoPanel(
          secondaryFirstOnMobile: true,
          primary: table,
          secondary: UiCard(
            title: 'Screen library',
            subtitle: '${screens.length} curated screens',
            child: LayoutBuilder(
              builder: (context, box) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UiSelect<String>(
                    value: selected,
                    options: [
                      for (final key in screens.keys)
                        UiOption(label: marketFieldLabel(key), value: key),
                    ],
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  UiGap.v(context.ui.spacing.md),
                  UiStatStrip(
                    stats: [
                      UiStat(
                        label: 'In this snapshot',
                        value: '${quotes.length}',
                      ),
                      UiStat(
                        label: 'Provider matches',
                        value: '${total ?? '—'}',
                      ),
                    ],
                  ),
                  UiGap.v(context.ui.spacing.md),
                  UiCard(
                    title: 'Browse categories',
                    collapsible: true,
                    initiallyExpanded: !context.uiRes.isMobile,
                    variant: UiCardVariant.ghost,
                    padding: EdgeInsets.zero,
                    child: selector,
                  ),
                  UiGap.v(context.ui.spacing.md),
                  Text(
                    'Open a symbol for its research dossier. Expand a result to inspect all available fields.',
                    style: context.uiText.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
