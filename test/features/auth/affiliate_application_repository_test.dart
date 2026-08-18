import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/affiliate_program/affiliate_program.dart';

void main() {
  test(
    'affiliate application stays pending until an admin approves it',
    () async {
      final AffiliateApplicationRepository repository =
          AffiliateApplicationRepositoryImpl.instance;
      final AffiliateApplicationModel application = AffiliateApplicationModel(
        id: 'aff_test_${DateTime.now().microsecondsSinceEpoch}',
        userId: 'usr_aff_test',
        fullName: 'Test Trader',
        email: 'affiliate-flow@tradex.test',
        phone: '9876543210',
        city: 'Pune',
        state: 'Maharashtra',
        dateOfBirth: DateTime(1995, 1, 1),
        gender: 'Prefer not to say',
        platforms: const <String>['YouTube'],
        primaryPlatform: 'YouTube',
        channelHandle: '@testtrader',
        audienceReach: '1,000 – 10,000',
        niches: const <String>['Trading education'],
        accountHolder: 'Test Trader',
        bankName: 'HDFC Bank',
        accountNumber: '123456789012',
        ifsc: 'HDFC0001234',
        accountType: 'Savings',
        pan: 'ABCDE1234F',
      );

      final AffiliateApplicationModel pending = await repository.submit(
        application,
      );
      expect(pending.status, AffiliateApplicationStatus.pending);

      final AffiliateApplicationModel approved = await repository.review(
        applicationId: pending.id,
        approve: true,
        notes: 'Identity and channel verified.',
      );
      expect(approved.status, AffiliateApplicationStatus.approved);
      expect(
        (await repository.getForUser(application.userId))?.status,
        AffiliateApplicationStatus.approved,
      );
    },
  );
}
