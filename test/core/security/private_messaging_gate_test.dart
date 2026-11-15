import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/security/private_messaging_gate.dart';
import 'package:tradex/features/auth/widgets/auth_carousel_panel.dart';

Widget _wrapGate(Widget child, {Size size = const Size(1280, 900)}) {
  return UiThemeScope(
    theme: UiTheme.dark(),
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivateMessagingGate', () {
    testWidgets(
      'shows loading state then first-time setup with desktop carousel and unlocks',
      (tester) async {
        final statusCompleter =
            Completer<({bool unlocked, bool hasIdentity})>();
        String? submittedPassphrase;

        await tester.pumpWidget(
          _wrapGate(
            PrivateMessagingGate(
              checkStatus: () => statusCompleter.future,
              unlockWithPassphrase: (passphrase) async {
                submittedPassphrase = passphrase;
              },
              onLogout: () {},
              builder: (_) => const Text('UNLOCKED_HOME'),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text('Checking your encrypted messaging identity…'),
          findsOneWidget,
        );
        expect(find.byType(AuthCarouselPanel), findsOneWidget);
        expect(find.text('Create encrypted identity'), findsNothing);

        statusCompleter.complete((unlocked: false, hasIdentity: false));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Secure private messaging'), findsOneWidget);
        expect(find.text('FIRST-TIME SETUP'), findsOneWidget);
        expect(
          find.textContaining('Recovery passphrase', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Confirm recovery passphrase',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(find.text('Create encrypted identity'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);

        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(2));

        await tester.enterText(fields.at(0), 'correct horse battery staple');
        await tester.enterText(fields.at(1), 'different passphrase value');
        await tester.pump();

        expect(find.text('Passphrases do not match'), findsOneWidget);

        await tester.enterText(fields.at(1), 'correct horse battery staple');
        await tester.pump();

        await tester.ensureVisible(find.text('Create encrypted identity'));
        await tester.tap(find.text('Create encrypted identity'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(submittedPassphrase, 'correct horse battery staple');
        expect(find.text('UNLOCKED_HOME'), findsOneWidget);
      },
    );

    testWidgets('shows returning-device unlock mode when identity exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapGate(
          PrivateMessagingGate(
            checkStatus: () async => (unlocked: false, hasIdentity: true),
            unlockWithPassphrase: (_) async {},
            builder: (_) => const Text('UNLOCKED_HOME'),
          ),
          size: const Size(430, 844),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AuthCarouselPanel), findsNothing);
      expect(find.text('Unlock private messages'), findsOneWidget);
      expect(find.text('DEVICE UNLOCK'), findsOneWidget);
      expect(
        find.textContaining(
          'Confirm recovery passphrase',
          findRichText: true,
        ),
        findsNothing,
      );
      expect(find.text('Unlock history'), findsOneWidget);
    });

    testWidgets(
      'hides creation form on connection failure and retries cleanly',
      (tester) async {
        int attempts = 0;

        await tester.pumpWidget(
          _wrapGate(
            PrivateMessagingGate(
              checkStatus: () async {
                attempts++;
                if (attempts == 1) {
                  throw StateError('Network unreachable');
                }
                return (unlocked: true, hasIdentity: true);
              },
              onLogout: () {},
              builder: (_) => const Text('UNLOCKED_HOME'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Encrypted storage unavailable'), findsOneWidget);
        expect(find.text('Unable to continue'), findsOneWidget);
        expect(find.text('Network unreachable'), findsOneWidget);
        expect(find.text('Create encrypted identity'), findsNothing);
        expect(
          find.textContaining(
            'Confirm recovery passphrase',
            findRichText: true,
          ),
          findsNothing,
        );
        expect(find.text('Retry connection'), findsOneWidget);

        await tester.ensureVisible(find.text('Retry connection'));
        await tester.tap(find.text('Retry connection'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(attempts, 2);
        expect(find.text('UNLOCKED_HOME'), findsOneWidget);
      },
    );
  });
}
