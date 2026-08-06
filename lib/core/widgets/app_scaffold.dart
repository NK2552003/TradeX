import 'package:flutter/material.dart';
import 'package:tradex/core/config/app_constants.dart';
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        centerTitle: true,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book_outlined), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Watchlists'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Portfolio'),
        ],
      ),
    );
  }
}
