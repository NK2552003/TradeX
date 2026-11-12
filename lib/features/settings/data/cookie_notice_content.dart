import 'dart:convert';

import 'package:flutter/services.dart';

/// Editable notice copy bundled with the cookie policy.
class CookieNoticeContent {
  CookieNoticeContent._(Map<String, dynamic> json)
    : labels = Map<String, String>.from(json['labels'] as Map),
      purposes = (json['purposes'] as Map<String, dynamic>).map(
        (id, fields) => MapEntry(id, Map<String, String>.from(fields as Map)),
      );

  final Map<String, String> labels;
  final Map<String, Map<String, String>> purposes;

  String operator [](String key) => labels[key]!;

  static Future<CookieNoticeContent> load() => rootBundle.loadStructuredData(
    'assets/legal/cookie_notice.json',
    (raw) async =>
        CookieNoticeContent._(jsonDecode(raw) as Map<String, dynamic>),
  );
}
