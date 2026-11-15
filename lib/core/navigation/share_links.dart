import 'package:tradex/features/auth/models/auth_user_role.dart';

import '../app-ui/models/app_models.dart';
import '../config/app_constants.dart';
import 'customer_routes.dart';

/// Browser links emitted by every share surface, including older URL aliases.
class AppShareLinks {
  const AppShareLinks._();

  /// Canonical `https://<sub>.alphajournal.in/<destination>` URL for a workspace destination.
  static String destinationUrl(
    String destination, {
    UserRole? activeRole,
    String currentHost = '',
  }) {
    final clean = destination.trim().replaceFirst(RegExp(r'^/+'), '');
    final subdomain = CustomerRoute.subdomainForDestination(
      clean,
      activeRole: activeRole,
      currentHost: currentHost,
    );
    if (clean.isEmpty) return subdomain.baseUrl;
    return '${subdomain.baseUrl}/${Uri.encodeComponent(clean)}';
  }

  /// Compact host + path label suitable for cards and watermark stamps.
  static String displayHostAndPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final path = uri.path == '/' ? '' : uri.path;
    return '${uri.host}$path';
  }

  static String record(AppLinkRef ref) => Uri.parse(
        CustomerRoute.subdomainForRecord(ref.kind).baseUrl,
      )
      .resolveUri(
        Uri(
          pathSegments: [
            '',
            ...switch (ref.kind) {
              AppLinkKind.note => ['notes', ref.id],
              AppLinkKind.journal => ['journal', ref.id],
              AppLinkKind.strategy => ['strategies', ref.id],
              AppLinkKind.communityPost => ['community', 'post', ref.id],
              AppLinkKind.ticker => ['market', ref.id],
              AppLinkKind.messageThread => ['messages', ref.id],
              AppLinkKind.aiCopilot => ['ai_copilot'],
            },
          ],
          queryParameters:
              ref.isPublicContext || ref.kind == AppLinkKind.communityPost
              ? {'public': 'true'}
              : null,
        ),
      )
      .toString();

  static String profile(String handle) =>
      '${CustomerSubdomain.community.baseUrl}/@${Uri.encodeComponent(handle.trim().replaceFirst(RegExp(r'^@+'), ''))}';

  static String referral(String code) =>
      '${AppConstants.appUrl}/r/${Uri.encodeComponent(code.trim())}';

  static String? profileHandle(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length != 1 || !segments.first.startsWith('@')) return null;
    final handle = segments.first.substring(1);
    return RegExp(r'^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$').hasMatch(handle)
        ? handle
        : null;
  }

  static ({AppLinkKind kind, String id, bool publicContext})? target(Uri uri) {
    final segments = uri.pathSegments.toList();
    if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
    var publicContext = uri.queryParameters['public'] == 'true';
    if (segments.length == 2 && segments.first == 'p') {
      return (
        kind: AppLinkKind.communityPost,
        id: segments[1],
        publicContext: true,
      );
    }
    if (segments.length == 3 &&
        (segments.first == 'p' || segments.first == 'community')) {
      segments.removeAt(0);
      publicContext = true;
    }
    if (segments.length != 2 || segments[1].trim().isEmpty) return null;
    final kind = switch (segments.first.toLowerCase()) {
      'note' || 'notes' => AppLinkKind.note,
      'journal' || 'trade' || 'trades' || 'entry' => AppLinkKind.journal,
      'strategy' || 'strategies' || 'playbook' => AppLinkKind.strategy,
      'market' || 'ticker' || 'tickers' || 'symbol' => AppLinkKind.ticker,
      'post' ||
      'posts' ||
      'community' ||
      'communitypost' => AppLinkKind.communityPost,
      'message' || 'messages' || 'thread' => AppLinkKind.messageThread,
      'ai' || 'copilot' => AppLinkKind.aiCopilot,
      _ => null,
    };
    return kind == null
        ? null
        : (
            kind: kind,
            id: segments[1],
            publicContext: publicContext || kind == AppLinkKind.communityPost,
          );
  }
}
