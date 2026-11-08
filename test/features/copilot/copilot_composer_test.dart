import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/copilot/presentation/chat_pane.dart';

class _RecordingController extends CopilotController {
  _RecordingController() : super(autoLoad: false) {
    connected = true;
  }
  bool accept = false;
  String? prompt, mode;
  List<Json> files = [];
  int sends = 0;
  @override
  Future<bool> sendPrompt(
    String prompt, {
    List<Json> attachments = const [],
    String mode = 'auto',
  }) async {
    this.prompt = prompt;
    this.mode = mode;
    files = attachments;
    sends++;
    return accept;
  }
}

class _Picker extends FilePicker {
  List<PlatformFile> files = [];
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult(files);
}

void main() {
  void size(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('composer supports input, modes and shortcuts at $width', (
      tester,
    ) async {
      size(tester, width);
      final controller = _RecordingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CopilotChatPane(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      final profile = find.byWidgetPredicate(
        (w) => w is UiDropdownMenu && w.semanticLabel == 'Select a profile',
      );
      final surface = find.byKey(const ValueKey('copilot-composer-surface'));
      expect(
        tester.getRect(profile).right,
        closeTo(tester.getRect(surface).right, 1),
      );
      await tester.enterText(find.byType(TextField), 'Review my trade');
      await tester.pump();
      expect(find.text('15 chars / 3 words'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(controller.sends, 1);
      expect(
        find.text('Review my trade'),
        findsOneWidget,
        reason: 'Rejected sends preserve the draft',
      );
      if (width >= 470) {
        await tester.tap(find.text('Deep research'));
      } else {
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is UiDropdownMenu && w.semanticLabel == 'Research mode',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Deep research'));
      }
      await tester.pumpAndSettle();
      controller.accept = true;
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is UiButton && w.label == 'Send message',
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.mode, 'research');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets(
    'phone composer stays usable with large text and the keyboard open',
    (tester) async {
      size(tester, 320);
      tester.view.physicalSize = const Size(320, 720);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      FilePicker.platform = _Picker()
        ..files = [
          for (var i = 0; i < 4; i++)
            PlatformFile(
              name: 'notes-$i.md',
              size: 5,
              bytes: Uint8List.fromList(utf8.encode('Notes')),
            ),
        ];
      final controller = _RecordingController()..accept = true;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(body: CopilotScreen(repository: controller)),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'First line\nSecond line\nThird line\nFourth line\nFifth line',
      );
      await tester.tap(find.byTooltip('Attach files'));
      await tester.pumpAndSettle();
      final send = find.byWidgetPredicate(
        (w) => w is UiButton && w.label == 'Send message',
      );
      expect(tester.getRect(send).bottom, lessThanOrEqualTo(420));
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(controller.sends, 1);
      expect(controller.files, hasLength(4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('clipboard pastes at the selection and copies the full draft', (
    tester,
  ) async {
    size(tester, 768);
    String copied = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') return {'text': 'market'};
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final controller = _RecordingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CopilotChatPane(controller: controller)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Review my trade');
    final input = tester.widget<TextField>(find.byType(TextField)).controller!;
    input.selection = const TextSelection(baseOffset: 10, extentOffset: 15);
    final menu = find.byWidgetPredicate(
      (w) => w is UiDropdownMenu && w.semanticLabel == 'Composer actions',
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    expect(input.text, 'Review my market');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy draft'));
    await tester.pumpAndSettle();
    expect(copied, 'Review my market');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'attachments send without typed text and remain after a rejected send',
    (tester) async {
      size(tester, 768);
      final picker = _Picker()
        ..files = [
          PlatformFile(
            name: 'notes.md',
            size: 12,
            bytes: Uint8List.fromList(utf8.encode('Trading notes')),
          ),
        ];
      FilePicker.platform = picker;
      final controller = _RecordingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CopilotChatPane(controller: controller)),
        ),
      );
      await tester.tap(find.byTooltip('Attach files'));
      await tester.pumpAndSettle();
      expect(find.text('notes.md'), findsOneWidget);
      final send = find.byWidgetPredicate(
        (w) => w is UiButton && w.label == 'Send message',
      );
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(controller.prompt, 'Please review the attached files.');
      expect(controller.files.single['text'], contains('Trading notes'));
      expect(find.text('notes.md'), findsOneWidget);
      controller.accept = true;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('notes.md'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
