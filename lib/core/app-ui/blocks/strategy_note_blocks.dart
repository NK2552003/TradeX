import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../theme/app_tokens.dart';
import '../cards/desk_record_card.dart';
import 'workbench_blocks.dart';

/// Strategy-note blocks — the presentation half of the playbook library.
///
/// A playbook is a *document with a track record*. Every block here shows both:
/// the rules the trader wrote and the numbers the journal produced while they
/// followed them. Performance is never entered by hand — it is aggregated from
/// the entries filed under the playbook, which is what makes the library honest.
///
/// Prefixed `AppStrategyNote*` to sit beside the existing `AppStrategyCard` and
/// friends, which render the strategy as a marketplace tile rather than a
/// document.

// ── Filtering ────────────────────────────────────────────────────────────────

/// Search, status, tag, instrument, favourites and sort for the playbook library.
///
/// Status leads because it is the only filter that changes what the numbers
/// *mean*: a retired playbook's win rate is history, a live one's is a claim
/// about tomorrow.
class AppStrategyNoteFilterBar extends StatelessWidget {
  const AppStrategyNoteFilterBar({
    super.key,
    this.compact = false,
    this.showSearch = true,
    this.showFilterControl = true,
    this.panelOnly = false,
    required this.query,
    required this.sort,
    this.status,
    this.tag,
    this.ticker,
    this.onlyFavorites = false,
    this.availableTags = const <String>[],
    this.availableTickers = const <String>[],
    this.onQueryChanged,
    this.onStatusChanged,
    this.onTagChanged,
    this.onTickerChanged,
    this.onSortChanged,
    this.onOnlyFavoritesChanged,
    this.onNew,
  });

  final bool compact;
  final bool showSearch;
  final bool showFilterControl;
  final bool panelOnly;
  final String query;
  final AppStrategySort sort;
  final AppStrategyStatus? status;
  final String? tag;
  final String? ticker;
  final bool onlyFavorites;
  final List<String> availableTags;
  final List<String> availableTickers;

  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<AppStrategyStatus?>? onStatusChanged;
  final ValueChanged<String?>? onTagChanged;
  final ValueChanged<String?>? onTickerChanged;
  final ValueChanged<AppStrategySort>? onSortChanged;
  final ValueChanged<bool>? onOnlyFavoritesChanged;
  final VoidCallback? onNew;

  int get activeCount =>
      (status == null ? 0 : 1) +
      (tag == null ? 0 : 1) +
      (ticker == null ? 0 : 1) +
      (onlyFavorites ? 1 : 0);

  Future<void> showFilters(BuildContext context) async {
    AppStrategyStatus? selectedStatus = status;
    String? selectedTag = tag;
    String? selectedTicker = ticker;
    bool selectedFavorites = onlyFavorites;
    AppStrategySort selectedSort = sort;

    await UiDrawer.show<void>(
      context,
      title: 'Playbook filters',
      child: StatefulBuilder(
        builder: (BuildContext panelContext, StateSetter updatePanel) =>
            AppStrategyNoteFilterBar(
              panelOnly: true,
              query: query,
              sort: selectedSort,
              status: selectedStatus,
              tag: selectedTag,
              ticker: selectedTicker,
              onlyFavorites: selectedFavorites,
              availableTags: availableTags,
              availableTickers: availableTickers,
              onStatusChanged: (AppStrategyStatus? value) => updatePanel(() {
                selectedStatus = value;
                onStatusChanged?.call(value);
              }),
              onTagChanged: (String? value) => updatePanel(() {
                selectedTag = value;
                onTagChanged?.call(value);
              }),
              onTickerChanged: (String? value) => updatePanel(() {
                selectedTicker = value;
                onTickerChanged?.call(value);
              }),
              onSortChanged: (AppStrategySort value) => updatePanel(() {
                selectedSort = value;
                onSortChanged?.call(value);
              }),
              onOnlyFavoritesChanged: (bool value) => updatePanel(() {
                selectedFavorites = value;
                onOnlyFavoritesChanged?.call(value);
              }),
            ),
      ),
    );
  }

  /// Status as a segmented control on desktop: four values, all worth one click.
  Widget _statusToggle(BuildContext context, {StateSetter? onAny}) {
    void fire(VoidCallback change) => onAny == null ? change() : onAny(change);
    return UiToggleGroup<String>(
      value: status?.name ?? 'all',
      size: UiSize.sm,
      allowEmpty: false,
      onChanged: (String value) => fire(
        () => onStatusChanged?.call(
          value == 'all' ? null : AppStrategyStatus.values.byName(value),
        ),
      ),
      options: <UiToggleOption<String>>[
        const UiToggleOption<String>(value: 'all', label: 'All'),
        for (final AppStrategyStatus s in AppStrategyStatus.values)
          UiToggleOption<String>(
            value: s.name,
            label: s.label,
            icon: s.icon,
            tooltip: s.label,
          ),
      ],
    );
  }

  Widget _sortField(
    BuildContext context, {
    bool expand = false,
    StateSetter? onAny,
  }) {
    final Widget select = UiSelect<AppStrategySort>(
      expand: expand,
      value: sort,
      leadingIcon: Icons.sort_rounded,
      size: expand ? UiSize.md : UiSize.sm,
      minWidth: expand ? null : context.sz(160),
      onChanged: (AppStrategySort value) {
        void apply() => onSortChanged?.call(value);
        onAny == null ? apply() : onAny(apply);
      },
      options: <UiOption<AppStrategySort>>[
        for (final AppStrategySort s in AppStrategySort.values)
          UiOption<AppStrategySort>(value: s, label: s.label),
      ],
    );
    return expand ? UiField(label: 'Sort by', child: select) : select;
  }

  Widget _tickerField(
    BuildContext context, {
    bool expand = false,
    StateSetter? onAny,
  }) {
    final Widget select = UiSelect<String>(
      expand: expand,
      value: ticker ?? 'all',
      hintText: 'Any instrument',
      leadingIcon: Icons.candlestick_chart_outlined,
      size: expand ? UiSize.md : UiSize.sm,
      minWidth: expand ? null : context.sz(150),
      onChanged: (String value) {
        void apply() => onTickerChanged?.call(value == 'all' ? null : value);
        onAny == null ? apply() : onAny(apply);
      },
      options: <UiOption<String>>[
        const UiOption<String>(value: 'all', label: 'Any instrument'),
        for (final String symbol in availableTickers)
          UiOption<String>(value: symbol, label: symbol),
      ],
    );
    return expand ? UiField(label: 'Instrument', child: select) : select;
  }

  Widget _tagDropField(
    BuildContext context, {
    bool expand = false,
    StateSetter? onAny,
  }) {
    final Widget select = UiSelect<String>(
      expand: expand,
      value: tag ?? 'all',
      hintText: 'Any tag',
      leadingIcon: Icons.sell_outlined,
      size: expand ? UiSize.md : UiSize.sm,
      onChanged: (String value) {
        void apply() => onTagChanged?.call(value == 'all' ? null : value);
        onAny == null ? apply() : onAny(apply);
      },
      options: <UiOption<String>>[
        const UiOption<String>(value: 'all', label: 'Any tag'),
        for (final String t in availableTags)
          UiOption<String>(value: t, label: '#$t'),
      ],
    );
    return expand ? UiField(label: 'Tag', child: select) : select;
  }

  Widget _favoriteToggle(BuildContext context, {StateSetter? onAny}) {
    void fire(VoidCallback change) => onAny == null ? change() : onAny(change);
    return UiBadge(
      label: 'Favourites',
      icon: Icons.star_rounded,
      intent: UiIntent.warning,
      variant: onlyFavorites ? UiBadgeVariant.solid : UiBadgeVariant.outline,
      onTap: () => fire(() => onOnlyFavoritesChanged?.call(!onlyFavorites)),
    );
  }

  /// One command row: search, one filter trigger, and an optional create icon.
  Widget _collapsedBar(BuildContext context) {
    final UiTheme theme = context.ui;
    if (!showSearch && !showFilterControl && onNew == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: <Widget>[
        if (showSearch)
          Expanded(
            child: UiInput.search(
              value: query,
              hintText: 'Search playbooks',
              size: UiSize.sm,
              onChanged: onQueryChanged,
            ),
          ),
        if (showSearch && (showFilterControl || onNew != null))
          SizedBox(width: context.sp(theme.spacing.xs)),
        if (showFilterControl)
          UiIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Playbook filters',
            badgeCount: activeCount == 0 ? null : activeCount,
            size: UiSize.sm,
            variant: UiVariant.soft,
            onPressed: () => showFilters(context),
          ),
        if (showFilterControl && onNew != null)
          SizedBox(width: context.sp(theme.spacing.xs)),
        if (onNew != null)
          UiIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New playbook',
            size: UiSize.sm,
            variant: UiVariant.primary,
            onPressed: onNew,
          ),
      ],
    );
  }

  Widget _panel(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Status', style: context.uiText.label),
        SizedBox(height: context.sp(theme.spacing.xs)),
        _statusToggle(context),
        SizedBox(height: context.sp(theme.spacing.md)),
        _sortField(context, expand: true),
        if (availableTickers.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          _tickerField(context, expand: true),
        ],
        if (availableTags.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          _tagDropField(context, expand: true),
        ],
        SizedBox(height: context.sp(theme.spacing.md)),
        Align(alignment: Alignment.centerLeft, child: _favoriteToggle(context)),
      ],
    );
  }

  Widget _wideBar(BuildContext context) => _collapsedBar(context);

  @override
  Widget build(BuildContext context) {
    if (panelOnly) return _panel(context);
    if (compact || context.uiRes.isMobile) return _collapsedBar(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) =>
          box.maxWidth < context.sz(680)
          ? _collapsedBar(context)
          : _wideBar(context),
    );
  }
}

// ── Summary ──────────────────────────────────────────────────────────────────

/// Library-level numbers: how many playbooks exist, how many are live, and what
/// the ones being traded have actually returned.
///
/// Primitives in, like [AppJournalNoteStatRow] — this layer cannot import the
/// feature code that computes them.
class AppStrategyNoteStatRow extends StatelessWidget {
  const AppStrategyNoteStatRow({
    super.key,
    required this.total,
    this.live = 0,
    this.testing = 0,
    this.drafts = 0,
    this.tradedEntries = 0,
    this.netPnl = 0,
    this.winRate = 0,
    this.unusedPlaybooks = 0,
    this.compact = false,
  });

  final int total;
  final int live;
  final int testing;
  final int drafts;

  /// Journal entries filed under any playbook in the slice.
  final int tradedEntries;
  final double netPnl;

  /// 0..1, across the traded entries rather than across playbooks — averaging
  /// win rates would weight a two-trade playbook like a two-hundred-trade one.
  ///
  /// Note the scale: this is a fraction, like [AppJournalNoteStatRow.winRate]
  /// and like the journal stats it is computed from, whereas a single
  /// `AppStrategy.winRate` is already a 0..100 percentage.
  final double winRate;

  /// Playbooks with no journal entries at all: rules nobody has tested.
  final int unusedPlaybooks;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool mobile = compact || context.uiRes.isMobile;
    // Denser than the old 132/150: a phone fits all four figures on one line
    // (92 × 4 clears a 390dp viewport) and a desktop reflows later, so the
    // strip never costs a second row before it has to.
    return UiStatStrip(
      minCellWidth: mobile ? 92 : 132,
      stats: <UiStat>[
        UiStat(label: 'Playbooks', value: '$total', hint: '$live live'),
        UiStat(
          label: 'Net P/L',
          value: AppTokens.signedMoney(netPnl),
          intent: AppTokens.plIntent(netPnl),
          hint: 'across $tradedEntries entries',
        ),
        UiStat(
          label: 'Win rate',
          value: AppTokens.percent(winRate * 100),
          intent: winRate >= 0.5 ? UiIntent.bullish : UiIntent.neutral,
        ),
        UiStat(
          label: 'Untested',
          value: '$unusedPlaybooks',
          hint: unusedPlaybooks == 0 ? 'all traded' : 'never traded',
          intent: unusedPlaybooks == 0 ? UiIntent.bullish : UiIntent.warning,
        ),
        if (!mobile) UiStat(label: 'In testing', value: '$testing'),
        if (!mobile) UiStat(label: 'Drafts', value: '$drafts'),
      ],
    );
  }
}

// ── Index rail (desktop) ─────────────────────────────────────────────────────

/// The library as a status-grouped list for the workbench rail.
///
/// Grouped by status, not by date: a trader opening the library is picking *which
/// set of rules to work on*, and "live" versus "draft" is the distinction that
/// answers that. Chronology is available through the sort.
class AppStrategyNoteIndexList extends StatelessWidget {
  const AppStrategyNoteIndexList({
    super.key,
    required this.strategies,
    this.selectedId,
    this.onOpen,
    this.onToggleFavorite,
    this.scrollController,
    this.groupByStatus = true,
    this.emptyState,
    this.padding,
  });

  final List<AppStrategy> strategies;
  final String? selectedId;
  final ValueChanged<AppStrategy>? onOpen;
  final ValueChanged<AppStrategy>? onToggleFavorite;
  final ScrollController? scrollController;

  /// Off when a sort other than status-neutral ordering is applied.
  final bool groupByStatus;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (strategies.isEmpty) {
      return emptyState ??
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(context.ui.spacing.md),
              vertical: context.sp(context.ui.spacing.xl),
            ),
            child: const UiEmptyState(
              icon: Icons.auto_awesome_mosaic_outlined,
              title: 'No playbooks match',
              message: 'Clear a filter, or write the setup you keep taking.',
            ),
          );
    }

    final List<_StrategyItem> items = <_StrategyItem>[];
    if (groupByStatus) {
      // Fixed order rather than first-seen: the library should read live →
      // testing → draft → retired every time, so the rail does not reshuffle
      // when a playbook is promoted.
      for (final AppStrategyStatus status in <AppStrategyStatus>[
        AppStrategyStatus.live,
        AppStrategyStatus.testing,
        AppStrategyStatus.draft,
        AppStrategyStatus.retired,
      ]) {
        final List<AppStrategy> group = strategies
            .where((AppStrategy s) => s.status == status)
            .toList(growable: false);
        if (group.isEmpty) continue;
        items.add(_StrategyItem.header(status, group.length));
        items.addAll(group.map(_StrategyItem.strategy));
      }
    } else {
      items.addAll(strategies.map(_StrategyItem.strategy));
    }

    return ListView.builder(
      controller: scrollController,
      padding: padding ?? EdgeInsets.only(bottom: context.uiPageBottomInset),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int i) {
        final _StrategyItem item = items[i];
        final AppStrategy? strategy = item.strategy;
        if (strategy == null) {
          return AppIndexSectionHeader(
            label: item.status!.label,
            icon: item.status!.icon,
            count: item.count,
          );
        }
        return AppStrategyNoteIndexRow(
          strategy: strategy,
          selected: strategy.id == selectedId,
          onTap: onOpen == null ? null : () => onOpen!(strategy),
          onToggleFavorite: onToggleFavorite == null
              ? null
              : () => onToggleFavorite!(strategy),
        );
      },
    );
  }
}

class _StrategyItem {
  const _StrategyItem.header(this.status, this.count) : strategy = null;
  _StrategyItem.strategy(this.strategy) : status = null, count = 0;

  final AppStrategyStatus? status;
  final int count;
  final AppStrategy? strategy;
}

/// One playbook in the rail.
///
/// The stripe is net P/L, not status — status is already the group header, and
/// what a trader wants from a glance down the list is which rules are making
/// money. A playbook with no trades gets no stripe and a warning flag: it is
/// untested, which is neither good nor bad, just unproven.
class AppStrategyNoteIndexRow extends StatelessWidget {
  const AppStrategyNoteIndexRow({
    super.key,
    required this.strategy,
    this.selected = false,
    this.onTap,
    this.onToggleFavorite,
  });

  final AppStrategy strategy;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final UiColors c = context.uiColors;
    final bool untested = strategy.trades == 0;

    return AppIndexRow(
      title: strategy.name,
      subtitle: strategy.summary?.trim().isNotEmpty == true
          ? strategy.summary
          : (strategy.category ?? 'No summary yet'),
      meta: untested
          ? '—'
          : AppTokens.signedMoney(strategy.netPnl, decimals: 0),
      metaColor: untested
          ? c.foregroundMuted
          : AppTokens.pl(context, strategy.netPnl),
      accent: untested ? null : AppTokens.pl(context, strategy.netPnl),
      icon: strategy.status.icon,
      selected: selected,
      onTap: onTap,
      warning: untested || !strategy.hasPlaybook,
      trailing: onToggleFavorite == null
          ? null
          : UiIconButton(
              icon: strategy.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: UiSize.xs,
              tooltip: strategy.isFavorite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              onPressed: onToggleFavorite,
            ),
      badges: <Widget>[
        if (!strategy.hasPlaybook)
          const UiBadge(
            label: 'No rules written',
            size: UiSize.xs,
            intent: UiIntent.warning,
            variant: UiBadgeVariant.soft,
          ),
        if (untested)
          const UiBadge(
            label: 'Untested',
            size: UiSize.xs,
            intent: UiIntent.info,
            variant: UiBadgeVariant.soft,
          )
        else
          UiBadge(
            label: '${strategy.trades} trades',
            size: UiSize.xs,
            variant: UiBadgeVariant.outline,
          ),
        if (!untested)
          UiBadge(
            label: AppTokens.percent(strategy.winRate, decimals: 0),
            size: UiSize.xs,
            icon: Icons.percent_rounded,
            intent: strategy.winRate >= 50
                ? UiIntent.bullish
                : UiIntent.neutral,
            variant: UiBadgeVariant.soft,
          ),
        if (strategy.versionCount > 1)
          UiBadge(
            label: 'v${strategy.versionCount}',
            size: UiSize.xs,
            icon: Icons.history_rounded,
            variant: UiBadgeVariant.outline,
          ),
      ],
    );
  }
}

// ── Cards (mobile) ───────────────────────────────────────────────────────────

/// A playbook as a document card — the phone's row.
///
/// Leads with the rules and ends with the record. `AppStrategyCard` does the
/// opposite because it sells a strategy to someone browsing the marketplace;
/// this one is read by the person who wrote it, who already knows the pitch and
/// wants to know whether it is working.
class AppStrategyNoteCard extends StatelessWidget {
  const AppStrategyNoteCard({
    super.key,
    required this.strategy,
    this.onTap,
    this.onToggleFavorite,
    this.selected = false,
    this.showExcerpt = true,
    this.linkedNoteCount,
    this.footerEngagement,
    this.density = AppNoteDensity.comfortable,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;
  final bool selected;
  final bool showExcerpt;

  /// Overrides `strategy.linkedNoteIds.length` when the graph knows about edges
  /// stored on the note side.
  final int? linkedNoteCount;

  /// Optional engagement row (views, likes, comments, post link).
  final Widget? footerEngagement;

  final AppNoteDensity density;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final bool untested = strategy.trades == 0;
    final Color accent = strategy.status.intent.color(context);
    final String excerpt = AppMarkdownStats.excerpt(
      strategy.content.trim().isEmpty
          ? (strategy.summary ?? '')
          : strategy.content,
      maxChars: 160,
    );
    final int notes = linkedNoteCount ?? strategy.linkedNoteIds.length;
    final TextStyle metaStyle = context.uiText.caption.copyWith(
      color: c.foregroundSubtle,
    );

    final Set<String> seenTags = <String>{};
    final String lowerName = strategy.name.trim().toLowerCase();
    final String lowerStatus = strategy.status.label.toLowerCase();
    final String lowerCategory = (strategy.category ?? '').trim().toLowerCase();

    final List<Widget> uniqueTags = <Widget>[];
    for (final String rawTag in strategy.tags) {
      final String clean = rawTag.replaceAll('#', '').trim();
      final String lower = clean.toLowerCase();
      if (clean.isEmpty) continue;
      if (lower == lowerName ||
          lower == lowerStatus ||
          lower == lowerCategory) {
        continue;
      }
      if (seenTags.add(lower)) {
        uniqueTags.add(
          UiBadge(
            label: '#$clean',
            variant: UiBadgeVariant.ghost,
            size: UiSize.xs,
          ),
        );
      }
    }

    final double effectiveWinRate = strategy.winRate > 1
        ? strategy.winRate
        : strategy.winRate * 100;

    return AppDeskRecordCard(
      category: null,
      accentColor: accent,
      title: strategy.name,
      preview: showExcerpt && excerpt.isNotEmpty
          ? Text(
              excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: c.foregroundMuted,
                height: 1.45,
              ),
            )
          : null,
      showPreview: showExcerpt,
      density: density,
      selected: selected,
      onTap: onTap,
      semanticLabel: 'Playbook: ${strategy.name}',
      trailingHeader: onToggleFavorite != null
          ? UiIconButton(
              icon: strategy.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: UiSize.xs,
              tooltip: strategy.isFavorite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              onPressed: onToggleFavorite,
            )
          : null,
      badges: <Widget>[
        UiBadge(
          label: strategy.status.label,
          size: UiSize.xs,
          icon: strategy.status.icon,
          intent: strategy.status.intent,
          variant: UiBadgeVariant.soft,
        ),
        if (!untested) ...<Widget>[
          UiBadge(
            label: '${effectiveWinRate.toStringAsFixed(0)}% win',
            size: UiSize.xs,
            intent: effectiveWinRate >= 50
                ? UiIntent.success
                : UiIntent.warning,
            variant: UiBadgeVariant.soft,
          ),
          UiBadge(
            label: AppTokens.signedMoney(strategy.netPnl, decimals: 0),
            size: UiSize.xs,
            intent: AppTokens.plIntent(strategy.netPnl),
            variant: UiBadgeVariant.soft,
          ),
        ],
        if (!strategy.hasPlaybook)
          const UiBadge(
            label: 'No rules written',
            size: UiSize.xs,
            icon: Icons.edit_note_rounded,
            intent: UiIntent.warning,
            variant: UiBadgeVariant.soft,
          ),
        if (untested)
          const UiBadge(
            label: 'Untested',
            size: UiSize.xs,
            intent: UiIntent.info,
            variant: UiBadgeVariant.soft,
          ),
        if (notes > 0)
          UiBadge(
            label: '$notes note${notes == 1 ? '' : 's'}',
            size: UiSize.xs,
            icon: Icons.link_rounded,
            variant: UiBadgeVariant.outline,
          ),
        if (strategy.versionCount > 1)
          UiBadge(
            label: '${strategy.versionCount} revisions',
            size: UiSize.xs,
            icon: Icons.history_rounded,
            variant: UiBadgeVariant.outline,
          ),
      ],
      tags: uniqueTags,
      footerMetadata: <Widget>[
        Text(
          AppTokens.relativeTime(strategy.updatedAt ?? DateTime.now()),
          style: metaStyle,
        ),
        Text('·', style: metaStyle),
        Text(
          untested ? 'No trades logged' : '${strategy.trades} trades logged',
          style: metaStyle,
        ),
      ],
      footerEngagement: footerEngagement,
    );
  }
}

/// The track record, aggregated from the journal.
///
/// Renders "Untested" rather than a row of zeros when nothing has been traded
/// under the playbook. `0.0%` win rate over no trades is a false statement, and
/// a library full of them trains the trader to ignore the whole column.
class AppStrategyNotePerformance extends StatelessWidget {
  const AppStrategyNotePerformance({
    super.key,
    required this.strategy,
    this.dense = false,
    this.showCurve = true,
  });

  final AppStrategy strategy;

  /// Card mode: four figures on one line, no chart frame.
  final bool dense;
  final bool showCurve;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    if (strategy.trades == 0) {
      return UiCallout(
        intent: UiIntent.info,
        icon: Icons.science_outlined,
        title: 'No trades filed yet',
        message: dense
            ? null
            : 'File a journal entry under this playbook and its win rate, '
                  'average R and equity curve appear here automatically.',
      );
    }

    final List<UiStat> stats = <UiStat>[
      UiStat(
        label: 'Net P/L',
        value: AppTokens.signedMoney(strategy.netPnl, decimals: 0),
        intent: AppTokens.plIntent(strategy.netPnl),
        spark: showCurve && strategy.equityCurve.length >= 3
            ? strategy.equityCurve
            : null,
      ),
      UiStat(
        label: 'Win rate',
        value: AppTokens.percent(strategy.winRate, decimals: 0),
        intent: strategy.winRate >= 50 ? UiIntent.bullish : UiIntent.neutral,
      ),
      UiStat(
        label: 'Avg R',
        value: AppTokens.rr(strategy.avgR),
        intent: AppTokens.plIntent(strategy.avgR),
      ),
      UiStat(label: 'Trades', value: '${strategy.trades}'),
    ];

    if (dense) {
      return UiStatStrip(stats: stats, minCellWidth: 92, showSpark: false);
    }

    return UiCard(
      title: 'Track record',
      subtitle: 'Aggregated from the journal entries filed under this playbook',
      variant: UiCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiStatStrip(stats: stats, minCellWidth: 132),
          if (showCurve && strategy.equityCurve.length >= 3) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Text('Equity curve', style: uiOverline(context)),
            SizedBox(height: context.sp(theme.spacing.xs)),
            SizedBox(
              height: context.sz(96),
              child: UiSparkChart(
                values: strategy.equityCurve,
                color: AppTokens.pl(context, strategy.netPnl),
                filled: true,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              'Running P/L of every entry filed under this playbook, oldest '
              'first.',
              style: context.uiText.caption.copyWith(color: c.foregroundMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The phone and tablet reading of the library: status headers over a column of
/// [AppStrategyNoteCard]s, two-up on a tablet.
class AppStrategyNoteGrid extends StatelessWidget {
  const AppStrategyNoteGrid({
    super.key,
    required this.strategies,
    this.onOpen,
    this.onToggleFavorite,
    this.selectedId,
    this.groupByStatus = true,
    this.showExcerpt = true,
    this.linkedNoteCounts = const <String, int>{},
    this.emptyState,
    this.padding,
    this.header,
  });

  final List<AppStrategy> strategies;
  final ValueChanged<AppStrategy>? onOpen;
  final ValueChanged<AppStrategy>? onToggleFavorite;
  final String? selectedId;
  final bool groupByStatus;
  final bool showExcerpt;
  final Map<String, int> linkedNoteCounts;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;

  /// Scrolls with the list.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    // One step tighter than md: cards sit in a list, and the gap between them
    // competes with the group headers that structure the list.
    final double gap = context.sp(theme.spacing.sm);
    final int columns = context.uiRes.columns(mobile: 1, tablet: 2, desktop: 2);

    final List<Widget> children = <Widget>[
      ?header,
      if (strategies.isEmpty)
        emptyState ??
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xl),
              ),
              child: const UiEmptyState(
                icon: Icons.auto_awesome_mosaic_outlined,
                title: 'No playbooks yet',
                message:
                    'Write down the setup you keep taking. Once entries are '
                    'filed under it, its track record fills itself in.',
              ),
            ),
    ];

    void addRows(List<AppStrategy> batch) {
      for (int i = 0; i < batch.length; i += columns) {
        final List<AppStrategy> row = batch.sublist(
          i,
          (i + columns).clamp(0, batch.length),
        );
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: columns == 1
                ? _card(row.first)
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (int j = 0; j < columns; j++) ...<Widget>[
                          if (j > 0) SizedBox(width: gap),
                          Expanded(
                            child: j < row.length
                                ? _card(row[j])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      }
    }

    if (groupByStatus) {
      for (final AppStrategyStatus status in <AppStrategyStatus>[
        AppStrategyStatus.live,
        AppStrategyStatus.testing,
        AppStrategyStatus.draft,
        AppStrategyStatus.retired,
      ]) {
        final List<AppStrategy> group = strategies
            .where((AppStrategy s) => s.status == status)
            .toList(growable: false);
        if (group.isEmpty) continue;
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: _GroupLabel(label: status.label, icon: status.icon),
          ),
        );
        addRows(group);
      }
    } else {
      addRows(strategies);
    }

    return ListView(
      padding:
          padding ??
          EdgeInsets.fromLTRB(gap, gap, gap, context.uiPageBottomInset),
      children: children,
    );
  }

  Widget _card(AppStrategy strategy) => AppStrategyNoteCard(
    strategy: strategy,
    selected: strategy.id == selectedId,
    showExcerpt: showExcerpt,
    linkedNoteCount: linkedNoteCounts[strategy.id],
    onTap: onOpen == null ? null : () => onOpen!(strategy),
    onToggleFavorite: onToggleFavorite == null
        ? null
        : () => onToggleFavorite!(strategy),
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      if (icon != null) ...<Widget>[
        Icon(
          icon,
          size: context.sz(13),
          color: context.uiColors.foregroundMuted,
        ),
        SizedBox(width: context.sp(context.ui.spacing.xs)),
      ],
      Text(label.toUpperCase(), style: uiOverline(context)),
      SizedBox(width: context.sp(context.ui.spacing.xs)),
      Expanded(
        child: SizedBox(
          height: context.ui.borders.hairline,
          child: ColoredBox(color: context.uiColors.border),
        ),
      ),
    ],
  );
}

// ── Document ─────────────────────────────────────────────────────────────────

/// The masthead of an open playbook.
///
/// Status is editable from here because promoting a playbook from testing to
/// live is the single most consequential edit a trader makes to it, and burying
/// that behind an edit screen means it never gets updated.
class AppStrategyNoteHeader extends StatelessWidget {
  const AppStrategyNoteHeader({
    super.key,
    required this.strategy,
    this.onBack,
    this.actions = const <Widget>[],
    this.onStatusChanged,
    this.onToggleFavorite,
    this.onToggleVisibility,
    this.showTitle = true,
  });

  final AppStrategy strategy;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// Null renders status as a read-only badge.
  final ValueChanged<AppStrategyStatus>? onStatusChanged;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onToggleVisibility;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final bool embedded = AppWorkbenchScope.hasEmbeddedHeader(context);
    final bool inWorkbench = AppWorkbenchScope.of(context);
    final bool isDesktop = context.uiRes.isDesktop;
    final bool showBackButton = !isDesktop && !embedded && !inWorkbench && onBack != null;
    final bool shouldDisplayTitle = showTitle;

    final List<Widget> allActions = [
      if (onToggleFavorite != null)
        UiIconButton(
          icon: strategy.isFavorite
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          tooltip: strategy.isFavorite
              ? 'Remove from favourites'
              : 'Add to favourites',
          onPressed: onToggleFavorite,
        ),
      ...actions,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (shouldDisplayTitle)
          UiHeader(
            title: strategy.name,
            leading: showBackButton
                ? UiIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to the library',
                    onPressed: onBack,
                  )
                : null,
            actions: allActions,
          )
        else if (allActions.isNotEmpty || showBackButton)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showBackButton)
                  UiIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to the library',
                    onPressed: onBack,
                  )
                else
                  const SizedBox.shrink(),
                Row(mainAxisSize: MainAxisSize.min, children: allActions),
              ],
            ),
          ),
        if (strategy.summary?.trim().isNotEmpty == true) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            strategy.summary!,
            style: context.uiText.body.copyWith(color: c.foregroundMuted),
          ),
        ],
        SizedBox(height: context.sp(theme.spacing.xs)),
        if (onStatusChanged == null)
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                UiBadge(
                  label: strategy.status.label,
                  size: UiSize.xs,
                  icon: strategy.status.icon,
                  intent: strategy.status.intent,
                  variant: UiBadgeVariant.soft,
                ),
                ..._metaBadges(context, theme, c),
              ],
            ),
          )
        else ...<Widget>[
          UiSelect<AppStrategyStatus>(
            value: strategy.status,
            size: UiSize.sm,
            expand: true,
            leadingIcon: strategy.status.icon,
            onChanged: onStatusChanged,
            options: <UiOption<AppStrategyStatus>>[
              for (final AppStrategyStatus s in AppStrategyStatus.values)
                UiOption<AppStrategyStatus>(
                  value: s,
                  label: s.label,
                  icon: s.icon,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _metaBadges(context, theme, c),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _metaBadges(BuildContext context, UiTheme theme, UiColors c) =>
      <Widget>[
        UiBadge(
          label: strategy.isPublic ? 'Public' : 'Private',
          size: UiSize.xs,
          icon: strategy.isPublic
              ? Icons.public_rounded
              : Icons.lock_outline_rounded,
          variant: UiBadgeVariant.outline,
          onTap: onToggleVisibility,
        ),
        UiBadge(
          label: 'v${strategy.versionCount}',
          size: UiSize.xs,
          icon: Icons.history_rounded,
          variant: UiBadgeVariant.outline,
        ),
        if (strategy.updatedAt != null)
          Text(
            'Edited ${AppTokens.relativeTime(strategy.updatedAt!)}',
            style: context.uiText.caption.copyWith(color: c.foregroundMuted),
          ),
        for (final String tag in strategy.tags)
          UiBadge(
            label: '#$tag',
            size: UiSize.xs,
            intent: UiIntent.primary,
            variant: UiBadgeVariant.outline,
          ),
      ];
}

/// Revision history for a playbook.
///
/// A playbook is the one document in the app where *what it used to say* matters:
/// a win rate is only meaningful next to the rules that were in force while it
/// was earned. So every revision keeps its full body, and this list is how the
/// trader gets back to one.
class AppStrategyNoteVersionList extends StatelessWidget {
  const AppStrategyNoteVersionList({
    super.key,
    required this.versions,
    this.onView,
    this.onRestore,
    this.onCompare,
    this.selectedId,
    this.emptyState,
  });

  final List<AppStrategyVersion> versions;
  final ValueChanged<AppStrategyVersion>? onView;
  final ValueChanged<AppStrategyVersion>? onRestore;
  final ValueChanged<AppStrategyVersion>? onCompare;
  final String? selectedId;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    if (versions.isEmpty) {
      return emptyState ??
          const UiEmptyState(
            icon: Icons.history_rounded,
            title: 'One revision so far',
            message:
                'Save with a changelog line and the previous rules are kept '
                'here, body and all.',
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final AppStrategyVersion v in versions)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: UiCard(
              variant: UiCardVariant.outlined,
              density: UiDensity.compact,
              selected: v.id == selectedId,
              onTap: onView == null ? null : () => onView!(v),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              v.label,
                              style: context.uiText.bodyStrong.copyWith(
                                color: c.foreground,
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            if (v.isCurrent)
                              const UiBadge(
                                label: 'Current',
                                size: UiSize.xs,
                                intent: UiIntent.success,
                                variant: UiBadgeVariant.soft,
                              ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          v.note?.trim().isNotEmpty == true
                              ? v.note!
                              : 'No changelog line',
                          style: context.uiText.caption.copyWith(
                            color: c.foregroundMuted,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          <String>[
                            AppTokens.stamp(v.savedAt),
                            '${v.wordCount} words',
                            if (v.author != null) v.author!,
                          ].join(' · '),
                          style: context.uiText.caption.copyWith(
                            color: c.foregroundSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onCompare != null)
                    UiIconButton(
                      icon: Icons.compare_arrows_rounded,
                      size: UiSize.xs,
                      tooltip: 'Compare with current',
                      onPressed: () => onCompare!(v),
                    ),
                  if (onRestore != null && !v.isCurrent)
                    UiIconButton(
                      icon: Icons.restore_rounded,
                      size: UiSize.xs,
                      tooltip: 'Restore this revision',
                      onPressed: () => onRestore!(v),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
