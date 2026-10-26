import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';

/// Conversation details bottom sheet: peer/group identity, quick toggles (pin, mute,
/// archive), group membership management, the shared records/media exchanged in the
/// thread, and destructive actions (clear history, leave/delete, block).
/// Reads live thread state and message history from the repository.
class ConversationInfoSheet extends StatefulWidget {
  const ConversationInfoSheet({
    super.key,
    required this.repository,
    required this.threadId,
    this.onOpenRef,
    this.onOpenProfile,
    this.onLeft,
  });

  final MessagesRepository repository;
  final String threadId;
  final void Function(AppLinkRef ref)? onOpenRef;
  final void Function(AppTrader trader)? onOpenProfile;

  /// Called after deleting/archiving/blocking so the shell can drop the open thread.
  final VoidCallback? onLeft;

  static Future<void> show(
    BuildContext context, {
    required MessagesRepository repository,
    required String threadId,
    void Function(AppLinkRef ref)? onOpenRef,
    void Function(AppTrader trader)? onOpenProfile,
    VoidCallback? onLeft,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => MessagesDensityScope(
        child: ConversationInfoSheet(
          repository: repository,
          threadId: threadId,
          onOpenRef: onOpenRef,
          onOpenProfile: onOpenProfile,
          onLeft: onLeft,
        ),
      ),
    );
  }

  @override
  State<ConversationInfoSheet> createState() => _ConversationInfoSheetState();
}

class _ConversationInfoSheetState extends State<ConversationInfoSheet> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepo);
  }

  void _onRepo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepo);
    super.dispose();
  }

  void _showRenameDialog(BuildContext context, MessageThread thread) {
    final TextEditingController controller = TextEditingController(
      text: thread.groupTitle ?? '',
    );
    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: 'Rename Group',
        content: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(context.ui.spacing.sm),
          ),
          child: UiInput(
            label: 'Group Name',
            controller: controller,
            autofocus: true,
            hintText: 'Enter new group name',
          ),
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UiButton(
            label: 'Save',
            intent: UiIntent.primary,
            onPressed: () {
              final String val = controller.text.trim();
              if (val.isNotEmpty) {
                widget.repository.renameGroup(thread.id, val);
                Navigator.of(context).pop();
                UiToastScope.maybeOf(context)?.show(
                  UiToastData(
                    title: 'Group Renamed',
                    message: 'Group is now "$val".',
                    intent: UiIntent.success,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, MessageThread thread) {
    List<AppTrader> candidates = [];
    if (CustomerDataPolicy.allowDemo) {
      candidates = DemoDataSource.instance
          .traders()
          .where(
            (AppTrader t) =>
                !thread.participants.any((AppTrader p) => p.id == t.id),
          )
          .toList();
    }

    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: 'Add Member',
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: context.sz(280),
            minWidth: context.sz(280),
          ),
          child: candidates.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
                  child: Text(
                    'All available traders are already in this group.',
                    style: context.uiText.body.copyWith(
                      color: context.uiColors.foregroundMuted,
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (BuildContext _, int _) =>
                      const UiDivider(),
                  itemBuilder: (BuildContext ctx, int i) {
                    final AppTrader candidate = candidates[i];
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(context.ui.spacing.xxs),
                      ),
                      child: Row(
                        children: <Widget>[
                          UiAvatar(
                            name: candidate.displayName ?? candidate.handle,
                          ),
                          SizedBox(width: context.sp(context.ui.spacing.sm)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  candidate.displayName ?? candidate.handle,
                                  style: context.uiText.bodyStrong,
                                ),
                                Text(
                                  '@${candidate.handle}',
                                  style: context.uiText.caption.copyWith(
                                    color: context.uiColors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          UiButton(
                            label: 'Add',
                            size: UiSize.xs,
                            variant: UiVariant.soft,
                            intent: UiIntent.primary,
                            onPressed: () {
                              widget.repository.addParticipant(
                                thread.id,
                                candidate,
                              );
                              Navigator.of(context).pop();
                              UiToastScope.maybeOf(context)?.show(
                                UiToastData(
                                  title: 'Member Added',
                                  message:
                                      '${candidate.displayName ?? candidate.handle} joined.',
                                  intent: UiIntent.success,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: <Widget>[
          UiButton(
            label: 'Close',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, MessageThread thread) {
    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: 'Clear Chat History',
        content: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(context.ui.spacing.sm),
          ),
          child: Text(
            'Are you sure you want to clear all messages in this conversation? This cannot be undone.',
            style: context.uiText.body,
          ),
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UiButton(
            label: 'Clear messages',
            intent: UiIntent.warning,
            onPressed: () {
              widget.repository.clearThreadMessages(thread.id);
              Navigator.of(context).pop();
              UiToastScope.maybeOf(context)?.show(
                UiToastData(
                  title: 'History Cleared',
                  message: 'Messages in this conversation have been deleted.',
                  intent: UiIntent.neutral,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmLeaveOrDelete(BuildContext context, MessageThread thread) {
    final bool isGroup = thread.isGroup;
    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: isGroup ? 'Leave Group' : 'Delete Conversation',
        content: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(context.ui.spacing.sm),
          ),
          child: Text(
            isGroup
                ? 'Are you sure you want to leave "${thread.title}"? You will no longer receive new messages.'
                : 'Are you sure you want to delete this conversation with ${thread.title}? All messages will be permanently removed.',
            style: context.uiText.body,
          ),
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UiButton(
            label: isGroup ? 'Leave' : 'Delete',
            intent: UiIntent.danger,
            onPressed: () {
              widget.repository.deleteThread(thread.id);
              Navigator.of(context).pop(); // dismiss dialog
              Navigator.of(context).pop(); // dismiss info sheet
              widget.onLeft?.call();
              UiToastScope.maybeOf(context)?.show(
                UiToastData(
                  title: isGroup ? 'Left Group' : 'Conversation Deleted',
                  message: isGroup
                      ? 'You left "${thread.title}".'
                      : 'Conversation with ${thread.title} deleted.',
                  intent: UiIntent.danger,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmBlock(BuildContext context, MessageThread thread) {
    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: 'Block @${thread.peer.handle}',
        content: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(context.ui.spacing.sm),
          ),
          child: Text(
            'Are you sure you want to block @${thread.peer.handle}? They will no longer be able to message you.',
            style: context.uiText.body,
          ),
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UiButton(
            label: 'Block',
            intent: UiIntent.danger,
            onPressed: () {
              widget.repository.blockTrader(thread.peer.id);
              Navigator.of(context).pop(); // dismiss dialog
              Navigator.of(context).pop(); // dismiss sheet
              widget.onLeft?.call();
              UiToastScope.maybeOf(context)?.show(
                UiToastData(
                  title: 'Trader Blocked',
                  message: '@${thread.peer.handle} has been blocked.',
                  intent: UiIntent.danger,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final MessageThread? thread = widget.repository.threadById(widget.threadId);
    if (thread == null) return const SizedBox.shrink();

    final List<AppLinkRef> sharedRefs = widget.repository
        .messagesFor(thread.id)
        .where((ChatMessage m) => m.sharedRef != null)
        .map((ChatMessage m) => m.sharedRef!)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.sz(theme.radii.xl)),
            ),
          ),
          child: Column(
            children: <Widget>[
              const MessagesSheetGrabber(),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.fromLTRB(
                    context.sp(theme.spacing.md),
                    0,
                    context.sp(theme.spacing.md),
                    context.sp(theme.spacing.xl),
                  ),
                  children: <Widget>[
                    _identity(context, thread),
                    SizedBox(height: context.sp(theme.spacing.md)),
                    _quickActions(context, thread),
                    if (thread.isGroup) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.md)),
                      _groupMembers(context, thread),
                    ],
                    SizedBox(height: context.sp(theme.spacing.md)),
                    const MessagesSectionHeader(
                      title: 'Shared records',
                      icon: Icons.link_rounded,
                    ),
                    if (sharedRefs.isEmpty)
                      _mutedLine(context, 'No records shared yet.')
                    else
                      ...sharedRefs.map(
                        (AppLinkRef ref) => Padding(
                          padding: EdgeInsets.only(
                            bottom: context.sp(theme.spacing.xs),
                          ),
                          child: AppLinkRefTile(
                            ref: ref,
                            onTap: widget.onOpenRef == null
                                ? null
                                : () => widget.onOpenRef!(ref),
                          ),
                        ),
                      ),
                    SizedBox(height: context.sp(theme.spacing.md)),
                    _dangerZone(context, thread),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _identity(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Column(
      children: <Widget>[
        MessagesThreadAvatar(
          thread: thread,
          size: UiSize.xl,
          onTap: (widget.onOpenProfile == null || thread.isGroup)
              ? null
              : () => widget.onOpenProfile!(thread.peer),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                thread.title,
                textAlign: TextAlign.center,
                style: context.uiText.heading,
              ),
            ),
            if (thread.peer.verified && !thread.isGroup) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Icon(
                Icons.verified_rounded,
                size: context.sz(18),
                color: colors.primary,
              ),
            ],
            if (thread.isGroup) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xxs)),
              UiIconButton(
                icon: Icons.edit_outlined,
                size: UiSize.xs,
                tooltip: 'Rename group',
                onPressed: () => _showRenameDialog(context, thread),
              ),
            ],
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          thread.isGroup ? thread.subtitle : thread.presence.label,
          style: context.uiText.body.copyWith(color: colors.foregroundMuted),
        ),
        if (!thread.isGroup && widget.onOpenProfile != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiButton(
            label: 'View profile',
            icon: Icons.person_outline_rounded,
            variant: UiVariant.soft,
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenProfile!(thread.peer);
            },
          ),
        ],
      ],
    );
  }

  Widget _quickActions(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionTile(
            icon: thread.pinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined,
            label: thread.pinned ? 'Pinned' : 'Pin',
            active: thread.pinned,
            onTap: () => widget.repository.togglePin(thread.id),
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.sm)),
        Expanded(
          child: _ActionTile(
            icon: thread.muted
                ? Icons.notifications_off_rounded
                : Icons.notifications_none_rounded,
            label: thread.muted ? 'Muted' : 'Mute',
            active: thread.muted,
            onTap: () => widget.repository.toggleMute(thread.id),
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.sm)),
        Expanded(
          child: _ActionTile(
            icon: Icons.archive_outlined,
            label: 'Archive',
            onTap: () {
              widget.repository.toggleArchive(thread.id);
              Navigator.of(context).pop();
              widget.onLeft?.call();
            },
          ),
        ),
      ],
    );
  }

  Widget _groupMembers(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MessagesSectionHeader(
                title: 'Group members (${thread.participants.length})',
                icon: Icons.groups_rounded,
              ),
            ),
            UiButton(
              label: 'Add',
              icon: Icons.person_add_outlined,
              size: UiSize.xs,
              variant: UiVariant.ghost,
              onPressed: () => _showAddMemberDialog(context, thread),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        ...thread.participants.map((AppTrader p) {
          return Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: UiCard(
              variant: UiCardVariant.surface,
              padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
              child: Row(
                children: <Widget>[
                  UiAvatar(name: p.displayName ?? p.handle),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          p.displayName ?? p.handle,
                          style: context.uiText.bodyStrong,
                        ),
                        Text(
                          '@${p.handle}',
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (p.winRate != null)
                    UiBadge(
                      label: '${p.winRate!.toStringAsFixed(0)}% WR',
                      intent: UiIntent.success,
                      size: UiSize.xs,
                    ),
                  if (widget.onOpenProfile != null) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiIconButton(
                      icon: Icons.person_outline_rounded,
                      size: UiSize.xs,
                      tooltip: 'View profile',
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenProfile!(p);
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _dangerZone(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    final bool isGroup = thread.isGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const MessagesSectionHeader(
          title: 'Actions & Privacy',
          icon: Icons.shield_outlined,
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        UiButton(
          label: 'Clear chat history',
          icon: Icons.cleaning_services_outlined,
          variant: UiVariant.soft,
          intent: UiIntent.warning,
          onPressed: () => _confirmClearHistory(context, thread),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        UiButton(
          label: isGroup ? 'Leave group' : 'Delete conversation',
          icon: isGroup ? Icons.logout_rounded : Icons.delete_outline_rounded,
          variant: UiVariant.soft,
          intent: UiIntent.danger,
          onPressed: () => _confirmLeaveOrDelete(context, thread),
        ),
        if (!isGroup) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          UiButton(
            label: 'Block @${thread.peer.handle}',
            icon: Icons.block_rounded,
            variant: UiVariant.ghost,
            intent: UiIntent.danger,
            onPressed: () => _confirmBlock(context, thread),
          ),
        ],
      ],
    );
  }

  Widget _mutedLine(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.sp(context.ui.spacing.sm),
      ),
      child: Text(
        text,
        style: context.uiText.body.copyWith(
          color: context.uiColors.foregroundMuted,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final Color fg = active ? colors.primary : colors.foreground;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext context, UiInteractiveState state) {
        return Container(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(theme.spacing.sm),
            horizontal: context.sp(theme.spacing.xs),
          ),
          decoration: BoxDecoration(
            color: active
                ? colors.primary.withValues(alpha: 0.10)
                : (state.hovered ? colors.surfaceHover : colors.surfaceMuted),
            borderRadius: context.radius(theme.radii.md),
            border: Border.all(
              color: active ? colors.primary : colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: context.sz(theme.sizes.iconMd), color: fg),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                label,
                style: context.uiText.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
