import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../../markdown_kit/markdown_preview.dart';
import '../cards/journal_cards.dart';
import '../cards/strategy_cards.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Filter bar: search + side/outcome segmented filters + sort.
class AppJournalFilterBlock extends StatelessWidget {
  const AppJournalFilterBlock({
    super.key,
    required this.query,
    required this.outcome,
    this.onQueryChanged,
    this.onOutcomeChanged,
    this.onOpenFilters,
  });

  final String query;
  final AppOutcome? outcome;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<AppOutcome?>? onOutcomeChanged;
  final VoidCallback? onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Widget search = UiInput.search(
      value: query,
      hintText: 'Search ticker, tag or note',
      onChanged: onQueryChanged,
    );
    final Widget filters = UiToggleGroup<AppOutcome?>(
      value: outcome,
      onChanged: onOutcomeChanged,
      options: <UiToggleOption<AppOutcome?>>[
        const UiToggleOption<AppOutcome?>(value: null, label: 'All'),
        const UiToggleOption<AppOutcome?>(
          value: AppOutcome.win,
          label: 'Wins',
          intent: UiIntent.bullish,
        ),
        const UiToggleOption<AppOutcome?>(
          value: AppOutcome.loss,
          label: 'Losses',
          intent: UiIntent.bearish,
        ),
        const UiToggleOption<AppOutcome?>(
          value: AppOutcome.open,
          label: 'Open',
          intent: UiIntent.info,
        ),
      ],
    );

    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          search,
          SizedBox(height: context.sp(theme.spacing.sm)),
          filters,
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: search),
        SizedBox(width: context.sp(theme.spacing.md)),
        filters,
        if (onOpenFilters != null) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.sm)),
          UiIconButton(
            icon: Icons.tune,
            tooltip: 'More filters',
            onPressed: onOpenFilters,
          ),
        ],
      ],
    );
  }
}

/// Trade list: cards on phones, sortable table from tablet up.
class AppTradeListBlock extends StatelessWidget {
  const AppTradeListBlock({
    super.key,
    required this.trades,
    this.onTradeTap,
    this.loading = false,
    this.emptyAction,
  });

  final List<AppTrade> trades;
  final ValueChanged<AppTrade>? onTradeTap;
  final bool loading;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (loading) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: UiSkeleton(height: context.sz(84)),
            ),
        ],
      );
    }
    if (trades.isEmpty) {
      return UiEmptyState(
        title: 'No trades match',
        message: 'Try clearing filters or log a new trade.',
        icon: Icons.receipt_long_outlined,
        action: emptyAction,
      );
    }

    if (context.uiRes.isMobile) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < trades.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: AppFadeIn(
                delay: Duration(milliseconds: 40 * i),
                child: AppTradeCard(
                  trade: trades[i],
                  onTap: onTradeTap == null
                      ? null
                      : () => onTradeTap!(trades[i]),
                ),
              ),
            ),
        ],
      );
    }

    return UiTable<AppTrade>(
      rows: trades,
      onRowTap: onTradeTap == null ? null : (AppTrade t) => onTradeTap!(t),
      columns: <UiTableColumn<AppTrade>>[
        UiTableColumn<AppTrade>(
          header: 'Ticker',
          cell: (BuildContext context, AppTrade t) =>
              Text(t.ticker, style: context.uiText.bodyStrong),
          compare: (AppTrade a, AppTrade b) => a.ticker.compareTo(b.ticker),
        ),
        UiTableColumn<AppTrade>(
          header: 'Side',
          cell: (BuildContext context, AppTrade t) => UiBadge(
            label: AppTokens.sideLabel(t.side),
            intent: AppTokens.sideIntent(t.side),
          ),
        ),
        UiTableColumn<AppTrade>(
          header: 'Entry',
          numeric: true,
          hideBelow: UiTableVisibility.tabletUp,
          cell: (BuildContext context, AppTrade t) =>
              Text(AppTokens.money(t.entry)),
        ),
        UiTableColumn<AppTrade>(
          header: 'Exit',
          numeric: true,
          hideBelow: UiTableVisibility.tabletUp,
          cell: (BuildContext context, AppTrade t) =>
              Text(t.exit == null ? '—' : AppTokens.money(t.exit!)),
        ),
        UiTableColumn<AppTrade>(
          header: 'R',
          numeric: true,
          hideBelow: UiTableVisibility.desktopUp,
          cell: (BuildContext context, AppTrade t) =>
              Text(t.rMultiple == null ? '—' : AppTokens.rr(t.rMultiple!)),
        ),
        UiTableColumn<AppTrade>(
          header: 'P/L',
          numeric: true,
          compare: (AppTrade a, AppTrade b) => a.pnl.compareTo(b.pnl),
          cell: (BuildContext context, AppTrade t) => Text(
            AppTokens.signedMoney(t.pnl),
            style: context.uiText.numeric.copyWith(
              color: AppTokens.pl(context, t.pnl),
            ),
          ),
        ),
        UiTableColumn<AppTrade>(
          header: 'Date',
          hideBelow: UiTableVisibility.desktopUp,
          compare: (AppTrade a, AppTrade b) => a.openedAt.compareTo(b.openedAt),
          cell: (BuildContext context, AppTrade t) =>
              Text(AppTokens.shortDate(t.openedAt)),
        ),
      ],
    );
  }
}

/// Full trade detail: levels, notes, screenshot, psychology.
class AppTradeDetailBlock extends StatelessWidget {
  const AppTradeDetailBlock({
    super.key,
    required this.trade,
    this.onEdit,
    this.onDelete,
  });

  final AppTrade trade;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.lg);

    final Widget levels = UiCard(
      title: 'Levels',
      child: Column(
        children: <Widget>[
          _row(context, 'Entry', AppTokens.money(trade.entry)),
          _row(
            context,
            'Stop',
            trade.stopLoss == null ? '—' : AppTokens.money(trade.stopLoss!),
          ),
          _row(
            context,
            'Target',
            trade.target == null ? '—' : AppTokens.money(trade.target!),
          ),
          _row(
            context,
            'Exit',
            trade.exit == null ? 'Open' : AppTokens.money(trade.exit!),
          ),
          _row(context, 'Size', trade.size.toStringAsFixed(2)),
        ],
      ),
    );

    final Widget result = UiCard(
      title: 'Result',
      accentColor: AppTokens.pl(context, trade.pnl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppCountUp(
            value: trade.pnl,
            formatter: (num v) => AppTokens.signedMoney(v),
            style: context.uiText.display.copyWith(
              color: AppTokens.pl(context, trade.pnl),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              UiBadge.delta(trade.pnlPercent),
              if (trade.rMultiple != null)
                UiBadge(label: AppTokens.rr(trade.rMultiple!)),
              UiBadge(
                label: AppTokens.outcomeLabel(trade.outcome),
                intent: AppTokens.outcomeIntent(trade.outcome),
              ),
            ],
          ),
        ],
      ),
    );

    final String noteData = trade.content.isNotEmpty
        ? trade.content
        : (trade.notes ?? '');
    final Widget notes = UiCard(
      title: 'Notes',
      trailing: onEdit == null
          ? null
          : UiIconButton(
              icon: Icons.edit_outlined,
              size: UiSize.sm,
              onPressed: onEdit,
            ),
      child: noteData.isNotEmpty
          ? RichMarkdownPreview(data: noteData)
          : Text(
              'No notes for this trade yet.',
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
    );

    final List<Widget> left = <Widget>[
      result,
      levels,
      if (trade.screenshotUrl != null)
        UiCard(
          title: 'Chart screenshot',
          child: ClipRRect(
            borderRadius: context.radius(theme.radii.lg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: UiRemoteImage(
                url: trade.screenshotUrl,
                semanticLabel: 'Chart screenshot for ${trade.ticker}',
              ),
            ),
          ),
        ),
    ];

    final List<Widget> right = <Widget>[
      notes,
      if (trade.psychologyScore != null)
        AppPsychologyCard(score: trade.psychologyScore!),
      if (trade.tags.isNotEmpty)
        UiCard(
          title: 'Tags',
          child: Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: trade.tags.map((String t) => UiBadge(label: t)).toList(),
          ),
        ),
      if (onDelete != null)
        UiButton(
          label: 'Delete trade',
          variant: UiVariant.destructive,
          expand: true,
          onPressed: onDelete,
        ),
    ];

    Widget stack(List<Widget> w) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < w.length; i++) ...<Widget>[
          w[i],
          if (i != w.length - 1) SizedBox(height: gap),
        ],
      ],
    );

    if (!context.uiRes.isDesktop) return stack(<Widget>[...left, ...right]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: stack(left)),
        SizedBox(width: gap),
        Expanded(child: stack(right)),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          // Loose, so the figure takes only the width it needs and the label keeps
          // the rest — but it can still be squeezed rather than run past the edge
          // of the card on a narrow phone.
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: context.uiText.numeric,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pre-trade checklist gate with completion progress.
class AppPreTradeChecklistBlock extends StatelessWidget {
  const AppPreTradeChecklistBlock({
    super.key,
    required this.items,
    this.onToggle,
    this.onConfirm,
  });

  final List<AppChecklistItem> items;
  final void Function(AppChecklistItem item, bool value)? onToggle;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int done = items.where((AppChecklistItem i) => i.done).length;
    final bool ready = done == items.length && items.isNotEmpty;
    return UiCard(
      title: 'Pre-trade checklist',
      subtitle: '$done of ${items.length} complete',
      accentColor: ready ? theme.colors.bullish : theme.colors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiProgressBar(
            value: items.isEmpty ? 0 : done / items.length,
            intent: ready ? UiIntent.bullish : UiIntent.warning,
            showValue: false,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          for (final AppChecklistItem i in items)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: UiCheckbox(
                value: i.done,
                label: i.label,
                description: i.description,
                onChanged: onToggle == null
                    ? null
                    : (bool v) => onToggle!(i, v),
              ),
            ),
          UiButton(
            label: ready ? 'Log trade' : 'Complete checklist first',
            expand: true,
            onPressed: ready ? onConfirm : null,
          ),
        ],
      ),
    );
  }
}

/// Strategy library grid with search and create action.
class AppStrategyLibraryBlock extends StatelessWidget {
  const AppStrategyLibraryBlock({
    super.key,
    required this.strategies,
    this.onCreate,
    this.onOpen,
    this.onFavorite,
  });

  final List<AppStrategy> strategies;
  final VoidCallback? onCreate;
  final ValueChanged<AppStrategy>? onOpen;
  final ValueChanged<AppStrategy>? onFavorite;

  @override
  Widget build(BuildContext context) {
    if (strategies.isEmpty) {
      return UiEmptyState(
        title: 'No strategies yet',
        message: 'Document your first playbook and let AI summarise it.',
        icon: Icons.auto_stories_outlined,
        action: UiButton(
          label: 'New strategy',
          leadingIcon: Icons.add,
          expandOnMobile: false,
          onPressed: onCreate,
        ),
      );
    }
    return UiCardGrid(
      childAspectRatio: context.uiRes.pick<double>(
        mobile: 1.25,
        tablet: 1.15,
        desktop: 1.12,
      ),
      children: <Widget>[
        for (int i = 0; i < strategies.length; i++)
          AppFadeIn(
            delay: Duration(milliseconds: 50 * i),
            child: AppStrategyCard(
              strategy: strategies[i],
              onTap: onOpen == null ? null : () => onOpen!(strategies[i]),
              onFavorite: onFavorite == null
                  ? null
                  : () => onFavorite!(strategies[i]),
            ),
          ),
      ],
    );
  }
}

/// Strategy version history timeline.
class AppVersionHistoryBlock extends StatelessWidget {
  const AppVersionHistoryBlock({
    super.key,
    required this.versions,
    this.onRestore,
  });

  final List<AppStrategyVersion> versions;
  final ValueChanged<AppStrategyVersion>? onRestore;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < versions.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: AppVersionCard(
              version: versions[i],
              onRestore: onRestore == null
                  ? null
                  : () => onRestore!(versions[i]),
            ),
          ),
      ],
    );
  }
}
