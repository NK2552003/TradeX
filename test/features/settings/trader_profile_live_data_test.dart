import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

Widget _wrap(Widget child, {Size size = const Size(1280, 800)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TraderProfilePreviewPage Live & Clean Data Tests', () {
    testWidgets('prevents double @ handle and removes disclaimer callout', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final author = CommunityAuthor(
        id: 'usr_nk2552003',
        handle: '@nk2552003',
        displayName: 'Nitish Kumar',
        userRole: UserRole.customer,
        bio: 'Day trader focusing on price action and momentum.',
        location: 'India',
        website: 'https://github.com/nk2552003',
        avgHoldDuration: 'Intraday (15m - 2h)',
        primaryMarket: 'Nifty 50, Bank Nifty Options',
        tradingStyle: 'Price Action & Breakouts',
        riskMantra: 'Protect capital first',
        winRate: null,
      );

      await tester.pumpWidget(
        _wrap(
          TraderProfilePreviewPage(
            displayName: 'Nitish Kumar',
            handle: '@nk2552003',
            userRole: UserRole.customer,
            author: author,
            isCurrentUser: true,
            location: 'India',
            website: 'https://github.com/nk2552003',
            avgHoldDuration: 'Intraday (15m - 2h)',
            primaryMarket: 'Nifty 50, Bank Nifty Options',
            topStrategy: 'Price Action & Breakouts',
            riskMantra: 'Protect capital first',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Double @ is completely prevented
      expect(find.text('@@nk2552003'), findsNothing);
      expect(find.text('@nk2552003'), findsAtLeastNWidgets(1));

      // 2. Disclaimer callout is removed
      expect(find.text('Public profile preview'), findsNothing);
      expect(find.textContaining('This is how verified traders'), findsNothing);
      expect(find.byType(UiCallout), findsNothing);

      // 3. Live profile fields are rendered cleanly
      expect(find.text('Nitish Kumar'), findsAtLeastNWidgets(1));
      expect(find.text('India'), findsOneWidget);
      expect(find.text('https://github.com/nk2552003'), findsOneWidget);
      expect(find.text('Avg Hold: Intraday (15m - 2h)'), findsOneWidget);
      expect(
        find.text('Nifty 50, Bank Nifty Options'),
        findsAtLeastNWidgets(1),
      );

      // 4. Performance KPI strip renders live values without mock data
      expect(find.text('Intraday (15m - 2h)'), findsOneWidget);
      expect(find.text('Price Action & Breakouts'), findsAtLeastNWidgets(1));
      expect(find.text('Protect capital first'), findsOneWidget);
      // Win Rate displays '--' when no closed trades exist (NOT 0.0%)
      expect(find.text('--'), findsAtLeastNWidgets(1));

      // Zero fake mock numbers (like 12.4K or 148.2 Cr)
      expect(find.text('12.4K'), findsNothing);
      expect(find.text('₹148.2 Cr'), findsNothing);
    });

    testWidgets(
      'displays "Not Set" for unset fields instead of fake mock defaults',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        final emptyAuthor = CommunityAuthor(
          id: 'usr_new_trader',
          handle: 'new_trader',
          displayName: 'New Trader',
          userRole: UserRole.customer,
        );

        await tester.pumpWidget(
          _wrap(
            TraderProfilePreviewPage(
              displayName: 'New Trader',
              handle: 'new_trader',
              userRole: UserRole.customer,
              author: emptyAuthor,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Handle rendered with single @
        expect(find.text('@new_trader'), findsAtLeastNWidgets(1));
        expect(find.text('@@new_trader'), findsNothing);

        // Unset KPI pills cleanly display "Not Set"
        expect(find.text('Not Set'), findsAtLeastNWidgets(2));
        expect(find.text('--'), findsAtLeastNWidgets(1));

        // Zero hardcoded mock strings
        expect(find.text('Mumbai, Maharashtra'), findsNothing);
        expect(find.text('45 mins (Intraday)'), findsNothing);
        expect(find.text('Equities & Index Options'), findsNothing);
        expect(find.text('ORB Breakout'), findsNothing);
      },
    );
  });
}
