import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/presentation/community_root_screen.dart';
import 'package:alphajournal/features/strategies/ui/strategy_editor_screen.dart';
import 'package:alphajournal/features/workspace/ui/workspace_screen.dart';

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'workspace retains its vertical position after leaving and returning',
    (tester) async {
      viewport(tester, const Size(1024, 700));
      WorkspaceViewState? saved;
      Widget workspace(WorkspaceViewState? state) => MaterialApp(
        home: Scaffold(
          body: WorkspaceScreen(
            viewState: state,
            onViewStateChanged: (value) => saved = value,
            onOpenFeature: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(workspace(null));
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(UiPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scroll, const Offset(0, -450));
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(scroll).position.pixels;
      expect(offset, greaterThan(100));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(saved!.scrollOffset, offset);
      await tester.pumpWidget(workspace(saved));
      await tester.pumpAndSettle();
      final restored = find
          .descendant(
            of: find.byType(UiPage),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(
        tester.state<ScrollableState>(restored).position.pixels,
        closeTo(offset, 1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'strategy split mode adapts after resize and its More menu requires publication consent',
    (tester) async {
      viewport(tester, const Size(1440, 1100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StrategyEditorScreen(
              strategy: const AppStrategy(
                id: '',
                name: 'Private playbook',
                content: '# Rules\nWait for confirmation.',
              ),
              initialMode: StrategyEditorMode.split,
              onClose: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Live preview'), findsOneWidget);
      tester.view.physicalSize = const Size(768, 1100);
      await tester.pumpAndSettle();
      expect(find.text('Split'), findsNothing);
      final modes = tester.widget<UiToggleGroup<StrategyEditorMode>>(
        find.byType(UiToggleGroup<StrategyEditorMode>),
      );
      expect(modes.value, StrategyEditorMode.write);
      await tester.tap(find.text('Read').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find
            .ancestor(
              of: find.byTooltip('More'),
              matching: find.byType(UiDropdownMenu),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Share to the feed'), findsOneWidget);
      await tester.tap(find.text('Share to the feed'));
      await tester.pumpAndSettle();
      expect(find.text('Publish this playbook?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.byTooltip('More'),
              matching: find.byType(UiDropdownMenu),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Share to the feed'), findsOneWidget);
      expect(find.text('Make private'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Community top tabs notify the URL owner and sidebar Feed restores the feed',
    (tester) async {
      viewport(tester, const Size(1440, 1000));
      final repository = CommunityRepository();
      addTearDown(repository.dispose);
      int? tab;
      Widget root(int initial) => MaterialApp(
        home: Scaffold(
          body: CommunityRootScreen(
            repository: repository,
            embedInScaffold: false,
            initialTabIndex: initial,
            onTabChanged: (index) => tab = index,
          ),
        ),
      );
      await tester.pumpWidget(root(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore').first);
      await tester.pumpAndSettle();
      expect(tab, 1);
      await tester.pumpWidget(root(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(root(0));
      await tester.pumpAndSettle();
      expect(find.text('For you'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
