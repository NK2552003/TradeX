import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_application_repository.dart';
import 'package:tradex/features/admin_console/models/admin_records.dart';
import '../../helpers/admin_repository_fixture.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_application_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_approvals_page.dart';
import '../../helpers/workspace_design_harness.dart';
import '../admin_console/admin_affiliate_interaction_audit_test.dart'
    show tapLabel, enterField;

class DesignApplicationRepository extends Fake
    implements AffiliateApplicationRepository {
  AffiliateApplicationModel application = AffiliateApplicationModel.fromJson({
    'id': 'design-application',
    'user_id': 'design-partner',
    'full_name': 'Design Partner',
    'email': 'design@example.com',
    'phone': '9876543210',
    'city': 'Mumbai',
    'state': 'Maharashtra',
    'date_of_birth': '1995-04-18',
    'gender': 'Prefer not to say',
    'platforms': ['YouTube'],
    'primary_platform': 'YouTube',
    'channel_handle': '@design-partner',
    'audience_reach': '10,000 – 100,000',
    'niches': ['Trading education'],
    'account_holder': 'Design Partner',
    'bank_name': 'HDFC Bank',
    'account_number': '123456789012',
    'ifsc': 'HDFC0001234',
    'account_type': 'Savings',
    'pan': 'ABCDE1234F',
    'upi_id': 'design@bank',
  });
  @override
  Future<AffiliateApplicationModel?> getForUser(String userId) async =>
      application;
  @override
  Future<List<AffiliateApplicationModel>> listApplications() async => [
    application,
  ];
  @override
  Future<AffiliateApplicationModel> submit(
    AffiliateApplicationModel value,
  ) async =>
      application = value.copyWith(status: AffiliateApplicationStatus.pending);
  @override
  Future<AffiliateApplicationModel> review({
    required String applicationId,
    required bool approve,
    String? notes,
  }) async => application = application.copyWith(
    status: approve
        ? AffiliateApplicationStatus.approved
        : AffiliateApplicationStatus.rejected,
    reviewNotes: notes,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadWorkspaceFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CustomerDataPolicy.allowDemo = true;
  });
  tearDown(() => CustomerDataPolicy.allowDemo = false);
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'application all steps and review at $width using preview data',
      (tester) async {
        final repository = DesignApplicationRepository();
        await pumpWorkspace(
          tester,
          AffiliateApplicationPage(
            userId: 'design-partner',
            email: 'design@example.com',
            displayName: 'Design Partner',
            repository: repository,
          ),
          width: width,
          paneWidth: width,
        );
        final verify = find.byTooltip('Verify +91 mobile via OTP');
        await tester.ensureVisible(verify);
        await tester.tap(verify);
        await settleWorkspace(tester);
        await enterField(tester, '6-Digit Verification OTP', '123456');
        await tapLabel(tester, 'Verify Mobile');
        await tapLabel(tester, 'Continue');
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is UiField && widget.label == 'Promotion channels',
          ),
          findsOneWidget,
        );
        await captureWorkspace(tester, 'application-presence-${width.toInt()}');
        await scrollWorkspace(tester);
        await tapLabel(tester, 'Continue');
        expect(find.text('Payout and tax details'), findsOneWidget);
        await captureWorkspace(tester, 'application-bank-${width.toInt()}');
        await enterField(tester, 'Confirm account number', '123456789012');
        await tapLabel(tester, 'Continue');
        final terms = find.byType(UiCheckbox).last;
        await tester.ensureVisible(terms);
        await tester.tap(terms);
        await settleWorkspace(tester);
        await captureWorkspace(tester, 'application-review-${width.toInt()}');
        await tapLabel(tester, 'Submit Application');
        await captureWorkspace(
          tester,
          'application-submitted-${width.toInt()}',
        );
        expect(
          repository.application.status,
          AffiliateApplicationStatus.pending,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('approval detail records the decision and reason at $width', (
      tester,
    ) async {
      final repository = AdminRepositoryFixture();
      await pumpWorkspace(
        tester,
        AffiliateApprovalsPage(repository: repository),
        width: width,
        paneWidth: width,
      );
      await tapLabel(tester, 'Details');
      expect(find.text('9012'), findsOneWidget);
      await tapLabel(tester, 'Approve affiliate');
      await enterField(
        tester,
        'Reason for this change',
        'Application reviewed and approved',
      );
      await captureWorkspace(tester, 'affiliate-approval-${width.toInt()}');
      await tapLabel(tester, 'Confirm');
      expect(
        repository.records[AdminResource.applications]!.single['status'],
        'approved',
      );
      expect(
        repository.changes.single['reason'],
        'Application reviewed and approved',
      );
      expect(find.text('Approve affiliate'), findsNothing);
      await tapLabel(tester, 'Manage this user');
      expect(find.text('Account controls'), findsOneWidget);
    });
  }
  for (final status in [
    AffiliateApplicationStatus.pending,
    AffiliateApplicationStatus.approved,
    AffiliateApplicationStatus.suspended,
  ]) {
    testWidgets('${status.name} application status at 320px with larger text', (
      tester,
    ) async {
      final repository = DesignApplicationRepository();
      repository.application = repository.application.copyWith(status: status);
      await pumpWorkspace(
        tester,
        AffiliateApplicationPage(
          userId: 'design-partner',
          email: 'design@example.com',
          displayName: 'Design Partner',
          repository: repository,
        ),
        width: 320,
        paneWidth: 320,
        textScale: 1.5,
      );
      await scrollWorkspace(tester);
      await captureWorkspace(tester, 'application-${status.name}-large-text');
      expect(tester.takeException(), isNull);
    });
  }
}
