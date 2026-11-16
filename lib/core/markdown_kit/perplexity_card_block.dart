import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/models/app_models.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import 'chart_block.dart';
import 'research/research_panel.dart';
import 'perplexity_domain_cards.dart';
import 'perplexity_extended_cards.dart';
import 'perplexity_parser.dart';

/// Polymorphic renderer for Perplexity-style structured fenced blocks in
/// markdown replies (`company`, `person`, `news`, `compare`, `timeline`,
/// `setup`, `verdict`, `factbox`, `faq`, `checklist`, `quote`, `card`, `cards`,
/// and `loading_card`).
class PerplexityCardBlock extends StatelessWidget {
  const PerplexityCardBlock({
    super.key,
    required this.tag,
    required this.spec,
    this.onOpenRef,
    this.onTapUrl,
    this.onPromptTap,
  });

  final String tag;
  final String spec;
  final PerplexityOpenRefCallback? onOpenRef;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityPromptCallback? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String lowerTag = tag.toLowerCase().trim();
    final Map<String, dynamic>? parsed = PerplexityAnswerParser.parseCardMap(
      spec,
      fallbackKind: lowerTag,
    );

    if (lowerTag == 'loading_card') {
      final String label =
          parsed?['label']?.toString() ?? 'Building research card';
      return _LoadingCardSkeleton(label: label);
    }

    if (parsed == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
        child: UiCard(
          variant: UiCardVariant.subtle,
          title: PerplexityBlockTags.friendlyLabel(lowerTag),
          child: Text(spec.trim(), style: context.uiText.body),
        ),
      );
    }

    // Multiple cards container (`cards` block or `"cards": [...]`).
    final dynamic nestedCards = parsed['cards'];
    if (nestedCards is List && nestedCards.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final dynamic entry in nestedCards)
            if (entry is Map)
              _dispatch(
                context,
                tag: (entry['kind'] ?? entry['type'] ?? 'card')
                    .toString()
                    .toLowerCase()
                    .trim(),
                data: Map<String, dynamic>.from(entry),
              ),
        ],
      );
    }

    final String effectiveTag = lowerTag == 'card'
        ? _inferCardKind(parsed)
        : lowerTag;
    return _dispatch(context, tag: effectiveTag, data: parsed);
  }

  Widget _dispatch(
    BuildContext context, {
    required String tag,
    required Map<String, dynamic> data,
  }) {
    switch (tag) {
      case 'research_panel':
        return ResearchPanel(data: data, onTapUrl: onTapUrl);
      case 'company':
      case 'stock':
      case 'equity':
      case 'crypto':
      case 'etf':
      case 'entity_company':
        return PerplexityCompanyCard(
          data: data,
          onOpenRef: onOpenRef,
          onTapUrl: onTapUrl,
          onPromptTap: onPromptTap,
        );
      case 'person':
      case 'profile':
      case 'executive':
      case 'founder':
      case 'investor':
      case 'bio':
      case 'person_profile':
        return PerplexityPersonCard(
          data: data,
          onOpenRef: onOpenRef,
          onTapUrl: onTapUrl,
          onPromptTap: onPromptTap,
        );
      case 'news':
      case 'headlines':
      case 'articles':
        return PerplexityNewsCard(
          data: data,
          onOpenRef: onOpenRef,
          onTapUrl: onTapUrl,
        );
      case 'compare':
      case 'comparison':
      case 'pros_cons':
      case 'bull_bear':
      case 'swot':
      case 'versus':
        return PerplexityComparisonCard(data: data, defaultMode: tag);
      case 'timeline':
      case 'events':
      case 'catalysts':
      case 'roadmap':
        return PerplexityTimelineCard(data: data);
      case 'setup':
      case 'trade_setup':
      case 'signal':
      case 'order_plan':
        return PerplexityTradeSetupCard(data: data, onOpenRef: onOpenRef);
      case 'verdict':
      case 'takeaways':
      case 'summary':
        return _VerdictCard(data: data);
      case 'product':
      case 'software':
      case 'service':
      case 'place':
      case 'location':
        return PerplexityProductPlaceCard(
          data: data,
          tag: tag,
          onTapUrl: onTapUrl,
          onPromptTap: onPromptTap,
        );
      case 'factbox':
      case 'entity':
      case 'concept':
      case 'book':
      case 'glossary':
        return _FactBoxCard(
          data: data,
          tag: tag,
          onOpenRef: onOpenRef,
          onTapUrl: onTapUrl,
        );
      case 'earnings':
      case 'earnings_call':
      case 'quarter':
        return PerplexityEarningsCard(
          data: data,
          onOpenRef: onOpenRef,
          onPromptTap: onPromptTap,
        );
      case 'financials':
      case 'income_statement':
      case 'balance_sheet':
      case 'cash_flow':
      case 'valuation':
        return PerplexityFinancialsCard(data: data, onOpenRef: onOpenRef);
      case 'macro':
      case 'economic':
      case 'fed':
      case 'rates':
      case 'calendar':
        return PerplexityMacroCard(data: data);
      case 'analyst':
        if (data.containsKey('actions') ||
            data.containsKey('upgrades') ||
            data.containsKey('targetMean') ||
            data.containsKey('targetLow') ||
            data.containsKey('targetHigh') ||
            data.containsKey('filings')) {
          return PerplexityRatingsCard(data: data, onOpenRef: onOpenRef);
        }
        return PerplexityPersonCard(
          data: data,
          onOpenRef: onOpenRef,
          onTapUrl: onTapUrl,
          onPromptTap: onPromptTap,
        );
      case 'ratings':
      case 'price_target':
      case 'insider':
      case 'ownership':
        return PerplexityRatingsCard(data: data, onOpenRef: onOpenRef);
      case 'screener':
      case 'watchlist':
      case 'movers':
      case 'sector':
      case 'peers':
      case 'leaderboard':
      case 'ranking':
        return PerplexityScreenerCard(data: data, onOpenRef: onOpenRef);
      case 'sentiment':
      case 'options_flow':
      case 'social_pulse':
        return PerplexitySentimentCard(data: data, onOpenRef: onOpenRef);
      case 'media':
      case 'gallery':
      case 'images':
        return PerplexityMediaCard(data: data, onTapUrl: onTapUrl);
      case 'formula':
      case 'calculation':
      case 'math_card':
        return PerplexityFormulaCard(data: data);
      case 'faq':
      case 'accordion':
        return _FaqCard(data: data);
      case 'checklist':
      case 'steps':
      case 'how_to':
        return _ChecklistCard(data: data);
      case 'quote':
        return _QuoteCard(data: data, onTapUrl: onTapUrl);
      case 'chart':
      case 'bar':
      case 'line':
      case 'area':
      case 'combo':
      case 'pie':
      case 'donut':
      case 'candle':
      case 'waterfall':
      case 'barlist':
      case 'kpi':
      case 'metrics':
      case 'spark':
        return ChartBlock(spec: spec, defaultType: tag);
      default:
        return _GenericResearchCard(
          data: data,
          onOpenRef: onOpenRef,
          onTapUrl: onTapUrl,
        );
    }
  }

  static String _inferCardKind(Map<String, dynamic> data) {
    final String? explicit = (data['kind'] ?? data['type'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (data.containsKey('epsActual') || data.containsKey('epsEstimate')) {
      return 'earnings';
    }
    if (data.containsKey('lineItems') ||
        (data.containsKey('periods') && data.containsKey('rows'))) {
      return 'financials';
    }
    if (data.containsKey('indicators') || data.containsKey('releases')) {
      return 'macro';
    }
    if (data.containsKey('targetMean') ||
        data.containsKey('upgrades') ||
        data.containsKey('filings')) {
      return 'ratings';
    }
    if (data.containsKey('putCallRatio') || data.containsKey('fearGreed')) {
      return 'sentiment';
    }
    if (data.containsKey('formula') || data.containsKey('equation')) {
      return 'formula';
    }
    if (data.containsKey('price') ||
        data.containsKey('marketCap') ||
        data.containsKey('peRatio')) {
      return 'company';
    }
    if (data.containsKey('born') ||
        data.containsKey('netWorth') ||
        data.containsKey('role') ||
        data.containsKey('bio')) {
      return 'person';
    }
    if (data.containsKey('articles') ||
        (data['items'] is List &&
            (data['items'] as List).isNotEmpty &&
            (data['items'] as List).first is Map &&
            ((data['items'] as List).first as Map).containsKey('publisher'))) {
      return 'news';
    }
    if (data.containsKey('entry') && data.containsKey('stopLoss')) {
      return 'setup';
    }
    if (data.containsKey('leftItems') ||
        data.containsKey('rightItems') ||
        data.containsKey('entities') ||
        data.containsKey('quadrants')) {
      return 'compare';
    }
    if (data.containsKey('facts')) return 'factbox';
    if (data.containsKey('quote')) return 'quote';
    return 'generic';
  }
}

class _LoadingCardSkeleton extends StatelessWidget {
  const _LoadingCardSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        variant: UiCardVariant.subtle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            UiBadge.status('Building $label…', intent: UiIntent.primary),
            UiGap.v(theme.spacing.sm),
            UiSkeleton.heading(width: 180, height: 18),
            UiGap.v(theme.spacing.xs),
            UiSkeleton.text(lines: 2, spacing: 6),
          ],
        ),
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'heading']) ??
        'Key Takeaways & Verdict';
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'verdict',
      'body',
      'message',
    ]);
    final String? badge = PerplexityCardDataUtils.str(data, [
      'badge',
      'rating',
      'stance',
      'intent',
    ]);
    final UiIntent intent = PerplexityCardDataUtils.parseIntent(
      badge ?? PerplexityCardDataUtils.str(data, ['intent']),
    );
    final double? confidence = PerplexityCardDataUtils.numField(data, [
      'confidence',
    ]);
    final List<String> bullets = PerplexityCardDataUtils.strList(data, [
      'bullets',
      'takeaways',
      'points',
      'items',
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        variant: UiCardVariant.subtle,
        accentColor: intent.color(context),
        title: title,
        leading: Icon(
          Icons.auto_awesome_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: intent.color(context),
        ),
        trailing: badge != null
            ? UiBadge(label: badge, intent: intent, size: UiSize.xs)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (summary != null) Text(summary, style: context.uiText.body),
            if (bullets.isNotEmpty) ...<Widget>[
              if (summary != null) UiGap.v(theme.spacing.sm),
              for (int i = 0; i < bullets.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(theme.spacing.xs),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      UiBadge(
                        label: '${i + 1}',
                        intent: intent,
                        size: UiSize.xs,
                      ),
                      UiGap.h(theme.spacing.xs),
                      Expanded(
                        child: Text(bullets[i], style: context.uiText.body),
                      ),
                    ],
                  ),
                ),
            ],
            if (confidence != null) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              UiProgressBar(
                value: confidence > 1 ? confidence / 100 : confidence,
                label: 'Conviction / Confidence',
                intent: intent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactBoxCard extends StatelessWidget {
  const _FactBoxCard({
    required this.data,
    required this.tag,
    this.onOpenRef,
    this.onTapUrl,
  });

  final Map<String, dynamic> data;
  final String tag;
  final PerplexityOpenRefCallback? onOpenRef;
  final PerplexityOpenUrlCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'name']) ?? 'Fact Sheet';
    final String? subtitle = PerplexityCardDataUtils.str(data, [
      'subtitle',
      'category',
      'typeLabel',
    ]);
    final String? badge = PerplexityCardDataUtils.str(data, [
      'badge',
      'status',
    ]);
    final String? imageUrl = PerplexityCardDataUtils.str(data, [
      'imageUrl',
      'thumbnail',
    ]);
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'description',
      'definition',
    ]);
    final List<String> tags = PerplexityCardDataUtils.strList(data, [
      'tags',
      'keywords',
      'tickers',
    ]);
    final List<Map<String, dynamic>> facts = PerplexityCardDataUtils.mapList(
      data,
      ['facts', 'attributes', 'details', 'specs'],
    );
    final List<Map<String, dynamic>> links = PerplexityCardDataUtils.mapList(
      data,
      ['links', 'sources'],
    );

    final List<UiKeyValueRow> rows = <UiKeyValueRow>[
      for (final Map<String, dynamic> f in facts)
        if ((PerplexityCardDataUtils.str(f, ['label', 'key', 'name']) ?? '')
                .isNotEmpty &&
            (PerplexityCardDataUtils.str(f, ['value', 'val']) ?? '').isNotEmpty)
          UiKeyValueRow(
            label: PerplexityCardDataUtils.str(f, ['label', 'key', 'name'])!,
            value: PerplexityCardDataUtils.str(f, ['value', 'val'])!,
            detail: PerplexityCardDataUtils.str(f, ['detail', 'note']),
            trailing: PerplexityCardDataUtils.str(f, ['trailing', 'change']),
            intent: PerplexityCardDataUtils.parseIntent(
              PerplexityCardDataUtils.str(f, ['intent']),
            ),
          ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        title: title,
        subtitle: subtitle,
        leading: Icon(
          switch (tag) {
            'product' => Icons.inventory_2_outlined,
            'book' => Icons.menu_book_outlined,
            'place' => Icons.public_outlined,
            'concept' || 'glossary' => Icons.lightbulb_outline,
            _ => Icons.info_outline_rounded,
          },
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: badge != null
            ? UiBadge(label: badge, intent: UiIntent.info, size: UiSize.xs)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (imageUrl != null) ...<Widget>[
              ClipRRect(
                borderRadius: context.radius(theme.radii.md),
                child: UiRemoteImage(
                  url: imageUrl,
                  height: context.sz(148),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              UiGap.v(theme.spacing.md),
            ],
            if (summary != null) ...<Widget>[
              Text(
                summary,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              if (rows.isNotEmpty) UiGap.v(theme.spacing.md),
            ],
            if (rows.isNotEmpty)
              UiKeyValueTable(rows: rows, showShareBars: false),
            if (tags.isNotEmpty || links.isNotEmpty) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  for (final String t in tags.take(6))
                    UiBadge(
                      label: t,
                      variant: UiBadgeVariant.outline,
                      size: UiSize.xs,
                      onTap: onOpenRef != null && t.startsWith(r'$')
                          ? () {
                              final String sym =
                                  PerplexityCardDataUtils.cleanTicker(t);
                              onOpenRef!(
                                AppLinkRef(
                                  kind: AppLinkKind.ticker,
                                  id: sym,
                                  title: sym,
                                ),
                              );
                            }
                          : null,
                    ),
                  for (final Map<String, dynamic> link in links.take(3))
                    if (PerplexityCardDataUtils.str(link, ['url', 'href']) !=
                        null)
                      UiButton(
                        label:
                            PerplexityCardDataUtils.str(link, [
                              'label',
                              'title',
                            ]) ??
                            'Source',
                        icon: Icons.open_in_new_rounded,
                        size: UiSize.xs,
                        variant: UiVariant.ghost,
                        onPressed: onTapUrl == null
                            ? null
                            : () => onTapUrl!(
                                PerplexityCardDataUtils.str(link, [
                                  'url',
                                  'href',
                                ])!,
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

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title']) ??
        'Key Questions & Answers';
    final List<Map<String, dynamic>> items = PerplexityCardDataUtils.mapList(
      data,
      ['items', 'questions', 'faqs'],
    );
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        title: title,
        leading: Icon(
          Icons.help_outline_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        child: UiAccordion(
          variant: UiAccordionVariant.separated,
          allowMultiple: true,
          initiallyOpen: const <int>{0},
          items: <UiAccordionItem>[
            for (final Map<String, dynamic> item in items)
              UiAccordionItem(
                title:
                    PerplexityCardDataUtils.str(item, [
                      'question',
                      'title',
                      'q',
                    ]) ??
                    'Question',
                badge: PerplexityCardDataUtils.str(item, ['badge', 'tag']),
                content: Text(
                  PerplexityCardDataUtils.str(item, [
                        'answer',
                        'detail',
                        'body',
                        'a',
                      ]) ??
                      '',
                  style: context.uiText.body,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatefulWidget {
  const _ChecklistCard({required this.data});

  final Map<String, dynamic> data;

  @override
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  final Set<int> _checked = <int>{};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final List<Map<String, dynamic>> items = _normalizedItems();
    for (int i = 0; i < items.length; i++) {
      if (items[i]['done'] == true || items[i]['checked'] == true) {
        _checked.add(i);
      }
    }
  }

  List<Map<String, dynamic>> _normalizedItems() {
    final dynamic raw = widget.data['items'] ?? widget.data['steps'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map((dynamic entry) {
      if (entry is Map) return Map<String, dynamic>.from(entry);
      return <String, dynamic>{'title': entry.toString()};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(widget.data, ['title']) ??
        'Action Checklist';
    final String? subtitle = PerplexityCardDataUtils.str(widget.data, [
      'subtitle',
    ]);
    final List<Map<String, dynamic>> items = _normalizedItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.checklist_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label: '${_checked.length}/${items.length}',
          intent: _checked.length == items.length
              ? UiIntent.bullish
              : UiIntent.primary,
          size: UiSize.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) UiGap.v(theme.spacing.xs),
              UiCheckbox(
                value: _checked.contains(i),
                asCard: true,
                density: UiDensity.compact,
                label:
                    PerplexityCardDataUtils.str(items[i], [
                      'title',
                      'step',
                      'label',
                      'name',
                    ]) ??
                    'Step ${i + 1}',
                description: PerplexityCardDataUtils.str(items[i], [
                  'detail',
                  'subtitle',
                  'description',
                ]),
                onChanged: (bool val) {
                  setState(() {
                    if (val) {
                      _checked.add(i);
                    } else {
                      _checked.remove(i);
                    }
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.data, this.onTapUrl});

  final Map<String, dynamic> data;
  final PerplexityOpenUrlCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String quote =
        PerplexityCardDataUtils.str(data, ['quote', 'text', 'statement']) ?? '';
    if (quote.isEmpty) return const SizedBox.shrink();
    final String? author = PerplexityCardDataUtils.str(data, [
      'author',
      'speaker',
      'source',
    ]);
    final String? role = PerplexityCardDataUtils.str(data, ['role', 'context']);
    final String? date = PerplexityCardDataUtils.str(data, ['date']);
    final String? url = PerplexityCardDataUtils.str(data, ['url', 'link']);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        variant: UiCardVariant.subtle,
        accentColor: theme.colors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.format_quote_rounded,
              size: context.sz(20),
              color: theme.colors.primary,
            ),
            UiGap.v(theme.spacing.xs),
            Text(
              quote,
              style: context.uiText.body.copyWith(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (author != null || date != null || url != null) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xxs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (author != null)
                    Text('— $author', style: context.uiText.label),
                  if (role != null)
                    Text(
                      role,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  if (date != null)
                    UiBadge(
                      label: date,
                      variant: UiBadgeVariant.outline,
                      size: UiSize.xs,
                    ),
                  if (url != null && onTapUrl != null)
                    UiButton(
                      label: 'Source',
                      icon: Icons.open_in_new_rounded,
                      size: UiSize.xs,
                      variant: UiVariant.ghost,
                      onPressed: () => onTapUrl!(url),
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

class _GenericResearchCard extends StatelessWidget {
  const _GenericResearchCard({
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
        PerplexityCardDataUtils.str(data, ['title', 'name']) ?? 'Research Card';
    final String? subtitle = PerplexityCardDataUtils.str(data, ['subtitle']);
    final String? badge = PerplexityCardDataUtils.str(data, [
      'badge',
      'status',
    ]);
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'description',
      'body',
    ]);
    final List<String> items = PerplexityCardDataUtils.strList(data, [
      'items',
      'bullets',
      'points',
    ]);
    final String? url = PerplexityCardDataUtils.str(data, ['url', 'link']);

    final List<UiKeyValueRow> scalarRows = <UiKeyValueRow>[];
    const Set<String> skip = <String>{
      'kind',
      'type',
      'title',
      'name',
      'subtitle',
      'badge',
      'status',
      'summary',
      'description',
      'body',
      'items',
      'bullets',
      'points',
      'url',
      'link',
    };
    for (final MapEntry<String, dynamic> entry in data.entries) {
      if (skip.contains(entry.key)) continue;
      if (entry.value is String || entry.value is num || entry.value is bool) {
        final String v = entry.value.toString().trim();
        if (v.isNotEmpty) {
          scalarRows.add(UiKeyValueRow(label: entry.key, value: v));
        }
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        title: title,
        subtitle: subtitle,
        trailing: badge != null
            ? UiBadge(label: badge, intent: UiIntent.primary, size: UiSize.xs)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (summary != null) ...<Widget>[
              Text(summary, style: context.uiText.body),
              UiGap.v(theme.spacing.sm),
            ],
            if (scalarRows.isNotEmpty) ...<Widget>[
              UiKeyValueTable(rows: scalarRows, showShareBars: false),
              UiGap.v(theme.spacing.sm),
            ],
            for (final String item in items)
              Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('• ', style: context.uiText.bodyStrong),
                    Expanded(child: Text(item, style: context.uiText.body)),
                  ],
                ),
              ),
            if (url != null && onTapUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: UiButton(
                  label: 'Open source',
                  icon: Icons.open_in_new_rounded,
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  onPressed: () => onTapUrl!(url),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
