import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/app_constants.dart';
import 'package:alphajournal/core/config/subdomain_cookie_codec.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/features/auth/models/auth_state.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'role_navigation_config.dart';
import 'share_links.dart';

/// Canonical web host surface for each product area on `alphajournal.in`.
enum CustomerSubdomain {
  root,
  app,
  community,
  affiliate,
  admin;

  String get host => switch (this) {
    CustomerSubdomain.root => AppConstants.rootDomain,
    CustomerSubdomain.app => 'app.${AppConstants.rootDomain}',
    CustomerSubdomain.community => 'community.${AppConstants.rootDomain}',
    CustomerSubdomain.affiliate => 'affiliate.${AppConstants.rootDomain}',
    CustomerSubdomain.admin => 'admin.${AppConstants.rootDomain}',
  };

  String get baseUrl => 'https://$host';
}

/// URL codec shared by browser navigation and platform deep links.
class CustomerRoute {
  const CustomerRoute({
    this.destination,
    this.request,
    this.profileHandle,
    this.stage = AuthStage.splash,
    this.valid = true,
  });
  final String? destination;
  final String? profileHandle;
  final AppLinkOpenRequest? request;
  final AuthStage stage;
  final bool valid;

  /// Returns `true` when [host] is `alphajournal.in` or a subdomain of it.
  static bool isAlphajournalHost(String host) =>
      SubdomainCookieCodec.isProductionDomain(host);

  /// Identifies the canonical subdomain represented by [host].
  static CustomerSubdomain subdomainFromHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.startsWith('community.')) return CustomerSubdomain.community;
    if (normalized.startsWith('affiliate.')) return CustomerSubdomain.affiliate;
    if (normalized.startsWith('admin.')) return CustomerSubdomain.admin;
    if (normalized.startsWith('app.')) return CustomerSubdomain.app;
    return CustomerSubdomain.root;
  }

  /// Resolves the canonical subdomain for a linked record [kind].
  static CustomerSubdomain subdomainForRecord(AppLinkKind kind) =>
      switch (kind) {
        AppLinkKind.communityPost => CustomerSubdomain.community,
        _ => CustomerSubdomain.app,
      };

  /// Resolves which `alphajournal.in` subdomain owns [destination].
  static CustomerSubdomain subdomainForDestination(
    String? destination, {
    UserRole? activeRole,
    String currentHost = '',
  }) {
    final normalized = (destination ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return subdomainFromHost(currentHost);
    }
    if (normalized == 'community' ||
        normalized.startsWith('community_') ||
        normalized == 'public_profile') {
      return CustomerSubdomain.community;
    }
    if (normalized == 'admin_console' ||
        normalized == 'affiliate_reviews' ||
        normalized == 'settings_platform' ||
        normalized.startsWith('admin_') ||
        normalized.startsWith('org_')) {
      return CustomerSubdomain.admin;
    }
    if (normalized == 'affiliate_application' ||
        normalized == 'referrals' ||
        normalized == 'marketing' ||
        normalized == 'payouts' ||
        normalized == 'settings_affiliate' ||
        normalized.startsWith('affiliate_')) {
      return CustomerSubdomain.affiliate;
    }
    if (normalized == 'overview') {
      if (activeRole == UserRole.userAdmin) {
        return CustomerSubdomain.admin;
      }
      if (activeRole == UserRole.affiliate) {
        return CustomerSubdomain.affiliate;
      }
      if (activeRole == UserRole.customer) {
        return CustomerSubdomain.app;
      }
      if (currentHost.trim().toLowerCase().startsWith('admin.')) {
        return CustomerSubdomain.admin;
      }
      return CustomerSubdomain.affiliate;
    }
    if (normalized == 'settings' ||
        normalized == 'settings_profile' ||
        normalized == 'settings_security' ||
        normalized == 'settings_trading' ||
        normalized == 'settings_ai' ||
        normalized == 'settings_notifications' ||
        normalized == 'settings_privacy' ||
        normalized == 'settings_appearance' ||
        normalized == 'settings_help') {
      final current = subdomainFromHost(currentHost);
      if (current == CustomerSubdomain.admin ||
          current == CustomerSubdomain.affiliate) {
        return current;
      }
      return CustomerSubdomain.app;
    }
    return CustomerSubdomain.app;
  }

  /// Returns an absolute `https://<sub>.alphajournal.in/...` URI when [target]
  /// belongs to a different subdomain than [currentHost], or `null` when the
  /// router can handle [target] in-place via SPA navigation.
  ///
  /// Returns `null` on localhost / preview deploys (`*.pages.dev`, `*.workers.dev`)
  /// unless [requireProductionHost] is `false`.
  static Uri? crossOriginRedirectUri(
    Uri target, {
    required String currentHost,
    UserRole? activeRole,
    bool requireProductionHost = true,
  }) {
    final normalizedHost = currentHost.trim().toLowerCase();
    if (requireProductionHost && !isAlphajournalHost(normalizedHost)) {
      return null;
    }

    final path = target.path.isEmpty ? '/' : target.path;
    if (path == '/' ||
        path.startsWith('/auth/') ||
        path.startsWith('/r/') ||
        path.startsWith('/join/') ||
        path == '/help' ||
        path.startsWith('/help/')) {
      return null;
    }

    final parsed = parse(
      target,
      host: target.host.isNotEmpty ? target.host : normalizedHost,
    );
    if (!parsed.valid) return null;

    final CustomerSubdomain targetSubdomain;
    if (parsed.request != null) {
      targetSubdomain = subdomainForRecord(parsed.request!.kind);
    } else if (parsed.profileHandle != null) {
      targetSubdomain = CustomerSubdomain.community;
    } else if (parsed.destination != null) {
      targetSubdomain = subdomainForDestination(
        parsed.destination,
        activeRole: activeRole,
        currentHost: normalizedHost,
      );
    } else {
      return null;
    }

    if (targetSubdomain == CustomerSubdomain.root) return null;
    final targetHost = targetSubdomain.host;
    if (targetHost == normalizedHost) return null;

    return Uri(
      scheme: 'https',
      host: targetHost,
      path: path,
      queryParameters: target.queryParameters.isEmpty
          ? null
          : target.queryParameters,
    );
  }

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

  static CustomerRoute parse(Uri uri, {String? host}) {
    if (uri.scheme == 'alphajournal' &&
        uri.host == 'auth' &&
        uri.path == '/callback') {
      return const CustomerRoute(destination: 'workspace');
    }
    if (uri.scheme == AppDeepLink.scheme) {
      final target = AppDeepLink.target(uri);
      return target == null
          ? const CustomerRoute(valid: false)
          : _record(target.kind, target.id, uri);
    }
    final shared = AppShareLinks.target(uri);
    if (shared != null) {
      return _record(
        shared.kind,
        shared.id,
        uri,
        publicContext: shared.publicContext,
      );
    }
    final handle = AppShareLinks.profileHandle(uri);
    if (handle != null) {
      return CustomerRoute(
        destination: 'public_profile',
        profileHandle: handle,
      );
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      final effectiveHost = (uri.host.isNotEmpty ? uri.host : (host ?? ''))
          .trim()
          .toLowerCase();
      if (effectiveHost.startsWith('community.')) {
        return const CustomerRoute(destination: 'community_feed');
      }
      if (effectiveHost.startsWith('admin.')) {
        return const CustomerRoute(
          destination: 'admin_console',
          stage: AuthStage.login,
        );
      }
      if (effectiveHost.startsWith('affiliate.')) {
        return const CustomerRoute(
          destination: 'affiliate_application',
          stage: AuthStage.login,
        );
      }
      if (effectiveHost.startsWith('app.')) {
        return const CustomerRoute(
          destination: 'workspace',
          stage: AuthStage.login,
        );
      }
      return const CustomerRoute();
    }
    if (segments.length == 2 && segments.first == 'auth') {
      final stage = switch (segments[1]) {
        'login' => AuthStage.login,
        'signup' => AuthStage.signup,
        'forgot-password' => AuthStage.forgotPassword,
        // Verified App/Universal Link target used by native OAuth callbacks.
        // Auth state is consumed by Supabase before this route is rendered.
        'callback' => AuthStage.login,
        _ => null,
      };
      return stage == null
          ? const CustomerRoute(valid: false)
          : CustomerRoute(
              stage: stage,
              destination: afterAuthentication(uri)?.$2.destination,
              request: afterAuthentication(uri)?.$2.request,
              profileHandle: afterAuthentication(uri)?.$2.profileHandle,
            );
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

  /// Accept only known local or verified `alphajournal.in` subdomain
  /// destinations; never redirect to an external URL.
  static (Uri, CustomerRoute)? afterAuthentication(Uri uri) {
    final next = uri.queryParameters['next'];
    if (next == null || next.startsWith('//') || next.contains('\\')) {
      return null;
    }
    final target = Uri.tryParse(next);
    if (target == null) return null;
    if (target.hasScheme || target.hasAuthority) {
      if (target.scheme != 'https' ||
          !isAlphajournalHost(target.host) ||
          target.path.startsWith('/auth/')) {
        return null;
      }
      final route = parse(target);
      return route.valid && route.destination != null ? (target, route) : null;
    }
    if (!next.startsWith('/') || target.path.startsWith('/auth/')) {
      return null;
    }
    final route = parse(target);
    return route.valid && route.destination != null ? (target, route) : null;
  }

  static CustomerRoute _record(
    AppLinkKind kind,
    String id,
    Uri uri, {
    bool publicContext = false,
  }) => CustomerRoute(
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
          publicContext ||
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
