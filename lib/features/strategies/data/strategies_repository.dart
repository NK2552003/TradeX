import 'package:tradex/core/config/record_access.dart';
import 'package:tradex/core/utils/attachment_compression_service.dart';
import 'package:tradex/core/data/owned_record_writer.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/config/supabase_storage_egress.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import '../../notes/data/note_attachments.dart';
import 'strategy_attachments.dart';


/// Everything the strategies feature needs from storage.
abstract class StrategiesRepository {
  /// Emits every playbook the trader owns, last edited first, re-emitting after
  /// each mutation.
  Stream<List<AppStrategy>> watchAll();

  /// The subset shared to the community feed.
  Stream<List<AppStrategy>> watchPublic();

  Future<List<AppStrategy>> fetchAll();

  Future<List<AppStrategy>> fetchPublicStrategies();

  Future<AppStrategy?> getById(String id);

  Future<AppStrategy> create(AppStrategy draft);

  /// Saves the playbook. Pass [versionNote] to cut a new revision at the same
  /// time — that is what the editor's "Save version" does.
  Future<AppStrategy> update(AppStrategy strategy, {String? versionNote});

  Future<void> delete(String id);

  Future<AppStrategy> toggleFavorite(String id);

  Future<AppStrategy> setStatus(String id, AppStrategyStatus status);

  Future<AppStrategy> setVisibility(String id, bool isPublic);

  /// Revisions newest first. The first entry is always the live playbook.
  Future<List<AppStrategyVersion>> versions(String strategyId);

  /// Snapshots the current body as a new revision.
  Future<AppStrategyVersion> saveVersion(String strategyId, {String? note});

  /// Copies an old revision's body back onto the live playbook, cutting a new
  /// revision as it goes.
  Future<AppStrategy> restoreVersion(String strategyId, String versionId);

  Future<AppStrategy> linkNote(String strategyId, String noteId);

  Future<AppStrategy> unlinkNote(String strategyId, String noteId);

  Future<AppStrategy> linkJournal(String strategyId, String entryId);

  Future<AppStrategy> unlinkJournal(String strategyId, String entryId);

  /// Stores a diagram, chart or reference document against [strategyId] and
  /// returns the opaque reference the markdown body embeds.
  Future<String> uploadAttachment(
    String strategyId,
    File? file, {
    Uint8List? bytes,
    String? filename,
  });

  /// Turns a stored reference back into something the preview can load.
  Future<String> resolveAttachmentUrl(String ref);

  /// Deletes an attachment from private storage and purges its tracking record.
  Future<void> deleteAttachment(String storagePath);
}

/// Live Supabase-backed implementation with real-time sync and offline resilience.
class StrategiesRepositoryImpl implements StrategiesRepository {
  StrategiesRepositoryImpl._();

  static final StrategiesRepositoryImpl instance = StrategiesRepositoryImpl._();

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

  static String _resolveMimeType(String ext) {
    switch (ext.toLowerCase()) {
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

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final List<AppStrategy> _strategies = <AppStrategy>[];
  final Map<String, List<AppStrategyVersion>> _versions =
      <String, List<AppStrategyVersion>>{};
  final StreamController<List<AppStrategy>> _changes =
      StreamController<List<AppStrategy>>.broadcast();

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
      _strategies.clear();
      _versions.clear();
      _initialized = false;
      _cacheActor = actor;
    }
    if (_initialized) return;
    _initialized = true;

    if (SupabaseConfig.isConfigured) {
      _initRealtime();
      await _fetchFromSupabase();
    } else {
      _publish();
    }
  }

  static const String _selectColumns =
      'id, user_id, title, name, summary, ai_summary, content, category, '
      'status, visibility, is_favorite, tags, linked_tickers, linked_note_ids, '
      'linked_journal_ids, created_at, updated_at, version_count, word_count, '
      'checklist_done, checklist_total, has_images, has_code';

  static const String _versionSelectColumns =
      'id, strategy_id, version_number, content, summary, note, is_current, '
      'word_count, author_id, created_at';

  void _initRealtime() {
    if (_subscribedToRealtime || !SupabaseConfig.isConfigured) return;
    final targetUserId = _resolveUserId();
    if (!_isUuid(targetUserId)) return;
    _subscribedToRealtime = true;

    try {
      final client = SupabaseConfig.client!;
      _realtimeChannel =
          client
              .channel('public:strategies_channel')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'strategies',
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
      debugPrint('[StrategiesRepository] Realtime subscription error: $e');
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
            final strategy = _mapRowToStrategy(newRecord);
            _strategies.removeWhere((s) => s.id == strategy.id);
            _strategies.insert(0, strategy);
            _recordTickerLinks(strategy);
            _publish();
          }
        }
      } else if (eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final strategy = _mapRowToStrategy(newRecord);
          final recordUserId = newRecord['user_id']?.toString();
          if (recordUserId == currentUserId) {
            final at = _strategies.indexWhere((s) => s.id == strategy.id);
            if (at != -1) {
              _strategies[at] = strategy;
            } else {
              _strategies.insert(0, strategy);
            }
            _recordTickerLinks(strategy);
            _publish();
          } else {
            _strategies.removeWhere((s) => s.id == strategy.id);
            _publish();
          }
        }
      } else if (eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final deletedId = oldRecord['id']?.toString();
        if (deletedId != null) {
          _strategies.removeWhere((s) => s.id == deletedId);
          _versions.remove(deletedId);
          unawaited(
            EntityTickerLinksRepository.instance.removeLinks(
              entityType: 'strategy',
              entityId: deletedId,
            ),
          );
          _publish();
        }
      }
    } catch (e) {
      debugPrint('[StrategiesRepository] Error handling postgres change: $e');
    }
  }

  Future<void> _fetchFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty) {
        _strategies.clear();
        _publish();
        return;
      }

      final res = await client
          .from('strategies')
          .select(_selectColumns)
          .eq('user_id', targetUserId)
          .order('updated_at', ascending: false)
          .limit(100);

      final List<AppStrategy> list = (res as List)
          .map((row) => _mapRowToStrategy(row as Map<String, dynamic>))
          .toList();

      _strategies
        ..clear()
        ..addAll(list);

      // Fetch real trade performance metrics from journal_entries
      try {
        final tradesRes = await client
            .from('journal_entries')
            .select('strategy_id, outcome, pnl, r_multiple')
            .eq('user_id', targetUserId)
            .not('strategy_id', 'is', null)
            .limit(500);

        final Map<String, List<Map<String, dynamic>>> tradesByStrategy = {};
        for (final t in tradesRes as List) {
          final row = t as Map<String, dynamic>;
          final sId = row['strategy_id']?.toString();
          if (sId != null && sId.isNotEmpty) {
            (tradesByStrategy[sId] ??= []).add(row);
          }
        }

        for (int i = 0; i < _strategies.length; i++) {
          final s = _strategies[i];
          final sTrades = tradesByStrategy[s.id] ?? const [];
          if (sTrades.isNotEmpty) {
            int wins = 0;
            double netPnl = 0.0;
            double totalR = 0.0;
            int rCount = 0;

            for (final st in sTrades) {
              final outcome = st['outcome']?.toString().toLowerCase();
              if (outcome == 'win') wins++;
              final pnl = (st['pnl'] as num?)?.toDouble() ?? 0.0;
              netPnl += pnl;
              final r = (st['r_multiple'] as num?)?.toDouble();
              if (r != null) {
                totalR += r;
                rCount++;
              }
            }

            final double winRate = (wins / sTrades.length) * 100.0;
            final double avgR = rCount > 0 ? (totalR / rCount) : 0.0;

            _strategies[i] = s.copyWith(
              trades: sTrades.length,
              winRate: double.parse(winRate.toStringAsFixed(1)),
              avgR: double.parse(avgR.toStringAsFixed(2)),
              netPnl: netPnl,
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[StrategiesRepository] Error calculating strategy metrics: $e',
        );
      }

      _syncAllTickerLinks();
      _publish();
    } catch (e) {
      debugPrint('[StrategiesRepository] _fetchFromSupabase error: $e');
    }
  }

  void _syncAllTickerLinks() {
    for (final AppStrategy s in _strategies) {
      _recordTickerLinks(s);
    }
  }

  void _recordTickerLinks(AppStrategy strategy) {
    final Set<String> tickers = <String>{
      ...strategy.linkedTickers,
      ...EntityTickerLinksRepository.extractTickers(strategy.content),
    };
    if (tickers.isNotEmpty) {
      EntityTickerLinksRepository.instance.recordLinks(
        entityType: 'strategy',
        entityId: strategy.id,
        tickers: tickers,
      );
    }
  }

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is Map) {
      if (value['text'] != null) return value['text'].toString();
      if (value['markdown'] != null) return value['markdown'].toString();
      if (value['raw'] != null) return value['raw'].toString();
      return jsonEncode(value);
    }
    return value.toString();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      if (value['text'] != null) return value['text'].toString();
      if (value['markdown'] != null) return value['markdown'].toString();
      if (value['raw'] != null) return value['raw'].toString();
      return jsonEncode(value);
    }
    return value.toString();
  }

  AppStrategy _mapRowToStrategy(Map<String, dynamic> row) {
    final statusStr = _parseString(
      row['status'],
      fallback: 'draft',
    ).toLowerCase();
    final status = switch (statusStr) {
      'testing' => AppStrategyStatus.testing,
      'live' => AppStrategyStatus.live,
      'retired' => AppStrategyStatus.retired,
      _ => AppStrategyStatus.draft,
    };

    final visibility = _parseString(row['visibility'], fallback: 'private');
    final isPublic = visibility == 'public';
    final isFavorite = row['is_favorite'] as bool? ?? false;

    final tags = row['tags'] != null
        ? List<String>.from((row['tags'] as List).map((e) => e.toString()))
        : const <String>[];
    final linkedTickers = row['linked_tickers'] != null
        ? List<String>.from(
            (row['linked_tickers'] as List).map((e) => e.toString()),
          )
        : const <String>[];
    final linkedNoteIds = row['linked_note_ids'] != null
        ? List<String>.from(
            (row['linked_note_ids'] as List).map((e) => e.toString()),
          )
        : const <String>[];
    final linkedJournalIds = row['linked_journal_ids'] != null
        ? List<String>.from(
            (row['linked_journal_ids'] as List).map((e) => e.toString()),
          )
        : const <String>[];

    final DateTime? createdAt = row['created_at'] != null
        ? DateTime.tryParse(row['created_at'].toString())
        : null;
    final DateTime? updatedAt = row['updated_at'] != null
        ? DateTime.tryParse(row['updated_at'].toString())
        : null;

    final name = _parseString(
      row['title'] ?? row['name'],
      fallback: 'Untitled Strategy',
    );
    final content = _parseString(row['content']);
    final summary = _parseNullableString(row['summary'] ?? row['ai_summary']);
    final category = _parseNullableString(row['category']);

    return AppStrategy(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      name: name,
      summary: summary,
      content: content,
      category: category,
      status: status,
      isPublic: isPublic,
      isFavorite: isFavorite,
      tags: tags,
      linkedTickers: linkedTickers,
      linkedNoteIds: linkedNoteIds,
      linkedJournalIds: linkedJournalIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
      versionCount: (row['version_count'] as num?)?.toInt() ?? 1,
      trades:
          (row['trades'] as num?)?.toInt() ??
          (row['trades_count'] as num?)?.toInt() ??
          0,
      winRate: (row['win_rate'] as num?)?.toDouble() ?? 0.0,
      avgR: (row['avg_r'] as num?)?.toDouble() ?? 0.0,
      netPnl: (row['net_pnl'] as num?)?.toDouble() ?? 0.0,
      wordCount: (row['word_count'] as num?)?.toInt() ?? 0,
      checklistDone: (row['checklist_done'] as num?)?.toInt() ?? 0,
      checklistTotal: (row['checklist_total'] as num?)?.toInt() ?? 0,
      hasImages: row['has_images'] as bool? ?? false,
      hasCode: row['has_code'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _mapStrategyToRow(
    AppStrategy strategy,
    String userId, {
    String? targetId,
  }) {
    final Map<String, dynamic> row = <String, dynamic>{
      'user_id': userId,
      'title': strategy.name,
      'summary': strategy.summary,
      'content': strategy.content,
      'category': strategy.category,
      'status': strategy.status.name,
      'is_favorite': strategy.isFavorite,
      'visibility': strategy.isPublic ? 'public' : 'private',
      'tags': strategy.tags,
      'linked_tickers': strategy.linkedTickers,
      'linked_note_ids': strategy.linkedNoteIds,
      'linked_journal_ids': strategy.linkedJournalIds,
      'version_count': strategy.versionCount,
      'word_count': strategy.wordCount,
      'checklist_done': strategy.checklistDone,
      'checklist_total': strategy.checklistTotal,
      'has_images': strategy.hasImages,
      'has_code': strategy.hasCode,
    };

    if (targetId != null && targetId.isNotEmpty) {
      row['id'] = targetId;
    }

    return row;
  }

  AppStrategyVersion _mapRowToVersion(Map<String, dynamic> row) {
    return AppStrategyVersion(
      id: row['id']?.toString() ?? '',
      version: (row['version_number'] as num?)?.toInt() ?? 1,
      savedAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      author: _parseString(row['author_id'], fallback: 'You'),
      note: _parseNullableString(row['note']),
      isCurrent: row['is_current'] as bool? ?? false,
      strategyId: row['strategy_id']?.toString() ?? '',
      content: _parseString(row['content']),
      summary: _parseNullableString(row['summary']),
      wordCount: (row['word_count'] as num?)?.toInt() ?? 0,
    );
  }

  List<AppStrategy> _snapshot() {
    final List<AppStrategy> copy = List<AppStrategy>.of(_strategies)
      ..sort(
        (AppStrategy a, AppStrategy b) => _editedAt(b).compareTo(_editedAt(a)),
      );
    return List<AppStrategy>.unmodifiable(copy);
  }

  static DateTime _editedAt(AppStrategy s) =>
      s.updatedAt ?? s.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot());
  }

  @override
  Stream<List<AppStrategy>> watchAll() {
    unawaited(_init());
    return Stream<List<AppStrategy>>.multi((
      MultiStreamController<List<AppStrategy>> controller,
    ) {
      controller.add(_snapshot());
      final StreamSubscription<List<AppStrategy>> sub = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<AppStrategy>> watchPublic() => watchAll().map(
    (List<AppStrategy> items) =>
        items.where((AppStrategy s) => s.isPublic).toList(growable: false),
  );

  @override
  Future<List<AppStrategy>> fetchAll() async {
    await _init();
    if (SupabaseConfig.isConfigured) {
      await _fetchFromSupabase();
    }
    return _snapshot();
  }

  @override
  Future<List<AppStrategy>> fetchPublicStrategies() async {
    if (!SupabaseConfig.isConfigured) {
      return _strategies.where((s) => s.isPublic).toList();
    }
    try {
      final client = SupabaseConfig.client!;
      final res = await client
          .from('strategies')
          .select(_selectColumns)
          .eq('visibility', 'public')
          .order('updated_at', ascending: false)
          .limit(50);
      return (res as List)
          .map((row) => _mapRowToStrategy(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[StrategiesRepository] fetchPublicStrategies error: $e');
      return _strategies.where((s) => s.isPublic).toList();
    }
  }

  @override
  Future<AppStrategy?> getById(String id) async {
    await _init();
    for (final AppStrategy s in _strategies) {
      if (s.id == id) return s;
    }
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('strategies')
            .select(_selectColumns)
            .eq('id', id)
            .maybeSingle();
        if (res != null) {
          final strategy = _mapRowToStrategy(res);
          if (!RecordAccess.canRead(strategy.userId, strategy.isPublic)) {
            return null;
          }
          final currentUserId = _resolveUserId();
          if (strategy.userId == currentUserId) {
            final at = _strategies.indexWhere((s) => s.id == strategy.id);
            if (at == -1) {
              _strategies.insert(0, strategy);
            } else {
              _strategies[at] = strategy;
            }
            _recordTickerLinks(strategy);
            _publish();
          }
          return strategy;
        }
      } catch (e) {
        debugPrint('[StrategiesRepository] getById error: $e');
      }
    }
    return null;
  }

  @override
  Future<AppStrategy> create(AppStrategy draft) async {
    RecordAccess.requireService();
    await _init();
    final DateTime now = DateTime.now();

    AppStrategy saved = draft;
    final resolvedUid = _resolveUserId();
    final targetUserId = (SupabaseConfig.isConfigured || draft.userId.isEmpty) ? resolvedUid : draft.userId;
    final String assignedId =
        draft.id.isEmpty || (SupabaseConfig.isConfigured && !_isUuid(draft.id))
        ? const Uuid().v4()
        : draft.id;

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final row = _mapStrategyToRow(
          draft.withDerivedCounts(),
          targetUserId,
          targetId: assignedId,
        );

        final res = await client
            .from('strategies')
            .insert(row)
            .select(_selectColumns)
            .single();
        saved = _mapRowToStrategy(res);

        // Seed version 1 in strategy_versions
        try {
          await client.from('strategy_versions').insert({
            'strategy_id': saved.id,
            'version_number': 1,
            'content': saved.content,
            'summary': saved.summary,
            'note': 'Initial release',
            'is_current': true,
            'word_count': saved.wordCount,
            'author_id': targetUserId,
          });
        } catch (_) {}
      } catch (e) {
        debugPrint(
          '[StrategiesRepository] create error (cloud sync fallback): $e',
        );
        saved = draft
            .copyWith(
              id: assignedId,
              userId: targetUserId,
              createdAt: now,
              updatedAt: now,
            )
            .withDerivedCounts();
      }
    } else {
      saved = draft
          .copyWith(
            id: assignedId,
            userId: targetUserId,
            createdAt: now,
            updatedAt: now,
          )
          .withDerivedCounts();
    }

    _strategies.removeWhere((AppStrategy s) => s.id == saved.id);
    _strategies.insert(0, saved);
    _versions[saved.id] = <AppStrategyVersion>[
      _versionOf(saved, 1, isCurrent: true, note: 'Initial release'),
    ];
    _publish();
    _recordTickerLinks(saved);

    return saved;
  }

  @override
  Future<AppStrategy> update(
    AppStrategy strategy, {
    String? versionNote,
  }) async {
    RecordAccess.requireService();
    final owned = await getById(strategy.id);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    await _init();

    AppStrategy saved = strategy
        .copyWith(userId: owned.userId, updatedAt: DateTime.now())
        .withDerivedCounts();

    if (SupabaseConfig.isConfigured && _isUuid(strategy.id)) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        final row = _mapStrategyToRow(saved, targetUserId);
        row.remove('id');
        // Do not overwrite trigger-maintained mirror columns during regular updates
        row.remove('linked_note_ids');
        row.remove('linked_journal_ids');
        row['updated_at'] = DateTime.now().toIso8601String();

        final res = await client
            .from('strategies')
            .update(row)
            .eq('id', strategy.id)
            .eq('user_id', targetUserId)
            .select(_selectColumns)
            .single();

        saved = _mapRowToStrategy(res);
      } catch (e) {
        debugPrint(
          '[StrategiesRepository] update error (cloud sync fallback): $e',
        );
      }
    }

    final int at = _strategies.indexWhere((AppStrategy s) => s.id == saved.id);
    if (at == -1) {
      _strategies.insert(0, saved);
    } else {
      _strategies[at] = saved;
    }

    if (owned.isPublic && !saved.isPublic) {
      StrategyAttachments.invalidateForStrategy(saved.id);
      NoteAttachments.invalidate(saved.id);
    }

    if (versionNote != null) {
      await saveVersion(saved.id, note: versionNote);
    } else {
      final existingVersions = _versions[saved.id];
      if (existingVersions != null && existingVersions.isNotEmpty) {
        final idx = existingVersions.indexWhere((v) => v.isCurrent);
        if (idx != -1) {
          existingVersions[idx] = _versionOf(
            saved,
            existingVersions[idx].version,
            isCurrent: true,
            note: existingVersions[idx].note,
          );
        }
      }
    }

    final removedRefs = NoteAttachments.extractRefs(owned.content)
        .difference(NoteAttachments.extractRefs(saved.content));
    if (removedRefs.isNotEmpty) {
      final historicalRefs = <String>{
        for (final v in _versions[saved.id] ?? const <AppStrategyVersion>[])
          if (!v.isCurrent) ...NoteAttachments.extractRefs(v.content),
      };
      for (final ref in removedRefs.difference(historicalRefs)) {
        try {
          await deleteAttachment(ref);
        } catch (e) {
          debugPrint(
            '[StrategiesRepository] update attachment cleanup warning: $e',
          );
        }
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
            .from('strategy-attachments')
            .list(path: folder);
        if (files.isNotEmpty) {
          final filePaths = files.map((f) => '$folder/${f.name}').toList();
          await client.storage.from('strategy-attachments').remove(filePaths);
        }
        await OwnedRecordWriter().delete('strategies', id);
      } catch (e) {
        debugPrint('[StrategiesRepository] delete error: $e');
        rethrow;
      }
    } else {
      final allRefs = <String>{
        ...NoteAttachments.extractRefs(owned.content),
        for (final v in _versions[id] ?? const <AppStrategyVersion>[])
          ...NoteAttachments.extractRefs(v.content),
      };
      for (final ref in allRefs) {
        try {
          await deleteAttachment(ref);
        } catch (_) {}
      }
    }

    StrategyAttachments.invalidateForStrategy(id);
    NoteAttachments.invalidate(id);

    _strategies.removeWhere((AppStrategy s) => s.id == id);
    _versions.remove(id);
    _publish();
    unawaited(
      EntityTickerLinksRepository.instance.removeLinks(
        entityType: 'strategy',
        entityId: id,
      ),
    );
  }

  AppStrategy _mutate(String id, AppStrategy Function(AppStrategy s) change) {
    final int at = _strategies.indexWhere((AppStrategy s) => s.id == id);
    if (at < 0) throw StateError('Strategy not found: $id');
    final AppStrategy updated = change(
      _strategies[at],
    ).copyWith(updatedAt: DateTime.now());
    _strategies[at] = updated;
    _publish();
    return updated;
  }

  @override
  Future<AppStrategy> toggleFavorite(String id) async {
    final current = await getById(id);
    RecordAccess.requireService();
    if (current == null) {
      throw StateError('This strategy is no longer available.');
    }
    RecordAccess.requireOwner(current.userId);
    final targetFavorite = !current.isFavorite;
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('strategies')
            .update({'is_favorite': targetFavorite})
            .eq('id', id)
            .eq('user_id', _resolveUserId())
            .select('id')
            .single();
      } catch (e) {
        debugPrint('[StrategiesRepository] toggleFavorite error: $e');
        rethrow;
      }
    }
    return _mutate(
      id,
      (AppStrategy s) => s.copyWith(isFavorite: targetFavorite),
    );
  }

  @override
  Future<AppStrategy> setStatus(String id, AppStrategyStatus status) async {
    RecordAccess.requireService();
    final owned = await getById(id);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('strategies')
            .update({'status': status.name})
            .eq('id', id)
            .eq('user_id', _resolveUserId())
            .select('id')
            .single();
      } catch (e) {
        debugPrint('[StrategiesRepository] setStatus error: $e');
        rethrow;
      }
    }
    return _mutate(id, (AppStrategy s) => s.copyWith(status: status));
  }

  @override
  Future<AppStrategy> setVisibility(String id, bool isPublic) async {
    RecordAccess.requireService();
    final owned = await getById(id);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured) {
      await OwnedRecordWriter().update('strategies', id, {
        'visibility': isPublic ? 'public' : 'private',
      });
    }
    if (!isPublic) {
      StrategyAttachments.invalidateForStrategy(id);
      NoteAttachments.invalidate(id);
    }

    return _mutate(id, (AppStrategy s) => s.copyWith(isPublic: isPublic));
  }

  @override
  Future<List<AppStrategyVersion>> versions(String strategyId) async {
    await _init();
    final strategy = await getById(strategyId);
    if (strategy != null) {
      final currentUserId = _resolveUserId();
      if (strategy.userId != currentUserId && !strategy.isPublic) {
        throw StateError(
          'Unauthorized: access denied to private strategy versions.',
        );
      }
    }
    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('strategy_versions')
            .select(_versionSelectColumns)
            .eq('strategy_id', strategyId)
            .order('version_number', ascending: false)
            .limit(50);

        final list = (res as List)
            .map((row) => _mapRowToVersion(row as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          _versions[strategyId] = list;
          return list;
        }
      } catch (e) {
        debugPrint('[StrategiesRepository] versions error: $e');
      }
    }
    final List<AppStrategyVersion> history =
        _versions[strategyId] ?? const <AppStrategyVersion>[];
    final List<AppStrategyVersion> copy = List<AppStrategyVersion>.of(history)
      ..sort(
        (AppStrategyVersion a, AppStrategyVersion b) =>
            b.version.compareTo(a.version),
      );
    return List<AppStrategyVersion>.unmodifiable(copy);
  }

  @override
  Future<AppStrategyVersion> saveVersion(
    String strategyId, {
    String? note,
  }) async {
    RecordAccess.requireService();
    final owned = await getById(strategyId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    await _init();
    final AppStrategy? s = await getById(strategyId);
    if (s == null) throw StateError('Strategy not found: $strategyId');

    final currentVersions = await versions(strategyId);
    final int nextVersion =
        currentVersions.fold<int>(
          0,
          (int max, AppStrategyVersion v) => v.version > max ? v.version : max,
        ) +
        1;

    AppStrategyVersion? created;
    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        await client
            .from('strategy_versions')
            .update({'is_current': false})
            .eq('strategy_id', strategyId);

        final res = await client
            .from('strategy_versions')
            .insert({
              'strategy_id': strategyId,
              'version_number': nextVersion,
              'content': s.content,
              'summary': s.summary,
              'note': note,
              'is_current': true,
              'word_count': s.wordCount,
              'author_id': user?.id,
            })
            .select(_versionSelectColumns)
            .single();

        created = _mapRowToVersion(res);

        await client
            .from('strategies')
            .update({'version_count': nextVersion})
            .eq('id', strategyId)
            .eq('user_id', _resolveUserId())
            .select('id')
            .single();
      } catch (e) {
        debugPrint('[StrategiesRepository] saveVersion error: $e');
        rethrow;
      }
    }

    final AppStrategyVersion cut =
        created ??
        AppStrategyVersion(
          id: '${s.id}_v$nextVersion',
          version: nextVersion,
          savedAt: DateTime.now(),
          author: 'You',
          note: note,
          isCurrent: true,
          strategyId: s.id,
          content: s.content,
          summary: s.summary,
          wordCount: s.wordCount,
        );

    final List<AppStrategyVersion> history = _versions[strategyId] ??=
        <AppStrategyVersion>[];
    for (int i = 0; i < history.length; i++) {
      if (history[i].isCurrent) {
        history[i] = history[i].copyWith(isCurrent: false);
      }
    }
    history.insert(0, cut);

    _mutate(
      strategyId,
      (AppStrategy current) => current.copyWith(versionCount: history.length),
    );

    return cut;
  }

  static AppStrategyVersion _versionOf(
    AppStrategy s,
    int version, {
    required bool isCurrent,
    String? note,
  }) => AppStrategyVersion(
    id: '${s.id}_v$version',
    version: version,
    savedAt: DateTime.now(),
    author: 'You',
    note: note,
    isCurrent: isCurrent,
    strategyId: s.id,
    content: s.content,
    summary: s.summary,
    wordCount: AppMarkdownStats.of(s.content).wordCount,
  );

  @override
  Future<AppStrategy> restoreVersion(
    String strategyId,
    String versionId,
  ) async {
    RecordAccess.requireService();
    final owned = await getById(strategyId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    await _init();
    final List<AppStrategyVersion> history = await versions(strategyId);
    AppStrategyVersion? target;
    for (final AppStrategyVersion v in history) {
      if (v.id == versionId) {
        target = v;
        break;
      }
    }
    if (target == null) throw StateError('Version not found: $versionId');
    final String body = target.content;
    final String label = target.label;

    final AppStrategy restored = _mutate(
      strategyId,
      (AppStrategy s) => s.copyWith(content: body).withDerivedCounts(),
    );

    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('strategies')
            .update({
              'content': body,
              'word_count': restored.wordCount,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', strategyId)
            .eq('user_id', _resolveUserId())
            .select('id')
            .single();
      } catch (e) {
        debugPrint('[StrategiesRepository] restoreVersion error: $e');
        rethrow;
      }
    }

    await saveVersion(strategyId, note: 'Restored $label');
    return (await getById(strategyId)) ?? restored;
  }

  @override
  Future<AppStrategy> linkNote(String strategyId, String noteId) async {
    RecordAccess.requireService();
    final owned = await getById(strategyId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured && _isUuid(strategyId) && _isUuid(noteId)) {
      try {
        final client = SupabaseConfig.client!;
        // Authoritative mutation path: set strategy_id on the child note.
        // The database trigger trg_trader_notes_strategy_mirror automatically
        // recalculates strategies.linked_note_ids atomically.
        await client
            .from('trader_notes')
            .update({
              'strategy_id': strategyId,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', noteId)
            .eq('user_id', _resolveUserId());
      } catch (e) {
        debugPrint('[StrategiesRepository] linkNote authoritative error: $e');
        rethrow;
      }
    }
    return _mutate(strategyId, (AppStrategy s) {
      if (s.linkedNoteIds.contains(noteId)) return s;
      return s.copyWith(linkedNoteIds: <String>[...s.linkedNoteIds, noteId]);
    });
  }

  @override
  Future<AppStrategy> unlinkNote(String strategyId, String noteId) async {
    RecordAccess.requireService();
    final owned = await getById(strategyId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured && _isUuid(strategyId) && _isUuid(noteId)) {
      try {
        final client = SupabaseConfig.client!;
        // Authoritative mutation path: clear strategy_id on the child note.
        // The database trigger trg_trader_notes_strategy_mirror automatically
        // recalculates strategies.linked_note_ids atomically.
        await client
            .from('trader_notes')
            .update({
              'strategy_id': null,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', noteId)
            .eq('strategy_id', strategyId)
            .eq('user_id', _resolveUserId());
      } catch (e) {
        debugPrint('[StrategiesRepository] unlinkNote authoritative error: $e');
        rethrow;
      }
    }
    return _mutate(
      strategyId,
      (AppStrategy s) => s.copyWith(
        linkedNoteIds: s.linkedNoteIds
            .where((String id) => id != noteId)
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<AppStrategy> linkJournal(String strategyId, String entryId) async {
    RecordAccess.requireService();
    final owned = await getById(strategyId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured && _isUuid(strategyId) && _isUuid(entryId)) {
      try {
        final client = SupabaseConfig.client!;
        // Authoritative mutation path: set strategy_id on the child journal entry.
        // The database trigger trg_journal_entries_strategy_mirror automatically
        // recalculates strategies.linked_journal_ids atomically.
        await client
            .from('journal_entries')
            .update({
              'strategy_id': strategyId,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', entryId)
            .eq('user_id', _resolveUserId());
      } catch (e) {
        debugPrint('[StrategiesRepository] linkJournal authoritative error: $e');
        rethrow;
      }
    }
    return _mutate(strategyId, (AppStrategy s) {
      if (s.linkedJournalIds.contains(entryId)) return s;
      return s.copyWith(
        linkedJournalIds: <String>[...s.linkedJournalIds, entryId],
      );
    });
  }

  @override
  Future<AppStrategy> unlinkJournal(String strategyId, String entryId) async {
    RecordAccess.requireService();
    final owned = await getById(strategyId);
    if (owned == null) throw StateError('This record is no longer available.');
    RecordAccess.requireOwner(owned.userId);
    if (SupabaseConfig.isConfigured && _isUuid(strategyId) && _isUuid(entryId)) {
      try {
        final client = SupabaseConfig.client!;
        // Authoritative mutation path: clear strategy_id on the child journal entry.
        // The database trigger trg_journal_entries_strategy_mirror automatically
        // recalculates strategies.linked_journal_ids atomically.
        await client
            .from('journal_entries')
            .update({
              'strategy_id': null,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', entryId)
            .eq('strategy_id', strategyId)
            .eq('user_id', _resolveUserId());
      } catch (e) {
        debugPrint('[StrategiesRepository] unlinkJournal authoritative error: $e');
        rethrow;
      }
    }
    return _mutate(
      strategyId,
      (AppStrategy s) => s.copyWith(
        linkedJournalIds: s.linkedJournalIds
            .where((String id) => id != entryId)
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<String> uploadAttachment(
    String strategyId,
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
      final owner = await getById(strategyId);
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

    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        final storagePath =
            '$currentUserId/$strategyId/${const Uuid().v4()}.$ext';

        final mimeType = _resolveMimeType(ext);
        final isImage = NoteAttachments.isImageFile(rawFileName);

        await client.storage
            .from('strategy-attachments')
            .uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: FileOptions(
                contentType: mimeType,
                cacheControl:
                    SupabaseStorageEgress.strategyAttachments.uploadCacheControl,
                upsert: false,
              ),
            );

        try {
          await client
              .from('strategy_attachments')
              .insert({
                'strategy_id': strategyId,
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
                  .from('strategy-attachments')
                  .remove(<String>[storagePath]);
            } catch (_) {}
            rethrow;
          }
          debugPrint(
            '[StrategiesRepository] strategy_attachments insert warning: $metaError',
          );
        }

        return storagePath;
      } catch (e) {
        debugPrint('[StrategiesRepository] uploadAttachment cloud error: $e');
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
    if (cleanPath.startsWith('strategy-attachments/')) {
      cleanPath = cleanPath.substring('strategy-attachments/'.length);
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

    StrategyAttachments.invalidate(cleanPath);

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      await client.storage.from('strategy-attachments').remove([cleanPath]);
      await client
          .from('strategy_attachments')
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

    // 2. Extract relative storage path inside strategy-attachments bucket
    String storagePath = ref.trim();

    if (storagePath.startsWith('https://') ||
        storagePath.startsWith('http://')) {
      final uri = Uri.tryParse(storagePath);
      if (uri != null) {
        final pathSegments = uri.pathSegments;
        final bucketIdx = pathSegments.indexOf('strategy-attachments');
        if (bucketIdx != -1 && bucketIdx < pathSegments.length - 1) {
          storagePath = pathSegments.sublist(bucketIdx + 1).join('/');
        } else {
          // 3rd party external URL, e.g. unsplash or external CDN
          return ref;
        }
      }
    }

    // Strip leading bucket name or slashes
    if (storagePath.startsWith('strategy-attachments/')) {
      storagePath = storagePath.substring('strategy-attachments/'.length);
    }
    while (storagePath.startsWith('/')) {
      storagePath = storagePath.substring(1);
    }

    // Strip query string if any was appended
    if (storagePath.contains('?')) {
      storagePath = storagePath.split('?').first;
    }

    if (storagePath.contains('..')) {
      throw StateError('Unauthorized: invalid attachment storage path.');
    }

    // 3. Authorization check: Strategy attachments must match both the strategy
    // ID and that strategy's actual owner, and require visibility when not owned
    // by the current user.
    final currentUserId = _resolveUserId();
    final pathSegments = storagePath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (pathSegments.length >= 2) {
      final ownerId = pathSegments[0];
      final strategyId = pathSegments[1];
      final strategy = await getById(strategyId);

      if (strategy == null) {
        if (ownerId != currentUserId) {
          throw StateError(
            'Unauthorized: access denied to private attachment belonging to another user.',
          );
        }
      } else {
        if (strategy.userId.isNotEmpty && strategy.userId != ownerId) {
          throw StateError(
            'Unauthorized: attachment path owner does not match strategy owner.',
          );
        }
        if (ownerId != currentUserId && !strategy.isPublic) {
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
      return storagePath;
    }

    // 4. Generate short-lived (300s) expiring signed Direct Egress access URL from private bucket
    try {
      return await SupabaseConfig.client!.storage
          .from(SupabaseStorageEgress.strategyAttachments.bucketId)
          .createSignedUrl(
            storagePath,
            SupabaseStorageEgress.strategyAttachments.signedUrlTtlSeconds!,
          );
    } catch (e) {
      debugPrint('[StrategiesRepository] createSignedUrl error: $e');
      rethrow;
    }
  }
}

/// The single place a screen reaches the strategies repository.
class StrategiesRepositoryScope {
  const StrategiesRepositoryScope._();

  static StrategiesRepository? _override;

  static StrategiesRepository get repository =>
      _override ?? StrategiesRepositoryImpl.instance;

  static void override(StrategiesRepository? replacement) =>
      _override = replacement;
}

/// Pure functions the index screen uses to turn the full library into what is
/// on screen.
class StrategiesQuery {
  const StrategiesQuery._();

  static List<AppStrategy> apply(
    List<AppStrategy> items, {
    String query = '',
    AppStrategyStatus? status,
    String? category,
    String? tag,
    String? ticker,
    bool onlyUnwritten = false,
    bool onlyFavorites = false,
    AppStrategySort sort = AppStrategySort.recentlyUpdated,
  }) {
    final String needle = query.trim().toLowerCase();
    final List<AppStrategy> out = items.where((AppStrategy s) {
      if (status != null && s.status != status) return false;
      if (category != null && s.category != category) return false;
      if (tag != null && !s.tags.contains(tag)) return false;
      if (ticker != null &&
          !s.linkedTickers
              .map((String t) => t.toUpperCase())
              .contains(ticker.toUpperCase())) {
        return false;
      }
      if (onlyUnwritten && s.hasPlaybook) return false;
      if (onlyFavorites && !s.isFavorite) return false;
      if (needle.isEmpty) return true;
      return s.name.toLowerCase().contains(needle) ||
          (s.summary ?? '').toLowerCase().contains(needle) ||
          s.content.toLowerCase().contains(needle) ||
          (s.category ?? '').toLowerCase().contains(needle) ||
          s.tags.any((String t) => t.toLowerCase().contains(needle)) ||
          s.linkedTickers.any((String t) => t.toLowerCase().contains(needle));
    }).toList();

    out.sort(switch (sort) {
      AppStrategySort.recentlyUpdated =>
        (AppStrategy a, AppStrategy b) => StrategiesRepositoryImpl._editedAt(
          b,
        ).compareTo(StrategiesRepositoryImpl._editedAt(a)),
      AppStrategySort.nameAscending =>
        (AppStrategy a, AppStrategy b) => a.name.compareTo(b.name),
      AppStrategySort.mostTraded =>
        (AppStrategy a, AppStrategy b) => b.trades.compareTo(a.trades),
      AppStrategySort.bestWinRate =>
        (AppStrategy a, AppStrategy b) => b.winRate.compareTo(a.winRate),
      AppStrategySort.bestNetPnl =>
        (AppStrategy a, AppStrategy b) => b.netPnl.compareTo(a.netPnl),
    });
    return out;
  }

  static List<String> tickersOf(List<AppStrategy> items) {
    final Map<String, int> counts = <String, int>{};
    for (final AppStrategy s in items) {
      for (final String ticker in s.linkedTickers) {
        final String symbol = ticker.toUpperCase();
        counts[symbol] = (counts[symbol] ?? 0) + 1;
      }
    }
    final List<String> list = counts.keys.toList()
      ..sort((String a, String b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return list;
  }

  static List<String> categoriesOf(List<AppStrategy> items) {
    final Set<String> set = <String>{};
    for (final AppStrategy s in items) {
      if (s.category != null && s.category!.trim().isNotEmpty) {
        set.add(s.category!.trim());
      }
    }
    final List<String> list = set.toList()..sort();
    return list;
  }

  static List<String> tagsOf(List<AppStrategy> items) {
    final Map<String, int> counts = <String, int>{};
    for (final AppStrategy s in items) {
      for (final String tag in s.tags) {
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
