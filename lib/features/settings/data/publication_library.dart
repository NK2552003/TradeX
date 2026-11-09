import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PublicationSection {
  const PublicationSection(this.title, this.body);
  final String title;
  final String body;
}

class PublicationDocument {
  PublicationDocument(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      group = json['group'] as String,
      status = json['status'] as String,
      updated = json['updated'] as String,
      intro = json['intro'] as String,
      sections = (json['sections'] as List)
          .map(
            (section) => PublicationSection(
              section['title'] as String,
              section['body'] as String,
            ),
          )
          .toList();

  final String id;
  final String title;
  final String group;
  final String status;
  final String updated;
  final String intro;
  final List<PublicationSection> sections;

  bool matches(String query) {
    final text =
        '$title $group $intro ${sections.map((s) => '${s.title} ${s.body}').join(' ')}'
            .toLowerCase();
    return query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .every(text.contains);
  }
}

class PublicationLibrary {
  static List<PublicationDocument>? _documents;
  static Future<List<PublicationDocument>>? _loading;

  static Future<List<PublicationDocument>> load() {
    if (_documents != null) return SynchronousFuture(_documents!);
    return _loading ??= _read()
        .then((documents) {
          _documents = List.unmodifiable(documents);
          return _documents!;
        })
        .catchError((Object error, StackTrace stack) {
          _loading = null;
          Error.throwWithStackTrace(error, stack);
        });
  }

  static Future<List<PublicationDocument>> _read() async {
    final raw = await rootBundle.loadString(
      'assets/legal/publication_library.json',
    );
    return (jsonDecode(raw) as List)
        .map((json) => PublicationDocument(json as Map<String, dynamic>))
        .toList();
  }
}
