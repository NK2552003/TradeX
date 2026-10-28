import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Screen for managing muted and blocked accounts with 1-tap unmute / unblock.
class CommunityModerationListPage extends StatefulWidget {
  const CommunityModerationListPage({
    super.key,
    required this.repository,
    this.onBack,
    this.isEmbedded = false,
  });

  final CommunityRepository repository;
  final VoidCallback? onBack;
  final bool isEmbedded;

  @override
  State<CommunityModerationListPage> createState() =>
      _CommunityModerationListPageState();
}

class _CommunityModerationListPageState
    extends State<CommunityModerationListPage> {
  int _selectedTab = 0; // 0: Muted, 1: Blocked

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final mutedList = widget.repository.loadMutedUsers();
    final blockedList = widget.repository.loadBlockedUsers();

    final Widget content = Column(
      children: [
        Container(
          color: colors.surface,
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(16),
            vertical: context.sp(10),
          ),
          child: UiToggleGroup<int>(
            value: _selectedTab,
            onChanged: (int val) => setState(() => _selectedTab = val),
            expand: true,
            size: UiSize.sm,
            variant: UiToggleGroupVariant.segmented,
            options: [
              UiToggleOption<int>(
                value: 0,
                label: 'Muted',
                badge: '${mutedList.length}',
                icon: Icons.volume_off_outlined,
              ),
              UiToggleOption<int>(
                value: 1,
                label: 'Blocked',
                badge: '${blockedList.length}',
                icon: Icons.block_outlined,
              ),
            ],
          ),
        ),
        const UiDivider(),
        Expanded(
          child: _selectedTab == 0
              ? _buildMutedView(mutedList)
              : _buildBlockedView(blockedList),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: UiIconButton(
          icon: Icons.arrow_back,
          variant: UiVariant.ghost,
          onPressed: () => widget.onBack != null
              ? widget.onBack!()
              : Navigator.of(context).pop(),
        ),
        title: Text(
          'Moderation & Safety',
          style: context.uiText.subheading.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.foreground,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kCommunityMaxWidth),
          child: content,
        ),
      ),
    );
  }

  Widget _buildMutedView(List<dynamic> muted) {
    final colors = context.ui.colors;
    if (muted.isEmpty) {
      return Center(
        child: UiEmptyState(
          icon: Icons.volume_off_outlined,
          title: 'No Muted Accounts',
          message:
              'When you mute someone, their posts and replies will not appear in your feeds, but they can still view your profile.',
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(context.sp(16)),
      itemCount: muted.length,
      separatorBuilder: (_, _) => SizedBox(height: context.sp(10)),
      itemBuilder: (ctx, idx) {
        final entry = muted[idx];
        return UiCard(
          child: Padding(
            padding: EdgeInsets.all(context.sp(14)),
            child: Row(
              children: [
                UiAvatar(name: entry.userId, size: UiSize.sm),
                SizedBox(width: context.sp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.userId,
                        style: context.uiText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        'Muted on ${entry.mutedAt.day}/${entry.mutedAt.month}/${entry.mutedAt.year}',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                UiButton(
                  label: 'Unmute',
                  variant: UiVariant.outline,
                  size: UiSize.sm,
                  onPressed: () {
                    widget.repository.unmuteUser(entry.userId);
                    UiToast.show(
                      context,
                      title: 'Account Unmuted',
                      message: 'Unmuted ${entry.userId}',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlockedView(List<dynamic> blocked) {
    final colors = context.ui.colors;
    if (blocked.isEmpty) {
      return Center(
        child: UiEmptyState(
          icon: Icons.block_outlined,
          title: 'No Blocked Accounts',
          message:
              'Blocked users cannot see your posts, follow your profile, or send you direct messages.',
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(context.sp(16)),
      itemCount: blocked.length,
      separatorBuilder: (_, _) => SizedBox(height: context.sp(10)),
      itemBuilder: (ctx, idx) {
        final entry = blocked[idx];
        return UiCard(
          child: Padding(
            padding: EdgeInsets.all(context.sp(14)),
            child: Row(
              children: [
                UiAvatar(name: entry.userId, size: UiSize.sm),
                SizedBox(width: context.sp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.userId,
                        style: context.uiText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        'Blocked on ${entry.blockedAt.day}/${entry.blockedAt.month}/${entry.blockedAt.year}',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                UiButton(
                  label: 'Unblock',
                  variant: UiVariant.outline,
                  size: UiSize.sm,
                  onPressed: () async {
                    try {
                      await widget.repository.unblockUser(entry.userId);
                      if (!context.mounted) return;
                      UiToast.show(
                        context,
                        title: 'Account Unblocked',
                        message: 'Unblocked ${entry.userId}',
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      UiToast.show(
                        context,
                        title: 'Action Failed',
                        message: 'Failed to unblock: $e',
                        intent: UiIntent.danger,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
