import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';

abstract class AffiliateApplicationRepository {
  Future<AffiliateApplicationModel?> getForUser(String userId);

  Future<List<AffiliateApplicationModel>> listApplications();

  Future<AffiliateApplicationModel> submit(
    AffiliateApplicationModel application,
  );

  Future<AffiliateApplicationModel> review({
    required String applicationId,
    required bool approve,
    String? notes,
  });
}

/// In-memory adapter used by the frontend preview. The contract maps directly
/// to GET/POST/PATCH endpoints and can be replaced by the backend developer.
class AffiliateApplicationRepositoryImpl
    implements AffiliateApplicationRepository {
  AffiliateApplicationRepositoryImpl._() {
    final DateTime now = DateTime.now();
    final AffiliateApplicationModel seeded = AffiliateApplicationModel(
      id: 'aff_app_demo_001',
      userId: 'usr_creator_demo',
      fullName: 'Aarav Mehta',
      email: 'aarav@markets.example',
      phone: '9876543210',
      city: 'Mumbai',
      state: 'Maharashtra',
      dateOfBirth: DateTime(1996, 4, 18),
      gender: 'Prefer not to say',
      platforms: const <String>['YouTube', 'Instagram'],
      primaryPlatform: 'YouTube',
      channelHandle: '@aaravtrades',
      audienceReach: '10,000 – 100,000',
      niches: const <String>['Trading education', 'Personal finance'],
      sampleLink: 'https://example.com/aaravtrades',
      accountHolder: 'Aarav Mehta',
      bankName: 'HDFC Bank',
      accountNumber: '001234567890',
      ifsc: 'HDFC0001234',
      accountType: 'Savings',
      pan: 'ABCDE1234F',
      upiId: 'aarav@upi',
      status: AffiliateApplicationStatus.pending,
      submittedAt: now.subtract(const Duration(hours: 9)),
    );
    _applications[seeded.id] = seeded;
  }

  static final AffiliateApplicationRepositoryImpl instance =
      AffiliateApplicationRepositoryImpl._();

  final Map<String, AffiliateApplicationModel> _applications =
      <String, AffiliateApplicationModel>{};

  @override
  Future<AffiliateApplicationModel?> getForUser(String userId) async {
    for (final AffiliateApplicationModel application in _applications.values) {
      if (application.userId == userId) return application;
    }
    return null;
  }

  @override
  Future<List<AffiliateApplicationModel>> listApplications() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final List<AffiliateApplicationModel> result = _applications.values.toList()
      ..sort((AffiliateApplicationModel a, AffiliateApplicationModel b) {
        final DateTime left = a.submittedAt ?? DateTime(1970);
        final DateTime right = b.submittedAt ?? DateTime(1970);
        return right.compareTo(left);
      });
    return result;
  }

  @override
  Future<AffiliateApplicationModel> submit(
    AffiliateApplicationModel application,
  ) async {
    final AffiliateApplicationModel pending = application.copyWith(
      status: AffiliateApplicationStatus.pending,
      submittedAt: DateTime.now(),
    );
    _applications[pending.id] = pending;
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return pending;
  }

  @override
  Future<AffiliateApplicationModel> review({
    required String applicationId,
    required bool approve,
    String? notes,
  }) async {
    final AffiliateApplicationModel? current = _applications[applicationId];
    if (current == null) {
      throw StateError('Affiliate application not found.');
    }
    final AffiliateApplicationModel reviewed = current.copyWith(
      status: approve
          ? AffiliateApplicationStatus.approved
          : AffiliateApplicationStatus.rejected,
      reviewNotes: notes?.trim(),
      reviewedAt: DateTime.now(),
    );
    _applications[applicationId] = reviewed;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    return reviewed;
  }
}
