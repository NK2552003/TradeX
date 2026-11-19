import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import '../../data/community_repository.dart';
import '../../models/community_models.dart';

class CommunityNetworkActivity extends StatelessWidget {
  const CommunityNetworkActivity({
    super.key,
    required this.repository,
    required this.postId,
    this.onAuthorTap,
    this.repostedBy,
  });
  final CommunityRepository repository;
  final String postId;
  final String? repostedBy;
  final ValueChanged<CommunityAuthor>? onAuthorTap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) {
      final activity = repository.followedReactionsForPost(postId);
      final first = activity.firstOrNull;
      final reposts = repository.followedRepostsForPost(postId);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reposts.isNotEmpty)
            CommunityActivityRow(
              name: reposts.first.displayName,
              action: reposts.length == 1
                  ? 'reposted this'
                  : 'and ${reposts.length - 1} others you follow reposted this',
              onTap: onAuthorTap == null
                  ? null
                  : () => onAuthorTap!(reposts.first),
            )
          else if (repostedBy?.trim().isNotEmpty ?? false)
            CommunityActivityRow(
              name: repostedBy!.trim(),
              action: 'reposted this',
            ),
          if (activity.isNotEmpty)
            CommunityActivityRow(
              name: first!.author.displayName,
              action: activity.length == 1
                  ? first.activityLabel
                  : 'and ${activity.length - 1} others you follow reacted to this',
              onTap: onAuthorTap == null
                  ? null
                  : () => onAuthorTap!(first.author),
            ),
        ],
      );
    },
  );
}

/// Shared attribution spacing and connector for reactions and reposts.
class CommunityActivityRow extends StatelessWidget {
  const CommunityActivityRow({
    super.key,
    required this.name,
    required this.action,
    this.onTap,
  });
  final String name;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    // The feed already supplies the post separator and top inset. Keep the
    // activity attached to its author header instead of adding a second rule.
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: context.sz(theme.sizes.avatarMd),
              child: Icon(
                Icons.south_rounded,
                size: context.sz(theme.sizes.iconSm),
                color: theme.colors.foregroundSubtle,
              ),
            ),
          ),
          UiGap.h(theme.spacing.sm),
          Expanded(
            child: UiInteractive(
              onTap: onTap,
              builder: (context, _) => Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' $action'),
                  ],
                ),
                style: context.uiText.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
