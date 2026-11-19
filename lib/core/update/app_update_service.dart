import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:alphajournal/core/config/env_config.dart';

import 'app_update_models.dart';

typedef AppBuildIdentityLoader = Future<AppBuildIdentity> Function();

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Uri? manifestUri,
    this.identityLoader,
    DateTime Function()? now,
    this.minimumCheckInterval = const Duration(hours: 6),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       manifestUri = manifestUri ?? Uri.parse(EnvConfig.appUpdateManifestUrl),
       _now = now ?? DateTime.now;

  static final AppUpdateService instance = AppUpdateService();

  static const int _maximumManifestBytes = 64 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const Duration _failureRetryInterval = Duration(minutes: 15);

  final http.Client _client;
  final bool _ownsClient;
  final Uri manifestUri;
  final AppBuildIdentityLoader? identityLoader;
  final DateTime Function() _now;
  final Duration minimumCheckInterval;

  Future<AppBuildIdentity>? _identity;
  Future<AppUpdateStatus>? _inFlight;
  AppUpdateStatus? _cached;

  Future<AppBuildIdentity> currentIdentity() {
    final cached = _identity;
    if (cached != null) return cached;
    final pending = _loadCurrentIdentity();
    late final Future<AppBuildIdentity> tracked;
    tracked = pending.onError((Object error, StackTrace stackTrace) {
      if (identical(_identity, tracked)) _identity = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _identity = tracked;
    return tracked;
  }

  Future<AppUpdateStatus> check({bool force = false}) {
    final now = _now().toUtc();
    final cached = _cached;
    final cacheLifetime = cached?.checkedSuccessfully == true
        ? minimumCheckInterval
        : _failureRetryInterval;
    if (!force &&
        cached != null &&
        now.difference(cached.checkedAt) < cacheLifetime) {
      return SynchronousFuture<AppUpdateStatus>(cached);
    }
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final pending = _check(now);
    _inFlight = pending;
    return pending.whenComplete(() => _inFlight = null);
  }

  Future<AppUpdateStatus> _check(DateTime checkedAt) async {
    late final AppBuildIdentity current;
    try {
      current = await currentIdentity();
    } on Object {
      return _cacheUnavailable(_fallbackIdentity(), checkedAt);
    }
    if (manifestUri.scheme != 'https' ||
        manifestUri.host.isEmpty ||
        manifestUri.userInfo.isNotEmpty) {
      return _cacheUnavailable(current, checkedAt);
    }
    try {
      final request = http.Request('GET', manifestUri)
        ..headers.addAll(const <String, String>{
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        });
      final response = await _client.send(request).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        return _cacheUnavailable(current, checkedAt);
      }
      final bodyBytes = <int>[];
      await for (final chunk in response.stream.timeout(_requestTimeout)) {
        if (bodyBytes.length + chunk.length > _maximumManifestBytes) {
          return _cacheUnavailable(current, checkedAt);
        }
        bodyBytes.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is! Map) return _cacheUnavailable(current, checkedAt);
      final manifest = AppUpdateManifest.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      final release = manifest.platforms[current.platform];
      final status = AppUpdateStatus(
        current: current,
        release: release,
        releaseNotesUri: manifest.releaseNotesUri,
        urgency: release?.urgencyFor(current) ?? AppUpdateUrgency.none,
        checkedSuccessfully: true,
        checkedAt: checkedAt,
      );
      _cached = status;
      return status;
    } on Object {
      return _cacheUnavailable(current, checkedAt);
    }
  }

  AppUpdateStatus _cacheUnavailable(
    AppBuildIdentity current,
    DateTime checkedAt,
  ) {
    final status = AppUpdateStatus(
      current: current,
      release: null,
      releaseNotesUri: null,
      urgency: AppUpdateUrgency.none,
      checkedSuccessfully: false,
      checkedAt: checkedAt,
    );
    _cached = status;
    return status;
  }

  Future<AppBuildIdentity> _loadCurrentIdentity() async {
    final customLoader = identityLoader;
    if (customLoader != null) return customLoader();
    final info = await PackageInfo.fromPlatform();
    final version =
        AppSemanticVersion.tryParse(info.version) ??
        AppSemanticVersion.parse('0.0.0');
    return AppBuildIdentity(
      appName: info.appName,
      packageName: info.packageName,
      platform: currentAppPlatform(),
      version: version,
      buildNumber: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  AppBuildIdentity _fallbackIdentity() => AppBuildIdentity(
    appName: 'AlphaJournal',
    packageName: 'com.nk2552003.alphajournal',
    platform: currentAppPlatform(),
    version: AppSemanticVersion.parse('0.0.0'),
    buildNumber: 0,
  );

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

String currentAppPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux || TargetPlatform.fuchsia => 'linux',
  };
}
