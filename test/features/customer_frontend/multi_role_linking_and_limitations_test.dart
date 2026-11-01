import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/data/workspace_attachment_service.dart';
import 'package:tradex/features/workspace/data/workspace_post_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSession.instance.setProfileMode(UserProfileMode.traderAffiliateAdmin);
    AppSession.instance.changeTier(AppTier.free);
  });

  group('Multi-Role Profile Modes & Dock/Sidebar Switching', () {
    test('computes correct UserProfileMode from user eligibility', () {
      expect(
        UserProfileMode.fromEligibility(
          baseRole: UserRole.customer,
          isApprovedAffiliate: false,
          isAdmin: false,
        ),
        UserProfileMode.traderOnly,
      );

      expect(
        UserProfileMode.fromEligibility(
          baseRole: UserRole.customer,
          isApprovedAffiliate: true,
          isAdmin: false,
        ),
        UserProfileMode.traderAffiliate,
      );

      expect(
        UserProfileMode.fromEligibility(
          baseRole: UserRole.customer,
          isApprovedAffiliate: false,
          isAdmin: true,
        ),
        UserProfileMode.traderAdmin,
      );

      expect(
        UserProfileMode.fromEligibility(
          baseRole: UserRole.customer,
          isApprovedAffiliate: true,
          isAdmin: true,
        ),
        UserProfileMode.traderAffiliateAdmin,
      );

      expect(
        UserProfileMode.fromEligibility(
          baseRole: UserRole.userAdmin,
          isApprovedAffiliate: false,
        ),
        UserProfileMode.traderAdmin,
      );

      expect(
        UserProfileMode.fromEligibility(
          baseRole: UserRole.userAdmin,
          isApprovedAffiliate: true,
        ),
        UserProfileMode.traderAffiliateAdmin,
      );
    });

    test('Trader Only mode exposes zero role switchers in navigation', () {
      AppSession.instance.setProfileMode(UserProfileMode.traderOnly);
      final config = RoleNavigationConfig.forRole(
        UserRole.customer,
        profileMode: UserProfileMode.traderOnly,
      );

      final ids = config.mobileMoreItems.map((e) => e.id).toSet();
      expect(ids.contains('switch_role_customer'), isFalse);
      expect(ids.contains('switch_role_affiliate'), isFalse);
      expect(ids.contains('switch_role_admin'), isFalse);
      expect(ids.contains('toggle_profile_mode'), isFalse);
      expect(config.allows('switch_role_affiliate'), isFalse);
      expect(config.allows('switch_role_admin'), isFalse);
    });

    test(
      'Trader + Affiliate mode exposes ONLY Trader and Affiliate role switchers',
      () {
        AppSession.instance.setProfileMode(UserProfileMode.traderAffiliate);
        final config = RoleNavigationConfig.forRole(
          UserRole.customer,
          profileMode: UserProfileMode.traderAffiliate,
        );

        final ids = config.mobileMoreItems.map((e) => e.id).toSet();
        expect(ids.contains('switch_role_customer'), isTrue);
        expect(ids.contains('switch_role_affiliate'), isTrue);
        expect(ids.contains('switch_role_admin'), isFalse);
        expect(ids.contains('toggle_profile_mode'), isFalse);
        expect(config.allows('switch_role_affiliate'), isTrue);
        expect(config.allows('switch_role_admin'), isFalse);
      },
    );

    test(
      'Trader + Admin mode exposes ONLY Trader and Admin role switchers',
      () {
        AppSession.instance.setProfileMode(UserProfileMode.traderAdmin);
        final config = RoleNavigationConfig.forRole(
          UserRole.customer,
          profileMode: UserProfileMode.traderAdmin,
        );

        final ids = config.mobileMoreItems.map((e) => e.id).toSet();
        expect(ids.contains('switch_role_customer'), isTrue);
        expect(ids.contains('switch_role_admin'), isTrue);
        expect(ids.contains('switch_role_affiliate'), isFalse);
        expect(ids.contains('toggle_profile_mode'), isFalse);
        expect(config.allows('switch_role_admin'), isTrue);
        expect(config.allows('switch_role_affiliate'), isFalse);
      },
    );

    test(
      'Trader + Affiliate + Admin mode exposes all three workspace switchers',
      () {
        AppSession.instance.setProfileMode(
          UserProfileMode.traderAffiliateAdmin,
        );
        final config = RoleNavigationConfig.forRole(
          UserRole.customer,
          profileMode: UserProfileMode.traderAffiliateAdmin,
        );

        final moreIds = config.mobileMoreItems.map((e) => e.id).toSet();
        final menuIds = config.userMenuItems.map((e) => e.id).toSet();
        expect(moreIds.contains('switch_role_customer'), isTrue);
        expect(moreIds.contains('switch_role_affiliate'), isTrue);
        expect(moreIds.contains('switch_role_admin'), isTrue);
        expect(menuIds.contains('switch_role_admin'), isTrue);
        expect(config.allows('switch_role_admin'), isTrue);
        expect(config.allows('switch_role_affiliate'), isTrue);
      },
    );

    test('Dev preview includes profile mode toggle when requested', () {
      final config = RoleNavigationConfig.forRole(
        UserRole.customer,
        profileMode: UserProfileMode.traderAffiliate,
        includeProfileModeToggle: true,
      );
      final ids = config.mobileMoreItems.map((e) => e.id).toSet();
      expect(ids.contains('toggle_profile_mode'), isTrue);
    });
  });

  group('Customer Deep Links & Shared Web Links', () {
    test('parses internal and shared alphajournal links', () {
      final noteRef = AppDeepLink.tryParseUrl(
        'https://alphajournal.in/p/notes/note_001',
      );
      expect(noteRef, isNotNull);
      expect(noteRef!.kind, AppLinkKind.note);
      expect(noteRef.id, 'note_001');

      final journalRef = AppDeepLink.tryParseUrl(
        'https://alphajournal.in/p/journal/trd_nifty50_0',
      );
      expect(journalRef, isNotNull);
      expect(journalRef!.kind, AppLinkKind.journal);
      expect(journalRef.id, 'trd_nifty50_0');

      final strategyRef = AppDeepLink.tryParseUrl(
        'https://alphajournal.in/p/strategies/stg_2',
      );
      expect(strategyRef, isNotNull);
      expect(strategyRef!.kind, AppLinkKind.strategy);
      expect(strategyRef.id, 'stg_2');

      final postRef = AppDeepLink.tryParseUrl(
        'https://alphajournal.in/post/post_a1',
      );
      expect(postRef, isNotNull);
      expect(postRef!.kind, AppLinkKind.communityPost);
      expect(postRef.id, 'post_a1');

      final schemeRef = AppDeepLink.tryParseUrl('tradex://ticker/NIFTY50');
      expect(schemeRef, isNotNull);
      expect(schemeRef!.kind, AppLinkKind.ticker);
      expect(schemeRef.id, 'NIFTY50');

      expect(
        CustomerRoute.parse(Uri.parse('https://app.alphajournal.in/')).destination,
        'workspace',
      );
      expect(
        CustomerRoute.parse(Uri.parse('https://community.alphajournal.in/')).destination,
        'community_feed',
      );
      expect(
        CustomerRoute.parse(Uri.parse('https://admin.alphajournal.in/')).destination,
        'admin_console',
      );
      expect(
        CustomerRoute.parse(Uri.parse('https://affiliate.alphajournal.in/')).destination,
        'affiliate_application',
      );
      expect(
        CustomerRoute.parse(Uri.parse('https://app.alphagournal.in/')).destination,
        'workspace',
      );
    });

    test(
      'WorkspacePostService links match real DemoDataSource & CommunityRepository IDs',
      () async {
        final postService = WorkspacePostService.instance;
        final communityRepo = CommunityRepository();
        addTearDown(communityRepo.dispose);

        expect(postService.isLinked(AppLinkKind.note, 'note_001'), isTrue);
        expect(postService.isLinked(AppLinkKind.strategy, 'stg_2'), isTrue);
        expect(
          postService.isLinked(AppLinkKind.journal, 'trd_nifty50_0'),
          isTrue,
        );

        final link = postService.getPrimaryLink(AppLinkKind.note, 'note_001');
        expect(link, isNotNull);
        final resolvedPost = communityRepo.loadPostById(link!.postId);
        expect(resolvedPost, isNotNull);

        // Verify seed community posts only attach public records
        for (final post in communityRepo.forYouPosts) {
          if (post.attachment != null) {
            final resolved = await WorkspaceAttachmentService().resolve(
              post.attachment!.source,
            );
            expect(
              resolved,
              isNotNull,
              reason:
                  'Post ${post.id} attachment ${post.attachment!.source.id} must resolve as public',
            );
          }
        }
      },
    );
  });

  group('Customer Subscription Quotas (INR) & Desk Risk Limitations', () {
    test('INR subscription quotas scale across Free, Basic, and Pro', () {
      final free = CustomerTierQuota.forTier(AppTier.free);
      final basic = CustomerTierQuota.forTier(AppTier.premium);
      final pro = CustomerTierQuota.forTier(AppTier.enterprise);

      expect(free.monthlyPriceInr, 0);
      expect(free.maxNotes, 3);
      expect(free.maxTrades, 15);
      expect(free.maxLiveStrategies, 1);
      expect(free.allowPdfExport, isFalse);

      expect(basic.monthlyPriceInr, 299);
      expect(basic.maxNotes, 25);
      expect(basic.maxTrades, 100);
      expect(basic.maxLiveStrategies, 3);
      expect(basic.allowPdfExport, isFalse);

      expect(pro.monthlyPriceInr, 499);
      expect(pro.maxNotes, 10000);
      expect(pro.maxTrades, 50000);
      expect(pro.allowPdfExport, isTrue);
    });

    test(
      'evaluateTradeRisk enforces mandatory stop-loss, approval threshold, position cap, and circuit breaker',
      () async {
        final adminRepo = AdminConsoleRepository.instance;
        await adminRepo.setCircuitBreakerState(state: 'armed');

        // 1. Missing stop-loss when required by desk policy
        final missingStop = await CustomerLimitations.evaluateTradeRisk(
          symbol: 'NIFTY',
          entryPrice: 24000,
          quantity: 10,
          stopLoss: null,
        );
        expect(missingStop.allowed, isFalse);
        expect(missingStop.missingMandatoryStopLoss, isTrue);

        // 2. Order above ₹10L requires manager approval
        final approvalEval = await CustomerLimitations.evaluateTradeRisk(
          symbol: 'RELIANCE',
          entryPrice: 3000,
          quantity: 500, // ₹15,00,000 notional
          stopLoss: 2940,
        );
        expect(approvalEval.allowed, isTrue);
        expect(approvalEval.requiresManagerApproval, isTrue);

        // 3. Order above ₹50L exceeds max position cap
        final capEval = await CustomerLimitations.evaluateTradeRisk(
          symbol: 'BANKNIFTY',
          entryPrice: 52000,
          quantity: 120, // ₹62,40,000 notional
          stopLoss: 51500,
        );
        expect(capEval.allowed, isFalse);
        expect(capEval.exceedsPositionCap, isTrue);

        // 4. Halted circuit breaker blocks all new trades
        await adminRepo.setCircuitBreakerState(
          state: 'halted',
          reason: 'RBI Volatility Halt',
        );
        final haltedEval = await CustomerLimitations.evaluateTradeRisk(
          symbol: 'TCS',
          entryPrice: 4000,
          quantity: 10,
          stopLoss: 3950,
        );
        expect(haltedEval.allowed, isFalse);
        expect(haltedEval.isCircuitBreakerHalted, isTrue);

        // Reset circuit breaker to armed
        await adminRepo.setCircuitBreakerState(state: 'armed');
      },
    );
  });
}
