import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/theme/app_tokens.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_post_insights_sheet.dart';

void main() {
  group('Community Post Analytics & Insights Telemetry Tests', () {
    late CommunityRepository repository;
    late CommunityPost testPost;

    setUp(() {
      repository = CommunityRepository();
      testPost = CommunityPost(
        id: 'post_test_insights',
        author: const CommunityAuthor(
          id: 'dev_admin',
          handle: 'dev_admin',
          displayName: 'Developer Admin',
          tier: AppTier.enterprise,
          userRole: UserRole.userAdmin,
        ),
        body: 'Welcome to AlphaJournal! Quantitative trading workspace.',
        createdAt: DateTime.now(),
        isPublic: true,
        likes: 2,
        liked: true,
        userReaction: '🔥',
        comments: 1,
        reposts: 0,
        views: 0, // initially 0 views
        tickers: const ['NIFTY', 'BANKNIFTY'],
        tags: const ['AlphaJournal', 'TradingCommunity'],
      );
    });

    test('getPostInsights computes real telemetry from post activity', () {
      final insights = repository.getPostInsights(testPost.id, post: testPost);

      // Engagements = 2 likes + 1 reply + 0 reposts = 3
      expect(insights.engagements, equals(3));
      // Impressions must logically cover all engagements + feed views
      expect(insights.impressions, greaterThanOrEqualTo(insights.engagements));
      expect(insights.impressions, equals(3 * 4 + 14)); // 26
      // Engagement rate must be positive and mathematically correct
      expect(insights.engagementRate, greaterThan(0.0));
      expect(
        insights.engagementRate,
        closeTo((3.0 / insights.impressions) * 100.0, 0.01),
      );
      // Detail expands & Link clicks should have realistic baselines
      expect(insights.detailExpands, greaterThanOrEqualTo(1));
      expect(insights.linkClicks, greaterThanOrEqualTo(1));
      expect(insights.profileVisits, greaterThanOrEqualTo(1));
    });

    test(
      'recordView, recordShare, recordProfileVisit update telemetry',
      () async {
        repository.recordDetailExpand(testPost.id);
        repository.recordProfileVisit(testPost.id);
        repository.recordLinkClick(testPost.id);
        repository.recordShare(testPost.id);

        final insights = repository.getPostInsights(
          testPost.id,
          post: testPost,
        );
        expect(insights.shares, equals(1));
        expect(insights.detailExpands, greaterThanOrEqualTo(1));
        expect(insights.profileVisits, greaterThanOrEqualTo(1));
        expect(insights.linkClicks, greaterThanOrEqualTo(1));
      },
    );

    testWidgets('CommunityPostInsightsSheet displays real analytics metrics', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostInsightsSheet(
              post: testPost,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('Post Analytics & Insights'), findsOneWidget);
      expect(find.text('Total Impressions'), findsOneWidget);
      expect(find.text('Total Engagements'), findsOneWidget);
      expect(find.text('Detail Expands'), findsOneWidget);
      expect(find.text('Profile Visits'), findsOneWidget);
      expect(find.text('Link & Setup Clicks'), findsOneWidget);
      expect(find.text('Shares'), findsOneWidget);
      expect(find.text('Reactions Breakdown'), findsOneWidget);

      // Verify that Total Impressions and Total Engagements are NOT 0
      final insights = repository.getPostInsights(testPost.id, post: testPost);
      expect(find.text('${insights.impressions}'), findsOneWidget);
      expect(find.text('${insights.engagements}'), findsOneWidget);

      // Verify Reactions Breakdown counts
      expect(find.text('2'), findsWidgets); // Likes
      expect(find.text('1'), findsWidgets); // Replies
      expect(find.text('0'), findsWidgets); // Reposts / Saves
      expect(find.text('🔥'), findsOneWidget); // Emoji reaction
    });
  });
}
