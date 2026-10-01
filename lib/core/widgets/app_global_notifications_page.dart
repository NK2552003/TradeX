import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/community.dart';
import 'package:tradex/features/community/presentation/views/community_notification_settings_page.dart';

/// Comprehensive Global Notification Center opened from the top header bell.
///
/// Houses a dedicated "Community" notifications view alongside Trading & Orders
/// and System & Security alert streams, unified under an "All" feed.
class AppGlobalNotificationsPage extends StatefulWidget {
  const AppGlobalNotificationsPage({
    super.key,
    required this.repository,
    required this.currentUser,
    this.onOpenRef,
    this.onNavigateToCommunity,
    this.onSubpageChanged,
  });

  final CommunityRepository repository;
  final AppTrader currentUser;
  final void Function(AppLinkRef ref)? onOpenRef;
  final VoidCallback? onNavigateToCommunity;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;

  @override
  State<AppGlobalNotificationsPage> createState() =>
      _AppGlobalNotificationsPageState();
}

class _AppGlobalNotificationsPageState
    extends State<AppGlobalNotificationsPage> {
  int _selectedTab = 0; // 0: All, 1: Community, 2: Trading & Orders, 3: System & Security
  int _communityFilter = 0; // 0: All, 1: Likes, 2: Replies, 3: Reposts, 4: Signals

  Widget? _activeSubpage;

  late List<_SystemAlertItem> _systemAlerts;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
    _initSystemAlerts();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  void _initSystemAlerts() {
    final now = DateTime.now();
    _systemAlerts = <_SystemAlertItem>[
      _SystemAlertItem(
        id: 'sys_1',
        title: 'Limit Order Executed: Bought 50 AAPL @ \$175.20',
        message: 'Order #TX-88291 filled on NASDAQ via SMART route.',
        time: now.subtract(const Duration(minutes: 18)),
        category: _AlertCategory.trading,
        icon: Icons.check_circle_outline_rounded,
        intent: UiIntent.success,
        read: false,
      ),
      _SystemAlertItem(
        id: 'sys_2',
        title: 'Stop-Loss Triggered: Closed 0.5 BTC @ \$61,200',
        message: 'Protective stop activated to prevent drawdown past -2.5%.',
        time: now.subtract(const Duration(hours: 1, minutes: 20)),
        category: _AlertCategory.trading,
        icon: Icons.shield_outlined,
        intent: UiIntent.warning,
        read: false,
      ),
      _SystemAlertItem(
        id: 'sys_3',
        title: 'Price Alert: NVDA crossed \$124.50 Resistance',
        message: 'Bullish breakout detected with above-average relative volume.',
        time: now.subtract(const Duration(hours: 3)),
        category: _AlertCategory.trading,
        icon: Icons.trending_up_rounded,
        intent: UiIntent.primary,
        read: true,
      ),
      _SystemAlertItem(
        id: 'sys_4',
        title: 'New Session Login: macOS Safari in London, UK',
        message: 'IP 82.165.197.10 verified with biometric passkey.',
        time: now.subtract(const Duration(hours: 5)),
        category: _AlertCategory.system,
        icon: Icons.security_rounded,
        intent: UiIntent.primary,
        read: true,
      ),
      _SystemAlertItem(
        id: 'sys_5',
        title: 'Dividend Credited: \$24.50 from MSFT',
        message: 'Cash credited to Primary USD Trading Balance.',
        time: now.subtract(const Duration(days: 1)),
        category: _AlertCategory.trading,
        icon: Icons.account_balance_wallet_outlined,
        intent: UiIntent.success,
        read: true,
      ),
      _SystemAlertItem(
        id: 'sys_6',
        title: 'Exchange Maintenance Notice',
        message: 'Binance API maintenance scheduled Sunday 02:00–02:15 UTC.',
        time: now.subtract(const Duration(days: 2)),
        category: _AlertCategory.system,
        icon: Icons.info_outline_rounded,
        intent: UiIntent.neutral,
        read: true,
      ),
    ];
  }

  CommunityAuthor get _currentAuthor => CommunityAuthor(
        id: widget.currentUser.id,
        handle: widget.currentUser.handle,
        displayName: widget.currentUser.displayName ?? widget.currentUser.handle,
        userRole: UserRole.customer,
        avatarUrl: widget.currentUser.avatarUrl,
        tier: widget.currentUser.tier,
      );

  int get _unreadSystemCount =>
      _systemAlerts.where((a) => !a.read).length;

  int get _totalUnreadCount =>
      widget.repository.unreadNotifications + _unreadSystemCount;

  void _markAllRead() {
    widget.repository.markAllNotificationsRead();
    setState(() {
      _systemAlerts = _systemAlerts.map((a) => a.copyWith(read: true)).toList();
    });
  }

  void _openSubpage(Widget page, String title, IconData icon) {
    setState(() {
      _activeSubpage = page;
    });
    widget.onSubpageChanged?.call(title, icon, () {
      if (mounted) {
        setState(() => _activeSubpage = null);
        widget.onSubpageChanged?.call(null, null, null);
      }
    });
  }

  void _closeSubpage() {
    setState(() => _activeSubpage = null);
    widget.onSubpageChanged?.call(null, null, null);
  }

  void _openPostDetail(CommunityPost post) {
    _openSubpage(
      CommunityPostDetailView(
        post: post,
        repository: widget.repository,
        currentUser: _currentAuthor,
        onBack: _closeSubpage,
        onAuthorTap: _openAuthorProfile,
        onOpenRef: widget.onOpenRef,
      ),
      'Post Discussion',
      Icons.article_rounded,
    );
  }

  void _openAuthorProfile(CommunityAuthor author) {
    _openSubpage(
      CommunityProfileView(
        author: author,
        repository: widget.repository,
        isCurrentUser: author.id == _currentAuthor.id,
        onBack: _closeSubpage,
        onPostTap: _openPostDetail,
        onOpenRef: widget.onOpenRef,
      ),
      '@${author.handle}',
      Icons.person_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSubpage != null) return _activeSubpage!;

    final UiTheme theme = context.ui;
    final UiResponsive r = context.uiRes;

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: r.isDesktop ? 860 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(context),
              _buildPrimaryTabs(context),
              Expanded(
                child: _buildSelectedTabContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final UiTheme theme = context.ui;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.lg),
        vertical: context.sp(theme.spacing.md),
      ),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.primary.withValues(alpha: 0.12),
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              Icons.notifications_rounded,
              color: theme.colors.primary,
              size: context.sz(20),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Notifications',
                      style: context.uiText.heading.copyWith(
                        fontSize: context.fs(18),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_totalUnreadCount > 0) ...<Widget>[
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      UiBadge(
                        label: '$_totalUnreadCount new',
                        intent: UiIntent.primary,
                        variant: UiBadgeVariant.soft,
                      ),
                    ],
                  ],
                ),
                Text(
                  'Real-time alerts, trading fills, and community activity',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_totalUnreadCount > 0) ...<Widget>[
            UiButton(
              label: 'Mark all read',
              variant: UiVariant.ghost,
              size: UiSize.sm,
              expandOnMobile: false,
              onPressed: _markAllRead,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          UiIconButton(
            icon: Icons.settings_outlined,
            size: UiSize.sm,
            tooltip: 'Notification Preferences',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CommunityNotificationSettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Widget _buildPrimaryTabs(BuildContext context) {
    final UiTheme theme = context.ui;
    final int commUnread = widget.repository.unreadNotifications;
    final int tradeUnread = _systemAlerts
        .where((a) => !a.read && a.category == _AlertCategory.trading)
        .length;

    final tabs = <String>[
      'All${_totalUnreadCount > 0 ? " ($_totalUnreadCount)" : ""}',
      'Community${commUnread > 0 ? " ($commUnread)" : ""}',
      'Trading & Orders${tradeUnread > 0 ? " ($tradeUnread)" : ""}',
      'System & Security',
    ];

    return Container(
      color: theme.colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.lg),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: UiTabs(
        tabs: tabs,
        selectedIndex: _selectedTab,
        onChanged: (int index) => setState(() => _selectedTab = index),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab Content Switcher
  // ---------------------------------------------------------------------------

  Widget _buildSelectedTabContent(BuildContext context) {
    return switch (_selectedTab) {
      1 => _buildCommunityView(context),
      2 => _buildTradingAlertsView(context),
      3 => _buildSystemAlertsView(context),
      _ => _buildCombinedFeedView(context),
    };
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Dedicated Community View
  // ---------------------------------------------------------------------------

  Widget _buildCommunityView(BuildContext context) {
    final UiTheme theme = context.ui;
    final all = widget.repository.notifications;

    final filtered = all.where((n) {
      if (_communityFilter == 1) return n.type == CommunityNotificationType.like;
      if (_communityFilter == 2) return n.type == CommunityNotificationType.reply;
      if (_communityFilter == 3) return n.type == CommunityNotificationType.repost;
      if (_communityFilter == 4) return n.type == CommunityNotificationType.signal;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.lg),
            context.sp(theme.spacing.sm),
            context.sp(theme.spacing.lg),
            context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: UiTabs(
                  tabs: const <String>[
                    'All',
                    'Likes',
                    'Replies',
                    'Reposts',
                    'Signals',
                  ],
                  selectedIndex: _communityFilter,
                  onChanged: (int idx) => setState(() => _communityFilter = idx),
                ),
              ),
              if (widget.repository.unreadNotifications > 0) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiButton(
                  label: 'Clear unread',
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  expandOnMobile: false,
                  onPressed: widget.repository.markAllNotificationsRead,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
                    child: UiEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No community notifications',
                      message:
                          'Mentions, likes, replies, and shared signals from other traders will appear here.',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = filtered[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      child: CommunityNotificationCard(
                        notification: item,
                        onTap: () {
                          if (item.postSnippet != null &&
                              widget.repository.feedPosts.isNotEmpty) {
                            final post = widget.repository.feedPosts.firstWhere(
                              (p) => p.author.handle == item.actor.handle,
                              orElse: () => widget.repository.feedPosts.first,
                            );
                            _openPostDetail(post);
                          } else {
                            _openAuthorProfile(item.actor);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Trading Alerts View
  // ---------------------------------------------------------------------------

  Widget _buildTradingAlertsView(BuildContext context) {
    final UiTheme theme = context.ui;
    final tradingList = _systemAlerts
        .where((a) => a.category == _AlertCategory.trading)
        .toList();

    if (tradingList.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.candlestick_chart_outlined,
            title: 'No trading alerts',
            message: 'Executed orders, stops, and price triggers will appear here.',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      itemCount: tradingList.length,
      itemBuilder: (BuildContext context, int index) {
        final alert = tradingList[index];
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: _AlertCard(
            item: alert,
            onTap: () {
              setState(() {
                final idx = _systemAlerts.indexWhere((a) => a.id == alert.id);
                if (idx >= 0) {
                  _systemAlerts[idx] = alert.copyWith(read: true);
                }
              });
            },
            onDismiss: () {
              setState(() {
                _systemAlerts.removeWhere((a) => a.id == alert.id);
              });
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: System & Security View
  // ---------------------------------------------------------------------------

  Widget _buildSystemAlertsView(BuildContext context) {
    final UiTheme theme = context.ui;
    final systemList = _systemAlerts
        .where((a) => a.category == _AlertCategory.system)
        .toList();

    if (systemList.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.shield_outlined,
            title: 'No security notices',
            message: 'Login events, session security, and system updates appear here.',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      itemCount: systemList.length,
      itemBuilder: (BuildContext context, int index) {
        final alert = systemList[index];
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: _AlertCard(
            item: alert,
            onTap: () {
              setState(() {
                final idx = _systemAlerts.indexWhere((a) => a.id == alert.id);
                if (idx >= 0) {
                  _systemAlerts[idx] = alert.copyWith(read: true);
                }
              });
            },
            onDismiss: () {
              setState(() {
                _systemAlerts.removeWhere((a) => a.id == alert.id);
              });
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Combined Stream (All)
  // ---------------------------------------------------------------------------

  Widget _buildCombinedFeedView(BuildContext context) {
    final UiTheme theme = context.ui;
    final communityNotifications = widget.repository.notifications;

    // Merge community notifications and system alerts sorted by date descending
    final combined = <_UnifiedNotificationEntry>[
      for (final c in communityNotifications)
        _UnifiedNotificationEntry.community(c),
      for (final s in _systemAlerts)
        _UnifiedNotificationEntry.system(s),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (combined.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'You are all caught up!',
            message: 'No notifications or alerts at this moment.',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      itemCount: combined.length,
      itemBuilder: (BuildContext context, int index) {
        final entry = combined[index];

        if (entry.isCommunity) {
          final c = entry.communityItem!;
          return Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: CommunityNotificationCard(
              notification: c,
              onTap: () {
                if (c.postSnippet != null &&
                    widget.repository.feedPosts.isNotEmpty) {
                  final post = widget.repository.feedPosts.firstWhere(
                    (p) => p.author.handle == c.actor.handle,
                    orElse: () => widget.repository.feedPosts.first,
                  );
                  _openPostDetail(post);
                } else {
                  _openAuthorProfile(c.actor);
                }
              },
            ),
          );
        }

        final s = entry.systemAlert!;
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: _AlertCard(
            item: s,
            onTap: () {
              setState(() {
                final idx = _systemAlerts.indexWhere((a) => a.id == s.id);
                if (idx >= 0) {
                  _systemAlerts[idx] = s.copyWith(read: true);
                }
              });
            },
            onDismiss: () {
              setState(() {
                _systemAlerts.removeWhere((a) => a.id == s.id);
              });
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Unified Entry for Combined Stream
// ---------------------------------------------------------------------------

class _UnifiedNotificationEntry {
  _UnifiedNotificationEntry.community(this.communityItem)
      : systemAlert = null,
        createdAt = communityItem!.createdAt,
        isCommunity = true;

  _UnifiedNotificationEntry.system(this.systemAlert)
      : communityItem = null,
        createdAt = systemAlert!.time,
        isCommunity = false;

  final CommunityNotificationItem? communityItem;
  final _SystemAlertItem? systemAlert;
  final DateTime createdAt;
  final bool isCommunity;
}

// ---------------------------------------------------------------------------
// Alert Data Model
// ---------------------------------------------------------------------------

enum _AlertCategory { trading, system }

class _SystemAlertItem {
  const _SystemAlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.category,
    required this.icon,
    required this.intent,
    required this.read,
  });

  final String id;
  final String title;
  final String message;
  final DateTime time;
  final _AlertCategory category;
  final IconData icon;
  final UiIntent intent;
  final bool read;

  _SystemAlertItem copyWith({bool? read}) => _SystemAlertItem(
        id: id,
        title: title,
        message: message,
        time: time,
        category: category,
        icon: icon,
        intent: intent,
        read: read ?? this.read,
      );
}

// ---------------------------------------------------------------------------
// Alert Card Widget (Using UiCard & Design Tokens)
// ---------------------------------------------------------------------------

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  final _SystemAlertItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    final Color badgeColor = switch (item.intent) {
      UiIntent.success => theme.colors.bullish,
      UiIntent.warning => theme.colors.warning,
      UiIntent.danger => theme.colors.destructive,
      UiIntent.primary => theme.colors.primary,
      _ => theme.colors.foregroundMuted,
    };

    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: item.read ? 0.08 : 0.16),
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              item.icon,
              size: context.sz(20),
              color: item.read
                  ? badgeColor.withValues(alpha: 0.7)
                  : badgeColor,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    UiBadge(
                      label: item.category == _AlertCategory.trading
                          ? 'Trading'
                          : 'Security',
                      intent: item.intent,
                      variant: UiBadgeVariant.soft,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      _formatTime(item.time),
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                    const Spacer(),
                    if (!item.read)
                      Container(
                        width: context.sz(8),
                        height: context.sz(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colors.primary,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  item.title,
                  style: context.uiText.bodyStrong.copyWith(
                    fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  item.message,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          UiIconButton(
            icon: Icons.close_rounded,
            size: UiSize.xs,
            variant: UiVariant.ghost,
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
