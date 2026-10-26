import 'package:flutter/foundation.dart';

@immutable
class PrivacySettingsModel {
  const PrivacySettingsModel({
    this.publicJournals = false,
    this.publicStatsEnabled = false,
    this.messagePermission = 'everyone',
    this.allowMessageRequests = true,
    this.showReadReceipts = true,
    this.showActivityStatus = true,
    this.filterSpamRequests = true,
  });

  final bool publicJournals;
  final bool publicStatsEnabled;

  /// Who can send direct messages: 'everyone' | 'followers' | 'invited'
  final String messagePermission;

  /// Whether non-followers can send message requests
  final bool allowMessageRequests;

  /// Whether others can see when messages have been read (Seen)
  final bool showReadReceipts;

  /// Whether contacts can see active / online presence
  final bool showActivityStatus;

  /// Whether low quality / suspected spam requests are automatically filtered
  final bool filterSpamRequests;

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      publicJournals: json['public_journals'] as bool? ?? false,
      publicStatsEnabled: json['public_stats_enabled'] as bool? ?? false,
      messagePermission: json['message_permission'] as String? ?? 'everyone',
      allowMessageRequests: json['allow_message_requests'] as bool? ?? true,
      showReadReceipts: json['show_read_receipts'] as bool? ?? true,
      showActivityStatus: json['show_activity_status'] as bool? ?? true,
      filterSpamRequests: json['filter_spam_requests'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'public_journals': publicJournals,
      'public_stats_enabled': publicStatsEnabled,
      'message_permission': messagePermission,
      'allow_message_requests': allowMessageRequests,
      'show_read_receipts': showReadReceipts,
      'show_activity_status': showActivityStatus,
      'filter_spam_requests': filterSpamRequests,
    };
  }

  PrivacySettingsModel copyWith({
    bool? publicJournals,
    bool? publicStatsEnabled,
    String? messagePermission,
    bool? allowMessageRequests,
    bool? showReadReceipts,
    bool? showActivityStatus,
    bool? filterSpamRequests,
  }) {
    return PrivacySettingsModel(
      publicJournals: publicJournals ?? this.publicJournals,
      publicStatsEnabled: publicStatsEnabled ?? this.publicStatsEnabled,
      messagePermission: messagePermission ?? this.messagePermission,
      allowMessageRequests: allowMessageRequests ?? this.allowMessageRequests,
      showReadReceipts: showReadReceipts ?? this.showReadReceipts,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      filterSpamRequests: filterSpamRequests ?? this.filterSpamRequests,
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
      requestedAt:
          DateTime.tryParse(json['requested_at'] as String? ?? '') ??
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
