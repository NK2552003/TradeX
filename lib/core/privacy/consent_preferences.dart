import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/cross_subdomain_storage.dart';

import 'consent_browser_sync.dart';

/// Device-scoped choices; these are not terms acceptance or a certified CMP.
class ConsentPreferences {
  const ConsentPreferences({
    this.analytics = false,
    this.advertising = false,
    this.personalizedAds = false,
    this.affiliate = false,
    this.savedAt,
  });

  static const version = 1;
  static const lifetime = Duration(days: 180);
  final bool analytics;
  final bool advertising;
  final bool personalizedAds;
  final bool affiliate;
  final DateTime? savedAt;

  bool isCurrent(DateTime now) =>
      savedAt != null &&
      !savedAt!.isAfter(now) &&
      now.difference(savedAt!) < lifetime;

  Map<String, Object?> toJson() => {
    'version': version,
    'analytics': analytics,
    'advertising': advertising,
    'personalizedAds': advertising && personalizedAds,
    'affiliate': affiliate,
    'savedAt': savedAt?.toUtc().toIso8601String(),
  };

  static ConsentPreferences parse(String? raw, DateTime now) {
    try {
      final map = jsonDecode(raw ?? '') as Map<String, dynamic>;
      if (map['version'] != version) return const ConsentPreferences();
      final result = ConsentPreferences(
        analytics: map['analytics'] == true,
        advertising: map['advertising'] == true,
        personalizedAds:
            map['advertising'] == true && map['personalizedAds'] == true,
        affiliate: map['affiliate'] == true,
        savedAt: DateTime.tryParse(map['savedAt'] as String? ?? ''),
      );
      return result.isCurrent(now) ? result : const ConsentPreferences();
    } catch (_) {
      return const ConsentPreferences();
    }
  }
}

class ConsentController extends ChangeNotifier {
  ConsentController({
    Future<SharedPreferences> Function()? storage,
    bool syncBrowser = false,
    String? Function(String key)? readShared,
    void Function(String key, String value, {int maxAgeDays})? writeShared,
    void Function(String key)? removeShared,
  }) : _storage = storage ?? SharedPreferences.getInstance,
       _syncBrowser = syncBrowser,
       _readShared = readShared ?? CrossSubdomainState.getFlag,
       _writeShared = writeShared ?? CrossSubdomainState.setFlag,
       _removeShared = removeShared ?? CrossSubdomainState.removeFlag {
    if (syncBrowser) watchConsentStorage(refresh);
  }

  static final instance = ConsentController(syncBrowser: true);
  static const storageKey = 'alphajournal_consent_v1';
  static const dismissedNoticeKey = 'ax_cookie_notice_dismissed_v1';
  final Future<SharedPreferences> Function() _storage;
  final bool _syncBrowser;
  final String? Function(String key) _readShared;
  final void Function(String key, String value, {int maxAgeDays}) _writeShared;
  final void Function(String key) _removeShared;
  ConsentPreferences _value = const ConsentPreferences();
  Future<void>? _initializing;
  Zone? _initializingZone;
  int _revision = 0;
  bool _refreshAfterSave = false;
  bool loaded = false;
  bool saving = false;
  String? error;

  ConsentPreferences get value =>
      _value.isCurrent(DateTime.now()) ? _value : const ConsentPreferences();
  bool get needsChoice => !value.isCurrent(DateTime.now());

  Future<void> initialize() {
    final Zone currentZone = Zone.current;
    if (_initializing != null && identical(_initializingZone, currentZone)) {
      return _initializing!;
    }
    _initializingZone = currentZone;
    return _initializing = _load();
  }

  Future<void> refresh() async {
    if (saving) {
      _refreshAfterSave = true;
      return;
    }
    await _load();
  }

  ConsentPreferences _pickLatest(
    ConsentPreferences localChoice,
    ConsentPreferences sharedChoice,
    DateTime now,
  ) {
    final localValid = localChoice.isCurrent(now);
    final sharedValid = sharedChoice.isCurrent(now);
    if (localValid && sharedValid) {
      return sharedChoice.savedAt!.isAfter(localChoice.savedAt!)
          ? sharedChoice
          : localChoice;
    }
    if (sharedValid) return sharedChoice;
    if (localValid) return localChoice;
    return const ConsentPreferences();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    try {
      final prefs = await _storage();
      await prefs.reload();
      if (revision != _revision) return;
      final now = DateTime.now();
      final localRaw = prefs.getString(storageKey);
      final localChoice = ConsentPreferences.parse(localRaw, now);
      final sharedRaw = _syncBrowser ? _readShared(storageKey) : null;
      final sharedChoice = _syncBrowser
          ? ConsentPreferences.parse(sharedRaw, now)
          : const ConsentPreferences();
      final resolved = _pickLatest(localChoice, sharedChoice, now);
      if (_syncBrowser) {
        if (resolved.isCurrent(now)) {
          final encoded = jsonEncode(resolved.toJson());
          if (localRaw != encoded) {
            try {
              await prefs.setString(storageKey, encoded);
            } catch (_) {}
          }
          if (sharedRaw != encoded) {
            _writeShared(
              storageKey,
              encoded,
              maxAgeDays: ConsentPreferences.lifetime.inDays,
            );
          }
          _removeShared(dismissedNoticeKey);
        } else if (sharedRaw != null) {
          _removeShared(storageKey);
        }
      }
      _value = resolved;
      if (!_value.affiliate) await _clearAttribution(prefs);
      error = null;
    } catch (_) {
      if (revision != _revision) return;
      _value = const ConsentPreferences();
      error = 'Device storage is unavailable. Optional tracking stays off.';
    }
    loaded = true;
    notifyListeners();
  }

  Future<bool> save(ConsentPreferences choice) async {
    if (saving) return false;
    await initialize();
    if (saving) return false;
    ++_revision;
    saving = true;
    error = null;
    // Stop optional processing immediately, including if persistence fails.
    _value = const ConsentPreferences();
    notifyListeners();
    try {
      final prefs = await _storage();
      if (!choice.affiliate) await _clearAttribution(prefs);
      final saved = ConsentPreferences(
        analytics: choice.analytics,
        advertising: choice.advertising,
        personalizedAds: choice.advertising && choice.personalizedAds,
        affiliate: choice.affiliate,
        savedAt: DateTime.now().toUtc(),
      );
      final encoded = jsonEncode(saved.toJson());
      if (!await prefs.setString(storageKey, encoded)) {
        throw StateError('Preferences were not persisted');
      }
      if (_syncBrowser) {
        _writeShared(
          storageKey,
          encoded,
          maxAgeDays: ConsentPreferences.lifetime.inDays,
        );
        _removeShared(dismissedNoticeKey);
      }
      _value = saved;
    } catch (_) {
      error =
          'Choices could not be saved. Optional tracking stays off. '
          'Allow device storage and try again, or continue with essential storage.';
    }
    saving = false;
    notifyListeners();
    final succeeded = error == null;
    if (_refreshAfterSave) {
      _refreshAfterSave = false;
      await refresh();
    }
    return succeeded;
  }

  Future<void> _clearAttribution(SharedPreferences prefs) async {
    for (final key in ['affiliate_attribution_v1', 'affiliate_visitor_v1']) {
      if (_syncBrowser) {
        _removeShared(key);
      }
      if (prefs.containsKey(key) && !await prefs.remove(key)) {
        throw StateError('Optional attribution could not be removed');
      }
    }
  }
}
