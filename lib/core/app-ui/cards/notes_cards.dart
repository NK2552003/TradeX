import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../theme/app_tokens.dart';

/// Note cards — pure presentation over [AppNote], composing UiCard.

/// Strips markdown down to something readable in a two-line card preview.
///
/// Not a parser: a card preview only has to *look* like prose, so fences,
/// tables and images are dropped outright and inline markers are unwrapped.
/// Anything subtler than that is the preview screen's job.
String markdownToPlainText(String source, {int maxLength = 240}) {
  final String cacheKey = '$maxLength:$source';
  final String? cached = _plainTextCache[cacheKey];
  if (cached != null) return cached;
  String text = source;
  // Whole blocks that would render as noise on one line.
  text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  text = text.replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), ' ');
  text = text.replaceAll(RegExp(r'^\s*\|.*\|\s*$', multiLine: true), ' ');
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  // Inline markers, keeping the words.
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (Match m) => m.group(1) ?? '',
  );
  text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');
  text = text.replaceAll(
    RegExp(r'^\s*[-*+]\s+\[( |x|X)\]\s+', multiLine: true),
    '',
  );
  text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
  text = text.replaceAll(
    RegExp(r'^\s*(\*\*\*|---|___)\s*$', multiLine: true),
    ' ',
  );
  text = text.replaceAll(RegExp(r'[*_~`=]{1,3}'), '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final String result = text.length <= maxLength
      ? text
      : '${text.substring(0, maxLength)}…';
  if (_plainTextCache.length >= 256) {
    _plainTextCache.remove(_plainTextCache.keys.first);
  }
  _plainTextCache[cacheKey] = result;
  return result;
}

final Map<String, String> _plainTextCache = <String, String>{};

/// One note in the list: type, title, body preview, trader links and a footer
/// of derived counts.
class AppNoteCard extends StatelessWidget {
  const AppNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onDelete,
    this.density = AppNoteDensity.comfortable,
    this.selected = false,
    this.highlight = '',
  });

  final AppNote note;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final AppNoteDensity density;
  final bool selected;

  /// The active search term, so the matched words can be tinted in the preview.
  final String highlight;

  static const int _maxTickerBadges = 3;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color accent = note.noteType.intent.color(context);
    final bool showPreview = density != AppNoteDensity.titleOnly;
    final bool showTags =
        density == AppNoteDensity.full && note.tags.isNotEmpty;
    final List<String> tickers = note.linkedTickers;
    final int overflow = tickers.length - _maxTickerBadges;

    return UiCard(
      onTap: onTap,
      variant: UiCardVariant.outlined,
      selected: selected,
      hoverLift: false,
      motion: false,
      minHeight: context.sz(switch (density) {
        AppNoteDensity.titleOnly => 108,
        AppNoteDensity.comfortable => 140,
        AppNoteDensity.full => 182,
      }),
      semanticLabel: '${note.noteType.label}: ${note.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.circle, size: context.sz(8), color: accent),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Text(
                  note.noteType.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.label.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (note.isPublic)
                Padding(
                  padding: EdgeInsets.only(
                    right: context.sp(theme.spacing.xxs),
                  ),
                  child: Icon(
                    Icons.public_rounded,
                    size: context.sz(theme.sizes.iconXs),
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
              if (onDelete != null)
                UiIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete note',
                  size: UiSize.sm,
                  onPressed: onDelete,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            note.title.trim().isEmpty ? 'Untitled note' : note.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.bodyStrong.copyWith(
              color: note.title.trim().isEmpty
                  ? theme.colors.foregroundSubtle
                  : theme.colors.foreground,
            ),
          ),
          if (showPreview) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xxs)),
            _Preview(note: note, highlight: highlight),
          ],
          if (note.strategyName != null ||
              note.linkedJournalIds.isNotEmpty ||
              tickers.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xxs),
              children: <Widget>[
                if (note.strategyName != null)
                  UiBadge(
                    label: note.strategyName!,
                    intent: UiIntent.primary,
                    icon: Icons.account_tree_outlined,
                    size: UiSize.xs,
                    maxWidth: context.sz(160),
                  ),
                if (note.linkedJournalIds.isNotEmpty)
                  UiBadge(
                    label: note.linkedJournalIds.length == 1
                        ? '1 journal'
                        : '${note.linkedJournalIds.length} journals',
                    intent: UiIntent.info,
                    icon: Icons.receipt_long_outlined,
                    size: UiSize.xs,
                  ),
                ...tickers
                    .take(_maxTickerBadges)
                    .map(
                      (String symbol) => UiBadge(
                        label: symbol,
                        variant: UiBadgeVariant.outline,
                        size: UiSize.xs,
                      ),
                    ),
                if (overflow > 0)
                  UiBadge(
                    label: '+$overflow',
                    variant: UiBadgeVariant.ghost,
                    size: UiSize.xs,
                    tooltip: tickers.skip(_maxTickerBadges).join(' · '),
                  ),
              ],
            ),
          ],
          if (showTags) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Wrap(
              spacing: context.sp(theme.spacing.xxs),
              runSpacing: context.sp(theme.spacing.xxs),
              children: note.tags
                  .map(
                    (String tag) => UiBadge(
                      label: '#$tag',
                      variant: UiBadgeVariant.ghost,
                      size: UiSize.xs,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.xs)),
          _Footer(note: note),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.note, required this.highlight});

  final AppNote note;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.uiText.caption.copyWith(
      color: context.uiColors.foregroundMuted,
      height: 1.45,
    );
    final String plain = markdownToPlainText(note.content);
    if (plain.isEmpty) {
      return Text(
        'Empty note',
        style: style.copyWith(fontStyle: FontStyle.italic),
      );
    }
    final String needle = highlight.trim().toLowerCase();
    if (needle.isEmpty) {
      return Text(
        plain,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    // Search matches are tinted rather than the card being re-ordered or
    // annotated: the reader is scanning for the phrase they typed, and seeing it
    // in place is faster than a "matched in body" label.
    final List<TextSpan> spans = <TextSpan>[];
    final String lower = plain.toLowerCase();
    int cursor = 0;
    while (cursor < plain.length) {
      final int hit = lower.indexOf(needle, cursor);
      if (hit == -1) {
        spans.add(TextSpan(text: plain.substring(cursor)));
        break;
      }
      if (hit > cursor) {
        spans.add(TextSpan(text: plain.substring(cursor, hit)));
      }
      spans.add(
        TextSpan(
          text: plain.substring(hit, hit + needle.length),
          style: TextStyle(
            color: context.uiColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = hit + needle.length;
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.note});

  final AppNote note;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final TextStyle style = context.uiText.caption.copyWith(
      color: theme.colors.foregroundSubtle,
    );
    final Widget metadata = Wrap(
      spacing: context.sp(theme.spacing.xs),
      runSpacing: context.sp(theme.spacing.xxs),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(AppTokens.relativeTime(note.updatedAt), style: style),
        Text('·', style: style),
        Text('${note.wordCount} words', style: style),
        if (note.hasChecklist) ...<Widget>[
          Text('·', style: style),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                note.checklistDone == note.checklistTotal
                    ? Icons.check_circle_outline_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: context.sz(theme.sizes.iconXs),
                color: note.checklistDone == note.checklistTotal
                    ? theme.colors.bullish
                    : theme.colors.foregroundSubtle,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Text(
                '${note.checklistDone}/${note.checklistTotal}',
                style: style,
              ),
            ],
          ),
        ],
        if (note.hasImages)
          Icon(
            Icons.image_outlined,
            size: context.sz(theme.sizes.iconXs),
            color: theme.colors.foregroundSubtle,
          ),
        if (note.hasCode)
          Icon(
            Icons.code_rounded,
            size: context.sz(theme.sizes.iconXs),
            color: theme.colors.foregroundSubtle,
          ),
      ],
    );

    if (!note.isPublic) return metadata;

    final Widget engagement = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.visibility_outlined,
          size: context.sz(14),
          color: style.color,
        ),
        SizedBox(width: context.sp(theme.spacing.xxs)),
        Text('${note.viewCount}', style: style),
        SizedBox(width: context.sp(theme.spacing.xs)),
        Icon(
          Icons.favorite_border_rounded,
          size: context.sz(14),
          color: style.color,
        ),
        SizedBox(width: context.sp(theme.spacing.xxs)),
        Text('${note.likeCount}', style: style),
        SizedBox(width: context.sp(theme.spacing.xs)),
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: context.sz(14),
          color: style.color,
        ),
        SizedBox(width: context.sp(theme.spacing.xxs)),
        Text('${note.comments.length}', style: style),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: metadata),
        SizedBox(width: context.sp(theme.spacing.sm)),
        engagement,
      ],
    );
  }
}

/// Loading placeholder shaped like [AppNoteCard].
class AppNoteCardSkeleton extends StatelessWidget {
  const AppNoteCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => UiCard(
    loading: true,
    loadingHeight: context.sz(96),
    child: const SizedBox.shrink(),
  );
}

/// Four metric cards inside a unified hairline strip above the note list:
/// total, edited this week, public, and words.
class AppNoteStatRow extends StatelessWidget {
  const AppNoteStatRow({super.key, required this.notes, this.loading = false});

  final List<AppNote> notes;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    if (loading) {
      return UiDataPanel(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
          child: Row(
            children: List<Widget>.generate(
              4,
              (int index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.xs),
                  ),
                  child: UiSkeleton(
                    key: ValueKey<String>('note_stat_skeleton_$index'),
                    height: context.sz(54),
                    borderRadius: context.radius(theme.radii.md),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final int thisWeek = notes
        .where((AppNote n) => n.updatedAt.isAfter(weekAgo))
        .length;
    final int public = notes.where((AppNote n) => n.isPublic).length;
    final int words = notes.fold<int>(
      0,
      (int sum, AppNote n) => sum + n.wordCount,
    );
    final int privateCount = notes.length - public;

    final List<UiStat> stats = <UiStat>[
      UiStat(
        icon: Icons.notes_rounded,
        label: 'Notes',
        value: '${notes.length}',
        hint: '$privateCount private',
        intent: UiIntent.primary,
      ),
      UiStat(
        icon: Icons.edit_calendar_outlined,
        label: 'This week',
        value: '$thisWeek',
        hint: 'past 7 days',
        intent: thisWeek > 0 ? UiIntent.bullish : UiIntent.neutral,
      ),
      UiStat(
        icon: Icons.public_rounded,
        label: 'Public',
        value: '$public',
        hint: notes.isEmpty
            ? '0% shared'
            : '${((public / notes.length) * 100).round()}% shared',
        intent: UiIntent.neutral,
      ),
      UiStat(
        icon: Icons.text_fields_rounded,
        label: 'Words',
        value: AppTokens.count(words),
        hint: notes.isEmpty
            ? '0 avg / note'
            : '${(words / notes.length).round()} avg / note',
        intent: UiIntent.neutral,
      ),
    ];

    return UiDataPanel(
      padding: EdgeInsets.zero,
      child: UiStatStrip(
        stats: stats,
        columns: context.uiRes.isMobile ? 2 : 4,
        minCellWidth: context.uiRes.isMobile ? 108 : 132,
        density: UiDensity.compact,
      ),
    );
  }
}
