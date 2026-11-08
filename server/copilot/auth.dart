import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'store.dart';

class CopilotAuth {
  CopilotAuth(this.config);
  final CopilotConfig config;

  Future<String> identify(
    String? authorization,
    InternetAddress? address,
  ) async {
    if (config.localOwner && address?.isLoopback == true) return 'local-owner';
    if (authorization == null ||
        !authorization.startsWith('Bearer ') ||
        config.supabaseUrl.isEmpty ||
        config.anonKey.isEmpty) {
      throw const CopilotFailure(
        'Sign in to connect your copilot workspace.',
        401,
      );
    }
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('${config.supabaseUrl}/auth/v1/user'),
            headers: {'Authorization': authorization, 'apikey': config.anonKey},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const CopilotFailure('Your session expired. Sign in again.', 401);
      }
      final user = jsonDecode(response.body) as Map<String, dynamic>;
      final id = user['id'];
      if (id is! String || id.isEmpty) {
        throw const CopilotFailure('Unable to verify this account.', 401);
      }
      return id;
    } finally {
      client.close();
    }
  }
}
