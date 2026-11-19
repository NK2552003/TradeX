import 'package:flutter_test/flutter_test.dart';

import 'package:alphajournal/core/update/app_update.dart';

void main() {
  group('AppSemanticVersion', () {
    test('orders stable, prerelease, and numeric identifiers correctly', () {
      expect(
        AppSemanticVersion.parse(
          '1.0.0',
        ).compareTo(AppSemanticVersion.parse('1.0.0-rc.1')),
        greaterThan(0),
      );
      expect(
        AppSemanticVersion.parse(
          '1.0.0-rc.10',
        ).compareTo(AppSemanticVersion.parse('1.0.0-rc.2')),
        greaterThan(0),
      );
      expect(AppSemanticVersion.parse('v2.3.4+91').toString(), '2.3.4');
    });

    test('rejects malformed versions', () {
      expect(() => AppSemanticVersion.parse('1.2'), throwsFormatException);
      expect(() => AppSemanticVersion.parse('release'), throwsFormatException);
      expect(() => AppSemanticVersion.parse('1.02.3'), throwsFormatException);
      expect(
        () => AppSemanticVersion.parse('1.2.3-rc.01'),
        throwsFormatException,
      );
    });
  });

  group('AppPlatformRelease', () {
    final current = AppBuildIdentity(
      appName: 'AlphaJournal',
      packageName: 'com.nk2552003.alphajournal',
      platform: 'android',
      version: AppSemanticVersion.parse('1.0.0'),
      buildNumber: 5,
    );

    AppPlatformRelease release({
      String latest = '1.0.0',
      int latestBuild = 5,
      String minimum = '1.0.0',
      int minimumBuild = 1,
    }) => AppPlatformRelease(
      enabled: true,
      latestVersion: AppSemanticVersion.parse(latest),
      latestBuildNumber: latestBuild,
      minimumVersion: AppSemanticVersion.parse(minimum),
      minimumBuildNumber: minimumBuild,
      updateUri: Uri.parse('https://alphajournal.in/download'),
      summary: 'Update available.',
    );

    test('uses build numbers when semantic versions match', () {
      expect(
        release(latestBuild: 6).urgencyFor(current),
        AppUpdateUrgency.recommended,
      );
      expect(
        release(minimumBuild: 6).urgencyFor(current),
        AppUpdateUrgency.required,
      );
      expect(release().urgencyFor(current), AppUpdateUrgency.none);
    });

    test('requires versions below the minimum supported release', () {
      expect(
        release(latest: '2.0.0', minimum: '1.1.0').urgencyFor(current),
        AppUpdateUrgency.required,
      );
    });
  });

  test('manifest rejects unsupported schemas and insecure update URLs', () {
    expect(
      () => AppUpdateManifest.fromJson(<String, dynamic>{
        'schema_version': 2,
        'platforms': <String, dynamic>{},
      }),
      throwsFormatException,
    );
    final manifest = AppUpdateManifest.fromJson(<String, dynamic>{
      'schema_version': 1,
      'platforms': <String, dynamic>{
        'web': <String, dynamic>{
          'enabled': true,
          'latest_version': '1.0.1',
          'latest_build_number': 2,
          'minimum_supported_version': '1.0.0',
          'minimum_build_number': 1,
          'update_url': 'http://example.test/update',
          'summary': 'A safe summary.',
        },
      },
    });
    expect(manifest.platforms['web']?.updateUri, isNull);
  });

  test('manifest rejects a minimum release newer than the latest release', () {
    expect(
      () => AppUpdateManifest.fromJson(<String, dynamic>{
        'schema_version': 1,
        'platforms': <String, dynamic>{
          'web': <String, dynamic>{
            'enabled': true,
            'latest_version': '1.0.0',
            'latest_build_number': 1,
            'minimum_supported_version': '1.0.1',
            'minimum_build_number': 1,
            'update_url': 'https://app.alphajournal.in',
            'summary': 'Invalid release order.',
          },
        },
      }),
      throwsFormatException,
    );
  });
}
