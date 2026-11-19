import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/ads/ad_config.dart';
import 'package:alphajournal/core/ads/ad_scope.dart';
import 'package:alphajournal/core/ads/ad_slot.dart';
import 'package:alphajournal/core/ads/promotion_preview.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/privacy/consent_preferences.dart';
import 'package:alphajournal/main_ads_preview.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets(
      'ad preview fits ${width.toInt()}px and paid mode removes every container',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          UiApp(
            theme: UiTheme.dark(),
            builder: (_) => const MaterialApp(home: AdPlacementPreview()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Advertisement'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Show paid plan'));
        await tester.pumpAndSettle();
        expect(find.text('Advertisement'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'feed containers fill their column at mobile and desktop widths',
    (tester) async {
      for (final width in [280.0, 390.0, 664.0, 960.0]) {
        for (final placement in [
          AdPlacement.feedInline,
          AdPlacement.feedFooter,
        ]) {
          await tester.pumpWidget(
            UiApp(
              theme: UiTheme.dark(),
              builder: (_) => MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: width,
                      child: AdSenseScope(
                        eligible: true,
                        config: const AdConfig(preview: true),
                        child: AdSlot(placement: placement),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final box = find.descendant(
            of: find.byType(AdSlot),
            matching: find.byType(UiCard),
          );
          // The test viewport is 800px wide, so wider columns are constrained.
          expect(tester.getSize(box).width, width.clamp(0, 800));
          expect(tester.getSize(box).height, 250);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('private-screen promotion spaces disappear outside preview', (
    tester,
  ) async {
    for (final enabled in [true, false]) {
      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (_) => MaterialApp(
            home: AdSenseScope(
              key: ValueKey(enabled),
              eligible: false,
              config: AdConfig(preview: enabled),
              child: const PromotionPreview(surface: 'Messages'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Messages promotion space'),
        enabled ? findsOneWidget : findsNothing,
      );
      expect(find.byType(AdSlot), findsNothing);
    }
  });
  testWidgets('development preview can show admin slots on public surfaces', (
    tester,
  ) async {
    final consent = ConsentController();
    addTearDown(consent.dispose);
    Widget preview(bool publicSurface) => UiApp(
      theme: UiTheme.dark(),
      builder: (_) => MaterialApp(
        home: AdSenseScope(
          consent: consent,
          eligible: false,
          previewEligible: publicSurface,
          config: const AdConfig(preview: true),
          child: const AdSlot(placement: AdPlacement.feedInline),
        ),
      ),
    );
    await tester.pumpWidget(preview(true));
    await tester.pumpAndSettle();
    expect(find.text('Advertisement'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(preview(false));
    await tester.pumpAndSettle();
    expect(find.text('Advertisement'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview eligibility never overrides live account eligibility', (
    tester,
  ) async {
    final consent = ConsentController();
    addTearDown(consent.dispose);
    AdSenseState? state;
    await tester.pumpWidget(
      MaterialApp(
        home: AdSenseScope(
          consent: consent,
          eligible: false,
          previewEligible: true,
          config: const AdConfig(enabled: true),
          child: Builder(
            builder: (context) {
              state = AdSenseScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(state, isNotNull);
    expect(state!.eligible, isFalse);
    expect(state!.shows(AdPlacement.feedInline), isFalse);
  });

  testWidgets('private content and missing scope never render a slot', (
    tester,
  ) async {
    final consent = ConsentController();
    addTearDown(consent.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AdSenseScope(
          consent: consent,
          eligible: true,
          config: const AdConfig(preview: true),
          child: const AdSlot(
            placement: AdPlacement.feedInline,
            contentReady: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Advertisement'), findsNothing);
    await tester.pumpWidget(
      const MaterialApp(home: AdSlot(placement: AdPlacement.feedInline)),
    );
    expect(find.text('Advertisement'), findsNothing);
  });
}
