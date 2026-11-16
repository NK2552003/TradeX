import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:tradex/core/ads/ad_scope.dart';
import 'package:tradex/core/ads/promotion_preview.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';
import 'package:tradex/features/settings/data/repositories/privacy_repository.dart';

/// The inbox: search, filter chips, an optional pinned section, then the thread
/// list. Every row and count comes from [MessagesRepository]; this widget holds
/// only local UI state (the active filter and search text).
class MessagesInboxView extends StatefulWidget {
  const MessagesInboxView({
    super.key,
    required this.repository,
    this.selectedThreadId,
    this.onOpenThread,
    this.onOpenRequests,
    this.onOpenArchived,
    this.onNewMessage,
    this.onThreadLongPress,
    this.externalQuery,
    this.showHeaderActions = true,
  });

  final MessagesRepository repository;
  final String? selectedThreadId;
  final void Function(MessageThread thread)? onOpenThread;
  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenArchived;
  final VoidCallback? onNewMessage;
  final void Function(MessageThread thread)? onThreadLongPress;

  /// Search text pushed from the global top header (desktop/tablet).
  final String? externalQuery;
  final bool showHeaderActions;

  @override
  State<MessagesInboxView> createState() => _MessagesInboxViewState();
}

class _MessagesInboxViewState extends State<MessagesInboxView> {
  ThreadFilter _filter = ThreadFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.externalQuery ?? '';
    widget.repository.addListener(_onRepo);
  }

  @override
  void didUpdateWidget(covariant MessagesInboxView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository) {
      oldWidget.repository.removeListener(_onRepo);
      widget.repository.addListener(_onRepo);
    }
    if (widget.externalQuery != oldWidget.externalQuery &&
        widget.externalQuery != null) {
      _query = widget.externalQuery!;
    }
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
    final MessagesRepository repo = widget.repository;

    final List<MessageThread> results = repo.filtered(_filter, _query);
    final bool showPinned =
        _filter == ThreadFilter.all && _query.trim().isEmpty;
    final List<MessageThread> pinned = showPinned
        ? results.where((MessageThread t) => t.pinned).toList()
        : const <MessageThread>[];
    final List<MessageThread> rest = showPinned
        ? results.where((MessageThread t) => !t.pinned).toList()
        : results;

    final bool showRequestsBanner =
        _filter == ThreadFilter.all &&
        _query.trim().isEmpty &&
        repo.requestCount > 0 &&
        widget.onOpenRequests != null;

    // Default-view-only accents: who is live right now, and how much is unread.
    final List<MessageThread> live = showPinned
        ? results
              .where((MessageThread t) => !t.isGroup && t.presence.isLive)
              .take(12)
              .toList()
        : const <MessageThread>[];
    int unreadTotal = 0;
    int unreadChats = 0;
    if (showPinned) {
      for (final MessageThread t in results) {
        if (t.unread > 0) {
          unreadTotal += t.unread;
          unreadChats++;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _searchBar(context),
        _filterChips(context, repo),
        if (showRequestsBanner) _requestsBanner(context, repo),
        Expanded(
          child: results.isEmpty
              ? (!kReleaseMode &&
                        AdSenseScope.maybeOf(context)?.config.preview == true
                    ? SingleChildScrollView(
                        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _empty(context),
                            UiGap.v(theme.spacing.md),
                            const PromotionPreview(surface: 'Messages'),
                          ],
                        ),
                      )
                    : _empty(context))
              : ListView(
                  padding: EdgeInsets.only(
                    left: context.sp(theme.spacing.sm),
                    right: context.sp(theme.spacing.sm),
                    bottom: context.sp(theme.spacing.xl),
                  ),
                  children: <Widget>[
                    if (showPinned && unreadTotal > 0)
                      _unreadSummary(context, unreadTotal, unreadChats),
                    if (live.isNotEmpty &&
                        PrivacyRepositoryImpl
                            .instance
                            .cachedSettings
                            .showActivityStatus) ...<Widget>[
                      const MessagesSectionHeader(
                        title: 'Active now',
                        icon: Icons.bolt_rounded,
                      ),
                      _presenceStrip(context, live),
                    ],
                    if (pinned.isNotEmpty) ...<Widget>[
                      const MessagesSectionHeader(
                        title: 'Pinned',
                        icon: Icons.push_pin_rounded,
                      ),
                      ...pinned.map((MessageThread t) => _tile(repo, t)),
                      const MessagesSectionHeader(title: 'All messages'),
                    ],
                    ...rest.map((MessageThread t) => _tile(repo, t)),
                    _footerLinks(context, repo),
                    if (!kReleaseMode &&
                        AdSenseScope.maybeOf(context)?.config.preview ==
                            true) ...<Widget>[
                      UiGap.v(theme.spacing.md),
                      const PromotionPreview(surface: 'Messages'),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tile(MessagesRepository repo, MessageThread thread) {
    return ConversationTile(
      thread: thread,
      typing: repo.isTyping(thread.id),
      selected: thread.id == widget.selectedThreadId,
      onTap: () => widget.onOpenThread?.call(thread),
      onLongPress: () => widget.onThreadLongPress?.call(thread),
    );
  }

  Widget _unreadSummary(BuildContext context, int unreadTotal, int chats) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.xs),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          UiBadge(
            label: '$unreadTotal',
            intent: UiIntent.primary,
            size: UiSize.xs,
          ),
          Expanded(
            child: Text(
              unreadTotal == 1
                  ? '1 unread message'
                  : '$unreadTotal unread across $chats ${chats == 1 ? 'chat' : 'chats'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presenceStrip(BuildContext context, List<MessageThread> live) {
    final UiTheme theme = context.ui;
    return SizedBox(
      height: context.sz(92),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.xs),
          vertical: context.sp(theme.spacing.xxs),
        ),
        itemCount: live.length,
        separatorBuilder: (BuildContext _, int _) =>
            SizedBox(width: context.sp(theme.spacing.sm)),
        itemBuilder: (BuildContext ctx, int i) {
          final MessageThread t = live[i];
          return SizedBox(
            width: ctx.sz(64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                MessagesThreadAvatar(
                  thread: t,
                  size: UiSize.lg,
                  onTap: () => widget.onOpenThread?.call(t),
                ),
                SizedBox(height: ctx.sp(theme.spacing.xxs)),
                Text(
                  t.peer.displayName ?? '@${t.peer.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ctx.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.sm),
        context.sp(theme.spacing.sm),
        context.sp(theme.spacing.sm),
        context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: UiInput.search(
              hintText: 'Search messages',
              value: _query,
              onChanged: (String v) => setState(() => _query = v),
              onClear: () => setState(() => _query = ''),
            ),
          ),
          if (widget.showHeaderActions &&
              widget.onNewMessage != null) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            UiIconButton(
              icon: Icons.edit_square,
              tooltip: 'New message',
              variant: UiVariant.soft,
              intent: UiIntent.primary,
              onPressed: widget.onNewMessage,
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChips(BuildContext context, MessagesRepository repo) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xxs),
      ),
      child: UiToggleGroup<ThreadFilter>(
        variant: UiToggleGroupVariant.pill,
        value: _filter,
        scrollWhenTight: true,
        allowEmpty: false,
        onChanged: (ThreadFilter f) {
          if (f == ThreadFilter.requests) {
            widget.onOpenRequests?.call();
            return;
          }
          setState(() => _filter = f);
        },
        options: <UiOption<ThreadFilter>>[
          for (final ThreadFilter f in ThreadFilter.values)
            UiToggleOption<ThreadFilter>(
              value: f,
              label: f.label,
              icon: f.icon,
              badge: f == ThreadFilter.requests && repo.requestCount > 0
                  ? '${repo.requestCount}'
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _requestsBanner(BuildContext context, MessagesRepository repo) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xxs),
      ),
      child: UiInteractive(
        onTap: widget.onOpenRequests,
        builder: (BuildContext context, UiInteractiveState state) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.sm),
            ),
            decoration: BoxDecoration(
              color: state.hovered
                  ? colors.surfaceHover
                  : colors.primary.withValues(alpha: 0.08),
              borderRadius: context.radius(theme.radii.lg),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.25),
                width: theme.borders.hairline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: context.sz(36),
                  height: context.sz(36),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    size: context.sz(18),
                    color: colors.primary,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Message requests',
                            style: context.uiText.bodyStrong,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          UiBadge(
                            label: '${repo.requestCount}',
                            intent: UiIntent.primary,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                      SizedBox(height: context.sz(2)),
                      Text(
                        '${repo.requestCount} ${repo.requestCount == 1 ? 'person wants' : 'people want'} to connect with you',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: context.sz(theme.sizes.iconSm),
                  color: colors.foregroundSubtle,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _footerLinks(BuildContext context, MessagesRepository repo) {
    final UiTheme theme = context.ui;
    final List<Widget> links = <Widget>[];
    if (repo.requestCount > 0 && widget.onOpenRequests != null) {
      links.add(
        _FooterLink(
          icon: Icons.mark_email_unread_outlined,
          label: 'Message requests',
          trailing: '${repo.requestCount}',
          onTap: widget.onOpenRequests!,
        ),
      );
    }
    if (repo.archivedThreads.isNotEmpty && widget.onOpenArchived != null) {
      links.add(
        _FooterLink(
          icon: Icons.archive_outlined,
          label: 'Archived',
          trailing: '${repo.archivedThreads.length}',
          onTap: widget.onOpenArchived!,
        ),
      );
    }
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.sp(theme.spacing.sm)),
      child: Column(children: links),
    );
  }

  Widget _empty(BuildContext context) {
    final bool searching = _query.trim().isNotEmpty;
    return MessagesEmptyState(
      icon: searching ? Icons.search_off_rounded : Icons.forum_outlined,
      title: searching ? 'No matches' : 'No conversations yet',
      message: searching
          ? 'No conversations match "${_query.trim()}".'
          : 'Start a conversation with a trader you follow.',
      action: widget.onNewMessage == null
          ? null
          : UiButton(
              label: searching ? 'Search live traders' : 'New message',
              icon: searching
                  ? Icons.person_search_outlined
                  : Icons.edit_square,
              onPressed: widget.onNewMessage,
            ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext context, UiInteractiveState state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.sm),
          ),
          decoration: BoxDecoration(
            color: state.hovered ? colors.surfaceHover : Colors.transparent,
            borderRadius: context.radius(theme.radii.md),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: context.sz(theme.sizes.iconSm),
                color: colors.foregroundMuted,
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Text(
                  label,
                  style: context.uiText.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                  ),
                ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Icon(
                Icons.chevron_right_rounded,
                size: context.sz(theme.sizes.iconSm),
                color: colors.foregroundSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}
