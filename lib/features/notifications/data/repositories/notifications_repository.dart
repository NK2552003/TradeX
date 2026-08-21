import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Per-channel delivery preference for one notification category.
@immutable
class NotificationPreference {
  const NotificationPreference({
    required this.category,
    required this.inApp,
    required this.email,
    required this.push,
  });

  final String category;
  final bool inApp;
  final bool email;
  final bool push;

  NotificationPreference copyWith({bool? inApp, bool? email, bool? push}) =>
      NotificationPreference(
        category: category,
        inApp: inApp ?? this.inApp,
        email: email ?? this.email,
        push: push ?? this.push,
      );
}

/// Which channel a preference toggle targets.
enum NotificationChannel { inApp, email, push }

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications({
    String? category,
    bool unreadOnly = false,
  });
  Future<List<String>> getCategories();
  Future<int> getUnreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> dismiss(String id);
  Future<void> clearAll();
  Future<List<NotificationPreference>> getPreferences();
  Future<NotificationPreference> setPreference(
    String category,
    NotificationChannel channel,
    bool enabled,
  );
}

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance {
    _items = List<AppNotification>.from(_source.notifications());
    _preferences = <NotificationPreference>[
      for (final String category in _source.notificationCategories)
        NotificationPreference(
          category: category,
          inApp: true,
          email: category != 'Community',
          push: category == 'Alerts' || category == 'Risk',
        ),
    ];
  }

  final DemoDataSource _source;
  late List<AppNotification> _items;
  late List<NotificationPreference> _preferences;

  AppNotification _copy(AppNotification source, {bool? read}) =>
      AppNotification(
        id: source.id,
        title: source.title,
        createdAt: source.createdAt,
        body: source.body,
        icon: source.icon,
        category: source.category,
        read: read ?? source.read,
      );

  @override
  Future<List<AppNotification>> getNotifications({
    String? category,
    bool unreadOnly = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    Iterable<AppNotification> rows = _items;
    if (category != null) {
      rows = rows.where((AppNotification n) => n.category == category);
    }
    if (unreadOnly) {
      rows = rows.where((AppNotification n) => !n.read);
    }
    final List<AppNotification> list = rows.toList();
    list.sort(
      (AppNotification a, AppNotification b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return list;
  }

  @override
  Future<List<String>> getCategories() async {
    final Set<String> categories = <String>{
      for (final AppNotification n in _items)
        if (n.category != null) n.category!,
    };
    return categories.toList()..sort();
  }

  @override
  Future<int> getUnreadCount() async =>
      _items.where((AppNotification n) => !n.read).length;

  @override
  Future<void> markRead(String id) async {
    final int index = _items.indexWhere((AppNotification n) => n.id == id);
    if (index < 0) return;
    _items[index] = _copy(_items[index], read: true);
  }

  @override
  Future<void> markAllRead() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _items = _items.map((AppNotification n) => _copy(n, read: true)).toList();
  }

  @override
  Future<void> dismiss(String id) async {
    _items = _items.where((AppNotification n) => n.id != id).toList();
  }

  @override
  Future<void> clearAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _items = <AppNotification>[];
  }

  @override
  Future<List<NotificationPreference>> getPreferences() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return List<NotificationPreference>.from(_preferences);
  }

  @override
  Future<NotificationPreference> setPreference(
    String category,
    NotificationChannel channel,
    bool enabled,
  ) async {
    final int index = _preferences.indexWhere(
      (NotificationPreference p) => p.category == category,
    );
    if (index < 0) throw StateError('Preference $category not found');
    final NotificationPreference current = _preferences[index];
    final NotificationPreference updated = switch (channel) {
      NotificationChannel.inApp => current.copyWith(inApp: enabled),
      NotificationChannel.email => current.copyWith(email: enabled),
      NotificationChannel.push => current.copyWith(push: enabled),
    };
    _preferences[index] = updated;
    return updated;
  }
}
