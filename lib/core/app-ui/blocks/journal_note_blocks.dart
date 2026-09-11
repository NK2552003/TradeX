import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../theme/app_tokens.dart';
import '../cards/desk_record_card.dart';
import 'workbench_blocks.dart';

/// Journal-note blocks — the presentation half of the trade journal.
///
/// A journal entry is a trade *and* its write-up, so these blocks always render
/// both halves: the numbers give the row its colour and its scan value, the words
/// give it its reason for existing. A row that shows only P/L is a broker
/// statement; the whole point of this surface is the sentence next to it.
///
/// Prefixed `AppJournalNote*` to sit beside the older `AppJournal*` and `AppTrade*`
/// blocks — those render the trade log, these render the journal as documents.

/// Iconography for outcome badges, shared by every journal surface that names
/// an outcome: rows, cards and document headers all render the same shape —
/// [UiBadgeVariant.soft], [UiSize.xs], [AppTokens.outcomeIntent] and one of
/// these icons — so a Win reads identically wherever it appears. The playbook
/// status badges use the same soft/xs/icon recipe with `AppStrategyStatus`.
IconData _outcomeIcon(AppOutcome outcome) => switch (outcome) {
  AppOutcome.win => Icons.check_circle_outline_rounded,
  AppOutcome.loss => Icons.cancel_outlined,
  AppOutcome.breakeven => Icons.remove_circle_outline_rounded,
  AppOutcome.open => Icons.schedule_rounded,
};

// ── Filtering ────────────────────────────────────────────────────────────────

/// Search, outcome, sort, tag and the two review prompts in one bar.
///
/// The two toggles are the reason this is not a generic filter bar. "Needs
/// write-up" and "Unfiled" are the questions a journal exists to answer — which
/// trades did I never explain, and which did I take without a plan — so they get
/// permanent controls rather than living inside a menu.
class AppJournalNoteFilterBar extends StatelessWidget {
  const AppJournalNoteFilterBar({
    super.key,
    this.compact = false,
    this.showSearch = true,
    this.showFilterControl = true,
    this.panelOnly = false,
    required this.query,
    required this.sort,
    this.outcome,
    this.tag,
    this.ticker,
    this.onlyUnwritten = false,
    this.onlyUnfiled = false,
    this.availableTags = const <String>[],
    this.availableTickers = const <String>[],
    this.onQueryChanged,
    this.onOutcomeChanged,
    this.onTagChanged,
    this.onTickerChanged,
    this.onSortChanged,
    this.onOnlyUnwrittenChanged,
    this.onOnlyUnfiledChanged,
    this.onNew,
  });

  final bool compact;
  final bool showSearch;
  final bool showFilterControl;
  final bool panelOnly;
  final String query;
  final AppJournalSort sort;
  final AppOutcome? outcome;
  final String? tag;
  final String? ticker;

  /// Show only entries with no markdown body.
  final bool onlyUnwritten;

  /// Show only entries with no playbook attached.
  final bool onlyUnfiled;

  final List<String> availableTags;
  final List<String> availableTickers;

  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<AppOutcome?>? onOutcomeChanged;
  final ValueChanged<String?>? onTagChanged;
  final ValueChanged<String?>? onTickerChanged;
  final ValueChanged<AppJournalSort>? onSortChanged;
  final ValueChanged<bool>? onOnlyUnwrittenChanged;
  final ValueChanged<bool>? onOnlyUnfiledChanged;
  final VoidCallback? onNew;

  int get activeCount =>
      (outcome == null ? 0 : 1) +
      (tag == null ? 0 : 1) +
      (ticker == null ? 0 : 1) +
      (onlyUnwritten ? 1 : 0) +
      (onlyUnfiled ? 1 : 0);

  Future<void> showFilters(BuildContext context) async {
    AppOutcome? selectedOutcome = outcome;
    String? selectedTag = tag;
    String? selectedTicker = ticker;
    bool selectedUnwritten = onlyUnwritten;
    bool selectedUnfiled = onlyUnfiled;
    AppJournalSort selectedSort = sort;

    await UiDrawer.show<void>(
      context,
      title: 'Journal filters',
      child: StatefulBuilder(
        builder: (BuildContext panelContext, StateSetter updatePanel) =>
            AppJournalNoteFilterBar(
              panelOnly: true,
              query: query,
              sort: selectedSort,
              outcome: selectedOutcome,
              tag: selectedTag,
              ticker: selectedTicker,
              onlyUnwritten: selectedUnwritten,
              onlyUnfiled: selectedUnfiled,
              availableTags: availableTags,
              availableTickers: availableTickers,
              onOutcomeChanged: (AppOutcome? value) => updatePanel(() {
                selectedOutcome = value;
                onOutcomeChanged?.call(value);
              }),
              onTagChanged: (String? value) => updatePanel(() {
                selectedTag = value;
                onTagChanged?.call(value);
              }),
              onTickerChanged: (String? value) => updatePanel(() {
                selectedTicker = value;
                onTickerChanged?.call(value);
              }),
              onSortChanged: (AppJournalSort value) => updatePanel(() {
                selectedSort = value;
                onSortChanged?.call(value);
              }),
              onOnlyUnwrittenChanged: (bool value) => updatePanel(() {
                selectedUnwritten = value;
                onOnlyUnwrittenChanged?.call(value);
              }),
              onOnlyUnfiledChanged: (bool value) => updatePanel(() {
                selectedUnfiled = value;
                onOnlyUnfiledChanged?.call(value);
              }),
            ),
      ),
    );
  }

  /// Built once and used by both surfaces. [onAny] lets the mobile sheet rebuild
  /// itself after a change that the parent screen also handles — without it the
  /// sheet would show stale selections until it was reopened.
  Widget _outcomeField(
    BuildContext context, {
    bool expand = false,
    StateSetter? onAny,
  }) {
    final Widget select = UiSelect<String>(
      expand: expand,
      value: outcome?.name ?? 'all',
      hintText: 'Any outcome',
      leadingIcon: Icons.filter_alt_outlined,
      size: expand ? UiSize.md : UiSize.sm,
      minWidth: expand ? null : context.sz(150),
      onChanged: (String value) {
        final AppOutcome? next = value == 'all'
            ? null
            : AppOutcome.values.byName(value);
        void apply() => onOutcomeChanged?.call(next);
        onAny == null ? apply() : onAny(apply);
      },
      options: <UiOption<String>>[
        const UiOption<String>(value: 'all', label: 'Any outcome'),
        for (final AppOutcome o in AppOutcome.values)
          UiOption<String>(value: o.name, label: AppTokens.outcomeLabel(o)),
      ],
    );
    return expand ? UiField(label: 'Outcome', child: select) : select;
  }

  Widget _sortField(
    BuildContext context, {
    bool expand = false,
    StateSetter? onAny,
  }) {
    final Widget select = UiSelect<AppJournalSort>(
      expand: expand,
      value: sort,
      leadingIcon: Icons.sort_rounded,
      size: expand ? UiSize.md : UiSize.sm,
      minWidth: expand ? null : context.sz(160),
      onChanged: (AppJournalSort value) {
        void apply() => onSortChanged?.call(value);
        onAny == null ? apply() : onAny(apply);
      },
      options: <UiOption<AppJournalSort>>[
        for (final AppJournalSort s in AppJournalSort.values)
          UiOption<AppJournalSort>(value: s, label: s.label),
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

  /// The two review prompts, as toggle chips. Rendered as badges rather than a
  /// segmented control because they compose: "no write-up **and** no playbook"
  /// is the worst state an entry can be in, and it is the one worth looking at
  /// first. Returned as a list so the wide bar can lay them into the same wrap
  /// row as the selects.
  List<Widget> _promptToggles(BuildContext context, {StateSetter? onAny}) {
    void fire(VoidCallback change) => onAny == null ? change() : onAny(change);
    return <Widget>[
      UiBadge(
        label: 'Needs write-up',
        icon: Icons.edit_note_rounded,
        intent: UiIntent.warning,
        variant: onlyUnwritten ? UiBadgeVariant.solid : UiBadgeVariant.outline,
        onTap: () => fire(() => onOnlyUnwrittenChanged?.call(!onlyUnwritten)),
      ),
      UiBadge(
        label: 'Unfiled',
        icon: Icons.folder_off_outlined,
        intent: UiIntent.info,
        variant: onlyUnfiled ? UiBadgeVariant.solid : UiBadgeVariant.outline,
        onTap: () => fire(() => onOnlyUnfiledChanged?.call(!onlyUnfiled)),
      ),
    ];
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
              hintText: 'Search journal',
              size: UiSize.sm,
              onChanged: onQueryChanged,
            ),
          ),
        if (showSearch && (showFilterControl || onNew != null))
          SizedBox(width: context.sp(theme.spacing.xs)),
        if (showFilterControl)
          UiIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Journal filters',
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
            tooltip: 'New entry',
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
        _outcomeField(context, expand: true),
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
        Text('Review state', style: context.uiText.label),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          children: _promptToggles(context),
        ),
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

/// The headline numbers above the journal.
///
/// Takes primitives, not a stats object: this layer must not import `features/`,
/// and the numbers are computed there. The trade-off is a longer constructor in
/// exchange for a block that any caller — including a widget test — can render
/// without building a repository.
class AppJournalNoteStatRow extends StatelessWidget {
  const AppJournalNoteStatRow({
    super.key,
    required this.total,
    required this.netPnl,
    required this.winRate,
    this.open = 0,
    this.avgR = 0,
    this.written = 0,
    this.unfiled = 0,
    this.equityCurve = const <double>[],
    this.compact = false,
  });

  final int total;
  final int open;
  final double netPnl;

  /// 0..1.
  final double winRate;
  final double avgR;

  /// Entries carrying a write-up. The gap to [total] is the prompt.
  final int written;
  final int unfiled;

  /// Running P/L for the slice on screen, oldest first. Drawn as a spark under
  /// net P/L when there are enough closed trades to make a shape.
  final List<double> equityCurve;

  /// Phones show four cells, desktops six: the strip reflows on its own, but on
  /// a phone the extra two push the list below the fold.
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
        UiStat(
          label: 'Net P/L',
          value: AppTokens.signedMoney(netPnl),
          intent: AppTokens.plIntent(netPnl),
          spark: equityCurve.length >= 3 ? equityCurve : null,
          hint: open == 0 ? null : '$open still open',
        ),
        UiStat(
          label: 'Win rate',
          value: AppTokens.percent(winRate * 100),
          intent: winRate >= 0.5 ? UiIntent.bullish : UiIntent.neutral,
        ),
        UiStat(
          label: 'Avg R',
          value: AppTokens.rr(avgR),
          intent: AppTokens.plIntent(avgR),
        ),
        UiStat(label: 'Entries', value: '$total'),
        if (!mobile)
          UiStat(
            label: 'Written up',
            value: '$written / $total',
            hint: total == 0
                ? null
                : '${AppTokens.percent(written / total * 100, decimals: 0)} '
                      'covered',
            intent: total > 0 && written < total
                ? UiIntent.warning
                : UiIntent.bullish,
          ),
        if (!mobile)
          UiStat(
            label: 'Unfiled',
            value: '$unfiled',
            hint: unfiled == 0 ? 'every trade has a plan' : 'no playbook',
            intent: unfiled == 0 ? UiIntent.bullish : UiIntent.info,
          ),
      ],
    );
  }
}

// ── Index rail (desktop) ─────────────────────────────────────────────────────

/// The journal as a dense, month-grouped list for the workbench rail.
///
/// Grouping is by month rather than by day: a trader takes a handful of trades a
/// week, so day headers would outnumber entries. Each row carries a P/L-coloured
/// stripe, so the shape of a month is visible before a single title is read.
class AppJournalNoteIndexList extends StatelessWidget {
  const AppJournalNoteIndexList({
    super.key,
    required this.entries,
    this.selectedId,
    this.onOpen,
    this.scrollController,
    this.groupByMonth = true,
    this.emptyState,
    this.padding,
  });

  final List<AppTrade> entries;
  final String? selectedId;
  final ValueChanged<AppTrade>? onOpen;
  final ScrollController? scrollController;

  /// Off when a sort other than chronological is applied — month headers over a
  /// list ordered by P/L would be lying about the grouping.
  final bool groupByMonth;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;

  static String _monthLabel(DateTime date) {
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return emptyState ??
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(context.ui.spacing.md),
              vertical: context.sp(context.ui.spacing.xl),
            ),
            child: const UiEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No entries match',
              message: 'Clear a filter, or log the trade you just closed.',
            ),
          );
    }

    // Flattened once so the list can stay a builder: forty entries is nothing,
    // but four hundred with a Column would build every row on every frame.
    final List<_IndexItem> items = <_IndexItem>[];
    String lastGroup = '';
    for (final AppTrade entry in entries) {
      if (groupByMonth) {
        final String group = _monthLabel(entry.sortDate);
        if (group != lastGroup) {
          lastGroup = group;
          items.add(_IndexItem.header(group));
        }
      }
      items.add(_IndexItem.entry(entry));
    }

    return ListView.builder(
      controller: scrollController,
      padding: padding ?? EdgeInsets.only(bottom: context.uiPageBottomInset),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int i) {
        final _IndexItem item = items[i];
        final AppTrade? entry = item.entry;
        if (entry == null) {
          return AppIndexSectionHeader(
            label: item.label,
            count: entries
                .where((AppTrade t) => _monthLabel(t.sortDate) == item.label)
                .length,
          );
        }
        return AppJournalNoteIndexRow(
          entry: entry,
          selected: entry.id == selectedId,
          onTap: onOpen == null ? null : () => onOpen!(entry),
        );
      },
    );
  }
}

class _IndexItem {
  const _IndexItem.header(this.label) : entry = null;
  _IndexItem.entry(this.entry) : label = '';

  final String label;
  final AppTrade? entry;
}

/// One journal entry in the rail.
///
/// Thin wrapper over [AppIndexRow] that decides what a journal row *means*: the
/// stripe is P/L, the warning state is "no write-up", and the badges are the two
/// things a trader needs to see without opening the entry — whether it is filed,
/// and whether anything is attached to it.
class AppJournalNoteIndexRow extends StatelessWidget {
  const AppJournalNoteIndexRow({
    super.key,
    required this.entry,
    this.selected = false,
    this.onTap,
  });

  final AppTrade entry;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiColors c = context.uiColors;
    final bool unfiled = entry.strategyId == null || entry.strategyId!.isEmpty;
    final String side = AppTokens.sideLabel(entry.side);

    return AppIndexRow(
      title: entry.displayTitle,
      subtitle:
          '$side · ${AppTokens.shortDate(entry.sortDate)}'
          '${entry.strategy == null ? '' : ' · ${entry.strategy}'}',
      meta: entry.isOpen
          ? 'Open'
          : AppTokens.signedMoney(entry.pnl, decimals: 0),
      metaColor: entry.isOpen ? c.info : AppTokens.pl(context, entry.pnl),
      accent: entry.isOpen ? c.info : AppTokens.pl(context, entry.pnl),
      selected: selected,
      onTap: onTap,
      warning: !entry.hasStory,
      badges: <Widget>[
        if (!entry.hasStory)
          const UiBadge(
            label: 'No write-up',
            size: UiSize.xs,
            intent: UiIntent.warning,
            variant: UiBadgeVariant.soft,
          ),
        if (unfiled)
          const UiBadge(
            label: 'Unfiled',
            size: UiSize.xs,
            intent: UiIntent.info,
            variant: UiBadgeVariant.soft,
          ),
        if (entry.linkedNoteIds.isNotEmpty)
          UiBadge(
            label:
                '${entry.linkedNoteIds.length} note'
                '${entry.linkedNoteIds.length == 1 ? '' : 's'}',
            size: UiSize.xs,
            icon: Icons.link_rounded,
            variant: UiBadgeVariant.outline,
          ),
        if (entry.rMultiple != null)
          UiBadge(
            label: AppTokens.rr(entry.rMultiple!),
            size: UiSize.xs,
            intent: AppTokens.plIntent(entry.rMultiple!),
            variant: UiBadgeVariant.soft,
          ),
      ],
    );
  }
}

// ── Cards (mobile) ───────────────────────────────────────────────────────────

/// A journal entry as a document card — the phone's row.
///
/// [AppTradeCard] already renders a trade well, but it leads with the numbers,
/// which is the trade-log reading. This leads with the trader's headline and the
/// first lines of what they wrote, and puts P/L, R and the tape underneath: the
/// journal reading of the same record.
class AppJournalNoteCard extends StatelessWidget {
  const AppJournalNoteCard({
    super.key,
    required this.entry,
    this.onTap,
    this.selected = false,
    this.showExcerpt = true,
    this.trailing,
    this.linkedNoteCount,
    this.footerEngagement,
    this.density = AppNoteDensity.comfortable,
  });

  final AppTrade entry;
  final VoidCallback? onTap;
  final bool selected;

  /// Off in the densest list mode, where titles alone fit more entries.
  final bool showExcerpt;
  final Widget? trailing;

  /// Overrides `entry.linkedNoteIds.length` when the caller has resolved the
  /// graph and knows about edges stored on the note side too.
  final int? linkedNoteCount;

  /// Optional engagement row (views, likes, comments, post link).
  final Widget? footerEngagement;

  final AppNoteDensity density;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final Color pl = entry.isOpen ? c.info : AppTokens.pl(context, entry.pnl);
    final String excerpt = AppMarkdownStats.excerpt(
      entry.content.trim().isEmpty ? (entry.notes ?? '') : entry.content,
      maxChars: 160,
    );
    final int notes = linkedNoteCount ?? entry.linkedNoteIds.length;
    final bool unfiled = entry.strategyId == null || entry.strategyId!.isEmpty;
    final TextStyle metaStyle = context.uiText.caption.copyWith(
      color: c.foregroundSubtle,
    );

    final Set<String> seenTags = <String>{};
    final String lowerTitle = entry.displayTitle.trim().toLowerCase();
    final String lowerTicker = entry.ticker.trim().toLowerCase();
    final String lowerStrategy = (entry.strategy ?? '').trim().toLowerCase();
    final String lowerSide = AppTokens.sideLabel(entry.side).toLowerCase();
    final String lowerOutcome = AppTokens.outcomeLabel(entry.outcome).toLowerCase();

    final List<Widget> uniqueTags = <Widget>[];
    for (final String rawTag in entry.tags) {
      final String clean = rawTag.replaceAll('#', '').trim();
      final String lower = clean.toLowerCase();
      if (clean.isEmpty) continue;
      if (lower == lowerTitle ||
          lower == lowerTicker ||
          lower == lowerStrategy ||
          lower == lowerSide ||
          lower == lowerOutcome ||
          lower == 'open' ||
          lower == 'closed') {
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

    final bool showStrategyBadge = entry.strategy != null &&
        entry.strategy!.isNotEmpty &&
        lowerStrategy != lowerTitle;

    return AppDeskRecordCard(
      category: '${entry.ticker} · ${AppTokens.sideLabel(entry.side).toUpperCase()}',
      accentColor: pl,
      title: entry.displayTitle,
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
      semanticLabel: 'Trade: ${entry.displayTitle}',
      trailingHeader: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            entry.isOpen
                ? 'Open'
                : AppTokens.signedMoney(entry.pnl, decimals: 0),
            style: context.uiText.bodyStrong.copyWith(color: pl),
          ),
          if (trailing != null) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            trailing!,
          ],
        ],
      ),
      badges: <Widget>[
        if (!entry.isOpen)
          UiBadge(
            label: AppTokens.outcomeLabel(entry.outcome),
            size: UiSize.xs,
            icon: _outcomeIcon(entry.outcome),
            intent: AppTokens.outcomeIntent(entry.outcome),
            variant: UiBadgeVariant.soft,
          ),
        if (entry.rMultiple != null)
          UiBadge(
            label: AppTokens.rr(entry.rMultiple!),
            size: UiSize.xs,
            intent: AppTokens.plIntent(entry.rMultiple!),
            variant: UiBadgeVariant.soft,
          ),
        if (showStrategyBadge)
          UiBadge(
            label: entry.strategy!,
            icon: Icons.account_tree_outlined,
            size: UiSize.xs,
            intent: UiIntent.primary,
            maxWidth: context.sz(160),
          ),
        if (!entry.hasStory)
          const UiBadge(
            label: 'Needs write-up',
            size: UiSize.xs,
            icon: Icons.edit_note_rounded,
            intent: UiIntent.warning,
            variant: UiBadgeVariant.soft,
          ),
        if (unfiled)
          const UiBadge(
            label: 'Unfiled',
            size: UiSize.xs,
            icon: Icons.folder_off_outlined,
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
        if (entry.checklistTotal > 0)
          UiBadge(
            label: '${entry.checklistDone}/${entry.checklistTotal} checks',
            size: UiSize.xs,
            icon: Icons.checklist_rounded,
            variant: UiBadgeVariant.outline,
          ),
      ],
      tags: uniqueTags,
      footerMetadata: <Widget>[
        Text(AppTokens.relativeTime(entry.sortDate), style: metaStyle),
        Text('·', style: metaStyle),
        Text(
          '${entry.size.toStringAsFixed(0)} shares @ ${AppTokens.money(entry.entry)}',
          style: metaStyle,
        ),
        if (entry.wordCount > 0) ...<Widget>[
          Text('·', style: metaStyle),
          Text('${entry.wordCount} words', style: metaStyle),
        ],
      ],
      footerEngagement: footerEngagement,
    );
  }
}

/// The phone and tablet reading of the journal: month headers over a column of
/// [AppJournalNoteCard]s, two-up on a tablet.
///
/// Deliberately not the rail. The rail exists so a desktop trader can move
/// between entries without losing the one they are reading; a phone has no room
/// for both, so its list is the whole screen and opening an entry replaces it.
class AppJournalNoteGrid extends StatelessWidget {
  const AppJournalNoteGrid({
    super.key,
    required this.entries,
    this.onOpen,
    this.selectedId,
    this.groupByMonth = true,
    this.showExcerpt = true,
    this.linkedNoteCounts = const <String, int>{},
    this.emptyState,
    this.padding,
    this.header,
  });

  final List<AppTrade> entries;
  final ValueChanged<AppTrade>? onOpen;
  final String? selectedId;
  final bool groupByMonth;
  final bool showExcerpt;

  /// Entry id → linked-note count resolved from the graph, so a card can show
  /// edges the entry record itself does not store.
  final Map<String, int> linkedNoteCounts;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;

  /// Scrolls with the list — the stat strip and filter bar go here so they do
  /// not eat a third of a phone screen permanently.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    // One step tighter than md: cards sit in a list, and the gap between them
    // competes with the month headers that structure the list.
    final double gap = context.sp(theme.spacing.sm);
    final int columns = context.uiRes.columns(mobile: 1, tablet: 2, desktop: 2);

    final List<Widget> children = <Widget>[
      ?header,
      if (entries.isEmpty)
        emptyState ??
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xl),
              ),
              child: const UiEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Nothing here yet',
                message:
                    'Log the trade you just closed and write what you saw '
                    'while it is still fresh.',
              ),
            ),
    ];

    String lastGroup = '';
    final List<AppTrade> pending = <AppTrade>[];

    void flush() {
      if (pending.isEmpty) return;
      final List<AppTrade> batch = List<AppTrade>.of(pending);
      pending.clear();
      for (int i = 0; i < batch.length; i += columns) {
        final List<AppTrade> row = batch.sublist(
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

    for (final AppTrade entry in entries) {
      if (groupByMonth) {
        final String group = AppJournalNoteIndexList._monthLabel(
          entry.sortDate,
        );
        if (group != lastGroup) {
          flush();
          lastGroup = group;
          children.add(
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
              child: _GroupLabel(label: group),
            ),
          );
        }
      }
      pending.add(entry);
    }
    flush();

    return ListView(
      padding:
          padding ??
          EdgeInsets.fromLTRB(gap, gap, gap, context.uiPageBottomInset),
      children: children,
    );
  }

  Widget _card(AppTrade entry) => AppJournalNoteCard(
    entry: entry,
    selected: entry.id == selectedId,
    showExcerpt: showExcerpt,
    linkedNoteCount: linkedNoteCounts[entry.id],
    onTap: onOpen == null ? null : () => onOpen!(entry),
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
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

/// The masthead of an open journal entry.
///
/// Drops its own back button when the host already drew one — a document in the
/// desktop rail is inside a page that never navigated, so a back affordance there
/// would point nowhere.
class AppJournalNoteHeader extends StatelessWidget {
  const AppJournalNoteHeader({
    super.key,
    required this.entry,
    this.onBack,
    this.actions = const <Widget>[],
    this.onOpenStrategy,
    this.onOpenTicker,
    this.showTitle = true,
  });

  final AppTrade entry;

  /// Ignored when the workbench says the host owns the header.
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// Tapping the playbook name files through to the strategy. Null renders it as
  /// plain text.
  final VoidCallback? onOpenStrategy;
  final VoidCallback? onOpenTicker;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final embedded = AppWorkbenchScope.hasEmbeddedHeader(context);
    final inWorkbench = AppWorkbenchScope.of(context);
    final bool isDesktop = context.uiRes.isDesktop;
    final bool showBackButton = !isDesktop && !embedded && !inWorkbench && onBack != null;
    final bool shouldDisplayTitle = showTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shouldDisplayTitle)
          UiHeader(
            title: entry.displayTitle,
            leading: showBackButton
                ? UiIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to the journal',
                    onPressed: onBack,
                  )
                : null,
            actions: actions,
          )
        else if (actions.isNotEmpty || showBackButton)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(context.uiSpace.xs)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showBackButton)
                  UiIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to the journal',
                    onPressed: onBack,
                  )
                else
                  const SizedBox.shrink(),
                Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ),
          ),
        UiGap.v(context.uiSpace.sm),
        Wrap(
          spacing: context.sp(context.uiSpace.xs),
          runSpacing: context.sp(context.uiSpace.xs),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            UiBadge(
              label: entry.ticker,
              size: UiSize.xs,
              variant: UiBadgeVariant.outline,
              icon: Icons.candlestick_chart_outlined,
              onTap: onOpenTicker,
            ),
            UiBadge(
              label: AppTokens.sideLabel(entry.side),
              size: UiSize.xs,
              intent: AppTokens.sideIntent(entry.side),
              icon: AppTokens.sideIcon(entry.side),
            ),
            UiBadge(
              label: entry.isOpen
                  ? 'Open position'
                  : AppTokens.signedMoney(entry.pnl),
              size: UiSize.xs,
              icon: entry.isOpen
                  ? _outcomeIcon(AppOutcome.open)
                  : _outcomeIcon(entry.outcome),
              intent: entry.isOpen
                  ? UiIntent.info
                  : AppTokens.plIntent(entry.pnl),
            ),
            UiBadge(
              label: entry.isPublic ? 'Public' : 'Private',
              size: UiSize.xs,
              variant: UiBadgeVariant.soft,
              intent: entry.isPublic ? UiIntent.info : UiIntent.neutral,
              icon: entry.isPublic
                  ? Icons.public_rounded
                  : Icons.lock_outline_rounded,
            ),
            if (entry.strategy != null)
              UiBadge(
                label: entry.strategy!,
                size: UiSize.xs,
                variant: UiBadgeVariant.outline,
                onTap: onOpenStrategy,
              ),
            Text(
              AppTokens.fullDate(entry.sortDate),
              style: context.uiText.caption.copyWith(
                color: context.ui.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The trade's numbers as a statement: levels, size, result, discipline.
///
/// Sits under the write-up rather than above it. The words are why the entry
/// exists; the numbers are the evidence, and a trader re-reading an entry wants
/// the reasoning first and the arithmetic to check it against second.
class AppJournalNoteMetrics extends StatelessWidget {
  const AppJournalNoteMetrics({
    super.key,
    required this.entry,
    this.title = 'The trade',
    this.card = true,
  });

  final AppTrade entry;
  final String title;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final double? risk = entry.stopLoss == null
        ? null
        : (entry.entry - entry.stopLoss!).abs() * entry.size;
    final double? plannedR = (risk == null || risk == 0 || entry.target == null)
        ? null
        : (entry.target! - entry.entry).abs() * entry.size / risk;

    final Widget table = UiKeyValueTable(
      rows: <UiKeyValueRow>[
        UiKeyValueRow(
          label: 'Entry',
          value: AppTokens.price(entry.entry),
          detail: '${AppTokens.count(entry.size)} × ${entry.ticker}',
        ),
        if (entry.exit != null)
          UiKeyValueRow(label: 'Exit', value: AppTokens.price(entry.exit!)),
        if (entry.stopLoss != null)
          UiKeyValueRow(
            label: 'Stop',
            value: AppTokens.price(entry.stopLoss!),
            detail: risk == null ? null : '${AppTokens.money(risk)} at risk',
            intent: UiIntent.bearish,
          ),
        if (entry.target != null)
          UiKeyValueRow(
            label: 'Target',
            value: AppTokens.price(entry.target!),
            detail: plannedR == null
                ? null
                : 'planned ${AppTokens.rr(plannedR)}',
            intent: UiIntent.bullish,
          ),
        UiKeyValueRow(
          label: 'Held',
          value: _held(entry),
          detail: AppTokens.relativeTime(entry.sortDate),
        ),
        if (entry.psychologyScore != null)
          UiKeyValueRow(
            label: 'Discipline',
            value: '${entry.psychologyScore}/10',
            share: entry.psychologyScore! / 10,
            intent: entry.psychologyScore! >= 7
                ? UiIntent.bullish
                : UiIntent.warning,
          ),
        UiKeyValueRow(
          label: entry.isOpen ? 'Unrealised' : 'Result',
          value: AppTokens.signedMoney(entry.pnl),
          trailing: entry.rMultiple == null
              ? AppTokens.signedPercent(entry.pnlPercent)
              : AppTokens.rr(entry.rMultiple!),
          intent: AppTokens.plIntent(entry.pnl),
          emphasis: true,
        ),
      ],
    );

    if (!card) return table;
    return UiCard(title: title, variant: UiCardVariant.outlined, child: table);
  }

  static String _held(AppTrade entry) {
    final DateTime end = entry.closedAt ?? DateTime.now();
    final Duration d = end.difference(entry.openedAt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inDays}d ${d.inHours % 24}h';
  }
}
