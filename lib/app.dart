import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/app_constants.dart';
import 'package:alphajournal/core/config/cross_subdomain_storage.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:alphajournal/core/config/startup_ready.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/core/navigation/customer_routes.dart';
import 'package:alphajournal/core/navigation/feature_location_scope.dart';
import 'package:alphajournal/core/update/app_update.dart';
import 'package:alphajournal/core/widgets/not_found_page.dart';
import 'package:alphajournal/core/widgets/record_unavailable.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:alphajournal/features/auth/auth.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/help_about_page.dart';
import 'package:alphajournal/features/settings/presentation/widgets/help/browser_experience_gate.dart';
import 'package:alphajournal/features/settings/presentation/widgets/help/publication_reader.dart';

class AlphaJournalApp extends StatefulWidget {
  const AlphaJournalApp({
    super.key,
    this.initialThemeMode,
    this.initialZoom = AppZoom.system,
    this.initialTextSize = AppTextSize.system,
  });

  final ThemeMode? initialThemeMode;
  final AppZoom initialZoom;
  final AppTextSize initialTextSize;

  @override
  State<AlphaJournalApp> createState() => _AlphaJournalAppState();
}

class _AlphaJournalAppState extends State<AlphaJournalApp>
    with WidgetsBindingObserver {
  UserRole? _activeRole;
  String? _pendingExternalRedirect;
  final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  late final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
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
    final label = profile != null
        ? 'profile'
        : target!.kind.label.toLowerCase();
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
          child: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.ui.colors.background,
              body: RecordOpeningBanner(
                title: 'Switching workspace...',
                subtitle: 'Connecting to ${initialRedirect.host}',
                badgeLabel: 'Subdomain',
                icon: Icons.swap_horiz_rounded,
              ),
            ),
          ),
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
          CrossSubdomainState.navigateExternal(redirect.toString());
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
                if (!_hadThemeModeCookie && !_cloudHydrated) {
                  _hydrateCloudAppearanceIfUnset();
                }
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
                      (_activeRole == UserRole.affiliate ||
                              _activeRole == UserRole.userAdmin)
                          ? 'overview'
                          : 'affiliate_application',
                    CustomerSubdomain.root ||
                    CustomerSubdomain.app => switch (_activeRole) {
                      UserRole.userAdmin => 'overview',
                      UserRole.affiliate => 'overview',
                      _ => route.destination ?? 'community',
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
  late final bool _hadThemeModeCookie;
  late final bool _hadDensityCookie;
  late final bool _hadRangeCookie;
  late final bool _hadStyleCookie;
  late final bool _hadColorsCookie;
  bool _cloudHydrated = false;
  bool _userOrLocalThemeApplied = false;

  static String? _readInitialPref(String key) =>
      CrossSubdomainState.getFlag(key) ??
      CrossSubdomainState.getLocalPreferenceFallback(key);

  static ThemeMode? _parseThemeMode(String? raw) => switch (raw?.trim()) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    'dark' => ThemeMode.dark,
    _ => null,
  };

  AppThemeController _createThemeController() {
    final savedMode = _readInitialPref('ax_theme_mode');
    final mode =
        _parseThemeMode(savedMode) ??
        widget.initialThemeMode ??
        ThemeMode.system;
    final savedDensity = _readInitialPref('ax_theme_density');
    final density = savedDensity == 'Compact' ? 'Compact' : 'Comfortable';
    final savedRange = _readInitialPref('ax_chart_range');
    final chartRange =
        const <String>{'1D', '1W', '1M', '1Y', 'ALL'}.contains(savedRange)
        ? savedRange!
        : '1D';
    final savedStyle = _readInitialPref('ax_chart_style');
    final chartStyle =
        const <String>{
          'Candlestick',
          'Line',
          'Area',
          'Bars',
        }.contains(savedStyle)
        ? savedStyle!
        : 'Candlestick';
    final savedColors = _readInitialPref('ax_chart_colors');
    final colorConvention =
        const <String>{
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
      AppZoom.fromPreference(_readInitialPref(AppZoom.preferenceKey)) ??
          widget.initialZoom,
      AppTextSize.fromPreference(_readInitialPref(AppTextSize.preferenceKey)) ??
          widget.initialTextSize,
    );
  }

  bool _resolveIsDark([BuildContext? ctx]) {
    final Brightness systemBrightness =
        (ctx != null ? MediaQuery.maybePlatformBrightnessOf(ctx) : null) ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return switch (_themeController.value) {
      ThemeMode.system => systemBrightness == Brightness.dark,
      ThemeMode.dark => true,
      ThemeMode.light => false,
    };
  }

  SystemUiOverlayStyle _systemUiOverlayStyle(bool isDark) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      );

  void _syncSystemUiOverlayStyle([bool? isDark]) {
    if (kIsWeb) return;
    try {
      SystemChrome.setSystemUIOverlayStyle(
        _systemUiOverlayStyle(isDark ?? _resolveIsDark()),
      );
    } catch (_) {}
  }

  void _syncWebThemeDom() {
    final bool isDark = _resolveIsDark();
    CrossSubdomainState.syncWebTheme(
      mode: _themeController.value.name,
      density: _themeController.density,
      isLight: !isDark,
    );
    _syncSystemUiOverlayStyle(isDark);
  }

  void _syncThemeToSubdomains({bool saveLocal = true}) {
    _userOrLocalThemeApplied = true;
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
    _syncWebThemeDom();
    if (saveLocal) {
      _saveAppearancePrefs();
    }
  }

  void _applyAppearanceMapIfUnset(Map<String, dynamic> map) {
    final mode = _parseThemeMode(map['theme_mode'] as String?);
    if (!_hadThemeModeCookie && mode != null) {
      _themeController.setMode(mode);
    }
    final density = map['density'] as String?;
    if (!_hadDensityCookie &&
        (density == 'Compact' || density == 'Comfortable')) {
      _themeController.setDensity(density!);
    }
    final range = map['chart_range'] as String?;
    if (!_hadRangeCookie &&
        const {'1D', '1W', '1M', '1Y', 'ALL'}.contains(range)) {
      _themeController.setChartRange(range!);
    }
    final style = map['chart_style'] as String?;
    if (!_hadStyleCookie &&
        const {'Candlestick', 'Line', 'Area', 'Bars'}.contains(style)) {
      _themeController.setChartStyle(style!);
    }
    final colors = map['color_convention'] as String?;
    if (!_hadColorsCookie &&
        const {
          'Standard (Green/Red)',
          'Colorblind-Safe (Blue/Orange)',
          'Monochrome (High Contrast)',
        }.contains(colors)) {
      _themeController.setColorConvention(colors!);
    }
  }

  Future<void> _hydrateCloudAppearanceIfUnset() async {
    if (_cloudHydrated || _hadThemeModeCookie || _userOrLocalThemeApplied) {
      return;
    }
    _cloudHydrated = true;
    try {
      final client = SupabaseConfig.client;
      final uid = client?.auth.currentUser?.id;
      if (!SupabaseConfig.isConfigured || client == null || uid == null) return;
      final row = await client
          .from('user_app_preferences')
          .select('appearance_extras')
          .eq('user_id', uid)
          .maybeSingle();
      final extras = row?['appearance_extras'];
      if (extras is Map && extras.isNotEmpty && mounted) {
        if (_userOrLocalThemeApplied) return;
        _applyAppearanceMapIfUnset(Map<String, dynamic>.from(extras));
      }
    } catch (_) {}
  }

  Future<void> _hydrateAppearancePrefs() async {
    bool appliedLocal =
        CrossSubdomainState.getLocalPreferenceFallback('ax_theme_mode') != null;
    try {
      final sp = await SharedPreferences.getInstance();
      if (!mounted) return;
      final savedMode = _parseThemeMode(sp.getString('ax_theme_mode'));
      if (savedMode != null && !_hadThemeModeCookie) {
        _themeController.setMode(savedMode);
        appliedLocal = true;
      }
      final savedDensity = sp.getString('ax_theme_density');
      if (savedDensity != null &&
          !_hadDensityCookie &&
          (savedDensity == 'Compact' || savedDensity == 'Comfortable')) {
        _themeController.setDensity(savedDensity);
        appliedLocal = true;
      }
      final savedRange = sp.getString('ax_chart_range');
      if (savedRange != null &&
          !_hadRangeCookie &&
          const {'1D', '1W', '1M', '1Y', 'ALL'}.contains(savedRange)) {
        _themeController.setChartRange(savedRange);
        appliedLocal = true;
      }
      final savedStyle = sp.getString('ax_chart_style');
      if (savedStyle != null &&
          !_hadStyleCookie &&
          const {'Candlestick', 'Line', 'Area', 'Bars'}.contains(savedStyle)) {
        _themeController.setChartStyle(savedStyle);
        appliedLocal = true;
      }
      final savedColors = sp.getString('ax_chart_colors');
      if (savedColors != null &&
          !_hadColorsCookie &&
          const {
            'Standard (Green/Red)',
            'Colorblind-Safe (Blue/Orange)',
            'Monochrome (High Contrast)',
          }.contains(savedColors)) {
        _themeController.setColorConvention(savedColors);
        appliedLocal = true;
      }

      if (!appliedLocal && !_hadThemeModeCookie) {
        await _hydrateCloudAppearanceIfUnset();
      }
    } catch (_) {}
    if (!mounted) return;
    if (_hadThemeModeCookie || appliedLocal) {
      _syncThemeToSubdomains(saveLocal: false);
    } else {
      _syncWebThemeDom();
    }
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
    _hadThemeModeCookie = CrossSubdomainState.getFlag('ax_theme_mode') != null;
    _hadDensityCookie = CrossSubdomainState.getFlag('ax_theme_density') != null;
    _hadRangeCookie = CrossSubdomainState.getFlag('ax_chart_range') != null;
    _hadStyleCookie = CrossSubdomainState.getFlag('ax_chart_style') != null;
    _hadColorsCookie = CrossSubdomainState.getFlag('ax_chart_colors') != null;
    WidgetsBinding.instance.addObserver(this);
    _syncWebThemeDom();
    _hydrateAppearancePrefs();
    _themeController.addListener(_syncThemeToSubdomains);
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeController.value == ThemeMode.system) {
      _syncWebThemeDom();
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _themeController.value == ThemeMode.system) {
      _syncWebThemeDom();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          final bool isDark = _resolveIsDark(context);

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
          final zoom = _themeController.zoom.factor;
          final lightTheme = UiTheme.light(
            colors: lightColors,
            spacing: spacing,
          ).copyWith(zoom: zoom);
          final darkTheme = UiTheme.dark(
            colors: darkColors,
            spacing: spacing,
          ).copyWith(zoom: zoom);

          return UiApp(
            theme: isDark ? darkTheme : lightTheme,
            builder: (context) => MaterialApp.router(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: lightTheme.toThemeData(),
              darkTheme: darkTheme.toThemeData(),
              themeMode: _themeController.value,
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: _systemUiOverlayStyle(isDark),
                  child: MediaQuery(
                    data: media.copyWith(
                      textScaler: _themeController.textSize.resolve(
                        media.textScaler,
                      ),
                    ),
                    child: AppUpdateCoordinator(
                      navigatorKey: _rootNavigatorKey,
                      enabled: EnvConfig.appUpdateChecksEnabled,
                      child: UiToastScope(
                        child: Material(
                          type: MaterialType.transparency,
                          child: DefaultTextStyle.merge(
                            style: const TextStyle(
                              decoration: TextDecoration.none,
                            ),
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
