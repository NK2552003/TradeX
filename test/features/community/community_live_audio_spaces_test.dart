import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/community_root_screen.dart';
import 'package:tradex/features/community/presentation/widgets/community_audio_mini_player.dart';
import 'package:tradex/features/community/presentation/widgets/community_host_live_space_dialog.dart';

void main() {
  group('Live Audio Spaces & Rooms Feature Tests', () {
    late CommunityRepository repository;

    setUp(() {
      repository = CommunityRepository();
    });

    test('CommunityRepository initializes with seeded active and upcoming live rooms', () {
      expect(repository.liveRooms.length, greaterThanOrEqualTo(2));
      expect(repository.upcomingRooms.length, greaterThanOrEqualTo(2));
      expect(repository.isTunedIntoLiveRoom, isFalse);
      expect(repository.activeTunedRoom, isNull);
      expect(repository.isAudioMuted, isTrue);
      expect(repository.isHandRaised, isFalse);

      final active = repository.liveRooms.first;
      expect(active.isLive, isTrue);
      expect(active.listenerCount, greaterThan(0));
      expect(active.speakers, isNotEmpty);
      expect(active.pinnedSetup, isNotNull);

      final upcoming = repository.upcomingRooms.first;
      expect(upcoming.isScheduled, isTrue);
      expect(upcoming.scheduledFor, isNotNull);
    });

    test('Tuning into room updates repository tuned room state and listener count', () {
      final active = repository.liveRooms.first;
      final initialListeners = active.listenerCount;

      repository.tuneIntoRoom(active.id);
      expect(repository.isTunedIntoLiveRoom, isTrue);
      expect(repository.activeTunedRoom?.id, equals(active.id));
      expect(repository.activeTunedRoom?.listenerCount, equals(initialListeners + 1));

      // Toggle mute and hand raise
      repository.toggleMute();
      expect(repository.isAudioMuted, isFalse);
      repository.toggleHandRaised();
      expect(repository.isHandRaised, isTrue);

      // Leaving room resets tuned state and listener count
      repository.leaveRoom();
      expect(repository.isTunedIntoLiveRoom, isFalse);
      expect(repository.activeTunedRoom, isNull);
      expect(repository.isHandRaised, isFalse);
      expect(repository.liveRooms.first.listenerCount, equals(initialListeners));
    });

    test('Toggling reminder on upcoming scheduled room', () {
      final upcoming = repository.upcomingRooms.first;
      expect(upcoming.hasReminder, isFalse);

      repository.toggleRoomReminder(upcoming.id);
      expect(repository.upcomingRooms.first.hasReminder, isTrue);

      repository.toggleRoomReminder(upcoming.id);
      expect(repository.upcomingRooms.first.hasReminder, isFalse);
    });

    test('createLiveRoom adds a new live audio room and tunes in immediately', () async {
      final room = await repository.createLiveRoom(
        title: 'Nifty Midcap Scalp Floor',
        topic: 'Live scalp triggers and 5-min range breakouts',
        category: 'Equities & Breakouts',
        startNow: true,
        pinnedSetup: const LivePinnedSetup(
          ticker: 'MIDCPNIFTY',
          side: 'LONG',
          entry: 12450.0,
          stopLoss: 12380.0,
          target: 12600.0,
          note: 'Breakout above day high',
        ),
      );

      expect(room.title, equals('Nifty Midcap Scalp Floor'));
      expect(repository.isTunedIntoLiveRoom, isTrue);
      expect(repository.activeTunedRoom?.id, equals(room.id));
      expect(repository.activeTunedRoom?.listenerCount, equals(1));
      expect(repository.activeTunedRoom?.pinnedSetup?.ticker, equals('MIDCPNIFTY'));
    });

    testWidgets('CommunityAudioMiniPlayer renders room details, mute button and leave action', (WidgetTester tester) async {
      final active = repository.liveRooms.first;
      repository.tuneIntoRoom(active.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityAudioMiniPlayer(repository: repository),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CommunityAudioMiniPlayer), findsOneWidget);
      expect(find.text(active.title), findsOneWidget);
      expect(find.textContaining('listening'), findsOneWidget);

      // Verify leave icon is present and functional
      final leaveButton = find.byTooltip('Leave Quietly');
      expect(leaveButton, findsOneWidget);
      await tester.tap(leaveButton);
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.isTunedIntoLiveRoom, isFalse);
    });

    testWidgets('CommunityHostLiveSpaceDialog renders form controls and submits new room', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CommunityHostLiveSpaceDialog.show(
                  context,
                  repository: repository,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Host a Live Audio Space'), findsOneWidget);
      expect(find.text('Space Title'), findsOneWidget);
      expect(find.text('Agenda / Topic'), findsOneWidget);
      expect(find.text('Market Category'), findsOneWidget);
      expect(find.text('Go Live Immediately'), findsOneWidget);

      // Enter space title into first UiInput
      await tester.enterText(
        find.byType(UiInput).first,
        'Special Expiry Gamma Floor',
      );
      await tester.pumpAndSettle();

      // Tap Start Space Now
      await tester.tap(find.text('Start Space Now'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(repository.isTunedIntoLiveRoom, isTrue);
      expect(repository.activeTunedRoom?.title, equals('Special Expiry Gamma Floor'));
    });

    testWidgets('CommunityRootScreen mounts CommunityAudioMiniPlayer when tuned into live space', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityRootScreen(
              repository: repository,
              embedInScaffold: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Initially not tuned in -> no mini player
      expect(find.byType(CommunityAudioMiniPlayer), findsNothing);

      // Tune into active live room
      repository.tuneIntoRoom(repository.liveRooms.first.id);
      await tester.pump(const Duration(milliseconds: 200));

      // Mini player is now docked in the root screen
      expect(find.byType(CommunityAudioMiniPlayer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CommunityAudioMiniPlayer),
          matching: find.text(repository.liveRooms.first.title),
        ),
        findsOneWidget,
      );
    });
  });
}
