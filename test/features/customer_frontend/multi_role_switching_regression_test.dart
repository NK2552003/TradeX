import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/config/cross_subdomain_storage.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/core/navigation/customer_routes.dart';
import 'package:alphajournal/core/widgets/app_scaffold.dart';
import 'package:alphajournal/features/auth/data/services/auth_session_storage.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/user_profile_model.dart';

import '../../helpers/workspace_design_harness.dart';

void main() {
  setUpAll(loadWorkspaceFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CrossSubdomainState.removeFlag('ax_role');
    AppSession.instance.setProfileMode(UserProfileMode.traderAffiliateAdmin);
  });

  group('Multi-Role Workspace Switching Persistence & Subdomain Routing', () {
    test(
      'saveWorkspaceRole & workspaceRoleFor honor admin -> trader -> affiliate -> admin',
      () async {
        final adminProfile = UserProfileModel(
          id: 'admin-1',
          email: 'admin@alphajournal.in',
          displayName: 'Admin One',
          handle: 'admin_one',
          role: UserRole.userAdmin,
          status: ProfileStatus.active,
          createdAt: DateTime(2026, 1, 1),
        );

        await AuthSessionStorage.saveWorkspaceRole(
          adminProfile.id,
          UserRole.customer,
        );
        expect(
          await AuthSessionStorage.workspaceRoleFor(adminProfile),
          UserRole.customer,
        );

        await AuthSessionStorage.saveWorkspaceRole(
          adminProfile.id,
          UserRole.affiliate,
        );
        expect(
          await AuthSessionStorage.workspaceRoleFor(adminProfile),
          UserRole.affiliate,
        );

        await AuthSessionStorage.saveWorkspaceRole(
          adminProfile.id,
          UserRole.userAdmin,
        );
        expect(
          await AuthSessionStorage.workspaceRoleFor(adminProfile),
          UserRole.userAdmin,
        );
      },
    );

    test(
      'affiliate switches between trader and affiliate, never escalates to admin',
      () async {
        final affProfile = UserProfileModel(
          id: 'aff-1',
          email: 'partner@alphajournal.in',
          displayName: 'Partner One',
          handle: 'partner_one',
          role: UserRole.affiliate,
          status: ProfileStatus.active,
          createdAt: DateTime(2026, 1, 1),
        );

        await AuthSessionStorage.saveWorkspaceRole(
          affProfile.id,
          UserRole.customer,
        );
        expect(
          await AuthSessionStorage.workspaceRoleFor(affProfile),
          UserRole.customer,
        );

        await AuthSessionStorage.saveWorkspaceRole(
          affProfile.id,
          UserRole.userAdmin,
        );
        expect(
          await AuthSessionStorage.workspaceRoleFor(affProfile),
          UserRole.affiliate,
        );
      },
    );

    test(
      'plain customer fails closed even if preference claims admin or affiliate',
      () async {
        final custProfile = UserProfileModel(
          id: 'cust-1',
          email: 'trader@alphajournal.in',
          displayName: 'Trader One',
          handle: 'trader_one',
          role: UserRole.customer,
          status: ProfileStatus.active,
          createdAt: DateTime(2026, 1, 1),
        );

        await AuthSessionStorage.saveWorkspaceRole(
          custProfile.id,
          UserRole.userAdmin,
        );
        expect(
          await AuthSessionStorage.workspaceRoleFor(custProfile),
          UserRole.customer,
        );
        await AuthSessionStorage.saveWorkspaceRole(
          custProfile.id,
          UserRole.affiliate,
        );
        expect(
          await AuthSessionStorage.workspaceRoleFor(custProfile),
          UserRole.customer,
        );
      },
    );

    test(
      'crossOriginRedirectUri transitions admin <-> affiliate <-> trader subdomains properly',
      () {
        expect(
          CustomerRoute.crossOriginRedirectUri(
            Uri.parse('/workspace'),
            currentHost: 'admin.alphajournal.in',
            activeRole: UserRole.customer,
          ).toString(),
          'https://app.alphajournal.in/workspace',
        );
        expect(
          CustomerRoute.crossOriginRedirectUri(
            Uri.parse('/overview'),
            currentHost: 'admin.alphajournal.in',
            activeRole: UserRole.affiliate,
          ).toString(),
          'https://affiliate.alphajournal.in/overview',
        );
        expect(
          CustomerRoute.crossOriginRedirectUri(
            Uri.parse('/workspace'),
            currentHost: 'affiliate.alphajournal.in',
            activeRole: UserRole.customer,
          ).toString(),
          'https://app.alphajournal.in/workspace',
        );
        expect(
          CustomerRoute.crossOriginRedirectUri(
            Uri.parse('/overview'),
            currentHost: 'affiliate.alphajournal.in',
            activeRole: UserRole.userAdmin,
          ).toString(),
          'https://admin.alphajournal.in/overview',
        );
      },
    );
  });

  group('AppScaffold In-App Role Switching Regression', () {
    testWidgets(
      'admin switches seamlessly to Trader and Affiliate and back without "Not available"',
      (tester) async {
        UserRole? reportedRole;
        await pumpWorkspace(
          tester,
          AppScaffold(
            userRole: UserRole.userAdmin,
            showDevelopmentRoleSwitcher: true,
            initialDestination: 'overview',
            onRoleChanged: (role) => reportedRole = role,
          ),
          width: 1440,
        );

        expect(
          find.text('This surface is not part of the User Admin workspace yet'),
          findsNothing,
        );
        expect(find.text('Switch to Trader'), findsOneWidget);
        expect(find.text('Switch to Affiliate'), findsOneWidget);

        // Admin -> Trader
        await tester.ensureVisible(find.text('Switch to Trader'));
        await tester.tap(find.text('Switch to Trader'));
        await settleWorkspace(tester);
        expect(reportedRole, UserRole.customer);
        expect(find.text('Nothing here yet'), findsNothing);
        expect(
          find.text('This surface is not part of the User Admin workspace yet'),
          findsNothing,
        );
        expect(find.text('Trader (Active)'), findsOneWidget);

        // Trader -> Affiliate
        await tester.ensureVisible(find.text('Switch to Affiliate'));
        await tester.tap(find.text('Switch to Affiliate'));
        await settleWorkspace(tester);
        expect(reportedRole, UserRole.affiliate);
        expect(find.text('Nothing here yet'), findsNothing);
        expect(find.text('Affiliate (Active)'), findsOneWidget);

        // Affiliate -> Admin
        await tester.ensureVisible(find.text('Switch to Admin'));
        await tester.tap(find.text('Switch to Admin'));
        await settleWorkspace(tester);
        expect(reportedRole, UserRole.userAdmin);
        expect(find.text('Admin (Active)'), findsOneWidget);
      },
    );

    testWidgets('affiliate switches seamlessly to Trader without dead-end', (
      tester,
    ) async {
      AppSession.instance.setProfileMode(UserProfileMode.traderAffiliate);
      UserRole? reportedRole;
      await pumpWorkspace(
        tester,
        AppScaffold(
          userRole: UserRole.affiliate,
          showDevelopmentRoleSwitcher: false,
          initialDestination: 'overview',
          onRoleChanged: (role) => reportedRole = role,
        ),
        width: 1440,
      );

      await tester.ensureVisible(find.text('Switch to Trader'));
      await tester.tap(find.text('Switch to Trader'));
      await settleWorkspace(tester);

      expect(reportedRole, UserRole.customer);
      expect(find.text('Nothing here yet'), findsNothing);
      expect(find.text('Trader (Active)'), findsOneWidget);
    });
  });
}
