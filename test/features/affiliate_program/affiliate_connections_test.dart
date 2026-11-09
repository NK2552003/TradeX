import 'package:tradex/core/privacy/consent_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'package:tradex/features/auth/data/services/auth_session_storage.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/auth/presentation/pages/signup_page.dart';
import 'package:tradex/features/auth/presentation/pages/auth_wrapper.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:tradex/features/settings/presentation/pages/trader/trader_affiliate_perks_page.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/affiliate_program/affiliate_program.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_overview_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart';
import 'package:tradex/features/settings/presentation/pages/affiliate/affiliate_settings_page.dart';

class RecordingSignup extends Fake implements AuthRepository {
  String? referral;
  @override
  Future<bool> isSignupOpen() async => true;
  @override
  Future<AuthResult> signUp({
    required UserRole role,
    required String handle,
    required String email,
    required String password,
    String? referralCode,
    String? adminKey,
  }) async {
    referral = referralCode;
    return AuthResult.failure('Recorded signup');
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CustomerDataPolicy.allowDemo = true;
  });
  tearDown(() => CustomerDataPolicy.allowDemo = false);
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> application(String userId, {bool approve = false}) async {
    final repo = AffiliateApplicationRepositoryImpl.instance;
    await repo.submit(
      AffiliateApplicationModel.fromJson({
        'id': 'app-$userId',
        'user_id': userId,
        'full_name': 'Connection test',
        'email': '$userId@example.com',
      }),
    );
    if (approve) await repo.review(applicationId: 'app-$userId', approve: true);
  }

  testWidgets(
    'approved customer can enter Partner Hub outside design preview',
    (tester) async {
      await application('approved-connection', approve: true);
      await tester.pumpWidget(
        const MaterialApp(
          home: AppScaffold(
            userId: 'approved-connection',
            userRole: UserRole.customer,
            initialDestination: 'settings_affiliate_perks',
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Open Partner Hub'), findsWidgets);
      await tester.tap(find.text('Open Partner Hub').first);
      await settle(tester);
      expect(find.byType(AffiliateOverviewPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending customer can review the existing application from program settings',
    (tester) async {
      await application('pending-connection');
      await tester.pumpWidget(
        const MaterialApp(
          home: AppScaffold(
            userId: 'pending-connection',
            initialDestination: 'settings_affiliate_perks',
          ),
        ),
      );
      await settle(tester);
      expect(find.text('View application status'), findsWidgets);
      await tester.tap(find.text('View application status').first);
      await settle(tester);
      expect(find.byType(AffiliateApplicationPage), findsOneWidget);
      expect(find.text('Application Submitted!'), findsWidgets);
    },
  );
  testWidgets('payout settings provides a return to payout results', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScaffold(
          userRole: UserRole.affiliate,
          initialDestination: 'payouts',
        ),
      ),
    );
    await settle(tester);
    await tester.ensureVisible(find.text('Payment settings'));
    await tester.tap(find.text('Payment settings'));
    await settle(tester);
    expect(find.byType(AffiliateSettingsPage), findsOneWidget);
    expect(find.text('Back to payouts'), findsWidgets);
    await tester.tap(find.text('Back to payouts').first);
    await settle(tester);
    expect(find.byType(AffiliatePayoutsPage), findsOneWidget);
  });
  test(
    'workspace preference is account scoped and cannot elevate a customer',
    () async {
      final partner = UserProfileModel.fromJson({
        'id': 'partner-pref',
        'handle': 'partner',
        'email': 'partner@example.com',
        'role': 'affiliate',
      });
      final customer = UserProfileModel.fromJson({
        'id': 'customer-pref',
        'handle': 'customer',
        'email': 'customer@example.com',
        'role': 'customer',
      });
      await AuthSessionStorage.saveWorkspaceRole(partner.id, UserRole.customer);
      expect(
        await AuthSessionStorage.workspaceRoleFor(partner),
        UserRole.customer,
      );
      await AuthSessionStorage.saveWorkspaceRole(
        customer.id,
        UserRole.affiliate,
      );
      expect(
        await AuthSessionStorage.workspaceRoleFor(customer),
        UserRole.customer,
      );
    },
  );
  test('application destination survives URL parsing', () {
    expect(
      CustomerRoute.parse(Uri(path: '/affiliate_application')).destination,
      'affiliate_application',
    );
  });
  testWidgets(
    'unapproved customers cannot copy a fabricated personal referral link',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TraderAffiliatePerksPage())),
      );
      await settle(tester);
      expect(find.text('Copy Referral Link'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is UiInput && (w.value ?? '').contains('nitish_alpha'),
        ),
        findsNothing,
      );
      expect(find.text('Referral links unlock after approval'), findsOneWidget);
    },
  );
  testWidgets(
    'referred customer signup passes the captured code to the auth repository',
    (tester) async {
      await ConsentController.instance.initialize();
      await ConsentController.instance.save(
        const ConsentPreferences(affiliate: true),
      );
      await AffiliateAttribution.capture('actual-partner', 'weekly-launch');
      final repository = RecordingSignup();
      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            authRepository: repository,
            onSignupSuccess: (_, _, {requiresVerification = false}) {},
            onNavigateToLogin: (_) {},
            onNavigateBack: () {},
          ),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'newtrader');
      await tester.enterText(find.byType(TextField).at(1), 'new@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'TestPassword123');
      await tester.enterText(find.byType(TextField).at(3), 'TestPassword123');
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await settle(tester);
      expect(repository.referral, 'actual-partner');
    },
  );
  testWidgets('approved application status opens the connected Partner Hub', (
    tester,
  ) async {
    await application('approved-app-view', approve: true);
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScaffold(
          userId: 'approved-app-view',
          initialDestination: 'affiliate_application',
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Application approved'), findsOneWidget);
    expect(find.text('Awaiting administrator review'), findsNothing);
    await tester.ensureVisible(find.text('Open Partner Hub'));
    await tester.tap(find.text('Open Partner Hub'));
    await settle(tester);
    expect(find.byType(AffiliateOverviewPage), findsOneWidget);
  });
  testWidgets(
    'rejected application opens with saved details and review notes',
    (tester) async {
      await application('rejected-connection');
      await AffiliateApplicationRepositoryImpl.instance.review(
        applicationId: 'app-rejected-connection',
        approve: false,
        notes: 'Add your channel details',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: AppScaffold(
            userId: 'rejected-connection',
            initialDestination: 'affiliate_application',
          ),
        ),
      );
      await settle(tester);
      expect(find.textContaining('Add your channel details'), findsWidgets);
      expect(
        find
            .byType(TextField)
            .evaluate()
            .map((e) => (e.widget as TextField).controller?.text),
        contains('Connection test'),
      );
    },
  );
  testWidgets(
    'trader workspace preference is restored for an approved account',
    (tester) async {
      final profile = UserProfileModel.fromJson({
        'id': 'restore-partner',
        'handle': 'partner',
        'email': 'partner@example.com',
        'role': 'affiliate',
      });
      await AuthSessionStorage.saveSession(profile: profile);
      await AuthSessionStorage.saveWorkspaceRole(profile.id, UserRole.customer);
      await tester.pumpWidget(const MaterialApp(home: AuthWrapper()));
      await settle(tester);
      final shell = tester.widget<AppScaffold>(find.byType(AppScaffold));
      expect(shell.userRole, UserRole.customer);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
