import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:alphajournal/core/update/app_update.dart';

void main() {
  AppBuildIdentity identity({String platform = 'web'}) => AppBuildIdentity(
    appName: 'AlphaJournal',
    packageName: 'com.nk2552003.alphajournal',
    platform: platform,
    version: AppSemanticVersion.parse('1.0.0'),
    buildNumber: 1,
  );

  String manifest({
    String latestVersion = '1.0.1',
    int latestBuild = 2,
    String minimumVersion = '1.0.0',
    int minimumBuild = 1,
  }) => jsonEncode(<String, dynamic>{
    'schema_version': 1,
    'generated_at': '2026-11-19T00:00:00Z',
    'release_notes_url': 'https://alphajournal.in/help/release-notes',
    'platforms': <String, dynamic>{
      'web': <String, dynamic>{
        'enabled': true,
        'latest_version': latestVersion,
        'latest_build_number': latestBuild,
        'minimum_supported_version': minimumVersion,
        'minimum_build_number': minimumBuild,
        'update_url': 'https://app.alphajournal.in',
        'summary': 'A newer AlphaJournal build is available.',
      },
    },
  });

  test('deduplicates concurrent requests and caches recent results', () async {
    final responseGate = Completer<void>();
    var requestCount = 0;
    var now = DateTime.utc(2026, 11, 19, 10);
    final client = MockClient((_) async {
      requestCount++;
      await responseGate.future;
      return http.Response(manifest(), 200);
    });
    final service = AppUpdateService(
      client: client,
      manifestUri: Uri.parse('https://alphajournal.in/app-update.json'),
      identityLoader: () async => identity(),
      now: () => now,
    );

    final first = service.check();
    final second = service.check();
    responseGate.complete();
    final results = await Future.wait(<Future<AppUpdateStatus>>[first, second]);

    expect(requestCount, 1);
    expect(results.every((status) => status.hasUpdate), isTrue);
    expect(results.first.urgency, AppUpdateUrgency.recommended);

    now = now.add(const Duration(hours: 1));
    await service.check();
    expect(requestCount, 1);
  });

  test(
    'treats identity, malformed, and oversized failures as unavailable',
    () async {
      final identityFailure = AppUpdateService(
        client: MockClient((_) async => http.Response(manifest(), 200)),
        manifestUri: Uri.parse('https://alphajournal.in/app-update.json'),
        identityLoader: () async =>
            throw StateError('package metadata missing'),
      );
      expect((await identityFailure.check()).checkedSuccessfully, isFalse);

      final malformed = AppUpdateService(
        client: MockClient((_) async => http.Response('{bad json', 200)),
        manifestUri: Uri.parse('https://alphajournal.in/app-update.json'),
        identityLoader: () async => identity(),
      );
      expect((await malformed.check()).checkedSuccessfully, isFalse);

      final oversized = AppUpdateService(
        client: MockClient(
          (_) async => http.Response(
            List<String>.filled(64 * 1024 + 1, 'x').join(),
            200,
          ),
        ),
        manifestUri: Uri.parse('https://alphajournal.in/app-update.json'),
        identityLoader: () async => identity(),
      );
      expect((await oversized.check()).checkedSuccessfully, isFalse);
    },
  );

  test('marks clients below the supported version as required', () async {
    final service = AppUpdateService(
      client: MockClient(
        (_) async => http.Response(
          manifest(latestVersion: '2.0.0', minimumVersion: '1.1.0'),
          200,
        ),
      ),
      manifestUri: Uri.parse('https://alphajournal.in/app-update.json'),
      identityLoader: () async => identity(),
    );

    final status = await service.check();
    expect(status.checkedSuccessfully, isTrue);
    expect(status.urgency, AppUpdateUrgency.required);
    expect(status.isRequired, isTrue);
  });

  test('retries failed checks sooner than successful checks', () async {
    var now = DateTime.utc(2026, 11, 19, 10);
    var requestCount = 0;
    final service = AppUpdateService(
      client: MockClient((_) async {
        requestCount++;
        if (requestCount == 1) return http.Response('unavailable', 503);
        return http.Response(manifest(), 200);
      }),
      manifestUri: Uri.parse('https://alphajournal.in/app-update.json'),
      identityLoader: () async => identity(),
      now: () => now,
    );

    expect((await service.check()).checkedSuccessfully, isFalse);
    now = now.add(const Duration(minutes: 5));
    expect((await service.check()).checkedSuccessfully, isFalse);
    expect(requestCount, 1);

    now = now.add(const Duration(minutes: 11));
    expect((await service.check()).checkedSuccessfully, isTrue);
    expect(requestCount, 2);
  });

  test('does not request an insecure manifest URL', () async {
    var requested = false;
    final service = AppUpdateService(
      client: MockClient((_) async {
        requested = true;
        return http.Response(manifest(), 200);
      }),
      manifestUri: Uri.parse('http://alphajournal.in/app-update.json'),
      identityLoader: () async => identity(),
    );

    expect((await service.check()).checkedSuccessfully, isFalse);
    expect(requested, isFalse);
  });
}
