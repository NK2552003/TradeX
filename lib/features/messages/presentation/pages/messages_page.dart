import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/session_trader.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/community/data/repositories/community_repository.dart';
import 'package:tradex/features/messages/data/repositories/messages_repository.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/subscriptions/data/repositories/subscription_repository.dart';

/// Direct messages: inbox on the left, thread on the right, split from tablet
/// up and drill-in on phones.
///
/// DMs are a paid capability, so the page reads the live [Subscription] and
/// renders an [AppTierGateCard] instead of the inbox on the free plan — the
/// gate is data-driven, never a compile-time flag.
class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    this.repository,
    this.profileRepository,
    this.subscriptionRepository,
    this.communityRepository,
    this.initialPeer,
    this.onUpgrade,
    this.onOpenTrader,
  });

  final MessagesRepository? repository;
  final ProfileSettingsRepository? profileRepository;
  final SubscriptionRepository? subscriptionRepository;
  final CommunityRepository? communityRepository;

  /// When the shell hands off from a profile ("Message @handle"), the thread
  /// opens straight away.
  final AppTrader? initialPeer;

  final VoidCallback? onUpgrade;
  final ValueChanged<AppTrader>? onOpenTrader;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late final MessagesRepository _repo =
      widget.repository ?? MessagesRepositoryImpl();
  late final ProfileSettingsRepository _profiles =
      widget.profileRepository ?? ProfileSettingsRepositoryImpl();
  late final SubscriptionRepository _billing =
      widget.subscriptionRepository ?? SubscriptionRepositoryImpl();
  late final CommunityRepository _community =
      widget.communityRepository ?? CommunityRepositoryImpl();

  AppTrader? _me;
  AppTier _tier = AppTier.free;
  List<AppConversation> _conversations = const <AppConversation>[];
  List<AppTrader> _contacts = const <AppTrader>[];
  AppConversation? _open;
  List<AppChatMessage> _thread = const <AppChatMessage>[];
  String _draft = '';
  String _search = '';
  bool _loading = true;
  bool _loadingThread = false;
  bool _sending = false;

  /// DMs need a paid plan; the free tier sees the gate instead.
  bool get _unlocked => _tier != AppTier.free;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _profiles.getProfile(),
      _billing.getSubscription(),
      _repo.getConversations(),
      _community.getFollowing(),
    ]);
    if (!mounted) return;
    setState(() {
      _me = appTraderFromProfile(results[0]! as UserProfileModel);
      _tier = (results[1]! as Subscription).tier;
      _conversations = results[2]! as List<AppConversation>;
      _contacts = results[3]! as List<AppTrader>;
      _loading = false;
    });
    final AppTrader? peer = widget.initialPeer;
    if (peer != null && _unlocked) await _startWith(peer);
  }

  Future<void> _reloadInbox() async {
    final List<AppConversation> rows = await _repo.getConversations(
      query: _search.isEmpty ? null : _search,
    );
    if (!mounted) return;
    setState(() => _conversations = rows);
  }

  void _setSearch(String value) {
    setState(() => _search = value);
    _reloadInbox();
  }

  Future<void> _openThread(AppConversation conversation) async {
    setState(() {
      _open = conversation;
      _thread = const <AppChatMessage>[];
      _draft = '';
      _loadingThread = true;
    });
    await _repo.markRead(conversation.id);
    final List<AppChatMessage> messages = await _repo.getMessages(
      conversation.id,
    );
    if (!mounted || _open?.id != conversation.id) return;
    setState(() {
      _thread = messages;
      _loadingThread = false;
    });
    await _reloadInbox();
  }

  Future<void> _startWith(AppTrader peer) async {
    final AppConversation conversation = await _repo.startConversation(peer);
    if (!mounted) return;
    await _reloadInbox();
    if (!mounted) return;
    await _openThread(conversation);
  }

  Future<void> _send() async {
    final AppConversation? conversation = _open;
    final String body = _draft.trim();
    if (conversation == null || body.isEmpty) return;
    setState(() => _sending = true);
    final AppChatMessage message = await _repo.sendMessage(
      conversation.id,
      body,
    );
    if (!mounted) return;
    setState(() {
      _thread = <AppChatMessage>[..._thread, message];
      _draft = '';
      _sending = false;
    });
    await _reloadInbox();
  }

  Future<void> _delete(AppConversation conversation) async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete this conversation?',
      description:
          'The thread with @${conversation.peer.handle} is removed for you. '
          'They keep their copy.',
      confirmLabel: 'Delete',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    await _repo.deleteConversation(conversation.id);
    if (!mounted) return;
    setState(() => _open = null);
    await _reloadInbox();
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Conversation deleted',
      message: 'It is gone from your inbox.',
      intent: UiIntent.neutral,
    );
  }

  /// Picks a follower to start a brand-new thread with.
  Future<void> _newMessage() async {
    final List<AppTrader> available = _contacts
        .where(
          (AppTrader t) => !_conversations.any(
            (AppConversation c) => c.peer.id == t.id,
          ),
        )
        .toList(growable: false);
    if (available.isEmpty) {
      UiToast.show(
        context,
        title: 'No one left to start with',
        message: 'You already have a thread with everyone you follow.',
        intent: UiIntent.info,
      );
      return;
    }
    final AppTrader? peer = await UiDialog.show<AppTrader>(
      context,
      child: _PeerPicker(traders: available),
    );
    if (peer == null || !mounted) return;
    await _startWith(peer);
  }

  int get _unread =>
      _conversations.fold<int>(0, (int sum, AppConversation c) => sum + c.unread);

  String get _subtitle {
    if (_loading) return 'Opening your inbox…';
    if (!_unlocked) {
      return 'Direct messages are part of Premium and Enterprise.';
    }
    return '${_conversations.length} threads · $_unread unread · '
        '${_contacts.length} contacts';
  }

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'Messages',
    subtitle: _subtitle,
    scrollable: false,
    actions: <Widget>[
      if (_unlocked)
        UiButton(
          label: 'New message',
          leadingIcon: Icons.add_comment_outlined,
          expandOnMobile: false,
          onPressed: _loading ? null : _newMessage,
        ),
    ],
    child: Expanded(
      child: _loading
          ? UiCard(child: UiSkeleton(height: context.sz(320)))
          : _unlocked
          ? _inboxView()
          : _gateView(),
    ),
  );

  Widget _gateView() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppFadeIn(
          child: AppTierGateCard(
            requiredTier: AppTier.premium,
            title: 'Unlock direct messages',
            message:
                'Premium adds one-to-one messaging with every trader you follow, '
                'plus shared charts and playbook links inside the thread.',
            onUpgrade: widget.onUpgrade,
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        AppFadeIn(
          delay: AppMotion.step * 2,
          child: UiCard(
            title: 'What you get',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final ({IconData icon, String title, String body}) row
                    in const <({IconData icon, String title, String body})>[
                      (
                        icon: Icons.forum_outlined,
                        title: 'Unlimited threads',
                        body: 'Message anyone who follows you back.',
                      ),
                      (
                        icon: Icons.insert_chart_outlined,
                        title: 'Share setups inline',
                        body: 'Send charts and playbooks without leaving chat.',
                      ),
                      (
                        icon: Icons.verified_user_outlined,
                        title: 'Verified-only inbox',
                        body: 'Filter requests to traders with public stats.',
                      ),
                    ])
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: context.sp(context.ui.spacing.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          row.icon,
                          color: context.uiColors.primary,
                          size: context.sz(context.ui.sizes.iconMd),
                        ),
                        UiGap.h(context.ui.spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(row.title, style: context.uiText.bodyStrong),
                              Text(
                                row.body,
                                style: context.uiText.caption.copyWith(
                                  color: context.uiColors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  /// The thread needs a bounded height (it scrolls internally), so this uses
  /// [UiSplitPane] directly instead of the scrolling workspace pane.
  Widget _inboxView() => UiSplitPane(
    initialRatio: 0.34,
    detailVisible: _open != null,
    primary: Padding(
      padding: EdgeInsets.only(right: context.sp(context.ui.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiSearchField(
            value: _search,
            hintText: 'Search people or messages',
            onChanged: _setSearch,
          ),
          UiGap.v(context.ui.spacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppInboxBlock(
                    conversations: _conversations,
                    onOpen: _openThread,
                  ),
                  if (_conversations.isEmpty && _search.isNotEmpty)
                    UiButton(
                      label: 'Clear search',
                      variant: UiVariant.ghost,
                      expand: true,
                      onPressed: () => _setSearch(''),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    detail: _open == null
        ? const UiPanePlaceholder(
            title: 'Pick a conversation',
            message: 'Your threads stay in sync across every device.',
            icon: Icons.chat_bubble_outline_rounded,
          )
        : _threadPane(_open!),
  );

  Widget _threadPane(AppConversation conversation) {
    final AppTrader? me = _me;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (context.uiRes.isMobile) ...<Widget>[
              UiIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to inbox',
                onPressed: () => setState(() => _open = null),
              ),
              UiGap.h(context.ui.spacing.xs),
            ],
            Expanded(
              child: Text(
                conversation.peer.displayName ?? '@${conversation.peer.handle}',
                style: context.uiText.subheading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            UiIconButton(
              icon: Icons.person_outline_rounded,
              tooltip: 'View profile',
              onPressed: widget.onOpenTrader == null
                  ? null
                  : () => widget.onOpenTrader!(conversation.peer),
            ),
            UiIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete conversation',
              onPressed: () => _delete(conversation),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.sm),
        Expanded(
          child: _loadingThread
              ? UiCard(child: UiSkeleton(height: context.sz(240)))
              : UiCard(
                  child: AppChatThreadBlock(
                    peer: conversation.peer,
                    messages: _thread,
                    draft: _draft,
                    onDraftChanged: (String value) =>
                        setState(() => _draft = value),
                    onSend: _sending ? null : _send,
                  ),
                ),
        ),
        if (me != null && _thread.isEmpty && !_loadingThread) ...<Widget>[
          UiGap.v(context.ui.spacing.sm),
          UiCallout(
            title: 'Say something useful',
            message:
                'Threads with context — a chart, a level, a question — get answered.',
            intent: UiIntent.info,
          ),
        ],
      ],
    );
  }
}

/// Picks a trader to open a brand-new thread with.
class _PeerPicker extends StatefulWidget {
  const _PeerPicker({required this.traders});

  final List<AppTrader> traders;

  @override
  State<_PeerPicker> createState() => _PeerPickerState();
}

class _PeerPickerState extends State<_PeerPicker> {
  String _search = '';

  List<AppTrader> get _rows => widget.traders
      .where(
        (AppTrader t) =>
            _search.isEmpty ||
            t.handle.toLowerCase().contains(_search.toLowerCase()) ||
            (t.displayName ?? '').toLowerCase().contains(_search.toLowerCase()),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final List<AppTrader> rows = _rows;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('New message', style: context.uiText.heading),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.lg),
        UiSearchField(
          value: _search,
          hintText: 'Search the people you follow',
          onChanged: (String value) => setState(() => _search = value),
        ),
        UiGap.v(context.ui.spacing.md),
        Flexible(
          child: rows.isEmpty
              ? UiEmptyState(
                  title: 'No match for "$_search"',
                  message: 'Try another handle.',
                  icon: Icons.search_off_rounded,
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final AppTrader trader in rows)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: context.sp(context.ui.spacing.sm),
                          ),
                          child: UiCard(
                            variant: UiCardVariant.surface,
                            padding: EdgeInsets.all(
                              context.sp(context.ui.spacing.md),
                            ),
                            onTap: () => Navigator.of(context).pop(trader),
                            child: AppTraderRow(
                              trader: trader,
                              trailingLabel: trader.tradingStyle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
