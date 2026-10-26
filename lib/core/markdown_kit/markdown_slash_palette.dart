import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import 'markdown_snippets.dart';

/// The `/` block palette — Obsidian's slash menu, minus the markdown literacy
/// requirement: every row is named in plain English and carries a one-line
/// description of what it produces.
///
/// Purely presentational. The editor field reports the live query, the screen
/// decides where this card sits, and [onSelect] hands back the chosen snippet.
class MarkdownSlashPalette extends StatelessWidget {
  const MarkdownSlashPalette({
    super.key,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
    this.maxHeight,
    this.width,
  });

  final String query;
  final ValueChanged<MarkdownSnippet> onSelect;
  final VoidCallback onDismiss;
  final double? maxHeight;
  final double? width;

  /// What Enter accepts while the palette is open.
  static MarkdownSnippet? topMatch(String query) {
    final List<MarkdownSnippet> hits = MarkdownSnippets.search(query);
    return hits.isEmpty ? null : hits.first;
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<MarkdownSnippet> results = MarkdownSnippets.search(query);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? context.sz(320),
        maxWidth: width ?? context.sz(380),
      ),
      child: UiCard(
        variant: UiCardVariant.elevated,
        hoverLift: false,
        padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
        child: results.isEmpty
            ? Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.search_off_rounded,
                      size: context.sz(theme.sizes.iconSm),
                      color: theme.colors.foregroundSubtle,
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Text(
                        'No block called "$query"',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ),
                    UiIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      size: UiSize.sm,
                      onPressed: onDismiss,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                itemBuilder: (BuildContext ctx, int index) {
                  final MarkdownSnippet snippet = results[index];
                  final bool newGroup =
                      index == 0 || results[index - 1].group != snippet.group;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (newGroup)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.sp(theme.spacing.sm),
                            context.sp(
                              index == 0 ? theme.spacing.xxs : theme.spacing.sm,
                            ),
                            context.sp(theme.spacing.sm),
                            context.sp(theme.spacing.xxs),
                          ),
                          child: Text(
                            snippet.group.toUpperCase(),
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      _PaletteRow(
                        snippet: snippet,
                        highlighted: index == 0,
                        onTap: () => onSelect(snippet),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.snippet,
    required this.highlighted,
    required this.onTap,
  });

  final MarkdownSnippet snippet;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Material(
      color: highlighted
          ? theme.colors.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: context.radius(theme.radii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: context.radius(theme.radii.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                snippet.icon,
                size: context.sz(theme.sizes.iconSm),
                color: highlighted
                    ? theme.colors.primary
                    : theme.colors.foregroundMuted,
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      snippet.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.body,
                    ),
                    if (snippet.description != null)
                      Text(
                        snippet.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundSubtle,
                        ),
                      ),
                  ],
                ),
              ),
              if (highlighted)
                Text(
                  '↵',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
