import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/workspace/ui/workspace_screen.dart';

void main() {
  testWidgets('workspace restores calendar mode and filters after leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WorkspaceViewState? saved;
    Widget workspace({WorkspaceViewState? viewState}) => MaterialApp(
      home: Scaffold(
        body: WorkspaceScreen(
          viewState: viewState,
          onViewStateChanged: (state) => saved = state,
          onOpenFeature: (_) {},
          searchQuery: 'review',
        ),
      ),
    );
    await tester.pumpWidget(workspace());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(saved, isNotNull);
    expect(saved!.isMonthView, isTrue);
    final snapshot = saved!;
    await tester.pumpWidget(workspace(viewState: snapshot));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(saved!.isMonthView, isTrue);
    expect(saved!.selectedDay, snapshot.selectedDay);
    expect(saved!.notesFilter, snapshot.notesFilter);
  });
}
