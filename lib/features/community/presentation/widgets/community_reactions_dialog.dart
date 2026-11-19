import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import '../../data/community_repository.dart';
import '../../models/community_activity.dart';
import '../../models/community_models.dart';
import 'community_follow_button.dart';

class CommunityReactionsDialog extends StatefulWidget {
  const CommunityReactionsDialog({
    super.key,
    required this.repository,
    required this.targetId,
    this.comment = false,
    this.onAuthorTap,
  });
  final CommunityRepository repository;
  final String targetId;
  final bool comment;
  final ValueChanged<CommunityAuthor>? onAuthorTap;

  static Future<void> show(
    BuildContext context, {
    required CommunityRepository repository,
    required String targetId,
    bool comment = false,
    ValueChanged<CommunityAuthor>? onAuthorTap,
  }) => UiDialog.show<void>(
    context,
    maxWidth: 640,
    child: CommunityReactionsDialog(
      repository: repository,
      targetId: targetId,
      comment: comment,
      onAuthorTap: onAuthorTap,
    ),
  );

  @override
  State<CommunityReactionsDialog> createState() =>
      _CommunityReactionsDialogState();
}

class _CommunityReactionsDialogState extends State<CommunityReactionsDialog> {
  late Future<List<CommunityReaction>> _request;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _request = widget.repository.fetchReactions(
      widget.targetId,
      comment: widget.comment,
    );
  }

  @override
  Widget build(BuildContext context) => UiDialog(
    title: 'Reactions',
    content: FutureBuilder<List<CommunityReaction>>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
                  child: const UiSkeleton(height: 56),
                ),
            ],
          );
        }
        if (snapshot.hasError) {
          return UiCallout(
            title: 'Could not load reactions',
            message: 'Please try again.',
            intent: UiIntent.danger,
            action: UiButton(
              label: 'Retry',
              onPressed: () => setState(() {
                _request = widget.repository.fetchReactions(
                  widget.targetId,
                  comment: widget.comment,
                );
              }),
            ),
          );
        }
        final reactions = snapshot.data ?? [];
        final counts = <String, int>{};
        for (final item in reactions) {
          counts.update(item.reaction, (value) => value + 1, ifAbsent: () => 1);
        }
        final filters = <String?>[null, ...counts.keys];
        final index = filters.indexOf(_filter);
        final visible = reactions
            .where((r) => _filter == null || r.reaction == _filter)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            UiTabs(
              scrollable: true,
              selectedIndex: index < 0 ? 0 : index,
              onChanged: (i) => setState(() => _filter = filters[i]),
              items: [
                UiTabItem(label: 'All ${reactions.length}'),
                for (final entry in counts.entries)
                  UiTabItem(label: '${entry.key} ${entry.value}'),
              ],
            ),
            if (visible.isEmpty)
              const UiEmptyState(
                icon: Icons.favorite_border,
                title: 'No reactions yet',
                message: 'Be the first to react.',
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const UiDivider(),
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return ListenableBuilder(
                      listenable: widget.repository,
                      builder: (context, _) => CommunityReactorRow(
                        item: item,
                        currentUserId: widget.repository.currentAuthor.id,
                        following: widget.repository.isFollowing(
                          item.author.id,
                        ),
                        followButton: CommunityFollowButton(
                          repository: widget.repository,
                          authorId: item.author.id,
                        ),
                        onFollow: () =>
                            widget.repository.toggleFollow(item.author.id),
                        onAuthorTap: widget.onAuthorTap == null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                widget.onAuthorTap!(item.author);
                              },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

class CommunityReactorRow extends StatelessWidget {
  const CommunityReactorRow({
    super.key,
    required this.item,
    required this.currentUserId,
    required this.following,
    required this.onFollow,
    this.onAuthorTap,
    this.followButton,
  });
  final CommunityReaction item;
  final String currentUserId;
  final bool following;
  final VoidCallback onFollow;
  final Widget? followButton;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.sp(context.ui.spacing.sm)),
    child: Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UiAvatar(
              name: item.author.displayName,
              imageUrl: item.author.avatarUrl,
              onTap: onAuthorTap,
            ),
            Positioned(
              right: -context.sp(context.ui.spacing.xxs),
              bottom: 0,
              child: Text(item.reaction, style: context.uiText.body),
            ),
          ],
        ),
        UiGap.h(context.ui.spacing.md),
        Expanded(
          child: UiInteractive(
            onTap: onAuthorTap,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.author.displayName, style: context.uiText.bodyStrong),
                Text(
                  item.author.bio?.trim().isNotEmpty == true
                      ? item.author.bio!
                      : item.author.displayHandle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption,
                ),
              ],
            ),
          ),
        ),
        if (item.author.id != currentUserId)
          followButton ??
              UiButton(
                label: following ? 'Following' : 'Follow',
                leadingIcon: following ? Icons.check : Icons.add,
                variant: UiVariant.ghost,
                size: UiSize.sm,
                onPressed: onFollow,
              ),
      ],
    ),
  );
}
