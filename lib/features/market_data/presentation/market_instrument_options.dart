import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'market_instrument_data.dart';
import 'market_instrument_data_fields.dart';
import 'market_visuals.dart';

enum _OptionSide {
  calls('Calls'),
  puts('Puts');

  const _OptionSide(this.label);
  final String label;
}

class InstrumentOptions extends StatefulWidget {
  const InstrumentOptions({super.key, required this.data});
  final InstrumentDetailData data;

  @override
  State<InstrumentOptions> createState() => _InstrumentOptionsState();
}

class _InstrumentOptionsState extends State<InstrumentOptions> {
  String? _expiry;
  _OptionSide _side = _OptionSide.calls;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final expiries = data.chains.keys.where((key) {
      final sides = instrumentMap(data.chains[key]);
      return _OptionSide.values.any(
        (side) => instrumentRows(sides[side.name]).isNotEmpty,
      );
    }).toList()..sort();
    if (expiries.isEmpty) {
      return const UiCard(
        title: 'Options chains',
        child: UiEmptyState(
          icon: Icons.account_tree_outlined,
          title: 'No options available',
          message: 'This snapshot has no option contracts for the ticker.',
        ),
      );
    }

    final expiry = expiries.contains(_expiry) ? _expiry! : expiries.first;
    final sides = instrumentMap(data.chains[expiry]);
    final rows = instrumentRows(sides[_side.name])
      ..sort(
        (a, b) => (instrumentNumber(a['strike']) ?? double.infinity).compareTo(
          instrumentNumber(b['strike']) ?? double.infinity,
        ),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarketOptionsInterest(
          chains: {for (final date in expiries) date: data.chains[date]},
        ),
        UiGap.v(context.ui.spacing.md),
        UiCard(
          title: 'Options chains',
          leading: const Icon(Icons.account_tree_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: context.sp(context.ui.spacing.md),
                runSpacing: context.sp(context.ui.spacing.sm),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  UiSelect<String>(
                    label: 'Expiration',
                    size: UiSize.sm,
                    value: expiry,
                    options: [
                      for (final date in expiries)
                        UiOption(value: date, label: instrumentDate(date)),
                    ],
                    onChanged: (date) => setState(() => _expiry = date),
                  ),
                  UiToggleGroup<_OptionSide>(
                    size: UiSize.sm,
                    value: _side,
                    options: [
                      for (final side in _OptionSide.values)
                        UiOption(value: side, label: side.label),
                    ],
                    onChanged: (side) => setState(() => _side = side),
                  ),
                ],
              ),
              UiGap.v(context.ui.spacing.md),
              if (rows.isEmpty)
                UiEmptyState(
                  title: 'No ${_side.name} for this expiration',
                  compact: true,
                )
              else
                _OptionsTable(
                  key: ValueKey((expiry, _side)),
                  rows: rows,
                  data: data,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionsTable extends StatelessWidget {
  const _OptionsTable({super.key, required this.rows, required this.data});
  final List<InstrumentRow> rows;
  final InstrumentDetailData data;

  @override
  Widget build(BuildContext context) {
    String price(Object? value) => data.formatPrice(instrumentNumber(value));
    bool hasValues(String key) =>
        rows.any((row) => instrumentNumber(row[key]) != null);
    return UiTable<InstrumentRow>(
      rows: rows,
      pageSize: 8,
      stackOnMobile: true,
      expandableWhen: (_) => true,
      expandedBuilder: (context, row) => MarketDataFields(data: row),
      columns: [
        _column('strike', 'Strike', price),
        if (hasValues('lastPrice')) _column('lastPrice', 'Last', price),
        if (hasValues('bid')) _column('bid', 'Bid', price),
        if (hasValues('ask')) _column('ask', 'Ask', price),
        if (hasValues('impliedVolatility'))
          _column(
            'impliedVolatility',
            'IV',
            (value) => instrumentPercent(value, scale: 100),
          ),
        if (hasValues('openInterest'))
          _column('openInterest', 'Open interest', instrumentCount),
        if (hasValues('volume')) _column('volume', 'Volume', instrumentCount),
      ],
    );
  }

  UiTableColumn<InstrumentRow> _column(
    String key,
    String label,
    String Function(Object?) format,
  ) => UiTableColumn(
    id: key,
    header: label,
    numeric: true,
    valueGetter: (row) => format(row[key]),
    sortValue: (row) => instrumentNumber(row[key]) ?? double.negativeInfinity,
  );
}
