import 'core/navigation/feature_location_scope.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/features/auth/auth.dart';

class TradeXApp extends StatefulWidget {
  const TradeXApp({super.key});

  @override
  State<TradeXApp> createState() => _TradeXAppState();
}

class _TradeXAppState extends State<TradeXApp> {
  late final GoRouter _router = GoRouter(
    routes: [
      for (final path in [
        '/',
        '/auth/:stage',
        '/community/post/:id',
        '/:destination/:id',
        '/:destination',
      ])
        GoRoute(
          path: path,
          pageBuilder: (context, state) => _routePage(context, state),
        ),
    ],
    errorBuilder: (context, state) => const UiEmptyState(
      title: 'Page not found',
      message: 'Check the link and try again.',
    ),
  );

  Page<void> _routePage(BuildContext context, GoRouterState state) {
    final route = CustomerRoute.parse(state.uri);
    if (!route.valid) {
      return NoTransitionPage(
        key: state.pageKey,
        child: UiEmptyState(
          title: 'Page not found',
          action: UiButton(
            label: 'Go to workspace',
            onPressed: () => _router.go('/workspace'),
          ),
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

    return NoTransitionPage(
      key: const ValueKey('customer-auth-shell'),
      child: FeatureLocationScope(
        location: state.uri,
        onNavigate: (target) => _router.go(location(target)),
        child: AuthWrapper(
          initialStage: route.stage,
          initialDestination: route.destination,
          openRequest: route.request,
          onDestinationChanged: (destination) =>
              _router.go(location(Uri(path: '/$destination'))),
          onOpenRecord: (ref) =>
              _router.go(location(CustomerRoute.forRecord(ref))),
          onStageChanged: (stage) {
            final String? path = switch (stage) {
              AuthStage.login => '/auth/login',
              AuthStage.signup => '/auth/signup',
              AuthStage.forgotPassword => '/auth/forgot-password',
              AuthStage.onboarding => '/',
              AuthStage.authenticated
                  when state.uri.path.startsWith('/auth/') =>
                CustomerRoute.afterAuthentication(state.uri)?.$1.toString() ??
                    '/workspace',
              _ => null,
            };
            if (path != null && path != state.uri.path) {
              _router.go(location(Uri.parse(path)));
            }
          },
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
              builder: (context, child) =>
                  UiToastScope(child: child ?? const SizedBox.shrink()),
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
