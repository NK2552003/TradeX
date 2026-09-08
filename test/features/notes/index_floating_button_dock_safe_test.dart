import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/journal/ui/journal_entry_screen.dart';
import 'package:tradex/features/notes/ui/note_preview_screen.dart';
import 'package:tradex/features/strategies/ui/strategy_detail_screen.dart';

Widget _host(Widget child) => UiApp(
  theme: UiTheme.dark(),
  builder: (BuildContext context) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  const Size phone = Size(390, 844);
  const double dockInset = 88;

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child,
  ) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: phone,
          padding: EdgeInsets.only(bottom: dockInset),
        ),
        child: _host(child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'trader notes index floating button is dock safe and not too high on mobile',
    (WidgetTester tester) async {
      final AppNote note = DemoDataSource.instance.notes().first;
      await pumpAt(
        tester,
        NotePreviewScreen(note: note, onClose: () {}, onEdit: () {}),
      );

      final Finder outline = find.byTooltip('Jump to section');
      expect(outline, findsOneWidget);

      final double bottomDy = tester.getBottomRight(outline).dy;
      // Must be above the dock (dock-safe).
      expect(bottomDy, lessThanOrEqualTo(phone.height - dockInset));
      // Must not be too high (previously was around 644 on an 844 screen with 88 dock).
      // Now it sits just above the dock (near ~732).
      expect(bottomDy, greaterThan(phone.height - dockInset - 40));
    },
  );

  testWidgets(
    'strategy notes index floating button is dock safe and not too high on mobile',
    (WidgetTester tester) async {
      final AppStrategy strategy = DemoDataSource.instance.strategies().first;
      await pumpAt(
        tester,
        StrategyDetailScreen(strategy: strategy, onClose: () {}, onEdit: () {}),
      );

      final Finder outline = find.byTooltip('Jump to section');
      expect(outline, findsOneWidget);

      final double bottomDy = tester.getBottomRight(outline).dy;
      // Must be above the dock (dock-safe).
      expect(bottomDy, lessThanOrEqualTo(phone.height - dockInset));
      // Must not be too high.
      expect(bottomDy, greaterThan(phone.height - dockInset - 40));
    },
  );

  testWidgets(
    'journal notes index floating button is dock safe and not too high on mobile',
    (WidgetTester tester) async {
      final AppTrade entry = DemoDataSource.instance.trades().first;
      await pumpAt(
        tester,
        JournalEntryScreen(entry: entry, onClose: () {}, onEdit: () {}),
      );

      final Finder outline = find.byTooltip('Jump to section');
      expect(outline, findsOneWidget);

      final double bottomDy = tester.getBottomRight(outline).dy;
      // Must be above the dock (dock-safe).
      expect(bottomDy, lessThanOrEqualTo(phone.height - dockInset));
      // Must not be too high.
      expect(bottomDy, greaterThan(phone.height - dockInset - 40));
    },
  );
}
