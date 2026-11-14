import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/record_access.dart';
import 'package:tradex/core/utils/attachment_compression_service.dart';
import 'package:tradex/core/data/owned_record_writer.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';
import 'package:tradex/features/notes/data/note_attachments.dart';
import 'package:uuid/uuid.dart';

/// Everything the journal feature needs from storage.
///
/// A journal entry is a trade **and** the write-up attached to it. The two are
/// one record on purpose: the numbers without the reasoning are a broker
/// statement, and the reasoning without the numbers is a diary. Splitting them
/// into two tables would let one exist without the other, which is the failure
/// mode this feature exists to prevent.
abstract class JournalRepository {
  /// Emits the full journal, newest trade first, and re-emits after every
  /// mutation so an edit made in the editor shows up on the index without the
  /// list screen polling for it.
  Stream<List<AppTrade>> watchAll();

  /// Entries the owner has explicitly allowed a public post to reference.
  Stream<List<AppTrade>> watchPublic();

  Future<List<AppTrade>> fetchAll();

  Future<List<AppTrade>> fetchPublicEntries();

  Future<AppTrade?> getById(String id);

  Future<AppTrade> create(AppTrade draft);

  Future<AppTrade> update(AppTrade entry);

  Future<AppTrade> toggleFavorite(String id);

  Future<AppTrade> setVisibility(String id, bool isPublic);

  Future<void> delete(String id);

  /// Attaches a trader note to [entryId]. Idempotent — linking twice is the
  /// same as linking once, because the caller is usually a picker the trader
  /// can reopen.
  Future<AppTrade> linkNote(String entryId, String noteId);

  Future<AppTrade> unlinkNote(String entryId, String noteId);

  /// Files [entryId] under a playbook, or clears it when [strategyId] is null.
  /// [strategyName] is denormalised onto the entry so a list row can render the
  /// playbook without resolving the graph first.
  Future<AppTrade> attachStrategy(
    String entryId,
    String? strategyId, {
    String? strategyName,
  });

  /// Stores a chart screenshot or document against [entryId] and returns the
  /// opaque reference the markdown body embeds.
  ///
  /// A journal entry's attachments belong to the journal, not to the notes
  /// bucket: a trader who deletes a note must not lose the screenshot that
  /// proves what a trade looked like.
  Future<String> uploadAttachment(
    String entryId,
    File? file, {
    Uint8List? bytes,
    String? filename,
  });

  /// Deletes an attachment from private storage and purges its tracking record.
  Future<void> deleteAttachment(String storagePath);

  /// Turns a stored reference back into something the preview can load. Local
  /// paths come back unchanged; private journal attachments resolve to 1-hour signed URLs.
  Future<String> resolveAttachmentUrl(String ref);

  /// Calculated summary metrics across all currently held entries.
  AppJournalStats get stats;
}

/// Live Supabase-backed implementation with real-time sync and offline resilience.
class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl._();

  /// Shared so the index, the reader and the editor observe one journal.
  static final JournalRepositoryImpl instance = JournalRepositoryImpl._();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final Set<String> _favoriteIds = {};
  final List<AppTrade> _entries = <AppTrade>[];
  final StreamController<List<AppTrade>> _changes =
      StreamController<List<AppTrade>>.broadcast();
  bool _initialized = false;
  String? _cacheActor;
  bool _subscribedToRealtime = false;
  RealtimeChannel? _realtimeChannel;

  /// Active Supabase Realtime channel, if subscribed.
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
      _entries.clear();
      _favoriteIds.clear();
      _initialized = false;
      _cacheActor = actor;
    }
    if (_initialized) return;
    _initialized = true;
    final preferences = await SharedPreferences.getInstance();
    if (actor.isNotEmpty) {
      _favoriteIds.addAll(
        preferences.getStringList('journal_favorites:$actor') ??
            const <String>[],
      );
    }

    await _loadLocalCache(preferences, actor);

    if (SupabaseConfig.isConfigured) {
      _initRealtime();
      await _fetchFromSupabase();
    } else {
      _publish();
    }
  }

  String _localCacheKey(String actor) =>
      actor.isEmpty ? 'journal_entries_cache:guest' : 'journal_entries_cache:$actor';

  Future<void> _loadLocalCache(
    SharedPreferences preferences,
    String actor,
  ) async {
    try {
      final raw = preferences.getStringList(_localCacheKey(actor));
      if (raw == null || raw.isEmpty) return;
      for (final item in raw) {
        final parts = item.split('||');
        if (parts.length < 11) continue;
        final id = parts[0];
        if (_entries.any((e) => e.id == id)) continue;
        final trade = AppTrade(
          id: id,
          userId: parts[1],
          ticker: parts[2],
          side: parts[3] == 'short' ? AppSide.short : AppSide.long,
          entry: double.tryParse(parts[4]) ?? 0,
          exit: parts[5].isEmpty ? null : double.tryParse(parts[5]),
          stopLoss: parts[6].isEmpty ? null : double.tryParse(parts[6]),
          target: parts[7].isEmpty ? null : double.tryParse(parts[7]),
          size: double.tryParse(parts[8]) ?? 1,
          pnl: double.tryParse(parts[9]) ?? 0,
          openedAt: DateTime.tryParse(parts[10]) ?? DateTime.now(),
          title: parts.length > 11 ? parts[11] : '',
          notes: parts.length > 12 && parts[12].isNotEmpty ? parts[12] : null,
          tags: parts.length > 13 && parts[13].isNotEmpty
              ? parts[13].split(',')
              : const <String>[],
        ).withDerivedCounts();
        _entries.add(trade);
      }
    } catch (_) {}
  }

  Future<void> _saveLocalCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final actor = _resolveUserId();
      final serialized = _entries.take(100).map((t) {
        final safeTitle = t.title.replaceAll('||', ' ');
        final safeNotes = (t.notes ?? '').replaceAll('||', ' ');
        final safeTags = t.tags.join(',');
        return <String>[
          t.id,
          t.userId,
          t.ticker,
          t.side == AppSide.short ? 'short' : 'long',
          t.entry.toString(),
          t.exit?.toString() ?? '',
          t.stopLoss?.toString() ?? '',
          t.target?.toString() ?? '',
          t.size.toString(),
          t.pnl.toString(),
          t.openedAt.toIso8601String(),
          safeTitle,
          safeNotes,
          safeTags,
        ].join('||');
      }).toList();
      await preferences.setStringList(_localCacheKey(actor), serialized);
    } catch (_) {}
  }

  void _initRealtime() {
    if (_subscribedToRealtime || !SupabaseConfig.isConfigured) return;
    _subscribedToRealtime = true;

    try {
      final client = SupabaseConfig.client!;
      _realtimeChannel =
          client
              .channel('public:journal_entries_channel')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'journal_entries',
                callback: (PostgresChangePayload payload) {
                  _handlePostgresChange(payload);
                },
              )
            ..subscribe();
    } catch (e) {
      debugPrint('[JournalRepository] Realtime subscription error: $e');
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
            final trade = _mapRowToTrade(newRecord);
            _entries.removeWhere((t) => t.id == trade.id);
            _entries.insert(0, trade);
            _recordTickerLinks(trade);
            _publish();
          }
        }
      } else if (eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final trade = _mapRowToTrade(newRecord);
          final recordUserId = newRecord['user_id']?.toString();
          if (recordUserId == currentUserId) {
            final at = _entries.indexWhere((t) => t.id == trade.id);
            if (at != -1) {
              _entries[at] = trade;
            } else {
              _entries.insert(0, trade);
            }
            _recordTickerLinks(trade);
            _publish();
          } else {
            _entries.removeWhere((t) => t.id == trade.id);
            _publish();
          }
        }
      } else if (eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final deletedId = oldRecord['id']?.toString();
        if (deletedId != null) {
          _entries.removeWhere((t) => t.id == deletedId);
          unawaited(
            EntityTickerLinksRepository.instance.removeLinks(
              entityType: 'journal',
              entityId: deletedId,
            ),
          );
          _publish();
        }
      }
    } catch (e) {
      debugPrint('[JournalRepository] Error handling postgres change: $e');
    }
  }

  Future<void> _fetchFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty) {
        _publish();
        return;
      }

      final res = await client
          .from('journal_entries')
          .select('*, strategies(id, title, name)')
          .eq('user_id', targetUserId)
          .order('opened_at', ascending: false);

      final List<AppTrade> list = (res as List)
          .map((row) => _mapRowToTrade(row as Map<String, dynamic>))
          .toList();

      final remoteIds = list.map((t) => t.id).toSet();
      final localUnsynced = _entries
          .where((t) => !remoteIds.contains(t.id))
          .toList();

      _entries
        ..clear()
        ..addAll(list)
        ..addAll(localUnsynced);
      _syncAllTickerLinks();
      unawaited(_saveLocalCache());
      _publish();
    } catch (e) {
      debugPrint('[JournalRepository] _fetchFromSupabase error: $e');
    }
  }

  void _syncAllTickerLinks() {
    for (final AppTrade t in _entries) {
      _recordTickerLinks(t);
    }
  }

  void _recordTickerLinks(AppTrade trade) {
    final Set<String> tickers = <String>{
      if (trade.ticker.isNotEmpty) trade.ticker,
      ...EntityTickerLinksRepository.extractTickers(trade.content),
    };
    if (tickers.isNotEmpty) {
      EntityTickerLinksRepository.instance.recordLinks(
        entityType: 'journal',
        entityId: trade.id,
        tickers: tickers,
        contextSource: 'trade_instrument',
      );
    }
  }

  AppTrade _mapRowToTrade(Map<String, dynamic> row) {
    final String sideStr = (row['side'] as String? ?? 'long').toLowerCase();
    final String outcomeStr = (row['outcome'] as String? ?? 'open')
        .toLowerCase();
    final List<dynamic>? screenshots = row['screenshots'] as List<dynamic>?;
    final List<dynamic>? linkedNotes = row['linked_note_ids'] as List<dynamic>?;
    final List<dynamic>? tagsList = row['tags'] as List<dynamic>?;

    String? strategyName =
        (row['strategy_name'] ?? row['strategy']) as String?;
    if (strategyName == null) {
      if (row['strategies'] is Map) {
        final sMap = row['strategies'] as Map;
        strategyName = (sMap['title'] ?? sMap['name'])?.toString();
      } else if (row['strategies'] is List &&
          (row['strategies'] as List).isNotEmpty) {
        final first = (row['strategies'] as List).first;
        if (first is Map) {
          strategyName = (first['title'] ?? first['name'])?.toString();
        }
      }
    }

    final AppOutcome outcome = switch (outcomeStr) {
      'win' => AppOutcome.win,
      'loss' => AppOutcome.loss,
      'breakeven' || 'break_even' => AppOutcome.breakeven,
      _ => AppOutcome.open,
    };

    final DateTime openedAt = row['opened_at'] != null
        ? DateTime.tryParse(row['opened_at'].toString()) ?? DateTime.now()
        : (row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString()) ??
                    DateTime.now()
              : DateTime.now());

    final DateTime? closedAt = row['closed_at'] != null
        ? DateTime.tryParse(row['closed_at'].toString())
        : null;

    final DateTime? updatedAt = row['updated_at'] != null
        ? DateTime.tryParse(row['updated_at'].toString())
        : null;

    final String content = row['content'] as String? ?? '';
    final String? psychology = row['psychology'] as String?;
    final String? mistakes = row['mistakes_made'] as String?;
    final String? lessons = row['lessons_learned'] as String?;
    final String? notesField = (row['notes'] ?? row['summary']) as String?;
    final String? notes =
        notesField ?? psychology ?? mistakes ?? lessons;

    return AppTrade(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      ticker: (row['ticker'] as String? ?? '').toUpperCase(),
      side: (sideStr == 'short' || sideStr == 'sell')
          ? AppSide.short
          : AppSide.long,
      entry: (row['entry_price'] as num?)?.toDouble() ?? 0.0,
      exit: (row['exit_price'] as num?)?.toDouble(),
      openedAt: openedAt,
      closedAt: closedAt,
      stopLoss: (row['stop_loss'] as num?)?.toDouble(),
      target: (row['target'] as num?)?.toDouble(),
      size: (row['size'] as num?)?.toDouble() ?? 1.0,
      pnl: (row['pnl'] as num?)?.toDouble() ?? 0.0,
      pnlPercent: (row['pnl_percent'] as num?)?.toDouble() ?? 0.0,
      rMultiple: (row['r_multiple'] as num?)?.toDouble(),
      outcome: outcome,
      strategyId: row['strategy_id']?.toString(),
      strategy: strategyName,
      tags: tagsList != null
          ? List<String>.from(tagsList.map((e) => e.toString()))
          : const <String>[],
      notes: notes,
      title: row['title'] as String? ?? '',
      content: content,
      screenshotUrl: (screenshots != null && screenshots.isNotEmpty)
          ? screenshots.first.toString()
          : null,
      psychologyScore: (row['psychology_score'] as num?)?.toInt(),
      linkedNoteIds: linkedNotes != null
          ? List<String>.from(linkedNotes.map((e) => e.toString()))
          : const <String>[],
      isPublic: row['is_public'] as bool? ?? false,
      updatedAt: updatedAt,
      wordCount: (row['word_count'] as num?)?.toInt() ?? 0,
      checklistDone: (row['checklist_done'] as num?)?.toInt() ?? 0,
      checklistTotal: (row['checklist_total'] as num?)?.toInt() ?? 0,
      hasImages: row['has_images'] as bool? ?? false,
      hasCode: row['has_code'] as bool? ?? false,
      isFavorite: _favoriteIds.contains(row['id']?.toString()),
    );
  }

  Map<String, dynamic> _mapTradeToRow(
    AppTrade trade,
    String userId, {
    String? targetId,
  }) {
    final String sideStr = trade.side == AppSide.short ? 'short' : 'long';
    final String outcomeStr = trade.outcome.name;

    final Map<String, dynamic> row = <String, dynamic>{
      'user_id': userId,
      'title': trade.title,
      'ticker': trade.ticker.toUpperCase(),
      'content': trade.content.isNotEmpty ? trade.content : (trade.notes ?? ''),
      'entry_price': trade.entry,
      'size': trade.size,
      'side': sideStr,
      'pnl': trade.pnl,
      'pnl_percent': trade.pnlPercent,
      'outcome': outcomeStr,
      'outcome_source': 'auto',
      'tags': trade.tags,
      'linked_note_ids': trade.linkedNoteIds,
      'word_count': trade.wordCount,
      'checklist_done': trade.checklistDone,
      'checklist_total': trade.checklistTotal,
      'has_images': trade.hasImages,
      'has_code': trade.hasCode,
      'is_public': trade.isPublic,
      'opened_at': trade.openedAt.toIso8601String(),
    };

    if (targetId != null && targetId.isNotEmpty) {
      row['id'] = targetId;
    }

    if (trade.rMultiple != null) row['r_multiple'] = trade.rMultiple;
    if (trade.stopLoss != null) row['stop_loss'] = trade.stopLoss;
    if (trade.target != null) row['target'] = trade.target;
    if (trade.strategyId != null &&
        trade.strategyId!.isNotEmpty &&
        _isUuid(trade.strategyId)) {
      row['strategy_id'] = trade.strategyId;
    } else {
      row['strategy_id'] = null;
    }

    if (trade.strategy != null && trade.strategy!.isNotEmpty) {
      row['strategy_name'] = trade.strategy;
    } else {
      row['strategy_name'] = null;
    }

    if (trade.outcome != AppOutcome.open) {
      if (trade.exit != null) row['exit_price'] = trade.exit;
      if (trade.closedAt != null) {
        row['closed_at'] = trade.closedAt!.toIso8601String();
      }
    } else {
      row['exit_price'] = null;
      row['closed_at'] = null;
    }

    if (trade.screenshotUrl != null && trade.screenshotUrl!.isNotEmpty) {
      row['screenshots'] = <String>[trade.screenshotUrl!];
    }
    if (trade.psychologyScore != null) {
      row['psychology_score'] = trade.psychologyScore;
    }

    return row;
  }

  List<AppTrade> _snapshot() {
    final List<AppTrade> copy = List<AppTrade>.of(_entries)
      ..sort((AppTrade a, AppTrade b) => b.sortDate.compareTo(a.sortDate));
    return List<AppTrade>.unmodifiable(copy);
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot());
  }

  @override
  Stream<List<AppTrade>> watchAll() {
    unawaited(_init());
    return Stream<List<AppTrade>>.multi((
      MultiStreamController<List<AppTrade>> controller,
    ) {
      controller.add(_snapshot());
      final StreamSubscription<List<AppTrade>> sub = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<AppTrade>> watchPublic() => watchAll().map(
    (List<AppTrade> entries) => entries
        .where((AppTrade entry) => entry.isPublic)
        .toList(growable: false),
  );

  @override
  AppJournalStats get stats => JournalQuery.statsOf(_entries);

  @override
  Future<List<AppTrade>> fetchAll() async {
    await _init();
    if (SupabaseConfig.isConfigured) {
      await _fetchFromSupabase();
    }
    return _snapshot();
  }

  @override
  Future<List<AppTrade>> fetchPublicEntries() async {
    if (!SupabaseConfig.isConfigured) {
      return _entries.where((e) => e.isPublic).toList();
    }
    try {
      final client = SupabaseConfig.client!;
      final res = await client
          .from('journal_entries')
          .select('*, strategies(id, title, name)')
          .eq('is_public', true)
          .order('opened_at', ascending: false)
          .limit(50);
      return (res as List)
          .map((row) => _mapRowToTrade(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[JournalRepository] fetchPublicEntries error: $e');
      return _entries.where((e) => e.isPublic).toList();
    }
  }

  @override
  Future<AppTrade?> getById(String id) async {
    await _init();
    for (final AppTrade entry in _entries) {
      if (entry.id == id) return entry;
    }
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('journal_entries')
            .select('*, strategies(id, title, name)')
            .eq('id', id)
            .maybeSingle();
        if (res != null) {
          final trade = _mapRowToTrade(res);
          if (!RecordAccess.canRead(trade.userId, trade.isPublic)) {
            return null;
          }
          final currentUserId = _resolveUserId();
          if (trade.userId == currentUserId) {
            final at = _entries.indexWhere((t) => t.id == trade.id);
            if (at == -1) {
              _entries.insert(0, trade);
            } else {
              _entries[at] = trade;
            }
            _recordTickerLinks(trade);
            _publish();
          }
          return trade;
        }
      } catch (e) {
        debugPrint('[JournalRepository] getById error: $e');
      }
    }
    return null;
  }

  @override
  Future<AppTrade> create(AppTrade draft) async {
    RecordAccess.requireService();
    await _init();

    AppTrade saved = draft;
    final targetUserId = _resolveUserId();
    final String assignedId = _isUuid(draft.id) ? draft.id : const Uuid().v4();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final row = _mapTradeToRow(
          draft.withDerivedCounts(),
          targetUserId,
          targetId: assignedId,
        );

        final res = await client
            .from('journal_entries')
            .insert(row)
            .select('*, strategies(id, title, name)')
            .single();

        saved = _mapRowToTrade(res);
      } catch (e) {
        debugPrint(
          '[JournalRepository] create error (cloud sync fallback): $e',
        );
        saved = draft
            .copyWith(
              id: assignedId,
              userId: targetUserId,
              updatedAt: DateTime.now(),
            )
            .withDerivedCounts();
      }
    } else {
      saved = draft
          .copyWith(
            id: assignedId,
            userId: targetUserId.isNotEmpty ? targetUserId : draft.userId,
            updatedAt: DateTime.now(),
          )
          .withDerivedCounts();
    }

    _entries.removeWhere((AppTrade t) => t.id == saved.id);
    _entries.insert(0, saved);
    unawaited(_saveLocalCache());
    _publish();
    _recordTickerLinks(saved);

    return saved;
  }

  @override
  Future<AppTrade> update(AppTrade entry) async {
    RecordAccess.requireService();
    final owned = await getById(entry.id);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    await _init();

    AppTrade saved = entry.copyWith(userId: owned.userId).withDerivedCounts();
    if (SupabaseConfig.isConfigured && _isUuid(entry.id)) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        final row = _mapTradeToRow(saved, targetUserId);
        row.remove('id');
        row['updated_at'] = DateTime.now().toIso8601String();

        final res = await client
            .from('journal_entries')
            .update(row)
            .eq('id', entry.id)
            .eq('user_id', targetUserId)
            .select('*, strategies(id, title, name)')
            .single();

        saved = _mapRowToTrade(res);
      } catch (e) {
        debugPrint(
          '[JournalRepository] update error (cloud sync fallback): $e',
        );
      }
    }

    final int at = _entries.indexWhere((AppTrade t) => t.id == entry.id);
    if (at == -1) {
      _entries.insert(0, saved);
    } else {
      _entries[at] = saved;
    }
    final removedRefs = NoteAttachments.extractRefs(owned.content)
        .difference(NoteAttachments.extractRefs(saved.content));
    for (final ref in removedRefs) {
      try {
        await deleteAttachment(ref);
      } catch (e) {
        debugPrint('[JournalRepository] update attachment cleanup warning: $e');
      }
    }
    unawaited(_saveLocalCache());
    _publish();
    _recordTickerLinks(saved);

    return saved;
  }

  @override
  Future<AppTrade> toggleFavorite(String id) async {
    final current = await getById(id);
    if (current == null) throw StateError('This trade is no longer available.');
    final next = !current.isFavorite;
    if (next) {
      _favoriteIds.add(id);
    } else {
      _favoriteIds.remove(id);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'journal_favorites:${_resolveUserId()}',
      _favoriteIds.toList(),
    );
    return _mutate(id, (entry) => entry.copyWith(isFavorite: next));
  }

  @override
  Future<AppTrade> setVisibility(String id, bool isPublic) async {
    RecordAccess.requireService();
    final owned = await getById(id);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured) {
      await OwnedRecordWriter().update('journal_entries', id, {
        'is_public': isPublic,
      });
    }

    return _mutate(id, (AppTrade entry) => entry.copyWith(isPublic: isPublic));
  }

  /// Updates the public visibility of all owned journal entries so that
  /// toggling "Show verified trade logs in public journal" immediately reflects
  /// across the public journal stream and Supabase.
  Future<void> setAllVisibility(bool isPublic) async {
    await _init();
    final String targetUserId = _resolveUserId();
    bool changed = false;
    for (int i = 0; i < _entries.length; i++) {
      final AppTrade entry = _entries[i];
      if ((targetUserId.isNotEmpty && entry.userId == targetUserId) ||
          RecordAccess.owns(entry.userId)) {
        if (entry.isPublic != isPublic) {
          _entries[i] = entry.copyWith(isPublic: isPublic);
          changed = true;
        }
      }
    }
    if (changed) {
      unawaited(_saveLocalCache());
      _publish();
    }
    if (SupabaseConfig.isConfigured && targetUserId.isNotEmpty) {
      try {
        await SupabaseConfig.client!
            .from('journal_entries')
            .update(<String, dynamic>{
              'is_public': isPublic,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', targetUserId);
      } catch (e) {
        debugPrint('[JournalRepository] setAllVisibility error: $e');
      }
    }
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

        // Note: Storage cleanup and database deletion are not atomic in Supabase.
        // We purge storage first; if listing or removing attachments fails, the
        // error propagates out immediately so the database row and local cache
        // are preserved for retry.
        final folder = '${owned.userId}/$id';
        final files = await client.storage
            .from('journal-attachments')
            .list(path: folder);
        if (files.isNotEmpty) {
          final filePaths = files.map((f) => '$folder/${f.name}').toList();
          await client.storage.from('journal-attachments').remove(filePaths);
        }

        await OwnedRecordWriter().delete('journal_entries', id);
      } catch (e) {
        debugPrint('[JournalRepository] delete error: $e');
        rethrow;
      }
    } else {
      for (final ref in NoteAttachments.extractRefs(owned.content)) {
        try {
          await deleteAttachment(ref);
        } catch (_) {}
      }
    }

    _entries.removeWhere((AppTrade t) => t.id == id);
    unawaited(_saveLocalCache());
    _publish();
    unawaited(
      EntityTickerLinksRepository.instance.removeLinks(
        entityType: 'journal',
        entityId: id,
      ),
    );
  }

  AppTrade _mutate(String id, AppTrade Function(AppTrade entry) change) {
    final int at = _entries.indexWhere((AppTrade t) => t.id == id);
    if (at < 0) throw StateError('Journal entry not found: $id');
    final AppTrade updated = change(
      _entries[at],
    ).copyWith(updatedAt: DateTime.now());
    _entries[at] = updated;
    _publish();
    return updated;
  }

  @override
  Future<AppTrade> linkNote(String entryId, String noteId) async {
    RecordAccess.requireService();
    final owned = await getById(entryId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured && _isUuid(entryId)) {
      try {
        final client = SupabaseConfig.client!;
        final trade = await getById(entryId);
        if (trade != null && !trade.linkedNoteIds.contains(noteId)) {
          final updated = <String>[...trade.linkedNoteIds, noteId];
          await client
              .from('journal_entries')
              .update({'linked_note_ids': updated})
              .eq('id', entryId)
              .eq('user_id', _resolveUserId())
              .select('id')
              .single();
          if (_isUuid(noteId)) {
            try {
              await client.from('note_journal_links').upsert({
                'journal_entry_id': entryId,
                'note_id': noteId,
              });
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[JournalRepository] linkNote error: $e');
        rethrow;
      }
    }
    return _mutate(entryId, (AppTrade entry) {
      if (entry.linkedNoteIds.contains(noteId)) return entry;
      return entry.copyWith(
        linkedNoteIds: <String>[...entry.linkedNoteIds, noteId],
      );
    });
  }

  @override
  Future<AppTrade> unlinkNote(String entryId, String noteId) async {
    RecordAccess.requireService();
    final owned = await getById(entryId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured && _isUuid(entryId)) {
      try {
        final client = SupabaseConfig.client!;
        final trade = await getById(entryId);
        if (trade != null) {
          final updated = trade.linkedNoteIds
              .where((String id) => id != noteId)
              .toList(growable: false);
          await client
              .from('journal_entries')
              .update({'linked_note_ids': updated})
              .eq('id', entryId)
              .eq('user_id', _resolveUserId())
              .select('id')
              .single();
          if (_isUuid(noteId)) {
            try {
              await client.from('note_journal_links').delete().match({
                'journal_entry_id': entryId,
                'note_id': noteId,
              });
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[JournalRepository] unlinkNote error: $e');
        rethrow;
      }
    }
    return _mutate(entryId, (AppTrade entry) {
      return entry.copyWith(
        linkedNoteIds: entry.linkedNoteIds
            .where((String id) => id != noteId)
            .toList(growable: false),
      );
    });
  }

  @override
  Future<AppTrade> attachStrategy(
    String entryId,
    String? strategyId, {
    String? strategyName,
  }) async {
    RecordAccess.requireService();
    final owned = await getById(entryId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);

    String? resolvedName = strategyName;
    final validStrategyId =
        strategyId != null && strategyId.isNotEmpty && _isUuid(strategyId)
            ? strategyId
            : null;

    if (SupabaseConfig.isConfigured && _isUuid(entryId)) {
      try {
        final client = SupabaseConfig.client!;

        // If strategyId was provided but name was omitted, fetch title / name from strategies
        if (validStrategyId != null && (resolvedName == null || resolvedName.isEmpty)) {
          try {
            final stratRow = await client
                .from('strategies')
                .select('id, title, name')
                .eq('id', validStrategyId)
                .maybeSingle();
            if (stratRow != null) {
              resolvedName = (stratRow['title'] ?? stratRow['name'])?.toString();
            }
          } catch (_) {}
        }

        final updatePayload = <String, dynamic>{
          'strategy_id': validStrategyId,
          'strategy_name': validStrategyId != null ? resolvedName : null,
        };

        final updatedRow = await client
            .from('journal_entries')
            .update(updatePayload)
            .eq('id', entryId)
            .eq('user_id', _resolveUserId())
            .select('id, strategy_name')
            .single();

        resolvedName = updatedRow['strategy_name']?.toString();
      } catch (e) {
        debugPrint('[JournalRepository] attachStrategy error: $e');
        rethrow;
      }
    }
    return _mutate(entryId, (AppTrade entry) {
      if (validStrategyId == null) {
        return entry.copyWith(clearStrategy: true);
      }
      if (resolvedName != null && resolvedName.isNotEmpty) {
        return entry.copyWith(
          strategyId: validStrategyId,
          strategy: resolvedName,
        );
      } else {
        // Persisted name is null/empty, but strategyId is valid: clear previous local strategy name while retaining strategyId
        return entry.copyWith(
          strategyId: validStrategyId,
          clearStrategyName: true,
        );
      }
    });
  }

  @override
  Future<String> uploadAttachment(
    String entryId,
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
      final owner = await getById(entryId);
      if (owner == null) {
        throw StateError('Save this record before adding attachments.');
      }
      RecordAccess.requireOwner(owner.userId);
    }

    final Uint8List rawBytes = bytes ?? (file != null ? await file.readAsBytes() : Uint8List(0));
    final String rawFileName = filename ?? (file != null ? p.basename(file.path) : 'attachment.png');

    final compressed = await AttachmentCompressionService.compressAttachment(
      bytes: rawBytes,
      filename: rawFileName,
    );
    final Uint8List fileBytes = compressed.bytes;
    final String effectiveFileName = compressed.filename;
    final rawExt = effectiveFileName.contains('.') ? effectiveFileName.split('.').last : 'webp';
    final ext = rawExt.toLowerCase().trim();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final storagePath = '$currentUserId/$entryId/${const Uuid().v4()}.$ext';
        final length = fileBytes.length;

        if (length > 10485760) {
          throw ArgumentError('Attachment file size exceeds the 10 MB limit.');
        }

        await client.storage
            .from('journal-attachments')
            .uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: FileOptions(
                contentType: _resolveMimeType(ext),
                cacheControl: '3600',
                upsert: true,
              ),
            );

        try {
          await client
              .from('journal_entry_attachments')
              .insert({
                'id': const Uuid().v4(),
                'entry_id': entryId,
                'user_id': currentUserId,
                'storage_path': storagePath,
                'filename': rawFileName,
                'mime_type': _resolveMimeType(ext),
                'byte_size': length,
                'is_image': _isImageExtension(ext),
              });
        } catch (metaError) {
          final isMissingTable = metaError is PostgrestException &&
              (metaError.code == '42P01' || metaError.code == 'PGRST205');
          if (!isMissingTable) {
            try {
              await client.storage
                  .from('journal-attachments')
                  .remove(<String>[storagePath]);
            } catch (_) {}
            rethrow;
          }
          debugPrint(
            '[JournalRepository] journal_entry_attachments insert warning: $metaError',
          );
        }

        return storagePath;
      } catch (e) {
        debugPrint('[JournalRepository] uploadAttachment error: $e');
        rethrow;
      }
    }
    return file?.path ?? rawFileName;
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

    // 2. Extract the relative storage path inside journal-attachments bucket
    String storagePath = ref.trim();

    if (storagePath.startsWith('https://') || storagePath.startsWith('http://')) {
      final uri = Uri.tryParse(storagePath);
      if (uri != null) {
        final pathSegments = uri.pathSegments;
        final bucketIdx = pathSegments.indexOf('journal-attachments');
        if (bucketIdx != -1 && bucketIdx < pathSegments.length - 1) {
          storagePath = pathSegments.sublist(bucketIdx + 1).join('/');
        } else {
          // 3rd party external URL, e.g. unsplash or external CDN
          return ref;
        }
      }
    }

    // Strip leading bucket name or slashes
    if (storagePath.startsWith('journal-attachments/')) {
      storagePath = storagePath.substring('journal-attachments/'.length);
    }
    while (storagePath.startsWith('/')) {
      storagePath = storagePath.substring(1);
    }

    // Strip query string if any was appended
    if (storagePath.contains('?')) {
      storagePath = storagePath.split('?').first;
    }

    // 3. Authorization check: Private bucket belongs strictly to owner folder
    final currentUserId = _resolveUserId();
    final pathSegments = storagePath.split('/');
    if (pathSegments.isNotEmpty) {
      final ownerId = pathSegments.first;
      if (_isUuid(ownerId) && ownerId != currentUserId) {
        throw StateError(
          'Unauthorized: access denied to private attachment belonging to another user.',
        );
      }
    }

    if (!SupabaseConfig.isConfigured) {
      return ref;
    }

    if (currentUserId.isEmpty) {
      throw StateError(
        'Unauthorized: unauthenticated access to private journal attachments is forbidden.',
      );
    }

    // 4. Generate 1-hour (3600s) expiring signed access URL
    try {
      return await SupabaseConfig.client!.storage
          .from('journal-attachments')
          .createSignedUrl(storagePath, 3600);
    } catch (e) {
      debugPrint('[JournalRepository] resolveAttachmentUrl createSignedUrl error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAttachment(String storagePath) async {
    RecordAccess.requireService();
    final currentUserId = _resolveUserId();
    if (currentUserId.isEmpty) {
      throw StateError('Unauthorized: user must be authenticated.');
    }

    String cleanPath = storagePath.trim();
    if (cleanPath.startsWith('journal-attachments/')) {
      cleanPath = cleanPath.substring('journal-attachments/'.length);
    }
    while (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    if (cleanPath.contains('?')) {
      cleanPath = cleanPath.split('?').first;
    }

    final segments = cleanPath.split('/');
    if (segments.length >= 2 && segments.first != currentUserId) {
      throw StateError(
        'Unauthorized: cannot delete another user\'s attachment.',
      );
    }

    NoteAttachments.invalidate(cleanPath);

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        // Purge tracking record from database
        await client
            .from('journal_entry_attachments')
            .delete()
            .eq('storage_path', cleanPath)
            .eq('user_id', currentUserId);

        // Remove object from private storage bucket
        await client.storage
            .from('journal-attachments')
            .remove([cleanPath]);
      } catch (e) {
        debugPrint('[JournalRepository] deleteAttachment error: $e');
        rethrow;
      }
    }
  }

  static String _resolveMimeType(String ext) {
    return switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'csv' => 'text/csv',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  static bool _isImageExtension(String ext) {
    return const <String>{'png', 'jpg', 'jpeg', 'webp', 'gif'}
        .contains(ext.toLowerCase());
  }
}

/// The single place a screen reaches the journal repository.
class JournalRepositoryScope {
  const JournalRepositoryScope._();

  static JournalRepository? _override;

  static JournalRepository get repository =>
      _override ?? JournalRepositoryImpl.instance;

  /// Swap the implementation. Pass `null` to restore the demo repository.
  static void override(JournalRepository? replacement) =>
      _override = replacement;
}

/// Pure functions the index screen uses to turn the full journal into what is
/// on screen. Kept out of the widget so the rules are testable without pumping
/// a frame.
class JournalQuery {
  const JournalQuery._();

  static List<AppTrade> apply(
    List<AppTrade> entries, {
    String query = '',
    AppOutcome? outcome,
    String? tag,
    String? ticker,
    String? strategyId,
    bool onlyUnwritten = false,
    bool onlyUnfiled = false,
    AppJournalSort sort = AppJournalSort.recentFirst,
  }) {
    final String needle = query.trim().toLowerCase();
    final List<AppTrade> out = entries.where((AppTrade entry) {
      if (outcome != null && entry.outcome != outcome) return false;
      if (tag != null && !entry.tags.contains(tag)) return false;
      if (ticker != null &&
          entry.ticker.toUpperCase() != ticker.toUpperCase()) {
        return false;
      }
      if (strategyId != null && entry.strategyId != strategyId) return false;
      // The two prompts that make the journal useful: what has no write-up, and
      // what was never filed under a plan.
      if (onlyUnwritten && entry.hasStory) return false;
      if (onlyUnfiled &&
          (entry.strategyId != null && entry.strategyId!.isNotEmpty)) {
        return false;
      }
      if (needle.isEmpty) return true;
      // Body included: the thing a trader remembers about an entry three weeks
      // later is a phrase from inside it, not its title.
      return entry.displayTitle.toLowerCase().contains(needle) ||
          entry.ticker.toLowerCase().contains(needle) ||
          entry.content.toLowerCase().contains(needle) ||
          (entry.notes ?? '').toLowerCase().contains(needle) ||
          (entry.strategy ?? '').toLowerCase().contains(needle) ||
          entry.tags.any((String t) => t.toLowerCase().contains(needle));
    }).toList();

    out.sort(switch (sort) {
      AppJournalSort.recentFirst =>
        (AppTrade a, AppTrade b) => b.sortDate.compareTo(a.sortDate),
      AppJournalSort.oldestFirst =>
        (AppTrade a, AppTrade b) => a.sortDate.compareTo(b.sortDate),
      AppJournalSort.biggestWin => (AppTrade a, AppTrade b) => b.pnl.compareTo(
        a.pnl,
      ),
      AppJournalSort.biggestLoss => (AppTrade a, AppTrade b) => a.pnl.compareTo(
        b.pnl,
      ),
      AppJournalSort.bestR =>
        (AppTrade a, AppTrade b) =>
            (b.rMultiple ?? 0).compareTo(a.rMultiple ?? 0),
      AppJournalSort.worstR =>
        (AppTrade a, AppTrade b) =>
            (a.rMultiple ?? 0).compareTo(b.rMultiple ?? 0),
      AppJournalSort.tickerAscending =>
        (AppTrade a, AppTrade b) => a.ticker.compareTo(b.ticker),
    });
    return out;
  }

  /// Every tag in use, most frequent first, for the filter chips.
  static List<String> tagsOf(List<AppTrade> entries) {
    final Map<String, int> counts = <String, int>{};
    for (final AppTrade entry in entries) {
      for (final String tag in entry.tags) {
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

  /// Every instrument traded, most traded first.
  static List<String> tickersOf(List<AppTrade> entries) {
    final Map<String, int> counts = <String, int>{};
    for (final AppTrade entry in entries) {
      final String symbol = entry.ticker.toUpperCase();
      counts[symbol] = (counts[symbol] ?? 0) + 1;
    }
    final List<String> symbols = counts.keys.toList()
      ..sort((String a, String b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return symbols;
  }

  /// The headline numbers for whatever slice is on screen. Computed over the
  /// filtered list rather than the whole journal, so the stats answer the
  /// question the trader just asked with the filters.
  static AppJournalStats statsOf(List<AppTrade> entries) {
    final List<AppTrade> closed = entries
        .where((AppTrade t) => !t.isOpen)
        .toList(growable: false);
    final List<AppTrade> wins = closed
        .where((AppTrade t) => t.pnl > 0)
        .toList(growable: false);
    final double net = closed.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    final Iterable<double> rs = closed
        .where((AppTrade t) => t.rMultiple != null)
        .map((AppTrade t) => t.rMultiple!);
    final int written = entries.where((AppTrade t) => t.hasStory).length;
    return AppJournalStats(
      total: entries.length,
      open: entries.length - closed.length,
      netPnl: net,
      winRate: closed.isEmpty ? 0 : wins.length / closed.length,
      avgR: rs.isEmpty
          ? 0
          : rs.reduce((double a, double b) => a + b) / rs.length,
      written: written,
      unfiled: entries
          .where((AppTrade t) => t.strategyId == null || t.strategyId!.isEmpty)
          .length,
    );
  }
}

/// The summary strip above the journal index.
class AppJournalStats {
  const AppJournalStats({
    this.total = 0,
    this.open = 0,
    this.netPnl = 0,
    this.winRate = 0,
    this.avgR = 0,
    this.written = 0,
    this.unfiled = 0,
  });

  final int total;
  final int open;
  final double netPnl;
  final double winRate;
  final double avgR;

  /// Entries carrying a write-up. The gap between this and [total] is the
  /// prompt the journal leads with.
  final int written;

  /// Entries with no playbook attached.
  final int unfiled;

  double get coverage => total == 0 ? 0 : written / total;

  bool get isEmpty => total == 0;
}
