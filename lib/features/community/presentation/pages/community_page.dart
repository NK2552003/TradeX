import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/mock_data.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community Feed',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'Share trade ideas, strategies and market discussions with traders',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              UiButton(
                label: 'Create Post',
                leadingIcon: Icons.edit_note,
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                onPressed: () {
                  UiToast.show(
                    context,
                    title: 'New Post',
                    message: 'Post creation modal opened',
                    intent: UiIntent.info,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Navigation Switcher
          UiTabs(
            items: const [
              UiTabItem(label: 'Trending Feed'),
              UiTabItem(label: 'Following'),
              UiTabItem(label: 'Trade Analyses'),
              UiTabItem(label: 'Saved Bookmarks'),
            ],
            selectedIndex: _selectedTabIndex,
            onChanged: (idx) => setState(() => _selectedTabIndex = idx),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Post Cards Feed
          AppPostCard(
            post: mockPost,
            onLike: () {
              UiToast.show(context, title: 'Liked Post', message: 'Added to your liked posts');
            },
          ),
        ],
      ),
    );
  }
}
