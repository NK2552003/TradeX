import 'dart:async';
import 'public_content_test.dart' show FileAssets;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/features/public_site/data/public_site_repository.dart';

void main() {
  test(
    'published pricing remains available when database tables are unseeded',
    () async {
      final client = SupabaseClient(
        'https://example.test',
        'test-key',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"code":"PGRST205","message":"pricing_catalogues missing"}',
            404,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final repo = DatabasePublicSiteRepository(
        client,
        fallback: MockPublicSiteRepository(bundle: FileAssets()),
      );
      final catalogue = await repo.pricing();
      expect(catalogue['plans'], isNotEmpty);
      await client.dispose();
    },
  );
  test('stalled database request resolves through bundled pricing', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((_) => Completer<http.Response>().future),
    );
    final repo = DatabasePublicSiteRepository(
      client,
      fallback: MockPublicSiteRepository(bundle: FileAssets()),
      requestTimeout: const Duration(milliseconds: 20),
    );
    expect((await repo.pricing())['plans'], isNotEmpty);
    await client.dispose();
  });
  test('missing landing row resolves through bundled page', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient(
        (_) async => http.Response(
          'null',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final repo = DatabasePublicSiteRepository(
      client,
      fallback: MockPublicSiteRepository(bundle: FileAssets()),
    );
    expect((await repo.landing()).json, isNotEmpty);
    await client.dispose();
  });
}
