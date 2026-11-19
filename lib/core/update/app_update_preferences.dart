import 'package:shared_preferences/shared_preferences.dart';

import 'app_update_models.dart';

class AppUpdatePreferences {
  AppUpdatePreferences._();

  static const String _keyPrefix = 'alphajournal_skipped_app_update_';

  static Future<bool> shouldPrompt(AppUpdateStatus status) async {
    if (!status.hasUpdate || status.isRequired) return status.hasUpdate;
    try {
      final preferences = await SharedPreferences.getInstance();
      final skipped = preferences.getString(
        '$_keyPrefix${status.current.platform}',
      );
      return skipped != status.release?.latestDisplay;
    } on Object {
      return true;
    }
  }

  static Future<void> skip(AppUpdateStatus status) async {
    final release = status.release;
    if (status.isRequired || release == null) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        '$_keyPrefix${status.current.platform}',
        release.latestDisplay,
      );
    } on Object {
      // A failed preference write should not interrupt application startup.
    }
  }
}
