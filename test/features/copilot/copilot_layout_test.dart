import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/copilot/data/copilot_api.dart';
import 'package:tradex/features/copilot/presentation/page_editor.dart';
import 'package:tradex/core/markdown_kit/markdown_editor_field.dart';

class MemoryCopilotApi extends CopilotApi {
  MemoryCopilotApi(this.state);
  Json state;
  bool failSave = false;
  @override
  Future<Json> getWorkspace() async => jsonDecode(jsonEncode(state)) as Json;
  @override
  Future<Json> action(Json body) async {
    if (failSave) {
      throw const CopilotApiException('This page changed elsewhere.', 409);
    }
    final page = records(
      state['pages'],
    ).firstWhere((p) => p['id'] == body['id']);
    page.addAll({...body, 'revision': (page['revision'] as int) + 1});
    state['pages'] = [page];
    return page;
  }
}

void main() {
  setUpAll(() async {
    final regular = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final mono = FontLoader('NotoSansMono')
      ..addFont(rootBundle.load('assets/fonts/NotoSansMono-Regular.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([regular.load(), mono.load(), icons.load()]);
  });
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets(
      'Copilot adapts at $width without extra desktop panes or overflow',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = CopilotController(autoLoad: false)..connected = true;
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: Scaffold(
              body: RepaintBoundary(
                key: captureKey,
                child: CopilotScreen(repository: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('What can I help with?'), findsOneWidget);
        expect(find.byType(UiThreePane), findsNothing);
        expect(
          find.byType(UiSplitPane),
          width >= 905 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('COPILOT_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '/tmp/tradex-copilot-${width.toInt()}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(
          find.text(width < 600 ? 'Library' : 'Workspace').first,
        );
        await tester.pumpAndSettle();
        expect(find.text('New conversation'), findsWidgets);
        if (const bool.fromEnvironment('COPILOT_CAPTURE')) {
          await capture(tester, captureKey, 'workspace-${width.toInt()}');
        }
        expect(tester.takeException(), isNull);
        if (width >= 905) {
          expect(
            tester.widget<UiSplitPane>(find.byType(UiSplitPane)).showDetail,
            isTrue,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  testWidgets(
    'Page editor autosaves changes and retains a conflicting local draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(768, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = initialWorkspace();
      final page = {
        'id': 'page-1',
        'title': 'Trade plan',
        'body': 'First draft',
        'spaceId': 'research',
        'revision': 1,
      };
      state['pages'] = [page];
      final api = MemoryCopilotApi(state);
      final controller = CopilotController(
        api: api,
        initialState: CopilotWorkspace.fromJson(state),
        autoLoad: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: CopilotPageEditor(
                controller: controller,
                page: WorkspacePage.fromJson(page),
                onClose: () {},
                onDiscuss: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final visual = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );
      visual.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        quill.ChangeSource.local,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Bold'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(controller.workspace.pages.single.body, contains('**First**'));
      await tester.tap(find.text('Markdown'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(RichMarkdownEditorField),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Updated plan');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(records(api.state['pages']).single['body'], 'Updated plan');
      api.failSave = true;
      await tester.enterText(field, 'Keep this local draft');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This page changed elsewhere.'),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('copilot.draft.local-owner.page-1'),
        contains('Keep this local draft'),
      );
      expect(records(api.state['pages']).single['body'], 'Updated plan');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      controller.dispose();
    },
  );
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/tmp/tradex-copilot-$name.png',
    ).writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}
