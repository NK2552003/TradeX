import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/widgets/app_scaffold.dart';

void main() {
  for (final (width, height, scale) in [
    (320.0, 844.0, 1.0),
    (390.0, 844.0, 1.0),
    (768.0, 844.0, 1.0),
    (390.0, 844.0, 1.5),
    (740.0, 320.0, 1.0),
  ]) {
    for (final destination in [
      'workspace',
      'notes',
      'journal',
      'strategies',
      'calculators',
      'community',
      'messages',
      'ai_copilot',
      'market',
      'settings',
    ]) {
      testWidgets('$destination fits $width × $height at text scale $scale', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          previousError?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousError);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: AppScaffold(initialDestination: destination),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
