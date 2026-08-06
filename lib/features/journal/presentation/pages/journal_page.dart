import 'package:flutter/material.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 48),
          SizedBox(height: 12),
          Text('Trading Journal'),
          Text('Log your trades and lessons here.'),
        ],
      ),
    );
  }
}
