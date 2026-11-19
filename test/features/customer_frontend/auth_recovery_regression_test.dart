import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/data/repositories/auth_otp_repository.dart';
import 'package:alphajournal/features/auth/models/otp_purpose.dart';
import 'package:alphajournal/features/auth/presentation/pages/forgot_password_page.dart';

class RecoveryFixture implements AuthOtpRepository {
  int sends = 0;
  bool failVerification = false;
  @override
  Future<void> sendOtp({
    required String identifier,
    required OtpPurpose purpose,
  }) async {
    sends++;
  }

  @override
  Future<void> resendOtp({
    required String identifier,
    required OtpPurpose purpose,
  }) => sendOtp(identifier: identifier, purpose: purpose);
  @override
  Future<OtpVerifyResult> verifyOtp({
    required String identifier,
    required OtpPurpose purpose,
    required String code,
  }) async {
    if (failVerification) throw StateError('Offline');
    return const OtpVerifyResult(
      success: true,
      token: 'verified-test-recovery',
    );
  }
}

void main() {
  for (final succeed in [false, true]) {
    testWidgets(
      'recovery reports ${succeed ? 'success only after update' : 'failed password update without fake success'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final otp = RecoveryFixture();
        String? submittedToken;
        await tester.pumpWidget(
          MaterialApp(
            home: ForgotPasswordPage(
              otpRepository: otp,
              onBackToLogin: () {},
              completePasswordReset: (token, password) async {
                submittedToken = token;
                expect(password, 'sample-test-password');
                if (!succeed) throw StateError('Update rejected');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'reader@example.test',
        );
        final send = find.byWidgetPredicate(
          (w) => w is UiButton && w.label.contains('Send'),
        );
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(otp.sends, 1);
        tester.widget<UiOtpField>(find.byType(UiOtpField)).controller!.value =
            '123456';
        await tester.pump();
        final verify = find.byWidgetPredicate(
          (w) => w is UiButton && w.label.contains('Verify'),
        );
        await tester.ensureVisible(verify);
        await tester.tap(verify);
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'sample-test-password');
        await tester.enterText(fields.at(1), 'sample-test-password');
        await tester.ensureVisible(find.text('Update Password'));
        await tester.tap(find.text('Update Password'));
        await tester.pumpAndSettle();
        expect(submittedToken, 'verified-test-recovery');
        expect(
          find.text('Password Updated!'),
          succeed ? findsOneWidget : findsNothing,
        );
        if (!succeed) expect(find.text('Update rejected'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
