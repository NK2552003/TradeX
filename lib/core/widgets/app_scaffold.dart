import 'package:flutter/material.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/showcase/numbered_component_showcase_page.dart';
import 'package:tradex/features/journal/presentation/pages/journal_page.dart';
import 'package:tradex/features/portfolio/presentation/pages/portfolio_page.dart';
import 'package:tradex/features/watchlists/presentation/pages/watchlists_page.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    JournalPage(),
    WatchlistsPage(),
    PortfolioPage(),
    NumberedComponentShowcasePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Scaffold(
      key: const ValueKey<String>(AppConstants.appName),
      backgroundColor: theme.colors.background,
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.book_outlined), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Watchlists'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Portfolio'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Showcase (133)'),
        ],
      ),
    );
  }
}
