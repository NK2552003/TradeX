import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import 'research/research_metrics.dart';

import 'perplexity_domain_cards.dart';

Widget? _tickerBadge(String? rawTicker, PerplexityOpenRefCallback? onOpenRef) {
  if (rawTicker == null || rawTicker.trim().isEmpty) return null;
  final String clean = PerplexityCardDataUtils.cleanTicker(rawTicker);
  if (clean.isEmpty) return null;
  return UiBadge(
    label: '\$$clean',
    icon: Icons.candlestick_chart_outlined,
    intent: UiIntent.primary,
    variant: UiBadgeVariant.soft,
    size: UiSize.xs,
    onTap: onOpenRef == null
        ? null
        : () => onOpenRef(
            AppLinkRef(kind: AppLinkKind.ticker, id: clean, title: clean),
          ),
  );
}

Widget _bulletListSection(
  BuildContext context, {
  required String title,
  required List<String> items,
  required UiIntent intent,
  IconData icon = Icons.circle,
}) {
  final UiTheme theme = context.ui;
  final Color color = intent.color(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        title,
        style: context.uiText.label.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      UiGap.v(theme.spacing.xs),
      for (final String item in items)
        Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: context.sp(4)),
                child: Icon(icon, size: context.sz(10), color: color),
              ),
              UiGap.h(theme.spacing.xs),
              Expanded(child: Text(item, style: context.uiText.body)),
            ],
          ),
        ),
    ],
  );
}

/// Perplexity Finance Earnings & Quarterly Beat/Miss Card.
class PerplexityEarningsCard extends StatelessWidget {
  const PerplexityEarningsCard({
    super.key,
    required this.data,
    this.onOpenRef,
    this.onPromptTap,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;
  final PerplexityPromptCallback? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? ticker = PerplexityCardDataUtils.str(data, [
      'ticker',
      'symbol',
    ]);
    final String? company = PerplexityCardDataUtils.str(data, [
      'company',
      'name',
      'title',
    ]);
    final String? quarter = PerplexityCardDataUtils.str(data, [
      'quarter',
      'period',
      'fiscalPeriod',
    ]);
    final String? date = PerplexityCardDataUtils.str(data, [
      'date',
      'reportDate',
      'reportedAt',
    ]);
    final String? status = PerplexityCardDataUtils.str(data, [
      'status',
      'verdict',
      'result',
    ]);
    final UiIntent statusIntent = PerplexityCardDataUtils.parseIntent(status);

    final String title = <String>[
      company ??
          (ticker != null
              ? '\$${PerplexityCardDataUtils.cleanTicker(ticker)}'
              : 'Earnings'),
      ?quarter,
    ].join(' · ');

    final List<UiStat> stats = <UiStat>[];
    void addMetric(
      String label,
      String? actual,
      String? est,
      String? surprise,
    ) {
      if (actual == null && est == null) return;
      final String value = actual ?? est!;
      final String hint = <String>[
        if (actual != null && est != null) 'Est: $est',
        ?surprise,
      ].join(' · ');
      stats.add(
        UiStat(
          label: label,
          value: value,
          hint: hint.isEmpty ? null : hint,
          intent: surprise != null
              ? PerplexityCardDataUtils.parseIntent(
                  surprise,
                  isPositive: !surprise.trimLeft().startsWith('-'),
                )
              : UiIntent.neutral,
        ),
      );
    }

    addMetric(
      'EPS',
      PerplexityCardDataUtils.str(data, ['epsActual', 'eps']),
      PerplexityCardDataUtils.str(data, ['epsEstimate', 'epsEst']),
      PerplexityCardDataUtils.str(data, ['epsSurprise', 'epsBeat']),
    );
    addMetric(
      'Revenue',
      PerplexityCardDataUtils.str(data, ['revenueActual', 'revenue']),
      PerplexityCardDataUtils.str(data, ['revenueEstimate', 'revenueEst']),
      PerplexityCardDataUtils.str(data, ['revenueSurprise', 'revenueGrowth']),
    );
    final String? reaction = PerplexityCardDataUtils.str(data, [
      'priceReaction',
      'reaction',
      'postEarningsMove',
    ]);
    if (reaction != null) {
      stats.add(
        UiStat(
          label: 'Price Reaction',
          value: reaction,
          intent: PerplexityCardDataUtils.parseIntent(
            reaction,
            isPositive: !reaction.trimLeft().startsWith('-'),
          ),
        ),
      );
    }
    final String? nextGuide = PerplexityCardDataUtils.str(data, [
      'nextQuarterGuide',
      'guidance',
    ]);
    if (nextGuide != null) {
      stats.add(
        UiStat(label: 'Guidance', value: nextGuide, intent: UiIntent.info),
      );
    }

    final List<String> highlights = PerplexityCardDataUtils.strList(data, [
      'highlights',
      'takeaways',
      'callHighlights',
    ]);
    final List<String> concerns = PerplexityCardDataUtils.strList(data, [
      'concerns',
      'risks',
      'headwinds',
    ]);
    final List<Map<String, dynamic>> history = PerplexityCardDataUtils.mapList(
      data,
      ['history', 'quarters', 'beatStreak'],
    );
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'guidanceSummary',
      'overview',
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: statusIntent.color(context),
        title: title,
        subtitle: date,
        leading: Icon(
          Icons.assessment_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: statusIntent.color(context),
        ),
        trailing: Wrap(
          spacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            if (_tickerBadge(ticker, onOpenRef) case final Widget badge) badge,
            if (status != null)
              UiBadge(
                label: status.toUpperCase(),
                intent: statusIntent,
                size: UiSize.xs,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (stats.isNotEmpty) ...<Widget>[
              ResearchMetrics(stats: stats),
              UiGap.v(theme.spacing.md),
            ],
            if (summary != null) ...<Widget>[
              Text(summary, style: context.uiText.body.copyWith(height: 1.6)),
              UiGap.v(theme.spacing.sm),
            ],
            if (highlights.isNotEmpty || concerns.isNotEmpty) ...<Widget>[
              LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  final bool twoCol =
                      highlights.isNotEmpty &&
                      concerns.isNotEmpty &&
                      constraints.maxWidth >= ctx.sz(540);
                  if (!twoCol) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (highlights.isNotEmpty)
                          _bulletListSection(
                            ctx,
                            title: 'Call Highlights',
                            items: highlights,
                            intent: UiIntent.bullish,
                            icon: Icons.check_circle_outline,
                          ),
                        if (highlights.isNotEmpty && concerns.isNotEmpty)
                          UiGap.v(theme.spacing.sm),
                        if (concerns.isNotEmpty)
                          _bulletListSection(
                            ctx,
                            title: 'Watchouts & Risks',
                            items: concerns,
                            intent: UiIntent.bearish,
                            icon: Icons.warning_amber_rounded,
                          ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _bulletListSection(
                          ctx,
                          title: 'Call Highlights',
                          items: highlights,
                          intent: UiIntent.bullish,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                      UiGap.h(theme.spacing.md),
                      Expanded(
                        child: _bulletListSection(
                          ctx,
                          title: 'Watchouts & Risks',
                          items: concerns,
                          intent: UiIntent.bearish,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                    ],
                  );
                },
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (history.isNotEmpty)
              UiTable<Map<String, dynamic>>(
                stackOnMobile: true,
                pageSize: 8,
                density: UiDensity.compact,
                rows: history,
                columns: <UiTableColumn<Map<String, dynamic>>>[
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Quarter',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, ['quarter', 'period']) ??
                          '—',
                      style: ctx.uiText.bodyStrong,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'EPS Act / Est',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      [
                        PerplexityCardDataUtils.str(r, [
                              'epsActual',
                              'actual',
                            ]) ??
                            '—',
                        if (PerplexityCardDataUtils.str(r, [
                              'epsEstimate',
                              'est',
                            ]) !=
                            null)
                          PerplexityCardDataUtils.str(r, [
                            'epsEstimate',
                            'est',
                          ])!,
                      ].join(' vs '),
                      style: ctx.uiText.body,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Surprise',
                    cell: (BuildContext ctx, Map<String, dynamic> r) {
                      final String s =
                          PerplexityCardDataUtils.str(r, [
                            'surprise',
                            'beat',
                          ]) ??
                          '—';
                      return UiBadge(
                        label: s,
                        intent: PerplexityCardDataUtils.parseIntent(
                          s,
                          isPositive: !s.trimLeft().startsWith('-'),
                        ),
                        size: UiSize.xs,
                      );
                    },
                  ),
                ],
              ),
            if (onPromptTap != null &&
                ticker != null &&
                ticker.trim().isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  UiButton(
                    label: 'Analyze full financials',
                    icon: Icons.table_chart_outlined,
                    size: UiSize.xs,
                    variant: UiVariant.outline,
                    onPressed: () => onPromptTap!(
                      'Show full income statement, cash flow, and margin trends for \$${PerplexityCardDataUtils.cleanTicker(ticker)}.',
                    ),
                  ),
                  UiButton(
                    label: 'Post-earnings ratings',
                    icon: Icons.star_outline_rounded,
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                    onPressed: () => onPromptTap!(
                      'Show updated analyst ratings and price targets after \$${PerplexityCardDataUtils.cleanTicker(ticker)} earnings.',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Perplexity Finance Financial Statements & Valuation Card.
class PerplexityFinancialsCard extends StatelessWidget {
  const PerplexityFinancialsCard({
    super.key,
    required this.data,
    this.onOpenRef,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? ticker = PerplexityCardDataUtils.str(data, [
      'ticker',
      'symbol',
    ]);
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ?? 'Financial Statements';
    final String? subtitle = PerplexityCardDataUtils.str(data, [
      'statement',
      'period',
      'currency',
      'subtitle',
    ]);
    final List<Map<String, dynamic>> rawMetrics =
        PerplexityCardDataUtils.mapList(data, [
          'metrics',
          'highlights',
          'kpis',
        ]);
    final List<UiStat> stats = <UiStat>[
      for (final Map<String, dynamic> m in rawMetrics)
        if ((PerplexityCardDataUtils.str(m, ['label', 'name']) ?? '')
                .isNotEmpty &&
            (PerplexityCardDataUtils.str(m, ['value', 'val']) ?? '').isNotEmpty)
          UiStat(
            label: PerplexityCardDataUtils.str(m, ['label', 'name'])!,
            value: PerplexityCardDataUtils.str(m, ['value', 'val'])!,
            hint: PerplexityCardDataUtils.str(m, ['yoy', 'change', 'hint']),
            intent: PerplexityCardDataUtils.parseIntent(
              PerplexityCardDataUtils.str(m, ['intent', 'yoy', 'change']),
            ),
          ),
    ];

    final List<Map<String, dynamic>> lineItems =
        PerplexityCardDataUtils.mapList(data, [
          'items',
          'lineItems',
          'breakdown',
          if (data['periods'] == null && data['columns'] == null) 'rows',
        ]);
    final List<UiKeyValueRow> kvRows = <UiKeyValueRow>[
      for (final Map<String, dynamic> row in lineItems)
        if ((PerplexityCardDataUtils.str(row, [
                      'label',
                      'name',
                      'lineItem',
                      'item',
                    ]) ??
                    '')
                .isNotEmpty &&
            (PerplexityCardDataUtils.str(row, ['value', 'amount', 'ttm']) ?? '')
                .isNotEmpty)
          UiKeyValueRow(
            label: PerplexityCardDataUtils.str(row, [
              'label',
              'name',
              'lineItem',
              'item',
            ])!,
            value: PerplexityCardDataUtils.str(row, [
              'value',
              'amount',
              'ttm',
            ])!,
            detail: PerplexityCardDataUtils.str(row, ['detail', 'note']),
            trailing: PerplexityCardDataUtils.str(row, [
              'yoy',
              'margin',
              'change',
            ]),
            emphasis: row['emphasis'] == true || row['total'] == true,
            share: PerplexityCardDataUtils.numField(row, ['share']),
            intent: PerplexityCardDataUtils.parseIntent(
              PerplexityCardDataUtils.str(row, ['intent', 'yoy', 'change']),
            ),
          ),
    ];

    final List<dynamic> rawPeriods =
        (data['periods'] ?? data['columns']) is List
        ? (data['periods'] ?? data['columns']) as List<dynamic>
        : const <dynamic>[];
    final List<String> periods = rawPeriods
        .map((dynamic e) => e.toString().trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    final List<Map<String, dynamic>> tableRows =
        PerplexityCardDataUtils.mapList(data, ['rows', 'table', 'series']);
    final List<Map<String, dynamic>> multiples =
        PerplexityCardDataUtils.mapList(data, ['multiples', 'valuation']);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: theme.colors.primary,
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.account_balance_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: _tickerBadge(ticker, onOpenRef),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (stats.isNotEmpty) ...<Widget>[
              ResearchMetrics(stats: stats),
              UiGap.v(theme.spacing.md),
            ],
            if (kvRows.isNotEmpty) ...<Widget>[
              UiKeyValueTable(
                rows: kvRows,
                labelHeader: 'Line Item',
                valueHeader: 'Value',
                trailingHeader: 'YoY / Margin',
              ),
              UiGap.v(theme.spacing.md),
            ],
            if (tableRows.isNotEmpty && periods.isNotEmpty) ...<Widget>[
              UiTable<Map<String, dynamic>>(
                stackOnMobile: true,
                pageSize: 8,
                density: UiDensity.compact,
                rows: tableRows,
                columns: <UiTableColumn<Map<String, dynamic>>>[
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Metric',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, [
                            'label',
                            'metric',
                            'name',
                          ]) ??
                          '—',
                      style: ctx.uiText.bodyStrong,
                    ),
                  ),
                  for (int i = 0; i < periods.length; i++)
                    UiTableColumn<Map<String, dynamic>>(
                      header: periods[i],
                      cell: (BuildContext ctx, Map<String, dynamic> r) {
                        final List<dynamic> vals =
                            (r['values'] as List?) ?? const [];
                        final String text = i < vals.length
                            ? vals[i].toString()
                            : '—';
                        return Text(text, style: ctx.uiText.body);
                      },
                    ),
                ],
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (multiples.isNotEmpty)
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  for (final Map<String, dynamic> m in multiples)
                    UiBadge(
                      label:
                          '${PerplexityCardDataUtils.str(m, ['label', 'name']) ?? 'Multiple'}: ${PerplexityCardDataUtils.str(m, ['value', 'val']) ?? ''}',
                      variant: UiBadgeVariant.outline,
                      intent: UiIntent.info,
                      size: UiSize.xs,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Perplexity Macro & Economic Release Calendar Card.
class PerplexityMacroCard extends StatelessWidget {
  const PerplexityMacroCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ??
        'Macro & Economic Pulse';
    final String? regime = PerplexityCardDataUtils.str(data, [
      'regime',
      'stance',
      'region',
      'subtitle',
    ]);
    final UiIntent regimeIntent = PerplexityCardDataUtils.parseIntent(regime);
    final List<Map<String, dynamic>> indicators =
        PerplexityCardDataUtils.mapList(data, [
          'indicators',
          'events',
          'releases',
          'rows',
          'items',
        ]);
    final List<Map<String, dynamic>> impacts = PerplexityCardDataUtils.mapList(
      data,
      ['impacts', 'assetImpact'],
    );
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'note',
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: theme.colors.info,
        title: title,
        subtitle: regime,
        leading: Icon(
          Icons.public_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.info,
        ),
        trailing: regime != null
            ? UiBadge(label: regime, intent: regimeIntent, size: UiSize.xs)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (summary != null) ...<Widget>[
              Text(summary, style: context.uiText.body.copyWith(height: 1.6)),
              UiGap.v(theme.spacing.sm),
            ],
            if (indicators.isNotEmpty)
              UiTable<Map<String, dynamic>>(
                stackOnMobile: true,
                pageSize: 8,
                density: UiDensity.compact,
                rows: indicators,
                columns: <UiTableColumn<Map<String, dynamic>>>[
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Indicator',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, [
                            'name',
                            'indicator',
                            'event',
                          ]) ??
                          '—',
                      style: ctx.uiText.bodyStrong,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Actual',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, ['actual', 'value']) ??
                          'Pending',
                      style: ctx.uiText.bodyStrong,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Forecast',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, [
                            'forecast',
                            'consensus',
                            'est',
                          ]) ??
                          '—',
                      style: ctx.uiText.body,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Prior',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, ['prior', 'previous']) ??
                          '—',
                      style: ctx.uiText.caption,
                    ),
                  ),
                ],
              ),
            if (impacts.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  for (final Map<String, dynamic> imp in impacts)
                    UiBadge(
                      label:
                          '${PerplexityCardDataUtils.str(imp, ['asset', 'label']) ?? ''}: ${PerplexityCardDataUtils.str(imp, ['impact', 'bias']) ?? ''}',
                      intent: PerplexityCardDataUtils.parseIntent(
                        PerplexityCardDataUtils.str(imp, [
                          'impact',
                          'bias',
                          'intent',
                        ]),
                      ),
                      variant: UiBadgeVariant.soft,
                      size: UiSize.xs,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wall Street Analyst Ratings, Target Range & Institutional/Insider Actions Card.
class PerplexityRatingsCard extends StatelessWidget {
  const PerplexityRatingsCard({super.key, required this.data, this.onOpenRef});

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? ticker = PerplexityCardDataUtils.str(data, [
      'ticker',
      'symbol',
    ]);
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ??
        'Analyst Ratings & Price Targets';
    final String? consensus = PerplexityCardDataUtils.str(data, [
      'consensus',
      'rating',
    ]);
    final double? targetLow = PerplexityCardDataUtils.numField(data, [
      'targetLow',
      'low',
    ]);
    final double? targetMean = PerplexityCardDataUtils.numField(data, [
      'targetMean',
      'targetMedian',
      'median',
      'mean',
      'target',
    ]);
    final double? targetHigh = PerplexityCardDataUtils.numField(data, [
      'targetHigh',
      'high',
    ]);
    final double? currentPrice = PerplexityCardDataUtils.numField(data, [
      'currentPrice',
      'price',
    ]);

    final double? buy = PerplexityCardDataUtils.numField(data, [
      'buy',
      'buyCount',
      'strongBuy',
    ]);
    final double? hold = PerplexityCardDataUtils.numField(data, [
      'hold',
      'holdCount',
    ]);
    final double? sell = PerplexityCardDataUtils.numField(data, [
      'sell',
      'sellCount',
    ]);

    final List<Map<String, dynamic>> actions = PerplexityCardDataUtils.mapList(
      data,
      ['actions', 'upgrades', 'firms', 'filings', 'items'],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: PerplexityCardDataUtils.parseIntent(
          consensus,
        ).color(context),
        title: title,
        leading: Icon(
          Icons.star_half_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: Wrap(
          spacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            if (_tickerBadge(ticker, onOpenRef) case final Widget badge) badge,
            if (consensus != null)
              UiBadge(
                label: consensus,
                intent: PerplexityCardDataUtils.parseIntent(consensus),
                size: UiSize.xs,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (targetLow != null &&
                targetHigh != null &&
                targetHigh > targetLow) ...<Widget>[
              Text(
                'Wall Street Price Target Range',
                style: context.uiText.label.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              UiGap.v(theme.spacing.xs),
              UiRangeMeter(
                min: targetLow,
                max: targetHigh,
                minLabel: 'Low ${targetLow.toStringAsFixed(0)}',
                maxLabel: 'High ${targetHigh.toStringAsFixed(0)}',
                markers: <UiRangeMarker>[
                  if (currentPrice != null)
                    UiRangeMarker(
                      value: currentPrice.clamp(targetLow, targetHigh),
                      label: 'Now ${currentPrice.toStringAsFixed(0)}',
                      intent: UiIntent.info,
                    ),
                  if (targetMean != null)
                    UiRangeMarker(
                      value: targetMean.clamp(targetLow, targetHigh),
                      label: 'Avg ${targetMean.toStringAsFixed(0)}',
                      intent: UiIntent.bullish,
                      strong: true,
                    ),
                ],
              ),
              UiGap.v(theme.spacing.md),
            ],
            if ((buy ?? 0) > 0 ||
                (hold ?? 0) > 0 ||
                (sell ?? 0) > 0) ...<Widget>[
              UiCategoryBar(
                categories: <UiCategoryItem>[
                  if ((buy ?? 0) > 0)
                    UiCategoryItem(label: 'Buy ${buy!.round()}', value: buy),
                  if ((hold ?? 0) > 0)
                    UiCategoryItem(label: 'Hold ${hold!.round()}', value: hold),
                  if ((sell ?? 0) > 0)
                    UiCategoryItem(label: 'Sell ${sell!.round()}', value: sell),
                ],
              ),
              UiGap.v(theme.spacing.md),
            ],
            if (actions.isNotEmpty)
              UiTable<Map<String, dynamic>>(
                stackOnMobile: true,
                pageSize: 8,
                density: UiDensity.compact,
                rows: actions,
                columns: <UiTableColumn<Map<String, dynamic>>>[
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Firm / Insider',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, [
                            'firm',
                            'insider',
                            'name',
                          ]) ??
                          '—',
                      style: ctx.uiText.bodyStrong,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Action',
                    cell: (BuildContext ctx, Map<String, dynamic> r) {
                      final String act =
                          PerplexityCardDataUtils.str(r, [
                            'action',
                            'rating',
                          ]) ??
                          '—';
                      return UiBadge(
                        label: act,
                        intent: PerplexityCardDataUtils.parseIntent(act),
                        size: UiSize.xs,
                      );
                    },
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Target / Value',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, [
                            'target',
                            'priceTarget',
                            'value',
                          ]) ??
                          '—',
                      style: ctx.uiText.body,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Perplexity Market Screener, Ranked Leaderboard & Top Movers Card.
class PerplexityScreenerCard extends StatelessWidget {
  const PerplexityScreenerCard({super.key, required this.data, this.onOpenRef});

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ??
        'Market Screener & Movers';
    final String? criteria = PerplexityCardDataUtils.str(data, [
      'criteria',
      'filter',
      'subtitle',
    ]);
    final List<Map<String, dynamic>> rows = PerplexityCardDataUtils.mapList(
      data,
      ['items', 'rows', 'stocks', 'movers', 'leaders'],
    );
    if (rows.isEmpty) return const SizedBox.shrink();

    final bool hasNumericScores = rows.any(
      (Map<String, dynamic> r) =>
          PerplexityCardDataUtils.numField(r, [
                'score',
                'changePercent',
                'value',
              ]) !=
              null &&
          PerplexityCardDataUtils.str(r, ['price', 'ticker']) == null,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: theme.colors.primary,
        title: title,
        subtitle: criteria,
        leading: Icon(
          Icons.leaderboard_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label: '${rows.length} ranked',
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        child: hasNumericScores
            ? UiBarList(
                items: <UiBarListItem>[
                  for (final Map<String, dynamic> r in rows)
                    UiBarListItem(
                      label:
                          PerplexityCardDataUtils.str(r, [
                            'label',
                            'name',
                            'ticker',
                          ]) ??
                          'Item',
                      value:
                          PerplexityCardDataUtils.numField(r, [
                            'score',
                            'changePercent',
                            'value',
                          ]) ??
                          0,
                      displayValue: PerplexityCardDataUtils.str(r, [
                        'displayValue',
                        'change',
                        'score',
                      ]),
                    ),
                ],
              )
            : UiTable<Map<String, dynamic>>(
                stackOnMobile: true,
                pageSize: 8,
                density: UiDensity.compact,
                rows: rows,
                columns: <UiTableColumn<Map<String, dynamic>>>[
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Asset',
                    cell: (BuildContext ctx, Map<String, dynamic> r) {
                      final String? t = PerplexityCardDataUtils.str(r, [
                        'ticker',
                        'symbol',
                      ]);
                      final String? name = PerplexityCardDataUtils.str(r, [
                        'name',
                        'label',
                      ]);
                      return Wrap(
                        spacing: ctx.sp(theme.spacing.xs),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          if (_tickerBadge(t, onOpenRef) case final Widget b) b,
                          if (name != null) Text(name, style: ctx.uiText.body),
                        ],
                      );
                    },
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Price',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, ['price', 'last']) ?? '—',
                      style: ctx.uiText.bodyStrong,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Change / Metric',
                    cell: (BuildContext ctx, Map<String, dynamic> r) {
                      final String ch =
                          PerplexityCardDataUtils.str(r, [
                            'change',
                            'changePercent',
                            'metric',
                            'score',
                          ]) ??
                          '—';
                      return UiBadge(
                        label: ch,
                        intent: PerplexityCardDataUtils.parseIntent(
                          ch,
                          isPositive: !ch.trimLeft().startsWith('-'),
                        ),
                        size: UiSize.xs,
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

/// Perplexity Market Sentiment, Fear & Greed & Unusual Options Flow Card.
class PerplexitySentimentCard extends StatelessWidget {
  const PerplexitySentimentCard({
    super.key,
    required this.data,
    this.onOpenRef,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? ticker = PerplexityCardDataUtils.str(data, [
      'ticker',
      'symbol',
    ]);
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ??
        'Market Sentiment & Options Flow';
    final String? regime = PerplexityCardDataUtils.str(data, [
      'regime',
      'sentiment',
      'bias',
    ]);
    final double? score = PerplexityCardDataUtils.numField(data, [
      'score',
      'fearGreed',
      'bullishScore',
    ]);
    final double? bullPct = PerplexityCardDataUtils.numField(data, [
      'bullishPct',
      'bullish',
    ]);
    final double? neutralPct = PerplexityCardDataUtils.numField(data, [
      'neutralPct',
      'neutral',
    ]);
    final double? bearPct = PerplexityCardDataUtils.numField(data, [
      'bearishPct',
      'bearish',
    ]);

    final List<UiStat> flowStats = <UiStat>[
      for (final (String l, List<String> k) in const [
        ('Put / Call', ['putCallRatio', 'putCall']),
        ('IV Rank', ['ivRank', 'iv']),
        ('Implied Move', ['impliedMove']),
        ('Max Pain', ['maxPain']),
      ])
        if (PerplexityCardDataUtils.str(data, k) != null)
          UiStat(label: l, value: PerplexityCardDataUtils.str(data, k)!),
    ];
    final List<String> alerts = PerplexityCardDataUtils.strList(data, [
      'alerts',
      'sweeps',
      'highlights',
      'items',
    ]);
    final UiIntent intent = PerplexityCardDataUtils.parseIntent(regime);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: intent.color(context),
        title: title,
        leading: Icon(
          Icons.waves_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: intent.color(context),
        ),
        trailing: Wrap(
          spacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            if (_tickerBadge(ticker, onOpenRef) case final Widget b) b,
            if (regime != null)
              UiBadge(label: regime, intent: intent, size: UiSize.xs),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (score != null) ...<Widget>[
              UiProgressBar(
                value: score > 1
                    ? (score / 100).clamp(0.0, 1.0)
                    : score.clamp(0.0, 1.0),
                label:
                    'Sentiment Index (${score > 1 ? score.round() : (score * 100).round()}/100)',
                intent: intent,
              ),
              UiGap.v(theme.spacing.md),
            ],
            if ((bullPct ?? 0) > 0 || (bearPct ?? 0) > 0) ...<Widget>[
              UiCategoryBar(
                categories: <UiCategoryItem>[
                  if ((bullPct ?? 0) > 0)
                    UiCategoryItem(
                      label: 'Bull ${bullPct!.round()}%',
                      value: bullPct,
                    ),
                  if ((neutralPct ?? 0) > 0)
                    UiCategoryItem(
                      label: 'Neutral ${neutralPct!.round()}%',
                      value: neutralPct,
                    ),
                  if ((bearPct ?? 0) > 0)
                    UiCategoryItem(
                      label: 'Bear ${bearPct!.round()}%',
                      value: bearPct,
                    ),
                ],
              ),
              UiGap.v(theme.spacing.md),
            ],
            if (flowStats.isNotEmpty) ...<Widget>[
              ResearchMetrics(stats: flowStats),
              UiGap.v(theme.spacing.sm),
            ],
            if (alerts.isNotEmpty)
              _bulletListSection(
                context,
                title: 'Notable Flow & Signals',
                items: alerts,
                intent: intent == UiIntent.neutral ? UiIntent.info : intent,
                icon: Icons.bolt_outlined,
              ),
          ],
        ),
      ),
    );
  }
}

/// Perplexity Media & Chart Gallery Card backed by [UiRemoteImage] + [UiLightbox].
class PerplexityMediaCard extends StatelessWidget {
  const PerplexityMediaCard({super.key, required this.data, this.onTapUrl});

  final Map<String, dynamic> data;
  final PerplexityOpenUrlCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ?? 'Visual Media & Charts';
    final List<Map<String, dynamic>> rawItems = PerplexityCardDataUtils.mapList(
      data,
      ['items', 'images', 'media'],
    );
    final List<({String url, String caption, String? sourceUrl})> entries = [];
    for (final Map<String, dynamic> item in rawItems) {
      final String? url = PerplexityCardDataUtils.str(item, [
        'url',
        'imageUrl',
        'src',
      ]);
      if (url != null) {
        entries.add((
          url: url,
          caption:
              PerplexityCardDataUtils.str(item, ['caption', 'title', 'alt']) ??
              '',
          sourceUrl: PerplexityCardDataUtils.str(item, ['sourceUrl', 'link']),
        ));
      }
    }
    if (entries.isEmpty) {
      final String? single = PerplexityCardDataUtils.str(data, [
        'url',
        'imageUrl',
      ]);
      if (single != null) {
        entries.add((
          url: single,
          caption:
              PerplexityCardDataUtils.str(data, ['caption', 'title']) ?? '',
          sourceUrl: PerplexityCardDataUtils.str(data, ['sourceUrl', 'link']),
        ));
      }
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        leading: Icon(
          Icons.collections_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label: '${entries.length} visual${entries.length == 1 ? '' : 's'}',
          intent: UiIntent.info,
          size: UiSize.xs,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < entries.length; i++) ...<Widget>[
                SizedBox(
                  width: context.sz(210),
                  child: UiCard(
                    variant: UiCardVariant.outlined,
                    headerDivider: true,
                    padding: EdgeInsets.all(context.sp(theme.spacing.md)),

                    density: UiDensity.compact,
                    onTap: () => UiLightbox.show(
                      context,
                      mediaUrl: entries[i].url,
                      caption: entries[i].caption.isEmpty
                          ? null
                          : entries[i].caption,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: context.radius(theme.radii.sm),
                          child: UiRemoteImage(
                            url: entries[i].url,
                            height: context.sz(116),
                            width: double.infinity,
                          ),
                        ),
                        if (entries[i].caption.isNotEmpty) ...<Widget>[
                          UiGap.v(theme.spacing.xs),
                          Text(
                            entries[i].caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (i < entries.length - 1) UiGap.h(theme.spacing.xs),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantitative Formula, Variable Breakdown & Worked Example Card.
class PerplexityFormulaCard extends StatelessWidget {
  const PerplexityFormulaCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'name']) ??
        'Quantitative Formula';
    final String? formula = PerplexityCardDataUtils.str(data, [
      'formula',
      'equation',
      'expression',
    ]);
    final String? example = PerplexityCardDataUtils.str(data, [
      'example',
      'workedExample',
    ]);
    final String? takeaway = PerplexityCardDataUtils.str(data, [
      'intuition',
      'note',
      'pitfall',
    ]);
    final List<Map<String, dynamic>> vars = PerplexityCardDataUtils.mapList(
      data,
      ['variables', 'inputs', 'terms'],
    );
    final List<UiKeyValueRow> rows = <UiKeyValueRow>[
      for (final Map<String, dynamic> v in vars)
        if ((PerplexityCardDataUtils.str(v, ['symbol', 'name', 'label']) ?? '')
                .isNotEmpty &&
            (PerplexityCardDataUtils.str(v, [
                      'meaning',
                      'description',
                      'value',
                    ]) ??
                    '')
                .isNotEmpty)
          UiKeyValueRow(
            label: PerplexityCardDataUtils.str(v, ['symbol', 'name', 'label'])!,
            value: PerplexityCardDataUtils.str(v, [
              'meaning',
              'description',
              'value',
            ])!,
            trailing: PerplexityCardDataUtils.str(v, ['unit', 'sample']),
          ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: theme.colors.info,
        title: title,
        leading: Icon(
          Icons.functions_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.info,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (formula != null) ...<Widget>[
              UiCallout(
                title: 'Formula',
                message: formula,
                intent: UiIntent.info,
                icon: Icons.calculate_outlined,
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (rows.isNotEmpty) ...<Widget>[
              UiKeyValueTable(
                rows: rows,
                labelHeader: 'Term',
                valueHeader: 'Definition',
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (example != null) ...<Widget>[
              Text(
                'Worked Example',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foregroundMuted,
                ),
              ),
              UiGap.v(theme.spacing.xxs),
              Text(example, style: context.uiText.body),
            ],
            if (takeaway != null) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              UiCallout(
                title: 'Key Intuition',
                message: takeaway,
                intent: UiIntent.neutral,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rich Product, Software, Platform, Service or Location Overview Card.
class PerplexityProductPlaceCard extends StatelessWidget {
  const PerplexityProductPlaceCard({
    super.key,
    required this.data,
    required this.tag,
    this.onTapUrl,
    this.onPromptTap,
  });

  final Map<String, dynamic> data;
  final String tag;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityPromptCallback? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['name', 'title']) ??
        'Entity Overview';
    final String? category = PerplexityCardDataUtils.str(data, [
      'category',
      'type',
      'location',
      'address',
    ]);
    final String? price = PerplexityCardDataUtils.str(data, [
      'price',
      'pricing',
    ]);
    final double? rating = PerplexityCardDataUtils.numField(data, [
      'rating',
      'score',
    ]);
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'description',
    ]);
    final List<String> pros = PerplexityCardDataUtils.strList(data, [
      'pros',
      'strengths',
      'highlights',
    ]);
    final List<String> cons = PerplexityCardDataUtils.strList(data, [
      'cons',
      'weaknesses',
      'limitations',
    ]);
    final List<String> alternatives = PerplexityCardDataUtils.strList(data, [
      'alternatives',
      'competitors',
    ]);
    final String? url = PerplexityCardDataUtils.str(data, ['url', 'website']);
    final bool isPlace = tag == 'place' || tag == 'location';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: theme.colors.primary,
        title: title,
        subtitle: category,
        leading: Icon(
          isPlace ? Icons.location_on_outlined : Icons.inventory_2_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: Wrap(
          spacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            if (price != null)
              UiBadge(label: price, intent: UiIntent.info, size: UiSize.xs),
            if (rating != null)
              UiBadge(
                label: '★ ${rating.toStringAsFixed(1)}',
                intent: UiIntent.bullish,
                size: UiSize.xs,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (summary != null) ...<Widget>[
              Text(summary, style: context.uiText.body.copyWith(height: 1.6)),
              UiGap.v(theme.spacing.sm),
            ],
            if (pros.isNotEmpty) ...<Widget>[
              _bulletListSection(
                context,
                title: 'Highlights',
                items: pros,
                intent: UiIntent.bullish,
                icon: Icons.check_circle_outline,
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (cons.isNotEmpty) ...<Widget>[
              _bulletListSection(
                context,
                title: 'Trade-offs',
                items: cons,
                intent: UiIntent.warning,
                icon: Icons.remove_circle_outline,
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (alternatives.isNotEmpty || (url != null && onTapUrl != null))
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  if (onPromptTap != null)
                    for (final String alt in alternatives.take(3))
                      UiButton(
                        label: 'Compare vs $alt',
                        icon: Icons.compare_arrows_rounded,
                        size: UiSize.xs,
                        variant: UiVariant.outline,
                        onPressed: () => onPromptTap!(
                          'Compare $title vs $alt in a structured matrix.',
                        ),
                      ),
                  if (url != null && onTapUrl != null)
                    UiButton(
                      label: PerplexityCardDataUtils.domainOf(url).isEmpty
                          ? 'Visit site'
                          : PerplexityCardDataUtils.domainOf(url),
                      icon: Icons.open_in_new_rounded,
                      size: UiSize.xs,
                      variant: UiVariant.ghost,
                      onPressed: () => onTapUrl!(url),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
