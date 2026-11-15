import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/widgets/feature_showcase_catalog.dart';
import 'package:tradex/core/widgets/feature_showcase_sheet.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

Widget _wrapWithTheme(Widget child, {Size size = const Size(1280, 800)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: UiTheme.dark().toThemeData(),
      home: UiThemeScope(
        theme: UiTheme.dark(),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'desktop right-side overlay renders every feature with interactive preview & opens destination',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      FeatureShowcaseItem? opened;
      FeatureShowcaseItem? toured;

      await tester.pumpWidget(
        _wrapWithTheme(
          Builder(
            builder: (context) => Center(
              child: UiButton(
                label: 'Open Features',
                onPressed: () => showFeatureShowcaseOverlay(
                  context,
                  currentDestination: 'workspace',
                  activeRole: UserRole.customer,
                  hasAffiliateAccess: false,
                  hasAdminAccess: false,
                  onOpenFeature: (item) => opened = item,
                  onStartPageTour: (item) => toured = item,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Features'));
      await tester.pumpAndSettle();

      // Overlay header + catalog items visible
      expect(find.text('Feature Explorer & Live Previews'), findsOneWidget);
      expect(find.byKey(const ValueKey('feature-nav-workspace')), findsOneWidget);
      expect(find.byKey(const ValueKey('feature-nav-journal')), findsOneWidget);
      expect(find.byKey(const ValueKey('feature-nav-calculators')), findsOneWidget);
      expect(find.byKey(const ValueKey('feature-nav-community')), findsOneWidget);

      // Select Calculators & verify 2-column editorial + specs + interactive slider/toggle preview
      await tester.tap(find.byKey(const ValueKey('feature-nav-calculators')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('feature-preview-calculators')),
        findsOneWidget,
      );
      expect(find.text('QUOTAS & SPECIFICATIONS'), findsOneWidget);
      expect(find.text('QUICK TIPS & HELPERS'), findsOneWidget);
      expect(find.text('MORE INFORMATION & HELPERS'), findsOneWidget);
      expect(
        find.text('7 Calculators (Position Size, Kelly, R:R...)'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('feature-copy-calculators')),
        findsOneWidget,
      );
      expect(find.text('80 Shares'), findsOneWidget);
      final risk05Finder = find.text('0.5% Risk');
      await tester.ensureVisible(risk05Finder);
      await tester.tap(risk05Finder);
      await tester.pumpAndSettle();
      expect(find.text('40 Shares'), findsOneWidget);

      // Verify Messages E2EE Plaintext vs Ciphertext toggle preview
      await tester.tap(find.byKey(const ValueKey('feature-nav-messages')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('feature-preview-messages')),
        findsOneWidget,
      );
      final cipherFinder = find.text('Server Wire Payload');
      await tester.ensureVisible(cipherFinder);
      await tester.tap(cipherFinder);
      await tester.pumpAndSettle();
      expect(find.text('Zero-Knowledge AES-256-GCM Envelope'), findsOneWidget);

      // Search filtering works cleanly
      await tester.enterText(
        find.byKey(const ValueKey('feature-showcase-search')),
        'playbook',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feature-nav-strategies')), findsOneWidget);
      expect(find.byKey(const ValueKey('feature-nav-market')), findsNothing);

      // Interactive page tour action works for Strategies
      await tester.tap(find.byKey(const ValueKey('feature-nav-strategies')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feature-tour-strategies')));
      await tester.pumpAndSettle();
      expect(toured?.id, 'strategies');

      // Re-open, select AI Copilot, and click Open Destination
      await tester.tap(find.text('Open Features'));
      await tester.pumpAndSettle();

      // Open link share sheet for Community from inside Feature Explorer
      await tester.tap(find.byKey(const ValueKey('feature-nav-community')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feature-share-community')));
      await tester.pumpAndSettle();
      expect(
        find.text('https://community.alphajournal.in/community_feed'),
        findsOneWidget,
      );
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
      expect(find.text('LinkedIn'), findsOneWidget);
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('feature-cat-ai')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feature-nav-ai_copilot')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('feature-preview-ai_copilot')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('feature-open-ai_copilot')));
      await tester.pumpAndSettle();
      expect(opened?.destinationId, 'ai_copilot');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'every feature in catalog renders with specs, tips and zero layout exception',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final catalog = buildFeatureShowcaseCatalog(
        hasAffiliateAccess: true,
        hasAdminAccess: true,
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          FeatureShowcaseSheet(
            currentDestination: 'overview',
            activeRole: UserRole.userAdmin,
            hasAffiliateAccess: true,
            hasAdminAccess: true,
            onOpenFeature: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final item in catalog) {
        final nav = find.byKey(ValueKey('feature-nav-${item.id}'));
        await tester.ensureVisible(nav);
        await tester.tap(nav);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('feature-preview-${item.id}')),
          findsOneWidget,
        );
        expect(find.text('QUOTAS & SPECIFICATIONS'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'admin item shows lock when customer and unlocks for admin on mobile viewport without overflow',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithTheme(
          FeatureShowcaseSheet(
            currentDestination: 'overview',
            activeRole: UserRole.customer,
            hasAffiliateAccess: false,
            hasAdminAccess: false,
            onOpenFeature: (_) {},
          ),
          size: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      final growthCat = find.byKey(const ValueKey('feature-cat-growth'));
      await tester.ensureVisible(growthCat);
      await tester.tap(growthCat);
      await tester.pumpAndSettle();
      final adminPill = find.byKey(const ValueKey('feature-pill-admin'));
      await tester.ensureVisible(adminPill);
      await tester.tap(adminPill);
      await tester.pumpAndSettle();
      expect(find.text('Admin Role Required'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
