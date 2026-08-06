enum AppRoute { journal, watchlists, portfolio, login }

class AppRouter {
  static String routeName(AppRoute route) {
    return switch (route) {
      AppRoute.journal => '/journal',
      AppRoute.watchlists => '/watchlists',
      AppRoute.portfolio => '/portfolio',
      AppRoute.login => '/login',
    };
  }
}
