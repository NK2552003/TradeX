import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tradex/features/auth/presentation/pages/get_started_page.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';
import 'package:tradex/features/auth/presentation/pages/signup_page.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final size in [const Size(320, 740), const Size(740, 320)]) {
    for (final scale in [1.0, 1.5]) {
      for (final page in ['welcome', 'login', 'signup']) {
        testWidgets('$page fits $size with text scale $scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final Widget child = switch (page) {
            'welcome' => GetStartedPage(onGetStarted: (_) {}, onSignIn: () {}),
            'login' => LoginPage(
              onLoginSuccess: (_, _) {},
              onNavigateToSignup: (_) {},
              onNavigateToForgotPassword: () {},
              onNavigateBack: () {},
            ),
            _ => SignupPage(
              onSignupSuccess: (_, _, {bool requiresVerification = false}) {},
              onNavigateToLogin: (_) {},
              onNavigateBack: () {},
            ),
          };
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: child,
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
