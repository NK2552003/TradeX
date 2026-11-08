import 'dart:async';
import 'dart:io';

import '../server/copilot/config.dart';
import '../server/copilot/server.dart';
import '../server/copilot/store.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help')) {
    stdout.writeln(
      'Usage: dart run bin/copilot.dart [path/to/.env]\nStarts the TradeX Dart copilot service.',
    );
    return;
  }
  final config = await CopilotConfig.load(arguments.firstOrNull ?? '.env');
  if (config.localOwner &&
      !['127.0.0.1', '::1', 'localhost'].contains(config.host)) {
    stderr.writeln(
      'COPILOT_LOCAL_OWNER is restricted to a loopback bind address.',
    );
    exitCode = 78;
    return;
  }
  final server = CopilotServer(
    config,
    WorkspaceStore(Directory(config.dataPath)),
  );
  await server.start();
  stdout.writeln('TradeX copilot listening on ${config.host}:${config.port}');
  final stopped = Completer<void>();
  final signals = [
    ProcessSignal.sigint.watch().listen((_) {
      if (!stopped.isCompleted) stopped.complete();
    }),
    if (!Platform.isWindows)
      ProcessSignal.sigterm.watch().listen((_) {
        if (!stopped.isCompleted) stopped.complete();
      }),
  ];
  await stopped.future;
  for (final subscription in signals) {
    await subscription.cancel();
  }
  await server.close();
}
