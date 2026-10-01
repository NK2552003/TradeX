import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/public_site/models/public_site_content.dart';

abstract class PublicSiteRepository {
  Future<PublicSiteContent> landing();
  Future<Map<String, dynamic>> pricing();
}

/// Asset fixtures use precisely the same row/JSON structure as SQL reads.
class MockPublicSiteRepository implements PublicSiteRepository {
  MockPublicSiteRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  Future<Map<String, dynamic>> _read(String name) async =>
      Map<String, dynamic>.from(
        jsonDecode(await _bundle.loadString('assets/data/$name.json')) as Map,
      );
  @override
  Future<PublicSiteContent> landing() async =>
      PublicSiteContent.fromJson(await _read('landing_page'));
  @override
  Future<Map<String, dynamic>> pricing() => _read('pricing_catalogue');
}

class DatabasePublicSiteRepository implements PublicSiteRepository {
  DatabasePublicSiteRepository(this.client);
  final SupabaseClient client;
  @override
  Future<PublicSiteContent> landing() async {
    final row = await client
        .from('public_site_pages')
        .select('content')
        .eq('id', 'landing')
        .eq('published', true)
        .single();
    return PublicSiteContent.fromJson(
      Map<String, dynamic>.from(row['content'] as Map),
    );
  }

  @override
  Future<Map<String, dynamic>> pricing() async {
    final row = await client
        .from('pricing_catalogues')
        .select('catalogue')
        .eq('id', 'default')
        .eq('published', true)
        .single();
    return Map<String, dynamic>.from(row['catalogue'] as Map);
  }
}

PublicSiteRepository publicSiteRepository() => SupabaseConfig.isConfigured
    ? DatabasePublicSiteRepository(SupabaseConfig.client!)
    : MockPublicSiteRepository();
