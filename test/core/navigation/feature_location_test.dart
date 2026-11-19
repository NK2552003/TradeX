import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/copilot/copilot.dart';
import 'package:alphajournal/core/navigation/feature_location_scope.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/presentation/views/community_feed_view.dart';

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Community feed tabs restore from URLs and emit URL selections', (
    tester,
  ) async {
    viewport(tester);
    final repo = CommunityRepository();
    addTearDown(repo.dispose);
    Uri? next;
    Widget page(Uri location) => MaterialApp(
      home: FeatureLocationScope(
        location: location,
        onNavigate: (uri) => next = uri,
        child: Scaffold(
          body: CommunityFeedView(
            currentUser: repo.currentAuthor,
            repository: repo,
            onPostTap: (_) {},
            onAuthorTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(Uri.parse('/community_feed?tab=news')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TabBar>(find.byType(TabBar).first).controller!.index,
      3,
    );
    await tester.ensureVisible(find.text('Crypto').first);
    await tester.tap(find.text('Crypto').first);
    await tester.pumpAndSettle();
    expect(next!.queryParameters['tab'], 'crypto');
    await tester.pumpWidget(page(Uri.parse('/community_feed?tab=following')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TabBar>(find.byType(TabBar).first).controller!.index,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Copilot tablet restores and publishes workspace URL selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = CopilotController(autoLoad: false)..connected = true;
    addTearDown(controller.dispose);
    Uri? next;
    Widget page(String location) => MaterialApp(
      home: Scaffold(
        body: FeatureLocationScope(
          location: Uri.parse(location),
          onNavigate: (uri) => next = uri,
          child: CopilotScreen(repository: controller),
        ),
      ),
    );
    await tester.pumpWidget(page('/ai_copilot?tab=workspace'));
    await tester.pumpAndSettle();
    expect(tester.widget<UiTabs>(find.byType(UiTabs).first).index, 1);
    await tester.tap(find.text('Conversation').first);
    await tester.pumpAndSettle();
    expect(next?.queryParameters['tab'], 'chat');
    await tester.pumpWidget(page('/ai_copilot?tab=chat'));
    await tester.pumpAndSettle();
    expect(tester.widget<UiTabs>(find.byType(UiTabs).first).index, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
