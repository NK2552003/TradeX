import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';
import 'package:uuid/uuid.dart';

/// Everything the strategies feature needs from storage.
abstract class StrategiesRepository {
  /// Emits every playbook the trader owns, last edited first, re-emitting after
  /// each mutation.
  Stream<List<AppStrategy>> watchAll();

  /// The subset shared to the community feed.
  Stream<List<AppStrategy>> watchPublic();

  Future<List<AppStrategy>> fetchAll();

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
  Future<String> uploadAttachment(String strategyId, File file);

  /// Turns a stored reference back into something the preview can load.
  Future<String> resolveAttachmentUrl(String ref);
}

/// Live Supabase-backed implementation with real-time sync and offline resilience.
class StrategiesRepositoryImpl implements StrategiesRepository {
  StrategiesRepositoryImpl._();

  static final StrategiesRepositoryImpl instance =
      StrategiesRepositoryImpl._();

  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final List<AppStrategy> _strategies = <AppStrategy>[];
  final Map<String, List<AppStrategyVersion>> _versions =
      <String, List<AppStrategyVersion>>{};
  final StreamController<List<AppStrategy>> _changes =
      StreamController<List<AppStrategy>>.broadcast();

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
      _strategies.addAll(demo.strategies());
      for (final AppStrategy s in _strategies) {
        _versions[s.id] =
            List<AppStrategyVersion>.of(demo.strategyVersions(s.id));
      }
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
          .channel('public:strategies_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'strategies',
            callback: (PostgresChangePayload payload) {
              _handlePostgresChange(payload);
            },
          )
        ..subscribe();
    } catch (e) {
      debugPrint('[StrategiesRepository] Realtime subscription error: $e');
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
          final isPublic = newRecord['visibility'] == 'public';
          if (recordUserId == currentUserId || isPublic) {
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
          final at = _strategies.indexWhere((s) => s.id == strategy.id);
          if (at != -1) {
            _strategies[at] = strategy;
          } else {
            final recordUserId = newRecord['user_id']?.toString();
            final isPublic = newRecord['visibility'] == 'public';
            if (recordUserId == currentUserId || isPublic) {
              _strategies.insert(0, strategy);
            }
          }
          _recordTickerLinks(strategy);
          _publish();
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

      final res = await client
          .from('strategies')
          .select()
          .or('user_id.eq.$targetUserId,visibility.eq.public')
          .order('updated_at', ascending: false);

      final List<AppStrategy> list = (res as List)
          .map((row) => _mapRowToStrategy(row as Map<String, dynamic>))
          .toList();

      _strategies
        ..clear()
        ..addAll(list);
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

  AppStrategy _mapRowToStrategy(Map<String, dynamic> row) {
    final statusStr = (row['status'] as String? ?? 'draft').toLowerCase();
    final status = switch (statusStr) {
      'testing' => AppStrategyStatus.testing,
      'live' => AppStrategyStatus.live,
      'retired' => AppStrategyStatus.retired,
      _ => AppStrategyStatus.draft,
    };

    final visibility = row['visibility'] as String? ?? 'private';
    final isPublic = visibility == 'public';
    final isFavorite = row['is_favorite'] as bool? ?? false;

    final tags = row['tags'] != null
        ? List<String>.from((row['tags'] as List).map((e) => e.toString()))
        : const <String>[];
    final linkedTickers = row['linked_tickers'] != null
        ? List<String>.from(
            (row['linked_tickers'] as List).map((e) => e.toString()))
        : const <String>[];
    final linkedNoteIds = row['linked_note_ids'] != null
        ? List<String>.from(
            (row['linked_note_ids'] as List).map((e) => e.toString()))
        : const <String>[];
    final linkedJournalIds = row['linked_journal_ids'] != null
        ? List<String>.from(
            (row['linked_journal_ids'] as List).map((e) => e.toString()))
        : const <String>[];

    final DateTime? createdAt = row['created_at'] != null
        ? DateTime.tryParse(row['created_at'].toString())
        : null;
    final DateTime? updatedAt = row['updated_at'] != null
        ? DateTime.tryParse(row['updated_at'].toString())
        : null;

    final name = (row['title'] as String?) ??
        (row['name'] as String?) ??
        'Untitled Strategy';
    final content = row['content'] as String? ?? '';
    final summary = row['summary'] as String? ?? row['ai_summary'] as String?;

    return AppStrategy(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      name: name,
      summary: summary,
      content: content,
      category: row['category'] as String?,
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
      trades: (row['trades'] as num?)?.toInt() ??
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
      author: row['author_id']?.toString() ?? 'You',
      note: row['note'] as String?,
      isCurrent: row['is_current'] as bool? ?? false,
      strategyId: row['strategy_id']?.toString() ?? '',
      content: row['content']?.toString() ?? '',
      summary: row['summary'] as String?,
      wordCount: (row['word_count'] as num?)?.toInt() ?? 0,
    );
  }

  List<AppStrategy> _snapshot() {
    final List<AppStrategy> copy = List<AppStrategy>.of(_strategies)
      ..sort((AppStrategy a, AppStrategy b) =>
          _editedAt(b).compareTo(_editedAt(a)));
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
            .select()
            .eq('id', id)
            .maybeSingle();
        if (res != null) {
          final strategy = _mapRowToStrategy(res);
          final at = _strategies.indexWhere((s) => s.id == strategy.id);
          if (at == -1) {
            _strategies.insert(0, strategy);
          } else {
            _strategies[at] = strategy;
          }
          _publish();
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
    await _init();
    final DateTime now = DateTime.now();

    AppStrategy saved = draft;
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        final String assignedId =
            _isUuid(draft.id) ? draft.id : const Uuid().v4();
        final row = _mapStrategyToRow(
          draft.withDerivedCounts(),
          targetUserId,
          targetId: assignedId,
        );

        final res = await client.from('strategies').insert(row).select().single();
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
            '[StrategiesRepository] create error, falling back to local: $e');
        saved = draft
            .copyWith(
              id: draft.id.isEmpty ? const Uuid().v4() : draft.id,
              createdAt: now,
              updatedAt: now,
            )
            .withDerivedCounts();
      }
    } else {
      saved = draft
          .copyWith(
            id: draft.id.isEmpty ? const Uuid().v4() : draft.id,
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
    await _init();

    AppStrategy saved = strategy
        .copyWith(updatedAt: DateTime.now())
        .withDerivedCounts();

    if (SupabaseConfig.isConfigured && _isUuid(strategy.id)) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        final row = _mapStrategyToRow(saved, targetUserId);
        row.remove('id');
        row['updated_at'] = DateTime.now().toIso8601String();

        final res = await client
            .from('strategies')
            .update(row)
            .eq('id', strategy.id)
            .select()
            .single();

        saved = _mapRowToStrategy(res);
      } catch (e) {
        debugPrint('[StrategiesRepository] update error: $e');
      }
    }

    final int at =
        _strategies.indexWhere((AppStrategy s) => s.id == saved.id);
    if (at == -1) {
      _strategies.insert(0, saved);
    } else {
      _strategies[at] = saved;
    }

    if (versionNote != null) {
      await saveVersion(saved.id, note: versionNote);
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
        await client.from('strategies').delete().eq('id', id);
      } catch (e) {
        debugPrint('[StrategiesRepository] delete error: $e');
      }
    }

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
    final targetFavorite = !(current?.isFavorite ?? false);
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('strategies')
            .update({'is_favorite': targetFavorite})
            .eq('id', id);
      } catch (e) {
        debugPrint('[StrategiesRepository] toggleFavorite error: $e');
      }
    }
    return _mutate(id, (AppStrategy s) => s.copyWith(isFavorite: targetFavorite));
  }

  @override
  Future<AppStrategy> setStatus(String id, AppStrategyStatus status) async {
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('strategies')
            .update({'status': status.name})
            .eq('id', id);
      } catch (e) {
        debugPrint('[StrategiesRepository] setStatus error: $e');
      }
    }
    return _mutate(id, (AppStrategy s) => s.copyWith(status: status));
  }

  @override
  Future<AppStrategy> setVisibility(String id, bool isPublic) async {
    if (SupabaseConfig.isConfigured && _isUuid(id)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('strategies')
            .update({'visibility': isPublic ? 'public' : 'private'})
            .eq('id', id);
      } catch (e) {
        debugPrint('[StrategiesRepository] setVisibility error: $e');
      }
    }
    return _mutate(id, (AppStrategy s) => s.copyWith(isPublic: isPublic));
  }

  @override
  Future<List<AppStrategyVersion>> versions(String strategyId) async {
    await _init();
    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('strategy_versions')
            .select()
            .eq('strategy_id', strategyId)
            .order('version_number', ascending: false);

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
    await _init();
    final AppStrategy? s = await getById(strategyId);
    if (s == null) throw StateError('Strategy not found: $strategyId');

    final currentVersions = await versions(strategyId);
    final int nextVersion = currentVersions.fold<int>(
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
            .select()
            .single();

        created = _mapRowToVersion(res);

        await client
            .from('strategies')
            .update({'version_count': nextVersion})
            .eq('id', strategyId);
      } catch (e) {
        debugPrint('[StrategiesRepository] saveVersion error: $e');
      }
    }

    final AppStrategyVersion cut = created ??
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

    final List<AppStrategyVersion> history =
        _versions[strategyId] ??= <AppStrategyVersion>[];
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
  }) =>
      AppStrategyVersion(
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
        await client.from('strategies').update({
          'content': body,
          'word_count': restored.wordCount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', strategyId);
      } catch (e) {
        debugPrint('[StrategiesRepository] restoreVersion error: $e');
      }
    }

    await saveVersion(strategyId, note: 'Restored $label');
    return (await getById(strategyId)) ?? restored;
  }

  @override
  Future<AppStrategy> linkNote(String strategyId, String noteId) async {
    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        final strategy = await getById(strategyId);
        if (strategy != null && !strategy.linkedNoteIds.contains(noteId)) {
          final updated = <String>[...strategy.linkedNoteIds, noteId];
          await client
              .from('strategies')
              .update({'linked_note_ids': updated})
              .eq('id', strategyId);
        }
      } catch (e) {
        debugPrint('[StrategiesRepository] linkNote error: $e');
      }
    }
    return _mutate(strategyId, (AppStrategy s) {
      if (s.linkedNoteIds.contains(noteId)) return s;
      return s.copyWith(
        linkedNoteIds: <String>[...s.linkedNoteIds, noteId],
      );
    });
  }

  @override
  Future<AppStrategy> unlinkNote(String strategyId, String noteId) async {
    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        final strategy = await getById(strategyId);
        if (strategy != null) {
          final updated = strategy.linkedNoteIds
              .where((String id) => id != noteId)
              .toList(growable: false);
          await client
              .from('strategies')
              .update({'linked_note_ids': updated})
              .eq('id', strategyId);
        }
      } catch (e) {
        debugPrint('[StrategiesRepository] unlinkNote error: $e');
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
    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        final strategy = await getById(strategyId);
        if (strategy != null &&
            !strategy.linkedJournalIds.contains(entryId)) {
          final updated = <String>[...strategy.linkedJournalIds, entryId];
          await client
              .from('strategies')
              .update({'linked_journal_ids': updated})
              .eq('id', strategyId);
        }
      } catch (e) {
        debugPrint('[StrategiesRepository] linkJournal error: $e');
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
    if (SupabaseConfig.isConfigured && _isUuid(strategyId)) {
      try {
        final client = SupabaseConfig.client!;
        final strategy = await getById(strategyId);
        if (strategy != null) {
          final updated = strategy.linkedJournalIds
              .where((String id) => id != entryId)
              .toList(growable: false);
          await client
              .from('strategies')
              .update({'linked_journal_ids': updated})
              .eq('id', strategyId);
        }
      } catch (e) {
        debugPrint('[StrategiesRepository] unlinkJournal error: $e');
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
  Future<String> uploadAttachment(String strategyId, File file) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final ext = file.path.contains('.') ? file.path.split('.').last : 'png';
        final storagePath = '$strategyId/${const Uuid().v4()}.$ext';
        await client.storage.from('strategy-attachments').upload(
              storagePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
        return storagePath;
      } catch (e) {
        debugPrint('[StrategiesRepository] uploadAttachment error: $e');
      }
    }
    return file.path;
  }

  @override
  Future<String> resolveAttachmentUrl(String ref) async {
    if (SupabaseConfig.isConfigured &&
        !ref.startsWith('/') &&
        !ref.contains(':\\') &&
        !ref.startsWith('file:')) {
      try {
        final client = SupabaseConfig.client!;
        final url =
            client.storage.from('strategy-attachments').getPublicUrl(ref);
        return url;
      } catch (e) {
        debugPrint('[StrategiesRepository] resolveAttachmentUrl error: $e');
      }
    }
    return ref;
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
        (AppStrategy a, AppStrategy b) =>
            StrategiesRepositoryImpl._editedAt(b)
                .compareTo(StrategiesRepositoryImpl._editedAt(a)),
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
