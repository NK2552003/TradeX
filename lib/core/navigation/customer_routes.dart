import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/auth/models/auth_state.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'role_navigation_config.dart';

/// URL codec shared by browser navigation and platform deep links.
class CustomerRoute {
  const CustomerRoute({
    this.destination,
    this.request,
    this.stage = AuthStage.splash,
    this.valid = true,
  });
  final String? destination;
  final AppLinkOpenRequest? request;
  final AuthStage stage;
  final bool valid;

  /// Returns the minimum role required when accessing the app from a dedicated
  /// subdomain (`admin.*`, `affiliate.*`, `app.*`, `community.*`), or `null`
  /// when any authenticated/public visitor may enter.
  static UserRole? requiredRoleForSubdomain(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.startsWith('admin.')) return UserRole.userAdmin;
    if (normalized.startsWith('affiliate.')) return UserRole.affiliate;
    return null;
  }

  /// Checks whether [role] (with optional [isApprovedAffiliate] and [isAdmin]
  /// flags) is permitted to access [destination] on [host].
  static bool canAccessDestination({
    required String? destination,
    required UserRole role,
    String host = '',
    bool isApprovedAffiliate = false,
    bool isAdmin = false,
  }) {
    final normalizedHost = host.trim().toLowerCase();
    final effectiveAdmin = isAdmin || role == UserRole.userAdmin;
    final effectiveAffiliate =
        effectiveAdmin || isApprovedAffiliate || role == UserRole.affiliate;

    if (normalizedHost.startsWith('admin.') && !effectiveAdmin) {
      return false;
    }

    if (destination == null || destination.isEmpty) return true;
    if (destination == 'admin_console' || destination.startsWith('admin_')) {
      return effectiveAdmin;
    }
    if (destination == 'affiliate_application') {
      return true;
    }
    if (destination.startsWith('affiliate_')) {
      return effectiveAffiliate;
    }
    return true;
  }

  static CustomerRoute parse(Uri uri) {
    if (uri.scheme == 'tradex' &&
        uri.host == 'auth' &&
        uri.path == '/callback') {
      return const CustomerRoute(destination: 'workspace');
    }
    if (AppDeepLink.isInternal(uri)) {
      final target = AppDeepLink.target(uri);
      return target == null
          ? const CustomerRoute(valid: false)
          : _record(target.kind, target.id, uri);
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      final host = uri.host.toLowerCase();
      if (host.startsWith('community.')) {
        return const CustomerRoute(destination: 'community_feed');
      }
      if (host.startsWith('admin.')) {
        return const CustomerRoute(
          destination: 'admin_console',
          stage: AuthStage.login,
        );
      }
      if (host.startsWith('affiliate.')) {
        return const CustomerRoute(
          destination: 'affiliate_application',
          stage: AuthStage.login,
        );
      }
      if (host.startsWith('app.')) {
        return const CustomerRoute(
          destination: 'workspace',
        );
      }
      return const CustomerRoute();
    }
    if (segments.length == 2 && segments.first == 'auth') {
      final stage = switch (segments[1]) {
        'login' => AuthStage.login,
        'signup' => AuthStage.signup,
        'forgot-password' => AuthStage.forgotPassword,
        _ => null,
      };
      return stage == null
          ? const CustomerRoute(valid: false)
          : CustomerRoute(
              stage: stage,
              destination: afterAuthentication(uri)?.$2.destination,
              request: afterAuthentication(uri)?.$2.request,
            );
    }
    if (segments.length == 3 &&
        segments[0] == 'community' &&
        segments[1] == 'post') {
      return _record(AppLinkKind.communityPost, segments[2], uri);
    }
    if (segments.length == 2) {
      final kind = switch (segments.first) {
        'notes' => AppLinkKind.note,
        'journal' => AppLinkKind.journal,
        'strategies' => AppLinkKind.strategy,
        'market' => AppLinkKind.ticker,
        'messages' => AppLinkKind.messageThread,
        _ => null,
      };
      if (kind != null) return _record(kind, segments[1], uri);
    }
    if (segments.length == 1) {
      final destination = segments.first;
      final known =
          destination == 'affiliate_application' ||
          UserRole.values.any(
            (role) => RoleNavigationConfig.forRole(role).allows(destination),
          );
      if (known) return CustomerRoute(destination: destination);
    }
    return const CustomerRoute(valid: false);
  }

  /// Accept only known local destinations; never redirect to an external URL.
  static (Uri, CustomerRoute)? afterAuthentication(Uri uri) {
    final next = uri.queryParameters['next'];
    if (next == null ||
        !next.startsWith('/') ||
        next.startsWith('//') ||
        next.contains('\\')) {
      return null;
    }
    final target = Uri.tryParse(next);
    if (target == null ||
        target.hasScheme ||
        target.hasAuthority ||
        target.path.startsWith('/auth/')) {
      return null;
    }
    final route = parse(target);
    return route.valid && route.destination != null ? (target, route) : null;
  }

  static CustomerRoute _record(AppLinkKind kind, String id, Uri uri) =>
      CustomerRoute(
        destination: switch (kind) {
          AppLinkKind.note => 'notes',
          AppLinkKind.journal => 'journal',
          AppLinkKind.strategy => 'strategies',
          AppLinkKind.ticker => 'market',
          AppLinkKind.communityPost => 'community_feed',
          AppLinkKind.messageThread => 'messages',
          AppLinkKind.aiCopilot => 'ai_copilot',
        },
        request: AppLinkOpenRequest(
          kind: kind,
          id: id,
          seq: uri.toString().hashCode,
          publicContext:
              kind == AppLinkKind.communityPost ||
              uri.queryParameters['public'] == 'true',
        ),
      );

  static Uri forRecord(AppLinkRef ref) => Uri(
    pathSegments: [
      '',
      ...switch (ref.kind) {
        AppLinkKind.note => ['notes', ref.id],
        AppLinkKind.journal => ['journal', ref.id],
        AppLinkKind.strategy => ['strategies', ref.id],
        AppLinkKind.ticker => ['market', ref.id],
        AppLinkKind.communityPost => ['community', 'post', ref.id],
        AppLinkKind.messageThread => ['messages', ref.id],
        AppLinkKind.aiCopilot => ['ai_copilot'],
      },
    ],
    queryParameters: ref.isPublicContext ? {'public': 'true'} : null,
  );
}
