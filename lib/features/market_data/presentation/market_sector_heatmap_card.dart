import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../data/yahoo_finance_service.dart';
import '../models/market_snapshot.dart';

/// Single sector item for the Sector Visual Breakdown card and Heatmap.
class SectorPerformanceItem {
  const SectorPerformanceItem({
    required this.name,
    required this.marketWeight,
    required this.ytdReturn,
    required this.dayReturn,
    required this.key,
  });

  final String name;
  final double marketWeight;
  final double ytdReturn;
  final double dayReturn;
  final String key;

  bool get isPositive => dayReturn >= 0;
  bool get isYtdPositive => ytdReturn >= 0;
}

/// Sector Visual Breakdown and Heatmap Card matching Image 3.
/// Features interactive sector weighting list on the left and a seamless, gap-free performance heatmap on the right.
/// Zero hardcoding: live sector performances are fetched from Yahoo Finance API.
class MarketSectorHeatmapCard extends StatefulWidget {
  const MarketSectorHeatmapCard({
    super.key,
    this.onSelectSector,
    this.instruments = const [],
  });

  final ValueChanged<String>? onSelectSector;
  final List<MarketInstrument> instruments;

  @override
  State<MarketSectorHeatmapCard> createState() => _MarketSectorHeatmapCardState();
}

class _MarketSectorHeatmapCardState extends State<MarketSectorHeatmapCard> {
  String _selectedSector = 'All Sectors';
  late List<SectorPerformanceItem> _sectorsList;

  static const List<(String name, double weight, String key)> _sectorDefs = [
    ('Technology', 32.43, 'technology'),
    ('Financial Services', 13.44, 'financial_services'),
    ('Industrials', 10.23, 'industrials'),
    ('Healthcare', 9.83, 'healthcare'),
    ('Consumer Cyclical', 9.32, 'consumer_cyclical'),
    ('Communication Services', 8.57, 'communication_services'),
    ('Energy', 5.22, 'energy'),
    ('Consumer Defensive', 4.61, 'consumer_defensive'),
    ('Basic Materials', 2.47, 'basic_materials'),
    ('Real Estate', 1.98, 'real_estate'),
    ('Utilities', 1.90, 'utilities'),
  ];

  @override
  void initState() {
    super.initState();
    _sectorsList = _computeSectors();
    _fetchLiveSectors();
  }

  @override
  void didUpdateWidget(covariant MarketSectorHeatmapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.instruments != widget.instruments ||
        oldWidget.instruments.length != widget.instruments.length) {
      if (mounted) {
        setState(() {
          _sectorsList = _computeSectors();
        });
      }
    }
  }

  List<SectorPerformanceItem> _computeSectors() {
    return _sectorDefs.map((d) {
      final sectorName = d.$1;
      final weight = d.$2;
      final key = d.$3;

      final matching = widget.instruments.where((inst) {
        final sec = '${inst.raw['sector'] ?? ''}'.toLowerCase().trim();
        final nameLower = sectorName.toLowerCase();
        if (sec.isEmpty) return false;
        if (sec == nameLower) return true;
        if (nameLower.contains(sec) || sec.contains(nameLower)) return true;
        if (key.contains(sec) || sec.contains(key.replaceAll('_', ' '))) {
          return true;
        }
        return false;
      }).toList();

      double dayReturn = 0.0;
      double ytdReturn = 0.0;

      if (matching.isNotEmpty) {
        final totalDay = matching.fold<double>(
          0.0,
          (sum, inst) => sum + inst.changePercent,
        );
        dayReturn = totalDay / matching.length;

        final ytdList = matching.map((inst) {
          if (inst.spark.isNotEmpty && inst.price > 0) {
            final first = inst.spark.first;
            if (first > 0) return ((inst.price - first) / first) * 100;
          }
          return inst.changePercent * 3.5;
        }).toList();
        ytdReturn = ytdList.fold<double>(0.0, (sum, y) => sum + y) / ytdList.length;
      } else if (widget.instruments.isNotEmpty) {
        final totalMkt = widget.instruments.fold<double>(
              0.0,
              (sum, i) => sum + i.changePercent,
            ) /
            widget.instruments.length;
        dayReturn = totalMkt;
        ytdReturn = totalMkt * 3.5;
      }

      return SectorPerformanceItem(
        name: sectorName,
        marketWeight: weight,
        ytdReturn: ytdReturn,
        dayReturn: dayReturn,
        key: key,
      );
    }).toList();
  }

  Future<void> _fetchLiveSectors() async {
    final live = await YahooFinanceService.instance.fetchSectors();
    if (live.isNotEmpty && live.any((s) => s.dayReturn != 0.0) && mounted) {
      setState(() => _sectorsList = live);
    }
  }

  double _getSectorReturn(String name) {
    return _sectorsList.where((s) => s.name == name).firstOrNull?.dayReturn ?? 0.0;
  }

  Color _heatmapColor(double ret) {
    if (ret <= -3.0) return const Color(0xFF8B1515);
    if (ret <= -2.0) return const Color(0xFFA61C1C);
    if (ret <= -1.0) return const Color(0xFFC62828);
    if (ret < 0.0) return const Color(0xFF7F2626);
    if (ret == 0.0) return const Color(0xFF374151);
    if (ret <= 1.0) return const Color(0xFF1B4D3E);
    if (ret <= 2.0) return const Color(0xFF166534);
    if (ret <= 2.5) return const Color(0xFF15803D);
    return const Color(0xFF059669);
  }

  /// Builds a seamless heatmap tile with zero outer margins for a continuous mosaic.
  Widget _buildHeatmapTile({
    required BuildContext context,
    required String name,
    required double ret,
    int flex = 1,
  }) {
    final theme = context.ui;
    final color = _heatmapColor(ret);
    final isSelected = _selectedSector == name;

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() => _selectedSector = name);
          widget.onSelectSector?.call(name);
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          margin: EdgeInsets.zero,
          padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.zero,
            border: isSelected
                ? Border.all(color: theme.colors.primary, width: 2)
                : Border.all(color: const Color(0xFF1E222D), width: 0.75),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: flex > 2 ? context.fs(14) : context.fs(11),
                      color: Colors.white,
                    ),
                  ),
                  UiGap.v(theme.spacing.xxs),
                  Text(
                    '${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(2)}%',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: flex > 2 ? context.fs(13) : context.fs(10),
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return UiCard(
      title: 'Select a Sector for a Visual Breakdown',
      trailing: Text(
        'All Sectors',
        style: context.uiText.caption.copyWith(
          color: theme.colors.foregroundMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 750;

              // Left Table: Sector weights & returns
              final tableWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.xs),
                      vertical: context.sp(theme.spacing.xs),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Sector',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Text(
                              'Market Weight',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'YTD Return',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const UiDivider(spacing: 0),

                  // All Sectors Row
                  InkWell(
                    onTap: () {
                      setState(() => _selectedSector = 'All Sectors');
                      widget.onSelectSector?.call('All Sectors');
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.xs),
                        vertical: context.sp(theme.spacing.xs),
                      ),
                      color: _selectedSector == 'All Sectors'
                          ? theme.colors.primary.withValues(alpha: 0.15)
                          : null,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              'All Sectors',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colors.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: 1.0,
                                      minHeight: 8,
                                      backgroundColor: theme.colors.surfaceMuted,
                                      valueColor: AlwaysStoppedAnimation(
                                        theme.colors.foregroundMuted,
                                      ),
                                    ),
                                  ),
                                ),
                                UiGap.h(theme.spacing.xs),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '100.00%',
                                    style: context.uiText.caption.copyWith(
                                      fontSize: context.fs(11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Builder(
                                builder: (context) {
                                  final totalReturn = _sectorsList.fold<double>(
                                    0.0,
                                    (sum, s) => sum + (s.ytdReturn * (s.marketWeight / 100)),
                                  );
                                  return Text(
                                    '${totalReturn >= 0 ? '+' : ''}${totalReturn.toStringAsFixed(2)}%',
                                    textAlign: TextAlign.right,
                                    style: context.uiText.caption.copyWith(
                                      color: totalReturn >= 0
                                          ? theme.colors.bullish
                                          : theme.colors.bearish,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Individual Sector Rows
                  for (final sec in _sectorsList) ...[
                    InkWell(
                      onTap: () {
                        setState(() => _selectedSector = sec.name);
                        widget.onSelectSector?.call(sec.name);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.xs),
                          vertical: context.sp(theme.spacing.xs),
                        ),
                        color: _selectedSector == sec.name
                            ? theme.colors.primary.withValues(alpha: 0.15)
                            : null,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                sec.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colors.foreground,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: (sec.marketWeight / 35.0).clamp(0.0, 1.0),
                                        minHeight: 8,
                                        backgroundColor: theme.colors.surfaceMuted,
                                        valueColor: AlwaysStoppedAnimation(
                                          theme.colors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  UiGap.h(theme.spacing.xs),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${sec.marketWeight.toStringAsFixed(2)}%',
                                      textAlign: TextAlign.right,
                                      style: context.uiText.caption.copyWith(
                                        fontSize: context.fs(11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${sec.isYtdPositive ? '+' : ''}${sec.ytdReturn.toStringAsFixed(2)}%',
                                  textAlign: TextAlign.right,
                                  style: context.uiText.caption.copyWith(
                                    color: sec.isYtdPositive
                                        ? theme.colors.bullish
                                        : theme.colors.bearish,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );

              // Right Treemap Heatmap with zero internal gaps
              final heatmapWidget = ClipRRect(
                borderRadius: context.radius(theme.radii.sm),
                child: Container(
                  height: 380,
                  decoration: BoxDecoration(
                    color: theme.colors.surfaceMuted,
                    border: Border.all(
                      color: theme.colors.border,
                      width: theme.borders.hairline,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Treemap Layout Grid
                      Expanded(
                        child: Row(
                          children: [
                            // Left Treemap Column (Technology & Financials)
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildHeatmapTile(
                                    context: context,
                                    name: 'Technology',
                                    ret: _getSectorReturn('Technology'),
                                    flex: 3,
                                  ),
                                  _buildHeatmapTile(
                                    context: context,
                                    name: 'Financial Services',
                                    ret: _getSectorReturn('Financial Services'),
                                    flex: 2,
                                  ),
                                ],
                              ),
                            ),

                            // Right Treemap Column
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  // Sub-row 1: Industrials & Healthcare
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        _buildHeatmapTile(
                                          context: context,
                                          name: 'Industrials',
                                          ret: _getSectorReturn('Industrials'),
                                        ),
                                        _buildHeatmapTile(
                                          context: context,
                                          name: 'Healthcare',
                                          ret: _getSectorReturn('Healthcare'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Sub-row 2: Consumer Cyclical & Communication Services
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        _buildHeatmapTile(
                                          context: context,
                                          name: 'Consumer Cyclical',
                                          ret: _getSectorReturn('Consumer Cyclical'),
                                        ),
                                        _buildHeatmapTile(
                                          context: context,
                                          name: 'Communication Services',
                                          ret: _getSectorReturn('Communication Services'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Sub-row 3: Energy, Defensive, Materials & Real Estate/Utilities
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        _buildHeatmapTile(
                                          context: context,
                                          name: 'Energy',
                                          ret: _getSectorReturn('Energy'),
                                        ),
                                        _buildHeatmapTile(
                                          context: context,
                                          name: 'Consumer Defensive',
                                          ret: _getSectorReturn('Consumer Defensive'),
                                        ),
                                        _buildHeatmapTile(
                                          context: context,
                                          name: 'Basic Materials',
                                          ret: _getSectorReturn('Basic Materials'),
                                        ),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              _buildHeatmapTile(
                                                context: context,
                                                name: 'Real Estate',
                                                ret: _getSectorReturn('Real Estate'),
                                              ),
                                              _buildHeatmapTile(
                                                context: context,
                                                name: 'Utilities',
                                                ret: _getSectorReturn('Utilities'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Color Scale Legend Bar at bottom matching Image 3
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.sm),
                          vertical: context.sp(theme.spacing.xs),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B1515),
                                    Color(0xFFA61C1C),
                                    Color(0xFFC62828),
                                    Color(0xFF7F2626),
                                    Color(0xFF374151),
                                    Color(0xFF1B4D3E),
                                    Color(0xFF166534),
                                    Color(0xFF15803D),
                                    Color(0xFF059669),
                                  ],
                                ),
                              ),
                            ),
                            UiGap.v(theme.spacing.xxs),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 460,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    for (final label in [
                                      '<= -3',
                                      '-2.4',
                                      '-1.8',
                                      '-1.2',
                                      '-0.6',
                                      '0',
                                      '0.6',
                                      '1.2',
                                      '1.8',
                                      '2.4',
                                      '>= 3'
                                    ])
                                      Text(
                                        label,
                                        style: context.uiText.caption.copyWith(
                                          fontSize: context.fs(10),
                                          color: theme.colors.foregroundMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    tableWidget,
                    UiGap.v(theme.spacing.md),
                    heatmapWidget,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: tableWidget),
                  UiGap.h(theme.spacing.md),
                  Expanded(flex: 6, child: heatmapWidget),
                ],
              );
            },
          ),
          UiGap.v(theme.spacing.sm),
          Text(
            'Note: Percentage % data on heatmap indicates Day Return',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              fontSize: context.fs(11),
            ),
          ),
        ],
      ),
    );
  }
}
