import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';

/// Conversation details bottom sheet: peer identity, quick toggles (pin, mute,
/// archive), the shared records/media exchanged in the thread, and destructive
/// actions. Reads live thread state and message history from the repository.
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

  /// Called after archiving/blocking so the shell can drop the open thread.
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
      initialChildSize: 0.72,
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
                          padding:
                              EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
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
              Icon(Icons.verified_rounded,
                  size: context.sz(18), color: colors.primary),
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
        SizedBox(width: context.sp(context.ui.spacing.sm)),
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
        SizedBox(width: context.sp(context.ui.spacing.sm)),
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

  Widget _dangerZone(BuildContext context, MessageThread thread) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const MessagesSectionHeader(
          title: 'Privacy',
          icon: Icons.shield_outlined,
        ),
        UiButton(
          label: thread.isGroup ? 'Leave group' : 'Block & report',
          icon: thread.isGroup
              ? Icons.logout_rounded
              : Icons.block_rounded,
          variant: UiVariant.soft,
          intent: UiIntent.danger,
          onPressed: () {
            widget.repository.toggleArchive(thread.id);
            Navigator.of(context).pop();
            widget.onLeft?.call();
          },
        ),
      ],
    );
  }

  Widget _mutedLine(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(context.ui.spacing.sm)),
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
