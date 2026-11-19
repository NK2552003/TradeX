import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/widgets/app_scaffold.dart';
import 'package:alphajournal/core/navigation/role_navigation_config.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/presentation/views/community_explore_view.dart';
import 'package:alphajournal/features/community/presentation/views/community_feed_view.dart';
import 'package:alphajournal/features/workspace/ui/workspace_screen.dart';
import 'package:alphajournal/features/community/presentation/views/community_follow_view.dart';
import 'package:alphajournal/features/community/presentation/views/community_profile_view.dart';

void main() {
  test(
    'consumer navigation excludes dashboard, portfolio and root watchlists',
    () {
      final consumer = RoleNavigationConfig.forRole(UserRole.customer);
      for (final destination in ['overview', 'portfolio', 'watchlists']) {
        expect(consumer.allows(destination), isFalse);
        expect(
          consumer.mobileMoreItems.any((item) => item.id == destination),
          isFalse,
        );
      }
      expect(
        RoleNavigationConfig.forRole(UserRole.affiliate).allows('overview'),
        isTrue,
      );
      expect(
        RoleNavigationConfig.forRole(UserRole.userAdmin).allows('overview'),
        isTrue,
      );
    },
  );

  testWidgets('global mobile header has no profile avatar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppTopBar(title: 'Feed')),
      ),
    );
    expect(find.byType(UiAvatar), findsNothing);
    final title = tester.widget<Text>(find.text('Feed'));
    expect(title.style?.decoration, TextDecoration.none);
    expect(title.style?.inherit, isFalse);
  });

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('global header fits $width px with large text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(1.3),
              ),
              child: AppTopBar(
                title: 'Community Feed',
                onSearch: () {},
                onSearchChanged: (_) {},
                onNotifications: () {},
                onHelp: () {},
                unread: 12,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(UiAvatar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile community dock opens each selected page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: AppScaffold(initialDestination: 'settings')),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.bySemanticsLabel('Community').last);
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<AppShell>(find.byType(AppShell)).selectedId,
      'community',
    );
    expect(find.bySemanticsLabel('Explore'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Explore').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<AppShell>(find.byType(AppShell)).selectedId,
      'community_explore',
    );
    expect(find.byType(CommunityExploreView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Network').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<AppShell>(find.byType(AppShell)).selectedId,
      'community_network',
    );
    expect(find.byType(CommunityFollowView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Profile').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<AppShell>(find.byType(AppShell)).selectedId,
      'community_profile',
    );
    expect(find.byType(CommunityProfileView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Switch to App'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Writing Desk').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<AppShell>(find.byType(AppShell)).selectedId,
      'workspace',
    );
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Community').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CommunityFeedView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop global header omits Features pill while keeping Help button',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: AppScaffold(initialDestination: 'workspace')),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(const ValueKey<String>('header-feature-guide-btn')),
        findsNothing,
      );
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
