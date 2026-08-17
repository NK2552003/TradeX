enum AppRoute {
  journal,
  watchlists,
  portfolio,
  scanner,
  strategies,
  insights,
  community,
  messages,
  notifications,
  subscriptions,
  enterprise,
  settings,
  login,
}

class AppRouter {
  static String routeName(AppRoute route) {
    return switch (route) {
      AppRoute.journal => '/journal',
      AppRoute.watchlists => '/watchlists',
      AppRoute.portfolio => '/portfolio',
      AppRoute.scanner => '/scanner',
      AppRoute.strategies => '/strategies',
      AppRoute.insights => '/insights',
      AppRoute.community => '/community',
      AppRoute.messages => '/messages',
      AppRoute.notifications => '/notifications',
      AppRoute.subscriptions => '/subscriptions',
      AppRoute.enterprise => '/enterprise',
      AppRoute.settings => '/settings',
      AppRoute.login => '/login',
    };
  }
}
