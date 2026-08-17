import 'package:flutter/foundation.dart';

@immutable
class ConnectedAccount {
  const ConnectedAccount({
    required this.provider,
    required this.linkedAt,
    this.email,
  });

  /// 'google' | 'apple'
  final String provider;
  final DateTime linkedAt;
  final String? email;

  factory ConnectedAccount.fromJson(Map<String, dynamic> json) {
    return ConnectedAccount(
      provider: json['provider'] as String,
      linkedAt: DateTime.tryParse(json['linked_at'] as String? ?? '') ?? DateTime.now(),
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'linked_at': linkedAt.toIso8601String(),
      'email': email,
    };
  }
}
