import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/utils/share_actions.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';

class FakeShare extends SharePlatform {
  ShareResult result = const ShareResult('', ShareResultStatus.dismissed);
  ShareParams? params;
  bool fail = false;
  @override
  Future<ShareResult> share(ShareParams value) async {
    params = value;
    if (fail) throw PlatformException(code: 'unavailable');
    return result;
  }
}

class FakeLauncher extends UrlLauncherPlatform {
  @override
  get linkDelegate => null;
  bool opened = true;
  String? url;
  @override
  Future<bool> launchUrl(String value, LaunchOptions options) async {
    url = value;
    return opened;
  }
}

void main() {
  late BuildContext context;
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UiToastScope(
          child: Scaffold(
            body: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'blocked clipboard offers selectable text without false success',
    (tester) async {
      await mount(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            throw PlatformException(code: 'denied');
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      unawaited(
        ShareActions.copy(context, 'https://alphajournal.in/@dev_admin'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy link manually'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('Link copied'), findsNothing);
    },
  );

  testWidgets('external app launch does not depend on clipboard permission', (
    tester,
  ) async {
    final previous = UrlLauncherPlatform.instance;
    final launcher = FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await mount(tester);
    var writes = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          writes++;
          throw PlatformException(code: 'denied');
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
    expect(
      await ShareActions.external(
        context,
        uri: Uri.parse('https://wa.me/?text=test'),
        text: 'test',
        platform: 'WhatsApp',
      ),
      isTrue,
    );
    expect(launcher.url, 'https://wa.me/?text=test');
    expect(writes, 0);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'cancelled system share does not copy or report success; errors fall back',
    (tester) async {
      final previous = SharePlatform.instance;
      final platform = FakeShare();
      SharePlatform.instance = platform;
      addTearDown(() => SharePlatform.instance = previous);
      await mount(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      expect(await ShareActions.system(context, text: 'shared link'), isFalse);
      expect(copied, isNull);
      expect(platform.params!.sharePositionOrigin, isNotNull);
      expect(find.text('Shared'), findsNothing);
      platform.fail = true;
      expect(await ShareActions.system(context, text: 'shared link'), isTrue);
      expect(copied, 'shared link');
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'private record requires explicit publishing before link sharing',
    (tester) async {
      await mount(tester);
      var published = false;
      unawaited(
        ShareToConversationDialog.showShareMenu(
          context,
          reference: const AppLinkRef(
            kind: AppLinkKind.note,
            id: 'private-1',
            title: 'Private note',
          ),
          isPublic: false,
          onPublish: () => published = true,
          onExportPdf: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This record is private'), findsOneWidget);
      expect(find.text('Copy Public Link'), findsNothing);
      expect(find.text('Share via WhatsApp'), findsNothing);
      expect(find.text('Export as PDF'), findsOneWidget);
      expect(published, isFalse);
      await tester.tap(find.text('Publish to share'));
      await tester.pumpAndSettle();
      expect(published, isTrue);
    },
  );
}
