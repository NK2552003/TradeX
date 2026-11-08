import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';
import 'package:tradex/features/auth/presentation/pages/signup_page.dart';

class _HoverAuthRepository extends AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Hovering a form must not submit authentication.');
}

void main() {
  for (final signup in [false, true]) {
    testWidgets(
      '${signup ? 'Signup' : 'Login'} fields show text cursors and accept input',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _HoverAuthRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: signup
                ? SignupPage(
                    authRepository: repository,
                    onSignupSuccess:
                        (_, _, {bool requiresVerification = false}) {},
                    onNavigateToLogin: (_) {},
                    onNavigateBack: () {},
                  )
                : LoginPage(
                    authRepository: repository,
                    onLoginSuccess: (_, _) {},
                    onNavigateToSignup: (_) {},
                    onNavigateToForgotPassword: () {},
                    onNavigateBack: () {},
                  ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          pointer: 1,
        );
        await mouse.addPointer(location: Offset.zero);
        final inputs = find.byType(UiInput);
        expect(inputs, findsNWidgets(signup ? 4 : 2));
        for (var index = 0; index < inputs.evaluate().length; index++) {
          final input = inputs.at(index);
          await tester.ensureVisible(input);
          await tester.pump();
          final field = find.descendant(
            of: input,
            matching: find.byType(TextField),
          );
          final bounds = tester.getRect(input);
          for (final point in [
            tester.getCenter(field),
            Offset(bounds.left + 2, bounds.center.dy),
          ]) {
            await mouse.moveTo(point);
            await tester.pump();
            expect(
              tester.binding.mouseTracker.debugDeviceActiveCursor(1),
              SystemMouseCursors.text,
            );
          }
          await tester.tap(field);
          await tester.enterText(field, 'example$index');
          await tester.pump();
          expect(
            tester.widget<TextField>(field).controller!.text,
            'example$index',
          );
        }
        expect(tester.takeException(), isNull);
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
