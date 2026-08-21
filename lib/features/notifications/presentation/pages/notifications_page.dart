import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/notifications/data/repositories/notifications_repository.dart';

/// Which slice of the inbox is on screen.
enum _Inbox { all, unread }

/// Notification centre: one inbox for alerts, community replies, AI reviews,
/// risk warnings and billing, with the filters needed to find one of them again
/// and per-category muting for the noise that is left.
///
/// The shell owns navigation, so it supplies [destinations] — the surfaces a
/// category can open for the signed-in role — and this page only asks for them.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.repository,
    this.destinations = const <String, String>{},
    this.onOpenCategory,
    this.onOpenSettings,
    this.onUnreadChanged,
  });

  final NotificationsRepository? repository;

  /// Category to the label of the surface it belongs to. A category missing
  /// from the map simply has nowhere to go for this role.
  final Map<String, String> destinations;

  /// Asks the shell to open the surface behind a category.
  final ValueChanged<String>? onOpenCategory;

  /// Opens the full delivery preferences, which live in settings.
  final VoidCallback? onOpenSettings;

  /// Fires whenever the unread total changes, so the shell badge stays honest.
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationsRepository _repo =
      widget.repository ?? NotificationsRepositoryImpl();

  List<AppNotification> _items = const <AppNotification>[];
  List<String> _categories = const <String>[];
  List<NotificationPreference> _preferences = const <NotificationPreference>[];

  int _unread = 0;
  String _query = '';
  String? _category;
  _Inbox _inbox = _Inbox.all;
  bool _loading = true;
  bool _filtering = false;
  bool _working = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getNotifications(),
      _repo.getCategories(),
      _repo.getPreferences(),
      _repo.getUnreadCount(),
    ]);
    if (!mounted) return;
    setState(() {
      _items = results[0]! as List<AppNotification>;
      _categories = results[1]! as List<String>;
      _preferences = results[2]! as List<NotificationPreference>;
      _unread = results[3]! as int;
      _loading = false;
    });
    widget.onUnreadChanged?.call(_unread);
  }

  /// Re-queries the inbox for the current filters. The answer is dropped if a
  /// filter moved on while the request was in flight, so a fast tapper never
  /// ends up looking at someone else's result.
  Future<void> _reload({bool silent = false}) async {
    final String? category = _category;
    final _Inbox inbox = _inbox;
    if (!silent) setState(() => _filtering = true);
    final List<AppNotification> rows = await _repo.getNotifications(
      category: category,
      unreadOnly: inbox == _Inbox.unread,
    );
    final int unread = await _repo.getUnreadCount();
    if (!mounted || _category != category || _inbox != inbox) return;
    setState(() {
      _items = rows;
      _unread = unread;
      _filtering = false;
    });
    widget.onUnreadChanged?.call(unread);
  }

  /// The text filter is applied here rather than in the repository: the backend
  /// filters by category and read state, and free text is a local convenience.
  List<AppNotification> get _visible {
    if (_query.trim().isEmpty) return _items;
    final String needle = _query.trim().toLowerCase();
    return _items
        .where(
          (AppNotification n) =>
              n.title.toLowerCase().contains(needle) ||
              (n.body ?? '').toLowerCase().contains(needle) ||
              (n.category ?? '').toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  bool get _hasFilters =>
      _query.trim().isNotEmpty || _category != null || _inbox != _Inbox.all;

  void _clearFilters() {
    setState(() {
      _query = '';
      _category = null;
      _inbox = _Inbox.all;
    });
    _reload();
  }

  /// Opens one notification. Reading it marks it read first, so the badge and
  /// the row agree before the sheet is even on screen.
  Future<void> _open(AppNotification notification) async {
    if (!notification.read) {
      setState(() => _busyId = notification.id);
      await _repo.markRead(notification.id);
      if (!mounted) return;
      setState(() => _busyId = null);
      await _reload(silent: true);
      if (!mounted) return;
    }
    final String? category = notification.category;
    final _NotificationAction? action =
        await UiDialog.show<_NotificationAction>(
          context,
          child: _NotificationSheet(
            notification: notification,
            destinationLabel: category == null
                ? null
                : widget.destinations[category],
          ),
        );
    if (action == null || !mounted) return;
    switch (action) {
      case _NotificationAction.open:
        if (category != null) widget.onOpenCategory?.call(category);
      case _NotificationAction.dismiss:
        await _dismiss(notification);
      case _NotificationAction.settings:
        widget.onOpenSettings?.call();
    }
  }

  Future<void> _dismiss(AppNotification notification) async {
    setState(() => _busyId = notification.id);
    await _repo.dismiss(notification.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    await _reload(silent: true);
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Dismissed',
      message: notification.title,
      intent: UiIntent.info,
    );
  }

  Future<void> _markAllRead() async {
    setState(() => _working = true);
    await _repo.markAllRead();
    if (!mounted) return;
    await _reload(silent: true);
    if (!mounted) return;
    setState(() => _working = false);
    UiToast.show(
      context,
      title: 'All caught up',
      message: 'Everything in the inbox is marked as read.',
      intent: UiIntent.success,
    );
  }

  Future<void> _clearAll() async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Clear the inbox?',
      description:
          'Every notification is removed from this device. Alerts already '
          'delivered by email or push are unaffected.',
      confirmLabel: 'Clear all',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    await _repo.clearAll();
    if (!mounted) return;
    await _reload(silent: true);
    if (!mounted) return;
    setState(() => _working = false);
  }

  /// In-app delivery is the one switch that belongs beside the inbox. Email and
  /// push sit in settings with the rest of the delivery matrix.
  Future<void> _mute(NotificationPreference preference, bool enabled) async {
    final NotificationPreference updated = await _repo.setPreference(
      preference.category,
      NotificationChannel.inApp,
      enabled,
    );
    if (!mounted) return;
    setState(() {
      _preferences = <NotificationPreference>[
        for (final NotificationPreference p in _preferences)
          if (p.category == updated.category) updated else p,
      ];
    });
  }

  DateTime? get _latestAt => _items.isEmpty
      ? null
      : _items
            .map((AppNotification n) => n.createdAt)
            .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);

  /// Counts what is on screen by category, busiest first, so the breakdown can
  /// never disagree with the list beside it.
  List<MapEntry<String, int>> get _byCategory {
    final Map<String, int> tally = <String, int>{};
    for (final AppNotification n in _visible) {
      final String key = n.category ?? 'Other';
      tally[key] = (tally[key] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> rows = tally.entries.toList();
    rows.sort(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value),
    );
    return rows;
  }

  String get _subtitle {
    if (_loading) return 'Opening the inbox…';
    final DateTime? latest = _latestAt;
    final List<String> parts = <String>[
      _unread == 0 ? 'nothing unread' : '$_unread unread',
      '${_visible.length} in view',
      if (latest != null) 'newest ${AppTokens.relativeTime(latest)}',
    ];
    return parts.join(' · ');
  }

  /// Category changes always go back to the repository, because read state and
  /// category are filtered there rather than locally.
  void _selectCategory(String? category) {
    if (_category == category) return;
    setState(() => _category = category);
    _reload();
  }

  void _selectInbox(_Inbox inbox) {
    if (_inbox == inbox) return;
    setState(() => _inbox = inbox);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AppPageBlock(
      title: 'Notifications',
      subtitle: _subtitle,
      actions: <Widget>[
        UiButton(
          label: 'Mark all read',
          leadingIcon: Icons.done_all_rounded,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          loading: _working,
          onPressed: _loading || _unread == 0 ? null : _markAllRead,
        ),
        _menu(),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFadeIn(child: _filters()),
          UiGap.v(theme.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step,
            child: AppDashboardLayoutBlock(
              main: <Widget>[_inboxCard()],
              side: <Widget>[_breakdownCard(), _deliveryCard()],
            ),
          ),
        ],
      ),
    );
  }

  /// Inbox-wide actions. They sit behind a menu because they are either rare or
  /// destructive, and the header already carries the one used daily.
  Widget _menu() {
    final UiTheme theme = context.ui;
    return UiDropdownMenu(
      alignRight: true,
      semanticLabel: 'Inbox actions',
      items: <UiMenuItem>[
        UiMenuItem(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          enabled: !_loading && !_filtering,
          onTap: () => _reload(),
        ),
        if (widget.onOpenSettings != null)
          UiMenuItem(
            label: 'Delivery settings',
            icon: Icons.tune_rounded,
            description: 'Email and push, per category',
            onTap: widget.onOpenSettings,
          ),
        const UiMenuItem.divider(),
        UiMenuItem(
          label: 'Clear the inbox',
          icon: Icons.delete_sweep_rounded,
          destructive: true,
          enabled: _items.isNotEmpty && !_working,
          onTap: _clearAll,
        ),
      ],
      child: Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
        child: Icon(
          Icons.more_horiz_rounded,
          size: context.sz(theme.sizes.iconLg),
          color: theme.colors.foregroundMuted,
        ),
      ),
    );
  }

  /// Search, category and read state narrow the same list, so they share a row
  /// on desktop and stack into a single column on phones.
  Widget _filters() {
    final UiTheme theme = context.ui;
    final Widget search = UiInput.search(
      value: _query,
      hintText: 'Search title, body or category',
      onChanged: (String value) => setState(() => _query = value),
    );
    final Widget categories = UiSelect<String?>(
      value: _category,
      hintText: 'All categories',
      leadingIcon: Icons.category_outlined,
      onChanged: _selectCategory,
      options: <UiOption<String?>>[
        const UiOption<String?>(value: null, label: 'All categories'),
        for (final String category in _categories)
          UiOption<String?>(value: category, label: category),
      ],
    );
    final Widget inbox = UiToggleGroup<_Inbox>(
      value: _inbox,
      onChanged: _selectInbox,
      expand: context.uiRes.isMobile,
      options: <UiToggleOption<_Inbox>>[
        UiToggleOption<_Inbox>(
          value: _Inbox.all,
          label: 'Everything',
          icon: Icons.inbox_outlined,
        ),
        UiToggleOption<_Inbox>(
          value: _Inbox.unread,
          label: 'Unread',
          icon: Icons.mark_email_unread_outlined,
          badge: _unread == 0 ? null : '$_unread',
        ),
      ],
    );
    final Widget clear = UiButton(
      label: 'Clear filters',
      variant: UiVariant.ghost,
      size: UiSize.sm,
      leadingIcon: Icons.filter_alt_off_outlined,
      onPressed: _clearFilters,
    );

    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          search,
          UiGap.v(theme.spacing.sm),
          categories,
          UiGap.v(theme.spacing.sm),
          inbox,
          if (_hasFilters) ...<Widget>[UiGap.v(theme.spacing.sm), clear],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 2, child: search),
        SizedBox(width: context.sp(theme.spacing.sm)),
        Expanded(child: categories),
        SizedBox(width: context.sp(theme.spacing.sm)),
        inbox,
        if (_hasFilters) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.sm)),
          clear,
        ],
      ],
    );
  }

  /// The list itself. A row being marked read or dismissed dims and stops
  /// responding, so a double tap can never fire the same request twice.
  Widget _inboxCard() {
    final UiTheme theme = context.ui;
    final List<AppNotification> rows = _visible;
    return UiCard(
      title: _inbox == _Inbox.unread ? 'Unread' : 'Inbox',
      subtitle: _category == null ? 'Newest first' : 'Filtered to $_category',
      child: UiAsyncView(
        loading: _loading || _filtering,
        loadingMessage: 'Fetching notifications…',
        isEmpty: rows.isEmpty,
        emptyTitle: _hasFilters
            ? 'Nothing matches those filters'
            : 'You are all caught up',
        emptyMessage: _hasFilters
            ? 'Widen the search or switch back to the whole inbox.'
            : 'Alerts, replies, AI reviews and billing notices land here as '
                  'they happen.',
        emptyIcon: Icons.notifications_none_rounded,
        emptyAction: _hasFilters
            ? UiButton(
                label: 'Clear filters',
                variant: UiVariant.secondary,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: _clearFilters,
              )
            : null,
        builder: (BuildContext ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i != 0) UiGap.v(theme.spacing.sm),
              _row(rows[i], i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(AppNotification notification, int index) {
    final bool busy = _busyId == notification.id;
    return AppFadeIn(
      delay: AppMotion.step * (index < 6 ? index : 6),
      child: AnimatedOpacity(
        opacity: busy ? 0.5 : 1,
        duration: context.uiMotion.fast,
        child: AppNotificationCard(
          notification: notification,
          onTap: busy ? null : () => _open(notification),
          onDismiss: busy ? null : () => _dismiss(notification),
        ),
      ),
    );
  }

  /// What the inbox is actually made of. Tapping a bar filters to it, which is
  /// the question a lopsided breakdown always raises.
  Widget _breakdownCard() {
    final List<MapEntry<String, int>> rows = _byCategory;
    return UiCard(
      title: 'What is in here',
      subtitle: _category == null
          ? 'Tap a category to filter'
          : 'Filtered to $_category',
      actions: <Widget>[
        if (_category != null)
          UiButton(
            label: 'Show everything',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => _selectCategory(null),
          ),
      ],
      child: UiAsyncView(
        loading: _loading,
        isEmpty: rows.isEmpty,
        emptyTitle: 'Nothing to break down',
        emptyMessage: 'Categories appear once there is something in the inbox.',
        emptyIcon: Icons.donut_large_rounded,
        builder: (BuildContext ctx) => UiBarList(
          intent: UiIntent.primary,
          valueFormatter: (num value) => '${value.toInt()}',
          items: <UiBarListItem>[
            for (final MapEntry<String, int> row in rows)
              UiBarListItem(
                label: row.key,
                value: row.value,
                icon: _iconFor(row.key),
                onTap: _categories.contains(row.key)
                    ? () => _selectCategory(row.key)
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  /// Borrows the icon the notifications themselves carry, so the breakdown and
  /// the list can never disagree about what a category looks like.
  IconData? _iconFor(String category) {
    for (final AppNotification n in _items) {
      if (n.category == category && n.icon != null) return n.icon;
    }
    return null;
  }

  /// In-app muting only. Email and push belong with the rest of the delivery
  /// matrix in settings, and this card links there rather than duplicating it.
  Widget _deliveryCard() {
    final UiTheme theme = context.ui;
    if (_loading) {
      return UiCard(
        title: 'In-app delivery',
        loading: true,
        loadingHeight: 220,
        child: const SizedBox.shrink(),
      );
    }
    final int muted = _preferences
        .where((NotificationPreference p) => !p.inApp)
        .length;
    return UiCard(
      title: 'In-app delivery',
      subtitle: muted == 0
          ? 'Every category reaches this inbox'
          : '$muted categor${muted == 1 ? 'y' : 'ies'} muted here',
      footer: widget.onOpenSettings == null
          ? null
          : UiButton(
              label: 'Email and push settings',
              variant: UiVariant.ghost,
              size: UiSize.sm,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: widget.onOpenSettings,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < _preferences.length; i++) ...<Widget>[
            if (i != 0) UiGap.v(theme.spacing.sm),
            UiSwitch(
              value: _preferences[i].inApp,
              label: _preferences[i].category,
              description: _deliveryHint(_preferences[i]),
              onChanged: (bool value) => _mute(_preferences[i], value),
            ),
          ],
          if (_preferences.isEmpty)
            const UiCallout(
              title: 'No categories yet',
              message:
                  'Muting becomes available once a category has sent something.',
              intent: UiIntent.info,
            ),
        ],
      ),
    );
  }

  /// Spells out where a category still lands when it is muted in-app, so
  /// silencing the inbox never reads as silencing the alert.
  String _deliveryHint(NotificationPreference preference) {
    final List<String> elsewhere = <String>[
      if (preference.email) 'email',
      if (preference.push) 'push',
    ];
    if (preference.inApp) {
      return elsewhere.isEmpty
          ? 'This inbox only'
          : 'This inbox and ${elsewhere.join(' and ')}';
    }
    return elsewhere.isEmpty
        ? 'Silenced everywhere'
        : 'Only by ${elsewhere.join(' and ')}';
  }
}

/// What the reader chose to do with an open notification.
enum _NotificationAction { open, dismiss, settings }

/// One notification in full, with the jump to wherever it came from.
class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({required this.notification, this.destinationLabel});

  final AppNotification notification;

  /// Label of the surface this notification belongs to, or null when the
  /// signed-in role has nowhere to go for it.
  final String? destinationLabel;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? category = notification.category;
    final String? body = notification.body;
    final String? destination = destinationLabel;
    return UiDialog(
      title: notification.title,
      icon: notification.icon ?? Icons.notifications_none_rounded,
      description: AppTokens.stamp(notification.createdAt),
      content: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  if (category != null) UiBadge(label: category),
                  UiBadge(
                    label: AppTokens.relativeTime(notification.createdAt),
                    icon: Icons.schedule_rounded,
                    variant: UiBadgeVariant.outline,
                  ),
                ],
              ),
              if (body != null) ...<Widget>[
                UiGap.v(theme.spacing.md),
                Text(body, style: context.uiText.body),
              ],
              if (destination == null && category != null) ...<Widget>[
                UiGap.v(theme.spacing.md),
                UiCallout(
                  title: 'Nothing to open',
                  message:
                      '$category has no dedicated surface for your role, so '
                      'this is the whole notification.',
                  intent: UiIntent.info,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        UiButton(
          label: 'Delivery settings',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          onPressed: () =>
              Navigator.of(context).pop(_NotificationAction.settings),
        ),
        UiButton(
          label: 'Dismiss',
          variant: UiVariant.secondary,
          size: UiSize.sm,
          leadingIcon: Icons.close_rounded,
          onPressed: () =>
              Navigator.of(context).pop(_NotificationAction.dismiss),
        ),
        if (destination != null)
          UiButton(
            label: 'Open $destination',
            size: UiSize.sm,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () =>
                Navigator.of(context).pop(_NotificationAction.open),
          ),
      ],
    );
  }
}
