import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/ads/ad_config.dart';
import 'package:tradex/core/ads/ad_scope.dart';
import 'package:tradex/core/ads/ad_slot.dart';
import 'package:tradex/core/ads/promotion_preview.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/config/env_config.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_feed_list.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:tradex/features/notes/ui/note_preview_screen.dart';

void main() {
  setUpAll(() async {
    await EnvConfig.init();
  });

  setUp(() {
    CustomerDataPolicy.allowDemo = false;
    dotenv.testLoad(fileInput: 'ADSENSE_PREVIEW=true\nADSENSE_ENABLED=false');
  });

  Widget themed(Widget child) => UiApp(
    theme: UiTheme.dark(),
    builder: (_) => MaterialApp(home: child),
  );

  Widget preview(Widget child, {bool enabled = true}) => themed(
    Scaffold(
      body: AdSenseScope(
        key: ValueKey(enabled),
        eligible: false,
        previewEligible: true,
        config: AdConfig(preview: enabled),
        child: child,
      ),
    ),
  );

  Finder labelFor(AdPlacement placement) => find.descendant(
    of: find.byWidgetPredicate((w) => w is AdSlot && w.placement == placement),
    matching: find.text('Advertisement'),
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets('normal app shows empty-feed previews at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Use the same shell and environment configuration as main.dart, with
      // no confirmed account and no demo posts to satisfy live eligibility.
      await tester.pumpWidget(
        themed(const AppScaffold(initialDestination: 'community_feed')),
      );
      await tester.pumpAndSettle();
      expect(labelFor(AdPlacement.feedInline), findsOneWidget);
      if (width > 905) {
        expect(labelFor(AdPlacement.communityRail), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final count in [1, 5, 10, 16]) {
    testWidgets('$count pending posts still show development placements', (
      tester,
    ) async {
      CommunityPost post(int index) => CommunityPost(
        id: 'preview-post-$index',
        author: const CommunityAuthor(
          id: 'preview-author',
          handle: 'preview-author',
          displayName: 'Preview author',
          userRole: UserRole.customer,
        ),
        body: 'A short post.',
        createdAt: DateTime(2026),
        moderationStatus: 'pending',
      );
      await tester.pumpWidget(
        preview(
          CommunityFeedList(
            posts: List.generate(count, post),
            showAdvertisements: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(CommunityFeedList),
            matching: find.byType(Scrollable),
          )
          .first;
      if (count < 5) {
        expect(labelFor(AdPlacement.feedInline), findsOneWidget);
      }
      for (var occurrence = 1; occurrence <= count ~/ 5; occurrence++) {
        final slot = find.byKey(ValueKey('feed-ad-$occurrence'));
        await tester.scrollUntilVisible(slot, 300, scrollable: scrollable);
        final ad = tester.widget<AdSlot>(slot);
        expect(ad.occurrence, occurrence);
        expect(
          ad.placement,
          occurrence.isOdd ? AdPlacement.feedInline : AdPlacement.feedFooter,
        );
        expect(
          find.descendant(of: slot, matching: find.text('Advertisement')),
          findsOneWidget,
        );
        final previousPost = find.byKey(
          ValueKey('preview-post-${occurrence * 5 - 1}'),
        );
        expect(
          tester.getTopLeft(slot).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(previousPost).dy),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty feed stays ad-free with preview off or placements off', (
    tester,
  ) async {
    for (final enabled in [false, true]) {
      await tester.pumpWidget(
        preview(
          CommunityFeedList(posts: const [], showAdvertisements: !enabled),
          enabled: enabled,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Advertisement'), findsNothing);
    }
  });

  for (final destination in ['messages', 'ai_copilot', 'workspace']) {
    testWidgets('$destination has only a non-Google development space', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(AppScaffold(initialDestination: destination)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PromotionPreview), findsOneWidget);
      expect(find.text('Preview only · non-Google placement'), findsOneWidget);
      expect(find.byType(AdSlot), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('short article shows its footer placeholder', (tester) async {
    final article = MarketArticle.fromJson({
      'title': 'Market update',
      'summary': 'A short third-party summary.',
      'publisher': 'Example publisher',
    });
    await tester.pumpWidget(
      preview(
        SingleChildScrollView(
          child: MarketArticleView(
            article: article,
            snapshot: const MarketSnapshot(instruments: [], articles: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(labelFor(AdPlacement.articleFooter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final isPublic in [true, false]) {
    testWidgets('${isPublic ? "public" : "private"} short note preview', (
      tester,
    ) async {
      final note = AppNote(
        id: 'preview-note-$isPublic',
        title: 'Short note',
        content: 'A short note body.',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        isPublic: isPublic,
      );
      await tester.pumpWidget(
        preview(
          NotePreviewScreen(
            note: note,
            onClose: () {},
            onEdit: () {},
            canEdit: false,
            isPublicContext: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        labelFor(AdPlacement.publicNoteFooter),
        isPublic ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
