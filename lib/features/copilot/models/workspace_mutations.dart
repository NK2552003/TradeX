import 'workspace.dart';
import 'workspace_errors.dart';

String requiredText(Json input, String key, {int max = 20000}) {
  final value = textOf(input, key).trim();
  if (value.isEmpty || value.length > max) {
    throw CopilotFailure('$key must contain 1–$max characters.');
  }
  return value;
}

class WorkspaceMutations {
  static Json apply(Json state, Json input) {
    final action = textOf(input, 'action');
    final id = textOf(input, 'id');
    final stamp = now();
    switch (action) {
      case 'thread.create':
        final specialist = recordById(
          state,
          'specialists',
          requiredText(input, 'specialistId'),
        );
        final pageId = input['pageId'];
        if (pageId != null) {
          final page = recordById(state, 'pages', pageId as String);
          if (!(specialist['spaceIds'] as List).contains(page['spaceId'])) {
            throw const CopilotFailure(
              'This specialist does not have access to that space.',
              403,
            );
          }
          final existing = records(state['threads'])
              .where(
                (t) =>
                    t['pageId'] == pageId &&
                    t['specialistId'] == specialist['id'],
              )
              .firstOrNull;
          if (existing != null) return existing;
        }
        final thread = <String, dynamic>{
          'id': newId(),
          'title': textOf(input, 'title', 'New conversation'),
          'specialistId': specialist['id'],
          'pageId': pageId,
          'createdAt': stamp,
          'updatedAt': stamp,
          'status': 'idle',
          'messages': <Json>[],
          'approvals': <Json>[],
          'pinned': false,
        };
        (state['threads'] as List).insert(0, thread);
        return thread;
      case 'thread.update':
        final thread = recordById(state, 'threads', id);
        if (input.containsKey('title')) {
          thread['title'] = requiredText(input, 'title', max: 160);
        }
        if (input.containsKey('pinned')) {
          thread['pinned'] = input['pinned'] == true;
        }
        return thread;
      case 'thread.delete':
        final thread = recordById(state, 'threads', id);
        if (thread['status'] == 'running') {
          throw const CopilotFailure(
            'Stop this conversation before deleting it.',
            409,
          );
        }
        (state['threads'] as List).removeWhere((t) => t['id'] == id);
        (state['schedules'] as List).removeWhere((t) => t['threadId'] == id);
        return {};
      case 'specialist.save':
        final previousSpecialist = id.isEmpty
            ? <String, dynamic>{}
            : recordById(state, 'specialists', id);
        final spaces = List<String>.from(input['spaceIds'] ?? []);
        if (spaces.isEmpty) {
          throw const CopilotFailure('Choose at least one space.');
        }
        for (final spaceId in spaces) {
          recordById(state, 'spaces', spaceId);
        }
        final item = <String, dynamic>{
          ...previousSpecialist,
          'id': id.isEmpty ? newId() : id,
          'name': requiredText(input, 'name', max: 60),
          'role': requiredText(input, 'role', max: 100),
          'instructions': requiredText(input, 'instructions', max: 12000),
          'spaceIds': spaces,
          'defaultSpaceId': spaces.contains(input['defaultSpaceId'])
              ? input['defaultSpaceId']
              : spaces.first,
          for (final permission in [
            'research',
            'memory',
            'code',
            'apps',
            'learning',
          ])
            permission: input[permission] == true,
        };
        _upsert(state, 'specialists', item);
        return item;
      case 'specialist.delete':
        if ((state['specialists'] as List).length <= 1) {
          throw const CopilotFailure('Keep at least one specialist.');
        }
        if (records(state['threads']).any((t) => t['specialistId'] == id)) {
          throw const CopilotFailure(
            'Delete this specialist’s conversations first.',
          );
        }
        (state['specialists'] as List).removeWhere((s) => s['id'] == id);
        (state['connections'] as List).removeWhere(
          (s) => s['specialistId'] == id,
        );
        return {};
      case 'space.save':
        final item = <String, dynamic>{
          'id': id.isEmpty ? newId() : id,
          'name': requiredText(input, 'name', max: 100),
          'description': textOf(input, 'description'),
        };
        _upsert(state, 'spaces', item);
        return item;
      case 'space.delete':
        if (records(state['pages']).any((p) => p['spaceId'] == id) ||
            records(
              state['specialists'],
            ).any((s) => (s['spaceIds'] as List).contains(id))) {
          throw const CopilotFailure(
            'Move pages and remove specialist access before deleting this space.',
          );
        }
        (state['spaces'] as List).removeWhere((s) => s['id'] == id);
        return {};
      case 'page.save':
        return savePage(state, input);
      case 'page.delete':
        if (records(state['pages']).any((p) => p['parentId'] == id)) {
          throw const CopilotFailure('Move or delete subpages first.');
        }
        (state['pages'] as List).removeWhere((p) => p['id'] == id);
        for (final thread in state['threads'] as List) {
          if (thread['pageId'] == id) thread['pageId'] = null;
        }
        return {};
      case 'memory.save':
        final item = <String, dynamic>{
          'id': id.isEmpty ? newId() : id,
          'text': requiredText(input, 'text', max: 4000),
          'createdAt': stamp,
        };
        _upsert(state, 'memories', item);
        return item;
      case 'memory.delete':
        (state['memories'] as List).removeWhere((m) => m['id'] == id);
        return {};
      case 'skill.publish':
        final skill = recordById(state, 'skills', id);
        skill['published'] = input['published'] == true;
        return skill;
      case 'skill.delete':
        (state['skills'] as List).removeWhere((s) => s['id'] == id);
        return {};
      case 'settings.save':
        final settings = state['settings'] as Json;
        if (['system', 'light', 'dark'].contains(input['appearance'])) {
          settings['appearance'] = input['appearance'];
        }
        for (final flag in ['paused', 'research', 'memory', 'apps']) {
          if (input.containsKey(flag)) settings[flag] = input[flag] == true;
        }
        return settings;
      case 'schedule.save':
        recordById(state, 'threads', requiredText(input, 'threadId'));
        final interval = (input['intervalMinutes'] as num?)?.toInt() ?? 0;
        if (interval != 0 && interval < 15) {
          throw const CopilotFailure(
            'Repeat intervals must be at least 15 minutes.',
          );
        }
        final next = DateTime.tryParse(textOf(input, 'nextRunAt'));
        if (next == null) {
          throw const CopilotFailure('Choose a valid run time.');
        }
        final item = <String, dynamic>{
          'id': id.isEmpty ? newId() : id,
          'threadId': input['threadId'],
          'prompt': requiredText(input, 'prompt'),
          'intervalMinutes': interval,
          'nextRunAt': next.toUtc().toIso8601String(),
          'status': 'scheduled',
          'runs': <Json>[],
        };
        if (id.isNotEmpty) {
          final previous = recordById(state, 'schedules', id);
          if (previous['status'] == 'running') {
            throw const CopilotFailure('Wait for this run to finish.', 409);
          }
          item['runs'] = previous['runs'];
        }
        _upsert(state, 'schedules', item);
        return item;
      case 'schedule.control':
        final task = recordById(state, 'schedules', id);
        if (task['status'] == 'running') {
          throw const CopilotFailure(
            'Stop the active conversation first.',
            409,
          );
        }
        final command = requiredText(input, 'command');
        if (!['pause', 'resume', 'retry', 'delete'].contains(command)) {
          throw const CopilotFailure('Unknown schedule action.');
        }
        if (command == 'delete') {
          (state['schedules'] as List).removeWhere((t) => t['id'] == id);
        } else {
          task['status'] = command == 'pause' ? 'paused' : 'scheduled';
          if (command == 'retry') task['nextRunAt'] = stamp;
        }
        return task;
      case 'connection.save':
        recordById(state, 'specialists', requiredText(input, 'specialistId'));
        final url = Uri.tryParse(requiredText(input, 'url'));
        if (url == null ||
            url.scheme != 'https' ||
            url.host.isEmpty ||
            url.userInfo.isNotEmpty) {
          throw const CopilotFailure('Use a public HTTPS MCP server URL.');
        }
        final previous = id.isEmpty
            ? <String, dynamic>{}
            : recordById(state, 'connections', id);
        final item = <String, dynamic>{
          'id': id.isEmpty ? newId() : id,
          'specialistId': input['specialistId'],
          'name': requiredText(input, 'name', max: 80),
          'url': url.toString(),
          'enabled': input['enabled'] == true,
          'kind': textOf(input, 'kind', 'app'),
          'token': input['clearToken'] == true
              ? ''
              : (textOf(input, 'token').isEmpty
                    ? previous['token'] ?? ''
                    : input['token']),
          'allowedTools': List<String>.from(input['allowedTools'] ?? []),
          'allTools':
              input['allTools'] ??
              (input['allowedTools'] as List? ?? []).isEmpty,
          'readOnlyTools': List<String>.from(input['readOnlyTools'] ?? []),
          'tools': previous['tools'] ?? <Json>[],
        };
        _upsert(state, 'connections', item);
        return {'id': item['id']};
      case 'connection.delete':
        (state['connections'] as List).removeWhere((c) => c['id'] == id);
        return {};
      default:
        throw const CopilotFailure('Unknown workspace action.');
    }
  }

  static Json savePage(Json state, Json input) {
    final id = textOf(input, 'id');
    final spaceId = requiredText(input, 'spaceId');
    recordById(state, 'spaces', spaceId);
    final old = id.isEmpty ? null : recordById(state, 'pages', id);
    if (old != null && old['revision'] != input['revision']) {
      throw const CopilotFailure(
        'This page changed elsewhere. Your draft is safe; reload the saved version before replacing it.',
        409,
      );
    }
    final parentId = input['parentId'];
    var cursor = parentId;
    final visited = <String>{if (id.isNotEmpty) id};
    while (cursor != null) {
      if (!visited.add(cursor as String)) {
        throw const CopilotFailure('A page cannot be its own ancestor.');
      }
      final parent = recordById(state, 'pages', cursor);
      if (parent['spaceId'] != spaceId) {
        throw const CopilotFailure('Parent pages must be in the same space.');
      }
      cursor = parent['parentId'];
    }
    if (old != null &&
        old['spaceId'] != spaceId &&
        records(state['pages']).any((p) => p['parentId'] == id)) {
      throw const CopilotFailure(
        'Move subpages before changing this page’s space.',
      );
    }
    final body = textOf(input, 'body');
    if (body.length > 200000) {
      throw const CopilotFailure('Pages can contain up to 200,000 characters.');
    }
    final item = <String, dynamic>{
      'id': id.isEmpty ? newId() : id,
      'title': requiredText(input, 'title', max: 200),
      'body': body,
      'spaceId': spaceId,
      'parentId': parentId,
      'revision': ((old?['revision'] as int?) ?? 0) + 1,
      'updatedAt': now(),
    };
    _upsert(state, 'pages', item);
    return item;
  }

  static void _upsert(Json state, String collection, Json item) {
    final list = state[collection] as List;
    final index = list.indexWhere((p) => p['id'] == item['id']);
    if (index < 0) {
      list.add(item);
    } else {
      list[index] = item;
    }
  }
}
