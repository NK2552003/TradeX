import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/record_access.dart';
import 'package:tradex/core/utils/attachment_compression_service.dart';
import 'package:tradex/core/data/owned_record_writer.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/config/supabase_storage_egress.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'note_attachments.dart';

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

  Future<List<AppNote>> fetchPublicNotes();

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
  Future<String> uploadAttachment(
    String noteId,
    File? file, {
    Uint8List? bytes,
    String? filename,
  });

  /// Deletes an attachment from private storage and purges its tracking record.
  Future<void> deleteAttachment(String storagePath);

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
  String? _cacheActor;
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
    final stored =
        SupabaseAuthBackendService.instance.currentUserProfile?.id ??
        AuthBackendService.instance.currentUserProfile?.id;
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return '';
  }

  bool _isUuid(String? id) => id != null && _uuidRegex.hasMatch(id);

  Future<void> _init() async {
    final actor = _resolveUserId();
    if (_cacheActor != actor) {
      _notes.clear();
      _likedNoteIds.clear();
      _favoriteNoteIds.clear();
      _commentsByNoteId.clear();
      _initialized = false;
      NoteAttachments.clearCache();
      _cacheActor = actor;
    }
    if (_initialized) return;
    _initialized = true;
    final preferences = await SharedPreferences.getInstance();
    if (actor.isNotEmpty) {
      _favoriteNoteIds.addAll(
        preferences.getStringList('note_favorites:$actor') ?? const <String>[],
      );
    }

    if (SupabaseConfig.isConfigured) {
      _initRealtime();
      await _fetchFromSupabase();
    } else {
      _publish();
    }
  }

  static const String _selectColumns =
      'id, user_id, title, content, created_at, updated_at, note_type, tags, '
      'linked_tickers, strategy_id, linked_journal_ids, is_public, word_count, '
      'checklist_done, checklist_total, has_images, has_code, view_count, '
      'like_count, strategies(id, title)';

  void _initRealtime() {
    if (_subscribedToRealtime || !SupabaseConfig.isConfigured) return;
    final targetUserId = _resolveUserId();
    if (!_isUuid(targetUserId)) return;
    _subscribedToRealtime = true;

    try {
      final client = SupabaseConfig.client!;
      _realtimeChannel =
          client
              .channel('public:trader_notes_channel')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'trader_notes',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: targetUserId,
                ),
                callback: (PostgresChangePayload payload) {
                  _handlePostgresChange(payload);
                },
              )
            ..subscribe();
    } catch (e) {
      _subscribedToRealtime = false;
      debugPrint('[NotesRepository] Realtime subscription error: $e');
    }
  }

  /// Releases the Realtime channel subscription when disposing this repository.
  void dispose() {
    if (_realtimeChannel != null && SupabaseConfig.isConfigured) {
      try {
        SupabaseConfig.client?.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
      _subscribedToRealtime = false;
    }
    if (!_changes.isClosed) {
      _changes.close();
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
          if (recordUserId == currentUserId) {
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
          final recordUserId = newRecord['user_id']?.toString();
          if (recordUserId == currentUserId) {
            final at = _notes.indexWhere((n) => n.id == note.id);
            if (at != -1) {
              _notes[at] = note;
            } else {
              _notes.insert(0, note);
            }
            _recordTickerLinks(note);
            _publish();
          } else {
            _notes.removeWhere((n) => n.id == note.id);
            _publish();
          }
        }
      } else if (eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final deletedId = oldRecord['id']?.toString();
        if (deletedId != null) {
          _notes.removeWhere((n) => n.id == deletedId);
          _commentsByNoteId.remove(deletedId);
          _likedNoteIds.remove(deletedId);
          _favoriteNoteIds.remove(deletedId);
          NoteAttachments.invalidateForNote(deletedId);
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
      if (targetUserId.isEmpty) {
        _notes.clear();
        _publish();
        return;
      }

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

      // Fetch personal notes belonging to current user
      final res = await client
          .from('trader_notes')
          .select(_selectColumns)
          .eq('user_id', targetUserId)
          .order('updated_at', ascending: false)
          .limit(200);

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
    final noteIds = _notes.map((n) => n.id).where(_isUuid).toList();
    if (noteIds.isEmpty) {
      _commentsByNoteId.clear();
      return;
    }
    try {
      final client = SupabaseConfig.client!;
      final commentsRes = await client
          .from('trader_note_comments')
          .select(
            'id, note_id, user_id, content, created_at, profiles(display_name, handle)',
          )
          .inFilter('note_id', noteIds)
          .order('created_at', ascending: true)
          .limit(300);

      _commentsByNoteId.clear();
      for (final item in commentsRes as List) {
        final row = item as Map<String, dynamic>;
        final noteId = row['note_id']?.toString();
        if (noteId == null) continue;

        final profiles = row['profiles'] as Map<String, dynamic>?;
        final author =
            profiles?['display_name'] as String? ??
            profiles?['handle'] as String? ??
            profiles?['username'] as String? ??
            'Trader';

        final comment = AppNoteComment(
          id: row['id']?.toString() ?? '',
          userId: row['user_id']?.toString() ?? '',
          authorName: author,
          body: row['content']?.toString() ?? '',
          createdAt:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
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
    final isFavorite = _favoriteNoteIds.contains(id);
    final comments = _commentsByNoteId[id] ?? const <AppNoteComment>[];

    return AppNote(
      id: id,
      userId: row['user_id']?.toString() ?? '',
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
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
    ).withDerivedCounts();
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
  Future<List<AppNote>> fetchPublicNotes() async {
    if (!SupabaseConfig.isConfigured) {
      return _notes.where((n) => n.isPublic).toList();
    }
    try {
      final client = SupabaseConfig.client!;
      final res = await client
          .from('trader_notes')
          .select(_selectColumns)
          .eq('is_public', true)
          .order('updated_at', ascending: false)
          .limit(50);
      return (res as List)
          .map((row) => _mapRowToNote(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NotesRepository] fetchPublicNotes error: $e');
      return _notes.where((n) => n.isPublic).toList();
    }
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
            .select(_selectColumns)
            .eq('id', id)
            .maybeSingle();
        if (res != null) {
          final note = _mapRowToNote(res);
          if (!RecordAccess.canRead(note.userId, note.isPublic)) {
            return null;
          }
          final currentUserId = _resolveUserId();
          if (note.userId == currentUserId) {
            final at = _notes.indexWhere((n) => n.id == note.id);
            if (at != -1) {
              _notes[at] = note;
            } else {
              _notes.insert(0, note);
            }
            _recordTickerLinks(note);
            _publish();
          }
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
    RecordAccess.requireService();
    await _init();
    final DateTime now = DateTime.now();
    final String assignedId =
        draft.id.isEmpty || (SupabaseConfig.isConfigured && !_isUuid(draft.id))
        ? const Uuid().v4()
        : draft.id;
    final String currentUserId = _resolveUserId();

    final AppNote saved = draft
        .copyWith(
          id: assignedId,
          userId: currentUserId,
          createdAt: now,
          updatedAt: now,
        )
        .withDerivedCounts();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final String supabaseId = _isUuid(assignedId)
            ? assignedId
            : const Uuid().v4();
        final Map<String, dynamic> row = <String, dynamic>{
          'id': supabaseId,
          'user_id': saved.userId,
          'title': saved.title,
          'content': saved.content,
          'note_type': saved.noteType.wireId,
          'tags': saved.tags,
          'linked_tickers': saved.linkedTickers,
          if (_isUuid(saved.strategyId)) 'strategy_id': saved.strategyId,
          'linked_journal_ids': saved.linkedJournalIds.where(_isUuid).toList(),
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
        await client.from('trader_notes').insert(row).select('id').single();
      } catch (e) {
        debugPrint('[NotesRepository] create error (cloud sync fallback): $e');
      }
    }

    _notes.removeWhere((n) => n.id == saved.id);
    _notes.insert(0, saved);
    _publish();
    _recordTickerLinks(saved);
    return saved;
  }

  @override
  Future<AppNote> update(AppNote note) async {
    RecordAccess.requireService();
    final owned = await getById(note.id);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    await _init();
    final DateTime now = DateTime.now();
    final AppNote saved = note
        .copyWith(userId: owned.userId, updatedAt: now)
        .withDerivedCounts();

    if (SupabaseConfig.isConfigured && _isUuid(saved.id)) {
      try {
        final Map<String, dynamic> row = <String, dynamic>{
          'title': saved.title,
          'content': saved.content,
          'note_type': saved.noteType.wireId,
          'tags': saved.tags,
          'linked_tickers': saved.linkedTickers,
          'strategy_id': _isUuid(saved.strategyId) ? saved.strategyId : null,
          'linked_journal_ids': saved.linkedJournalIds.where(_isUuid).toList(),
          'is_public': saved.isPublic,
          'word_count': saved.wordCount,
          'checklist_done': saved.checklistDone,
          'checklist_total': saved.checklistTotal,
          'has_images': saved.hasImages,
          'has_code': saved.hasCode,
          'updated_at': now.toIso8601String(),
        };
        await OwnedRecordWriter().update('trader_notes', saved.id, row);
      } catch (e) {
        debugPrint('[NotesRepository] update error (cloud sync fallback): $e');
      }
    }

    final int at = _notes.indexWhere((AppNote n) => n.id == note.id);
    if (at == -1) {
      _notes.insert(0, saved);
    } else {
      _notes[at] = saved;
    }
    final removedRefs = NoteAttachments.extractRefs(owned.content)
        .difference(NoteAttachments.extractRefs(saved.content));
    for (final ref in removedRefs) {
      try {
        await deleteAttachment(ref);
      } catch (e) {
        debugPrint('[NotesRepository] update attachment cleanup warning: $e');
      }
    }
    _publish();
    _recordTickerLinks(saved);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    RecordAccess.requireService();
    final owned = await getById(id);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    await _init();
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        final folder = '${owned.userId}/$id';
        final files = await client.storage
            .from('note-attachments')
            .list(path: folder);
        if (files.isNotEmpty) {
          final filePaths = files.map((f) => '$folder/${f.name}').toList();
          await client.storage.from('note-attachments').remove(filePaths);
        }
        await OwnedRecordWriter().delete('trader_notes', id);
      } catch (e) {
        debugPrint('[NotesRepository] delete error: $e');
        rethrow;
      }
    } else {
      for (final ref in NoteAttachments.extractRefs(owned.content)) {
        try {
          await deleteAttachment(ref);
        } catch (_) {}
      }
    }

    _notes.removeWhere((AppNote n) => n.id == id);
    _commentsByNoteId.remove(id);
    _likedNoteIds.remove(id);
    _favoriteNoteIds.remove(id);
    NoteAttachments.invalidateForNote(id);
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
    final current = await getById(id);
    if (current == null) throw StateError('This note is no longer available.');
    if (!current.isPublic) return current;
    if (SupabaseConfig.isConfigured) {
      final actor = SupabaseConfig.client?.auth.currentUser?.id;
      if (actor == null) return current;
      try {
        await SupabaseConfig.client!
            .from('trader_note_views')
            .upsert({
              'note_id': id,
              'user_id': actor,
              'viewed_at': DateTime.now().toUtc().toIso8601String(),
            })
            .select('note_id')
            .single();
        return await getById(id) ?? current;
      } catch (error) {
        debugPrint('[NotesRepository] view could not be recorded: $error');
        return current;
      }
    }
    return _mutate(id, (note) => note.copyWith(viewCount: note.viewCount + 1));
  }

  @override
  Future<AppNote> toggleLike(String id) async {
    RecordAccess.requireService();
    final current = await getById(id);
    if (current == null || !current.isPublic) {
      throw StateError('Only a public note can be liked.');
    }
    final isLikedNow = !_likedNoteIds.contains(id);
    if (SupabaseConfig.isConfigured) {
      final actor = SupabaseConfig.client?.auth.currentUser?.id;
      if (actor == null) throw StateError('Sign in to like a note.');
      final query = SupabaseConfig.client!.from('trader_note_likes');
      if (isLikedNow) {
        await query
            .insert({'note_id': id, 'user_id': actor})
            .select('note_id')
            .single();
      } else {
        await query
            .delete()
            .eq('note_id', id)
            .eq('user_id', actor)
            .select('note_id')
            .single();
      }
    }
    if (isLikedNow) {
      _likedNoteIds.add(id);
    } else {
      _likedNoteIds.remove(id);
    }
    // The database trigger owns aggregate counts. Never overwrite them with a
    // stale client-side increment or modify another author's note row.
    if (SupabaseConfig.isConfigured) return await getById(id) ?? current;
    return _mutate(
      id,
      (note) => note.copyWith(
        liked: isLikedNow,
        likeCount: (note.likeCount + (isLikedNow ? 1 : -1)).clamp(0, 1 << 30),
      ),
    );
  }

  @override
  Future<AppNote> toggleFavorite(String id) async {
    await _init();
    if (await getById(id) == null) {
      throw StateError('This note is no longer available.');
    }
    final isFav = !_favoriteNoteIds.contains(id);
    if (isFav) {
      _favoriteNoteIds.add(id);
    } else {
      _favoriteNoteIds.remove(id);
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'note_favorites:${_resolveUserId()}',
      _favoriteNoteIds.toList(),
    );

    return _mutate(id, (AppNote note) => note.copyWith(isFavorite: isFav));
  }

  @override
  Future<AppNote> setVisibility(String id, bool isPublic) async {
    RecordAccess.requireService();
    final owned = await getById(id);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    await _init();
    if (SupabaseConfig.isConfigured) {
      await OwnedRecordWriter().update('trader_notes', id, {
        'is_public': isPublic,
      });
    }

    NoteAttachments.invalidateForNote(id);
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

  /// Sanitizes file extension using package:path, stripping leading dot,
  /// restricting to `[a-z0-9]`, and defaulting to 'bin' if empty or invalid.
  static String sanitizeExtension(String filePath) {
    final extWithoutDot = p
        .extension(filePath)
        .replaceFirst(RegExp(r'^\.'), '')
        .toLowerCase();
    final sanitizedExt = extWithoutDot.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return sanitizedExt.isNotEmpty ? sanitizedExt : 'bin';
  }

  @override
  Future<String> uploadAttachment(
    String noteId,
    File? file, {
    Uint8List? bytes,
    String? filename,
  }) async {
    RecordAccess.requireService();
    final currentUserId = _resolveUserId();
    if (currentUserId.isEmpty) {
      throw StateError(
        'Unauthorized: user must be authenticated to upload attachments.',
      );
    }
    if (SupabaseConfig.isConfigured) {
      final owner = await getById(noteId);
      if (owner == null) {
        throw StateError('Save this record before adding attachments.');
      }
      RecordAccess.requireOwner(owner.userId);
    }

    final String rawFileName = filename ?? (file != null ? p.basename(file.path) : 'attachment.png');
    final Uint8List rawBytes = bytes ?? (file != null ? await file.readAsBytes() : Uint8List(0));

    final compressed = await AttachmentCompressionService.compressAttachment(
      bytes: rawBytes,
      filename: rawFileName,
    );
    final String effectiveFileName = compressed.filename;
    final String ext = sanitizeExtension(effectiveFileName);
    final Uint8List fileBytes = compressed.bytes;
    final int length = fileBytes.length;

    if (length > 10485760) {
      throw ArgumentError('Attachment file size exceeds the 10 MB limit.');
    }

    if (SupabaseConfig.isConfigured && _isUuid(noteId)) {
      try {
        final client = SupabaseConfig.client!;
        final storagePath = '$currentUserId/$noteId/${const Uuid().v4()}.$ext';

        final mimeType = _resolveMimeType(ext);
        final isImage = NoteAttachments.isImageFile(rawFileName);

        await client.storage
            .from('note-attachments')
            .uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: FileOptions(
                contentType: mimeType,
                cacheControl:
                    SupabaseStorageEgress.noteAttachments.uploadCacheControl,
                upsert: true,
              ),
            );

        try {
          await client
              .from('trader_note_attachments')
              .insert({
                'id': const Uuid().v4(),
                'note_id': noteId,
                'user_id': currentUserId,
                'storage_path': storagePath,
                'filename': rawFileName,
                'mime_type': mimeType,
                'byte_size': length,
                'is_image': isImage,
              });
        } catch (metaError) {
          final isMissingTable = metaError is PostgrestException &&
              (metaError.code == '42P01' || metaError.code == 'PGRST205');
          if (!isMissingTable) {
            try {
              await client.storage
                  .from('note-attachments')
                  .remove(<String>[storagePath]);
            } catch (_) {}
            rethrow;
          }
          debugPrint(
            '[NotesRepository] trader_note_attachments insert warning: $metaError',
          );
        }

        return storagePath;
      } catch (e) {
        debugPrint('[NotesRepository] uploadAttachment cloud error: $e');
        rethrow;
      }
    }
    return file?.path ?? rawFileName;
  }

  @override
  Future<void> deleteAttachment(String storagePath) async {
    RecordAccess.requireService();
    final currentUserId = _resolveUserId();
    if (currentUserId.isEmpty) {
      throw StateError('Unauthorized: user must be authenticated.');
    }

    String cleanPath = storagePath.trim();
    if (cleanPath.startsWith('note-attachments/')) {
      cleanPath = cleanPath.substring('note-attachments/'.length);
    }
    while (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    if (cleanPath.contains('?')) {
      cleanPath = cleanPath.split('?').first;
    }

    final segments = cleanPath.split('/');
    if (segments.isNotEmpty && _isUuid(segments.first)) {
      if (segments.first != currentUserId) {
        throw StateError(
          'Unauthorized: cannot delete attachments belonging to another user.',
        );
      }
    }

    NoteAttachments.invalidate(cleanPath);

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      await client.storage.from('note-attachments').remove([cleanPath]);
      await client
          .from('trader_note_attachments')
          .delete()
          .eq('storage_path', cleanPath)
          .eq('user_id', currentUserId)
          .catchError((_) => null);
    }
  }

  @override
  Future<String> resolveAttachmentUrl(String ref) async {
    // 1. Pass through local files or raw data URIs
    if (ref.startsWith('/') ||
        ref.contains(':\\') ||
        ref.startsWith('file:') ||
        ref.startsWith('data:')) {
      return ref;
    }

    // 2. Extract relative storage path inside note-attachments bucket
    String storagePath = ref.trim();

    if (storagePath.startsWith('https://') || storagePath.startsWith('http://')) {
      final uri = Uri.tryParse(storagePath);
      if (uri != null) {
        final pathSegments = uri.pathSegments;
        final bucketIdx = pathSegments.indexOf('note-attachments');
        if (bucketIdx != -1 && bucketIdx < pathSegments.length - 1) {
          storagePath = pathSegments.sublist(bucketIdx + 1).join('/');
        } else {
          // 3rd party external URL, e.g. unsplash or external CDN
          return ref;
        }
      }
    }

    // Strip leading bucket name or slashes
    if (storagePath.startsWith('note-attachments/')) {
      storagePath = storagePath.substring('note-attachments/'.length);
    }
    while (storagePath.startsWith('/')) {
      storagePath = storagePath.substring(1);
    }

    // Strip query string if any was appended
    if (storagePath.contains('?')) {
      storagePath = storagePath.split('?').first;
    }

    // 3. Authorization check: Private note attachments belong strictly to owner folder
    final currentUserId = _resolveUserId();
    final pathSegments = storagePath.split('/');
    if (pathSegments.length >= 2) {
      final ownerId = pathSegments[0];
      final noteId = pathSegments[1];

      // If owner does not match current user, check if note is public
      if (ownerId != currentUserId) {
        final note = await getById(noteId);
        final isPublic = note?.isPublic ?? false;
        if (!isPublic) {
          throw StateError(
            'Unauthorized: access denied to private attachment belonging to another user.',
          );
        }
      }
    } else if (pathSegments.length == 1 && _isUuid(pathSegments.first)) {
      if (pathSegments.first != currentUserId) {
        throw StateError(
          'Unauthorized: access denied to private attachment belonging to another user.',
        );
      }
    }

    if (!SupabaseConfig.isConfigured) {
      return ref;
    }

    // 4. Generate 1-hour (3600s) expiring signed Direct Egress access URL
    try {
      return await SupabaseConfig.client!.storage
          .from(SupabaseStorageEgress.noteAttachments.bucketId)
          .createSignedUrl(
            storagePath,
            SupabaseStorageEgress.noteAttachments.signedUrlTtlSeconds!,
          );
    } catch (e) {
      debugPrint(
        '[NotesRepository] resolveAttachmentUrl createSignedUrl error: $e',
      );
      rethrow;
    }
  }

  static String _resolveMimeType(String ext) {
    switch (ext.toLowerCase().trim()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'md':
      case 'markdown':
        return 'text/markdown';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }
}

/// The single place a screen reaches the repository.
///
/// Deliberately not a provider framework — alphajournal has no Riverpod and no
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
