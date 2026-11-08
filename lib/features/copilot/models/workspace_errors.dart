import 'package:uuid/uuid.dart';

import 'workspace.dart';

class CopilotFailure implements Exception {
  const CopilotFailure(this.message, [this.status = 400]);
  final String message;
  final int status;
  @override
  String toString() => message;
}

String newId() => const Uuid().v4();
String now() => DateTime.now().toUtc().toIso8601String();

Json recordById(Json state, String collection, String id) {
  for (final item in (state[collection] as List)) {
    if (item['id'] == id) return item as Json;
  }
  throw const CopilotFailure('This item no longer exists.', 404);
}
