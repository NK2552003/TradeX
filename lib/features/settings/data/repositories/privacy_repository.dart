import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/utils/zip_archive_builder.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:alphajournal/features/settings/models/privacy_settings_model.dart';

abstract class PrivacyRepository {
  Future<PrivacySettingsModel> getPrivacySettings();
  Future<void> setPublicJournalsDefault(bool enabled);
  Future<void> setPublicStatsEnabled(bool enabled);
  Future<void> setMessagePermission(String permission);
  Future<void> setAllowMessageRequests(bool enabled);
  Future<void> setShowReadReceipts(bool enabled);
  Future<void> setShowActivityStatus(bool enabled);
  Future<void> setFilterSpamRequests(bool enabled);
  Future<List<AppTrader>> getBlockedUsers();
  Future<void> unblockUser(String userId);
  Future<DataExportRequest> requestDataExport();
  Future<DataExportRequest> getDataExportStatus();
}

class PrivacyRepositoryImpl implements PrivacyRepository {
  static final PrivacyRepositoryImpl instance = PrivacyRepositoryImpl._();

  PrivacyRepositoryImpl._() {
    _blockedUsers.clear();
  }

  factory PrivacyRepositoryImpl() => instance;

  static const String _localPrivacyKeyPrefix =
      'alphajournal_message_privacy_v1:';

  String _resolveUserId() =>
      SupabaseConfig.client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      '';

  String get _localPrivacyKey {
    final uid = _resolveUserId();
    return '$_localPrivacyKeyPrefix${uid.isEmpty ? 'local' : uid}';
  }

  PrivacySettingsModel _settings = const PrivacySettingsModel(
    publicJournals: true,
    publicStatsEnabled: true,
  );

  final ValueNotifier<PrivacySettingsModel> settingsNotifier =
      ValueNotifier<PrivacySettingsModel>(
        const PrivacySettingsModel(
          publicJournals: true,
          publicStatsEnabled: true,
        ),
      );

  PrivacySettingsModel get cachedSettings => _settings;

  Uint8List? _cachedArchiveBytes;
  String? _cachedArchiveFilename;

  void _setSettings(PrivacySettingsModel next) {
    _settings = next;
    settingsNotifier.value = next;
  }

  Future<void> _saveLocalPrivacyCache(PrivacySettingsModel settings) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_localPrivacyKey, jsonEncode(settings.toJson()));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadLocalPrivacyCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_localPrivacyKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  final List<AppTrader> _blockedUsers = <AppTrader>[
    const AppTrader(
      id: 'blk_1',
      handle: 'spammer_bot99',
      displayName: 'Free Signals Official',
      bio: 'DM for 1000% daily returns telegram link',
      tier: AppTier.free,
    ),
    const AppTrader(
      id: 'blk_2',
      handle: 'toxic_scalper',
      displayName: 'Rage Trader',
      bio: 'Crypto maximalist. No DMs.',
      tier: AppTier.free,
    ),
  ];

  DataExportRequest _exportRequest = DataExportRequest(
    status: 'none',
    requestedAt: DateTime.now(),
  );

  @override
  Future<PrivacySettingsModel> getPrivacySettings() async {
    final profile = await ProfileSettingsRepositoryImpl.instance.getProfile();
    var merged = _settings.copyWith(
      publicJournals: profile.publicJournals,
      publicStatsEnabled: profile.publicStats,
    );
    final localMsgPrivacy = await _loadLocalPrivacyCache();
    if (localMsgPrivacy != null) {
      merged = merged.copyWith(
        messagePermission:
            localMsgPrivacy['message_permission'] as String? ??
            merged.messagePermission,
        allowMessageRequests:
            localMsgPrivacy['allow_message_requests'] as bool? ??
            merged.allowMessageRequests,
        showReadReceipts:
            localMsgPrivacy['show_read_receipts'] as bool? ??
            merged.showReadReceipts,
        showActivityStatus:
            localMsgPrivacy['show_activity_status'] as bool? ??
            merged.showActivityStatus,
        filterSpamRequests:
            localMsgPrivacy['filter_spam_requests'] as bool? ??
            merged.filterSpamRequests,
      );
    }
    _setSettings(merged);
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return _settings;

        final res = await client
            .from('profiles')
            .select('notification_settings')
            .eq('id', targetUserId)
            .maybeSingle();

        if (res != null) {
          final notif = res['notification_settings'] is Map
              ? Map<String, dynamic>.from(res['notification_settings'] as Map)
              : <String, dynamic>{};
          final msgPriv = notif['message_privacy'] is Map
              ? Map<String, dynamic>.from(notif['message_privacy'] as Map)
              : <String, dynamic>{};
          final remoteSettings = PrivacySettingsModel(
            publicJournals: profile.publicJournals,
            publicStatsEnabled: profile.publicStats,
            messagePermission:
                msgPriv['message_permission'] as String? ??
                _settings.messagePermission,
            allowMessageRequests:
                msgPriv['allow_message_requests'] as bool? ??
                _settings.allowMessageRequests,
            showReadReceipts:
                msgPriv['show_read_receipts'] as bool? ??
                _settings.showReadReceipts,
            showActivityStatus:
                msgPriv['show_activity_status'] as bool? ??
                _settings.showActivityStatus,
            filterSpamRequests:
                msgPriv['filter_spam_requests'] as bool? ??
                _settings.filterSpamRequests,
          );
          _setSettings(remoteSettings);
          await _saveLocalPrivacyCache(remoteSettings);
          return _settings;
        }
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.getPrivacySettings error: $e');
      }
    }
    return _settings;
  }

  Future<void> _persistMessagePrivacy(PrivacySettingsModel previous) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) {
          throw StateError('Sign in to save privacy settings.');
        }

        final res = await client
            .from('profiles')
            .select('notification_settings')
            .eq('id', targetUserId)
            .maybeSingle();

        final notif = Map<String, dynamic>.from(
          res?['notification_settings'] as Map<String, dynamic>? ?? {},
        );
        notif['message_privacy'] = {
          'message_permission': _settings.messagePermission,
          'allow_message_requests': _settings.allowMessageRequests,
          'show_read_receipts': _settings.showReadReceipts,
          'show_activity_status': _settings.showActivityStatus,
          'filter_spam_requests': _settings.filterSpamRequests,
        };

        await client
            .from('profiles')
            .update({
              'notification_settings': notif,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', targetUserId);
      } catch (e) {
        _setSettings(previous);
        debugPrint('PrivacyRepositoryImpl._persistMessagePrivacy error: $e');
        rethrow;
      }
    }
    await _saveLocalPrivacyCache(_settings);
  }

  @override
  Future<void> setMessagePermission(String permission) async {
    final prev = _settings;
    _setSettings(_settings.copyWith(messagePermission: permission));
    await _persistMessagePrivacy(prev);
  }

  @override
  Future<void> setAllowMessageRequests(bool enabled) async {
    final prev = _settings;
    _setSettings(_settings.copyWith(allowMessageRequests: enabled));
    await _persistMessagePrivacy(prev);
  }

  @override
  Future<void> setShowReadReceipts(bool enabled) async {
    final prev = _settings;
    _setSettings(_settings.copyWith(showReadReceipts: enabled));
    await _persistMessagePrivacy(prev);
  }

  @override
  Future<void> setShowActivityStatus(bool enabled) async {
    final prev = _settings;
    _setSettings(_settings.copyWith(showActivityStatus: enabled));
    await _persistMessagePrivacy(prev);
  }

  @override
  Future<void> setFilterSpamRequests(bool enabled) async {
    final prev = _settings;
    _setSettings(_settings.copyWith(filterSpamRequests: enabled));
    await _persistMessagePrivacy(prev);
  }

  @override
  Future<void> setPublicJournalsDefault(bool enabled) async {
    final prev = _settings;
    _setSettings(_settings.copyWith(publicJournals: enabled));
    try {
      await ProfileSettingsRepositoryImpl.instance.updateProfile(
        publicJournalsEnabled: enabled,
      );
    } catch (e) {
      _setSettings(prev);
      rethrow;
    }
  }

  @override
  Future<void> setPublicStatsEnabled(bool enabled) async {
    final prev = _settings;
    _setSettings(_settings.copyWith(publicStatsEnabled: enabled));
    try {
      await ProfileSettingsRepositoryImpl.instance.updateProfile(
        publicStatsEnabled: enabled,
      );
    } catch (e) {
      _setSettings(prev);
      rethrow;
    }
  }

  @override
  Future<List<AppTrader>> getBlockedUsers() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return _blockedUsers;

        final res = await client
            .from('blocks')
            .select(
              'blocked_id, profiles!blocks_blocked_id_fkey(handle, display_name, bio, subscription_tier)',
            )
            .eq('blocker_id', targetUserId);

        if ((res as List).isNotEmpty) {
          final list = <AppTrader>[];
          for (final item in res) {
            final profileMap = item['profiles'] as Map<String, dynamic>? ?? {};
            final tierStr =
                profileMap['subscription_tier'] as String? ?? 'free';
            final tier = AppTier.values.firstWhere(
              (t) => t.name == tierStr,
              orElse: () => AppTier.free,
            );
            list.add(
              AppTrader(
                id: item['blocked_id'] as String,
                handle: profileMap['handle'] as String? ?? 'user',
                displayName:
                    profileMap['display_name'] as String? ??
                    profileMap['handle'] as String? ??
                    'User',
                bio: profileMap['bio'] as String? ?? '',
                tier: tier,
              ),
            );
          }
          return list;
        }
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.getBlockedUsers error: $e');
      }
    }
    return List<AppTrader>.from(_blockedUsers);
  }

  @override
  Future<void> unblockUser(String userId) async {
    _blockedUsers.removeWhere((u) => u.id == userId);
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return;

        await client
            .from('blocks')
            .delete()
            .eq('blocker_id', targetUserId)
            .eq('blocked_id', userId);
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.unblockUser error: $e');
      }
    }
  }

  Future<({Uint8List bytes, String filename})> buildDataExportArchive({
    bool forceRebuild = false,
  }) async {
    if (!forceRebuild &&
        _cachedArchiveBytes != null &&
        _cachedArchiveFilename != null) {
      return (bytes: _cachedArchiveBytes!, filename: _cachedArchiveFilename!);
    }

    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    final userId = user?.id ?? _resolveUserId();
    final now = DateTime.now().toUtc();

    Map<String, dynamic> profileData = ProfileSettingsRepositoryImpl
        .instance
        .cachedProfile
        .toJson();
    Map<String, dynamic> preferencesData = const <String, dynamic>{};
    List<Map<String, dynamic>> journalRows = JournalRepositoryImpl
        .instance
        .currentEntries
        .map(
          (e) => <String, dynamic>{
            'id': e.id,
            'ticker': e.ticker,
            'side': e.side.name,
            'entry_price': e.entry,
            'exit_price': e.exit,
            'quantity': e.size,
            'pnl': e.pnl,
            'outcome': e.outcome.name,
            'title': e.title,
            'content': e.content,
            'tags': e.tags,
            'is_public': e.isPublic,
            'opened_at': e.openedAt.toIso8601String(),
            'closed_at': e.closedAt?.toIso8601String(),
          },
        )
        .toList();
    List<Map<String, dynamic>> noteRows = const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> strategyRows = const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> postRows = const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> blockedRows = const <Map<String, dynamic>>[];

    if (SupabaseConfig.isConfigured && client != null && userId.isNotEmpty) {
      Future<List<Map<String, dynamic>>> fetchTable(
        String table,
        String column,
      ) async {
        try {
          final res = await client.from(table).select().eq(column, userId);
          return (res as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        } catch (e) {
          debugPrint('[PrivacyRepository] export $table skipped: $e');
          return const <Map<String, dynamic>>[];
        }
      }

      try {
        final prof = await client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (prof != null) profileData = Map<String, dynamic>.from(prof);
      } catch (_) {}

      try {
        final pref = await client
            .from('trader_preferences')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (pref != null) preferencesData = Map<String, dynamic>.from(pref);
      } catch (_) {}

      final fetched = await Future.wait<List<Map<String, dynamic>>>([
        fetchTable('journal_entries', 'user_id'),
        fetchTable('trader_notes', 'user_id'),
        fetchTable('strategies', 'user_id'),
        fetchTable('community_posts', 'author_id'),
        fetchTable('blocks', 'blocker_id'),
      ]);
      if (fetched[0].isNotEmpty) journalRows = fetched[0];
      noteRows = fetched[1];
      strategyRows = fetched[2];
      postRows = fetched[3];
      blockedRows = fetched[4];
    }

    final zip = ZipArchiveBuilder();
    zip.addString(
      'README.txt',
      'AlphaJournal GDPR Data Export\n'
          'Generated (UTC): ${now.toIso8601String()}\n'
          'Account ID: ${userId.isEmpty ? 'local' : userId}\n'
          'Email: ${user?.email ?? ProfileSettingsRepositoryImpl.instance.cachedProfile.email}\n\n'
          'Included Files:\n'
          '- profile_and_privacy.json: Profile details, preferences, and privacy configuration\n'
          '- journal_entries.json & trades.csv: Trade journal history\n'
          '- notes.json: Saved market & execution notes\n'
          '- strategies.json: Trading playbooks and setups\n'
          '- community_posts.json: Authored community posts\n'
          '- blocked_users.json: Moderation & blocked account records\n',
    );
    zip.addJson('profile_and_privacy.json', {
      'exported_at_utc': now.toIso8601String(),
      'profile': profileData,
      'privacy_settings': _settings.toJson(),
      'trader_preferences': preferencesData,
    });
    zip.addJson('journal_entries.json', journalRows);
    zip.addString('trades.csv', _toCsv(journalRows));
    zip.addJson('notes.json', noteRows);
    zip.addJson('strategies.json', strategyRows);
    zip.addJson('community_posts.json', postRows);
    zip.addJson('blocked_users.json', blockedRows);

    final bytes = zip.build(timestamp: now);
    final slug = userId.isEmpty
        ? 'trader'
        : userId.substring(0, userId.length > 8 ? 8 : userId.length);
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filename = 'alphajournal_export_${slug}_$stamp.zip';
    _cachedArchiveBytes = bytes;
    _cachedArchiveFilename = filename;
    return (bytes: bytes, filename: filename);
  }

  static String _toCsv(List<Map<String, dynamic>> rows) {
    const columns = <String>[
      'id',
      'ticker',
      'side',
      'entry_price',
      'exit_price',
      'quantity',
      'pnl',
      'outcome',
      'title',
      'opened_at',
      'closed_at',
      'is_public',
    ];
    String escapeCell(Object? value) {
      final raw = value?.toString() ?? '';
      if (raw.contains(',') ||
          raw.contains('"') ||
          raw.contains('\n') ||
          raw.contains('\r')) {
        return '"${raw.replaceAll('"', '""')}"';
      }
      return raw;
    }

    final buffer = StringBuffer()..writeln(columns.join(','));
    for (final row in rows) {
      buffer.writeln(columns.map((c) => escapeCell(row[c])).join(','));
    }
    return buffer.toString();
  }

  @override
  Future<DataExportRequest> requestDataExport() async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      throw StateError('Data export is not available in this environment.');
    }
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(days: 7));
    await buildDataExportArchive(forceRebuild: true);

    Map<String, dynamic> row = await client
        .from('data_export_requests')
        .insert({
          'user_id': user.id,
          'status': 'ready',
          'requested_at': now.toIso8601String(),
          'completed_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        })
        .select(
          'id, user_id, status, requested_at, download_url, completed_at, expires_at',
        )
        .single();

    if (row['status'] != 'ready' && row['id'] is String) {
      try {
        row = await client
            .from('data_export_requests')
            .update({
              'status': 'ready',
              'completed_at': now.toIso8601String(),
              'expires_at': expiresAt.toIso8601String(),
            })
            .eq('id', row['id'] as String)
            .select(
              'id, user_id, status, requested_at, download_url, completed_at, expires_at',
            )
            .single();
      } catch (_) {}
    }

    _exportRequest = DataExportRequest.fromJson(row);
    return _exportRequest;
  }

  @override
  Future<DataExportRequest> getDataExportStatus() async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      return _exportRequest;
    }
    var row = await client
        .from('data_export_requests')
        .select(
          'id, user_id, status, requested_at, download_url, completed_at, expires_at',
        )
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row != null) {
      Map<String, dynamic> effectiveRow = Map<String, dynamic>.from(row);
      // Auto-complete stalled legacy 'pending' export requests on client check
      // so users are never permanently stuck on "Processing Archive...".
      if (effectiveRow['status'] == 'pending' && effectiveRow['id'] is String) {
        final now = DateTime.now().toUtc();
        final expiresAt = now.add(const Duration(days: 7));
        try {
          await buildDataExportArchive();
          effectiveRow = await client
              .from('data_export_requests')
              .update({
                'status': 'ready',
                'completed_at': now.toIso8601String(),
                'expires_at': expiresAt.toIso8601String(),
              })
              .eq('id', effectiveRow['id'] as String)
              .select(
                'id, user_id, status, requested_at, download_url, completed_at, expires_at',
              )
              .single();
        } catch (_) {}
      }
      _exportRequest = DataExportRequest.fromJson(effectiveRow);
    }
    return _exportRequest;
  }
}
