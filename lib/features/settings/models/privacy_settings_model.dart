import 'package:flutter/foundation.dart';

@immutable
class PrivacySettingsModel {
  const PrivacySettingsModel({
    this.publicJournals = false,
    this.publicStatsEnabled = false,
  });

  final bool publicJournals;
  final bool publicStatsEnabled;

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      publicJournals: json['public_journals'] as bool? ?? false,
      publicStatsEnabled: json['public_stats_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'public_journals': publicJournals,
      'public_stats_enabled': publicStatsEnabled,
    };
  }

  PrivacySettingsModel copyWith({
    bool? publicJournals,
    bool? publicStatsEnabled,
  }) {
    return PrivacySettingsModel(
      publicJournals: publicJournals ?? this.publicJournals,
      publicStatsEnabled: publicStatsEnabled ?? this.publicStatsEnabled,
    );
  }
}

@immutable
class DataExportRequest {
  const DataExportRequest({
    required this.status,
    required this.requestedAt,
    this.downloadUrl,
    this.completedAt,
    this.expiresAt,
  });

  /// 'pending' | 'processing' | 'ready' | 'failed'
  final String status;
  final DateTime requestedAt;
  final String? downloadUrl;
  final DateTime? completedAt;
  final DateTime? expiresAt;

  bool get isReady => status == 'ready';
  bool get isProcessing => status == 'processing' || status == 'pending';
  bool get isFailed => status == 'failed';

  factory DataExportRequest.fromJson(Map<String, dynamic> json) {
    return DataExportRequest(
      status: json['status'] as String? ?? 'pending',
      requestedAt: DateTime.tryParse(json['requested_at'] as String? ?? '') ??
          DateTime.now(),
      downloadUrl: json['download_url'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'requested_at': requestedAt.toIso8601String(),
      'download_url': downloadUrl,
      'completed_at': completedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}
