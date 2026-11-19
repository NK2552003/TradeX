import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'market_instrument_data.dart';

enum _HolderGroup {
  institutional('Institutions'),
  mutualFunds('Mutual funds');

  const _HolderGroup(this.label);
  final String label;
}

double? _ownershipFraction(Object? raw) {
  final text = instrumentText(raw);
  final value = text?.endsWith('%') == true
      ? (instrumentNumber(text!.substring(0, text.length - 1)) ?? -100) / 100
      : instrumentNumber(raw);
  return value != null && value >= 0 && value <= 1 ? value : null;
}

class _HolderPosition {
  _HolderPosition(InstrumentRow row)
    : name = instrumentText(row['Holder'] ?? row['holder_name']),
      ownership = _ownershipFraction(
        row['pctHeld'] ?? row['pct_out'] ?? row['% Out'],
      ),
      shares = instrumentNumber(row['Shares'] ?? row['shares']),
      value = instrumentNumber(row['Value'] ?? row['value']),
      reported = row['Date Reported'] ?? row['date_reported'];

  final String? name;
  final double? ownership, shares, value;
  final Object? reported;
}

class InstrumentOwnership extends StatefulWidget {
  const InstrumentOwnership({super.key, required this.data});
  final InstrumentDetailData data;

  @override
  State<InstrumentOwnership> createState() => _InstrumentOwnershipState();
}

class _InstrumentOwnershipState extends State<InstrumentOwnership> {
  static const _pageSize = 6;
  _HolderGroup? _group;
  int _page = 0;

  List<_HolderPosition> _positions(Object? raw) =>
      instrumentRows(
          raw,
        ).map(_HolderPosition.new).where((row) => row.name != null).toList()
        ..sort((a, b) => (b.ownership ?? -1).compareTo(a.ownership ?? -1));

  @override
  Widget build(BuildContext context) {
    final holders = widget.data.holders;
    final majors = instrumentRows(holders['major_holders']);
    final groups = {
      _HolderGroup.institutional: _positions(holders['institutional_holders']),
      _HolderGroup.mutualFunds: _positions(
        holders['mutual_fund_holders'] ?? holders['mutualfund_holders'],
      ),
    };
    groups.removeWhere((_, positions) => positions.isEmpty);
    final group = groups.containsKey(_group) ? _group : groups.keys.firstOrNull;
    final rows = groups[group] ?? const <_HolderPosition>[];
    final pages = (rows.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);

    if (rows.isEmpty && majors.isEmpty) {
      return const UiCard(
        title: 'Ownership & holders',
        child: UiEmptyState(
          icon: Icons.people_outline,
          title: 'No ownership data',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (majors.isNotEmpty) ...[
          _MajorOwners(holders: majors),
          UiGap.v(context.ui.spacing.md),
        ],
        if (group != null) ...[
          UiCard(
            title: 'Ownership & holders',
            subtitle:
                '${rows.length} disclosed ${rows.length == 1 ? 'position' : 'positions'}',
            leading: const Icon(Icons.people_outline),
            child: UiToggleGroup<_HolderGroup>(
              size: UiSize.sm,
              value: group,
              options: [
                for (final item in groups.keys)
                  UiOption(value: item, label: item.label),
              ],
              onChanged: (value) => setState(() {
                _group = value;
                _page = 0;
              }),
            ),
          ),
          UiGap.v(context.ui.spacing.md),
          if (rows.any((row) => (row.ownership ?? 0) > 0)) ...[
            _OwnershipMap(positions: rows),
            UiGap.v(context.ui.spacing.md),
          ],
          UiCardGrid(
            minTileWidth: context.sz(270),
            largeColumns: 3,
            equalHeight: true,
            children: [
              for (final row in rows.skip(page * _pageSize).take(_pageSize))
                _HolderCard(position: row, data: widget.data),
            ],
          ),
          if (pages > 1) ...[
            UiGap.v(context.ui.spacing.md),
            UiPagination(
              page: page,
              pageCount: pages,
              onPageChanged: (value) => setState(() => _page = value),
            ),
          ],
        ],
      ],
    );
  }
}

class _MajorOwners extends StatelessWidget {
  const _MajorOwners({required this.holders});
  final List<InstrumentRow> holders;

  @override
  Widget build(BuildContext context) {
    final stats = <UiStat>[];
    for (final row in holders) {
      final label = instrumentText(
        row['Breakdown'] ?? row['index'] ?? row['holder_name'],
      );
      final value = row['Value'] ?? row['pct_out'];
      if (label == null || value == null) continue;
      final (title, isPercentage) = switch (label
          .replaceAll(RegExp(r'[^a-zA-Z]'), '')
          .toLowerCase()) {
        'insiderspercentheld' => ('Insider ownership', true),
        'institutionspercentheld' => ('Institutional ownership', true),
        'institutionsfloatpercentheld' => (
          'Institutional share of float',
          true,
        ),
        'institutionscount' => ('Reporting institutions', false),
        _ => (label, label.contains('%')),
      };
      stats.add(
        UiStat(
          label: title,
          value: isPercentage
              ? instrumentPercent(_ownershipFraction(value), scale: 100)
              : instrumentCount(value),
        ),
      );
    }
    if (stats.isEmpty) return const SizedBox.shrink();
    return UiCard(
      title: 'Major ownership',
      leading: const Icon(Icons.account_balance_outlined),
      child: UiStatStrip(stats: stats, minCellWidth: 142),
    );
  }
}

class _OwnershipMap extends StatelessWidget {
  const _OwnershipMap({required this.positions});
  final List<_HolderPosition> positions;

  @override
  Widget build(BuildContext context) {
    final reported = positions
        .where((row) => (row.ownership ?? 0) > 0)
        .take(5)
        .toList();
    final total = reported.fold<double>(0, (sum, row) => sum + row.ownership!);
    final theme = context.ui;
    return UiCard(
      title: 'Ownership map',
      subtitle:
          'Largest reported positions as a percentage of outstanding shares',
      leading: const Icon(Icons.donut_large_outlined),
      child: total <= 1
          ? UiDonutChart(
              size: 170,
              showLegend: true,
              centerLabel: instrumentPercent(total, scale: 100),
              slices: [
                for (var i = 0; i < reported.length; i++)
                  UiDonutSlice(
                    label: reported[i].name!,
                    value: reported[i].ownership!,
                    color: theme.colors.series[i % theme.colors.series.length],
                  ),
                if (total < 1)
                  UiDonutSlice(
                    label: 'Other shares',
                    value: 1 - total,
                    color: theme.colors.foregroundSubtle,
                  ),
              ],
            )
          : UiBarList(
              items: [
                for (var i = 0; i < reported.length; i++)
                  UiBarListItem(
                    label: reported[i].name!,
                    value: reported[i].ownership!,
                    displayValue: instrumentPercent(
                      reported[i].ownership,
                      scale: 100,
                    ),
                    color: theme.colors.series[i % theme.colors.series.length],
                  ),
              ],
            ),
    );
  }
}

class _HolderCard extends StatelessWidget {
  const _HolderCard({required this.position, required this.data});
  final _HolderPosition position;
  final InstrumentDetailData data;

  @override
  Widget build(BuildContext context) {
    return UiCard(
      title: position.name!,
      subtitle: position.reported == null
          ? null
          : 'Reported ${instrumentDate(position.reported)}',
      leading: const Icon(Icons.account_balance_outlined),
      child: UiStatStrip(
        minCellWidth: 115,
        stats: [
          if (position.ownership != null)
            UiStat(
              label: 'Ownership',
              value: instrumentPercent(position.ownership, scale: 100),
              intent: UiIntent.primary,
            ),
          if (position.shares != null)
            UiStat(label: 'Shares', value: instrumentCount(position.shares)),
          if (position.value != null)
            UiStat(
              label: 'Position value',
              value: data.formatCapital(position.value),
              colSpan: 2,
            ),
        ],
      ),
    );
  }
}
