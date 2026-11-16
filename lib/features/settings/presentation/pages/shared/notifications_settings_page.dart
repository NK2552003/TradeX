import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_sidebar_widgets.dart';
import 'package:tradex/features/settings/data/repositories/notification_prefs_repository.dart';
import 'package:tradex/features/settings/models/notification_prefs_model.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key, this.repository});

  final NotificationPrefsRepository? repository;

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  static const String _dismissedPushBannerKey = 'tradex_push_card_dismissed_v1';

  late final NotificationPrefsRepository _repo;
  NotificationPrefsModel _prefs = NotificationPrefsModel.defaultPrefs();
  bool _loading = true;
  bool _pushBannerDismissed = false;

  final List<String> _digestOptions = const <String>['off', 'daily', 'weekly'];

  static final List<String> _timeSlots = List<String>.generate(48, (index) {
    final totalMinutes = index * 30;
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  });

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? NotificationPrefsRepositoryImpl();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _repo.getPreferences(),
        SharedPreferences.getInstance(),
      ]);
      final p = results[0] as NotificationPrefsModel;
      final sp = results[1] as SharedPreferences;
      final dismissed = sp.getBool(_dismissedPushBannerKey) ?? false;
      if (mounted) {
        setState(() {
          _prefs = p;
          _pushBannerDismissed = dismissed;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPushBannerDismissed(bool dismissed) async {
    setState(() => _pushBannerDismissed = dismissed);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_dismissedPushBannerKey, dismissed);
    } catch (_) {}
  }

  List<UiOption<String>> _buildTimeOptions(String? currentValue) {
    final values = List<String>.from(_timeSlots);
    if (currentValue != null &&
        currentValue.isNotEmpty &&
        !values.contains(currentValue)) {
      values.add(currentValue);
      values.sort();
    }
    return values
        .map((v) => UiOption<String>(label: _formatTimeLabel(v), value: v))
        .toList();
  }

  static String _formatTimeLabel(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mm = m.toString().padLeft(2, '0');
    return '$hhmm ($h12:$mm $period)';
  }

  Future<void> _pickCustomQuietTime({required bool isStart}) async {
    final raw = (isStart ? _prefs.quietHoursStart : _prefs.quietHoursEnd) ??
        (isStart ? '22:00' : '07:00');
    final parts = raw.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? (isStart ? 22 : 7),
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await _updatePrefsOptimistic(
      isStart
          ? _prefs.copyWith(quietHoursStart: formatted)
          : _prefs.copyWith(quietHoursEnd: formatted),
    );
  }

  Future<void> _updatePrefsOptimistic(NotificationPrefsModel newPrefs) async {
    final oldPrefs = _prefs;
    setState(() => _prefs = newPrefs);
    try {
      await _repo.updatePreferences(newPrefs);
    } catch (e) {
      if (mounted) {
        setState(() => _prefs = oldPrefs);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: 'Could not sync notification preferences. Rolled back.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  void _togglePushCategory(String key, bool val) {
    final updated = Map<String, bool>.from(_prefs.pushByCategory);
    updated[key] = val;
    _updatePrefsOptimistic(_prefs.copyWith(pushByCategory: updated));
  }

  void _toggleEmailCategory(String key, bool val) {
    final updated = Map<String, bool>.from(_prefs.emailByCategory);
    updated[key] = val;
    _updatePrefsOptimistic(_prefs.copyWith(emailByCategory: updated));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.settingsDetail(sections: 3, rowsPerSection: 4);
    }

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool isMobile = context.uiRes.isMobile;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_pushBannerDismissed)
                CommunityPushNotificationsCard(
                  onDismiss: () => _setPushBannerDismissed(true),
                )
              else
                UiCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: context.sz(18),
                        color: theme.colors.foregroundMuted,
                      ),
                      UiGap.h(theme.spacing.sm),
                      Expanded(
                        child: Text(
                          'Device browser push setup banner is hidden.',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ),
                      UiButton(
                        label: 'Configure Device Push',
                        variant: UiVariant.ghost,
                        size: UiSize.xs,
                        onPressed: () => _setPushBannerDismissed(false),
                      ),
                    ],
                  ),
                ),
              UiGap.v(theme.spacing.md),
              // Push notifications section
              AppSettingsSectionBlock(
                title: 'Push Notifications',
                description:
                    'Instant alerts sent to your mobile device or web browser.',
                children: [
                  AppSettingCard(
                    title: 'Trade Executions & Orders',
                    description:
                        'Fills, partial fills, stop-loss triggers, and order cancellations.',
                    icon: Icons.receipt_long_outlined,
                    control: UiSwitch(
                      value: _prefs.pushByCategory['trade'] ?? true,
                      onChanged: (v) => _togglePushCategory('trade', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Price Alerts & Key Levels',
                    description:
                        'Trigger notifications when watchlisted assets cross your price targets.',
                    icon: Icons.notifications_active_outlined,
                    control: UiSwitch(
                      value: _prefs.pushByCategory['price_alert'] ?? true,
                      onChanged: (v) => _togglePushCategory('price_alert', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Direct Messages & Mentions',
                    description:
                        'Direct chats from trader peers and mentions in community threads.',
                    icon: Icons.chat_bubble_outline_rounded,
                    control: UiSwitch(
                      value: _prefs.pushByCategory['message'] ?? true,
                      onChanged: (v) => _togglePushCategory('message', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Community Activity & Comments',
                    description:
                        'Replies, likes, and strategy forks from other members.',
                    icon: Icons.forum_outlined,
                    control: UiSwitch(
                      value: _prefs.pushByCategory['community'] ?? true,
                      onChanged: (v) => _togglePushCategory('community', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Affiliate & Referral Updates',
                    description:
                        'Commissions earned, payout updates, and new partner referrals.',
                    icon: Icons.monetization_on_outlined,
                    control: UiSwitch(
                      value: _prefs.pushByCategory['affiliate'] ?? true,
                      onChanged: (v) => _togglePushCategory('affiliate', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Performance Digest Push',
                    description:
                        'Push summary when your scheduled trading performance review is ready.',
                    icon: Icons.summarize_outlined,
                    control: UiSwitch(
                      value: _prefs.pushByCategory['digest'] ?? false,
                      onChanged: (v) => _togglePushCategory('digest', v),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Email preferences section
              AppSettingsSectionBlock(
                title: 'Email Notifications & Digest',
                description:
                    'Manage frequency of email communications sent to your account.',
                children: [
                  AppSettingCard(
                    title: 'Email Digest Frequency',
                    description:
                        'Periodic summary of portfolio performance, AI reviews, and top strategies.',
                    icon: Icons.mark_email_read_outlined,
                    control: UiSelect<String>(
                      value: _prefs.emailDigestFrequency,
                      options: _digestOptions
                          .map(
                            (o) => UiOption<String>(
                              label: o.toUpperCase(),
                              value: o,
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        _updatePrefsOptimistic(
                          _prefs.copyWith(emailDigestFrequency: v),
                        );
                      },
                    ),
                  ),
                  AppSettingCard(
                    title: 'Price Alert Emails',
                    description:
                        'Receive backup email for critical market alerts.',
                    icon: Icons.alternate_email_rounded,
                    control: UiSwitch(
                      value: _prefs.emailByCategory['price_alert'] ?? false,
                      onChanged: (v) => _toggleEmailCategory('price_alert', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Trade Execution Emails',
                    description:
                        'Email receipts for filled orders and stop-loss triggers.',
                    icon: Icons.receipt_outlined,
                    control: UiSwitch(
                      value: _prefs.emailByCategory['trade'] ?? false,
                      onChanged: (v) => _toggleEmailCategory('trade', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Direct Message Emails',
                    description:
                        'Email alerts for unread direct messages when you are away.',
                    icon: Icons.mail_outline_rounded,
                    control: UiSwitch(
                      value: _prefs.emailByCategory['message'] ?? false,
                      onChanged: (v) => _toggleEmailCategory('message', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Community Activity Emails',
                    description:
                        'Email updates for thread replies and mentions.',
                    icon: Icons.forum_outlined,
                    control: UiSwitch(
                      value: _prefs.emailByCategory['community'] ?? false,
                      onChanged: (v) => _toggleEmailCategory('community', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Affiliate Payout Emails',
                    description:
                        'Commission statements and partner payout confirmations.',
                    icon: Icons.payments_outlined,
                    control: UiSwitch(
                      value: _prefs.emailByCategory['affiliate'] ?? true,
                      onChanged: (v) => _toggleEmailCategory('affiliate', v),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Weekly Market Review & AI Insights',
                    description:
                        'Curated technical signals and trading journal analysis.',
                    icon: Icons.auto_awesome_outlined,
                    control: UiSwitch(
                      value: _prefs.emailByCategory['digest'] ?? true,
                      onChanged: (v) => _toggleEmailCategory('digest', v),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Quiet Hours Section
              AppSettingsSectionBlock(
                title: 'Quiet Hours Schedule',
                description:
                    'Mute non-critical push notifications during your sleep or focus schedule.',
                children: [
                  AppSettingCard(
                    title: 'Enable Quiet Hours',
                    description: _prefs.quietHoursEnabled
                        ? 'Active from ${_prefs.quietHoursStart ?? '22:00'} to ${_prefs.quietHoursEnd ?? '07:00'} (security alerts remain urgent)'
                        : 'Disabled. You will receive notifications 24/7.',
                    icon: Icons.nightlight_round,
                    control: UiSwitch(
                      value: _prefs.quietHoursEnabled,
                      onChanged: (v) => _updatePrefsOptimistic(
                        _prefs.copyWith(quietHoursEnabled: v),
                      ),
                    ),
                  ),
                  if (_prefs.quietHoursEnabled) ...[
                    UiCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isMobile) ...[
                            UiField(
                              label: 'Starts At',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: UiSelect<String>(
                                      value: _prefs.quietHoursStart ?? '22:00',
                                      options: _buildTimeOptions(
                                        _prefs.quietHoursStart,
                                      ),
                                      onChanged: (v) => _updatePrefsOptimistic(
                                        _prefs.copyWith(quietHoursStart: v),
                                      ),
                                    ),
                                  ),
                                  UiGap.h(theme.spacing.xs),
                                  UiIconButton(
                                    icon: Icons.schedule_rounded,
                                    tooltip: 'Pick exact start time',
                                    onPressed: () =>
                                        _pickCustomQuietTime(isStart: true),
                                  ),
                                ],
                              ),
                            ),
                            UiGap.v(theme.spacing.sm),
                            UiField(
                              label: 'Ends At',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: UiSelect<String>(
                                      value: _prefs.quietHoursEnd ?? '07:00',
                                      options: _buildTimeOptions(
                                        _prefs.quietHoursEnd,
                                      ),
                                      onChanged: (v) => _updatePrefsOptimistic(
                                        _prefs.copyWith(quietHoursEnd: v),
                                      ),
                                    ),
                                  ),
                                  UiGap.h(theme.spacing.xs),
                                  UiIconButton(
                                    icon: Icons.schedule_rounded,
                                    tooltip: 'Pick exact end time',
                                    onPressed: () =>
                                        _pickCustomQuietTime(isStart: false),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'Starts At',
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: UiSelect<String>(
                                            value:
                                                _prefs.quietHoursStart ??
                                                '22:00',
                                            options: _buildTimeOptions(
                                              _prefs.quietHoursStart,
                                            ),
                                            onChanged: (v) =>
                                                _updatePrefsOptimistic(
                                                  _prefs.copyWith(
                                                    quietHoursStart: v,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        UiGap.h(theme.spacing.xs),
                                        UiIconButton(
                                          icon: Icons.schedule_rounded,
                                          tooltip: 'Pick exact start time',
                                          onPressed: () => _pickCustomQuietTime(
                                            isStart: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'Ends At',
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: UiSelect<String>(
                                            value:
                                                _prefs.quietHoursEnd ?? '07:00',
                                            options: _buildTimeOptions(
                                              _prefs.quietHoursEnd,
                                            ),
                                            onChanged: (v) =>
                                                _updatePrefsOptimistic(
                                                  _prefs.copyWith(
                                                    quietHoursEnd: v,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        UiGap.h(theme.spacing.xs),
                                        UiIconButton(
                                          icon: Icons.schedule_rounded,
                                          tooltip: 'Pick exact end time',
                                          onPressed: () => _pickCustomQuietTime(
                                            isStart: false,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
