// FCM token HTTP v1 delivery remains supported; migrate to FID delivery as a coordinated backend change.
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

bool get _supported => [
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.macOS,
].contains(defaultTargetPlatform);
Future<FirebaseMessaging> _messaging() async {
  if (!_supported) {
    throw StateError('Use the browser app for notifications on this platform.');
  }
  if (Firebase.apps.isEmpty) {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if ([apiKey, appId, sender, project].any((value) => value.isEmpty)) {
      throw StateError('Native push is not configured in this build.');
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: sender,
        projectId: project,
        iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      ),
    );
  }
  return FirebaseMessaging.instance;
}

Future<String> currentSubscription() async {
  if (await pushStatus() != 'subscribed') return '';
  final token = await FirebaseMessaging.instance.getToken();
  return token == null
      ? ''
      : jsonEncode({
          'endpoint': 'fcm:$token',
          'keys': {'p256dh': '', 'auth': ''},
        });
}

Future<String> pushStatus() async {
  if (!_supported) return 'unsupported';
  final messaging = await _messaging();
  final permission =
      (await messaging.getNotificationSettings()).authorizationStatus;
  if (permission == AuthorizationStatus.denied) return 'denied';
  if (permission == AuthorizationStatus.notDetermined) return 'default';
  return messaging.isAutoInitEnabled && await messaging.getToken() != null
      ? 'subscribed'
      : 'default';
}

Future<String> enablePush(String key) async {
  final messaging = await _messaging();
  final permission = await messaging.requestPermission();
  if (![
    AuthorizationStatus.authorized,
    AuthorizationStatus.provisional,
  ].contains(permission.authorizationStatus)) {
    throw StateError(
      'Notifications are blocked. Enable them in device settings.',
    );
  }
  await messaging.setAutoInitEnabled(true);
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  final token = await messaging.getToken();
  if (token == null) {
    throw StateError('Device registration is not ready. Please try again.');
  }
  return jsonEncode({
    'endpoint': 'fcm:$token',
    'keys': {'p256dh': '', 'auth': ''},
  });
}

Future<String> disablePush() async {
  if (!_supported || Firebase.apps.isEmpty) return '';
  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken();
  await messaging.setAutoInitEnabled(false);
  await messaging.deleteToken();
  return token == null ? '' : 'fcm:$token';
}

Stream<String> get tokenChanges => FirebaseMessaging.instance.onTokenRefresh;
