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
    if (segments.isEmpty) return const CustomerRoute();
    if (segments.length == 2 && segments.first == 'auth') {
      final stage = switch (segments[1]) {
        'login' => AuthStage.login,
        'signup' => AuthStage.signup,
        'forgot-password' => AuthStage.forgotPassword,
        _ => null,
      };
      return stage == null
          ? const CustomerRoute(valid: false)
          : CustomerRoute(stage: stage);
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
      final known = UserRole.values.any(
        (role) => RoleNavigationConfig.forRole(role).allows(destination),
      );
      if (known) return CustomerRoute(destination: destination);
    }
    return const CustomerRoute(valid: false);
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
