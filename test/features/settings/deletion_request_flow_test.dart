import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/delete_account_page.dart';

class DeletionRequestFixture extends Fake implements ProfileSettingsRepository {
  bool fail = true;
  AccountDeletionRequestModel? saved;

  @override
  Future<AccountDeletionRequestModel> requestAccountDeletion({
    String? reason,
    String? feedback,
    String dataPurgeCondition = 'immediate_purge',
    bool purgeJournalsNotesStrategies = true,
    bool purgeCommunityMessages = true,
    bool purgeAiWorkspace = true,
    bool purgeAffiliateCampaigns = true,
    bool exportBeforeDelete = false,
    String userRole = 'customer',
  }) async {
    if (fail) throw StateError('Connection unavailable. Please retry.');
    final now = DateTime.now();
    return saved = AccountDeletionRequestModel(
      id: 'request',
      userId: 'user',
      userHandle: 'trader',
      userEmail: 'trader@example.invalid',
      userRole: userRole,
      reason: reason ?? '',
      feedback: feedback,
      dataPurgeCondition: dataPurgeCondition,
      purgeJournalsNotesStrategies: purgeJournalsNotesStrategies,
      purgeCommunityMessages: purgeCommunityMessages,
      purgeAiWorkspace: purgeAiWorkspace,
      purgeAffiliateCampaigns: purgeAffiliateCampaigns,
      exportRequestedBeforeDelete: exportBeforeDelete,
      status: 'pending',
      scheduledPurgeAt: now,
      createdAt: now,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('deletion failure retains confirmation and retry saves consent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DeletionRequestFixture();
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeleteAccountPage(
            repository: repository,
            onAccountDeleted: () => completed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request deletion after review'), findsOneWidget);
    expect(find.textContaining('Retain Statutory'), findsNothing);

    final acknowledge = find.byType(UiCheckbox);
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pumpAndSettle();
    final review = find.text('Review deletion request');
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    final confirmation = find.descendant(
      of: find.byType(UiDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(confirmation, 'DELETE');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit deletion request'));
    await tester.pumpAndSettle();
    expect(find.text('Request could not be saved'), findsOneWidget);
    expect(completed, isFalse);
    expect(repository.saved, isNull);

    repository.fail = false;
    await tester.tap(find.text('Submit deletion request'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(repository.saved?.dataPurgeCondition, 'immediate_purge');
    expect(repository.saved?.purgeJournalsNotesStrategies, isTrue);
    expect(repository.saved?.purgeCommunityMessages, isTrue);
    expect(repository.saved?.purgeAiWorkspace, isTrue);
    expect(repository.saved?.purgeAffiliateCampaigns, isTrue);
    expect(repository.saved?.exportRequestedBeforeDelete, isFalse);
    expect(tester.takeException(), isNull);
  });
}
