import 'package:flutter/material.dart';

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 48),
          SizedBox(height: 12),
          Text('Portfolio'),
          Text('Review your growth and performance.'),
        ],
      ),
    );
  }
}
