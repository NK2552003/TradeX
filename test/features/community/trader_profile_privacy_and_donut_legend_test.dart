import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_profile_view.dart';
import 'package:tradex/features/market_data/presentation/market_visuals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UiDonutChart default legend tests', () {
    testWidgets('UiDonutChart does not render dot percentages by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UiDonutChart(
              size: 160,
              centerLabel: '15311',
              slices: const [
                UiDonutSlice(label: 'US', value: 12700),
                UiDonutSlice(label: 'IN', value: 2611),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Center label is shown
      expect(find.text('15311'), findsOneWidget);

      // Percentage dots from the built-in legend are NOT shown by default
      expect(find.text('83.0%'), findsNothing);
      expect(find.text('17.0%'), findsNothing);
      expect(find.text('82.9%'), findsNothing);
      expect(find.text('17.1%'), findsNothing);
    });

    testWidgets('MarketDistributionCard renders custom bar list without redundant dot percentages', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarketDistributionCard(
              title: 'Market coverage',
              subtitle: 'Quoted instruments by market',
              values: {'US': 12700, 'IN': 2611},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card title and subtitle are present
      expect(find.text('Market coverage'), findsOneWidget);
      expect(find.text('Quoted instruments by market'), findsOneWidget);

      // Custom UiBarList is present with labels
      expect(find.byType(UiBarList), findsOneWidget);
      expect(find.text('US'), findsOneWidget);
      expect(find.text('IN'), findsOneWidget);

      // Built-in legend percentages are disabled
      expect(find.textContaining('83.0%'), findsNothing);
      expect(find.textContaining('17.1%'), findsNothing);
    });
  });

  group('Trader Profile Activity Privacy Tests', () {
    late CommunityRepository repo;

    setUp(() {
      repo = CommunityRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    testWidgets('viewing another trader profile hides the Activity history tab', (
      WidgetTester tester,
    ) async {
      const otherTrader = CommunityAuthor(
        id: 'other_trader_uuid_123',
        handle: 'marketwizard',
        displayName: 'Market Wizard',
        userRole: UserRole.customer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityProfileView(
              author: otherTrader,
              repository: repo,
              isCurrentUser: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Spaces History tab is visible
      expect(find.text('Spaces History'), findsOneWidget);

      // Activity tab is HIDDEN from other users
      expect(find.text('Activity'), findsNothing);
    });

    testWidgets('viewing own profile shows the Activity tab', (
      WidgetTester tester,
    ) async {
      final myAuthor = repo.currentAuthor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityProfileView(
              author: myAuthor,
              repository: repo,
              isCurrentUser: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both Spaces History and Activity tabs are visible for own profile
      expect(find.text('Spaces History'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });

    test('fetchUserActivityHistory returns empty list when querying another user', () async {
      final otherUserId = 'foreign_user_id_456';
      final history = await repo.fetchUserActivityHistory(otherUserId);
      expect(history, isEmpty);
    });
  });
}
