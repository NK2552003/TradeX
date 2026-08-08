import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class CommunityBlocksExampleView extends StatelessWidget {
  const CommunityBlocksExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppFeedBlock Example', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppFeedBlock(
            posts: <AppPost>[
              AppPost(
                id: 'p1',
                author: const AppTrader(id: 'u1', handle: '@nitish', displayName: 'Nitish Kumar'),
                body: 'NVDA breaking out of key resistance @ \$125! Target set at \$135.',
                createdAt: DateTime.now(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
