import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/copilot/data/copilot_api.dart';
import 'package:tradex/features/copilot/models/workspace_mutations.dart';
import 'package:tradex/features/copilot/presentation/workspace_pane.dart';
import 'package:tradex/features/settings/data/repositories/ai_settings_repository.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/models/active_session_model.dart';
import 'package:tradex/features/settings/models/connected_account_model.dart';
import 'package:tradex/features/settings/presentation/pages/shared/account_security_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/ai_copilot_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/appearance_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/trading_preferences_page.dart';

class _TestDeviceProfileRepo implements ProfileSettingsRepository {
  _TestDeviceProfileRepo({required List<ActiveDeviceSession> initialSessions})
    : sessions = List<ActiveDeviceSession>.from(initialSessions);

  List<ActiveDeviceSession> sessions;
  SecurityPreferencesModel securityPrefs = const SecurityPreferencesModel();
  final List<String> revokedIds = <String>[];
  int revokeOthersCalls = 0;

  final ProfileSettingsRepositoryImpl _delegate =
      ProfileSettingsRepositoryImpl.instance;

  @override
  UserProfileModel get cachedProfile => _delegate.cachedProfile;

  @override
  Future<UserProfileModel> getProfile() async => UserProfileModel(
    id: 'usr-test-1',
    handle: 'alpha_trader',
    email: 'trader@alphajournal.in',
    role: UserRole.customer,
    displayName: 'Alpha Trader',
  );

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
  }) => _delegate.updateProfile(displayName: displayName);

  @override
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType) =>
      _delegate.uploadAvatar(imageBytes, contentType);

  @override
  Future<void> removeAvatar() => _delegate.removeAvatar();

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<bool> hasEmailIdentity() async => true;

  @override
  Future<List<ConnectedAccount>> getConnectedAccounts() async => const [];

  @override
  Future<void> linkConnectedAccount(String provider) async {}

  @override
  Future<void> unlinkConnectedAccount(String provider) async {}

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
  }) => _delegate.requestAccountDeletion();

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
  Future<ActiveDeviceSession?> registerCurrentDeviceSession() async =>
      sessions.where((s) => s.isCurrent).firstOrNull;

  @override
  Future<List<ActiveDeviceSession>> getActiveSessions() async =>
      List<ActiveDeviceSession>.unmodifiable(sessions);

  @override
  Future<bool> revokeSession(String sessionId) async {
    revokedIds.add(sessionId);
    final match = sessions.where((s) => s.sessionId == sessionId).firstOrNull;
    final bool isCurrent = match?.isCurrent ?? false;
    sessions.removeWhere((s) => s.sessionId == sessionId);
    return isCurrent;
  }

  @override
  Future<int> revokeOtherSessions() async {
    revokeOthersCalls++;
    final int removed = sessions.where((s) => !s.isCurrent).length;
    sessions.removeWhere((s) => !s.isCurrent);
    return removed;
  }

  @override
  Future<SecurityPreferencesModel> getSecurityPreferences() async =>
      securityPrefs;

  @override
  Future<SecurityPreferencesModel> updateSecurityPreferences(
    SecurityPreferencesModel prefs,
  ) async {
    securityPrefs = prefs;
    return securityPrefs;
  }
}

class _RecordingCopilotApi extends CopilotApi {
  _RecordingCopilotApi() : state = initialWorkspace();

  final Json state;
  final List<Json> actions = <Json>[];

  @override
  Future<Json> getWorkspace() async => jsonDecode(jsonEncode(state)) as Json;

  @override
  Future<Json> action(Json body) async {
    actions.add(Map<String, dynamic>.from(body));
    return WorkspaceMutations.apply(state, body);
  }
}

Widget _wrapTestApp(Widget child, {AppThemeController? controller}) {
  final effective = controller ?? AppThemeController(ThemeMode.dark);
  return AppThemeScope(
    controller: effective,
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
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ActiveDeviceSession model & parsing', () {
    test('extracts session_id from JWT access token', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          '{"sub":"user-123","session_id":"11111111-2222-3333-4444-555555555555"}',
        ),
      );
      final token = '$header.$payload.sig';

      expect(
        ActiveDeviceSession.decodeJwtSessionId(token),
        '11111111-2222-3333-4444-555555555555',
      );
      expect(ActiveDeviceSession.decodeJwtSessionId('invalid'), isNull);
    });

    test('parses common browser and mobile user-agents accurately', () {
      final macChrome = ActiveDeviceSession.parseUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36',
      );
      expect(macChrome.browserOrApp, 'Chrome');
      expect(macChrome.osName, 'macOS');
      expect(macChrome.deviceName, 'Chrome on macOS');

      final iphoneSafari = ActiveDeviceSession.parseUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1',
      );
      expect(iphoneSafari.browserOrApp, 'Safari');
      expect(iphoneSafari.osName, 'iOS');
      expect(iphoneSafari.platform, 'ios');
      expect(iphoneSafari.deviceName, 'Safari on iOS');
    });
  });

  group('AccountSecurityPage active device management', () {
    List<ActiveDeviceSession> sampleSessions() {
      final now = DateTime.now();
      return <ActiveDeviceSession>[
        ActiveDeviceSession(
          sessionId: 'sess-current',
          deviceName: 'Chrome on macOS',
          platform: 'macos',
          browserOrApp: 'Chrome',
          osName: 'macOS',
          ipAddress: '103.21.14.8',
          createdAt: now.subtract(const Duration(days: 2)),
          lastActiveAt: now,
          isCurrent: true,
        ),
        ActiveDeviceSession(
          sessionId: 'sess-iphone',
          deviceName: 'alphajournal App on iOS',
          platform: 'ios',
          browserOrApp: 'alphajournal App',
          osName: 'iOS',
          ipAddress: '49.36.112.9',
          createdAt: now.subtract(const Duration(days: 5)),
          lastActiveAt: now.subtract(const Duration(minutes: 25)),
        ),
        ActiveDeviceSession(
          sessionId: 'sess-windows',
          deviceName: 'Microsoft Edge on Windows',
          platform: 'windows',
          browserOrApp: 'Microsoft Edge',
          osName: 'Windows',
          ipAddress: '122.170.4.21',
          createdAt: now.subtract(const Duration(days: 8)),
          lastActiveAt: now.subtract(const Duration(hours: 6)),
        ),
      ];
    }

    testWidgets(
      'displays device count, device details, and logs out remote & current devices',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _TestDeviceProfileRepo(initialSessions: sampleSessions());
        bool loggedOutCurrent = false;

        await tester.pumpWidget(
          _wrapTestApp(
            AccountSecurityPage(
              repository: repo,
              onAccountDeleted: () => loggedOutCurrent = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 active devices'), findsOneWidget);
        expect(find.text('Chrome on macOS'), findsOneWidget);
        expect(find.text('This device'), findsOneWidget);
        expect(find.text('alphajournal App on iOS'), findsOneWidget);
        expect(find.text('Microsoft Edge on Windows'), findsOneWidget);
        expect(find.text('Log out 2 other devices'), findsOneWidget);

        // Log out a specific remote device (iOS)
        final iphoneLogOutBtn = find.widgetWithText(UiButton, 'Log out').at(1);
        await tester.ensureVisible(iphoneLogOutBtn);
        await tester.tap(iphoneLogOutBtn);
        await tester.pumpAndSettle();

        expect(find.text('Log Out Device Session?'), findsOneWidget);
        await tester.tap(find.text('Log Out Device'));
        await tester.pumpAndSettle();

        expect(repo.revokedIds, contains('sess-iphone'));
        expect(find.text('alphajournal App on iOS'), findsNothing);
        expect(find.text('2 active devices'), findsOneWidget);

        // Bulk log out remaining other device
        final bulkBtn = find.text('Log out 1 other device');
        await tester.ensureVisible(bulkBtn);
        await tester.tap(bulkBtn);
        await tester.pumpAndSettle();

        expect(find.text('Log Out All Other Devices?'), findsOneWidget);
        await tester.tap(find.text('Log Out Other Devices'));
        await tester.pumpAndSettle();

        expect(repo.revokeOthersCalls, 1);
        expect(find.text('Microsoft Edge on Windows'), findsNothing);
        expect(find.text('1 active device'), findsOneWidget);

        // Log out current device triggers logout callback
        final currentLogoutBtn = find.widgetWithText(UiButton, 'Log out').first;
        await tester.ensureVisible(currentLogoutBtn);
        await tester.tap(currentLogoutBtn);
        await tester.pumpAndSettle();

        expect(find.text('Log Out of This Device?'), findsOneWidget);
        await tester.tap(find.text('Log Out This Device'));
        await tester.pumpAndSettle();

        expect(repo.revokedIds, contains('sess-current'));
        expect(loggedOutCurrent, isTrue);
      },
    );

    testWidgets('renders active devices cleanly at mobile width without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _TestDeviceProfileRepo(initialSessions: sampleSessions());

      await tester.pumpWidget(
        _wrapTestApp(AccountSecurityPage(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 active devices'), findsOneWidget);
      expect(find.text('Session & Sign-In Protection'), findsOneWidget);
      expect(find.text('New Device Sign-In Alerts'), findsOneWidget);
    });
  });

  group('AI & Copilot settings moved from Copilot into Settings', () {
    test('WorkspaceSection no longer embeds inline settings', () {
      expect(
        WorkspaceSection.values.any((s) => s.name == 'settings'),
        isFalse,
      );
    });

    testWidgets(
      'CopilotScreen routes settings button to onOpenSettings while AiCopilotSettingsPage manages and syncs all settings',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final api = _RecordingCopilotApi();
        final controller = CopilotController(api: api, autoLoad: false)
          ..connected = true;
        await controller.reload();

        bool openedSettings = false;
        await tester.pumpWidget(
          _wrapTestApp(
            CopilotScreen(
              repository: controller,
              onOpenSettings: () => openedSettings = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final settingsButton = find.byTooltip('AI & Copilot settings').first;
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();
        expect(openedSettings, isTrue);

        // Reset shared settings page & test AiCopilotSettingsPage controls
        await tester.pumpWidget(
          _wrapTestApp(
            AiCopilotSettingsPage(
              copilotController: controller,
              repository: AiSettingsRepositoryImpl.instance,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('AI Copilot Workspace Status'), findsOneWidget);
        expect(
          find.text('Copilot Capabilities & Privacy Controls'),
          findsOneWidget,
        );
        expect(find.text('Pause All AI Work'), findsOneWidget);
        expect(find.text('Allow Web Research'), findsOneWidget);
        expect(find.text('Allow Saved Preferences (Memory)'), findsOneWidget);
        expect(find.text('Allow Connected Apps (MCP)'), findsOneWidget);
        expect(find.text('Default AI Specialist'), findsOneWidget);
        expect(find.text('Memory & Learning Library'), findsOneWidget);
        expect(find.text('Connected Apps & MCP Servers'), findsOneWidget);

        // Toggle "Pause All AI Work"
        final pauseRow = find.ancestor(
          of: find.text('Pause All AI Work'),
          matching: find.byType(AppSettingCard),
        );
        await tester.tap(find.descendant(of: pauseRow, matching: find.byType(UiSwitch)));
        await tester.pumpAndSettle();

        expect(
          api.actions.any(
            (a) => a['action'] == 'settings.save' && a['paused'] == true,
          ),
          isTrue,
        );
        expect(controller.workspace.settings['paused'], isTrue);
      },
    );

    testWidgets(
      'AiCopilotSettingsPage updates live when CopilotController connects later and Connected Apps handles hosted mode cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final api = _RecordingCopilotApi();
        api.state['specialists'] = [
          ...(api.state['specialists'] as List),
          {
            'id': 'quant',
            'name': 'Quant',
            'role': 'Risk modeler',
            'instructions': 'Compute statistical expectancy.',
            'spaceIds': ['research'],
            'research': true,
            'memory': true,
            'code': true,
            'apps': false,
            'learning': false,
          },
        ];
        api.state['setup'] = <String, dynamic>{
          'backend': 'supabase',
          'apps': false,
          'schedules': false,
          'computer': false,
          'slack': false,
        };
        final controller = CopilotController(api: api, autoLoad: false);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            AiCopilotSettingsPage(
              copilotController: controller,
              repository: AiSettingsRepositoryImpl.instance,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Local Sync'), findsOneWidget);

        // Simulate background workspace connect finishing after page opened.
        await controller.reload();
        await tester.pumpAndSettle();

        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Hosted mode'), findsOneWidget);

        // Open Connected Apps & MCP Servers subpage and verify Hosted Mode guard.
        final mcpRow = find.text('Connected Apps & MCP Servers');
        await tester.ensureVisible(mcpRow);
        await tester.tap(mcpRow);
        await tester.pumpAndSettle();

        expect(find.text('Supabase Hosted Mode'), findsOneWidget);
        final connectBtn = tester.widget<UiButton>(
          find.widgetWithText(UiButton, 'Connect an MCP server'),
        );
        expect(connectBtn.onPressed, isNull);
      },
    );
  });

  group('Missing settings exposed & wired in navigation', () {
    test('RoleNavigationConfig and CustomerRoute expose settings_trading & settings_ai', () {
      final customerConfig = RoleNavigationConfig.forRole(UserRole.customer);
      final settingsItem = customerConfig.sections
          .expand((s) => s.items)
          .firstWhere((item) => item.id == 'settings');
      final subIds =
          settingsItem.subItems?.map((s) => s.id).toList() ?? const <String>[];

      expect(subIds, contains('settings_trading'));
      expect(subIds, contains('settings_ai'));

      expect(
        CustomerRoute.subdomainForDestination('settings_ai'),
        CustomerSubdomain.app,
      );
      expect(
        CustomerRoute.subdomainForDestination('settings_trading'),
        CustomerSubdomain.app,
      );
      expect(CustomerRoute.parse(Uri.parse('/settings_ai')).valid, isTrue);
      expect(CustomerRoute.parse(Uri.parse('/settings_trading')).valid, isTrue);
    });

    testWidgets('SettingsRootPage renders overview entries, Trading & Risk, AI & Copilot, and Appearance extras', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Overview exposes Trading & AI rows
      await tester.pumpWidget(
        _wrapTestApp(
          const SettingsRootPage(
            userRole: UserRole.customer,
            showNavigationPane: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trading, Risk & Checklists'), findsOneWidget);
      expect(find.text('AI & Copilot Settings'), findsOneWidget);

      // TradingPreferencesPage exposes Currency, Timezone & Journal rules
      await tester.pumpWidget(_wrapTestApp(const TradingPreferencesPage()));
      await tester.pumpAndSettle();
      expect(find.text('Currency, Session & Journal Rules'), findsOneWidget);
      expect(find.text('Preferred Display Currency'), findsOneWidget);
      expect(find.text('Default Market Session Timezone'), findsOneWidget);
      expect(
        find.text('Require Pre-Trade Checklist Confirmation'),
        findsOneWidget,
      );
      expect(
        find.text('Deduct Estimated Brokerage & Fees'),
        findsOneWidget,
      );

      // AppearanceSettingsPage exposes Formatting, Clock & Motion
      await tester.pumpWidget(_wrapTestApp(const AppearanceSettingsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Formatting, Clock & Motion'), findsOneWidget);
      expect(find.text('Number & Currency Grouping'), findsOneWidget);
      expect(find.text('Clock & Execution Time Format'), findsOneWidget);
      expect(find.text('Show Live Market Ticker Strip'), findsOneWidget);
      expect(find.text('Reduce Motion & Transitions'), findsOneWidget);
    });
  });
}
