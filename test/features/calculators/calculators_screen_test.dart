import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/calculators/calculator_registry.dart';
import 'package:tradex/features/calculators/ui/calculators_screen.dart';
import 'package:tradex/features/calculators/ui/position_size_screen.dart';
import 'package:tradex/features/calculators/ui/risk_reward_screen.dart';

/// Wraps [child] the way `AppShell` does, so tokens and responsive metrics
/// resolve exactly as they do in the app.
Widget _host(Widget child) => UiApp(
  theme: UiTheme.dark(),
  builder: (BuildContext context) => MaterialApp(home: Scaffold(body: child)),
);

const Size _desktopSize = Size(1400, 1200);
const Size _phoneSize = Size(390, 844);

/// The registry entry behind a given id, for tests that must not hardcode names.
AppCalculatorMeta _meta(String id) =>
    kAllCalculators.firstWhere((AppCalculatorMeta m) => m.id == id);

Finder _navItem(String name) => find.descendant(
  of: find.byType(AppCalculatorNavItem),
  matching: find.text(name),
);

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    Size size = _desktopSize,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(child));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> openOnPhone(WidgetTester tester, String id) async {
    await pumpAt(tester, const CalculatorsScreen(), size: _phoneSize);
    final Finder item = _navItem(_meta(id).name);
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  Future<void> openToolsSidebar(WidgetTester tester) async {
    final Finder fab = find.byKey(
      const ValueKey<String>('calculator_tools_fab'),
    );
    await tester.tap(fab);
    await tester.pumpAndSettle();
  }

  group('the desktop workbench', () {
    testWidgets(
      'displays live tool with floating button to open right sidebar overlay',
      (WidgetTester tester) async {
        await pumpAt(tester, const CalculatorsScreen());

        expect(
          find.byKey(const ValueKey<String>('calculator_tools_fab')),
          findsOneWidget,
        );
        expect(find.byType(PositionSizeCalculatorScreen), findsOneWidget);
        // The readout band leads with the answer, in overline case.
        expect(find.text('QUANTITY TO TRADE'), findsOneWidget);
        // Nothing to navigate back from — the tool lives in the workspace.
        expect(find.byTooltip('Back to calculators'), findsNothing);

        // Open floating right sidebar
        await openToolsSidebar(tester);
        expect(find.text('Tools'), findsWidgets);
        expect(find.byType(AppCalculatorNavItem), findsNWidgets(22));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('search narrows the index by name and by tag', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const CalculatorsScreen());
      await openToolsSidebar(tester);

      final Finder search = find.descendant(
        of: find.byKey(const ValueKey<String>('calculator_tool_search')),
        matching: find.byType(TextField),
      );

      await tester.enterText(search, 'fibonacci');
      await tester.pumpAndSettle();
      expect(find.byType(AppCalculatorNavItem), findsOneWidget);
      expect(find.text('Fibonacci Levels'), findsWidgets);

      // 'golden ratio' is a tag on the same tool, not part of its name.
      await tester.enterText(search, 'golden ratio');
      await tester.pumpAndSettle();
      expect(find.byType(AppCalculatorNavItem), findsOneWidget);
      expect(find.text('Fibonacci Levels'), findsWidgets);
    });

    testWidgets('a query that matches nothing offers a way back', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const CalculatorsScreen());
      await openToolsSidebar(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('calculator_tool_search')),
          matching: find.byType(TextField),
        ),
        'zzzzz',
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppCalculatorNavItem), findsNothing);
      expect(find.text('No tools found'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.byType(AppCalculatorNavItem), findsNWidgets(22));
    });

    testWidgets('a category filter keeps only that category', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const CalculatorsScreen());
      await openToolsSidebar(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('calculator_category_filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppCalculatorCategory.tax.label).last);
      await tester.pumpAndSettle();

      final int taxCount = kAllCalculators
          .where(
            (AppCalculatorMeta m) => m.category == AppCalculatorCategory.tax,
          )
          .length;
      expect(find.byType(AppCalculatorNavItem), findsNWidgets(taxCount));
      // Filtering narrows the index only. The tool in the workspace is work in
      // progress, so it survives a filter that would have hidden its entry.
      expect(find.byType(PositionSizeCalculatorScreen), findsOneWidget);
      expect(_navItem(_meta('position_size').name), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching tools swaps the pane, not the page', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const CalculatorsScreen());
      await openToolsSidebar(tester);

      await tester.tap(_navItem(_meta('risk_reward').name));
      await tester.pumpAndSettle();

      expect(find.byType(RiskRewardCalculatorScreen), findsOneWidget);
      expect(find.byType(PositionSizeCalculatorScreen), findsNothing);
      expect(find.byType(AppCalculatorWorkspaceSkeleton), findsNothing);
      expect(find.text('Inputs'), findsOneWidget);
      expect(find.byTooltip('Back to calculators'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every registry id renders a real screen', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const CalculatorsScreen());

      for (final AppCalculatorMeta m in kAllCalculators) {
        await openToolsSidebar(tester);

        final Finder item = _navItem(m.name);
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();

        expect(find.text('Tool unavailable'), findsNothing, reason: m.id);
        expect(find.text('Inputs'), findsOneWidget, reason: m.id);
        expect(tester.takeException(), isNull, reason: m.id);
      }
    });

    testWidgets('renders completely black background on desktop screens', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const CalculatorsScreen());

      final Finder coloredBoxes = find.descendant(
        of: find.byType(CalculatorsScreen),
        matching: find.byType(ColoredBox),
      );
      expect(coloredBoxes, findsWidgets);
      final ColoredBox rootBox = tester.widget<ColoredBox>(coloredBoxes.first);
      expect(rootBox.color, Colors.black);
    });
  });

  group('the phone surface', () {
    testWidgets('is an index first, and a tool second', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const CalculatorsScreen(), size: _phoneSize);

      // No rail on a phone: the list is the screen, and no tool is open yet.
      expect(find.byType(AppCalculatorNavItem), findsWidgets);
      expect(find.byType(PositionSizeCalculatorScreen), findsNothing);
      expect(find.text('Tools'), findsOneWidget);

      await tester.tap(_navItem(_meta('position_size').name));
      await tester.pumpAndSettle();

      expect(find.byType(PositionSizeCalculatorScreen), findsOneWidget);
      expect(find.byType(AppCalculatorNavItem), findsNothing);
      expect(find.byTooltip('Back to calculators'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leads with the readout and files the rest under tabs', (
      WidgetTester tester,
    ) async {
      await openOnPhone(tester, 'position_size');

      // The answer is pinned above the tab bar — the reverse of the desktop
      // rail, where inputs sit beside the result.
      final double readoutY = tester
          .getTopLeft(find.text('QUANTITY TO TRADE'))
          .dy;
      final double tabsY = tester.getTopLeft(find.text('Inputs')).dy;
      expect(readoutY, lessThan(tabsY));

      expect(find.text('Output'), findsOneWidget);
      expect(find.text('Visuals'), findsOneWidget);
      expect(find.text('Method'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each pane carries its own kind of detail', (
      WidgetTester tester,
    ) async {
      await openOnPhone(tester, 'position_size');

      // Inputs first — the controls, and nothing else.
      expect(find.byType(TextField), findsWidgets);

      await tester.tap(find.text('Output'));
      await tester.pumpAndSettle();
      expect(find.byType(UiKeyValueTable), findsWidgets);

      await tester.tap(find.text('Visuals'));
      await tester.pumpAndSettle();
      expect(find.byType(AppCalcTrendChart), findsWidgets);

      await tester.tap(find.text('Method'));
      await tester.pumpAndSettle();
      expect(find.text('Formula'), findsOneWidget);
      expect(find.text('Notes & assumptions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays clear of the docked navigation bar', (
      WidgetTester tester,
    ) async {
      const double dockInset = 88;
      await pumpAt(
        tester,
        const MediaQuery(
          data: MediaQueryData(
            size: _phoneSize,
            padding: EdgeInsets.only(bottom: dockInset),
          ),
          child: CalculatorsScreen(),
        ),
        size: _phoneSize,
      );

      expect(find.byType(AppCalculatorNavItem), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(_navItem(_meta('position_size').name));
      await tester.pumpAndSettle();

      // The tab bar has to stay reachable above the dock.
      expect(
        tester.getBottomLeft(find.text('Inputs')).dy,
        lessThanOrEqualTo(_phoneSize.height - dockInset),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('notifies onSubpageChanged and omits duplicate subheader when embedded', (
      WidgetTester tester,
    ) async {
      String? reportedTitle;
      IconData? reportedIcon;
      VoidCallback? reportedBack;

      await pumpAt(
        tester,
        CalculatorsScreen(
          onSubpageChanged: (String? title, IconData? icon, VoidCallback? onBack) {
            reportedTitle = title;
            reportedIcon = icon;
            reportedBack = onBack;
          },
        ),
        size: _phoneSize,
      );

      // Initially on index — no subpage reported
      expect(reportedTitle, isNull);
      expect(reportedIcon, isNull);
      expect(reportedBack, isNull);

      // Tap on Position Size
      await tester.tap(_navItem(_meta('position_size').name));
      await tester.pumpAndSettle();

      // Tool opens, subpage reported to main header
      expect(reportedTitle, 'Position Size');
      expect(reportedIcon, isNotNull);
      expect(reportedBack, isNotNull);

      // Extra sub-header is omitted so only the main header displays title and back
      expect(find.byTooltip('Back to calculators'), findsNothing);
      expect(find.byType(PositionSizeCalculatorScreen), findsOneWidget);

      // Trigger back navigation from the main header's reported callback
      reportedBack!();
      await tester.pumpAndSettle();

      // Screen is back to the tools index, subpage state reset to null
      expect(reportedTitle, isNull);
      expect(reportedIcon, isNull);
      expect(reportedBack, isNull);
      expect(find.byType(AppCalculatorNavItem), findsWidgets);
      expect(find.byType(PositionSizeCalculatorScreen), findsNothing);
    });
  });

  group('a calculator screen', () {
    testWidgets('recomputes live as inputs change, with no Calculate button', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const PositionSizeCalculatorScreen());

      // ₹5,000 risk over a ₹25 stop distance.
      expect(find.text('200'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '1000000');
      await tester.pumpAndSettle();

      // Twice the capital, twice the size — without pressing anything.
      expect(find.text('400'), findsWidgets);
      expect(find.widgetWithText(UiButton, 'Calculate'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty numeric field reads as zero rather than crashing', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const PositionSizeCalculatorScreen());

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the formula and the assumptions sit in the method column', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const PositionSizeCalculatorScreen());

      expect(find.text('Formula'), findsOneWidget);
      expect(find.text('Notes & assumptions'), findsOneWidget);
      expect(
        find.textContaining('Quantity = ⌊Risk budget ÷'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('every panel kind is present on one screen', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const PositionSizeCalculatorScreen());

      // The brief: a table, a chart and a visualisation in every calculator.
      expect(find.byType(UiKeyValueTable), findsWidgets);
      expect(find.byType(AppCalcTrendChart), findsWidgets);
      expect(find.byType(UiRangeMeter), findsWidgets);
      expect(
        tester.widget<UiStatStrip>(find.byType(UiStatStrip)).stats.length,
        6,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
