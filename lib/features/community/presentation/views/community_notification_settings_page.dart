import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/settings/presentation/pages/shared/notifications_settings_page.dart';

class CommunityNotificationSettingsPage extends StatelessWidget {
  const CommunityNotificationSettingsPage({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => UiPage(
    title: 'Notification preferences',
    actions: [
      UiIconButton(
        icon: Icons.arrow_back,
        onPressed: onBack ?? () => Navigator.of(context).pop(),
      ),
    ],
    child: const NotificationsSettingsPage(),
  );
}
