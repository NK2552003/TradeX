import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/account_access_repository.dart';
import 'package:tradex/core/security/private_messaging_gate.dart';
import 'package:tradex/core/widgets/account_access_gate.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/presentation/pages/splash_screen.dart';

class _Access extends AccountAccessRepository {
  final ready = Completer<AccountAccess>();
  @override
  Future<AccountAccess> load() => ready.future;
  @override
  Future<void> recordDestination(String destination) async {}
}

void main() {
  for (final status in ['active', 'suspended', 'error']) {
    testWidgets(
      'one brand loader holds private content until access resolves: $status',
      (tester) async {
        final repository = _Access();
        await tester.pumpWidget(
          MaterialApp(
            home: AccountAccessGate(
              repository: repository,
              destination: 'community',
              onAccess: (_) {},
              builder: (_) => const Text('Private community'),
            ),
          ),
        );
        expect(find.byType(SplashScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.text('Private community'), findsNothing);
        expect(find.text('Verifying Terminal Session'), findsNothing);
        if (status == 'error') {
          repository.ready.completeError(StateError('offline'));
        } else {
          repository.ready.complete(
            AccountAccess(
              userId: 'test',
              status: status,
              role: UserRole.customer,
              tier: AppTier.free,
              features: {},
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(SplashScreen), findsNothing);
        expect(
          find.text('Private community'),
          status == 'active' ? findsOneWidget : findsNothing,
        );
        if (status == 'error') {
          expect(find.text('Verification Interrupted'), findsOneWidget);
        }
        if (status == 'suspended') {
          expect(find.text('Terminal Access Suspended'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'AccountAccessGate does not wrap global non-E2EE screens in PrivateMessagingGate',
    (tester) async {
      final repository = _Access();
      await tester.pumpWidget(
        MaterialApp(
          home: AccountAccessGate(
            repository: repository,
            destination: 'workspace',
            onAccess: (_) {},
            builder: (_) => const Text('TRADER_WORKSPACE'),
          ),
        ),
      );
      repository.ready.complete(
        AccountAccess(
          userId: 'u1',
          status: 'active',
          role: UserRole.customer,
          tier: AppTier.free,
          features: const {'workspace': true},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PrivateMessagingGate), findsNothing);
      expect(find.text('TRADER_WORKSPACE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
