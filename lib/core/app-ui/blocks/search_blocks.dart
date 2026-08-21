import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models_extra.dart';

IconData appSearchKindIcon(AppSearchKind kind) => switch (kind) {
  AppSearchKind.trade => Icons.candlestick_chart_outlined,
  AppSearchKind.strategy => Icons.schema_outlined,
  AppSearchKind.ticker => Icons.show_chart,
  AppSearchKind.trader => Icons.person_outline,
  AppSearchKind.post => Icons.forum_outlined,
  AppSearchKind.note => Icons.sticky_note_2_outlined,
};

String appSearchKindLabel(AppSearchKind kind) => switch (kind) {
  AppSearchKind.trade => 'Trades',
  AppSearchKind.strategy => 'Strategies',
  AppSearchKind.ticker => 'Tickers',
  AppSearchKind.trader => 'Traders',
  AppSearchKind.post => 'Posts',
  AppSearchKind.note => 'Notes',
};

/// Global search surface: query field, kind filters and grouped results.
class AppSearchBlock extends StatelessWidget {
  const AppSearchBlock({
    super.key,
    required this.query,
    required this.results,
    required this.onQueryChanged,
    this.loading = false,
    this.activeKinds = const <AppSearchKind>{},
    this.onToggleKind,
    this.onResultTap,
    this.recent = const <String>[],
    this.onRecentTap,
  });

  final String query;
  final List<AppSearchResult> results;
  final ValueChanged<String> onQueryChanged;
  final bool loading;
  final Set<AppSearchKind> activeKinds;
  final ValueChanged<AppSearchKind>? onToggleKind;
  final ValueChanged<AppSearchResult>? onResultTap;
  final List<String> recent;
  final ValueChanged<String>? onRecentTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Map<AppSearchKind, List<AppSearchResult>> grouped =
        <AppSearchKind, List<AppSearchResult>>{};
    for (final AppSearchResult r in results) {
      grouped.putIfAbsent(r.kind, () => <AppSearchResult>[]).add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        UiSearchField(
          value: query,
          hintText: 'Search trades, strategies, tickers, traders',
          loading: loading,
          onChanged: onQueryChanged,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            for (final AppSearchKind k in AppSearchKind.values)
              UiBadge(
                label: appSearchKindLabel(k),
                icon: appSearchKindIcon(k),
                size: UiSize.md,
                filled: activeKinds.contains(k),
                intent: activeKinds.contains(k)
                    ? UiIntent.primary
                    : UiIntent.neutral,
                onTap: onToggleKind == null ? null : () => onToggleKind!(k),
              ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),
        if (query.isEmpty && recent.isNotEmpty) ...<Widget>[
          Text('Recent searches', style: context.uiText.label),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final String r in recent)
                UiBadge(
                  label: r,
                  icon: Icons.history,
                  onTap: onRecentTap == null ? null : () => onRecentTap!(r),
                ),
            ],
          ),
        ] else
          UiAsyncView(
            loading: loading,
            isEmpty: results.isEmpty,
            emptyTitle: 'No matches',
            emptyMessage: 'Try a different ticker, tag or trader handle.',
            emptyIcon: Icons.search_off,
            builder: (BuildContext ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final MapEntry<AppSearchKind, List<AppSearchResult>> g
                    in grouped.entries) ...<Widget>[
                  Padding(
                    padding: EdgeInsets.only(bottom: ctx.sp(theme.spacing.sm)),
                    child: Text(
                      appSearchKindLabel(g.key),
                      style: ctx.uiText.label.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ),
                  for (final AppSearchResult r in g.value)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: ctx.sp(theme.spacing.sm),
                      ),
                      child: AppSearchResultTile(
                        result: r,
                        onTap: onResultTap == null
                            ? null
                            : () => onResultTap!(r),
                      ),
                    ),
                  SizedBox(height: ctx.sp(theme.spacing.md)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A single search hit row.
class AppSearchResultTile extends StatelessWidget {
  const AppSearchResultTile({super.key, required this.result, this.onTap});

  final AppSearchResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        children: <Widget>[
          if (result.avatarUrl != null)
            UiAvatar(
              imageUrl: result.avatarUrl,
              name: result.title,
              size: UiSize.sm,
            )
          else
            Container(
              width: context.sz(theme.sizes.controlHeightSm),
              height: context.sz(theme.sizes.controlHeightSm),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: UiIntent.primary.surface(context),
                borderRadius: context.radius(theme.radii.md),
              ),
              child: Icon(
                appSearchKindIcon(result.kind),
                size: context.sz(theme.sizes.iconSm),
                color: theme.colors.primary,
              ),
            ),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  result.title,
                  style: context.uiText.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
                if (result.subtitle != null)
                  Text(
                    result.subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (result.meta != null)
            Text(
              result.meta!,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundSubtle,
              ),
            ),
        ],
      ),
    );
  }
}
