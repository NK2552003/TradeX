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
  String? prompt, mode, focus;
  List<Json> files = [];
  int sends = 0;
  @override
  Future<bool> sendPrompt(
    String prompt, {
    List<Json> attachments = const [],
    String mode = 'auto',
    String focus = 'all',
  }) async {
    this.prompt = prompt;
    this.mode = mode;
    this.focus = focus;
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

  testWidgets('browse and type trader commands without sending the draft', (
    tester,
  ) async {
    size(tester, 390);
    final controller = _RecordingController()..accept = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CopilotChatPane(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'size my portfolio');
    await tester.tap(find.text('Trader skills'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('/trader-budget'));
    await tester.tap(find.text('/trader-budget'));
    await tester.pumpAndSettle();
    expect(find.text('/trader-budget size my portfolio'), findsOneWidget);
    expect(controller.sends, 0);
    await tester.enterText(find.byType(TextField), '/ris');
    await tester.pumpAndSettle();
    await tester.tap(find.text('/trader-risk'));
    await tester.pumpAndSettle();
    expect(find.text('/trader-risk '), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.prompt, '/trader-risk');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

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
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is UiDropdownMenu && w.semanticLabel == 'Search focus',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finance'));
      await tester.pumpAndSettle();
      controller.accept = true;
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is UiButton && w.label == 'Send message',
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.mode, 'research');
      expect(controller.focus, 'finance');
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

  testWidgets('pressing Enter clears input immediately before async completion', (
    tester,
  ) async {
    size(tester, 768);
    final controller = _RecordingController()..accept = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CopilotChatPane(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    final textFieldFinder = find.byType(TextField);
    await tester.tap(textFieldFinder);
    await tester.enterText(textFieldFinder, 'What is the NVDA price today?');
    await tester.pump();
    final textController = tester.widget<TextField>(textFieldFinder).controller!;
    expect(textController.text, 'What is the NVDA price today?');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(textController.text, isEmpty);
    expect(controller.sends, 1);
    expect(controller.prompt, 'What is the NVDA price today?');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'voice button on composer card starts natural-language voice assistant and processes spoken turns',
    (tester) async {
      size(tester, 1024);
      final controller = _RecordingController()..accept = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CopilotScreen(repository: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Voice button is visible right on the AI Composer card and matches Send button size & alignment
      final voiceBtn = find.byKey(
        const ValueKey('copilot-composer-voice-button'),
      );
      final sendBtn = find.byWidgetPredicate(
        (w) => w is UiButton && w.label == 'Send message',
      );
      expect(voiceBtn, findsOneWidget);
      expect(sendBtn, findsOneWidget);
      expect(
        tester.getSize(voiceBtn).height,
        closeTo(tester.getSize(sendBtn).height, 0.5),
      );
      expect(
        tester.getCenter(voiceBtn).dy,
        closeTo(tester.getCenter(sendBtn).dy, 0.5),
      );

      // Tap Voice button on composer card to launch Live Natural-Language Voice Panel
      await tester.tap(voiceBtn);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('copilot-voice-panel')),
        findsOneWidget,
      );
      expect(find.text('Listening'), findsOneWidget);

      // Verify no bottom overflow even if an error callout is shown while Voice Panel is open on a short viewport
      tester.view.physicalSize = const Size(1024, 560);
      controller.error = 'Temporary network warning';
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      controller.notifyListeners();
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1024, 900);
      await tester.pump();

      // Tap a natural-language voice prompt chip inside the Voice Panel
      await tester.tap(find.text('Summarize my notes & journal'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 2));

      expect(controller.sends, 1);
      expect(controller.prompt, 'Summarize my notes & journal');
      expect(tester.takeException(), isNull);

      // End call
      await tester.tap(find.text('End call'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('copilot-voice-panel')), findsNothing);
      expect(controller.workspace.calls, isNotEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'CopilotFeatureConnector bridges Notes, Journal, Strategies, Community, and Watchlists',
    (tester) async {
      size(tester, 1280);
      final controller = _RecordingController()..accept = true;

      // 1. Save an AI Copilot response to Notes, Journal, Strategy, and Community
      final noteRes = await CopilotFeatureConnector.saveAsNote(
        body: '## \$NVDA Breakout Analysis\nStrong institutional volume above \$135.',
        title: 'NVDA Breakout Research',
      );
      expect(noteRes.note.title, 'NVDA Breakout Research');
      expect(noteRes.note.linkedTickers, contains('NVDA'));

      final tradeRes = await CopilotFeatureConnector.logAsJournalTrade(
        body: 'Executed \$NVDA long breakout with 2.4R reward.',
        ticker: 'NVDA',
        entry: 132.0,
        exit: 139.5,
        pnl: 750.0,
      );
      expect(tradeRes.trade.ticker, 'NVDA');
      expect(tradeRes.trade.pnl, 750.0);

      final stratRes = await CopilotFeatureConnector.saveAsStrategy(
        body: '### Opening Range Momentum\nWait for 15m candle close above VWAP.',
        name: 'Opening Range VWAP Playbook',
      );
      expect(stratRes.strategy.name, 'Opening Range VWAP Playbook');

      final postRes = await CopilotFeatureConnector.publishCommunityPost(
        body: 'Shared \$NVDA desk thesis from AI Copilot.',
        title: 'NVDA Desk Thesis',
      );
      expect(postRes.post.postTitle, 'NVDA Desk Thesis');

      // 2. Verify fetchConnectableItems returns connected items across features
      final items = await CopilotFeatureConnector.fetchConnectableItems();
      expect(items, isNotEmpty);
      expect(
        items.any((i) => i.category == CopilotFeatureCategory.notes),
        isTrue,
      );
      expect(
        items.any((i) => i.category == CopilotFeatureCategory.journal),
        isTrue,
      );
      expect(
        items.any((i) => i.category == CopilotFeatureCategory.strategies),
        isTrue,
      );
      expect(
        items.any((i) => i.category == CopilotFeatureCategory.community),
        isTrue,
      );

      // 3. Verify natural-language connected workspace reply includes KPI & table
      final reply =
          await CopilotFeatureConnector.buildConnectedNaturalLanguageReply(
            'Summarize my notes, journal trades, strategies, and community posts',
            controller,
          );
      expect(reply, contains('```kpi'));
      expect(reply, contains('Trade Journal & Execution Review'));

      controller.dispose();
    },
  );
}
