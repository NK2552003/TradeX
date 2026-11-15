// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/settings/presentation/pages/shared/help_about_page.dart';
import 'package:tradex/features/settings/presentation/widgets/help/publication_reader.dart';
import 'package:tradex/features/settings/presentation/widgets/help/browser_experience_gate.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_attribution.dart';
import 'core/navigation/feature_location_scope.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:tradex/core/config/cross_subdomain_storage.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/core/config/startup_ready.dart';
import 'package:tradex/features/auth/auth.dart';
import 'package:tradex/core/widgets/not_found_page.dart';
import 'package:tradex/core/linking/link_graph.dart';

class TradeXApp extends StatefulWidget {
  const TradeXApp({super.key});

  @override
  State<TradeXApp> createState() => _TradeXAppState();
}

class _TradeXAppState extends State<TradeXApp> {
  UserRole? _activeRole;
  String? _pendingExternalRedirect;

  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/help',
        builder: (context, state) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => finishWebStartup(),
          );
          return const BrowserExperienceGate(
            child: Scaffold(body: HelpAboutPage()),
          );
        },
        routes: [
          GoRoute(
            path: ':document',
            builder: (context, state) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => finishWebStartup(),
              );
              return BrowserExperienceGate(
                suggestInstall: false,
                child: Scaffold(
                  body: PublicationReader(
                    documentId: state.pathParameters['document']!,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/join/:code',
        redirect: (context, state) => Uri(
          pathSegments: ['', 'r', state.pathParameters['code']!],
          queryParameters: state.uri.queryParameters,
        ).toString(),
      ),
      GoRoute(
        path: '/r/:code',
        redirect: (context, state) async {
          final code = state.pathParameters['code']!;
          await AffiliateAttribution.capture(
            code,
            state.uri.queryParameters['utm_campaign'],
          );
          return Uri(
            path: '/auth/signup',
            queryParameters: {
              'ref': code,
              'utm_campaign': ?state.uri.queryParameters['utm_campaign'],
            },
          ).toString();
        },
      ),
      for (final path in [
        '/',
        '/auth/:stage',
        '/community/:kind/:id',
        '/p/:kind/:id',
        '/:destination/:id',
        '/:destination',
      ])
        GoRoute(
          path: path,
          pageBuilder: (context, state) => _routePage(context, state),
        ),
    ],
    errorBuilder: (context, state) {
      WidgetsBinding.instance.addPostFrameCallback((_) => finishWebStartup());
      return NotFoundPage(
        onPrimary: () => _router.go('/workspace'),
        primaryLabel: 'Back to workspace',
      );
    },
  );

  /// Message shown on the login screen when the visitor arrived through a
  /// shared community-post link (directly or via `?next=`).
  String? _loginNotice(Uri uri, CustomerRoute route) {
    final AppLinkOpenRequest? target = uri.path.startsWith('/auth/')
        ? CustomerRoute.afterAuthentication(uri)?.$2.request
        : route.request;
    final profile = route.profileHandle;
    if (target == null && profile == null) return null;
    final label = profile != null ? 'profile' : target!.kind.label.toLowerCase();
    return 'Please sign in or create an account to view this $label. '
        "You'll be taken straight to it after you sign in.";
  }

  Page<void> _routePage(BuildContext context, GoRouterState state) {
    final route = CustomerRoute.parse(
      state.uri,
      host: kIsWeb ? Uri.base.host : null,
    );
    if (!route.valid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => finishWebStartup());
      return NoTransitionPage(
        key: state.pageKey,
        child: NotFoundPage(
          onPrimary: () => _router.go('/workspace'),
          primaryLabel: 'Back to workspace',
        ),
      );
    }
    String location(Uri target) {
      final preview = state.uri.queryParameters['preview'];
      return target
          .replace(
            queryParameters: {
              ...target.queryParameters,
              if (target.path.startsWith('/auth/'))
                'next': state.uri.path.startsWith('/auth/')
                    ? state.uri.queryParameters['next'] ?? '/workspace'
                    : state.uri.toString(),
              'preview': ?preview,
            },
          )
          .toString();
    }

    final String? preview = state.uri.queryParameters['preview'];
    if (kIsWeb && preview == null && state.uri.path.startsWith('/auth/')) {
      final validatedNext = CustomerRoute.afterAuthentication(state.uri);
      if (validatedNext != null) {
        CrossSubdomainState.setFlag(
          'ax_post_auth_next',
          validatedNext.$1.toString(),
          maxAgeDays: 1,
        );
      }
    }

    if (kIsWeb && preview == null) {
      final initialRedirect = CustomerRoute.crossOriginRedirectUri(
        state.uri,
        currentHost: Uri.base.host,
        activeRole: _activeRole,
      );
      if (initialRedirect != null) {
        final targetUrl = initialRedirect.toString();
        if (_pendingExternalRedirect != targetUrl) {
          _pendingExternalRedirect = targetUrl;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            CrossSubdomainState.navigateExternal(targetUrl);
          });
        }
        return NoTransitionPage(
          key: ValueKey('redirect-$targetUrl'),
          child: const SizedBox.shrink(),
        );
      }
    }

    void navigateTarget(Uri target, {UserRole? roleOverride}) {
      if (kIsWeb && preview == null) {
        final redirect = CustomerRoute.crossOriginRedirectUri(
          target,
          currentHost: Uri.base.host,
          activeRole: roleOverride ?? _activeRole,
        );
        if (redirect != null) {
          final targetUrl = redirect.toString();
          if (_pendingExternalRedirect != targetUrl) {
            _pendingExternalRedirect = targetUrl;
            CrossSubdomainState.navigateExternal(targetUrl);
          }
          return;
        }
      }
      _router.go(location(target));
    }

    return NoTransitionPage(
      key: const ValueKey('customer-auth-shell'),
      child: FeatureLocationScope(
        location: state.uri,
        onNavigate: navigateTarget,
        child: BrowserExperienceGate(
          child: AuthWrapper(
            loginNotice: _loginNotice(state.uri, route),
            initialStage: route.stage,
            initialDestination: route.destination,
            openRequest: route.request,
            profileHandle: route.profileHandle,
            onRoleChanged: (role) => _activeRole = role,
            onDestinationChanged: (destination) =>
                navigateTarget(Uri(path: '/$destination')),
            onOpenRecord: (ref) => navigateTarget(CustomerRoute.forRecord(ref)),
            onStageChanged: (stage) {
              if (stage == AuthStage.authenticated) {
                final bool shouldResolveEntry =
                    state.uri.path.startsWith('/auth/') ||
                    state.uri.path == '/' ||
                    state.uri.queryParameters.containsKey('code') ||
                    state.uri.queryParameters.containsKey('error');
                if (!shouldResolveEntry) return;

                Uri? target = CustomerRoute.afterAuthentication(state.uri)?.$1;
                if (target == null && kIsWeb) {
                  final savedNext = CrossSubdomainState.getFlag(
                    'ax_post_auth_next',
                  );
                  if (savedNext != null && savedNext.isNotEmpty) {
                    target = CustomerRoute.afterAuthentication(
                      Uri(queryParameters: {'next': savedNext}),
                    )?.$1;
                  }
                }
                CrossSubdomainState.removeFlag('ax_post_auth_next');

                if (target == null) {
                  final hostSubdomain = kIsWeb
                      ? CustomerRoute.subdomainFromHost(Uri.base.host)
                      : CustomerSubdomain.root;
                  final defaultDest = switch (hostSubdomain) {
                    CustomerSubdomain.community => 'community_feed',
                    CustomerSubdomain.admin => 'overview',
                    CustomerSubdomain.affiliate =>
                      _activeRole == UserRole.affiliate
                          ? 'overview'
                          : 'affiliate_application',
                    CustomerSubdomain.root || CustomerSubdomain.app => switch (
                      _activeRole
                    ) {
                      UserRole.userAdmin => 'overview',
                      UserRole.affiliate => 'overview',
                      _ => route.destination ?? 'workspace',
                    },
                  };
                  target = Uri(path: '/$defaultDest');
                }

                if (target.toString() != state.uri.toString() ||
                    (kIsWeb &&
                        CustomerRoute.crossOriginRedirectUri(
                              target,
                              currentHost: Uri.base.host,
                              activeRole: _activeRole,
                            ) !=
                            null)) {
                  navigateTarget(target);
                }
                return;
              }

              final String? path = switch (stage) {
                AuthStage.login => '/auth/login',
                AuthStage.signup => '/auth/signup',
                AuthStage.forgotPassword => '/auth/forgot-password',
                AuthStage.onboarding => '/',
                _ => null,
              };
              if (path != null && path != state.uri.path) {
                _router.go(location(Uri.parse(path)));
              }
            },
          ),
        ),
      ),
    );
  }

  final AppThemeController _themeController = AppThemeController(
    ThemeMode.dark,
    'Comfortable',
  );

  @override
  void initState() {
    super.initState();
    usePathUrlStrategy();
  }

  @override
  void dispose() {
    _router.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      // Inspector paint flags are global and can survive a hot reload. Keep
      // development-only baselines/bounds out of the product header.
      debugPaintBaselinesEnabled = false;
      debugPaintSizeEnabled = false;
      return true;
    }());
    return AppThemeScope(
      controller: _themeController,
      child: ListenableBuilder(
        listenable: _themeController,
        builder: (context, _) {
          final Brightness systemBrightness =
              MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.dark;
          final bool isDark = switch (_themeController.value) {
            ThemeMode.system => systemBrightness == Brightness.dark,
            ThemeMode.dark => true,
            ThemeMode.light => false,
          };

          final UiSpacing spacing = _themeController.density == 'Compact'
              ? const UiSpacing(
                  none: 0,
                  xxs: 1.5,
                  xs: 3,
                  sm: 6,
                  md: 9,
                  lg: 12,
                  xl: 18,
                  xxl: 24,
                  xxxl: 36,
                )
              : const UiSpacing();

          final UiTheme theme = isDark
              ? UiTheme.dark(spacing: spacing)
              : UiTheme.light(spacing: spacing);

          return UiApp(
            theme: theme,
            builder: (context) => MaterialApp.router(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: UiTheme.light(spacing: spacing).toThemeData(),
              darkTheme: UiTheme.dark(spacing: spacing).toThemeData(),
              themeMode: _themeController.value,
              builder: (context, child) => UiToastScope(
                child: Material(
                  type: MaterialType.transparency,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(decoration: TextDecoration.none),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
