import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:tradex/features/copilot/models/workspace.dart';
import 'package:tradex/features/copilot/models/workspace_errors.dart';

export 'package:tradex/features/copilot/models/workspace_errors.dart';

void resetContinuation(Json thread) {
  thread.remove('responseId');
  thread.remove('continuation');
  for (final approval in thread['approvals'] as List? ?? []) {
    if (approval['status'] == 'pending' || approval['status'] == 'executing') {
      approval['status'] = 'interrupted';
      approval['result'] = {
        'error':
            'Interrupted. Check the destination before requesting another action; execution may already have occurred.',
      };
    }
  }
}

class WorkspaceStore {
  WorkspaceStore(this.directory);
  final Directory directory;
  final Map<String, Json> _cache = {};
  Future<void> _queue = Future.value();
  RandomAccessFile? _lock;

  Future<void> open() async {
    await directory.create(recursive: true);
    _lock = await File(
      p.join(directory.path, '.lock'),
    ).open(mode: FileMode.append);
    await _lock!.lock(FileLock.exclusive);
    await for (final entity in directory.list()) {
      if (entity is! File || p.extension(entity.path) != '.json') continue;
      final owner = p.basenameWithoutExtension(entity.path);
      final state = jsonDecode(await entity.readAsString()) as Json;
      for (final thread in records(state['threads'])) {
        if (thread['status'] == 'running' || thread['status'] == 'ready') {
          final live = recordById(state, 'threads', thread['id']);
          live['status'] = 'interrupted';
          resetContinuation(live);
          for (final message in live['messages'] as List) {
            if (message['status'] == 'streaming') {
              message['status'] = 'interrupted';
            }
          }
        }
        final live = recordById(state, 'threads', thread['id']);
        if ((live['approvals'] as List).any(
          (a) => a['status'] == 'executing',
        )) {
          live['status'] = 'interrupted';
          resetContinuation(live);
        }
      }
      for (final task in state['schedules'] as List) {
        if (task['status'] == 'running') task['status'] = 'interrupted';
      }
      for (final call in state['calls'] as List) {
        if (call['status'] == 'active') {
          call['status'] = 'interrupted';
          call['endedAt'] = now();
        }
      }
      _cache[owner] = state;
      await _write(owner, state);
    }
  }

  String _ownerKey(String owner) =>
      base64Url.encode(utf8.encode(owner)).replaceAll('=', '');
  Iterable<String> get owners => _cache.keys.map(
    (key) => utf8.decode(base64Url.decode(base64Url.normalize(key))),
  );

  Future<Json> read(String owner) async {
    await _queue;
    final key = _ownerKey(owner);
    final state = _cache.putIfAbsent(key, initialWorkspace);
    return jsonDecode(jsonEncode(state)) as Json;
  }

  Future<T> change<T>(String owner, T Function(Json state) apply) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        final key = _ownerKey(owner);
        final state =
            jsonDecode(jsonEncode(_cache[key] ?? initialWorkspace())) as Json;
        final result = apply(state);
        await _write(key, state);
        _cache[key] = state;
        completer.complete(result);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<void> _write(String key, Json state) async {
    final target = p.join(directory.path, '$key.json');
    final pending = File('$target.tmp');
    await pending.writeAsString(jsonEncode(state), flush: true);
    await pending.rename(target);
  }

  Future<void> close() async {
    await _queue;
    await _lock?.unlock();
    await _lock?.close();
  }
}
