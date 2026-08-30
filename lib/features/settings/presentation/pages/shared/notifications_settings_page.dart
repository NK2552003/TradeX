import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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
  late final NotificationPrefsRepository _repo;
  NotificationPrefsModel _prefs = NotificationPrefsModel.defaultPrefs();
  bool _loading = true;

  final List<String> _digestOptions = const <String>['off', 'daily', 'weekly'];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? NotificationPrefsRepositoryImpl();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _loading = true);
    try {
      final p = await _repo.getPreferences();
      if (mounted) {
        setState(() {
          _prefs = p;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
                        ? 'Active from ${_prefs.quietHoursStart} to ${_prefs.quietHoursEnd}'
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
                      child: Row(
                        children: [
                          Expanded(
                            child: UiField(
                              label: 'Starts At',
                              child: UiInput(
                                value: _prefs.quietHoursStart,
                                hintText: '22:00',
                                onChanged: (v) => _updatePrefsOptimistic(
                                  _prefs.copyWith(quietHoursStart: v),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.md)),
                          Expanded(
                            child: UiField(
                              label: 'Ends At',
                              child: UiInput(
                                value: _prefs.quietHoursEnd,
                                hintText: '07:00',
                                onChanged: (v) => _updatePrefsOptimistic(
                                  _prefs.copyWith(quietHoursEnd: v),
                                ),
                              ),
                            ),
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
