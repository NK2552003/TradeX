import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import 'perplexity_domain_cards.dart';
import 'research/research_metrics.dart';
import 'site_logo.dart';

/// Perplexity Search Results & Rich Web Links Card with real domain favicons.
class PerplexityLinksCard extends StatelessWidget {
  const PerplexityLinksCard({
    super.key,
    required this.data,
    this.onTapUrl,
    this.onOpenRef,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'heading']) ??
        'Web Sources & Links';
    final String? subtitle = PerplexityCardDataUtils.str(data, [
      'subtitle',
      'query',
      'description',
    ]);
    List<Map<String, dynamic>> items = PerplexityCardDataUtils.mapList(data, [
      'items',
      'links',
      'results',
      'sources',
      'bookmarks',
    ]);
    if (items.isEmpty && PerplexityCardDataUtils.str(data, ['url', 'href']) != null) {
      items = <Map<String, dynamic>>[data];
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.travel_explore_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label: '${items.length} ${items.length == 1 ? 'link' : 'links'}',
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        child: UiCardGrid(
          minTileWidth:
              context.sz(260) * MediaQuery.textScalerOf(context).scale(1),
          largeColumns: 2,
          desktopColumns: 2,
          tabletColumns: 2,
          equalHeight: false,
          children: <Widget>[
            for (final Map<String, dynamic> item in items)
              _LinkItemCard(item: item, onTapUrl: onTapUrl),
          ],
        ),
      ),
    );
  }
}

class _LinkItemCard extends StatelessWidget {
  const _LinkItemCard({required this.item, this.onTapUrl});

  final Map<String, dynamic> item;
  final PerplexityOpenUrlCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? url = PerplexityCardDataUtils.str(item, [
      'url',
      'href',
      'link',
    ]);
    final String domain =
        SiteLogoResolver.extractDomain(url) ??
        PerplexityCardDataUtils.str(item, ['domain', 'site', 'publisher']) ??
        'Web';
    final String title =
        PerplexityCardDataUtils.str(item, ['title', 'label', 'name']) ?? domain;
    final String? snippet = PerplexityCardDataUtils.str(item, [
      'snippet',
      'description',
      'summary',
    ]);
    final String? badge = PerplexityCardDataUtils.str(item, [
      'badge',
      'tag',
      'type',
    ]);
    final String? date = PerplexityCardDataUtils.str(item, [
      'publishedAt',
      'date',
      'timestamp',
    ]);
    final String? thumb = PerplexityCardDataUtils.str(item, [
      'imageUrl',
      'thumbnail',
    ]);
    final String? logoUrl = PerplexityCardDataUtils.str(item, [
      'logoUrl',
      'favicon',
    ]);

    return UiCard(
      variant: UiCardVariant.subtle,
      density: UiDensity.compact,
      onTap: url != null && onTapUrl != null ? () => onTapUrl!(url) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (thumb != null) ...<Widget>[
            ClipRRect(
              borderRadius: context.radius(theme.radii.sm),
              child: UiRemoteImage(
                url: thumb,
                height: context.sz(96),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            UiGap.v(theme.spacing.xs),
          ],
          Row(
            children: <Widget>[
              AppSiteLogo(
                url: url,
                domain: domain,
                explicitLogoUrl: logoUrl,
                label: title,
                size: 18,
              ),
              UiGap.h(theme.spacing.xs),
              Expanded(
                child: Text(
                  domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null) ...<Widget>[
                UiGap.h(theme.spacing.xs),
                UiBadge(
                  label: badge,
                  intent: UiIntent.info,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              ],
            ],
          ),
          UiGap.v(theme.spacing.xs),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.bodyStrong.copyWith(height: 1.35),
          ),
          if (snippet != null) ...<Widget>[
            UiGap.v(theme.spacing.xxs),
            Text(
              snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
                height: 1.45,
              ),
            ),
          ],
          if (date != null || url != null) ...<Widget>[
            UiGap.v(theme.spacing.xs),
            Row(
              children: <Widget>[
                if (date != null)
                  Expanded(
                    child: Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (url != null)
                  Icon(
                    Icons.open_in_new_rounded,
                    size: context.sz(14),
                    color: theme.colors.primary,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Perplexity Video, Podcast & Earnings Call Recording Card.
class PerplexityVideoCard extends StatelessWidget {
  const PerplexityVideoCard({
    super.key,
    required this.data,
    this.onTapUrl,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenUrlCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'heading']) ??
        'Videos & Briefings';
    List<Map<String, dynamic>> items = PerplexityCardDataUtils.mapList(data, [
      'items',
      'videos',
      'episodes',
    ]);
    if (items.isEmpty &&
        PerplexityCardDataUtils.str(data, ['url', 'videoUrl', 'thumbnail']) !=
            null) {
      items = <Map<String, dynamic>>[data];
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        leading: Icon(
          Icons.play_circle_outline_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label: '${items.length} ${items.length == 1 ? 'clip' : 'clips'}',
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        child: UiCardGrid(
          minTileWidth:
              context.sz(260) * MediaQuery.textScalerOf(context).scale(1),
          largeColumns: 2,
          desktopColumns: 2,
          tabletColumns: 2,
          equalHeight: false,
          children: <Widget>[
            for (final Map<String, dynamic> item in items)
              _VideoItemTile(item: item, onTapUrl: onTapUrl),
          ],
        ),
      ),
    );
  }
}

class _VideoItemTile extends StatelessWidget {
  const _VideoItemTile({required this.item, this.onTapUrl});

  final Map<String, dynamic> item;
  final PerplexityOpenUrlCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(item, ['title', 'name', 'headline']) ??
        'Video Briefing';
    final String? url = PerplexityCardDataUtils.str(item, [
      'url',
      'videoUrl',
      'link',
    ]);
    final String? thumb = PerplexityCardDataUtils.str(item, [
      'thumbnail',
      'imageUrl',
      'poster',
    ]);
    final String? channel = PerplexityCardDataUtils.str(item, [
      'channel',
      'creator',
      'author',
      'platform',
      'source',
    ]);
    final String? duration = PerplexityCardDataUtils.str(item, [
      'duration',
      'length',
    ]);
    final String? publishedAt = PerplexityCardDataUtils.str(item, [
      'publishedAt',
      'date',
      'views',
    ]);
    final String? summary = PerplexityCardDataUtils.str(item, [
      'summary',
      'description',
    ]);
    final List<String> chapters = PerplexityCardDataUtils.strList(item, [
      'chapters',
      'timestamps',
      'highlights',
    ]);

    return UiCard(
      variant: UiCardVariant.subtle,
      density: UiDensity.compact,
      onTap: url != null && onTapUrl != null ? () => onTapUrl!(url) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: context.radius(theme.radii.md),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumb != null
                      ? UiRemoteImage(url: thumb, fit: BoxFit.cover)
                      : Container(
                          color: theme.colors.surfaceHover,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.ondemand_video_rounded,
                            size: context.sz(36),
                            color: theme.colors.foregroundSubtle,
                          ),
                        ),
                ),
                Container(
                  width: context.sz(42),
                  height: context.sz(42),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: context.sz(26),
                  ),
                ),
                if (duration != null)
                  Positioned(
                    right: context.sp(theme.spacing.xs),
                    bottom: context.sp(theme.spacing.xs),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(6),
                        vertical: context.sp(2),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: context.radius(4),
                      ),
                      child: Text(
                        duration,
                        style: context.uiText.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          UiGap.v(theme.spacing.sm),
          Row(
            children: <Widget>[
              AppSiteLogo(
                url: url,
                domain: channel ?? 'youtube.com',
                label: channel ?? title,
                size: 16,
              ),
              UiGap.h(theme.spacing.xs),
              Expanded(
                child: Text(
                  <String>[?channel, ?publishedAt].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
          ),
          UiGap.v(theme.spacing.xxs),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.bodyStrong,
          ),
          if (summary != null) ...<Widget>[
            UiGap.v(theme.spacing.xxs),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
          if (chapters.isNotEmpty) ...<Widget>[
            UiGap.v(theme.spacing.xs),
            Wrap(
              spacing: context.sp(theme.spacing.xxs),
              runSpacing: context.sp(theme.spacing.xxs),
              children: <Widget>[
                for (final String ch in chapters.take(3))
                  UiBadge(
                    label: ch,
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Live Pulse / Indices / Commodities / FX / Conditions Card.
class PerplexityPulseCard extends StatelessWidget {
  const PerplexityPulseCard({
    super.key,
    required this.data,
    this.onTapUrl,
    this.onOpenRef,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'name', 'location']) ??
        'Market & Conditions Pulse';
    final String? subtitle = PerplexityCardDataUtils.str(data, [
      'subtitle',
      'asOf',
      'condition',
      'regime',
    ]);
    final String? primaryValue = PerplexityCardDataUtils.str(data, [
      'value',
      'price',
      'headlineValue',
      'temp',
    ]);
    final double? changePct = PerplexityCardDataUtils.numField(data, [
      'changePercent',
      'changePct',
    ]);
    final String? changeLabel = PerplexityCardDataUtils.str(data, [
      'change',
      'delta',
    ]);
    final List<double> sparkline = PerplexityCardDataUtils.numList(data, [
      'sparkline',
      'trend',
      'series',
    ]);
    final List<Map<String, dynamic>> items = PerplexityCardDataUtils.mapList(
      data,
      ['items', 'tiles', 'metrics', 'indices', 'pairs', 'forecast'],
    );
    final String? sourceUrl = PerplexityCardDataUtils.str(data, [
      'url',
      'sourceUrl',
    ]);
    final bool isPos = changePct != null
        ? changePct >= 0
        : !(changeLabel ?? '').trimLeft().startsWith('-');
    final UiIntent intent = isPos ? UiIntent.bullish : UiIntent.bearish;

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
          Icons.speed_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: sourceUrl != null
            ? AppSiteLogo(url: sourceUrl, label: title, size: 22)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (primaryValue != null || sparkline.length >= 2) ...<Widget>[
              Wrap(
                spacing: context.sp(theme.spacing.md),
                runSpacing: context.sp(theme.spacing.xs),
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Wrap(
                    spacing: context.sp(theme.spacing.sm),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (primaryValue != null)
                        Text(
                          primaryValue,
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
                          intent: intent,
                          size: UiSize.xs,
                        ),
                    ],
                  ),
                  if (sparkline.length >= 2)
                    SizedBox(
                      width: context.sz(128),
                      height: context.sz(36),
                      child: UiSparkChart(
                        data: sparkline,
                        color: intent.color(context),
                      ),
                    ),
                ],
              ),
              UiGap.v(theme.spacing.md),
            ],
            if (items.isNotEmpty)
              UiCardGrid(
                minTileWidth:
                    context.sz(150) * MediaQuery.textScalerOf(context).scale(1),
                largeColumns: 3,
                desktopColumns: 3,
                tabletColumns: 2,
                equalHeight: false,
                children: <Widget>[
                  for (final Map<String, dynamic> item in items)
                    _PulseTile(item: item, onOpenRef: onOpenRef),
                ],
              ),
            if (sourceUrl != null && onTapUrl != null) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: AppSiteLinkChip(
                  url: sourceUrl,
                  title: SiteLogoResolver.extractDomain(sourceUrl) ?? 'Source',
                  onTap: () => onTapUrl!(sourceUrl),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({required this.item, this.onOpenRef});

  final Map<String, dynamic> item;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String label =
        PerplexityCardDataUtils.str(item, [
          'label',
          'name',
          'symbol',
          'ticker',
          'day',
        ]) ??
        'Item';
    final String value =
        PerplexityCardDataUtils.str(item, [
          'value',
          'price',
          'last',
          'temp',
        ]) ??
        '—';
    final String? delta = PerplexityCardDataUtils.str(item, [
      'change',
      'changePercent',
      'delta',
      'condition',
    ]);
    final String? ticker = PerplexityCardDataUtils.str(item, ['ticker', 'symbol']);
    final UiIntent intent = delta != null
        ? PerplexityCardDataUtils.parseIntent(
            delta,
            isPositive: !delta.trimLeft().startsWith('-'),
          )
        : UiIntent.neutral;

    return UiCard(
      variant: UiCardVariant.subtle,
      density: UiDensity.compact,
      onTap: ticker != null && onOpenRef != null
          ? () {
              final String clean = PerplexityCardDataUtils.cleanTicker(ticker);
              onOpenRef!(
                AppLinkRef(kind: AppLinkKind.ticker, id: clean, title: clean),
              );
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (ticker != null) ...<Widget>[
                AppSiteLogo(ticker: ticker, label: label, size: 16),
                UiGap.h(theme.spacing.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          UiGap.v(theme.spacing.xxs),
          Text(value, style: context.uiText.title),
          if (delta != null) ...<Widget>[
            UiGap.v(theme.spacing.xxs),
            UiBadge(label: delta, intent: intent, size: UiSize.xs),
          ],
        ],
      ),
    );
  }
}

/// Interactive Schedule, Earnings Calendar & Event Scoreboard Card.
class PerplexityScheduleCard extends StatelessWidget {
  const PerplexityScheduleCard({
    super.key,
    required this.data,
    this.onOpenRef,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'heading']) ??
        'Calendar & Schedule';
    final String? subtitle = PerplexityCardDataUtils.str(data, [
      'subtitle',
      'period',
      'week',
    ]);
    final List<Map<String, dynamic>> events = PerplexityCardDataUtils.mapList(
      data,
      ['events', 'items', 'rows', 'matches', 'earnings'],
    );
    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.event_note_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label: '${events.length} events',
          intent: UiIntent.info,
          size: UiSize.xs,
        ),
        child: UiTable<Map<String, dynamic>>(
          stackOnMobile: true,
          pageSize: 8,
          density: UiDensity.compact,
          rows: events,
          columns: <UiTableColumn<Map<String, dynamic>>>[
            UiTableColumn<Map<String, dynamic>>(
              header: 'When',
              cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                PerplexityCardDataUtils.str(r, ['date', 'time', 'when']) ?? '—',
                style: ctx.uiText.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            UiTableColumn<Map<String, dynamic>>(
              header: 'Entity / Event',
              cell: (BuildContext ctx, Map<String, dynamic> r) {
                final String? ticker = PerplexityCardDataUtils.str(r, [
                  'ticker',
                  'symbol',
                ]);
                final String name =
                    PerplexityCardDataUtils.str(r, [
                      'event',
                      'title',
                      'name',
                      'company',
                    ]) ??
                    (ticker ?? 'Event');
                return Wrap(
                  spacing: ctx.sp(theme.spacing.xs),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (ticker != null)
                      AppSiteLogo(ticker: ticker, label: name, size: 16),
                    Text(name, style: ctx.uiText.bodyStrong),
                  ],
                );
              },
            ),
            UiTableColumn<Map<String, dynamic>>(
              header: 'Est / Forecast',
              cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                PerplexityCardDataUtils.str(r, [
                      'estimate',
                      'forecast',
                      'consensus',
                    ]) ??
                    '—',
                style: ctx.uiText.body,
              ),
            ),
            UiTableColumn<Map<String, dynamic>>(
              header: 'Status',
              cell: (BuildContext ctx, Map<String, dynamic> r) {
                final String status =
                    PerplexityCardDataUtils.str(r, [
                      'status',
                      'result',
                      'actual',
                      'impact',
                    ]) ??
                    'Upcoming';
                return UiBadge(
                  label: status,
                  intent: PerplexityCardDataUtils.parseIntent(status),
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

/// Interactive Bull / Base / Bear Scenario Probability Matrix Card.
class PerplexityScenarioMatrixCard extends StatefulWidget {
  const PerplexityScenarioMatrixCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<PerplexityScenarioMatrixCard> createState() =>
      _PerplexityScenarioMatrixCardState();
}

class _PerplexityScenarioMatrixCardState
    extends State<PerplexityScenarioMatrixCard> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(widget.data, ['title', 'heading']) ??
        'Scenario & Probability Matrix';
    final String? subtitle = PerplexityCardDataUtils.str(widget.data, [
      'subtitle',
      'horizon',
    ]);
    final List<Map<String, dynamic>> scenarios =
        PerplexityCardDataUtils.mapList(widget.data, [
          'scenarios',
          'cases',
          'options',
          'items',
        ]);
    if (scenarios.isEmpty) return const SizedBox.shrink();

    final int idx = _selected.clamp(0, scenarios.length - 1);
    final Map<String, dynamic> active = scenarios[idx];

    final List<UiCategoryItem> weights = <UiCategoryItem>[];
    for (final Map<String, dynamic> s in scenarios) {
      final double? prob = PerplexityCardDataUtils.numField(s, [
        'probability',
        'weight',
        'pct',
        'votes',
      ]);
      final String label =
          PerplexityCardDataUtils.str(s, ['name', 'title', 'case', 'label']) ??
          'Case';
      if (prob != null && prob > 0) {
        weights.add(UiCategoryItem(label: '$label ${prob.round()}%', value: prob));
      }
    }

    final String activeName =
        PerplexityCardDataUtils.str(active, ['name', 'title', 'case', 'label']) ??
        'Scenario';
    final String? target = PerplexityCardDataUtils.str(active, [
      'target',
      'priceTarget',
      'outcome',
      'value',
    ]);
    final String? upside = PerplexityCardDataUtils.str(active, [
      'upside',
      'return',
      'move',
      'delta',
    ]);
    final String? summary = PerplexityCardDataUtils.str(active, [
      'summary',
      'thesis',
      'description',
    ]);
    final List<String> triggers = PerplexityCardDataUtils.strList(active, [
      'triggers',
      'drivers',
      'catalysts',
      'bullets',
    ]);
    final UiIntent activeIntent = PerplexityCardDataUtils.parseIntent(
      PerplexityCardDataUtils.str(active, ['intent', 'bias', 'name']),
      isPositive: upside == null ? null : !upside.trimLeft().startsWith('-'),
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.account_tree_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (weights.isNotEmpty) ...<Widget>[
              UiCategoryBar(categories: weights),
              UiGap.v(theme.spacing.md),
            ],
            UiTabs(
              tabs: <String>[
                for (final Map<String, dynamic> s in scenarios)
                  PerplexityCardDataUtils.str(s, [
                        'name',
                        'title',
                        'case',
                        'label',
                      ]) ??
                      'Case',
              ],
              selectedIndex: idx,
              variant: UiTabsVariant.pill,
              size: UiSize.sm,
              scrollable: true,
              showPanel: false,
              onChanged: (int i) => setState(() => _selected = i),
            ),
            UiGap.v(theme.spacing.md),
            UiCard(
              variant: UiCardVariant.subtle,
              accentColor: activeIntent.color(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xs),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(activeName, style: context.uiText.title),
                      if (target != null)
                        UiBadge(
                          label: 'Target $target',
                          intent: activeIntent,
                          size: UiSize.xs,
                        ),
                      if (upside != null)
                        UiBadge(
                          label: upside,
                          intent: activeIntent,
                          variant: UiBadgeVariant.soft,
                          size: UiSize.xs,
                        ),
                    ],
                  ),
                  if (summary != null) ...<Widget>[
                    UiGap.v(theme.spacing.xs),
                    Text(summary, style: context.uiText.body),
                  ],
                  if (triggers.isNotEmpty) ...<Widget>[
                    UiGap.v(theme.spacing.sm),
                    for (final String tr in triggers)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: context.sp(theme.spacing.xxs),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.arrow_right_rounded,
                              size: context.sz(16),
                              color: activeIntent.color(context),
                            ),
                            UiGap.h(theme.spacing.xxs),
                            Expanded(
                              child: Text(tr, style: context.uiText.caption),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quantitative Strategy & Backtest Telemetry Card.
class PerplexityBacktestCard extends StatelessWidget {
  const PerplexityBacktestCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'name', 'strategy']) ??
        'Quantitative Backtest';
    final String? subtitle = PerplexityCardDataUtils.str(data, [
      'subtitle',
      'period',
      'universe',
      'timeframe',
    ]);
    final List<double> equityCurve = PerplexityCardDataUtils.numList(data, [
      'equityCurve',
      'equity',
      'curve',
      'series',
    ]);
    final List<UiStat> stats = <UiStat>[
      for (final (String l, List<String> k) in const [
        ('Net Return', ['netReturn', 'totalReturn', 'cagr']),
        ('Win Rate', ['winRate', 'winPct']),
        ('Sharpe', ['sharpe', 'sharpeRatio']),
        ('Profit Factor', ['profitFactor', 'pf']),
        ('Max Drawdown', ['maxDrawdown', 'drawdown', 'mdd']),
        ('Trades', ['trades', 'sampleSize', 'count']),
      ])
        if (PerplexityCardDataUtils.str(data, k) != null)
          UiStat(
            label: l,
            value: PerplexityCardDataUtils.str(data, k)!,
            intent: l == 'Max Drawdown'
                ? UiIntent.bearish
                : (l == 'Net Return' ? UiIntent.bullish : UiIntent.neutral),
          ),
    ];
    final List<Map<String, dynamic>> trades = PerplexityCardDataUtils.mapList(
      data,
      ['tradesList', 'breakdown', 'periods', 'rows'],
    );
    final String? notes = PerplexityCardDataUtils.str(data, [
      'summary',
      'notes',
      'methodology',
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: theme.colors.bullish,
        title: title,
        subtitle: subtitle,
        leading: Icon(
          Icons.query_stats_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.bullish,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (stats.isNotEmpty) ...<Widget>[
              ResearchMetrics(stats: stats),
              UiGap.v(theme.spacing.md),
            ],
            if (equityCurve.length >= 2) ...<Widget>[
              UiAreaChart(
                height: context.sz(148),
                showLegend: false,
                data: <UiChartPoint>[
                  for (int i = 0; i < equityCurve.length; i++)
                    UiChartPoint(
                      label: '${i + 1}',
                      values: <double>[equityCurve[i]],
                    ),
                ],
                series: <UiChartSeries>[
                  UiChartSeries(
                    name: 'Equity',
                    color: theme.colors.bullish,
                    type: UiChartSeriesType.area,
                  ),
                ],
              ),
              UiGap.v(theme.spacing.md),
            ],
            if (notes != null) ...<Widget>[
              Text(notes, style: context.uiText.body),
              UiGap.v(theme.spacing.sm),
            ],
            if (trades.isNotEmpty)
              UiTable<Map<String, dynamic>>(
                stackOnMobile: true,
                pageSize: 6,
                density: UiDensity.compact,
                rows: trades,
                columns: <UiTableColumn<Map<String, dynamic>>>[
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Segment / Period',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, [
                            'period',
                            'label',
                            'name',
                            'ticker',
                          ]) ??
                          '—',
                      style: ctx.uiText.bodyStrong,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Return',
                    cell: (BuildContext ctx, Map<String, dynamic> r) {
                      final String ret =
                          PerplexityCardDataUtils.str(r, [
                            'return',
                            'pnl',
                            'net',
                          ]) ??
                          '—';
                      return UiBadge(
                        label: ret,
                        intent: PerplexityCardDataUtils.parseIntent(
                          ret,
                          isPositive: !ret.trimLeft().startsWith('-'),
                        ),
                        size: UiSize.xs,
                      );
                    },
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Win Rate',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, ['winRate', 'wr']) ?? '—',
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

/// Portfolio Holdings & Target Rebalance Allocation Card.
class PerplexityPortfolioCard extends StatelessWidget {
  const PerplexityPortfolioCard({
    super.key,
    required this.data,
    this.onOpenRef,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenRefCallback? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'name']) ??
        'Portfolio & Asset Allocation';
    final String? totalValue = PerplexityCardDataUtils.str(data, [
      'totalValue',
      'aum',
      'value',
      'subtitle',
    ]);
    final List<Map<String, dynamic>> holdings = PerplexityCardDataUtils.mapList(
      data,
      ['holdings', 'positions', 'allocations', 'items', 'assets'],
    );
    if (holdings.isEmpty) return const SizedBox.shrink();

    final List<Color> palette = <Color>[
      theme.colors.primary,
      theme.colors.bullish,
      theme.colors.info,
      theme.colors.warning,
      theme.colors.bearish,
    ];
    final List<UiDonutSlice> slices = <UiDonutSlice>[];
    for (int i = 0; i < math.min(holdings.length, 6); i++) {
      final Map<String, dynamic> h = holdings[i];
      final double? weight = PerplexityCardDataUtils.numField(h, [
        'weight',
        'allocation',
        'pct',
        'share',
      ]);
      final String label =
          PerplexityCardDataUtils.str(h, ['ticker', 'symbol', 'name']) ??
          'Asset ${i + 1}';
      if (weight != null && weight > 0) {
        slices.add(
          UiDonutSlice(
            label: label,
            value: weight,
            color: palette[i % palette.length],
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: totalValue,
        leading: Icon(
          Icons.pie_chart_outline_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label: '${holdings.length} holdings',
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (slices.isNotEmpty) ...<Widget>[
              Center(
                child: UiDonutChart(
                  slices: slices,
                  size: 160,
                  showLegend: true,
                  centerLabel: totalValue ?? '${holdings.length} Assets',
                ),
              ),
              UiGap.v(theme.spacing.md),
            ],
            UiTable<Map<String, dynamic>>(
              stackOnMobile: true,
              pageSize: 8,
              density: UiDensity.compact,
              rows: holdings,
              columns: <UiTableColumn<Map<String, dynamic>>>[
                UiTableColumn<Map<String, dynamic>>(
                  header: 'Asset',
                  cell: (BuildContext ctx, Map<String, dynamic> r) {
                    final String? ticker = PerplexityCardDataUtils.str(r, [
                      'ticker',
                      'symbol',
                    ]);
                    final String name =
                        PerplexityCardDataUtils.str(r, ['name', 'asset']) ??
                        (ticker ?? 'Asset');
                    return Wrap(
                      spacing: ctx.sp(theme.spacing.xs),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        AppSiteLogo(ticker: ticker, label: name, size: 16),
                        if (ticker != null && onOpenRef != null)
                          UiBadge(
                            label: '\$${PerplexityCardDataUtils.cleanTicker(ticker)}',
                            intent: UiIntent.primary,
                            size: UiSize.xs,
                            onTap: () {
                              final clean = PerplexityCardDataUtils.cleanTicker(
                                ticker,
                              );
                              onOpenRef!(
                                AppLinkRef(
                                  kind: AppLinkKind.ticker,
                                  id: clean,
                                  title: name,
                                ),
                              );
                            },
                          )
                        else
                          Text(name, style: ctx.uiText.bodyStrong),
                      ],
                    );
                  },
                ),
                UiTableColumn<Map<String, dynamic>>(
                  header: 'Weight',
                  cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                    PerplexityCardDataUtils.str(r, [
                          'weight',
                          'allocation',
                          'pct',
                        ]) ??
                        '—',
                    style: ctx.uiText.bodyStrong,
                  ),
                ),
                UiTableColumn<Map<String, dynamic>>(
                  header: 'Target / Action',
                  cell: (BuildContext ctx, Map<String, dynamic> r) {
                    final String action =
                        PerplexityCardDataUtils.str(r, [
                          'action',
                          'targetWeight',
                          'status',
                        ]) ??
                        'Hold';
                    return UiBadge(
                      label: action,
                      intent: PerplexityCardDataUtils.parseIntent(action),
                      size: UiSize.xs,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// SEC Filing, Whitepaper, Transcript or Research Document Summary Card.
class PerplexityDocumentCard extends StatelessWidget {
  const PerplexityDocumentCard({
    super.key,
    required this.data,
    this.onTapUrl,
    this.onPromptTap,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityPromptCallback? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'document', 'name']) ??
        'Document & Filing Summary';
    final String? filingType = PerplexityCardDataUtils.str(data, [
      'filingType',
      'form',
      'docType',
      'type',
    ]);
    final String? date = PerplexityCardDataUtils.str(data, [
      'filedAt',
      'date',
      'period',
    ]);
    final String? issuer = PerplexityCardDataUtils.str(data, [
      'issuer',
      'company',
      'author',
    ]);
    final String? ticker = PerplexityCardDataUtils.str(data, ['ticker', 'symbol']);
    final String? url = PerplexityCardDataUtils.str(data, ['url', 'link']);
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'abstract',
      'overview',
    ]);
    final List<String> takeaways = PerplexityCardDataUtils.strList(data, [
      'highlights',
      'takeaways',
      'findings',
      'sections',
    ]);
    final String? riskFlag = PerplexityCardDataUtils.str(data, [
      'risk',
      'caveat',
      'footnote',
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: <String>[?issuer, ?date].join(' · '),
        leading: AppSiteLogo(
          url: url,
          ticker: ticker,
          label: issuer ?? title,
          size: 28,
        ),
        trailing: filingType != null
            ? UiBadge(
                label: filingType.toUpperCase(),
                intent: UiIntent.info,
                size: UiSize.xs,
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (summary != null) ...<Widget>[
              Text(summary, style: context.uiText.body),
              UiGap.v(theme.spacing.sm),
            ],
            for (final String item in takeaways)
              Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.description_outlined,
                      size: context.sz(14),
                      color: theme.colors.primary,
                    ),
                    UiGap.h(theme.spacing.xs),
                    Expanded(child: Text(item, style: context.uiText.caption)),
                  ],
                ),
              ),
            if (riskFlag != null) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              UiCallout(
                title: 'Key Disclosure / Risk',
                message: riskFlag,
                intent: UiIntent.warning,
              ),
            ],
            if (url != null || onPromptTap != null) ...<Widget>[
              UiGap.v(theme.spacing.sm),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  if (url != null && onTapUrl != null)
                    AppSiteLinkChip(
                      url: url,
                      title: SiteLogoResolver.extractDomain(url) ?? 'View document',
                      onTap: () => onTapUrl!(url),
                    ),
                  if (onPromptTap != null)
                    UiButton(
                      label: 'Extract key risks',
                      icon: Icons.warning_amber_outlined,
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () => onPromptTap!(
                        'List all material risk factors and accounting footnotes from "$title".',
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

/// Perplexity Knowledge Panel / Wikipedia / Definition Card.
class PerplexityWikiCard extends StatelessWidget {
  const PerplexityWikiCard({
    super.key,
    required this.data,
    this.onTapUrl,
    this.onPromptTap,
  });

  final Map<String, dynamic> data;
  final PerplexityOpenUrlCallback? onTapUrl;
  final PerplexityPromptCallback? onPromptTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'term', 'name']) ??
        'Knowledge Card';
    final String? subtitle = PerplexityCardDataUtils.str(data, [
      'subtitle',
      'phonetic',
      'category',
      'domain',
    ]);
    final String? summary = PerplexityCardDataUtils.str(data, [
      'summary',
      'definition',
      'description',
    ]);
    final String? imageUrl = PerplexityCardDataUtils.str(data, [
      'imageUrl',
      'thumbnail',
      'image',
    ]);
    final String? url = PerplexityCardDataUtils.str(data, ['url', 'sourceUrl']);
    final List<Map<String, dynamic>> facts = PerplexityCardDataUtils.mapList(
      data,
      ['facts', 'attributes', 'infobox'],
    );
    final List<String> related = PerplexityCardDataUtils.strList(data, [
      'related',
      'relatedTopics',
      'topics',
      'seeAlso',
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        subtitle: subtitle,
        leading: AppSiteLogo(url: url, label: title, size: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (imageUrl != null) ...<Widget>[
              GestureDetector(
                onTap: () => UiLightbox.show(
                  context,
                  mediaUrl: imageUrl,
                  caption: title,
                ),
                child: ClipRRect(
                  borderRadius: context.radius(theme.radii.md),
                  child: UiRemoteImage(
                    url: imageUrl,
                    height: context.sz(160),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (summary != null) ...<Widget>[
              Text(summary, style: context.uiText.body),
              UiGap.v(theme.spacing.sm),
            ],
            if (facts.isNotEmpty) ...<Widget>[
              UiKeyValueTable(
                rows: <UiKeyValueRow>[
                  for (final Map<String, dynamic> f in facts)
                    if ((PerplexityCardDataUtils.str(f, ['label', 'key']) ?? '')
                            .isNotEmpty &&
                        (PerplexityCardDataUtils.str(f, ['value', 'val']) ?? '')
                            .isNotEmpty)
                      UiKeyValueRow(
                        label: PerplexityCardDataUtils.str(f, ['label', 'key'])!,
                        value: PerplexityCardDataUtils.str(f, ['value', 'val'])!,
                      ),
                ],
                showShareBars: false,
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (related.isNotEmpty || url != null)
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  if (onPromptTap != null)
                    for (final String topic in related.take(4))
                      UiBadge(
                        label: topic,
                        variant: UiBadgeVariant.soft,
                        intent: UiIntent.primary,
                        size: UiSize.xs,
                        onTap: () => onPromptTap!(
                          'Explain $topic in the context of $title.',
                        ),
                      ),
                  if (url != null && onTapUrl != null)
                    AppSiteLinkChip(
                      url: url,
                      title: SiteLogoResolver.extractDomain(url) ?? 'Reference',
                      onTap: () => onTapUrl!(url),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Position Sizing & Risk Management Worksheet Card.
class PerplexityRiskPlanCard extends StatelessWidget {
  const PerplexityRiskPlanCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(data, ['title', 'name']) ??
        'Position Sizing & Risk Plan';
    final double? riskPct = PerplexityCardDataUtils.numField(data, [
      'riskPct',
      'riskPercent',
    ]);
    final List<UiStat> stats = <UiStat>[
      for (final (String l, List<String> k) in const [
        ('Account', ['accountSize', 'equity', 'capital']),
        ('Risk %', ['riskPct', 'riskPercent']),
        ('Max Loss', ['maxLoss', 'riskAmount', 'dollarRisk']),
        ('Position Size', ['positionSize', 'shares', 'units', 'qty']),
        ('Stop Distance', ['stopDistance', 'stopLoss']),
      ])
        if (PerplexityCardDataUtils.str(data, k) != null)
          UiStat(label: l, value: PerplexityCardDataUtils.str(data, k)!),
    ];
    final List<Map<String, dynamic>> ladder = PerplexityCardDataUtils.mapList(
      data,
      ['targets', 'ladder', 'rMultiples', 'rows'],
    );
    final String? invalidation = PerplexityCardDataUtils.str(data, [
      'invalidation',
      'rule',
      'note',
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        accentColor: theme.colors.warning,
        title: title,
        leading: Icon(
          Icons.shield_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.warning,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (stats.isNotEmpty) ...<Widget>[
              ResearchMetrics(stats: stats),
              UiGap.v(theme.spacing.md),
            ],
            if (riskPct != null) ...<Widget>[
              UiProgressBar(
                value: (riskPct / 5.0).clamp(0.0, 1.0),
                label: 'Risk Budget ($riskPct% of equity)',
                intent: riskPct <= 1.5
                    ? UiIntent.bullish
                    : (riskPct <= 2.5 ? UiIntent.warning : UiIntent.bearish),
              ),
              UiGap.v(theme.spacing.md),
            ],
            if (ladder.isNotEmpty) ...<Widget>[
              UiTable<Map<String, dynamic>>(
                stackOnMobile: true,
                pageSize: 6,
                density: UiDensity.compact,
                rows: ladder,
                columns: <UiTableColumn<Map<String, dynamic>>>[
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Level',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, ['label', 'multiple']) ??
                          'Target',
                      style: ctx.uiText.bodyStrong,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Price',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => Text(
                      PerplexityCardDataUtils.str(r, ['price', 'level']) ?? '—',
                      style: ctx.uiText.body,
                    ),
                  ),
                  UiTableColumn<Map<String, dynamic>>(
                    header: 'Profit',
                    cell: (BuildContext ctx, Map<String, dynamic> r) => UiBadge(
                      label: PerplexityCardDataUtils.str(r, [
                            'profit',
                            'gain',
                            'pnl',
                          ]) ??
                          '—',
                      intent: UiIntent.bullish,
                      size: UiSize.xs,
                    ),
                  ),
                ],
              ),
              UiGap.v(theme.spacing.sm),
            ],
            if (invalidation != null)
              UiCallout(
                title: 'Risk Rule',
                message: invalidation,
                intent: UiIntent.warning,
              ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Step-by-Step Workflow / Execution Playbook Card.
class PerplexityWorkflowCard extends StatefulWidget {
  const PerplexityWorkflowCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<PerplexityWorkflowCard> createState() => _PerplexityWorkflowCardState();
}

class _PerplexityWorkflowCardState extends State<PerplexityWorkflowCard> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String title =
        PerplexityCardDataUtils.str(widget.data, ['title', 'name']) ??
        'Step-by-Step Playbook';
    final List<Map<String, dynamic>> steps = PerplexityCardDataUtils.mapList(
      widget.data,
      ['steps', 'stages', 'phases', 'items'],
    );
    if (steps.isEmpty) return const SizedBox.shrink();
    final int current = _step.clamp(0, steps.length - 1);
    final Map<String, dynamic> active = steps[current];
    final String activeTitle =
        PerplexityCardDataUtils.str(active, ['title', 'step', 'name']) ??
        'Step ${current + 1}';
    final String? detail = PerplexityCardDataUtils.str(active, [
      'detail',
      'description',
      'action',
      'body',
    ]);
    final String? tip = PerplexityCardDataUtils.str(active, ['tip', 'rule']);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        headerDivider: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        title: title,
        leading: Icon(
          Icons.route_outlined,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.primary,
        ),
        trailing: UiBadge(
          label: 'Step ${current + 1}/${steps.length}',
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            UiStepper(
              currentStep: current,
              onStepTap: (int i) => setState(() => _step = i),
              steps: <UiStepperStep>[
                for (int i = 0; i < steps.length; i++)
                  UiStepperStep(
                    title:
                        PerplexityCardDataUtils.str(steps[i], [
                          'title',
                          'step',
                          'name',
                        ]) ??
                        'Step ${i + 1}',
                    subtitle: PerplexityCardDataUtils.str(steps[i], ['tag']),
                  ),
              ],
            ),
            UiGap.v(theme.spacing.md),
            UiCard(
              variant: UiCardVariant.subtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(activeTitle, style: context.uiText.title),
                  if (detail != null) ...<Widget>[
                    UiGap.v(theme.spacing.xs),
                    Text(detail, style: context.uiText.body),
                  ],
                  if (tip != null) ...<Widget>[
                    UiGap.v(theme.spacing.sm),
                    UiCallout(
                      title: 'Execution Tip',
                      message: tip,
                      intent: UiIntent.info,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
