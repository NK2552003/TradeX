import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/security/message_cipher.dart';
import 'package:alphajournal/core/security/private_message_service.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const peer = AppTrader(
    id: 'peer_user_1',
    handle: 'peer_trader',
    displayName: 'Peer Trader',
  );

  group('MessagesRepository realtime & post-unlock decryption', () {
    test(
      'preserves locked e2ee ciphertext and decrypts messages + preview upon unlock',
      () async {
        await PrivateMessageService.clearLocalUnlockCache();
        final repo = MessagesRepository();
        final threadId = repo.startConversation(peer);
        final ciphertext = '${MessageCipher.prefix}ciphertext_payload_1';

        await repo.ingestRealtimeMessageRow({
          'id': 'msg_locked_1',
          'thread_id': threadId,
          'sender_id': peer.id,
          'body': ciphertext,
          'created_at': '2026-11-15T10:00:00Z',
        }, currentUserIdOverride: 'me_user_1');

        final lockedMessages = repo.messagesFor(threadId);
        expect(lockedMessages.length, 1);
        expect(
          lockedMessages.single.body,
          'Encrypted message — unlock history to view.',
        );
        expect(
          repo.threadById(threadId)?.lastMessagePreview,
          'Encrypted message — unlock history to view.',
        );

        var notifyCount = 0;
        repo.addListener(() => notifyCount++);

        repo.decryptOverride = (body, context, sender) async {
          expect(body, ciphertext);
          expect(context, 'chat/$threadId/msg_locked_1');
          expect(sender, peer.id);
          return jsonEncode({'body': 'NIFTY breakout confirmed'});
        };

        await repo.redecryptLockedMessages();

        final unlockedMessages = repo.messagesFor(threadId);
        expect(unlockedMessages.single.body, 'NIFTY breakout confirmed');
        expect(
          repo.threadById(threadId)?.lastMessagePreview,
          'NIFTY breakout confirmed',
        );
        expect(notifyCount, greaterThanOrEqualTo(1));
      },
    );

    test(
      'deduplicates incoming realtime rows, sorts chronologically, and respects active thread unread counts',
      () async {
        final repo = MessagesRepository();
        repo.decryptOverride = (body, context, sender) async =>
            jsonEncode({'body': 'Decoded: $body'});

        final threadId = repo.startConversation(peer);

        // Background thread (not active) receives an older and newer message out of order.
        await repo.ingestRealtimeMessageRow({
          'id': 'msg_rt_2',
          'thread_id': threadId,
          'sender_id': peer.id,
          'body': '${MessageCipher.prefix}second',
          'created_at': '2026-11-15T10:05:00Z',
        }, currentUserIdOverride: 'me_user_1');

        await repo.ingestRealtimeMessageRow({
          'id': 'msg_rt_1',
          'thread_id': threadId,
          'sender_id': peer.id,
          'body': '${MessageCipher.prefix}first',
          'created_at': '2026-11-15T10:01:00Z',
        }, currentUserIdOverride: 'me_user_1');

        // Duplicate delivery of msg_rt_2 must be ignored.
        await repo.ingestRealtimeMessageRow({
          'id': 'msg_rt_2',
          'thread_id': threadId,
          'sender_id': peer.id,
          'body': '${MessageCipher.prefix}second',
          'created_at': '2026-11-15T10:05:00Z',
        }, currentUserIdOverride: 'me_user_1');

        final msgs = repo.messagesFor(threadId);
        expect(msgs.map((m) => m.id).toList(), ['msg_rt_1', 'msg_rt_2']);
        expect(msgs.first.fromMe, isFalse);
        expect(msgs.first.body, 'Decoded: ${MessageCipher.prefix}first');
        expect(repo.threadById(threadId)?.unread, 2);

        // Opening the thread clears unread, and incoming messages while open do not increment unread.
        repo.setActiveThread(threadId);
        expect(repo.threadById(threadId)?.unread, 0);

        await repo.ingestRealtimeMessageRow({
          'id': 'msg_rt_3',
          'thread_id': threadId,
          'sender_id': peer.id,
          'body': '${MessageCipher.prefix}third',
          'created_at': '2026-11-15T10:06:00Z',
        }, currentUserIdOverride: 'me_user_1');

        expect(repo.messagesFor(threadId).length, 3);
        expect(repo.threadById(threadId)?.unread, 0);

        // Sending own message marks fromMe=true without incrementing unread.
        repo.clearActiveThread(threadId);
        await repo.ingestRealtimeMessageRow({
          'id': 'msg_rt_4',
          'thread_id': threadId,
          'sender_id': 'me_user_1',
          'body': 'Plaintext ack',
          'created_at': '2026-11-15T10:07:00Z',
        }, currentUserIdOverride: 'me_user_1');

        expect(repo.messagesFor(threadId).last.fromMe, isTrue);
        expect(repo.messagesFor(threadId).last.body, 'Plaintext ack');
        expect(repo.threadById(threadId)?.unread, 0);
      },
    );
  });
}
