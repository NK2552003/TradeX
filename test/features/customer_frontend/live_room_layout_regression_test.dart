import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_live_room_sheet.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('audio preview sheet fits $width px', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommunityLiveRoomSheet(
              hostName: 'Rajesh Patel',
              listenerCount: 142,
              pinnedSetup: LivePinnedSetup(
                ticker: 'NIFTY 24,850 CE',
                side: 'LONG',
                entry: 142.5,
                stopLoss: 118,
                target: 210,
                note: 'VWAP breakout with a long setup description',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('SIMULATED AUDIO (BETA)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
