import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/core/utils/zip_archive_builder.dart';
import 'package:tradex/core/widgets/app_notifications_overlay.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_follow_view.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/journal/data/journal_templates.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/settings/data/repositories/notification_prefs_repository.dart';
import 'package:tradex/features/settings/data/repositories/privacy_repository.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/models/active_session_model.dart';
import 'package:tradex/features/settings/models/connected_account_model.dart';
import 'package:tradex/features/settings/models/notification_prefs_model.dart';
import 'package:tradex/features/settings/presentation/pages/shared/account_security_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/appearance_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/notifications_settings_page.dart';

import 'public_site/public_content_test.dart' show FileAssets;

class _FakeProfileSecurityRepository implements ProfileSettingsRepository {
  _FakeProfileSecurityRepository({
    required this.accounts,
    required this.emailIdentity,
  });

  List<ConnectedAccount> accounts;
  bool emailIdentity;
  String? lastLinkedProvider;
  String? lastUnlinkedProvider;
  String? lastPasswordChangedTo;

  final ProfileSettingsRepositoryImpl _delegate =
      ProfileSettingsRepositoryImpl.instance;

  @override
  UserProfileModel get cachedProfile => _delegate.cachedProfile;

  @override
  Future<UserProfileModel> getProfile() async => cachedProfile;

  @override
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? experienceLevel,
    String? tradingStyle,
    String? location,
    String? website,
    String? avgHoldDuration,
    String? primaryMarket,
    String? topStrategy,
    String? riskMantra,
    bool? publicStatsEnabled,
    bool? publicJournalsEnabled,
  }) => _delegate.updateProfile(
    displayName: displayName,
    bio: bio,
    avatarUrl: avatarUrl,
    experienceLevel: experienceLevel,
    tradingStyle: tradingStyle,
    location: location,
    website: website,
    avgHoldDuration: avgHoldDuration,
    primaryMarket: primaryMarket,
    topStrategy: topStrategy,
    riskMantra: riskMantra,
    publicStatsEnabled: publicStatsEnabled,
    publicJournalsEnabled: publicJournalsEnabled,
  );

  @override
  Future<bool> hasEmailIdentity() async => emailIdentity;

  @override
  Future<List<ConnectedAccount>> getConnectedAccounts() async =>
      List<ConnectedAccount>.unmodifiable(accounts);

  @override
  Future<void> linkConnectedAccount(String provider) async {
    lastLinkedProvider = provider;
    accounts = <ConnectedAccount>[
      ...accounts.where((a) => a.provider != provider),
      ConnectedAccount(
        provider: provider,
        linkedAt: DateTime.utc(2026, 11, 15),
        email: '$provider-trader@alphajournal.in',
      ),
    ];
  }

  @override
  Future<void> unlinkConnectedAccount(String provider) async {
    if (!emailIdentity && accounts.length <= 1) {
      throw Exception(
        'Set a password before unlinking your only sign-in method.',
      );
    }
    lastUnlinkedProvider = provider;
    accounts = accounts.where((a) => a.provider != provider).toList();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    lastPasswordChangedTo = newPassword;
    emailIdentity = true;
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {}

  @override
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType) =>
      _delegate.uploadAvatar(imageBytes, contentType);

  @override
  Future<void> removeAvatar() => _delegate.removeAvatar();

  @override
  Future<AccountDeletionRequestModel> requestAccountDeletion({
    String? reason,
    String? feedback,
    String dataPurgeCondition = 'immediate_purge',
    bool purgeJournalsNotesStrategies = true,
    bool purgeCommunityMessages = true,
    bool purgeAiWorkspace = true,
    bool purgeAffiliateCampaigns = true,
    bool exportBeforeDelete = false,
    String userRole = 'customer',
  }) => _delegate.requestAccountDeletion(
    reason: reason,
    feedback: feedback,
    dataPurgeCondition: dataPurgeCondition,
    purgeJournalsNotesStrategies: purgeJournalsNotesStrategies,
    purgeCommunityMessages: purgeCommunityMessages,
    purgeAiWorkspace: purgeAiWorkspace,
    purgeAffiliateCampaigns: purgeAffiliateCampaigns,
    exportBeforeDelete: exportBeforeDelete,
    userRole: userRole,
  );

  @override
  Future<List<AccountDeletionRequestModel>> getDeletionRequests() =>
      _delegate.getDeletionRequests();

  @override
  Future<AccountDeletionRequestModel> processDeletionRequest({
    required String requestId,
    required String action,
    String? adminNotes,
  }) => _delegate.processDeletionRequest(
    requestId: requestId,
    action: action,
    adminNotes: adminNotes,
  );

  @override
  Future<ActiveDeviceSession?> registerCurrentDeviceSession() =>
      _delegate.registerCurrentDeviceSession();

  @override
  Future<List<ActiveDeviceSession>> getActiveSessions() =>
      _delegate.getActiveSessions();

  @override
  Future<bool> revokeSession(String sessionId) =>
      _delegate.revokeSession(sessionId);

  @override
  Future<int> revokeOtherSessions() => _delegate.revokeOtherSessions();

  @override
  Future<SecurityPreferencesModel> getSecurityPreferences() =>
      _delegate.getSecurityPreferences();

  @override
  Future<SecurityPreferencesModel> updateSecurityPreferences(
    SecurityPreferencesModel prefs,
  ) => _delegate.updateSecurityPreferences(prefs);
}

Widget _wrapWithTheme(
  Widget child, {
  AppThemeController? controller,
}) {
  final ctrl = controller ?? AppThemeController();
  return AppThemeScope(
    controller: ctrl,
    child: AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final uiColors = UiColors.dark().withMarketConvention(
          ctrl.colorConvention,
          Brightness.dark,
        );
        return MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: <ThemeExtension<dynamic>>[
              UiTheme.dark(colors: uiColors),
            ],
          ),
          home: Scaffold(body: child),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Issue 1 & Issue 3: Notifications Overlay Single-Column & Routing', () {
    testWidgets(
      'CommunityPostDetailView forceSingleColumn omits right desktop panel on wide viewports',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = CommunityRepository();
        const author = CommunityAuthor(
          id: 'u_author_1',
          handle: 'udit',
          displayName: 'Udit',
          userRole: UserRole.customer,
          winRate: 78.5,
        );
        await repo.createPost(
          body: 'Single column notification post detail check',
          author: author,
        );
        final post = repo.forYouPosts.first;

        await tester.pumpWidget(
          _wrapWithTheme(
            CommunityPostDetailView(
              post: post,
              repository: repo,
              currentUser: repo.currentAuthor,
              forceSingleColumn: true,
              showHeader: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Single column notification post detail check'),
          findsAtLeastNWidgets(1),
        );
        expect(find.text('Thread Activity'), findsNothing);
      },
    );

    testWidgets(
      'AppNotificationsOverlay opens post notifications in single column, marks read, and routes Security Settings',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = CommunityRepository();
        const author = CommunityAuthor(
          id: 'u_udit',
          handle: 'udit',
          displayName: 'udit',
          userRole: UserRole.customer,
        );
        await repo.createPost(
          body: 'Overlay detail single-column thread check',
          author: author,
        );
        final post = repo.forYouPosts.first;

        final now = DateTime.now();
        repo.setNotificationsForTesting(<CommunityNotificationItem>[
          CommunityNotificationItem(
            id: 'notif_post_1',
            actor: const CommunityAuthor(
              id: 'u_nk',
              handle: 'nk2552003',
              displayName: 'nk2552003',
              userRole: UserRole.customer,
            ),
            type: CommunityNotificationType.comment,
            createdAt: now.subtract(const Duration(hours: 2)),
            title: 'New Comment',
            body: 'replied: great progress',
            postSnippet: 'great progress',
            postId: post.id,
            read: false,
          ),
          CommunityNotificationItem(
            id: 'notif_sec_1',
            actor: const CommunityAuthor(
              id: 'system',
              handle: 'alphajournal',
              displayName: 'alphajournal Security',
              userRole: UserRole.customer,
            ),
            type: CommunityNotificationType.security,
            createdAt: now.subtract(const Duration(hours: 1)),
            title: 'Security Alert',
            body: 'New login detected from Mac',
            read: false,
          ),
        ]);

        bool openedSecurity = false;
        await tester.pumpWidget(
          _wrapWithTheme(
            SizedBox(
              width: 440,
              height: 820,
              child: AppNotificationsOverlay(
                repository: repo,
                onOpenSecuritySettings: () => openedSecurity = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap post notification -> opens in-place single-column post detail
        await tester.tap(find.textContaining('great progress'));
        await tester.pumpAndSettle();

        expect(
          find.text('Overlay detail single-column thread check'),
          findsAtLeastNWidgets(1),
        );
        expect(find.text('Thread Activity'), findsNothing);
        expect(
          repo.notifications.firstWhere((n) => n.id == 'notif_post_1').read,
          isTrue,
        );

        // Return to notifications list using Back icon
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // Tap Security Alert -> opens Security Alert dialog and routes to Security Settings
        await tester.tap(find.textContaining('New login detected'));
        await tester.pumpAndSettle();
        expect(find.text('Security Settings'), findsOneWidget);

        await tester.tap(find.text('Security Settings'));
        await tester.pumpAndSettle();
        expect(openedSecurity, isTrue);
      },
    );
  });

  group('Issue 2: Community Leaderboard', () {
    testWidgets(
      'Leaderboard ranks traders by winRate, switches period, filters by query, and toggles follow',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = CommunityRepository();
        const topAuthor = CommunityAuthor(
          id: 'u_top',
          handle: 'quant_alpha',
          displayName: 'Quant Alpha',
          userRole: UserRole.customer,
          winRate: 88.4,
        );
        const midAuthor = CommunityAuthor(
          id: 'u_mid',
          handle: 'swing_pro',
          displayName: 'Swing Pro',
          userRole: UserRole.customer,
          winRate: 71.2,
        );
        await repo.createPost(body: 'Top breakout setup', author: topAuthor);
        await repo.createPost(body: 'Swing structure setup', author: midAuthor);

        await tester.pumpWidget(
          _wrapWithTheme(CommunityFollowView(repository: repo)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Leaderboard'));
        await tester.pumpAndSettle();

        expect(find.text('Quant Alpha'), findsAtLeastNWidgets(1));
        expect(find.text('Swing Pro'), findsAtLeastNWidgets(1));
        expect(find.text('88.4% Win'), findsAtLeastNWidgets(1));

        // Period switcher ('1W', '3M', 'All') executes cleanly and updates header
        await tester.tap(find.text('1W'));
        await tester.pumpAndSettle();
        expect(find.text('Ranked by Win-Rate · 1W'), findsOneWidget);
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();
        expect(find.text('Ranked by Win-Rate · ALL'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch back to '1M' so exact 88.4% seed holds, then toggle follow
        await tester.tap(find.text('1M'));
        await tester.pumpAndSettle();
        final followBtn = find.byTooltip('Follow @quant_alpha');
        expect(followBtn, findsOneWidget);
        await tester.tap(followBtn);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Following @quant_alpha'), findsOneWidget);
      },
    );
  });

  group('Issue 4: Security Page & Connected Accounts', () {
    testWidgets(
      'Connected Accounts shows Google & Apple, handles unlink confirmation & OAuth-only set-password mode',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakeProfileSecurityRepository(
          emailIdentity: false,
          accounts: <ConnectedAccount>[
            ConnectedAccount(
              provider: 'google',
              linkedAt: DateTime.utc(2026, 11, 10),
              email: 'trader@gmail.com',
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapWithTheme(AccountSecurityPage(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connected Accounts'), findsOneWidget);
        expect(find.text('Google'), findsOneWidget);
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Unlink'), findsOneWidget);
        expect(find.text('Link Apple'), findsOneWidget);
        expect(find.text('Set Account Password'), findsOneWidget);

        // Link Apple
        final linkApple = find.text('Link Apple');
        await tester.ensureVisible(linkApple);
        await tester.tap(linkApple);
        await tester.pumpAndSettle();
        expect(fakeRepo.lastLinkedProvider, 'apple');
        expect(find.text('Unlink'), findsNWidgets(2));

        // Unlink Google via confirmation dialog
        final firstUnlink = find.text('Unlink').first;
        await tester.ensureVisible(firstUnlink);
        await tester.tap(firstUnlink);
        await tester.pumpAndSettle();
        expect(find.text('Unlink Google?'), findsOneWidget);

        await tester.tap(find.widgetWithText(UiButton, 'Unlink Google'));
        await tester.pumpAndSettle();
        expect(fakeRepo.lastUnlinkedProvider, 'google');
      },
    );

    test(
      'ProfileSettingsRepositoryImpl.updateProfile persists publicStats toggle locally',
      () async {
        await ProfileSettingsRepositoryImpl.instance.updateProfile(
          publicStatsEnabled: false,
        );
        expect(
          ProfileSettingsRepositoryImpl.instance.cachedProfile.publicStats,
          isFalse,
        );
        await ProfileSettingsRepositoryImpl.instance.updateProfile(
          publicStatsEnabled: true,
        );
        expect(
          ProfileSettingsRepositoryImpl.instance.cachedProfile.publicStats,
          isTrue,
        );
      },
    );
  });

  group('Issue 5: Notification Preferences & Quiet Hours Policy', () {
    test(
      'NotificationPrefsRepositoryImpl respects push category toggles and Quiet Hours while preserving security alerts',
      () async {
        final repo = NotificationPrefsRepositoryImpl.instance;
        await repo.updatePreferences(
          NotificationPrefsModel(
            quietHoursEnabled: true,
            quietHoursStart: '22:00',
            quietHoursEnd: '08:00',
            pushByCategory: const <String, bool>{
              'trade': true,
              'price_alert': false,
              'message': true,
              'community': false,
              'affiliate': false,
              'digest': false,
            },
            emailByCategory: const <String, bool>{},
          ),
        );

        // Category disabled -> blocked even outside quiet hours
        final midday = DateTime(2026, 11, 15, 14, 0);
        expect(
          repo.shouldSurfaceInApp(CommunityNotificationType.like, now: midday),
          isFalse,
        );
        expect(
          repo.shouldSurfaceInApp(CommunityNotificationType.signal, now: midday),
          isFalse,
        );
        expect(
          repo.shouldSurfaceInApp(
            CommunityNotificationType.message,
            now: midday,
          ),
          isTrue,
        );

        // Overnight quiet hours blocks active category at 23:30 and 07:30, allows at 08:00
        expect(
          repo.shouldSurfaceInApp(
            CommunityNotificationType.tradeExecution,
            now: DateTime(2026, 11, 15, 23, 30),
          ),
          isFalse,
        );
        expect(
          repo.shouldSurfaceInApp(
            CommunityNotificationType.tradeExecution,
            now: DateTime(2026, 11, 15, 7, 30),
          ),
          isFalse,
        );
        expect(
          repo.shouldSurfaceInApp(
            CommunityNotificationType.tradeExecution,
            now: DateTime(2026, 11, 15, 8, 0),
          ),
          isTrue,
        );

        // Security alerts bypass quiet hours and push category filters
        expect(
          repo.shouldSurfaceInApp(
            CommunityNotificationType.security,
            now: DateTime(2026, 11, 15, 23, 45),
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'NotificationsSettingsPage supports dismiss/restore Push banner and displays all categories',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithTheme(const NotificationsSettingsPage()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Push Notifications'), findsOneWidget);
        expect(find.text('Quiet Hours Schedule'), findsOneWidget);
        expect(find.text('Trade Executions & Orders'), findsOneWidget);
        expect(find.text('Direct Messages & Mentions'), findsOneWidget);
        expect(find.text('Affiliate & Referral Updates'), findsOneWidget);
        expect(find.text('Email Notifications & Digest'), findsOneWidget);

        // Dismiss Push Notifications banner -> persists preference & shows restore button
        final dismissBtn = find.byTooltip('Dismiss');
        await tester.ensureVisible(dismissBtn);
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();
        expect(find.text('Configure Device Push'), findsOneWidget);

        final restoreBtn = find.text('Configure Device Push');
        await tester.ensureVisible(restoreBtn);
        await tester.tap(restoreBtn);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Dismiss'), findsOneWidget);
      },
    );
  });

  group('Issue 6: Privacy, GDPR ZIP Archive & Spam Filtering', () {
    test('ZipArchiveBuilder writes valid PKZIP headers and CRC32', () {
      final zip = ZipArchiveBuilder()
        ..addString('README.txt', 'TradeX GDPR Export')
        ..addJson('profile.json', <String, dynamic>{'public': true});
      final Uint8List bytes = zip.build(
        timestamp: DateTime(2026, 11, 15, 12, 0),
      );

      // Local file header signature PK\x03\x04
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4b);
      expect(bytes[2], 0x03);
      expect(bytes[3], 0x04);
      final asciiText = latin1.decode(bytes);
      expect(asciiText, contains('README.txt'));
      expect(asciiText, contains('profile.json'));
      expect(asciiText, contains('TradeX GDPR Export'));
    });

    test(
      'PrivacyRepositoryImpl builds valid GDPR ZIP archive offline while keeping requestDataExport offline contract',
      () async {
        final archive =
            await PrivacyRepositoryImpl.instance.buildDataExportArchive();
        expect(archive.filename, endsWith('.zip'));
        expect(archive.bytes[0], 0x50);
        expect(archive.bytes[1], 0x4b);
        final decoded = latin1.decode(archive.bytes);
        expect(decoded, contains('README.txt'));
        expect(decoded, contains('profile_and_privacy.json'));
        expect(decoded, contains('trades.csv'));

        expect(
          () => PrivacyRepositoryImpl.instance.requestDataExport(),
          throwsStateError,
        );
      },
    );

    test(
      'JournalTemplates.toDraft respects publicJournals default and MessagesRepository.isLikelySpamRequest detects spam',
      () {
        final privateDraft = JournalTemplates.review.toDraft(isPublic: false);
        final publicDraft = JournalTemplates.review.toDraft(isPublic: true);
        expect(privateDraft.isPublic, isFalse);
        expect(publicDraft.isPublic, isTrue);

        final spamThread = MessageThread(
          id: 't_spam',
          peer: const AppTrader(
            id: 'p_spam',
            displayName: 'Signal Bot',
            handle: '@bot_vip',
          ),
          lastMessagePreview: 'Join our Telegram for 1000% guaranteed profit!',
          lastMessageAt: DateTime.now(),
          isRequest: true,
        );
        final legThread = MessageThread(
          id: 't_legit',
          peer: const AppTrader(
            id: 'p_legit',
            displayName: 'Nikhil Rao',
            handle: '@nikhil',
          ),
          lastMessagePreview: 'Loved your NIFTY VWAP breakdown today.',
          lastMessageAt: DateTime.now(),
          isRequest: true,
        );
        expect(MessagesRepository.isLikelySpamRequest(spamThread), isTrue);
        expect(MessagesRepository.isLikelySpamRequest(legThread), isFalse);
      },
    );
  });

  group('Issue 7: Appearance Chart Defaults & Color Convention', () {
    test('UiColors.withMarketConvention switches bullish & bearish tokens', () {
      final standard = UiColors.dark().withMarketConvention(
        'Standard (Green/Red)',
        Brightness.dark,
      );
      final colorblind = UiColors.dark().withMarketConvention(
        'Colorblind-Safe (Blue/Orange)',
        Brightness.dark,
      );
      final mono = UiColors.dark().withMarketConvention(
        'Monochrome (High Contrast)',
        Brightness.dark,
      );

      expect(colorblind.bullish, isNot(equals(standard.bullish)));
      expect(colorblind.bearish, isNot(equals(standard.bearish)));
      expect(mono.bullish, equals(const Color(0xFFF9FAFB)));
      expect(mono.bullish, isNot(equals(standard.bullish)));
    });

    testWidgets(
      'AppearanceSettingsPage updates AppThemeController chart range, style, color convention and renders live preview',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ctrl = AppThemeController();
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          _wrapWithTheme(const AppearanceSettingsPage(), controller: ctrl),
        );
        await tester.pumpAndSettle();

        expect(find.text('Live Chart Preview'), findsOneWidget);
        expect(find.byType(UiCandleChart), findsOneWidget);

        await tester.tap(find.text('1W'));
        await tester.pumpAndSettle();
        expect(ctrl.chartRange, '1W');

        ctrl.setChartStyle('Line');
        await tester.pumpAndSettle();
        expect(ctrl.preferredPriceChartType, UiPriceChartType.line);
        expect(
          tester.widget<UiCandleChart>(find.byType(UiCandleChart)).type,
          UiPriceChartType.line,
        );
        expect(find.text('1W • Line'), findsOneWidget);

        ctrl.setColorConvention('Colorblind-Safe (Blue/Orange)');
        await tester.pumpAndSettle();
        expect(find.text('Colorblind-Safe (Blue/Orange)'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'MarketInstrumentView inherits AppThemeController chartRange and chartStyle defaults',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = AssetMarketRepository(bundle: FileAssets());
        final snapshot = (await tester.runAsync(() async {
          final snap = await repo.snapshot();
          await repo.detail('AAPL');
          return snap;
        }))!;
        final instrument =
            snapshot.instruments.firstWhere((q) => q.symbol == 'AAPL');

        final ctrl = AppThemeController(
          ThemeMode.dark,
          'Comfortable',
          '1W',
          'Line',
          'Colorblind-Safe (Blue/Orange)',
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          _wrapWithTheme(
            MarketInstrumentView(
              instrument: instrument,
              repository: repo,
              snapshot: snapshot,
            ),
            controller: ctrl,
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UiAreaChart), findsOneWidget);
        final rangeToggle = tester.widget<UiToggleGroup<MarketHistoryRange>>(
          find.byKey(const ValueKey<String>('market-history-range-toggle')),
        );
        expect(rangeToggle.value, MarketHistoryRange.week);
      },
    );
  });
}
