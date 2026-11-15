import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'package:tradex/features/auth/models/auth_state.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

void main() {
  test('login retains a validated shared-record return route', () {
    final uri = Uri(
      path: '/auth/login',
      queryParameters: {'next': '/notes/source-note?public=true'},
    );
    final route = CustomerRoute.parse(uri);
    expect(route.stage, AuthStage.login);
    expect(route.destination, 'notes');
    expect(route.request!.id, 'source-note');
    expect(route.request!.publicContext, isTrue);
    expect(
      CustomerRoute.afterAuthentication(uri)!.$1.toString(),
      '/notes/source-note?public=true',
    );
  });
  test(
    'auth return routes reject external, unknown and recursive auth targets',
    () {
      for (final next in [
        'https://example.com',
        '//example.com',
        '/unknown-page',
        '/auth/login?next=/workspace',
        '/\\example.com',
      ]) {
        expect(
          CustomerRoute.afterAuthentication(
            Uri(path: '/auth/login', queryParameters: {'next': next}),
          ),
          isNull,
        );
      }
    },
  );
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
  test('subdomain routing and role access guards enforce strict boundaries', () {
    final adminRoute = CustomerRoute.parse(
      Uri.parse('https://admin.alphajournal.in/'),
    );
    expect(adminRoute.destination, 'admin_console');
    expect(adminRoute.stage, AuthStage.login);
    expect(
      CustomerRoute.requiredRoleForSubdomain('admin.alphajournal.in'),
      UserRole.userAdmin,
    );
    expect(
      CustomerRoute.canAccessDestination(
        destination: 'admin_console',
        role: UserRole.customer,
        host: 'admin.alphajournal.in',
      ),
      isFalse,
    );
    expect(
      CustomerRoute.canAccessDestination(
        destination: 'admin_console',
        role: UserRole.userAdmin,
        host: 'admin.alphajournal.in',
      ),
      isTrue,
    );
    expect(
      CustomerRoute.canAccessDestination(
        destination: 'affiliate_overview',
        role: UserRole.customer,
        host: 'affiliate.alphajournal.in',
      ),
      isFalse,
    );
    expect(
      CustomerRoute.canAccessDestination(
        destination: 'affiliate_application',
        role: UserRole.customer,
        host: 'affiliate.alphajournal.in',
      ),
      isTrue,
    );
  });

  test('app and sibling subdomains resolve when GoRouter passes relative root URI', () {
    final appRoute = CustomerRoute.parse(
      Uri(path: '/'),
      host: 'app.alphajournal.in',
    );
    expect(appRoute.destination, 'workspace');
    expect(appRoute.stage, AuthStage.login);
    expect(CustomerRoute.requiredRoleForSubdomain('app.alphajournal.in'), isNull);
    expect(
      CustomerRoute.canAccessDestination(
        destination: 'workspace',
        role: UserRole.customer,
        host: 'app.alphajournal.in',
      ),
      isTrue,
    );

    expect(
      CustomerRoute.parse(Uri(path: '/'), host: 'community.alphajournal.in').destination,
      'community_feed',
    );
    expect(
      CustomerRoute.parse(Uri(path: '/'), host: 'admin.alphajournal.in').destination,
      'admin_console',
    );
    expect(
      CustomerRoute.parse(Uri(path: '/'), host: 'affiliate.alphajournal.in').destination,
      'affiliate_application',
    );
  });
}
