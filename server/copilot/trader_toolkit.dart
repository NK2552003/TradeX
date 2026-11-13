import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'store.dart';

/// Load only the shipped public scripts into the provider's Python sandbox.
Future<String> uploadTraderToolkit(http.Client client, String key) async {
  final file = File('supabase/functions/ai-gateway/trader-skills.json');
  final archive = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final request =
      http.MultipartRequest(
          'POST',
          Uri.parse('https://api.openai.com/v1/files'),
        )
        ..headers['Authorization'] = 'Bearer $key'
        ..fields.addAll({
          'purpose': 'user_data',
          'expires_after[anchor]': 'created_at',
          'expires_after[seconds]': '3600',
        })
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            base64Decode(archive['base64'] as String),
            filename: archive['filename'] as String,
            contentType: http.MediaType('application', 'zip'),
          ),
        );
  final response = await http.Response.fromStream(
    await client.send(request).timeout(const Duration(seconds: 15)),
  );
  final id = response.statusCode == 200
      ? jsonDecode(response.body)['id']
      : null;
  if (id is! String) {
    throw const CopilotFailure(
      'The trader toolkit could not be loaded. Retry this request.',
    );
  }
  return id;
}
