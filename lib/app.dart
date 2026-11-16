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
import 'package:shared_preferences/shared_preferences.dart';
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

  late final AppThemeController _themeController = _createThemeController();

  static AppThemeController _createThemeController() {
    final savedMode = CrossSubdomainState.getFlag('ax_theme_mode');
    final mode = switch (savedMode) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
    final savedDensity = CrossSubdomainState.getFlag('ax_theme_density');
    final density = savedDensity == 'Compact' ? 'Compact' : 'Comfortable';
    final savedRange = CrossSubdomainState.getFlag('ax_chart_range');
    final chartRange = const <String>{
      '1D',
      '1W',
      '1M',
      '1Y',
      'ALL',
    }.contains(savedRange)
        ? savedRange!
        : '1D';
    final savedStyle = CrossSubdomainState.getFlag('ax_chart_style');
    final chartStyle = const <String>{
      'Candlestick',
      'Line',
      'Area',
      'Bars',
    }.contains(savedStyle)
        ? savedStyle!
        : 'Candlestick';
    final savedColors = CrossSubdomainState.getFlag('ax_chart_colors');
    final colorConvention = const <String>{
      'Standard (Green/Red)',
      'Colorblind-Safe (Blue/Orange)',
      'Monochrome (High Contrast)',
    }.contains(savedColors)
        ? savedColors!
        : 'Standard (Green/Red)';
    return AppThemeController(
      mode,
      density,
      chartRange,
      chartStyle,
      colorConvention,
    );
  }

  void _syncThemeToSubdomains() {
    CrossSubdomainState.setFlag(
      'ax_theme_mode',
      _themeController.value.name,
      maxAgeDays: 180,
    );
    CrossSubdomainState.setFlag(
      'ax_theme_density',
      _themeController.density,
      maxAgeDays: 180,
    );
    CrossSubdomainState.setFlag(
      'ax_chart_range',
      _themeController.chartRange,
      maxAgeDays: 180,
    );
    CrossSubdomainState.setFlag(
      'ax_chart_style',
      _themeController.chartStyle,
      maxAgeDays: 180,
    );
    CrossSubdomainState.setFlag(
      'ax_chart_colors',
      _themeController.colorConvention,
      maxAgeDays: 180,
    );
    _saveAppearancePrefs();
  }

  Future<void> _hydrateAppearancePrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!mounted) return;
      final savedMode = sp.getString('ax_theme_mode');
      if (savedMode != null && CrossSubdomainState.getFlag('ax_theme_mode') == null) {
        final mode = switch (savedMode) {
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          'dark' => ThemeMode.dark,
          _ => null,
        };
        if (mode != null) _themeController.setMode(mode);
      }
      final savedDensity = sp.getString('ax_theme_density');
      if (savedDensity != null &&
          CrossSubdomainState.getFlag('ax_theme_density') == null &&
          (savedDensity == 'Compact' || savedDensity == 'Comfortable')) {
        _themeController.setDensity(savedDensity);
      }
      final savedRange = sp.getString('ax_chart_range');
      if (savedRange != null &&
          CrossSubdomainState.getFlag('ax_chart_range') == null &&
          const {'1D', '1W', '1M', '1Y', 'ALL'}.contains(savedRange)) {
        _themeController.setChartRange(savedRange);
      }
      final savedStyle = sp.getString('ax_chart_style');
      if (savedStyle != null &&
          CrossSubdomainState.getFlag('ax_chart_style') == null &&
          const {'Candlestick', 'Line', 'Area', 'Bars'}.contains(savedStyle)) {
        _themeController.setChartStyle(savedStyle);
      }
      final savedColors = sp.getString('ax_chart_colors');
      if (savedColors != null &&
          CrossSubdomainState.getFlag('ax_chart_colors') == null &&
          const {
            'Standard (Green/Red)',
            'Colorblind-Safe (Blue/Orange)',
            'Monochrome (High Contrast)',
          }.contains(savedColors)) {
        _themeController.setColorConvention(savedColors);
      }
    } catch (_) {}
  }

  Future<void> _saveAppearancePrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('ax_theme_mode', _themeController.value.name);
      await sp.setString('ax_theme_density', _themeController.density);
      await sp.setString('ax_chart_range', _themeController.chartRange);
      await sp.setString('ax_chart_style', _themeController.chartStyle);
      await sp.setString('ax_chart_colors', _themeController.colorConvention);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    usePathUrlStrategy();
    _hydrateAppearancePrefs();
    _themeController.addListener(_syncThemeToSubdomains);
  }

  @override
  void dispose() {
    _themeController.removeListener(_syncThemeToSubdomains);
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

          final UiColors lightColors = UiColors.light().withMarketConvention(
            _themeController.colorConvention,
            Brightness.light,
          );
          final UiColors darkColors = UiColors.dark().withMarketConvention(
            _themeController.colorConvention,
            Brightness.dark,
          );
          final UiTheme theme = isDark
              ? UiTheme.dark(colors: darkColors, spacing: spacing)
              : UiTheme.light(colors: lightColors, spacing: spacing);

          return UiApp(
            theme: theme,
            builder: (context) => MaterialApp.router(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: UiTheme.light(
                colors: lightColors,
                spacing: spacing,
              ).toThemeData(),
              darkTheme: UiTheme.dark(
                colors: darkColors,
                spacing: spacing,
              ).toThemeData(),
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
