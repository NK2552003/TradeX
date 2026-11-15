import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/presentation/overlays/new_message_dialog.dart';
import 'package:tradex/features/messages/presentation/views/messages_requests_view.dart';
import 'package:tradex/features/messages/presentation/views/messages_thread_view.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';
import 'package:tradex/features/settings/data/repositories/privacy_repository.dart';
import 'package:tradex/features/settings/models/privacy_settings_model.dart';
import 'package:tradex/features/settings/presentation/pages/shared/privacy_settings_page.dart';

Widget _wrap(Widget child, {Size size = const Size(1280, 800)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivacySettingsModel & Repository', () {
    test('serializes and deserializes message privacy properties correctly', () {
      const model = PrivacySettingsModel(
        publicJournals: true,
        publicStatsEnabled: true,
        messagePermission: 'invited',
        allowMessageRequests: false,
        showReadReceipts: false,
        showActivityStatus: false,
        filterSpamRequests: true,
      );

      final json = model.toJson();
      expect(json['message_permission'], 'invited');
      expect(json['allow_message_requests'], false);
      expect(json['show_read_receipts'], false);
      expect(json['show_activity_status'], false);
      expect(json['filter_spam_requests'], true);

      final restored = PrivacySettingsModel.fromJson(json);
      expect(restored.messagePermission, 'invited');
      expect(restored.allowMessageRequests, false);
      expect(restored.showReadReceipts, false);
      expect(restored.showActivityStatus, false);
      expect(restored.filterSpamRequests, true);
    });

    test('updates message settings via repository', () async {
      final repo = PrivacyRepositoryImpl();
      await repo.setMessagePermission('followers');
      await repo.setAllowMessageRequests(false);
      await repo.setShowReadReceipts(false);

      final current = await repo.getPrivacySettings();
      expect(current.messagePermission, 'followers');
      expect(current.allowMessageRequests, false);
      expect(current.showReadReceipts, false);
    });
  });

  group('PrivacySettingsPage UI', () {
    testWidgets('renders Direct Messages & Chat Privacy section and controls',
        (tester) async {
      final repo = PrivacyRepositoryImpl();

      await tester.pumpWidget(
        _wrap(
          PrivacySettingsPage(
            userRole: UserRole.customer,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Direct Messages & Chat Privacy'), findsOneWidget);
      expect(find.text('Who Can Send You Messages'), findsOneWidget);
      expect(find.text('Allow Message Requests'), findsOneWidget);
      expect(find.text('Show Read Receipts (Seen Status)'), findsOneWidget);
      expect(find.text('Show Active / Online Status'), findsOneWidget);
      expect(find.text('Spam & Low-Quality Message Filter'), findsOneWidget);

      // Verify toggle group options are rendered with balanced ratios
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Followers Only'), findsOneWidget);
      expect(find.text('Only Invited'), findsOneWidget);

      // Scroll the control into the test viewport before tapping it.
      await tester.ensureVisible(find.text('Only Invited'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only Invited'));
      await tester.pumpAndSettle();

      final updated = await repo.getPrivacySettings();
      expect(updated.messagePermission, 'invited');
    });
  });

  group('Instagram-style Message Request Flow', () {
    late MessagesRepository repo;

    setUp(() {
      repo = MessagesRepository();
    });

    testWidgets('renders Instagram-style request prompt with equal 1:1:1 buttons in MessagesThreadView',
        (tester) async {
      final threadId = repo.startConversation(
        const AppTrader(
          id: 'trader_req_1',
          handle: 'unknown_trader',
          displayName: 'Unknown Trader',
          followers: 120,
        ),
        isRequest: true,
      );

      await tester.pumpWidget(
        _wrap(
          MessagesThreadView(
            repository: repo,
            threadId: threadId,
            showHeader: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check request notice banner
      expect(
        find.textContaining('wants to send you a message'),
        findsWidgets,
      );
      expect(
        find.textContaining('won\'t know you\'ve seen their message until you accept'),
        findsWidgets,
      );

      // Check equal ratio action buttons: Block, Delete, Accept
      expect(find.text('Block'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      // Tap Accept
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      // Thread should now be accepted and regular composer shown
      expect(find.byType(MessageComposer), findsOneWidget);
      expect(
        find.textContaining('Direct messages are stored by alphajournal'),
        findsNothing,
      );
    });

    testWidgets('renders balanced 1:1:1 buttons in MessagesRequestsView and deletes request',
        (tester) async {
      repo.startConversation(
        const AppTrader(
          id: 'trader_req_2',
          handle: 'scalp_hunter',
          displayName: 'Scalp Hunter',
        ),
        isRequest: true,
      );

      await tester.pumpWidget(
        _wrap(
          MessagesRequestsView(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scalp Hunter'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('No message requests'), findsOneWidget);
    });

    testWidgets('shows Instagram dialog when messaging an invited-only restricted trader',
        (tester) async {
      const restrictedPeer = AppTrader(
        id: 'peer_restricted',
        handle: 'private_whale',
        displayName: 'Private Whale',
      );

      repo.setTraderMessagingRestricted(restrictedPeer.id, true);

      await tester.pumpWidget(
        _wrap(
          NewMessageDialog(
            repository: repo,
            candidates: const [restrictedPeer],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Private Whale'), findsOneWidget);

      // Tap on the restricted trader
      await tester.tap(find.text('Private Whale'));
      await tester.pumpAndSettle();

      // Dialog explaining that user only accepts messages from invited accounts
      expect(find.text('Cannot message @private_whale'), findsOneWidget);
      expect(
        find.textContaining('does not accept direct messages from everyone'),
        findsOneWidget,
      );

      // Dismiss dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot message @private_whale'), findsNothing);
    });
  });
}
