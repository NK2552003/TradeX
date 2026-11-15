import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'push_platform_native.dart'
    if (dart.library.js_interop) 'push_platform_web.dart'
    as platform;

class PushService extends ChangeNotifier {
  static final instance = PushService();
  String status = 'default';
  bool busy = false;
  StreamSubscription<String>? _tokens;
  String? _endpoint;
  static const publicKey = String.fromEnvironment('WEB_PUSH_PUBLIC_KEY');

  void initialize() {
    final client = SupabaseConfig.client;
    if (client == null) return;
    client.auth.onAuthStateChange.listen((event) {
      if (event.session != null) {
        refresh().catchError((Object _) {});
      } else {
        _tokens?.cancel();
        status = 'default';
        notifyListeners();
      }
    });
    refresh().catchError((Object _) {});
  }

  Future<void> refresh() async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    status = await platform.pushStatus();
    if (status == 'subscribed' && client != null && user != null) {
      final value = await platform.currentSubscription();
      if (value.isNotEmpty) {
        try {
          await _register(
            client,
            user.id,
            jsonDecode(value) as Map<String, dynamic>,
          );
        } catch (_) {
          status = 'default';
        }
      }
    } else if (user == null) {
      status = 'default';
    }
    notifyListeners();
  }

  Future<void> _register(
    SupabaseClient client,
    String userId,
    Map<String, dynamic> sub,
  ) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Your account changed.');
    }
    await client.from('push_subscriptions').upsert({
      'user_id': userId,
      'endpoint': sub['endpoint'],
      'p256dh': sub['keys']['p256dh'],
      'auth': sub['keys']['auth'],
      'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'endpoint');
    _endpoint = sub['endpoint'] as String;
    if (!kIsWeb) {
      await _tokens?.cancel();
      _tokens = platform.tokenChanges.listen((token) async {
        if (client.auth.currentUser?.id != userId) return;
        final previous = _endpoint;
        try {
          await client.from('push_subscriptions').upsert({
            'user_id': userId,
            'endpoint': 'fcm:$token',
            'p256dh': '',
            'auth': '',
            'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
          }, onConflict: 'endpoint');
          if (previous != null && previous != 'fcm:$token') {
            await client
                .from('push_subscriptions')
                .delete()
                .eq('endpoint', previous);
          }
          _endpoint = 'fcm:$token';
        } catch (_) {
          status = 'default';
          notifyListeners();
        }
      });
    }
  }

  Future<void> enable() async {
    if (busy) return;
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('Sign in to enable notifications.');
    }
    busy = true;
    notifyListeners();
    try {
      final sub =
          jsonDecode(await platform.enablePush(publicKey))
              as Map<String, dynamic>;
      if (client.auth.currentUser?.id != user.id) {
        await platform.disablePush();
        throw StateError('Your account changed. Please try again.');
      }
      await _register(client, user.id, sub);
      status = 'subscribed';
    } catch (_) {
      // Do not leave an unregistered browser subscription looking enabled.
      try {
        await platform.disablePush();
      } catch (_) {}
      status = 'default';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disable() async {
    await _tokens?.cancel();
    _tokens = null;
    final endpoint = await platform.disablePush();
    if (endpoint.isNotEmpty) {
      await SupabaseConfig.client
          ?.from('push_subscriptions')
          .delete()
          .eq('endpoint', endpoint);
    }
    status = 'default';
    notifyListeners();
  }
}
