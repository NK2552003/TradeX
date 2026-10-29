import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
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

    testWidgets(
      'shows owner-specific journal labels and badges when isCurrentUser is true',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        final now = DateTime.now();

        // Create a private trade
        final testTrade = AppTrade(
          id: 'test-trade-profile-1',
          userId: 'author-test-123',
          ticker: 'RELIANCE',
          side: AppSide.long,
          entry: 2500,
          exit: 2550,
          size: 50,
          pnl: 2500,
          pnlPercent: 2.0,
          rMultiple: 2.5,
          outcome: AppOutcome.win,
          openedAt: now,
          closedAt: now.add(const Duration(hours: 1)),
          isPublic: false,
          notes: 'Tested 200 EMA breakout.',
        );
        await JournalRepositoryScope.repository.create(testTrade);

        const author = CommunityAuthor(
          id: 'author-test-123',
          displayName: 'Test Trader',
          handle: '@testtrader',
          userRole: UserRole.customer,
        );

        // 1. View as current user (Owner mode)
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

        // Switch to Journal tab
        await tester.tap(find.text('Journal'));
        await tester.pumpAndSettle();

        // Verify owner labels are shown
        expect(find.text('Personal Trading Execution Journal'), findsOneWidget);
        expect(find.text('ALL EXECUTIONS (OWNER)'), findsOneWidget);
        expect(find.text('Total Trades'), findsOneWidget);
        expect(
          find.text(
            'Showing all logged trades including both public verified logs and private executions.',
          ),
          findsOneWidget,
        );
        expect(find.text('PRIVATE'), findsOneWidget);
        expect(find.text('Verified Public Execution Log'), findsNothing);
        expect(find.text('AUDITED BROKER FEED'), findsNothing);
      },
    );

    testWidgets(
      'shows public journal audit labels when isCurrentUser is false',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        final now = DateTime.now();

        // Create a public trade belonging to author
        final publicTrade = AppTrade(
          id: 'test-trade-public-1',
          userId: 'author-test-123',
          ticker: 'TCS',
          side: AppSide.long,
          entry: 3400,
          exit: 3450,
          size: 20,
          pnl: 1000,
          pnlPercent: 1.5,
          rMultiple: 1.8,
          outcome: AppOutcome.win,
          openedAt: now,
          closedAt: now.add(const Duration(hours: 2)),
          isPublic: true,
          notes: 'Public swing breakout.',
        );
        await JournalRepositoryScope.repository.create(publicTrade);

        const author = CommunityAuthor(
          id: 'author-test-123',
          displayName: 'Test Trader',
          handle: '@testtrader',
          userRole: UserRole.customer,
        );

        // 2. View as external user (!isCurrentUser)
        await tester.pumpWidget(
          _wrap(
            const TraderProfilePreviewPage(
              displayName: 'Test Trader',
              handle: '@testtrader',
              userRole: UserRole.customer,
              author: author,
              isCurrentUser: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Journal tab
        await tester.tap(find.text('Journal'));
        await tester.pumpAndSettle();

        // Verify public labels are shown
        expect(find.text('Verified Public Execution Log'), findsOneWidget);
        expect(find.text('AUDITED BROKER FEED'), findsOneWidget);
        expect(find.text('Public Trades'), findsOneWidget);
        expect(
          find.text(
            'Every trade shown below is cryptographically hashed against broker fill timestamps. Private personal executions remain confidential.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
