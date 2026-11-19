import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/data/app_entitlements.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/core/widgets/app_scaffold.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';
import 'package:alphajournal/features/messages/presentation/messages_root_screen.dart';

void main() {
  test('paid destinations are denied on Free and allowed on Basic and Pro', () {
    for (final destination in <String>[
      'market',
      'market_news',
      'market_screeners',
      'messages',
    ]) {
      final entitlement = AppEntitlement.forDestination(destination);
      expect(entitlement, isNotNull);
      expect(entitlement!.allows(AppTier.free), isFalse);
      expect(entitlement.allows(AppTier.premium), isTrue);
      expect(entitlement.allows(AppTier.enterprise), isTrue);
    }
    expect(AppEntitlement.forDestination('community_feed'), isNull);
  });

  test('Free keeps core calculators and locks selected advanced tools', () {
    expect(
      AppEntitlement.calculatorAllowed('position_size', AppTier.free),
      isTrue,
    );
    expect(
      AppEntitlement.calculatorAllowed('black_scholes', AppTier.free),
      isFalse,
    );
    expect(
      AppEntitlement.calculatorAllowed('black_scholes', AppTier.premium),
      isTrue,
    );
  });

  test('disabled Messages repository cannot create paid conversations', () {
    final repository = MessagesRepository(autoConnect: false);
    addTearDown(repository.dispose);
    expect(repository.accessEnabled, isFalse);
    expect(
      () => repository.startConversation(
        const AppTrader(id: 'peer', handle: 'peer'),
      ),
      throwsStateError,
    );
    expect(repository.searchLiveTraders('peer'), completion(isEmpty));
  });

  testWidgets('Free blocks Messages before its screen is mounted', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSession.instance.changeTier(AppTier.free);
    addTearDown(() => AppSession.instance.changeTier(AppTier.premium));

    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark().toThemeData(),
        home: const AppScaffold(
          initialDestination: 'messages',
          userRole: UserRole.customer,
          subscriptionTier: AppTier.free,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MessagesRootScreen), findsNothing);
    expect(find.text('Messages · Basic or Pro'), findsOneWidget);
    expect(
      find.text(
        'Private Messages are included with AlphaJournal Basic and Pro.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
