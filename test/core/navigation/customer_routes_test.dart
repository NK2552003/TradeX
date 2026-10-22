import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'package:tradex/features/auth/models/auth_state.dart';

void main() {
  test(
    'shell and authentication paths resolve without bypassing auth gate',
    () {
      expect(
        CustomerRoute.parse(Uri.parse('/community_feed')).destination,
        'community_feed',
      );
      expect(
        CustomerRoute.parse(Uri.parse('/auth/forgot-password')).stage,
        AuthStage.forgotPassword,
      );
      expect(CustomerRoute.parse(Uri.parse('/not-a-real-page')).valid, isFalse);
    },
  );
  test('shared record routes preserve identifiers and public context', () {
    for (final kind in AppLinkKind.values.where(
      (kind) => kind != AppLinkKind.aiCopilot,
    )) {
      final ref = AppLinkRef(
        kind: kind,
        id: 'test record/with space',
        title: 'Record',
        isPublicContext: true,
      );
      final decoded = CustomerRoute.parse(CustomerRoute.forRecord(ref));
      expect(decoded.valid, isTrue);
      expect(decoded.request!.id, ref.id);
      expect(decoded.request!.kind, kind);
      expect(decoded.request!.publicContext, isTrue);
    }
  });
  test('native scheme links use the same record codec', () {
    final route = CustomerRoute.parse(Uri.parse('tradex://note/test-note'));
    expect(route.destination, 'notes');
    expect(route.request!.id, 'test-note');
  });
}
