import 'package:tradex/features/settings/models/notification_prefs_model.dart';

abstract class NotificationPrefsRepository {
  Future<NotificationPrefsModel> getPreferences();
  Future<NotificationPrefsModel> updatePreferences(
    NotificationPrefsModel prefs,
  );
}

class NotificationPrefsRepositoryImpl implements NotificationPrefsRepository {
  NotificationPrefsModel _prefs = NotificationPrefsModel.defaultPrefs();

  @override
  Future<NotificationPrefsModel> getPreferences() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _prefs;
  }

  @override
  Future<NotificationPrefsModel> updatePreferences(
    NotificationPrefsModel prefs,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _prefs = prefs;
    return _prefs;
  }
}
