import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/navigation/customer_routes.dart';
import 'package:alphajournal/features/auth/models/auth_state.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';

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
      expect(
        CustomerRoute.parse(
          Uri.parse('https://app.alphajournal.in/auth/callback'),
        ).stage,
        AuthStage.login,
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
    final route = CustomerRoute.parse(
      Uri.parse('alphajournal://note/test-note'),
    );
    expect(route.destination, 'notes');
    expect(route.request!.id, 'test-note');
  });
  test(
    'subdomain routing and role access guards enforce strict boundaries',
    () {
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
    },
  );

  test(
    'app and sibling subdomains resolve when GoRouter passes relative root URI',
    () {
      final appRoute = CustomerRoute.parse(
        Uri(path: '/'),
        host: 'app.alphajournal.in',
      );
      expect(appRoute.destination, 'community');
      expect(appRoute.stage, AuthStage.login);
      expect(
        CustomerRoute.requiredRoleForSubdomain('app.alphajournal.in'),
        isNull,
      );
      expect(
        CustomerRoute.canAccessDestination(
          destination: 'workspace',
          role: UserRole.customer,
          host: 'app.alphajournal.in',
        ),
        isTrue,
      );

      expect(
        CustomerRoute.parse(
          Uri(path: '/'),
          host: 'community.alphajournal.in',
        ).destination,
        'community_feed',
      );
      expect(
        CustomerRoute.parse(
          Uri(path: '/'),
          host: 'admin.alphajournal.in',
        ).destination,
        'admin_console',
      );
      expect(
        CustomerRoute.parse(
          Uri(path: '/'),
          host: 'affiliate.alphajournal.in',
        ).destination,
        'affiliate_application',
      );
    },
  );

  test('destination and record subdomain mapping matches product surfaces', () {
    expect(
      CustomerRoute.subdomainForDestination('workspace'),
      CustomerSubdomain.app,
    );
    expect(
      CustomerRoute.subdomainForDestination('journal'),
      CustomerSubdomain.app,
    );
    expect(
      CustomerRoute.subdomainForDestination('messages'),
      CustomerSubdomain.app,
    );
    expect(
      CustomerRoute.subdomainForDestination('ai_copilot'),
      CustomerSubdomain.app,
    );
    for (final dest in [
      'community',
      'community_feed',
      'community_explore',
      'community_network',
      'community_profile',
      'community_bookmarks',
      'public_profile',
    ]) {
      expect(
        CustomerRoute.subdomainForDestination(dest),
        CustomerSubdomain.community,
        reason: dest,
      );
    }
    for (final dest in [
      'affiliate_application',
      'affiliate_overview',
      'referrals',
      'marketing',
      'payouts',
      'settings_affiliate',
    ]) {
      expect(
        CustomerRoute.subdomainForDestination(dest),
        CustomerSubdomain.affiliate,
        reason: dest,
      );
    }
    for (final dest in [
      'admin_console',
      'admin_comments',
      'affiliate_reviews',
      'org_team',
      'org_audit',
      'settings_platform',
    ]) {
      expect(
        CustomerRoute.subdomainForDestination(dest),
        CustomerSubdomain.admin,
        reason: dest,
      );
    }
    expect(
      CustomerRoute.subdomainForDestination(
        'overview',
        activeRole: UserRole.affiliate,
      ),
      CustomerSubdomain.affiliate,
    );
    expect(
      CustomerRoute.subdomainForDestination(
        'overview',
        activeRole: UserRole.userAdmin,
      ),
      CustomerSubdomain.admin,
    );
    expect(
      CustomerRoute.subdomainForRecord(AppLinkKind.communityPost),
      CustomerSubdomain.community,
    );
    expect(
      CustomerRoute.subdomainForRecord(AppLinkKind.journal),
      CustomerSubdomain.app,
    );
  });

  test(
    'crossOriginRedirectUri transitions between subdomains only when needed',
    () {
      // From apex after login -> app.alphajournal.in/workspace
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/workspace'),
          currentHost: 'alphajournal.in',
        ).toString(),
        'https://app.alphajournal.in/workspace',
      );
      // From app -> community page or post
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/community_feed'),
          currentHost: 'app.alphajournal.in',
        ).toString(),
        'https://community.alphajournal.in/community_feed',
      );
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/community/post/post-42?public=true'),
          currentHost: 'app.alphajournal.in',
        ).toString(),
        'https://community.alphajournal.in/community/post/post-42?public=true',
      );
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/@trader_one'),
          currentHost: 'app.alphajournal.in',
        ).toString(),
        'https://community.alphajournal.in/@trader_one',
      );
      // Inside community subdomain -> SPA navigation (no reload redirect)
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/community_explore'),
          currentHost: 'community.alphajournal.in',
        ),
        isNull,
      );
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/community/post/post-42?public=true'),
          currentHost: 'community.alphajournal.in',
        ),
        isNull,
      );
      // Role workspaces
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/overview'),
          currentHost: 'app.alphajournal.in',
          activeRole: UserRole.affiliate,
        ).toString(),
        'https://affiliate.alphajournal.in/overview',
      );
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/overview'),
          currentHost: 'app.alphajournal.in',
          activeRole: UserRole.userAdmin,
        ).toString(),
        'https://admin.alphajournal.in/overview',
      );
      // Local dev & preview hosts never trigger external subdomain redirects
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/community_feed'),
          currentHost: 'localhost',
        ),
        isNull,
      );
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/workspace'),
          currentHost: 'alphajournal.pages.dev',
        ),
        isNull,
      );
      // Auth, referral, and help routes stay on current origin
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/auth/login'),
          currentHost: 'alphajournal.in',
        ),
        isNull,
      );
      expect(
        CustomerRoute.crossOriginRedirectUri(
          Uri.parse('/r/ABC123'),
          currentHost: 'alphajournal.in',
        ),
        isNull,
      );
    },
  );

  test(
    'afterAuthentication supports validated alphajournal subdomain next URLs',
    () {
      final uri = Uri(
        path: '/auth/login',
        queryParameters: {
          'next':
              'https://community.alphajournal.in/community/post/p-1?public=true',
        },
      );
      final res = CustomerRoute.afterAuthentication(uri);
      expect(res, isNotNull);
      expect(res!.$1.host, 'community.alphajournal.in');
      expect(res.$2.destination, 'community_feed');

      final evil = Uri(
        path: '/auth/login',
        queryParameters: {'next': 'https://evil.com/workspace'},
      );
      expect(CustomerRoute.afterAuthentication(evil), isNull);
    },
  );
}
