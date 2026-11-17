import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import 'research/research_metrics.dart';
import 'site_logo.dart';

/// Shared callbacks passed from [RichMarkdownPreview] / [RichCodeBlockBuilder]
/// down into interactive Perplexity cards.
typedef PerplexityOpenRefCallback = void Function(AppLinkRef ref);
typedef PerplexityOpenUrlCallback = void Function(String url);
typedef PerplexityPromptCallback = void Function(String prompt);

/// Shared extraction helpers for tolerant LLM JSON maps.
class PerplexityCardDataUtils {
  const PerplexityCardDataUtils._();

  static String? str(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic v = map[key];
      final String? parsed = _scalarStr(v);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? _scalarStr(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(v);
      final String? direct = str(m, const [
        'formatted',
        'display',
        'text',
        'label',
        'title',
        'name',
      ]);
      if (direct != null) return direct;
      final String? val = _scalarStr(m['value'] ?? m['amount'] ?? m['price']);
      if (val == null) return null;
      final String? unit = _scalarStr(m['currency'] ?? m['unit']);
      if (unit != null && !val.contains(unit)) {
        if (unit.toUpperCase() == 'USD' && !val.startsWith(r'$')) {
          return '\$$val';
        }
        return '$unit $val';
      }
      return val;
    }
    if (v is List) {
      final List<String> parts = v
          .map(_scalarStr)
          .whereType<String>()
          .where((String s) => s.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    }
    final String s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }

  static double? numVal(dynamic raw) {
    if (raw is num && raw.isFinite) return raw.toDouble();
    if (raw is Map) {
      return numVal(
        raw['value'] ??
            raw['amount'] ??
            raw['price'] ??
            raw['formatted'] ??
            raw['display'],
      );
    }
    if (raw is String) {
      final String cleaned = raw.replaceAll(RegExp(r'[\$,%\s,+]'), '').trim();
      final double? parsed = double.tryParse(cleaned);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  /// Extracts a single numeric price from decorated quotes such as
  /// `"Approx: \$34.00"` or `"USD 55.47"`, while ignoring multi-number ranges.
  static double? embeddedNum(dynamic raw) {
    final double? direct = numVal(raw);
    if (direct != null) return direct;
    final String? text = _scalarStr(raw);
    if (text == null) return null;
    final List<RegExpMatch> matches = RegExp(
      r'-?\d+(?:\.\d+)?',
    ).allMatches(text.replaceAll(',', '')).toList();
    if (matches.length == 1) {
      final double? parsed = double.tryParse(matches.first.group(0)!);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  static double? numField(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final double? v = numVal(map[key]);
      if (v != null) return v;
    }
    return null;
  }

  static List<String> strList(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic raw = map[key];
      if (raw is List) {
        final List<String> items = raw
            .map((dynamic e) {
              if (e is Map) {
                return (e['text'] ??
                        e['title'] ??
                        e['label'] ??
                        e['name'] ??
                        e['summary'] ??
                        '')
                    .toString()
                    .trim();
              }
              return e.toString().trim();
            })
            .where((String s) => s.isNotEmpty)
            .toList();
        if (items.isNotEmpty) return items;
      }
    }
    return const <String>[];
  }

  static List<Map<String, dynamic>> mapList(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic raw = map[key];
      if (raw is List) {
        final List<Map<String, dynamic>> items = raw
            .whereType<Map>()
            .map((Map m) => Map<String, dynamic>.from(m))
            .toList();
        if (items.isNotEmpty) return items;
      }
    }
    return const <Map<String, dynamic>>[];
  }

  static List<double> numList(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic raw = map[key];
      if (raw is List) {
        final List<double> out = <double>[];
        for (final dynamic item in raw) {
          final double? n = numVal(item);
          if (n != null) out.add(n);
        }
        if (out.isNotEmpty) return out;
      }
    }
    return const <double>[];
  }

  static UiIntent parseIntent(String? raw, {bool? isPositive}) {
    final String lower = (raw ?? '').toLowerCase().trim();
    if (lower.contains('bull') ||
        lower.contains('pos') ||
        lower.contains('buy') ||
        lower.contains('strong') ||
        lower.contains('success') ||
        lower.contains('long') ||
        lower.contains('beat') ||
        lower.contains('up')) {
      return UiIntent.bullish;
    }
    if (lower.contains('bear') ||
        lower.contains('neg') ||
        lower.contains('sell') ||
        lower.contains('risk') ||
        lower.contains('danger') ||
        lower.contains('short') ||
        lower.contains('miss') ||
        lower.contains('down')) {
      return UiIntent.bearish;
    }
    if (lower.contains('warn') ||
        lower.contains('caution') ||
        lower.contains('hold') ||
        lower.contains('mixed') ||
        lower.contains('watch')) {
      return UiIntent.warning;
    }
    if (lower.contains('info') || lower.contains('primary')) {
      return UiIntent.info;
    }
    if (isPositive != null) {
      return isPositive ? UiIntent.bullish : UiIntent.bearish;
    }
    return UiIntent.neutral;
  }

  static String cleanTicker(String raw) =>
      raw.trim().replaceFirst(r'$', '').toUpperCase();

  static String domainOf(String url) {
    final Uri? uri = Uri.tryParse(url);
    final String host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

/// Interactive Perplexity-style Company / Stock / Crypto / ETF Dossier card.
class PerplexityCompanyCard extends StatelessWidget {
  const PerplexityCompanyCard({
    super.key,
    required this.data,
    this.onOpenRef,
    this.onTapUrl,
    this.onPromptTap,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityPromptCallback? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String rawTicker =
        PerplexityCardDataUtils.str(data, ['ticker', 'symbol']) ?? '';
    final String ticker = rawTicker.isEmpty
        ? ''
        : PerplexityCardDataUtils.cleanTicker(rawTicker);
    final String name =
        PerplexityCardDataUtils.str(data, ['name', 'company', 'title']) ??
        (ticker.isNotEmpty ? ticker : 'Company Overview');
    final String? exchange = PerplexityCardDataUtils.str(data, ['exchange']);
    final String? sector = PerplexityCardDataUtils.str(data, ['sector']);
    final String? industry = PerplexityCardDataUtils.str(data, ['industry']);
    final String? assetClass = PerplexityCardDataUtils.str(data, [
      'assetType',
      'asset_type',
    ]);
    final String? logoUrl = PerplexityCardDataUtils.str(data, [
      'logoUrl',
      'logo_url',
      'avatarUrl',
    ]);
    final String? websiteUrl = PerplexityCardDataUtils.str(data, [
      'url',
      'website',
    ]);

    final Map<String, dynamic>? priceMap = () {
      for (final String k in const ['price', 'currentPrice', 'lastPrice']) {
        final dynamic raw = data[k];
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
      return null;
    }();
    final String? priceStr = priceMap != null
        ? PerplexityCardDataUtils.str(priceMap, [
            'formatted',
            'display',
            'value',
            'amount',
            'price',
          ])
        : PerplexityCardDataUtils.str(data, [
            'price',
            'currentPrice',
            'lastPrice',
          ]);
    final String? currency =
        PerplexityCardDataUtils.str(data, ['currency']) ??
        (priceMap == null
            ? null
            : PerplexityCardDataUtils.str(priceMap, ['currency']));
    final double? changePct =
        PerplexityCardDataUtils.numField(data, [
          'changePct',
          'change_pct',
          'changePercent',
        ]) ??
        (priceMap == null
            ? null
            : PerplexityCardDataUtils.numField(priceMap, [
                'changePct',
                'change_pct',
                'changePercent',
              ]));
    final String? changeLabel =
        PerplexityCardDataUtils.str(data, ['change', 'delta']) ??
        (priceMap == null
            ? null
            : PerplexityCardDataUtils.str(priceMap, ['change', 'delta']));
    final String? asOf =
        PerplexityCardDataUtils.str(data, ['asOf', 'updatedAt', 'timestamp']) ??
        (priceMap == null
            ? null
            : PerplexityCardDataUtils.str(priceMap, [
                'asOf',
                'updatedAt',
                'timestamp',
              ]));
    final List<double> sparkline = PerplexityCardDataUtils.numList(data, [
      'sparkline',
      'history',
      'trend',
    ]);

    final List<UiStat> stats = _buildStats(context, data);
    final ({double low, double high, double? current, String label})? range52w =
        _extract52WeekRange(data);
    final _AnalystBreakdown? analyst = _extractAnalyst(data);
    final List<({String label, String value})> profileFacts =
        _extractProfileFacts(data);
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'overview',
      'description',
    ]);
    final List<String> highlights = PerplexityCardDataUtils.strList(data, [
      'highlights',
      'bullPoints',
      'catalysts',
    ]);
    final List<String> risks = PerplexityCardDataUtils.strList(data, [
      'risks',
      'bearPoints',
      'headwinds',
    ]);

    final bool? isPositive = changePct != null
        ? changePct >= 0
        : (changeLabel != null
              ? !changeLabel.trimLeft().startsWith('-')
              : null);
    final UiIntent priceIntent = isPositive == null
        ? UiIntent.primary
        : (isPositive ? UiIntent.bullish : UiIntent.bearish);

    final String subtitleParts = <String>[
      ?exchange,
      ?sector,
      if (industry != null && industry != sector) industry,
      if (assetClass != null && sector == null) assetClass,
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: priceIntent.color(context),
        title: name,
        subtitle: subtitleParts.isEmpty ? null : subtitleParts,
        leading: AppSiteLogo(
          url: websiteUrl,
          explicitLogoUrl: logoUrl,
          ticker: ticker,
          label: name,
          size: 40,
          circular: true,
        ),
        trailing: ticker.isEmpty
            ? null
            : UiBadge(
                label: '\$$ticker',
                icon: Icons.candlestick_chart_outlined,
                variant: UiBadgeVariant.soft,
                intent: UiIntent.primary,
                size: UiSize.sm,
                onTap: onOpenRef == null
                    ? null
                    : () => onOpenRef!(
                        AppLinkRef(
                          kind: AppLinkKind.ticker,
                          id: ticker,
                          title: name,
                        ),
                      ),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Quote + Sparkline Row
            if (priceStr != null ||
                changePct != null ||
                sparkline.length > 1) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Wrap(
                spacing: context.sp(theme.spacing.md),
                runSpacing: context.sp(theme.spacing.xs),
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Wrap(
                    spacing: context.sp(theme.spacing.sm),
                    runSpacing: context.sp(theme.spacing.xs),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (priceStr != null)
                        Text(
                          () {
                            if (currency == null ||
                                priceStr.contains(currency) ||
                                priceStr.startsWith(r'$')) {
                              return priceStr;
                            }
                            if (currency.toUpperCase() == 'USD') {
                              return '\$$priceStr';
                            }
                            return '$currency $priceStr';
                          }(),
                          style: context.uiText.display.copyWith(
                            fontSize: context.fs(24),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (changePct != null)
                        UiBadge.delta(changePct)
                      else if (changeLabel != null)
                        UiBadge(
                          label: changeLabel,
                          intent: priceIntent,
                          icon: isPositive == true
                              ? Icons.trending_up
                              : (isPositive == false
                                    ? Icons.trending_down
                                    : null),
                        ),
                      if (priceStr != null && asOf != null)
                        Text(
                          'As of $asOf',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundSubtle,
                          ),
                        ),
                    ],
                  ),
                  if (sparkline.length >= 2)
                    SizedBox(
                      width: context.sz(128),
                      height: context.sz(36),
                      child: UiSparkChart(
                        data: sparkline,
                        color: priceIntent.color(context),
                      ),
                    ),
                ],
              ),
            ],

            // Financial KPI Stat Strip
            if (stats.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.md),
              ResearchMetrics(stats: stats),
            ],

            // 52-Week Price Range Meter
            if (range52w != null) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Text(
                '52-Week Trading Range (${range52w.label})',
                style: context.uiText.label.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              UiGap.v(theme.spacing.xs),
              () {
                final double? clampedCurrent = range52w.current?.clamp(
                  range52w.low,
                  range52w.high,
                );
                return UiRangeMeter(
                  min: range52w.low,
                  max: range52w.high,
                  minLabel: range52w.low.toStringAsFixed(2),
                  maxLabel: range52w.high.toStringAsFixed(2),
                  valueFormatter: (num v) => v.toStringAsFixed(2),
                  zones: <UiRangeZone>[
                    if (clampedCurrent != null)
                      UiRangeZone(
                        start: range52w.low,
                        end: clampedCurrent,
                        intent: priceIntent,
                        alpha: 0.42,
                      )
                    else
                      UiRangeZone(
                        start: range52w.low,
                        end: range52w.high,
                        intent: UiIntent.primary,
                        alpha: 0.16,
                      ),
                  ],
                  markers: <UiRangeMarker>[
                    if (clampedCurrent != null)
                      UiRangeMarker(
                        value: clampedCurrent,
                        label: 'Current',
                        intent: priceIntent,
                        strong: true,
                      ),
                  ],
                );
              }(),
            ],

            // Analyst Consensus Category Bar
            if (analyst != null) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    'Analyst Consensus',
                    style: context.uiText.label.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    children: <Widget>[
                      if (analyst.rating != null)
                        UiBadge(
                          label: analyst.rating!,
                          intent: PerplexityCardDataUtils.parseIntent(
                            analyst.rating,
                          ),
                          size: UiSize.xs,
                        ),
                      if (analyst.target != null)
                        UiBadge(
                          label: 'Target: ${analyst.target!}',
                          intent: UiIntent.info,
                          variant: UiBadgeVariant.outline,
                          size: UiSize.xs,
                        ),
                    ],
                  ),
                ],
              ),
              if (analyst.segments.isNotEmpty) ...<Widget>[
                UiGap.v(theme.spacing.xs),
                UiCategoryBar(categories: analyst.segments),
              ],
            ],

            // Corporate Profile Facts
            if (profileFacts.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Wrap(
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  for (final ({String label, String value}) fact
                      in profileFacts)
                    UiBadge(
                      label: '${fact.label}: ${fact.value}',
                      variant: UiBadgeVariant.outline,
                      size: UiSize.xs,
                    ),
                ],
              ),
            ],

            // Business Summary
            if (summary != null) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Text(
                summary,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],

            // Highlights & Risks
            if (highlights.isNotEmpty || risks.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.md),
              LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  final bool twoCol =
                      highlights.isNotEmpty &&
                      risks.isNotEmpty &&
                      constraints.maxWidth >= ctx.sz(540);
                  if (!twoCol) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (highlights.isNotEmpty)
                          _bulletGroup(
                            ctx,
                            'Key Catalysts & Strengths',
                            highlights,
                            UiIntent.bullish,
                          ),
                        if (highlights.isNotEmpty && risks.isNotEmpty)
                          UiGap.v(theme.spacing.sm),
                        if (risks.isNotEmpty)
                          _bulletGroup(
                            ctx,
                            'Key Risks & Watchpoints',
                            risks,
                            UiIntent.bearish,
                          ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _bulletGroup(
                          ctx,
                          'Key Catalysts & Strengths',
                          highlights,
                          UiIntent.bullish,
                        ),
                      ),
                      UiGap.h(theme.spacing.md),
                      Expanded(
                        child: _bulletGroup(
                          ctx,
                          'Key Risks & Watchpoints',
                          risks,
                          UiIntent.bearish,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

            // Footer Actions
            if (onOpenRef != null ||
                onPromptTap != null ||
                websiteUrl != null) ...<Widget>[
              UiGap.v(theme.spacing.md),
              UiDivider(),
              UiGap.v(theme.spacing.sm),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  if (ticker.isNotEmpty && onOpenRef != null)
                    UiButton(
                      label: 'Open \$$ticker in Market',
                      icon: Icons.open_in_new_rounded,
                      size: UiSize.xs,
                      variant: UiVariant.soft,
                      intent: UiIntent.primary,
                      onPressed: () => onOpenRef!(
                        AppLinkRef(
                          kind: AppLinkKind.ticker,
                          id: ticker,
                          title: name,
                        ),
                      ),
                    ),
                  if (onPromptTap != null && ticker.isNotEmpty)
                    UiButton(
                      label: 'Latest news',
                      icon: Icons.newspaper_outlined,
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () => onPromptTap!(
                        'Show latest breaking news, earnings updates, and catalysts for $name (\$$ticker).',
                      ),
                    ),
                  if (onPromptTap != null && ticker.isNotEmpty)
                    UiButton(
                      label: 'Compare peers',
                      icon: Icons.compare_arrows_rounded,
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () => onPromptTap!(
                        'Compare $name (\$$ticker) against its top 3 competitors on valuation, growth, margins, and risks.',
                      ),
                    ),
                  if (websiteUrl != null && onTapUrl != null)
                    AppSiteLinkChip(
                      url: websiteUrl,
                      title: PerplexityCardDataUtils.domainOf(websiteUrl).isEmpty
                          ? 'Website'
                          : PerplexityCardDataUtils.domainOf(websiteUrl),
                      onTap: () => onTapUrl!(websiteUrl),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _bulletGroup(
    BuildContext context,
    String title,
    List<String> items,
    UiIntent intent,
  ) {
    final UiTheme theme = context.ui;
    final Color accent = intent.color(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: context.uiText.label.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        UiGap.v(theme.spacing.xs),
        for (final String item in items.take(5))
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: context.sp(5)),
                  child: Container(
                    width: context.sz(5),
                    height: context.sz(5),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                UiGap.h(theme.spacing.xs),
                Expanded(
                  child: Text(
                    item,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static List<UiStat> _buildStats(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final List<UiStat> out = <UiStat>[];
    final Set<String> seen = <String>{};

    void addStat(
      String label,
      String value, {
      String? hint,
      UiIntent intent = UiIntent.neutral,
    }) {
      final String key = label.toLowerCase();
      if (value.isEmpty || value.toLowerCase() == 'null' || !seen.add(key)) {
        return;
      }
      out.add(UiStat(label: label, value: value, hint: hint, intent: intent));
    }

    final List<Map<String, dynamic>> explicitMetrics =
        PerplexityCardDataUtils.mapList(data, ['metrics', 'stats', 'kpis']);
    for (final Map<String, dynamic> m in explicitMetrics) {
      final String label =
          PerplexityCardDataUtils.str(m, ['label', 'name', 'title']) ?? '';
      final String value =
          PerplexityCardDataUtils.str(m, ['value', 'val']) ?? '';
      if (label.isEmpty || value.isEmpty) continue;
      final String? change = PerplexityCardDataUtils.str(m, [
        'change',
        'delta',
        'subtitle',
      ]);
      final bool? isPos = m['isPositive'] is bool
          ? m['isPositive'] as bool
          : null;
      addStat(
        label,
        value,
        hint: change,
        intent: change != null || isPos != null
            ? PerplexityCardDataUtils.parseIntent(change, isPositive: isPos)
            : UiIntent.neutral,
      );
    }

    const List<(String label, List<String> keys)> wellKnown = [
      ('Market Cap', ['marketCap', 'market_cap', 'mcap']),
      ('P/E Ratio', ['peRatio', 'pe_ratio', 'pe']),
      ('Fwd P/E', ['forwardPe', 'forward_pe']),
      ('EPS (TTM)', ['eps', 'epsTtm']),
      ('Revenue', ['revenue', 'rev', 'revenueTtm']),
      ('Rev Growth', ['revenueGrowth', 'revenue_growth']),
      ('Gross Margin', ['grossMargin', 'gross_margin']),
      ('Dividend', ['dividendYield', 'dividend_yield', 'yield']),
      ('52W Range', ['range52w', 'week52Range', '52wRange']),
      ('Beta', ['beta']),
      ('Volume', ['volume', 'avgVolume']),
    ];
    for (final (String label, List<String> keys) in wellKnown) {
      if (out.length >= 8) break;
      final String? v = PerplexityCardDataUtils.str(data, keys);
      if (v != null) addStat(label, v);
    }
    return out.take(8).toList();
  }

  static ({double low, double high, double? current, String label})?
  _extract52WeekRange(Map<String, dynamic> data) {
    double? low = PerplexityCardDataUtils.numField(data, [
      'week52Low',
      'low52w',
      '52wLow',
    ]);
    double? high = PerplexityCardDataUtils.numField(data, [
      'week52High',
      'high52w',
      '52wHigh',
    ]);
    final String? rawRange = PerplexityCardDataUtils.str(data, [
      'range52w',
      'week52Range',
      '52wRange',
    ]);
    if ((low == null || high == null) && rawRange != null) {
      final List<RegExpMatch> nums = RegExp(
        r'\d+(?:\.\d+)?',
      ).allMatches(rawRange.replaceAll(',', '')).toList();
      if (nums.length >= 2) {
        low ??= double.tryParse(nums[0].group(0)!);
        high ??= double.tryParse(nums[1].group(0)!);
      }
    }
    if (low == null || high == null || high <= low) return null;
    final double? current =
        PerplexityCardDataUtils.embeddedNum(data['price']) ??
        PerplexityCardDataUtils.embeddedNum(data['currentPrice']) ??
        PerplexityCardDataUtils.embeddedNum(data['lastPrice']);
    return (
      low: low,
      high: high,
      current: current,
      label:
          rawRange ?? '${low.toStringAsFixed(2)} – ${high.toStringAsFixed(2)}',
    );
  }

  static _AnalystBreakdown? _extractAnalyst(Map<String, dynamic> data) {
    final Map<String, dynamic>? nested = data['analystConsensus'] is Map
        ? Map<String, dynamic>.from(data['analystConsensus'] as Map)
        : null;
    final String? rating = PerplexityCardDataUtils.str(nested ?? data, [
      'rating',
      'analystRating',
      'consensus',
    ]);
    final String? target = PerplexityCardDataUtils.str(nested ?? data, [
      'targetPrice',
      'analystTarget',
      'priceTarget',
    ]);
    final double? buy = PerplexityCardDataUtils.numField(nested ?? data, [
      'buyPct',
      'sentimentBuyPct',
      'buy',
    ]);
    final double? hold = PerplexityCardDataUtils.numField(nested ?? data, [
      'holdPct',
      'sentimentHoldPct',
      'hold',
    ]);
    final double? sell = PerplexityCardDataUtils.numField(nested ?? data, [
      'sellPct',
      'sentimentSellPct',
      'sell',
    ]);
    if (rating == null && target == null && buy == null) return null;
    final List<UiCategoryItem> segments = <UiCategoryItem>[
      if (buy != null && buy > 0)
        UiCategoryItem(label: 'Buy ${buy.round()}%', value: buy),
      if (hold != null && hold > 0)
        UiCategoryItem(label: 'Hold ${hold.round()}%', value: hold),
      if (sell != null && sell > 0)
        UiCategoryItem(label: 'Sell ${sell.round()}%', value: sell),
    ];
    return _AnalystBreakdown(
      rating: rating,
      target: target,
      segments: segments,
    );
  }

  static List<({String label, String value})> _extractProfileFacts(
    Map<String, dynamic> data,
  ) {
    const List<(String label, List<String> keys)> pairs = [
      ('CEO', ['ceo']),
      ('HQ', ['hq', 'headquarters', 'location']),
      ('Founded', ['founded']),
      ('Employees', ['employees', 'headcount']),
    ];
    final List<({String label, String value})> facts = [];
    for (final (String label, List<String> keys) in pairs) {
      final String? v = PerplexityCardDataUtils.str(data, keys);
      if (v != null) facts.add((label: label, value: v));
    }
    return facts;
  }
}

class _AnalystBreakdown {
  const _AnalystBreakdown({
    this.rating,
    this.target,
    this.segments = const <UiCategoryItem>[],
  });

  final String? rating;
  final String? target;
  final List<UiCategoryItem> segments;
}

/// Interactive Perplexity-style Person / Executive / Investor / Bio Dossier card.
class PerplexityPersonCard extends StatelessWidget {
  const PerplexityPersonCard({
    super.key,
    required this.data,
    this.onOpenRef,
    this.onTapUrl,
    this.onPromptTap,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityPromptCallback? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String name =
        PerplexityCardDataUtils.str(data, ['name', 'fullName', 'title']) ??
        'Profile';
    final String? role = PerplexityCardDataUtils.str(data, [
      'role',
      'title',
      'position',
      'occupation',
    ]);
    final String? org = PerplexityCardDataUtils.str(data, [
      'organization',
      'company',
      'affiliation',
      'fund',
    ]);
    final String? avatarUrl = PerplexityCardDataUtils.str(data, [
      'avatarUrl',
      'imageUrl',
      'photo',
    ]);
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'bio',
      'overview',
      'description',
    ]);

    final List<String> badges = PerplexityCardDataUtils.strList(data, [
      'badges',
      'tags',
      'affiliations',
    ]);
    final List<String> highlights = PerplexityCardDataUtils.strList(data, [
      'highlights',
      'achievements',
      'keyFacts',
    ]);
    final List<String> tickers = PerplexityCardDataUtils.strList(data, [
      'tickers',
      'companies',
      'holdings',
    ]);

    final List<({String label, String value})> bioFacts = [];
    for (final (String l, List<String> k) in const [
      ('Born', ['born', 'birthDate', 'age']),
      ('Location', ['location', 'hq']),
      ('Nationality', ['nationality', 'country']),
      ('Net Worth', ['netWorth', 'net_worth']),
      ('AUM', ['aum']),
      ('Tenure', ['tenure']),
      ('Education', ['education', 'almaMater']),
    ]) {
      final String? v = PerplexityCardDataUtils.str(data, k);
      if (v != null) bioFacts.add((label: l, value: v));
    }

    final List<Map<String, dynamic>> rawMetrics =
        PerplexityCardDataUtils.mapList(data, ['metrics', 'stats', 'kpis']);
    final List<UiStat> stats = <UiStat>[
      for (final Map<String, dynamic> m in rawMetrics)
        if ((PerplexityCardDataUtils.str(m, ['label', 'name']) ?? '')
                .isNotEmpty &&
            (PerplexityCardDataUtils.str(m, ['value', 'val']) ?? '').isNotEmpty)
          UiStat(
            label: PerplexityCardDataUtils.str(m, ['label', 'name'])!,
            value: PerplexityCardDataUtils.str(m, ['value', 'val'])!,
            hint: PerplexityCardDataUtils.str(m, ['subtitle', 'change']),
          ),
    ];

    final List<Map<String, dynamic>> timeline = PerplexityCardDataUtils.mapList(
      data,
      ['timeline', 'milestones', 'career'],
    );
    final List<Map<String, dynamic>> links = PerplexityCardDataUtils.mapList(
      data,
      ['links', 'sources'],
    );

    final String? roleLine = role != null && org != null && !role.contains(org)
        ? '$role · $org'
        : (role ?? org);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: theme.colors.info,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (avatarUrl != null && avatarUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () => UiLightbox.show(
                      context,
                      mediaUrl: avatarUrl,
                      caption: name,
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        width: context.sz(theme.sizes.avatarLg),
                        height: context.sz(theme.sizes.avatarLg),
                        child: UiRemoteImage(
                          url: avatarUrl,
                          fit: BoxFit.cover,
                          fallback: UiAvatar(
                            name: name,
                            size: UiSize.lg,
                            backgroundColor: theme.colors.info.withValues(
                              alpha: 0.14,
                            ),
                            textColor: theme.colors.info,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  UiAvatar(
                    name: name,
                    size: UiSize.lg,
                    backgroundColor: theme.colors.info.withValues(alpha: 0.14),
                    textColor: theme.colors.info,
                  ),
                UiGap.h(theme.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: context.uiText.title.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (roleLine != null && roleLine != name) ...<Widget>[
                        SizedBox(height: context.sp(2)),
                        Text(
                          roleLine,
                          style: context.uiText.bodyStrong.copyWith(
                            color: theme.colors.primary,
                          ),
                        ),
                      ],
                      if (badges.isNotEmpty) ...<Widget>[
                        UiGap.v(theme.spacing.xs),
                        Wrap(
                          spacing: context.sp(theme.spacing.xs),
                          runSpacing: context.sp(theme.spacing.xs),
                          children: <Widget>[
                            for (final String b in badges.take(4))
                              UiBadge(
                                label: b,
                                intent: UiIntent.info,
                                size: UiSize.xs,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (bioFacts.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  for (final ({String label, String value}) f in bioFacts)
                    UiBadge(
                      label: '${f.label}: ${f.value}',
                      variant: UiBadgeVariant.outline,
                      size: UiSize.xs,
                    ),
                ],
              ),
            ],

            if (stats.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.md),
              ResearchMetrics(stats: stats),
            ],

            if (summary != null) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Text(
                summary,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],

            if (highlights.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Text(
                'Key Highlights',
                style: context.uiText.label.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              UiGap.v(theme.spacing.xs),
              for (final String h in highlights.take(6))
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(theme.spacing.xxs),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome,
                        size: context.sz(14),
                        color: theme.colors.info,
                      ),
                      UiGap.h(theme.spacing.xs),
                      Expanded(child: Text(h, style: context.uiText.caption)),
                    ],
                  ),
                ),
            ],

            if (timeline.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.md),
              Text(
                'Career & Milestones',
                style: context.uiText.label.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              UiGap.v(theme.spacing.sm),
              UiTimeline(
                entries: <UiTimelineEntry>[
                  for (final Map<String, dynamic> m in timeline.take(5))
                    UiTimelineEntry(
                      title:
                          PerplexityCardDataUtils.str(m, ['title', 'event']) ??
                          'Milestone',
                      subtitle: PerplexityCardDataUtils.str(m, [
                        'subtitle',
                        'detail',
                        'description',
                      ]),
                      timestamp: PerplexityCardDataUtils.str(m, [
                        'date',
                        'year',
                      ]),
                      intent: UiIntent.info,
                    ),
                ],
              ),
            ],

            if (tickers.isNotEmpty ||
                links.isNotEmpty ||
                onPromptTap != null) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              UiDivider(),
              UiGap.v(theme.spacing.sm),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  for (final String t in tickers.take(5))
                    Builder(
                      builder: (BuildContext ctx) {
                        final String sym = PerplexityCardDataUtils.cleanTicker(
                          t,
                        );
                        final bool looksTicker = RegExp(
                          r'^[A-Z0-9\.\-]{1,6}$',
                        ).hasMatch(sym);
                        return UiBadge(
                          label: looksTicker ? '\$$sym' : t,
                          intent: UiIntent.primary,
                          size: UiSize.xs,
                          onTap: looksTicker && onOpenRef != null
                              ? () => onOpenRef!(
                                  AppLinkRef(
                                    kind: AppLinkKind.ticker,
                                    id: sym,
                                    title: sym,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  for (final Map<String, dynamic> link in links.take(3))
                    if (PerplexityCardDataUtils.str(link, ['url', 'href']) !=
                        null)
                      AppSiteLinkChip(
                        url: PerplexityCardDataUtils.str(link, [
                          'url',
                          'href',
                        ])!,
                        title: PerplexityCardDataUtils.str(link, [
                          'label',
                          'title',
                        ]),
                        onTap: onTapUrl == null
                            ? null
                            : () => onTapUrl!(
                                PerplexityCardDataUtils.str(link, [
                                  'url',
                                  'href',
                                ])!,
                              ),
                      ),
                  if (onPromptTap != null)
                    UiButton(
                      label: 'Recent news',
                      icon: Icons.newspaper_outlined,
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () => onPromptTap!(
                        'Show latest news, recent decisions, and market impact involving $name.',
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

/// Interactive Perplexity News Digest cards strip/grid.
class PerplexityNewsCard extends StatelessWidget {
  const PerplexityNewsCard({
    super.key,
    required this.data,
    this.onOpenRef,
    this.onTapUrl,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;
  final PerplexityOpenUrlCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ?? 'Latest News & Stories';
    final String? subtitle = PerplexityCardDataUtils.str(data, ['subtitle']);
    List<Map<String, dynamic>> articles = PerplexityCardDataUtils.mapList(
      data,
      ['items', 'articles', 'stories'],
    );
    if (articles.isEmpty &&
        PerplexityCardDataUtils.str(data, ['headline', 'url']) != null) {
      articles = <Map<String, dynamic>>[data];
    }
    if (articles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.newspaper_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label:
              '${articles.length} ${articles.length == 1 ? 'story' : 'stories'}',
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        child: UiCardGrid(
          minTileWidth:
              context.sz(290) * MediaQuery.textScalerOf(context).scale(1),
          largeColumns: 2,
          desktopColumns: 2,
          tabletColumns: 2,
          equalHeight: false,
          intrinsicHeight: true,
          children: [
            for (final article in articles)
              _NewsArticleItem(
                item: article,
                onOpenRef: onOpenRef,
                onTapUrl: onTapUrl,
              ),
          ],
        ),
      ),
    );
  }
}

class _NewsArticleItem extends StatelessWidget {
  const _NewsArticleItem({required this.item, this.onOpenRef, this.onTapUrl});

  final Map<String, dynamic> item;
  final PerplexityOpenRefCallback? onOpenRef;
  final PerplexityOpenUrlCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String headline =
        PerplexityCardDataUtils.str(item, ['title', 'headline']) ??
        'Market Update';
    final String? summary = PerplexityCardDataUtils.str(item, [
      'summary',
      'snippet',
      'description',
    ]);
    final String? url = PerplexityCardDataUtils.str(item, ['url', 'link']);
    final String? publisher = PerplexityCardDataUtils.str(item, [
      'publisher',
      'source',
    ]);
    final String? date = PerplexityCardDataUtils.str(item, [
      'publishedAt',
      'date',
      'time',
      'timestamp',
    ]);
    final String? sentiment = PerplexityCardDataUtils.str(item, [
      'sentiment',
      'impact',
    ]);
    final String? category = PerplexityCardDataUtils.str(item, [
      'category',
      'tag',
    ]);
    final String? imageUrl = PerplexityCardDataUtils.str(item, [
      'imageUrl',
      'thumbnail',
    ]);
    final List<String> tickers = PerplexityCardDataUtils.strList(item, [
      'tickers',
      'symbols',
    ]);

    final String sourceDomain = url != null
        ? PerplexityCardDataUtils.domainOf(url)
        : '';
    final String effectivePublisher =
        publisher ?? (sourceDomain.isNotEmpty ? sourceDomain : 'News');

    return UiCard(
      variant: UiCardVariant.outlined,
      density: UiDensity.compact,
      hoverLift: false,
      onTap: url != null && onTapUrl != null ? () => onTapUrl!(url) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (imageUrl != null) ...<Widget>[
            GestureDetector(
              onTap: () => UiLightbox.show(
                context,
                mediaUrl: imageUrl,
                caption: headline,
              ),
              child: ClipRRect(
                borderRadius: context.radius(theme.radii.md),
                child: UiRemoteImage(
                  url: imageUrl,
                  height: context.sz(112),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            UiGap.v(theme.spacing.sm),
          ],
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xxs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (url != null || sourceDomain.isNotEmpty)
                AppSiteLogo(
                  url: url,
                  domain: sourceDomain,
                  label: effectivePublisher,
                  size: 16,
                ),
              UiBadge(
                label: effectivePublisher,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
              if (sentiment != null)
                UiBadge(
                  label: sentiment,
                  intent: PerplexityCardDataUtils.parseIntent(sentiment),
                  size: UiSize.xs,
                ),
              if (category != null)
                UiBadge(
                  label: category,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
              if (date != null)
                Text(
                  date,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
            ],
          ),
          UiGap.v(theme.spacing.xs),
          Text(
            headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.bodyStrong.copyWith(height: 1.4),
          ),
          if (summary != null) ...<Widget>[
            UiGap.v(theme.spacing.xxs),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.body.copyWith(
                height: 1.5,
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
          if (tickers.isNotEmpty || url != null) ...<Widget>[
            UiGap.v(theme.spacing.xs),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xxs),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final String t in tickers.take(3))
                  UiBadge(
                    label: '\$${PerplexityCardDataUtils.cleanTicker(t)}',
                    intent: UiIntent.primary,
                    size: UiSize.xs,
                    onTap: onOpenRef == null
                        ? null
                        : () => onOpenRef!(
                            AppLinkRef(
                              kind: AppLinkKind.ticker,
                              id: PerplexityCardDataUtils.cleanTicker(t),
                              title: PerplexityCardDataUtils.cleanTicker(t),
                            ),
                          ),
                  ),
                if (url != null)
                  UiButton(
                    label: 'Read source',
                    icon: Icons.open_in_new_rounded,
                    variant: UiVariant.link,
                    size: UiSize.sm,
                    onPressed: onTapUrl == null ? null : () => onTapUrl!(url),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive Perplexity Comparison card supporting Pros/Cons, Bull/Bear,
/// SWOT 2x2 quadrants, and multi-entity Comparison Matrices.
class PerplexityComparisonCard extends StatelessWidget {
  const PerplexityComparisonCard({
    super.key,
    required this.data,
    this.defaultMode,
  });

  final Map<String, dynamic> data;
  final String? defaultMode;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ?? 'Comparison Analysis';
    final String? subtitle = PerplexityCardDataUtils.str(data, ['subtitle']);
    final String rawMode =
        (PerplexityCardDataUtils.str(data, ['mode', 'variant']) ??
                defaultMode ??
                '')
            .toLowerCase();

    final List<Map<String, dynamic>> quadrants =
        PerplexityCardDataUtils.mapList(data, ['quadrants', 'sections']);
    final List<Map<String, dynamic>> entities = PerplexityCardDataUtils.mapList(
      data,
      ['entities', 'columns', 'subjects'],
    );
    final List<Map<String, dynamic>> rows = PerplexityCardDataUtils.mapList(
      data,
      ['rows', 'criteria', 'matrix'],
    );
    final List<String> leftItems = PerplexityCardDataUtils.strList(data, [
      'leftItems',
      'pros',
      'bullCase',
      'bullPoints',
      'strengths',
    ]);
    final List<String> rightItems = PerplexityCardDataUtils.strList(data, [
      'rightItems',
      'cons',
      'bearCase',
      'bearPoints',
      'weaknesses',
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.compare_arrows_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (quadrants.isNotEmpty || rawMode == 'swot')
              _buildQuadrants(
                context,
                quadrants.isNotEmpty ? quadrants : _swotFromKeys(data),
              )
            else if (leftItems.isNotEmpty || rightItems.isNotEmpty)
              _buildTwoColumnCompare(
                context,
                leftTitle:
                    PerplexityCardDataUtils.str(data, [
                      'leftTitle',
                      'bullTitle',
                    ]) ??
                    (rawMode.contains('bull')
                        ? 'Bull Case'
                        : 'Pros / Strengths'),
                leftItems: leftItems,
                rightTitle:
                    PerplexityCardDataUtils.str(data, [
                      'rightTitle',
                      'bearTitle',
                    ]) ??
                    (rawMode.contains('bull') ? 'Bear Case' : 'Cons / Risks'),
                rightItems: rightItems,
              ),
            if (entities.isNotEmpty || rows.isNotEmpty) ...<Widget>[
              if (leftItems.isNotEmpty || rightItems.isNotEmpty)
                UiGap.v(theme.spacing.md),
              _buildMatrixCompare(context, entities: entities, rows: rows),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _swotFromKeys(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    for (final (String title, String key, String intent) in const [
      ('Strengths', 'strengths', 'bullish'),
      ('Weaknesses', 'weaknesses', 'warning'),
      ('Opportunities', 'opportunities', 'info'),
      ('Threats', 'threats', 'bearish'),
    ]) {
      final List<String> items = PerplexityCardDataUtils.strList(data, [key]);
      if (items.isNotEmpty) {
        list.add(<String, dynamic>{
          'title': title,
          'intent': intent,
          'items': items,
        });
      }
    }
    return list;
  }

  Widget _buildQuadrants(
    BuildContext context,
    List<Map<String, dynamic>> quadrants,
  ) {
    final UiTheme theme = context.ui;
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final bool twoCol = constraints.maxWidth >= ctx.sz(560);
        final double cardW = twoCol
            ? (constraints.maxWidth - ctx.sp(theme.spacing.sm)) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: ctx.sp(theme.spacing.sm),
          runSpacing: ctx.sp(theme.spacing.sm),
          children: <Widget>[
            for (int i = 0; i < quadrants.length; i++)
              SizedBox(
                width: cardW,
                child: _buildSidePanel(
                  ctx,
                  title:
                      PerplexityCardDataUtils.str(quadrants[i], [
                        'title',
                        'name',
                      ]) ??
                      'Section ${i + 1}',
                  items: PerplexityCardDataUtils.strList(quadrants[i], [
                    'items',
                    'points',
                    'bullets',
                  ]),
                  intent: PerplexityCardDataUtils.parseIntent(
                    PerplexityCardDataUtils.str(quadrants[i], [
                      'intent',
                      'title',
                    ]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTwoColumnCompare(
    BuildContext context, {
    required String leftTitle,
    required List<String> leftItems,
    required String rightTitle,
    required List<String> rightItems,
  }) {
    return UiCardGrid(
      minTileWidth: context.sz(260) * MediaQuery.textScalerOf(context).scale(1),
      largeColumns: 2,
      desktopColumns: 2,
      tabletColumns: 2,
      equalHeight: false,
      intrinsicHeight: true,
      children: [
        if (leftItems.isNotEmpty)
          _buildSidePanel(
            context,
            title: leftTitle,
            items: leftItems,
            intent: UiIntent.bullish,
          ),
        if (rightItems.isNotEmpty)
          _buildSidePanel(
            context,
            title: rightTitle,
            items: rightItems,
            intent: UiIntent.bearish,
          ),
      ],
    );
  }

  Widget _buildSidePanel(
    BuildContext context, {
    required String title,
    required List<String> items,
    required UiIntent intent,
  }) {
    final UiTheme theme = context.ui;
    final Color accent = intent.color(context);
    return UiCard(
      variant: UiCardVariant.subtle,
      accentColor: accent,
      density: UiDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          UiBadge(label: title, intent: intent, size: UiSize.xs),
          UiGap.v(theme.spacing.xs),
          for (final String item in items)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    intent == UiIntent.bearish
                        ? Icons.remove_circle_outline
                        : Icons.check_circle_outline,
                    size: context.sz(14),
                    color: accent,
                  ),
                  UiGap.h(theme.spacing.xs),
                  Expanded(child: Text(item, style: context.uiText.caption)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMatrixCompare(
    BuildContext context, {
    required List<Map<String, dynamic>> entities,
    required List<Map<String, dynamic>> rows,
  }) {
    final UiTheme theme = context.ui;
    final List<String> colNames = <String>[
      for (final Map<String, dynamic> e in entities)
        PerplexityCardDataUtils.str(e, ['name', 'title', 'ticker']) ?? 'Entity',
    ];

    // Derive columns count from rows if entities list was omitted
    final int inferredCount = rows.fold<int>(colNames.length, (int max, row) {
      final dynamic vals = row['values'];
      return vals is List ? math.max(max, vals.length) : max;
    });
    final declaredCols = PerplexityCardDataUtils.strList(data, ['columns']);
    final List<String> effectiveCols = colNames.isNotEmpty
        ? colNames
        : declaredCols.isNotEmpty
        ? declaredCols
        : List<String>.generate(inferredCount, (int i) => 'Option ${i + 1}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (entities.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final Map<String, dynamic> entity in entities)
                UiBadge(
                  label: [
                    PerplexityCardDataUtils.str(entity, ['name', 'ticker']) ??
                        '',
                    if (PerplexityCardDataUtils.str(entity, [
                          'badge',
                          'subtitle',
                        ]) !=
                        null)
                      PerplexityCardDataUtils.str(entity, [
                        'badge',
                        'subtitle',
                      ])!,
                  ].where((String s) => s.isNotEmpty).join(' · '),
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.soft,
                ),
            ],
          ),
          UiGap.v(theme.spacing.sm),
        ],
        if (rows.isNotEmpty && effectiveCols.isNotEmpty)
          UiTable<Map<String, dynamic>>(
            stackOnMobile: true,
            pageSize: 8,
            density: UiDensity.compact,
            rows: rows,
            columns: <UiTableColumn<Map<String, dynamic>>>[
              UiTableColumn<Map<String, dynamic>>(
                header: 'Dimension',
                cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                  PerplexityCardDataUtils.str(r, [
                        'criterion',
                        'metric',
                        'label',
                        'dimension',
                      ]) ??
                      '',
                  style: ctx.uiText.bodyStrong,
                ),
              ),
              for (int colIdx = 0; colIdx < effectiveCols.length; colIdx++)
                UiTableColumn<Map<String, dynamic>>(
                  header: effectiveCols[colIdx],
                  cell: (BuildContext ctx, Map<String, dynamic> r) {
                    final List<dynamic> vals =
                        (r['values'] as List?) ?? const [];
                    final String val = colIdx < vals.length
                        ? vals[colIdx].toString()
                        : '—';
                    final int? winner = (r['winnerIndex'] as num?)?.toInt();
                    final bool isWinner = winner == colIdx;
                    return Wrap(
                      spacing: ctx.sp(ctx.ui.spacing.xxs),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          val,
                          style: isWinner
                              ? ctx.uiText.bodyStrong.copyWith(
                                  color: ctx.ui.colors.bullish,
                                )
                              : ctx.uiText.body,
                        ),
                        if (isWinner)
                          Icon(
                            Icons.emoji_events_outlined,
                            size: ctx.sz(14),
                            color: ctx.ui.colors.bullish,
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// Interactive Perplexity Timeline / Catalysts / Milestones card backed by [UiTimeline].
class PerplexityTimelineCard extends StatelessWidget {
  const PerplexityTimelineCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ??
        'Key Timeline & Catalysts';
    final String? subtitle = PerplexityCardDataUtils.str(data, ['subtitle']);
    final List<Map<String, dynamic>> rawItems = PerplexityCardDataUtils.mapList(
      data,
      ['items', 'events', 'milestones', 'steps'],
    );
    if (rawItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.timeline_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        child: UiTimeline(
          entries: <UiTimelineEntry>[
            for (final Map<String, dynamic> item in rawItems)
              UiTimelineEntry(
                title:
                    PerplexityCardDataUtils.str(item, [
                      'title',
                      'event',
                      'name',
                    ]) ??
                    'Event',
                subtitle: PerplexityCardDataUtils.str(item, [
                  'subtitle',
                  'detail',
                  'description',
                  'impact',
                ]),
                timestamp: PerplexityCardDataUtils.str(item, [
                  'date',
                  'timestamp',
                  'when',
                ]),
                intent: PerplexityCardDataUtils.parseIntent(
                  PerplexityCardDataUtils.str(item, ['status', 'intent']),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Actionable Trade Setup & Risk Management card backed by [UiCard], [UiStatStrip],
/// [UiProgressBar], and [UiCallout].
class PerplexityTradeSetupCard extends StatelessWidget {
  const PerplexityTradeSetupCard({
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
    final String cleanSym = ticker == null
        ? ''
        : PerplexityCardDataUtils.cleanTicker(ticker);
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ??
        (cleanSym.isNotEmpty ? '\$$cleanSym Trade Plan' : 'Trade Setup');
    final String bias =
        PerplexityCardDataUtils.str(data, ['bias', 'side', 'direction']) ??
        'WATCH';
    final String? timeframe = PerplexityCardDataUtils.str(data, ['timeframe']);
    final UiIntent biasIntent = PerplexityCardDataUtils.parseIntent(bias);

    final String? entry = PerplexityCardDataUtils.str(data, ['entry', 'zone']);
    final String? stopLoss = PerplexityCardDataUtils.str(data, [
      'stopLoss',
      'stop',
    ]);
    final List<String> targets = PerplexityCardDataUtils.strList(data, [
      'targets',
      'takeProfit',
    ]);
    final String? singleTarget = PerplexityCardDataUtils.str(data, [
      'target',
      'takeProfit',
    ]);
    final String? rr = PerplexityCardDataUtils.str(data, [
      'riskReward',
      'rr',
      'rewardRisk',
    ]);
    final double? confidence = PerplexityCardDataUtils.numField(data, [
      'confidence',
    ]);
    final String? invalidation = PerplexityCardDataUtils.str(data, [
      'invalidation',
    ]);
    final String? thesis = PerplexityCardDataUtils.str(data, [
      'thesis',
      'rationale',
      'summary',
    ]);
    final List<String> catalysts = PerplexityCardDataUtils.strList(data, [
      'catalysts',
      'confluences',
    ]);

    final List<UiStat> stats = <UiStat>[
      if (entry != null)
        UiStat(label: 'Entry', value: entry, intent: UiIntent.info),
      if (stopLoss != null)
        UiStat(label: 'Stop Loss', value: stopLoss, intent: UiIntent.bearish),
      if (targets.isNotEmpty)
        UiStat(
          label: 'Targets',
          value: targets.join(' → '),
          intent: UiIntent.bullish,
        )
      else if (singleTarget != null)
        UiStat(label: 'Target', value: singleTarget, intent: UiIntent.bullish),
      if (rr != null)
        UiStat(label: 'Risk : Reward', value: rr, intent: UiIntent.primary),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: biasIntent.color(context),
        title: title,
        subtitle: timeframe,
        trailing: Wrap(
          spacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            if (cleanSym.isNotEmpty)
              UiBadge(
                label: '\$$cleanSym',
                intent: UiIntent.primary,
                size: UiSize.xs,
                onTap: onOpenRef == null
                    ? null
                    : () => onOpenRef!(
                        AppLinkRef(
                          kind: AppLinkKind.ticker,
                          id: cleanSym,
                          title: cleanSym,
                        ),
                      ),
              ),
            UiBadge(
              label: bias.toUpperCase(),
              intent: biasIntent,
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
            if (thesis != null) ...<Widget>[
              Text(thesis, style: context.uiText.body),
              UiGap.v(theme.spacing.sm),
            ],
            if (catalysts.isNotEmpty) ...<Widget>[
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  for (final String c in catalysts)
                    UiBadge(
                      label: c,
                      variant: UiBadgeVariant.outline,
                      size: UiSize.xs,
                    ),
                ],
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (confidence != null) ...<Widget>[
              UiProgressBar(
                value: confidence > 1 ? confidence / 100 : confidence,
                label: 'Setup Confidence',
                intent: biasIntent,
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (invalidation != null)
              UiCallout(
                title: 'Invalidation Condition',
                message: invalidation,
                intent: UiIntent.warning,
                icon: Icons.gpp_maybe_outlined,
              ),
          ],
        ),
      ),
    );
  }
}
