import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/community/presentation/community_root_screen.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';

void main() {
  testWidgets(
    'opening a post preserves its community shell across the URL echo',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var destination = 'community';
      AppLinkOpenRequest? request;
      var sequence = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) => AppScaffold(
              initialDestination: destination,
              initialOpenRequest: request,
              onOpenRecord: (ref) => update(() {
                destination = 'community_feed';
                request = AppLinkOpenRequest(
                  kind: ref.kind,
                  id: ref.id,
                  seq: ++sequence,
                );
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester.state(find.byType(CommunityRootScreen));
      await tester.tap(find.byType(CommunityPostCard).first);
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.state(find.byType(CommunityRootScreen)), same(original));
        expect(find.byType(CommunityPostDetailView), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(
        find.byKey(const ValueKey('settings-side-sheet-surface')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close panel'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityPostDetailView), findsNothing);
      expect(find.byType(CommunityPostCard), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
