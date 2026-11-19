import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/app-ui/theme/app_theme_controller.dart';

const captureWorkspaceUi = bool.fromEnvironment('CAPTURE_WORKSPACE_UI');
const workspaceCaptureKey = ValueKey('workspace-design-capture');

Future<void> loadWorkspaceFonts() async {
  for (final family in ['NotoSans', 'NotoSansMono']) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf'));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> settleWorkspace(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Future<void> pumpWorkspace(
  WidgetTester tester,
  Widget page, {
  double width = 1440,
  double paneWidth = 1440,
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = dark ? UiTheme.dark() : UiTheme.light();
  final controller = AppThemeController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.toThemeData(),
      builder: (context, child) => AppThemeScope(
        controller: controller,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(key: workspaceCaptureKey, child: child!),
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: paneWidth, child: page),
        ),
      ),
    ),
  );
  await settleWorkspace(tester);
  expect(tester.takeException(), isNull);
}

Future<void> captureWorkspace(WidgetTester tester, String name) async {
  if (!captureWorkspaceUi) return;
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(workspaceCaptureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('artifacts/admin-affiliate-design/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> scrollWorkspace(WidgetTester tester) async {
  // Visit all vertical scroll positions, including lazy content, without changing
  // horizontal tables. This catches lower-page cards missed by a one-drag check.
  final scrollables = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where(
        (state) => axisDirectionToAxis(state.axisDirection) == Axis.vertical,
      )
      .toList();
  for (final state in scrollables) {
    if (!state.mounted || !state.position.hasContentDimensions) continue;
    final position = state.position;
    for (double offset = 0; offset < position.maxScrollExtent; offset += 700) {
      position.jumpTo(offset.clamp(0, position.maxScrollExtent));
      await settleWorkspace(tester);
      expect(tester.takeException(), isNull);
    }
    position.jumpTo(position.maxScrollExtent);
    await settleWorkspace(tester);
    expect(tester.takeException(), isNull);
  }
}
