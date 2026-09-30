import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/models/app_models.dart';
import 'package:tradex/core/linking/link_graph.dart';

/// Whether a Writing Desk record may be read outside its owner's workspace.
enum AppRecordVisibility { private, public }

/// The single Writing Desk record a future social post may carry.
///
/// A post owns at most one of these objects, so the illegal state “one post
/// links a note and a strategy” cannot be represented by this contract. The
/// attachment is a reference plus a small, safe preview; it never copies linked
/// notes, trades or playbooks into the post.
@immutable
class AppWritingPostAttachment extends AppWritingRecordPostAttachment {
  const AppWritingPostAttachment._({
    required this.source,
    required this.visibility,
    required this.excerpt,
    required this.updatedAt,
    required this.tags,
    required this.hasMedia,
    this.primaryTicker,
  }) : super();

  factory AppWritingPostAttachment.note(AppNote note) =>
      AppWritingPostAttachment._(
        source: AppLinkRef(
          kind: AppLinkKind.note,
          id: note.id,
          title: note.title.trim().isEmpty
              ? 'Untitled note'
              : note.title.trim(),
          subtitle: note.noteType.label,
          icon: note.noteType.icon,
          intent: note.noteType.intent,
        ),
        visibility: note.isPublic
            ? AppRecordVisibility.public
            : AppRecordVisibility.private,
        excerpt: _preview(note.content),
        updatedAt: note.updatedAt,
        tags: List<String>.unmodifiable(note.tags),
        hasMedia: note.hasImages,
        primaryTicker: note.linkedTickers.firstOrNull,
      );

  factory AppWritingPostAttachment.journal(AppTrade entry) =>
      AppWritingPostAttachment._(
        source: AppLinkRef(
          kind: AppLinkKind.journal,
          id: entry.id,
          title: entry.displayTitle,
          subtitle: entry.isOpen ? 'Open trade' : 'Closed trade',
          icon: AppLinkKind.journal.icon,
        ),
        visibility: entry.isPublic
            ? AppRecordVisibility.public
            : AppRecordVisibility.private,
        excerpt: _preview(
          entry.content.trim().isEmpty ? entry.notes ?? '' : entry.content,
        ),
        updatedAt: entry.editedAt,
        tags: List<String>.unmodifiable(entry.tags),
        hasMedia: entry.hasImages || (entry.screenshotUrl?.isNotEmpty ?? false),
        primaryTicker: entry.ticker,
      );

  factory AppWritingPostAttachment.strategy(AppStrategy strategy) =>
      AppWritingPostAttachment._(
        source: AppLinkRef(
          kind: AppLinkKind.strategy,
          id: strategy.id,
          title: strategy.name.trim().isEmpty
              ? 'Untitled strategy'
              : strategy.name.trim(),
          subtitle: strategy.status.label,
          icon: AppLinkKind.strategy.icon,
        ),
        visibility: strategy.isPublic
            ? AppRecordVisibility.public
            : AppRecordVisibility.private,
        excerpt: _preview(
          strategy.summary?.trim().isNotEmpty == true
              ? strategy.summary!
              : strategy.content,
        ),
        updatedAt:
            strategy.updatedAt ??
            strategy.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0),
        tags: List<String>.unmodifiable(strategy.tags),
        hasMedia: strategy.hasImages,
        primaryTicker: strategy.linkedTickers.firstOrNull,
      );

  factory AppWritingPostAttachment.manual({
    required AppLinkRef source,
    required String excerpt,
    AppRecordVisibility visibility = AppRecordVisibility.public,
    DateTime? updatedAt,
    List<String> tags = const <String>[],
    bool hasMedia = false,
    String? primaryTicker,
  }) =>
      AppWritingPostAttachment._(
        source: source,
        visibility: visibility,
        excerpt: excerpt,
        updatedAt: updatedAt ?? DateTime.now(),
        tags: tags,
        hasMedia: hasMedia,
        primaryTicker: primaryTicker,
      );

  static const int previewCharacterLimit = 220;

  final AppLinkRef source;
  final AppRecordVisibility visibility;
  final String excerpt;
  final DateTime updatedAt;
  final List<String> tags;
  final bool hasMedia;
  final String? primaryTicker;

  AppLinkKind get kind => source.kind;
  String get sourceId => source.id;
  String get sourceKey => '${kind.host}:$sourceId';
  bool get isPublic => visibility == AppRecordVisibility.public;

  /// A public post must not expose a private workspace record. The future post
  /// composer can use this to request an explicit visibility change before it
  /// persists the post.
  bool get requiresPublication => !isPublic;

  static String _preview(String markdown) {
    final String plain = markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'[#>*_~`|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.length <= previewCharacterLimit) return plain;
    final String clipped = plain.substring(0, previewCharacterLimit);
    final int wordEnd = clipped.lastIndexOf(' ');
    return '${clipped.substring(0, wordEnd > 0 ? wordEnd : clipped.length)}…';
  }
}

typedef AppWritingPostAttachmentHandler =
    void Function(AppWritingPostAttachment attachment);

/// Resolves the three Writing Desk repositories into one source catalogue for
/// the future post composer. It does not create, mutate or publish posts.
class AppWritingPostAttachmentCatalog {
  const AppWritingPostAttachmentCatalog(this.graph);

  final AppLinkGraph graph;

  AppWritingPostAttachment? resolve(
    AppLinkKind kind,
    String id,
  ) => switch (kind) {
    AppLinkKind.note => switch (graph.note(id)) {
      final AppNote note => AppWritingPostAttachment.note(note),
      null => null,
    },
    AppLinkKind.journal => switch (graph.entry(id)) {
      final AppTrade entry => AppWritingPostAttachment.journal(entry),
      null => null,
    },
    AppLinkKind.strategy => switch (graph.strategy(id)) {
      final AppStrategy strategy => AppWritingPostAttachment.strategy(strategy),
      null => null,
    },
    // Tickers and other kinds are metadata on a post or Writing Desk record, never the record
    // attached to the post.
    AppLinkKind.ticker || _ => null,
  };

  List<AppWritingPostAttachment> search({
    String query = '',
    AppLinkKind? kind,
    bool publicOnly = false,
  }) {
    final Iterable<AppWritingPostAttachment> records =
        <AppWritingPostAttachment>[
          for (final AppNote note in graph.noteList)
            AppWritingPostAttachment.note(note),
          for (final AppTrade entry in graph.journalList)
            AppWritingPostAttachment.journal(entry),
          for (final AppStrategy strategy in graph.strategyList)
            AppWritingPostAttachment.strategy(strategy),
        ];
    final String needle = query.trim().toLowerCase();
    final List<AppWritingPostAttachment> matches = records
        .where((record) {
          if (kind != null && record.kind != kind) return false;
          if (publicOnly && !record.isPublic) return false;
          if (needle.isEmpty) return true;
          return record.source.title.toLowerCase().contains(needle) ||
              record.excerpt.toLowerCase().contains(needle) ||
              (record.primaryTicker ?? '').toLowerCase().contains(needle) ||
              record.tags.any((tag) => tag.toLowerCase().contains(needle));
        })
        .toList(growable: false);
    matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<AppWritingPostAttachment>.unmodifiable(matches);
  }
}
