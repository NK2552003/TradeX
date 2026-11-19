import 'dart:async';

import 'package:alphajournal/features/copilot/models/workspace.dart';
import 'agent_runner.dart';
import 'store.dart';

class CopilotScheduler {
  CopilotScheduler(this.store, this.runner);
  final WorkspaceStore store;
  final AgentRunner runner;
  Timer? _timer;
  bool _ticking = false;
  bool _stopped = false;
  Completer<void>? _tickFinished;
  final Set<Future<void>> _work = {};

  void start() => _timer = Timer.periodic(
    const Duration(seconds: 15),
    (_) => unawaited(tick()),
  );
  void stop() {
    _stopped = true;
    _timer?.cancel();
  }

  Future<void> settle() async {
    await _tickFinished?.future;
    await Future.wait(_work.toList());
  }

  Future<void> tick() async {
    if (_ticking || _stopped) return;
    _ticking = true;
    _tickFinished = Completer<void>();
    try {
      for (final owner in store.owners.toList()) {
        final state = await store.read(owner);
        if (state['settings']['paused'] == true) continue;
        for (final task in records(state['schedules'])) {
          if (_stopped) return;
          if (task['status'] != 'scheduled') continue;
          if (DateTime.parse(task['nextRunAt']).isAfter(DateTime.now())) {
            continue;
          }
          if (runner.isRunning(owner, task['threadId'])) continue;
          final thread = recordById(state, 'threads', task['threadId']);
          if (records(
            thread['approvals'],
          ).any((a) => a['status'] == 'pending')) {
            continue;
          }
          final claimed = await store.change(owner, (workspace) {
            final current = recordById(workspace, 'schedules', task['id']);
            if (_stopped ||
                current['status'] != 'scheduled' ||
                workspace['settings']['paused'] == true) {
              return false;
            }
            current['status'] = 'running';
            (current['runs'] as List).add({
              'id': newId(),
              'startedAt': now(),
              'status': 'running',
            });
            return true;
          });
          if (claimed) {
            final execution = _execute(owner, task);
            _work.add(execution);
            unawaited(execution.whenComplete(() => _work.remove(execution)));
          }
        }
      }
    } finally {
      _ticking = false;
      _tickFinished?.complete();
    }
  }

  Future<void> _execute(String owner, Json task) async {
    String? error;
    try {
      if (_stopped) throw const CopilotFailure('Service stopped.', 499);
      await runner.run(
        owner,
        task['threadId'],
        prompt: task['prompt'],
        emit: (event) {
          if (event['type'] == 'error') error = textOf(event, 'message');
        },
      );
    } catch (failure) {
      error = failure is CopilotFailure ? failure.message : 'Run interrupted.';
    }
    await store.change(owner, (state) {
      final current = recordById(state, 'schedules', task['id']);
      final run = (current['runs'] as List).last as Json;
      run.addAll({
        'finishedAt': now(),
        'status': error == null ? 'completed' : 'failed',
        'error': error,
      });
      final interval = current['intervalMinutes'] as int;
      current['status'] = error != null
          ? 'failed'
          : interval > 0
          ? 'scheduled'
          : 'completed';
      if (interval > 0 && error == null) {
        current['nextRunAt'] = DateTime.now()
            .toUtc()
            .add(Duration(minutes: interval))
            .toIso8601String();
      }
    });
  }
}
