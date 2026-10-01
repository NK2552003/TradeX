import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Screen allowing traders to configure per-category notification preferences,
/// signal alerts, and quiet hours.
class CommunityNotificationSettingsPage extends StatefulWidget {
  const CommunityNotificationSettingsPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<CommunityNotificationSettingsPage> createState() =>
      _CommunityNotificationSettingsPageState();
}

class _CommunityNotificationSettingsPageState
    extends State<CommunityNotificationSettingsPage> {
  bool _masterPushEnabled = true;
  bool _setupAlerts = true;
  bool _replies = true;
  bool _likes = false;
  bool _reposts = true;
  bool _newFollowers = true;
  bool _mentions = true;
  bool _deskAlerts = true;
  bool _quietHoursEnabled = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

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
          'Notification Preferences',
          style: context.uiText.subheading.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.foreground,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kCommunityMaxWidth),
          child: ListView(
            padding: EdgeInsets.all(context.sp(16)),
            children: [
              // Master Push Card
              UiCard(
                child: Padding(
                  padding: EdgeInsets.all(context.sp(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Push Notifications',
                              style: context.uiText.bodyStrong.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.foreground,
                              ),
                            ),
                            SizedBox(height: context.sp(4)),
                            Text(
                              'Enable immediate device push notifications for trading activity',
                              style: context.uiText.caption.copyWith(
                                color: colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      UiToggle(
                        value: _masterPushEnabled,
                        onChanged: (val) =>
                            setState(() => _masterPushEnabled = val),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.sp(20)),

              // Trading Alerts Section
              _SectionHeader(title: 'TRADING & SIGNALS'),
              SizedBox(height: context.sp(8)),
              UiCard(
                child: Column(
                  children: [
                    _ToggleRow(
                      icon: Icons.show_chart,
                      title: 'Trade Setup & Signal Alerts',
                      subtitle:
                          'When traders you follow post verified trade setups',
                      value: _setupAlerts,
                      onChanged: (v) => setState(() => _setupAlerts = v),
                    ),
                    const UiDivider(),
                    _ToggleRow(
                      icon: Icons.campaign_outlined,
                      title: 'Official Desk Announcements',
                      subtitle:
                          'High-priority market alerts from desk administrators',
                      value: _deskAlerts,
                      onChanged: (v) => setState(() => _deskAlerts = v),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(20)),

              // Social Interactions
              _SectionHeader(title: 'SOCIAL ENGAGEMENT'),
              SizedBox(height: context.sp(8)),
              UiCard(
                child: Column(
                  children: [
                    _ToggleRow(
                      icon: Icons.alternate_email,
                      title: 'Mentions & Cashtag Replies',
                      subtitle:
                          'When someone mentions you with @ or quotes your analysis',
                      value: _mentions,
                      onChanged: (v) => setState(() => _mentions = v),
                    ),
                    const UiDivider(),
                    _ToggleRow(
                      icon: Icons.chat_bubble_outline,
                      title: 'Replies & Discussion',
                      subtitle: 'Responses to your posts and threads',
                      value: _replies,
                      onChanged: (v) => setState(() => _replies = v),
                    ),
                    const UiDivider(),
                    _ToggleRow(
                      icon: Icons.repeat,
                      title: 'Reposts',
                      subtitle: 'When another trader reposts your analysis',
                      value: _reposts,
                      onChanged: (v) => setState(() => _reposts = v),
                    ),
                    const UiDivider(),
                    _ToggleRow(
                      icon: Icons.person_add_outlined,
                      title: 'New Followers',
                      subtitle: 'When a trader starts following your profile',
                      value: _newFollowers,
                      onChanged: (v) => setState(() => _newFollowers = v),
                    ),
                    const UiDivider(),
                    _ToggleRow(
                      icon: Icons.favorite_border,
                      title: 'Likes & Reactions',
                      subtitle: 'When other traders like your posts',
                      value: _likes,
                      onChanged: (v) => setState(() => _likes = v),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(20)),

              // Quiet Hours
              _SectionHeader(title: 'MARKET OFF-HOURS (QUIET TIME)'),
              SizedBox(height: context.sp(8)),
              UiCard(
                child: Padding(
                  padding: EdgeInsets.all(context.sp(16)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mute Outside Market Hours',
                                  style: context.uiText.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.foreground,
                                  ),
                                ),
                                Text(
                                  'Silence notifications between 11:00 PM and 07:00 AM',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          UiToggle(
                            value: _quietHoursEnabled,
                            onChanged: (v) =>
                                setState(() => _quietHoursEnabled = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.sp(28)),

              UiButton(
                label: 'Save Preferences',
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  UiToast.show(
                    context,
                    title: 'Preferences Updated',
                    message: 'Notification preferences updated',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.uiText.label.copyWith(
        fontWeight: FontWeight.w700,
        color: context.ui.colors.foregroundMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    return Padding(
      padding: EdgeInsets.all(context.sp(14)),
      child: Row(
        children: [
          Icon(icon, size: context.sz(20), color: colors.foregroundMuted),
          SizedBox(width: context.sp(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.uiText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          UiToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
