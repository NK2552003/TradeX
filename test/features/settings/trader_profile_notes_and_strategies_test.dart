import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

Widget _wrap(Widget child, {Size size = const Size(1280, 900)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TraderProfilePreviewPage Notes & Strategies Integration', () {
    testWidgets(
      'shows Strategies and Notes tabs, and updates private notes for current user',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        final now = DateTime.now();

        // 1. Create a private note
        final testNote = AppNote(
          id: 'test-note-profile-1',
          title: 'Breakout Playbook Review',
          content: 'Key levels for Bank Nifty tomorrow morning.',
          isPublic: false,
          createdAt: now,
          updatedAt: now,
        );
        await NotesRepositoryScope.repository.create(testNote);

        // 2. Create a strategy
        final testStrategy = AppStrategy(
          id: 'test-strat-profile-1',
          name: 'Opening Range Breakout',
          content: 'Trade the first 15m breakout with volume confirmation.',
          status: AppStrategyStatus.live,
          createdAt: now,
          updatedAt: now,
          isPublic: false,
        );
        await StrategiesRepositoryScope.repository.create(testStrategy);

        const author = CommunityAuthor(
          id: 'author-test-123',
          displayName: 'Test Trader',
          handle: '@testtrader',
          userRole: UserRole.customer,
        );

        await tester.pumpWidget(
          _wrap(
            const TraderProfilePreviewPage(
              displayName: 'Test Trader',
              handle: '@testtrader',
              userRole: UserRole.customer,
              author: author,
              isCurrentUser: true,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 3. Verify tabs exist: Posts, Journal, Strategies, Notes
        expect(find.text('Posts'), findsOneWidget);
        expect(find.text('Journal'), findsOneWidget);
        expect(find.text('Strategies'), findsOneWidget);
        expect(find.text('Notes'), findsOneWidget);

        // 4. Tap on Notes tab and verify note shows up
        await tester.tap(find.text('Notes'));
        await tester.pumpAndSettle();

        expect(find.text('Breakout Playbook Review'), findsOneWidget);
        expect(find.text('PRIVATE NOTE'), findsOneWidget);

        // 5. Tap on Strategies tab and verify strategy shows up
        await tester.tap(find.text('Strategies'));
        await tester.pumpAndSettle();

        expect(find.text('Opening Range Breakout'), findsOneWidget);
        expect(find.byType(PlaybookCard), findsAtLeastNWidgets(1));
      },
    );
  });
}
