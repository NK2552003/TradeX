import 'package:flutter/material.dart';

class WatchlistsPage extends StatelessWidget {
  const WatchlistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt_outlined, size: 48),
          SizedBox(height: 12),
          Text('Watchlists'),
          Text('Track your favorite tickers and alerts.'),
        ],
      ),
    );
  }
}
