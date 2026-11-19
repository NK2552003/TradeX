import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/settings/models/trading_prefs_model.dart';

abstract class TradingPrefsRepository {
  Future<TradingPrefsModel> getPreferences();
  Future<TradingPrefsModel> updatePreferences(TradingPrefsModel prefs);
  Future<List<AppChecklistItem>> getChecklist();
  Future<List<AppChecklistItem>> updateChecklist(List<AppChecklistItem> items);
  Future<List<AppChecklistItem>> addChecklistItem(
    String label, {
    String? description,
  });
  Future<List<AppChecklistItem>> deleteChecklistItem(String id);
}

class TradingPrefsRepositoryImpl implements TradingPrefsRepository {
  static const String _localExtrasKey = 'alphajournal_trading_extras_v1';
  static const String _localCoreKey = 'alphajournal_trading_core_v1';

  static final TradingPrefsRepositoryImpl instance =
      TradingPrefsRepositoryImpl._();
  TradingPrefsRepositoryImpl._();
  factory TradingPrefsRepositoryImpl() => instance;

  String get _targetUserId =>
      SupabaseConfig.client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      '';

  TradingPrefsModel _prefs = TradingPrefsModel.defaultPrefs();

  List<AppChecklistItem> _checklist = <AppChecklistItem>[
    const AppChecklistItem(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
      label: 'Trend alignment verified on higher timeframe (Daily/4H)',
      description: 'Ensure 200 EMA slope agrees with trade direction',
      done: true,
      icon: Icons.trending_up,
    ),
    const AppChecklistItem(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
      label: 'Key support/resistance level identified and tested',
      description: 'Check for volume confluence and liquidity sweep',
      done: true,
      icon: Icons.horizontal_rule,
    ),
    const AppChecklistItem(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3',
      label: 'Calculated stop-loss and 1:2+ risk-to-reward ratio',
      description: 'Max risk capped at 2% account equity',
      done: false,
      icon: Icons.shield_outlined,
    ),
    const AppChecklistItem(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4',
      label: 'High-impact economic news checked (FOMC, CPI, NFP)',
      description:
          'Avoid entering positions within 30 min of red-folder events',
      done: false,
      icon: Icons.event_note_outlined,
    ),
  ];

  Future<void> _hydrateLocalPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final coreRaw = sp.getString(_localCoreKey);
      if (coreRaw != null && coreRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(coreRaw);
        if (decoded is Map) {
          _prefs = TradingPrefsModel.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
      final extrasRaw = sp.getString(_localExtrasKey);
      if (extrasRaw != null && extrasRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(extrasRaw);
        if (decoded is Map) {
          _prefs = _prefs.mergeExtrasJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {}
  }

  Future<void> _persistLocalPrefs(TradingPrefsModel prefs) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_localCoreKey, jsonEncode(prefs.toJson()));
      await sp.setString(_localExtrasKey, jsonEncode(prefs.toExtrasJson()));
    } catch (_) {}
  }

  @override
  Future<TradingPrefsModel> getPreferences() async {
    await _hydrateLocalPrefs();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;

        final res = await client
            .from('trader_preferences')
            .select(
              'user_id, default_position_size_pct, default_r_multiple, '
              'default_watchlist_symbols, watchlist_refresh_interval_seconds',
            )
            .eq('user_id', targetUserId)
            .maybeSingle();

        if (res != null) {
          _prefs = TradingPrefsModel.fromJson(res);
        }

        final appPref = await client
            .from('user_app_preferences')
            .select('trading_extras')
            .eq('user_id', targetUserId)
            .maybeSingle();
        final extras = appPref?['trading_extras'];
        if (extras is Map && extras.isNotEmpty) {
          _prefs = _prefs.mergeExtrasJson(Map<String, dynamic>.from(extras));
        }
        await _persistLocalPrefs(_prefs);
        return _prefs;
      } catch (e) {
        debugPrint('[TradingPrefsRepository] getPreferences error: $e');
      }
    }
    return _prefs;
  }

  @override
  Future<TradingPrefsModel> updatePreferences(TradingPrefsModel prefs) async {
    _prefs = prefs;
    await _persistLocalPrefs(prefs);

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;

        final payload = prefs.toJson()..['user_id'] = targetUserId;
        final res = await client
            .from('trader_preferences')
            .upsert(payload)
            .select(
              'user_id, default_position_size_pct, default_r_multiple, '
              'default_watchlist_symbols, watchlist_refresh_interval_seconds',
            )
            .single();

        _prefs = TradingPrefsModel.fromJson(
          res,
        ).mergeExtrasJson(prefs.toExtrasJson());

        await client.from('user_app_preferences').upsert({
          'user_id': targetUserId,
          'trading_extras': prefs.toExtrasJson(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[TradingPrefsRepository] updatePreferences error: $e');
      }
    }
    return _prefs;
  }

  @override
  Future<List<AppChecklistItem>> getChecklist() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;

        final res = await client
            .from('trader_checklists')
            .select('id, user_id, label, description, done, sort_order')
            .eq('user_id', targetUserId)
            .order('sort_order', ascending: true)
            .limit(100);

        if ((res as List).isNotEmpty) {
          _checklist = (res as List).map((item) {
            final map = item as Map<String, dynamic>;
            return AppChecklistItem(
              id: map['id'] as String,
              label: map['label'] as String? ?? '',
              description: map['description'] as String?,
              done: map['done'] as bool? ?? false,
              icon: Icons.check_box_outlined,
            );
          }).toList();
          return List<AppChecklistItem>.from(_checklist);
        }
      } catch (e) {
        debugPrint('[TradingPrefsRepository] getChecklist error: $e');
      }
    }
    return List<AppChecklistItem>.from(_checklist);
  }

  @override
  Future<List<AppChecklistItem>> updateChecklist(
    List<AppChecklistItem> items,
  ) async {
    _checklist = List<AppChecklistItem>.from(items);

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;

        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          await client.from('trader_checklists').upsert({
            if (!item.id.startsWith('chk_') && !item.id.startsWith('bbb'))
              'id': item.id,
            'user_id': targetUserId,
            'label': item.label,
            'description': item.description,
            'done': item.done,
            'sort_order': i,
          });
        }
      } catch (e) {
        debugPrint('[TradingPrefsRepository] updateChecklist error: $e');
      }
    }
    return _checklist;
  }

  @override
  Future<List<AppChecklistItem>> addChecklistItem(
    String label, {
    String? description,
  }) async {
    final newItem = AppChecklistItem(
      id: 'chk_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      description: description,
      done: false,
      icon: Icons.check_box_outline_blank,
    );
    _checklist.add(newItem);

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;

        final res = await client
            .from('trader_checklists')
            .insert({
              'user_id': targetUserId,
              'label': label,
              'description': description,
              'done': false,
              'sort_order': _checklist.length - 1,
            })
            .select()
            .single();

        final createdItem = AppChecklistItem(
          id: res['id'] as String,
          label: res['label'] as String,
          description: res['description'] as String?,
          done: res['done'] as bool? ?? false,
          icon: Icons.check_box_outline_blank,
        );
        _checklist[_checklist.length - 1] = createdItem;
      } catch (e) {
        debugPrint('[TradingPrefsRepository] addChecklistItem error: $e');
      }
    }

    return List<AppChecklistItem>.from(_checklist);
  }

  @override
  Future<List<AppChecklistItem>> deleteChecklistItem(String id) async {
    _checklist.removeWhere((item) => item.id == id);

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        await client.from('trader_checklists').delete().eq('id', id);
      } catch (e) {
        debugPrint('[TradingPrefsRepository] deleteChecklistItem error: $e');
      }
    }

    return List<AppChecklistItem>.from(_checklist);
  }
}
