enum AffiliateApplicationStatus {
  draft,
  pending,
  approved,
  rejected,
  suspended;

  String get apiValue => switch (this) {
    AffiliateApplicationStatus.draft => 'draft',
    AffiliateApplicationStatus.pending => 'pending',
    AffiliateApplicationStatus.approved => 'approved',
    AffiliateApplicationStatus.rejected => 'rejected',
    AffiliateApplicationStatus.suspended => 'suspended',
  };

  static AffiliateApplicationStatus fromApi(String? value) => switch (value) {
    'pending' || 'pending_review' => AffiliateApplicationStatus.pending,
    'approved' || 'active' => AffiliateApplicationStatus.approved,
    'rejected' => AffiliateApplicationStatus.rejected,
    'suspended' => AffiliateApplicationStatus.suspended,
    _ => AffiliateApplicationStatus.draft,
  };
}

/// Backend-ready payload for both new affiliate registrations and existing
/// TradeX customers applying to add the affiliate capability to their account.
class AffiliateApplicationModel {
  const AffiliateApplicationModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    required this.state,
    required this.dateOfBirth,
    required this.gender,
    required this.platforms,
    required this.primaryPlatform,
    required this.channelHandle,
    required this.audienceReach,
    required this.niches,
    required this.accountHolder,
    required this.bankName,
    required this.accountNumber,
    required this.ifsc,
    required this.accountType,
    required this.pan,
    this.sampleLink,
    this.upiId,
    this.status = AffiliateApplicationStatus.draft,
    this.reviewNotes,
    this.submittedAt,
    this.reviewedAt,
  });

  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String state;
  final DateTime dateOfBirth;
  final String gender;
  final List<String> platforms;
  final String primaryPlatform;
  final String channelHandle;
  final String audienceReach;
  final List<String> niches;
  final String? sampleLink;
  final String accountHolder;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String accountType;
  final String pan;
  final String? upiId;
  final AffiliateApplicationStatus status;
  final String? reviewNotes;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '•••• ${accountNumber.substring(accountNumber.length - 4)}';
  }

  AffiliateApplicationModel copyWith({
    AffiliateApplicationStatus? status,
    String? reviewNotes,
    DateTime? submittedAt,
    DateTime? reviewedAt,
  }) {
    return AffiliateApplicationModel(
      id: id,
      userId: userId,
      fullName: fullName,
      email: email,
      phone: phone,
      city: city,
      state: state,
      dateOfBirth: dateOfBirth,
      gender: gender,
      platforms: platforms,
      primaryPlatform: primaryPlatform,
      channelHandle: channelHandle,
      audienceReach: audienceReach,
      niches: niches,
      sampleLink: sampleLink,
      accountHolder: accountHolder,
      bankName: bankName,
      accountNumber: accountNumber,
      ifsc: ifsc,
      accountType: accountType,
      pan: pan,
      upiId: upiId,
      status: status ?? this.status,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'city': city,
    'state': state,
    'date_of_birth': dateOfBirth.toIso8601String(),
    'gender': gender,
    'platforms': platforms,
    'primary_platform': primaryPlatform,
    'channel_handle': channelHandle,
    'audience_reach': audienceReach,
    'niches': niches,
    'sample_link': sampleLink,
    'account_holder': accountHolder,
    'bank_name': bankName,
    'account_number': accountNumber,
    'ifsc': ifsc,
    'account_type': accountType,
    'pan': pan,
    'upi_id': upiId,
    'status': status.apiValue,
    'review_notes': reviewNotes,
    'submitted_at': submittedAt?.toIso8601String(),
    'reviewed_at': reviewedAt?.toIso8601String(),
  };
}
