import 'package:flutter/foundation.dart';

@immutable
class NotificationPrefsModel {
  const NotificationPrefsModel({
    required this.pushByCategory,
    required this.emailByCategory,
    this.emailDigestFrequency = 'weekly',
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
  });

  /// Category keys: trade, price_alert, community, message, digest, affiliate
  final Map<String, bool> pushByCategory;
  final Map<String, bool> emailByCategory;

  /// 'off' | 'daily' | 'weekly'
  final String emailDigestFrequency;
  final bool quietHoursEnabled;

  /// 'HH:mm' format
  final String? quietHoursStart;
  final String? quietHoursEnd;

  factory NotificationPrefsModel.defaultPrefs() {
    return const NotificationPrefsModel(
      pushByCategory: <String, bool>{
        'trade': true,
        'price_alert': true,
        'community': true,
        'message': true,
        'digest': false,
        'affiliate': true,
      },
      emailByCategory: <String, bool>{
        'trade': false,
        'price_alert': true,
        'community': false,
        'message': false,
        'digest': true,
        'affiliate': true,
      },
      emailDigestFrequency: 'weekly',
      quietHoursEnabled: false,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
    );
  }

  factory NotificationPrefsModel.fromJson(Map<String, dynamic> json) {
    return NotificationPrefsModel(
      pushByCategory:
          (json['push_by_category'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool? ?? false),
          ) ??
          NotificationPrefsModel.defaultPrefs().pushByCategory,
      emailByCategory:
          (json['email_by_category'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool? ?? false),
          ) ??
          NotificationPrefsModel.defaultPrefs().emailByCategory,
      emailDigestFrequency:
          json['email_digest_frequency'] as String? ?? 'weekly',
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart: json['quiet_hours_start'] as String? ?? '22:00',
      quietHoursEnd: json['quiet_hours_end'] as String? ?? '07:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_by_category': pushByCategory,
      'email_by_category': emailByCategory,
      'email_digest_frequency': emailDigestFrequency,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
    };
  }

  NotificationPrefsModel copyWith({
    Map<String, bool>? pushByCategory,
    Map<String, bool>? emailByCategory,
    String? emailDigestFrequency,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPrefsModel(
      pushByCategory: pushByCategory ?? this.pushByCategory,
      emailByCategory: emailByCategory ?? this.emailByCategory,
      emailDigestFrequency: emailDigestFrequency ?? this.emailDigestFrequency,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}
