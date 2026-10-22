import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/navigation/feature_location_scope.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/views/community_feed_view.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/presentation/ai_assistant_root_screen.dart';
import 'package:tradex/features/ai_assistant/presentation/views/ai_insights_view.dart';
import 'package:tradex/features/ai_assistant/presentation/views/ai_create_view.dart';

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
      4,
    );
    await tester.ensureVisible(find.text('Crypto').first);
    await tester.tap(find.text('Crypto').first);
    await tester.pumpAndSettle();
    expect(next!.queryParameters['tab'], 'crypto');
    await tester.pumpWidget(page(Uri.parse('/community_feed?tab=following')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TabBar>(find.byType(TabBar).first).controller!.index,
      2,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'AI tabs restore from URLs and keep browser selections synchronized',
    (tester) async {
      viewport(tester);
      final repo = AiAssistantRepository();
      addTearDown(repo.dispose);
      Uri? next;
      Widget page(Uri location) => MaterialApp(
        home: FeatureLocationScope(
          location: location,
          onNavigate: (uri) => next = uri,
          child: Scaffold(body: AiAssistantRootScreen(repository: repo)),
        ),
      );
      await tester.pumpWidget(page(Uri.parse('/ai_copilot?tab=insights')));
      await tester.pumpAndSettle();
      expect(find.byType(AiInsightsView), findsWidgets);
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      expect(next!.queryParameters['tab'], 'chat');
      await tester.pumpWidget(page(Uri.parse('/ai_copilot?tab=create')));
      await tester.pumpAndSettle();
      expect(find.byType(AiCreateView), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
