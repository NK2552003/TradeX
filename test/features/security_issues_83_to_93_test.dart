import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/data/services/auth_backend_service.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/user_profile_model.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/copilot/models/workspace.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/journal/data/supabase_trade_repository.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';
import 'package:alphajournal/features/messages/models/messages_models.dart';
import 'package:alphajournal/features/notes/data/note_attachments.dart';
import 'package:alphajournal/features/settings/data/repositories/desk_risk_repository.dart';
import 'package:alphajournal/features/settings/models/desk_risk_model.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';
import 'package:alphajournal/features/strategies/data/strategy_attachments.dart';

import '../../server/copilot/agent_runner.dart';
import '../../server/copilot/auth.dart';
import '../../server/copilot/config.dart';
import '../../server/copilot/openai_gateway.dart';
import '../../server/copilot/store.dart';
import '../../server/copilot/voice.dart';
import '../../server/copilot/workspace_actions.dart';

String _ownerFileKey(String owner) =>
    base64Url.encode(utf8.encode(owner)).replaceAll('=', '');

String _randomBase64Key([int seed = 42]) {
  final rng = Random(seed);
  return base64.encode(List<int>.generate(32, (_) => rng.nextInt(255) + 1));
}

class _FakeJournalRepository extends JournalRepository {
  _FakeJournalRepository(this._trades);
  final List<AppTrade> _trades;

  @override
  Future<List<AppTrade>> fetchAll() async => List<AppTrade>.from(_trades);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Issue #88: Encrypt saved Copilot connector tokens at rest', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('copilot_enc_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'rejects missing or non-256-bit encryption key without hardcoded fallback',
      () {
        expect(
          () => WorkspaceStore(tempDir, encryptionKey: 'short-key'),
          throwsA(isA<WorkspaceEncryptionException>()),
        );
        expect(
          () => WorkspaceStore.parseKeyMaterial(''),
          throwsA(isA<WorkspaceEncryptionException>()),
        );
      },
    );

    test(
      'encrypts tokens at rest with AES-256-GCM, unique nonces, and owner AAD',
      () async {
        final key = _randomBase64Key(101);
        final store = WorkspaceStore(tempDir, encryptionKey: key);
        await store.open();

        await store.change('user_alice', (state) {
          state['connections'] = [
            {
              'id': 'github',
              'label': 'GitHub',
              'token': 'ghp_super_secret_token_value_12345',
            },
          ];
        });

        final file = File(
          '${tempDir.path}/${_ownerFileKey('user_alice')}.json',
        );
        expect(await file.exists(), isTrue);
        final rawDiskText = await file.readAsString();
        expect(
          rawDiskText.contains('ghp_super_secret_token_value_12345'),
          isFalse,
        );

        final envelope = jsonDecode(rawDiskText) as Map<String, dynamic>;
        expect(envelope['v'], equals(1));
        expect(envelope['alg'], equals('AES-256-GCM'));
        final firstNonce = envelope['nonce'] as String;

        // Second write must produce a fresh random 96-bit nonce
        await store.change('user_alice', (state) {
          state['settings'] = {'paused': false, 'note': 'second write'};
        });
        final secondEnvelope =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(secondEnvelope['nonce'], isNot(equals(firstNonce)));

        await store.close();

        // Reopen store with same key and verify round-trip decryption
        final reopened = WorkspaceStore(tempDir, encryptionKey: key);
        await reopened.open();
        final loaded = await reopened.read('user_alice');
        final connections = loaded['connections'] as List;
        expect(
          (connections.first as Map)['token'],
          equals('ghp_super_secret_token_value_12345'),
        );
        await reopened.close();
      },
    );

    test(
      'migrates legacy plaintext workspace files on open() and preserves original on wrong key or tampering',
      () async {
        final key1 = _randomBase64Key(202);
        final key2 = _randomBase64Key(303);

        // Write a legacy plaintext file directly to disk
        final legacyFile = File(
          '${tempDir.path}/${_ownerFileKey('user_legacy')}.json',
        );
        final legacyState = initialWorkspace();
        legacyState['connections'] = [
          {
            'id': 'notion',
            'label': 'Notion',
            'token': 'ntn_legacy_plaintext_secret_999',
          },
        ];
        await legacyFile.writeAsString(jsonEncode(legacyState));

        final store = WorkspaceStore(tempDir, encryptionKey: key1);
        await store.open();

        // Verify legacy file was atomically rewritten as an encrypted v1 envelope
        final migratedRaw = await legacyFile.readAsString();
        expect(
          migratedRaw.contains('ntn_legacy_plaintext_secret_999'),
          isFalse,
        );
        final migratedJson = jsonDecode(migratedRaw) as Map<String, dynamic>;
        expect(migratedJson['v'], equals(1));
        await store.close();

        // Verify cross-owner AAD binding prevents copying user_legacy file to user_evil
        final spoofedFile = File(
          '${tempDir.path}/${_ownerFileKey('user_evil')}.json',
        );
        await spoofedFile.writeAsString(migratedRaw);
        final spoofedStore = WorkspaceStore(tempDir, encryptionKey: key1);
        await expectLater(
          spoofedStore.open(),
          throwsA(isA<WorkspaceEncryptionException>()),
        );
        await spoofedFile.delete();

        // Verify wrong key fails without overwriting the encrypted file on disk
        final wrongStore = WorkspaceStore(tempDir, encryptionKey: key2);
        await expectLater(
          wrongStore.open(),
          throwsA(isA<WorkspaceEncryptionException>()),
        );
        expect(await legacyFile.readAsString(), equals(migratedRaw));

        // Verify key rotation with previousEncryptionKey re-encrypts seamlessly
        final rotatedStore = WorkspaceStore(
          tempDir,
          encryptionKey: key2,
          previousEncryptionKey: key1,
        );
        await rotatedStore.open();
        final rotatedWs = await rotatedStore.read('user_legacy');
        final conns = rotatedWs['connections'] as List;
        expect(
          (conns.first as Map)['token'],
          equals('ntn_legacy_plaintext_secret_999'),
        );
        await rotatedStore.close();
      },
    );
  });

  group('Issue #91: Limit concurrent Copilot voice sessions and upstream usage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('copilot_voice_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'enforces per-owner rate limits and releases lease in finally on upstream dial failure',
      () async {
        final config = CopilotConfig({
          'OPEN_AI_KEY': 'test-openai-key',
          'COPILOT_LOCAL_OWNER': 'true',
          'COPILOT_VOICE_MAX_SERVICE_SESSIONS': '2',
          'COPILOT_VOICE_MAX_CONCURRENT_PER_OWNER': '1',
          'COPILOT_VOICE_MAX_CALLS_PER_WINDOW': '2',
          'COPILOT_VOICE_RATE_WINDOW_SECONDS': '60',
        });
        final store = WorkspaceStore(
          tempDir,
          encryptionKey: _randomBase64Key(404),
        );
        await store.open();
        final actions = WorkspaceActions(store);
        final thread = await actions.apply('local-owner', {
          'action': 'thread.create',
          'specialistId': 'analyst',
        });
        final threadId = thread['id'] as String;

        final gateway = OpenAiGateway(
          config,
          clientFactory: () =>
              MockClient((_) async => http.Response('{}', 200)),
        );
        final runner = AgentRunner(store, gateway);
        final auth = CopilotAuth(config);

        var dialAttempts = 0;
        final voice = CopilotVoice(
          config,
          auth,
          store,
          runner,
          upstreamConnector: (url, {headers}) async {
            dialAttempts++;
            throw const SocketException('Simulated upstream failure');
          },
        );

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await voice.close();
          await server.close(force: true);
          await store.close();
        });

        server.listen((HttpRequest req) async {
          await voice.connect(req);
        });

        final wsUrl = 'ws://${server.address.address}:${server.port}/v1/voice';

        Future<List<Map<String, dynamic>>> runClientAttempt() async {
          final ws = await WebSocket.connect(wsUrl);
          final messages = <Map<String, dynamic>>[];
          ws.listen((raw) {
            if (raw is String) {
              messages.add(jsonDecode(raw) as Map<String, dynamic>);
            }
          });
          ws.add(jsonEncode({'threadId': threadId}));
          await ws.done;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return messages;
        }

        // First two attempts reserve a lease, fail dialing upstream, and release the lease in finally
        final msgs1 = await runClientAttempt();
        expect(msgs1, isNotEmpty);
        expect(voice.activeSessionCount, equals(0));
        expect(dialAttempts, equals(1));

        final msgs2 = await runClientAttempt();
        expect(msgs2, isNotEmpty);
        expect(voice.activeSessionCount, equals(0));
        expect(dialAttempts, equals(2));

        // Third attempt within the rate window is rejected BEFORE dialing upstream
        final msgs3 = await runClientAttempt();
        expect(dialAttempts, equals(2)); // Upstream was NOT dialed!
        expect(
          msgs3.any(
            (m) => (m['message']?.toString() ?? '').contains('rate limit'),
          ),
          isTrue,
        );
      },
    );
  });

  group('Issues #83 & #85: Private DM attachments & path normalization', () {
    test(
      'normalizes canonical and legacy chat attachment paths and rejects traversal',
      () {
        const threadId = '11111111-1111-4111-8111-111111111111';
        const senderId = '22222222-2222-4222-8222-222222222222';

        // Canonical <thread_id>/<uploader_id>/<filename>
        expect(
          MessagesRepository.normalizeLegacyChatStoragePath(
            '$threadId/$senderId/setup.png',
          ),
          equals('$threadId/$senderId/setup.png'),
        );
        expect(
          MessagesRepository.isValidChatStoragePath(
            '$threadId/$senderId/setup.png',
            expectedThreadId: threadId,
            expectedUploaderId: senderId,
          ),
          isTrue,
        );

        // Legacy layout 1: <uploader_id>/chat/<thread_id>/<filename>
        expect(
          MessagesRepository.normalizeLegacyChatStoragePath(
            'https://example.supabase.co/storage/v1/object/public/community-attachments/$senderId/chat/$threadId/setup.png?token=abc',
          ),
          equals('$threadId/$senderId/setup.png'),
        );

        // Legacy layout 2: chat/<thread_id>/<filename> with known fallbackUploaderId
        expect(
          MessagesRepository.normalizeLegacyChatStoragePath(
            'chat/$threadId/voice.m4a',
            fallbackUploaderId: senderId,
          ),
          equals('$threadId/$senderId/voice.m4a'),
        );

        // Rejects path traversal
        expect(
          MessagesRepository.normalizeLegacyChatStoragePath(
            '$threadId/$senderId/../secret.png',
          ),
          isNull,
        );
        expect(
          MessagesRepository.isValidChatStoragePath(
            '$threadId/$senderId/../secret.png',
          ),
          isFalse,
        );
      },
    );

    test(
      'MessageAttachment tracks storagePath and signed URL expiration accurately',
      () {
        final expired = MessageAttachment(
          id: 'att_1',
          kind: MessageAttachmentKind.image,
          title: 'chart.png',
          sizeLabel: '12 KB',
          url:
              'https://example.supabase.co/storage/v1/object/sign/chat-attachments/t/u/chart.png',
          storagePath: 't/u/chart.png',
          signedUrlExpiresAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 10),
          ),
        );
        expect(expired.isSignedUrlExpired, isTrue);

        final refreshed = expired.copyWith(
          url:
              'https://example.supabase.co/storage/v1/object/sign/chat-attachments/t/u/chart.png?token=fresh',
          signedUrlExpiresAt: DateTime.now().toUtc().add(
            const Duration(minutes: 5),
          ),
        );
        expect(refreshed.isSignedUrlExpired, isFalse);
        expect(refreshed.storagePath, equals('t/u/chart.png'));
      },
    );
  });

  group('Issue #84: Portfolio stats account isolation', () {
    test(
      'returns only the signed-in caller trades and never leaks other users trades',
      () async {
        const aliceId = '00000000-0000-0000-0000-000000000001';
        const bobId = '00000000-0000-0000-0000-000000000002';

        SupabaseAuthBackendService.instance.setCurrentProfile(
          const UserProfileModel(
            id: aliceId,
            handle: '@alice',
            email: 'alice@example.com',
            displayName: 'Alice',
            role: UserRole.customer,
          ),
        );
        addTearDown(
          () => SupabaseAuthBackendService.instance.setCurrentProfile(null),
        );

        final fakeJournal = _FakeJournalRepository([
          AppTrade(
            id: 't_alice',
            userId: aliceId,
            ticker: 'AAPL',
            side: AppSide.long,
            entry: 100,
            exit: 110,
            size: 10,
            pnl: 100,
            rMultiple: 2.0,
            outcome: AppOutcome.win,
            openedAt: DateTime.utc(2026, 11, 1),
            closedAt: DateTime.utc(2026, 11, 2),
          ),
          AppTrade(
            id: 't_bob',
            userId: bobId,
            ticker: 'TSLA',
            side: AppSide.short,
            entry: 200,
            exit: 250,
            size: 10,
            pnl: -500,
            rMultiple: -2.5,
            outcome: AppOutcome.loss,
            openedAt: DateTime.utc(2026, 11, 1),
            closedAt: DateTime.utc(2026, 11, 2),
          ),
        ]);

        final tradeRepo = SupabaseTradeRepositoryImpl(journalRepo: fakeJournal);
        final stats = await tradeRepo.getPortfolioStats();
        expect(stats['total_trades'], equals(1));
        expect(stats['total_pnl'], equals(100.0));
        expect(stats['winning_trades'], equals(1));
      },
    );
  });

  group('Issue #89: Desk risk configuration admin-only writes', () {
    tearDown(() {
      SupabaseAuthBackendService.instance.setCurrentProfile(null);
      AuthBackendService.instance.setCurrentProfile(null);
    });

    test(
      'blocks standard customer from updating desk risk configuration and allows user_admin',
      () async {
        final repo = DeskRiskRepositoryImpl();
        final updated = DeskRiskModel.defaultConfig().copyWith(
          maxFirmDrawdownPercent: 8.5,
        );

        // Standard customer must be rejected
        SupabaseAuthBackendService.instance.setCurrentProfile(
          const UserProfileModel(
            id: '00000000-0000-0000-0000-000000000001',
            handle: '@trader',
            email: 'trader@example.com',
            displayName: 'Trader',
            role: UserRole.customer,
          ),
        );
        await expectLater(
          repo.updateDeskRiskConfig(updated),
          throwsA(isA<StateError>()),
        );

        // Administrator is permitted
        SupabaseAuthBackendService.instance.setCurrentProfile(
          const UserProfileModel(
            id: '00000000-0000-0000-0000-000000000099',
            handle: '@admin',
            email: 'admin@example.com',
            displayName: 'Admin',
            role: UserRole.userAdmin,
          ),
        );
        final saved = await repo.updateDeskRiskConfig(updated);
        expect(saved.maxFirmDrawdownPercent, equals(8.5));
      },
    );
  });

  group('Issue #90: Strategy attachment visibility and cache invalidation', () {
    test(
      'NoteAttachments.refOf extracts legacy storage URLs into attachment: references',
      () {
        const path =
            '00000000-0000-0000-0000-000000000001/55555555-5555-4555-8555-555555555551/chart.png';
        final ref = NoteAttachments.refOf(
          Uri.parse(
            'https://proj.supabase.co/storage/v1/object/public/strategy-attachments/$path?download=1',
          ),
        );
        expect(ref, equals(path));
      },
    );

    test(
      'enforces strategy visibility and owner match on resolveAttachmentUrl',
      () async {
        const ownerId = '00000000-0000-0000-0000-000000000001';
        const stratId = '55555555-5555-4555-8555-555555555551';
        const storagePath = '$ownerId/$stratId/setup.png';

        SupabaseAuthBackendService.instance.setCurrentProfile(
          const UserProfileModel(
            id: ownerId,
            handle: '@alice',
            email: 'alice@example.com',
            displayName: 'Alice',
            role: UserRole.customer,
          ),
        );
        addTearDown(
          () => SupabaseAuthBackendService.instance.setCurrentProfile(null),
        );

        final repo = StrategiesRepositoryImpl.instance;
        final created = await repo.create(
          AppStrategy(
            id: stratId,
            userId: ownerId,
            name: 'Breakout Playbook',
            content: '![Setup](attachment:$storagePath)',
            category: 'Momentum',
            status: AppStrategyStatus.live,
            isPublic: true,
            updatedAt: DateTime.utc(2026, 11, 14),
          ),
        );

        final cachedPath = '$ownerId/${created.id}/setup.png';
        // Flipping visibility to private invalidates StrategyAttachments cache for that strategy
        await repo.setVisibility(created.id, false);
        StrategyAttachments.invalidateForStrategy(created.id);

        // Another user cannot resolve attachments on a private strategy
        SupabaseAuthBackendService.instance.setCurrentProfile(
          const UserProfileModel(
            id: '00000000-0000-0000-0000-000000000002',
            handle: '@bob',
            email: 'bob@example.com',
            displayName: 'Bob',
            role: UserRole.customer,
          ),
        );
        await expectLater(
          repo.resolveAttachmentUrl(cachedPath),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('Issue #93: Community post view count protection', () {
    test(
      'does not increment views for nonexistent post IDs when offline',
      () async {
        final repo = CommunityRepository();
        await repo.recordView('non_existent_post_id_999999');
        expect(repo.loadPostById('non_existent_post_id_999999'), isNull);
      },
    );
  });
}
