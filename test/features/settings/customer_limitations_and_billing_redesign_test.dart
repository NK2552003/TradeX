import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:alphajournal/features/settings/models/billing_models.dart';
import 'package:alphajournal/features/settings/presentation/pages/trader/billing_settings_page.dart';

class _FakeBillingSettingsRepository implements BillingSettingsRepository {
  _FakeBillingSettingsRepository();

  @override
  Future<SubscriptionSummary> getSubscription() async {
    return SubscriptionSummary(
      tier: AppTier.free,
      status: 'active',
      billingCycle: 'monthly',
      renewedAt: DateTime(2026, 1, 1),
      expiresAt: DateTime(2026, 12, 31),
      monthlyAmount: 0,
      annualMonthsBilled: 12,
      usage: const <String, dynamic>{
        'notes': 1,
        'trades_this_month': 2,
        'live_playbooks': 0,
        'ai_tokens': 3,
        'seats': 1,
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CustomerLimitationsBanner & BillingSettingsPage Redesign', () {
    testWidgets(
      'CustomerLimitationsBanner renders UiDataPanel and UiStatStrip with 4 stats',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        AppSession.instance.tier.value = AppTier.free;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: CustomerLimitationsBanner(
                  noteCount: 1,
                  tradeCount: 4,
                  liveStrategyCount: 0,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should render UiDataPanel and UiStatStrip
        expect(find.byType(UiDataPanel), findsOneWidget);
        expect(find.byType(UiStatStrip), findsOneWidget);

        // Verify header title
        expect(
          find.text('CUSTOMER PLAN & WORKSPACE ALLOWANCES'),
          findsOneWidget,
        );

        // Verify all 8 quota metric cards are present
        expect(find.text('RESEARCH NOTES'), findsOneWidget);
        expect(find.text('JOURNAL TRADES'), findsOneWidget);
        expect(find.text('LIVE PLAYBOOKS'), findsOneWidget);
        expect(find.text('AI COPILOT QUERIES'), findsOneWidget);
        expect(find.text('WATCHLISTS'), findsOneWidget);
        expect(find.text('PRICE ALERTS'), findsOneWidget);
        expect(find.text('COMMUNITY POSTS / DAY'), findsOneWidget);
        expect(find.text('COMMENTS / DAY'), findsOneWidget);

        // Feature capability cards are omitted by default (e.g. on Workspace)
        expect(find.text('INCLUDED IN FREE'), findsNothing);
        expect(find.text('UNLOCK WITH UPGRADE'), findsNothing);
        expect(find.textContaining('PDF & CSV Exports'), findsNothing);
        expect(find.textContaining('Advanced Backtest'), findsNothing);

        // Verify upgrade plan button is present
        expect(find.widgetWithText(UiButton, 'Upgrade Plan'), findsOneWidget);
        final CustomerTierQuota freeQuota = CustomerTierQuota.forTier(
          AppTier.free,
        );
        final Finder planBadge = find.byWidgetPredicate(
          (Widget widget) =>
              widget is UiBadge &&
              widget.label ==
                  '${freeQuota.planName} Tier · ${freeQuota.priceLabel}',
        );
        expect(planBadge, findsOneWidget);
        final Rect panelRect = tester.getRect(find.byType(UiDataPanel));
        final Rect upgradeRect = tester.getRect(
          find.widgetWithText(UiButton, 'Upgrade Plan'),
        );
        expect(panelRect.right - upgradeRect.right, lessThan(36));
      },
    );

    testWidgets(
      'BillingSettingsPage renders CustomerLimitationsBanner data panel and feature cards outside the panel',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _FakeBillingSettingsRepository();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: BillingSettingsPage(repository: repo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should render CustomerLimitationsBanner
        expect(find.byType(CustomerLimitationsBanner), findsOneWidget);
        expect(find.byType(UiDataPanel), findsOneWidget);
        expect(find.byType(UiStatStrip), findsOneWidget);

        // Verify metric labels
        expect(find.text('RESEARCH NOTES'), findsOneWidget);
        expect(find.text('JOURNAL TRADES'), findsOneWidget);
        expect(find.text('LIVE PLAYBOOKS'), findsOneWidget);
        expect(find.text('AI COPILOT QUERIES'), findsOneWidget);
        expect(find.text('WATCHLISTS'), findsOneWidget);
        expect(find.text('PRICE ALERTS'), findsOneWidget);
        expect(find.text('COMMUNITY POSTS / DAY'), findsOneWidget);
        expect(find.text('COMMENTS / DAY'), findsOneWidget);

        // Verify feature cards are displayed on settings_billing and sit outside UiDataPanel
        expect(find.text('INCLUDED IN FREE'), findsOneWidget);
        expect(find.text('UNLOCK WITH UPGRADE'), findsOneWidget);
        expect(find.textContaining('PDF & CSV Exports'), findsOneWidget);
        expect(find.textContaining('Advanced Backtest'), findsOneWidget);

        final Rect panelRect = tester.getRect(find.byType(UiDataPanel));
        final Rect includedHeaderRect = tester.getRect(
          find.text('INCLUDED IN FREE'),
        );
        expect(includedHeaderRect.top, greaterThanOrEqualTo(panelRect.bottom));
      },
    );
  });
}
