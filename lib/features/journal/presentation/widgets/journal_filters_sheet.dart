import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/journal/data/repositories/journal_repository.dart';

/// Advanced journal filters. Sheet on phones, dialog on desktop.
///
/// Returns the edited [JournalQuery] via `Navigator.pop`, or `null` when the
/// trader dismisses without applying. The free-text search stays owned by the
/// toolbar, so it is carried through untouched.
Future<JournalQuery?> showJournalFiltersSheet(
  BuildContext context, {
  required JournalQuery query,
  required List<String> symbols,
  required List<String> strategies,
}) => UiDialog.show<JournalQuery>(
  context,
  child: _JournalFilters(
    query: query,
    symbols: symbols,
    strategies: strategies,
  ),
);

class _JournalFilters extends StatefulWidget {
  const _JournalFilters({
    required this.query,
    required this.symbols,
    required this.strategies,
  });

  final JournalQuery query;
  final List<String> symbols;
  final List<String> strategies;

  @override
  State<_JournalFilters> createState() => _JournalFiltersState();
}

class _JournalFiltersState extends State<_JournalFilters> {
  late AppSide? _side = widget.query.side;
  late String _symbol = widget.query.symbol ?? '';
  late String _strategy = widget.query.strategy ?? '';
  late DateTimeRange? _range =
      widget.query.from == null || widget.query.to == null
      ? null
      : DateTimeRange(start: widget.query.from!, end: widget.query.to!);

  void _apply() {
    Navigator.of(context).pop(
      JournalQuery(
        search: widget.query.search,
        outcome: widget.query.outcome,
        side: _side,
        symbol: _symbol.isEmpty ? null : _symbol,
        strategy: _strategy.isEmpty ? null : _strategy,
        from: _range?.start,
        to: _range?.end,
      ),
    );
  }

  void _reset() => Navigator.of(
    context,
  ).pop(JournalQuery(search: widget.query.search));

  @override
  Widget build(BuildContext context) {
    final double gap = context.ui.spacing.md;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Filter trades', style: context.uiText.heading),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(gap),
        UiField(
          label: 'Direction',
          child: UiToggleGroup<AppSide?>(
            options: <UiToggleOption<AppSide?>>[
              const UiToggleOption<AppSide?>(value: null, label: 'Both'),
              for (final AppSide side in AppSide.values)
                UiToggleOption<AppSide?>(
                  value: side,
                  label: AppTokens.sideLabel(side),
                  icon: AppTokens.sideIcon(side),
                  intent: AppTokens.sideIntent(side),
                ),
            ],
            value: _side,
            expand: true,
            onChanged: (AppSide? side) => setState(() => _side = side),
          ),
        ),
        UiGap.v(gap),
        UiField(
          label: 'Instrument',
          child: UiSelect<String>(
            options: <UiOption<String>>[
              const UiOption<String>(value: '', label: 'Any instrument'),
              for (final String symbol in widget.symbols)
                UiOption<String>(value: symbol, label: symbol),
            ],
            value: _symbol,
            searchable: true,
            leadingIcon: Icons.candlestick_chart_rounded,
            onChanged: (String value) => setState(() => _symbol = value),
          ),
        ),
        UiGap.v(gap),
        UiField(
          label: 'Strategy',
          child: UiSelect<String>(
            options: <UiOption<String>>[
              const UiOption<String>(value: '', label: 'Any strategy'),
              for (final String strategy in widget.strategies)
                UiOption<String>(value: strategy, label: strategy),
            ],
            value: _strategy,
            searchable: widget.strategies.length > 6,
            leadingIcon: Icons.account_tree_outlined,
            onChanged: (String value) => setState(() => _strategy = value),
          ),
        ),
        UiGap.v(gap),
        UiField(
          label: 'Opened between',
          helper: 'Leave empty to include every date',
          child: UiDatePicker(
            rangeMode: true,
            range: _range,
            hintText: 'Any date',
            lastDate: DateTime.now(),
            onRangeChanged: (DateTimeRange value) =>
                setState(() => _range = value),
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: UiButton(
                label: 'Reset',
                variant: UiVariant.ghost,
                expand: true,
                onPressed: _reset,
              ),
            ),
            UiGap.h(gap),
            Expanded(
              child: UiButton(
                label: 'Apply filters',
                leadingIcon: Icons.filter_alt_rounded,
                expand: true,
                onPressed: _apply,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
