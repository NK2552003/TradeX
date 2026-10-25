import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/supabase_config.dart';

/// Stores a referral through auth navigation and email-verification reloads.
class AffiliateAttribution {
  static const _key = 'affiliate_attribution_v1';
  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null) return null;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(value) as Map);
      final date = DateTime.parse(data['captured_at'] as String);
      return DateTime.now().difference(date).inDays < 30 ? data : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> capture(String code, String? campaign) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{3,80}$').hasMatch(code)) return;
    if (campaign != null &&
        !RegExp(r'^[a-z0-9][a-z0-9-]{2,39}$').hasMatch(campaign)) {
      campaign = null;
    }
    final previous = await load();
    final prefs = await SharedPreferences.getInstance();
    final visitor =
        prefs.getString('affiliate_visitor_v1') ??
        List.generate(
          24,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    await prefs.setString('affiliate_visitor_v1', visitor);
    await prefs.setString(
      _key,
      jsonEncode({
        'code': code,
        'campaign': campaign,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    if (SupabaseConfig.isConfigured &&
        campaign != null &&
        (previous?['code'] != code || previous?['campaign'] != campaign)) {
      try {
        await SupabaseConfig.client!.functions
            .invoke(
              'affiliate-referral',
              body: {'code': code, 'campaign': campaign, 'visitor': visitor},
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Attribution remains available even if click telemetry is unavailable. */
      }
    }
  }

  static Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}
