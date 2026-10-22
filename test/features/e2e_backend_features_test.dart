import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/strategies/data/strategy_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/watchlists/data/watchlist_repository.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/messages/data/chat_repository.dart';
import 'package:tradex/features/settings/data/repositories/trading_prefs_repository.dart';
import 'package:tradex/features/settings/models/trading_prefs_model.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/data/repositories/affiliate_settings_repository.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_application_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/settings/data/repositories/desk_risk_repository.dart';
import 'package:tradex/features/settings/data/repositories/organization_settings_repository.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/data/repositories/notification_prefs_repository.dart';
import 'package:tradex/features/settings/models/notification_prefs_model.dart';
import 'package:tradex/features/settings/data/repositories/privacy_repository.dart';
import 'package:tradex/features/ai_assistant/data/ai_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Backend Modules Verification', () {
    test('1. Trade Journal & PnL Stats End-to-End', () async {
      final repo = JournalRepositoryImpl.instance;
      final initialEntries = await repo.fetchAll();
      expect(initialEntries, isNotEmpty);

      final newTrade = AppTrade(
        id: 'trade_e2e_01',
        ticker: 'TATAMOTORS',
        side: AppSide.long,
        entry: 980.0,
        exit: 1020.0,
        openedAt: DateTime.now().subtract(const Duration(hours: 2)),
        closedAt: DateTime.now(),
        stopLoss: 960.0,
        target: 1020.0,
        size: 50,
        pnl: 2000.0,
        pnlPercent: 4.08,
        rMultiple: 2.0,
        outcome: AppOutcome.win,
        strategy: 'Breakout',
        tags: const ['Automated', 'E2E'],
        content: 'Long breakout setup with strict 1:2 R:R',
      );

      final created = await repo.create(newTrade);
      expect(created.ticker, equals('TATAMOTORS'));
      expect(created.pnl, equals(2000.0));

      await repo.delete(created.id);
      final entriesAfterDelete = await repo.fetchAll();
      expect(entriesAfterDelete.any((e) => e.id == created.id), isFalse);
    });

    test('2. Quant Strategies & Versions End-to-End', () async {
      final repo = StrategyRepositoryImpl();
      final strategies = await repo.getStrategies();
      expect(strategies, isNotEmpty);

      final created = await repo.createStrategy(
        name: 'E2E Momentum Alpha',
        summary: 'Momentum strategy created during E2E verification',
        category: 'Momentum',
        rulesJson: {'timeframe': '15m', 'indicator': 'VWAP + EMA20'},
      );
      expect(created.name, equals('E2E Momentum Alpha'));

      final versioned = await repo.createVersion(
        strategyId: created.id,
        note: 'Switched indicator to VWAP + EMA9',
        contentJson: {'timeframe': '5m', 'indicator': 'VWAP + EMA9'},
      );
      expect(versioned.note, equals('Switched indicator to VWAP + EMA9'));

      final updated = await repo.updateStrategy(
        AppStrategy(
          id: created.id,
          name: created.name,
          summary: created.summary,
          category: created.category,
          isPublic: created.isPublic,
          isFavorite: true,
          trades: created.trades,
          winRate: created.winRate,
          avgR: created.avgR,
          netPnl: created.netPnl,
          updatedAt: created.updatedAt,
          versionCount: created.versionCount,
        ),
      );
      expect(updated.isFavorite, isTrue);

      await repo.deleteStrategy(created.id);
    });

    test('2b. Trader Notes & Markdown End-to-End', () async {
      final repo = NotesRepositoryImpl.instance;
      final notes = await repo.fetchAll();
      expect(notes, isNotEmpty);

      final draft = AppNote(
        id: 'note_e2e_test_1',
        title: 'E2E Technical Analysis',
        content:
            'Testing note with \$TSLA and checklist:\n- [ ] Plan trade\n- [x] Check risk',
        tags: const ['breakout', 'analysis'],
        linkedTickers: const ['TSLA'],
        isPublic: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await repo.create(draft);
      expect(created.title, equals('E2E Technical Analysis'));
      expect(created.wordCount, greaterThan(0));

      final commented = await repo.addComment(
        created.id,
        'Great setup analysis!',
      );
      expect(
        commented.comments.any((c) => c.body.contains('Great setup')),
        isTrue,
      );

      final liked = await repo.toggleLike(created.id);
      expect(liked.liked, isTrue);

      await repo.delete(created.id);
      final afterDelete = await repo.getById(created.id);
      expect(afterDelete, isNull);
    });

    test('3. Watchlists & Ticker Notes End-to-End', () async {
      final repo = WatchlistRepositoryImpl();
      final watchlists = await repo.getWatchlists();
      expect(watchlists, isNotEmpty);

      await repo.createWatchlist('E2E Tech Watchlist');
      await repo.addTickerToWatchlist('E2E Tech Watchlist', 'INFY');
      await repo.removeTickerFromWatchlist('E2E Tech Watchlist', 'INFY');

      final tickers = await repo.getWatchlistTickers();
      expect(tickers, isNotEmpty);
    });

    test('4. Community & Social Feed End-to-End', () async {
      final repo = CommunityRepository();
      expect(repo.forYouPosts, isNotEmpty);

      final initialCount = repo.forYouPosts.length;
      final author = repo.forYouPosts.first.author;
      repo.createPost(
        body: 'Testing NIFTY breakout setup with volume confirmation.',
        tickers: const ['NIFTY50'],
        author: author,
      );
      expect(repo.forYouPosts.length, greaterThan(initialCount));

      final created = repo.forYouPosts.first;
      repo.toggleLike(created.id);
      repo.addComment(created.id, 'Solid risk to reward structure!');

      expect(repo.commentsForPost(created.id), isNotEmpty);
    });

    test('5. Direct Messaging & Chat End-to-End', () async {
      final repo = ChatRepositoryImpl();
      final convos = await repo.getConversations();
      expect(convos, isNotEmpty);

      final targetConvoId = convos.first.id;
      final messages = await repo.getMessages(targetConvoId);
      expect(messages, isNotEmpty);

      final sent = await repo.sendMessage(
        targetConvoId,
        'What is your planned stop level for today?',
      );
      expect(sent.body, contains('planned stop level'));
    });

    test('6. Trading Preferences & Pre-Trade Checklist End-to-End', () async {
      final repo = TradingPrefsRepositoryImpl();
      final prefs = await repo.getPreferences();
      expect(prefs.defaultPositionSizePercent, greaterThan(0.0));

      final updatedPrefs = await repo.updatePreferences(
        const TradingPrefsModel(
          defaultPositionSizePercent: 3.5,
          defaultRMultipleTarget: 3.0,
        ),
      );
      expect(updatedPrefs.defaultPositionSizePercent, equals(3.5));
      expect(updatedPrefs.defaultRMultipleTarget, equals(3.0));

      final checklist = await repo.getChecklist();
      expect(checklist, isNotEmpty);

      final withNewItem = await repo.addChecklistItem(
        'Confirm volume breakout',
      );
      expect(
        withNewItem.any((i) => i.label == 'Confirm volume breakout'),
        isTrue,
      );
    });

    test('7. User Profile & 2FA Security End-to-End', () async {
      final repo = ProfileSettingsRepositoryImpl();
      final profile = await repo.getProfile();
      expect(profile.handle, isNotEmpty);

      final updated = await repo.updateProfile(
        bio: 'Automated quantitative swing trader bio.',
        location: 'Bengaluru, India',
      );
      expect(updated.bio, equals('Automated quantitative swing trader bio.'));
      expect(updated.location, equals('Bengaluru, India'));
    });

    test('8. Affiliate Partner & Referrals End-to-End', () async {
      final repo = AffiliateSettingsRepositoryImpl();
      final settings = await repo.getAffiliateSettings();
      expect(settings.referralCode, isNotEmpty);
      expect(settings.commissionRate, greaterThan(0.0));

      final updatedSlug = await repo.updateCustomSlug('e2e_alpha_partner');
      expect(updatedSlug.customSlug, equals('e2e_alpha_partner'));

      final updatedPayout = await repo.updatePayoutSettings(
        payoutMethod: 'upi',
        payoutAccount: 'e2e@upi',
        minimumThreshold: 5000.0,
        autoPayout: true,
      );
      expect(updatedPayout.payoutMethod, equals('upi'));
      expect(updatedPayout.minimumPayoutThreshold, equals(5000.0));

      final appRepo = AffiliateApplicationRepositoryImpl.instance;
      final newApp = await appRepo.submit(
        AffiliateApplicationModel(
          id: 'app_e2e_${DateTime.now().millisecondsSinceEpoch}',
          userId: '00000000-0000-0000-0000-000000000001',
          fullName: 'Test Trader',
          email: 'test@alphadesk.io',
          phone: '+919876543210',
          city: 'Mumbai',
          state: 'Maharashtra',
          dateOfBirth: DateTime(1995, 1, 1),
          gender: 'Male',
          platforms: const ['YouTube', 'Twitter'],
          primaryPlatform: 'YouTube',
          channelHandle: '@alphatrader',
          audienceReach: '10K - 50K',
          niches: const ['Options', 'Equities'],
          accountHolder: 'Test Trader',
          bankName: 'HDFC Bank',
          accountNumber: '1234567890',
          ifsc: 'HDFC0001234',
          accountType: 'Savings',
          pan: 'ABCDE1234F',
          status: AffiliateApplicationStatus.pending,
        ),
      );
      expect(newApp.status, equals(AffiliateApplicationStatus.pending));

      final reviewed = await appRepo.review(
        applicationId: newApp.id,
        approve: true,
        notes: 'Approved via automated test',
      );
      expect(reviewed.status, equals(AffiliateApplicationStatus.approved));
    });

    test('9. Desk Admin & Firm Risk Limits End-to-End', () async {
      final deskRepo = DeskRiskRepositoryImpl();
      final config = await deskRepo.getDeskRiskConfig();
      expect(config.maxFirmDrawdownPercent, greaterThan(0.0));

      final updatedConfig = await deskRepo.updateDeskRiskConfig(
        config.copyWith(maxFirmDrawdownPercent: 7.5),
      );
      expect(updatedConfig.maxFirmDrawdownPercent, equals(7.5));

      final orgRepo = OrganizationSettingsRepositoryImpl();
      final members = await orgRepo.getMembers();
      expect(members.length, greaterThanOrEqualTo(2));

      await orgRepo.inviteMember(
        email: 'e2e.trader@alphadesk.io',
        role: 'trader',
      );
      final membersAfterInvite = await orgRepo.getMembers();
      expect(membersAfterInvite.any((m) => m.handle == 'e2e.trader'), isTrue);

      final branding = await orgRepo.getBranding();
      expect(branding.displayName, isNotEmpty);

      final updatedBranding = await orgRepo.updateBranding(
        displayName: 'E2E Quant Desk Alpha',
        primaryColor: '#00E5FF',
      );
      expect(updatedBranding.displayName, equals('E2E Quant Desk Alpha'));
    });

    test('10. Billing & Subscriptions End-to-End', () async {
      final repo = BillingSettingsRepositoryImpl();
      final sub = await repo.getSubscription();
      expect(sub.status, isNotEmpty);

      final plans = await repo.getAvailablePlans();
      expect(plans, isNotEmpty);

      final checkout = await repo.startCheckout('pro', 'monthly');
      expect(checkout, isNotNull);

      final couponDiscount = await repo.redeemCoupon('TRADEX20');
      expect(couponDiscount, equals(20));

      final history = await repo.getBillingHistory();
      expect(history, isNotNull);

      final updatedCancelState = await repo.setCancelAtPeriodEnd(true);
      expect(updatedCancelState.cancelAtPeriodEnd, isTrue);
    });

    test('11. Notifications & GDPR Privacy End-to-End', () async {
      final notifRepo = NotificationPrefsRepositoryImpl();
      final notifPrefs = await notifRepo.getPreferences();
      expect(notifPrefs.pushByCategory, isNotEmpty);

      final updatedNotif = await notifRepo.updatePreferences(
        NotificationPrefsModel(
          pushByCategory: notifPrefs.pushByCategory,
          emailByCategory: notifPrefs.emailByCategory,
          emailDigestFrequency: 'daily',
        ),
      );
      expect(updatedNotif.emailDigestFrequency, equals('daily'));

      final privacyRepo = PrivacyRepositoryImpl();
      final privacySettings = await privacyRepo.getPrivacySettings();
      expect(privacySettings.publicJournals, isNotNull);

      await privacyRepo.setPublicJournalsDefault(false);
      await privacyRepo.setPublicStatsEnabled(true);

      final blocked = await privacyRepo.getBlockedUsers();
      expect(blocked, isNotEmpty);

      final firstBlockedId = blocked.first.id;
      await privacyRepo.unblockUser(firstBlockedId);
      final blockedAfterUnblock = await privacyRepo.getBlockedUsers();
      expect(blockedAfterUnblock.any((u) => u.id == firstBlockedId), isFalse);

      await expectLater(privacyRepo.requestDataExport(), throwsStateError);

      final exportStatus = await privacyRepo.getDataExportStatus();
      expect(exportStatus.status, equals('none'));
      expect(exportStatus.downloadUrl, isNull);
    });

    test('12. AI Trading Assistant End-to-End', () async {
      final repo = AiRepositoryImpl();
      final insights = await repo.getInsights();
      expect(insights, isNotEmpty);

      final firstInsight = insights.first;
      expect(firstInsight.confidence, greaterThan(0.0));
      expect(firstInsight.title, isNotEmpty);

      final requested = await repo.requestInsight(
        kind: 'pattern_scan',
        ticker: 'NIFTY50',
      );
      expect(requested.tickers, contains('NIFTY50'));
      expect(requested.confidence, greaterThan(0.8));
    });
  });
}
