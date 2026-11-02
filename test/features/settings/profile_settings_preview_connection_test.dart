import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('Profile Settings to Profile Preview Connection Tests', () {
    testWidgets(
      'renders customer profile options including experience, trading style, and respects privacy toggles',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        await tester.pumpWidget(
          _wrap(
            const TraderProfilePreviewPage(
              displayName: 'Alex Market Pro',
              handle: 'alex_trader',
              userRole: UserRole.customer,
              bio: 'Systematic breakout trader specializing in NIFTY options.',
              location: 'Bangalore, India',
              website: 'https://alextrader.com',
              experienceLevel: 'Advanced (3-5 years)',
              tradingStyle: 'Day Trading (Intraday)',
              avgHoldDuration: '45 mins (Intraday)',
              primaryMarket: 'Index Futures & Options',
              topStrategy: 'VWAP Bounce & Retest',
              riskMantra: 'Risk 1% per setup, let runners run',
              publicStats: false,
              publicJournals: false,
              isCurrentUser: true,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Display name, handle, bio, location, website
        expect(find.text('Alex Market Pro'), findsAtLeastNWidgets(1));
        expect(find.text('@alex_trader'), findsAtLeastNWidgets(1));
        expect(
          find.text('Systematic breakout trader specializing in NIFTY options.'),
          findsOneWidget,
        );
        expect(find.text('Bangalore, India'), findsOneWidget);
        expect(find.text('https://alextrader.com'), findsOneWidget);

        // 2. Experience level and trading style are rendered
        expect(find.text('Advanced (3-5 years)'), findsOneWidget);
        expect(find.text('Day Trading (Intraday)'), findsAtLeastNWidgets(1));

        // 3. Trading focus fields
        expect(find.text('Avg Hold: 45 mins (Intraday)'), findsOneWidget);
        expect(find.text('Index Futures & Options'), findsAtLeastNWidgets(1));
        expect(find.text('Top: VWAP Bounce & Retest'), findsOneWidget);

        // 4. Privacy toggles: publicStats == false renders "Private"
        expect(find.text('Private'), findsAtLeastNWidgets(1));

        // 5. Switch to Journal tab and verify publicJournals == false renders private empty state
        await tester.tap(find.text('Journal'));
        await tester.pumpAndSettle();
        expect(find.text('Public Journal Disabled'), findsOneWidget);
      },
    );

    testWidgets(
      'renders desk admin clearance, division, supervised capital, and operational controls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        await tester.pumpWidget(
          _wrap(
            const TraderProfilePreviewPage(
              displayName: 'Root Supervisor',
              handle: 'root_admin',
              userRole: UserRole.userAdmin,
              bio: 'Head of Quantitative Execution & Desk Risk.',
              deskDivision: 'Quantitative Hedge Fund Desk',
              adminClearanceLevel: 'Level 5 Root Superadmin',
              adminDesignation: 'Chief Risk Officer',
              adminSupervisedCapital: '₹250.0 Cr',
              adminTerminalUrl: 'tradex.internal/root-alpha',
              adminKillswitchEnabled: true,
              adminPreTradeVaREnabled: true,
              adminAuditHashingEnabled: true,
              isCurrentUser: true,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Admin metadata
        expect(find.text('Root Supervisor'), findsAtLeastNWidgets(1));
        expect(find.text('Clearance: Level 5 Root Superadmin'), findsOneWidget);
        expect(find.text('Quantitative Hedge Fund Desk'), findsOneWidget);
        expect(find.text('Chief Risk Officer'), findsOneWidget);
        expect(find.text('Pool: ₹250.0 Cr'), findsOneWidget);
        expect(find.text('tradex.internal/root-alpha'), findsOneWidget);

        // 2. Command Center metrics reflecting admin state
        expect(find.text('Armed / Active'), findsOneWidget);
        expect(find.text('0.8 ms (VaR sub-ms)'), findsOneWidget);
        expect(find.text('₹250.0 Cr'), findsOneWidget);
        expect(find.text('SHA-256 Verified'), findsOneWidget);
      },
    );

    testWidgets(
      'renders affiliate partner channel, reach, niche, and settlement details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        await tester.pumpWidget(
          _wrap(
            const TraderProfilePreviewPage(
              displayName: 'Trade Mentor Partner',
              handle: 'trade_mentor',
              userRole: UserRole.affiliate,
              bio: 'Educating new market participants with live analysis.',
              referralCode: 'MENTOR-2026',
              channelHandle: '@mentortrades',
              niche: 'Options & Futures Strategies',
              audienceReach: '10,000 – 100,000 Traders',
              payoutMethod: 'UPI Instant Transfer',
              sampleLink: 'https://youtube.com/@mentortrades',
              phoneNumber: '+91 98765 00000',
              isCurrentUser: true,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Partner meta chips
        expect(find.text('Trade Mentor Partner'), findsAtLeastNWidgets(1));
        expect(find.text('@mentortrades'), findsAtLeastNWidgets(1));
        expect(find.text('Options & Futures Strategies'), findsAtLeastNWidgets(1));
        expect(find.text('Reach: 10,000 – 100,000 Traders'), findsOneWidget);
        expect(find.text('Payout: UPI Instant Transfer'), findsOneWidget);
        expect(find.text('https://youtube.com/@mentortrades'), findsAtLeastNWidgets(1));

        // 2. Switch to Community Perks tab
        await tester.tap(find.text('Community Perks'));
        await tester.pumpAndSettle();
        expect(find.text('Partner Verification & Settlement Rails'), findsOneWidget);
        expect(find.text('https://alphajournal.in/join/MENTOR-2026'), findsOneWidget);
      },
    );

    testWidgets(
      'hides follow and direct message buttons when viewing own profile, and displays them for others',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        // 1. Own profile (isCurrentUser = true)
        await tester.pumpWidget(
          _wrap(
            const TraderProfilePreviewPage(
              displayName: 'Self Trader',
              handle: 'self_trader',
              userRole: UserRole.customer,
              bio: 'Trading my own account.',
              isCurrentUser: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must display Share Profile icon button
        expect(find.byTooltip('Share Profile'), findsOneWidget);
        expect(find.byIcon(Icons.share_outlined), findsOneWidget);
        // Must NOT display Direct Message or Follow buttons
        expect(find.byTooltip('Direct Message'), findsNothing);
        expect(find.byIcon(Icons.mail_outline_rounded), findsNothing);
        expect(find.byIcon(Icons.person_add_alt_1_rounded), findsNothing);
        expect(find.byTooltip('Follow @self_trader'), findsNothing);

        // 2. Other trader profile (isCurrentUser = false)
        await tester.pumpWidget(
          _wrap(
            const TraderProfilePreviewPage(
              displayName: 'Other Trader',
              handle: 'other_trader',
              userRole: UserRole.customer,
              bio: 'Trading an external account.',
              isCurrentUser: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must display Share Profile icon button
        expect(find.byTooltip('Share Profile'), findsOneWidget);
        expect(find.byIcon(Icons.share_outlined), findsOneWidget);
        // Must display Direct Message and Follow buttons
        expect(find.byTooltip('Direct Message'), findsOneWidget);
        expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
        expect(find.byTooltip('Follow @other_trader'), findsOneWidget);
      },
    );
  });
}
