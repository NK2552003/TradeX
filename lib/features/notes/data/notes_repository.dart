import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';
import 'package:uuid/uuid.dart';

/// Everything the notes feature needs from storage.
///
/// Backend hand-off: implement this interface against Supabase (`trader_notes`
/// + the `note-attachments` bucket) and swap the one line in
/// [NotesRepositoryScope.repository]. No widget constructs an implementation
/// itself, so nothing above this file changes.
abstract class NotesRepository {
  /// Emits the full note list, newest edit first, and re-emits after every
  /// mutation. The list screen listens rather than polling so an edit made in
  /// the editor is reflected the moment the reader navigates back.
  Stream<List<AppNote>> watchAll();

  Stream<List<AppNote>> watchPublic();

  Future<List<AppNote>> fetchAll();

  Future<AppNote?> getById(String id);

  Future<AppNote> create(AppNote draft);

  Future<AppNote> update(AppNote note);

  Future<void> delete(String id);

  Future<AppNote> recordView(String id);

  Future<AppNote> toggleLike(String id);

  Future<AppNote> toggleFavorite(String id);

  Future<AppNote> setVisibility(String id, bool isPublic);

  Future<AppNote> addComment(String id, String body);

  /// Stores an attachment and returns the storage reference to embed in the
  /// markdown body (`![alt](ref)`).
  Future<String> uploadAttachment(String noteId, File file);

  /// Turns a stored reference back into something the preview can load. Local
  /// file paths come back unchanged; a Supabase implementation returns a signed
  /// URL here.
  Future<String> resolveAttachmentUrl(String ref);
}

/// Live Supabase-backed implementation with real-time sync and offline resilience.
class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl._();

  /// Shared so the list, the editor and the preview all observe the same notes.
  static final NotesRepositoryImpl instance = NotesRepositoryImpl._();

  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final List<AppNote> _notes = <AppNote>[];
  final Set<String> _likedNoteIds = <String>{};
  final Set<String> _favoriteNoteIds = <String>{};
  final Map<String, List<AppNoteComment>> _commentsByNoteId =
      <String, List<AppNoteComment>>{};
  final StreamController<List<AppNote>> _changes =
      StreamController<List<AppNote>>.broadcast();

  bool _initialized = false;
  bool _subscribedToRealtime = false;
  RealtimeChannel? _realtimeChannel;

  RealtimeChannel? get realtimeChannel => _realtimeChannel;

  String _resolveUserId() {
    if (SupabaseConfig.isConfigured) {
      final user = SupabaseConfig.client?.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
    }
    return _demoUserId;
  }

  bool _isUuid(String? id) => id != null && _uuidRegex.hasMatch(id);

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    if (SupabaseConfig.isConfigured) {
      _initRealtime();
      await _fetchFromSupabase();
    } else {
      // Offline fallback for unit tests without network
      final DemoDataSource demo = DemoDataSource.instance;
      _notes.addAll(demo.notes());
      _syncAllTickerLinks();
      _publish();
    }
  }

  void _initRealtime() {
    if (_subscribedToRealtime || !SupabaseConfig.isConfigured) return;
    _subscribedToRealtime = true;

    try {
      final client = SupabaseConfig.client!;
      _realtimeChannel = client
          .channel('public:trader_notes_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trader_notes',
            callback: (PostgresChangePayload payload) {
              _handlePostgresChange(payload);
            },
          )
        ..subscribe();
    } catch (e) {
      debugPrint('[NotesRepository] Realtime subscription error: $e');
    }
  }

  void _handlePostgresChange(PostgresChangePayload payload) {
    try {
      final currentUserId = _resolveUserId();
      final eventType = payload.eventType;

      if (eventType == PostgresChangeEvent.insert) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final recordUserId = newRecord['user_id']?.toString();
          final isPublic = newRecord['is_public'] == true;
          if (recordUserId == currentUserId || isPublic) {
            final note = _mapRowToNote(newRecord);
            _notes.removeWhere((n) => n.id == note.id);
            _notes.insert(0, note);
            _recordTickerLinks(note);
            _publish();
          }
        }
      } else if (eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final note = _mapRowToNote(newRecord);
          final at = _notes.indexWhere((n) => n.id == note.id);
          if (at != -1) {
            _notes[at] = note;
          } else {
            final recordUserId = newRecord['user_id']?.toString();
            final isPublic = newRecord['is_public'] == true;
            if (recordUserId == currentUserId || isPublic) {
              _notes.insert(0, note);
            }
          }
          _recordTickerLinks(note);
          _publish();
        }
      } else if (eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final deletedId = oldRecord['id']?.toString();
        if (deletedId != null) {
          _notes.removeWhere((n) => n.id == deletedId);
          _commentsByNoteId.remove(deletedId);
          _likedNoteIds.remove(deletedId);
          _favoriteNoteIds.remove(deletedId);
          unawaited(
            EntityTickerLinksRepository.instance.removeLinks(
              entityType: 'note',
              entityId: deletedId,
            ),
          );
          _publish();
        }
      }
    } catch (e) {
      debugPrint('[NotesRepository] Error handling postgres change: $e');
    }
  }

  Future<void> _fetchFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();

      // Fetch user likes
      try {
        final likesRes = await client
            .from('trader_note_likes')
            .select('note_id')
            .eq('user_id', targetUserId);
        _likedNoteIds
          ..clear()
          ..addAll(
            (likesRes as List)
                .map((e) => e['note_id']?.toString() ?? '')
                .where((s) => s.isNotEmpty),
          );
      } catch (e) {
        debugPrint('[NotesRepository] Error fetching note likes: $e');
      }

      // Fetch notes
      final res = await client
          .from('trader_notes')
          .select('*, strategies(id, title)')
          .or('user_id.eq.$targetUserId,is_public.eq.true')
          .order('updated_at', ascending: false);

      final List<AppNote> list = (res as List)
          .map((row) => _mapRowToNote(row as Map<String, dynamic>))
          .toList();

      _notes
        ..clear()
        ..addAll(list);
      _syncAllTickerLinks();
      _publish();

      // Background load comments
      unawaited(_loadCommentsForNotes());
    } catch (e) {
      debugPrint('[NotesRepository] _fetchFromSupabase error: $e');
    }
  }

  Future<void> _loadCommentsForNotes() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = SupabaseConfig.client!;
      final commentsRes = await client
          .from('trader_note_comments')
          .select(
            'id, note_id, user_id, content, created_at, profiles(display_name, username)',
          )
          .order('created_at', ascending: true);

      _commentsByNoteId.clear();
      for (final item in commentsRes as List) {
        final row = item as Map<String, dynamic>;
        final noteId = row['note_id']?.toString();
        if (noteId == null) continue;

        final profiles = row['profiles'] as Map<String, dynamic>?;
        final author = profiles?['display_name'] as String? ??
            profiles?['username'] as String? ??
            'Trader';

        final comment = AppNoteComment(
          id: row['id']?.toString() ?? '',
          userId: row['user_id']?.toString() ?? '',
          authorName: author,
          body: row['content']?.toString() ?? '',
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
        );

        (_commentsByNoteId[noteId] ??= <AppNoteComment>[]).add(comment);
      }

      // Re-populate comments on cached notes
      for (int i = 0; i < _notes.length; i++) {
        final n = _notes[i];
        if (_commentsByNoteId.containsKey(n.id)) {
          _notes[i] = n.copyWith(comments: _commentsByNoteId[n.id]);
        }
      }
      _publish();
    } catch (e) {
      debugPrint('[NotesRepository] _loadCommentsForNotes error: $e');
    }
  }

  void _syncAllTickerLinks() {
    for (final AppNote n in _notes) {
      _recordTickerLinks(n);
    }
  }

  void _recordTickerLinks(AppNote note) {
    final Set<String> tickers = <String>{
      ...note.linkedTickers,
      ...EntityTickerLinksRepository.extractTickers(note.content),
    };
    if (tickers.isNotEmpty) {
      EntityTickerLinksRepository.instance.recordLinks(
        entityType: 'note',
        entityId: note.id,
        tickers: tickers,
        contextSource: note.linkedTickers.isNotEmpty ? 'manual' : 'inline',
      );
    }
  }

  AppNote _mapRowToNote(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final strategyMap = row['strategies'] as Map<String, dynamic>?;
    final strategyName = strategyMap?['title'] as String?;

    final tags = row['tags'] != null
        ? List<String>.from((row['tags'] as List).map((e) => e.toString()))
        : const <String>[];
    final linkedTickers = row['linked_tickers'] != null
        ? List<String>.from(
            (row['linked_tickers'] as List).map((e) => e.toString()),
          )
        : const <String>[];
    final linkedJournalIds = row['linked_journal_ids'] != null
        ? List<String>.from(
            (row['linked_journal_ids'] as List).map((e) => e.toString()),
          )
        : const <String>[];

    final isLiked = _likedNoteIds.contains(id);
    final isFavorite = _favoriteNoteIds.contains(id) ||
        (row['is_favorite'] as bool? ?? false);
    final comments = _commentsByNoteId[id] ?? const <AppNoteComment>[];

    return AppNote(
      id: id,
      userId: row['user_id']?.toString() ?? '',
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      noteType: AppNoteType.fromId(row['note_type'] as String?),
      tags: tags,
      linkedTickers: linkedTickers,
      strategyId: row['strategy_id']?.toString(),
      strategyName: strategyName,
      linkedJournalIds: linkedJournalIds,
      isPublic: row['is_public'] as bool? ?? false,
      wordCount: (row['word_count'] as num?)?.toInt() ?? 0,
      checklistDone: (row['checklist_done'] as num?)?.toInt() ?? 0,
      checklistTotal: (row['checklist_total'] as num?)?.toInt() ?? 0,
      hasImages: row['has_images'] as bool? ?? false,
      hasCode: row['has_code'] as bool? ?? false,
      viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
      liked: isLiked,
      isFavorite: isFavorite,
      comments: comments,
    );
  }

  List<AppNote> _snapshot() {
    final List<AppNote> copy = List<AppNote>.of(_notes)
      ..sort((AppNote a, AppNote b) => b.updatedAt.compareTo(a.updatedAt));
    return List<AppNote>.unmodifiable(copy);
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot());
  }

  @override
  Stream<List<AppNote>> watchAll() {
    _init();
    return Stream<List<AppNote>>.multi((
      MultiStreamController<List<AppNote>> controller,
    ) {
      controller.add(_snapshot());
      final StreamSubscription<List<AppNote>> sub = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<AppNote>> watchPublic() => watchAll().map(
    (List<AppNote> notes) =>
        notes.where((AppNote note) => note.isPublic).toList(growable: false),
  );

  @override
  Future<List<AppNote>> fetchAll() async {
    await _init();
    if (SupabaseConfig.isConfigured) {
      await _fetchFromSupabase();
    }
    return _snapshot();
  }

  @override
  Future<AppNote?> getById(String id) async {
    await _init();
    for (final AppNote note in _notes) {
      if (note.id == id) return note;
    }
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('trader_notes')
            .select('*, strategies(id, title)')
            .eq('id', id)
            .maybeSingle();
        if (res != null) {
          final note = _mapRowToNote(res);
          _notes.removeWhere((n) => n.id == note.id);
          _notes.insert(0, note);
          _recordTickerLinks(note);
          _publish();
          return note;
        }
      } catch (e) {
        debugPrint('[NotesRepository] getById error: $e');
      }
    }
    return null;
  }

  @override
  Future<AppNote> create(AppNote draft) async {
    await _init();
    final DateTime now = DateTime.now();
    final String assignedId =
        draft.id.isEmpty ? const Uuid().v4() : draft.id;
    final String currentUserId = _resolveUserId();

    final AppNote saved = draft
        .copyWith(
          id: assignedId,
          userId: draft.userId.isNotEmpty ? draft.userId : currentUserId,
          createdAt: now,
          updatedAt: now,
        )
        .withDerivedCounts();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final String supabaseId =
            _isUuid(assignedId) ? assignedId : const Uuid().v4();
        final Map<String, dynamic> row = <String, dynamic>{
          'id': supabaseId,
          'user_id': saved.userId,
          'title': saved.title,
          'content': saved.content,
          'note_type': saved.noteType.wireId,
          'tags': saved.tags,
          'linked_tickers': saved.linkedTickers,
          if (_isUuid(saved.strategyId)) 'strategy_id': saved.strategyId,
          'linked_journal_ids':
              saved.linkedJournalIds.where(_isUuid).toList(),
          'is_public': saved.isPublic,
          'word_count': saved.wordCount,
          'checklist_done': saved.checklistDone,
          'checklist_total': saved.checklistTotal,
          'has_images': saved.hasImages,
          'has_code': saved.hasCode,
          'view_count': saved.viewCount,
          'like_count': saved.likeCount,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        await client.from('trader_notes').insert(row);
      } catch (e) {
        debugPrint('[NotesRepository] create error: $e');
      }
    }

    _notes.insert(0, saved);
    _publish();
    _recordTickerLinks(saved);
    return saved;
  }

  @override
  Future<AppNote> update(AppNote note) async {
    await _init();
    final DateTime now = DateTime.now();
    final AppNote saved = note
        .copyWith(updatedAt: now)
        .withDerivedCounts();

    if (SupabaseConfig.isConfigured && _isUuid(saved.id)) {
      try {
        final client = SupabaseConfig.client!;
        final Map<String, dynamic> row = <String, dynamic>{
          'title': saved.title,
          'content': saved.content,
          'note_type': saved.noteType.wireId,
          'tags': saved.tags,
          'linked_tickers': saved.linkedTickers,
          'strategy_id': _isUuid(saved.strategyId) ? saved.strategyId : null,
          'linked_journal_ids':
              saved.linkedJournalIds.where(_isUuid).toList(),
          'is_public': saved.isPublic,
          'word_count': saved.wordCount,
          'checklist_done': saved.checklistDone,
          'checklist_total': saved.checklistTotal,
          'has_images': saved.hasImages,
          'has_code': saved.hasCode,
          'updated_at': now.toIso8601String(),
        };
        await client.from('trader_notes').update(row).eq('id', saved.id);
      } catch (e) {
        debugPrint('[NotesRepository] update error: $e');
      }
    }

    final int at = _notes.indexWhere((AppNote n) => n.id == note.id);
    if (at == -1) {
      _notes.insert(0, saved);
    } else {
      _notes[at] = saved;
    }
    _publish();
    _recordTickerLinks(saved);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    await _init();
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client.from('trader_notes').delete().eq('id', id);
      } catch (e) {
        debugPrint('[NotesRepository] delete error: $e');
      }
    }

    _notes.removeWhere((AppNote n) => n.id == id);
    _commentsByNoteId.remove(id);
    _likedNoteIds.remove(id);
    _favoriteNoteIds.remove(id);
    _publish();
    unawaited(
      EntityTickerLinksRepository.instance.removeLinks(
        entityType: 'note',
        entityId: id,
      ),
    );
  }

  AppNote _mutate(String id, AppNote Function(AppNote note) change) {
    final int index = _notes.indexWhere((AppNote note) => note.id == id);
    if (index < 0) throw StateError('Note not found: $id');
    final AppNote updated = change(_notes[index]);
    _notes[index] = updated;
    _publish();
    return updated;
  }

  @override
  Future<AppNote> recordView(String id) async {
    await _init();
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        final userId = _resolveUserId();
        await client.from('trader_note_views').upsert({
          'note_id': id,
          'user_id': userId,
          'viewed_at': DateTime.now().toUtc().toIso8601String(),
        });
        await client.rpc(
          'increment_note_view',
          params: {'note_uuid': id},
        ).catchError((_) async {
          final current = await getById(id);
          if (current != null) {
            await client
                .from('trader_notes')
                .update({'view_count': current.viewCount + 1})
                .eq('id', id);
          }
        });
      } catch (e) {
        debugPrint('[NotesRepository] recordView error: $e');
      }
    }

    return _mutate(
      id,
      (AppNote note) =>
          note.isPublic ? note.copyWith(viewCount: note.viewCount + 1) : note,
    );
  }

  @override
  Future<AppNote> toggleLike(String id) async {
    await _init();
    final isLikedNow = !_likedNoteIds.contains(id);
    if (isLikedNow) {
      _likedNoteIds.add(id);
    } else {
      _likedNoteIds.remove(id);
    }

    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        final userId = _resolveUserId();
        if (isLikedNow) {
          await client.from('trader_note_likes').insert({
            'note_id': id,
            'user_id': userId,
          });
        } else {
          await client
              .from('trader_note_likes')
              .delete()
              .eq('note_id', id)
              .eq('user_id', userId);
        }
        final note = await getById(id);
        if (note != null) {
          final updatedCount =
              (note.likeCount + (isLikedNow ? 1 : -1)).clamp(0, 1 << 30);
          await client
              .from('trader_notes')
              .update({'like_count': updatedCount})
              .eq('id', id);
        }
      } catch (e) {
        debugPrint('[NotesRepository] toggleLike error: $e');
      }
    }

    return _mutate(id, (AppNote note) {
      if (!note.isPublic) return note;
      return note.copyWith(
        liked: isLikedNow,
        likeCount: (note.likeCount + (isLikedNow ? 1 : -1)).clamp(0, 1 << 30),
      );
    });
  }

  @override
  Future<AppNote> toggleFavorite(String id) async {
    await _init();
    final isFav = !_favoriteNoteIds.contains(id);
    if (isFav) {
      _favoriteNoteIds.add(id);
    } else {
      _favoriteNoteIds.remove(id);
    }

    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('trader_notes')
            .update({'is_favorite': isFav})
            .eq('id', id);
      } catch (e) {
        debugPrint('[NotesRepository] toggleFavorite error: $e');
      }
    }

    return _mutate(
      id,
      (AppNote note) => note.copyWith(isFavorite: isFav),
    );
  }

  @override
  Future<AppNote> setVisibility(String id, bool isPublic) async {
    await _init();
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('trader_notes')
            .update({'is_public': isPublic})
            .eq('id', id);
      } catch (e) {
        debugPrint('[NotesRepository] setVisibility error: $e');
      }
    }

    return _mutate(id, (AppNote note) => note.copyWith(isPublic: isPublic));
  }

  @override
  Future<AppNote> addComment(String id, String body) async {
    await _init();
    final String content = body.trim();
    if (content.isEmpty) {
      final cur = await getById(id);
      if (cur == null) throw StateError('Note not found: $id');
      return cur;
    }

    final commentId = const Uuid().v4();
    final currentUserId = _resolveUserId();
    final now = DateTime.now();

    final comment = AppNoteComment(
      id: commentId,
      userId: currentUserId,
      authorName: 'You',
      body: content,
      createdAt: now,
    );

    (_commentsByNoteId[id] ??= <AppNoteComment>[]).add(comment);

    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client.from('trader_note_comments').insert({
          'id': commentId,
          'note_id': id,
          'user_id': currentUserId,
          'content': content,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('[NotesRepository] addComment error: $e');
      }
    }

    return _mutate(id, (AppNote note) {
      return note.copyWith(
        comments: <AppNoteComment>[...note.comments, comment],
      );
    });
  }

  @override
  Future<String> uploadAttachment(String noteId, File file) async {
    if (SupabaseConfig.isConfigured && _isUuid(noteId)) {
      try {
        final client = SupabaseConfig.client!;
        final ext = file.path.contains('.') ? file.path.split('.').last : 'png';
        final fileName = '${const Uuid().v4()}.$ext';
        final storagePath = '$noteId/$fileName';

        await client.storage.from('note-attachments').upload(
          storagePath,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

        final length = await file.length().catchError((_) => 0);
        await client.from('trader_note_attachments').insert({
          'id': const Uuid().v4(),
          'note_id': noteId,
          'user_id': _resolveUserId(),
          'storage_path': storagePath,
          'filename': fileName,
          'byte_size': length,
          'is_image': true,
        });

        return storagePath;
      } catch (e) {
        debugPrint('[NotesRepository] uploadAttachment error: $e');
      }
    }
    return file.path;
  }

  @override
  Future<String> resolveAttachmentUrl(String ref) async {
    if (SupabaseConfig.isConfigured &&
        !ref.startsWith('http') &&
        !File(ref).existsSync()) {
      try {
        final client = SupabaseConfig.client!;
        return client.storage.from('note-attachments').getPublicUrl(ref);
      } catch (e) {
        debugPrint('[NotesRepository] resolveAttachmentUrl error: $e');
      }
    }
    return ref;
  }
}

/// The single place a screen reaches the repository.
///
/// Deliberately not a provider framework — TradeX has no Riverpod and no
/// router, so features resolve their dependencies through a static accessor and
/// hold state in `StatefulWidget`s. Tests (and, later, the Supabase wiring)
/// replace the instance through [override].
class NotesRepositoryScope {
  const NotesRepositoryScope._();

  static NotesRepository? _override;

  static NotesRepository get repository =>
      _override ?? NotesRepositoryImpl.instance;

  /// Swap the implementation. Pass `null` to restore the demo repository.
  static void override(NotesRepository? replacement) => _override = replacement;
}

/// Pure functions the list screen uses to turn the full note set into what is
/// on screen. Kept out of the widget so the filtering rules can be unit-tested
/// without pumping a frame.
class NotesQuery {
  const NotesQuery._();

  static List<AppNote> apply(
    List<AppNote> notes, {
    String query = '',
    AppNoteType? type,
    String? tag,
    AppNoteSort sort = AppNoteSort.recentlyUpdated,
  }) {
    final String needle = query.trim().toLowerCase();
    final List<AppNote> out = notes.where((AppNote note) {
      if (type != null && note.noteType != type) return false;
      if (tag != null && !note.tags.contains(tag)) return false;
      if (needle.isEmpty) return true;
      // Body included on purpose: notes are long, and the thing a reader
      // remembers is usually a phrase from inside one, not its title.
      return note.title.toLowerCase().contains(needle) ||
          note.content.toLowerCase().contains(needle) ||
          note.tags.any((String t) => t.toLowerCase().contains(needle)) ||
          note.linkedTickers.any(
            (String t) => t.toLowerCase().contains(needle),
          ) ||
          (note.strategyName ?? '').toLowerCase().contains(needle);
    }).toList();

    out.sort(switch (sort) {
      AppNoteSort.recentlyUpdated =>
        (AppNote a, AppNote b) => b.updatedAt.compareTo(a.updatedAt),
      AppNoteSort.recentlyCreated =>
        (AppNote a, AppNote b) => b.createdAt.compareTo(a.createdAt),
      AppNoteSort.titleAscending =>
        (AppNote a, AppNote b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      AppNoteSort.longestFirst =>
        (AppNote a, AppNote b) => b.wordCount.compareTo(a.wordCount),
    });
    return out;
  }

  /// Every tag in use, most frequent first, for the filter chips.
  static List<String> tagsOf(List<AppNote> notes) {
    final Map<String, int> counts = <String, int>{};
    for (final AppNote note in notes) {
      for (final String tag in note.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final List<String> tags = counts.keys.toList()
      ..sort((String a, String b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return tags;
  }
}
