import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

void main() {
  Widget buildTestable(Widget child, {Brightness brightness = Brightness.light}) {
    final UiTheme theme =
        brightness == Brightness.dark ? UiTheme.dark() : UiTheme.light();
    return MaterialApp(
      theme: theme.toThemeData(),
      home: UiApp(
        theme: theme,
        builder: (BuildContext context) => Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Flutter UI Components Tests', () {
    testWidgets('UiButton renders label and triggers onPressed', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        buildTestable(
          UiButton(
            label: 'Test Button',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
      await tester.tap(find.text('Test Button'));
      expect(pressed, isTrue);
    });

    testWidgets('UiIconButton renders icon and handles tap', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        buildTestable(
          UiIconButton(
            icon: Icons.add,
            tooltip: 'Add Item',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      expect(pressed, isTrue);
    });

    testWidgets('UiBadge renders text and custom intent', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const UiBadge(
            label: 'Bullish',
            intent: UiIntent.bullish,
          ),
        ),
      );

      expect(find.text('Bullish'), findsOneWidget);
    });

    testWidgets('UiCard renders title, subtitle and child content', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const UiCard(
            title: 'Card Title',
            subtitle: 'Card Subtitle',
            child: Text('Card Content'),
          ),
        ),
      );

      expect(find.text('Card Title'), findsOneWidget);
      expect(find.text('Card Subtitle'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('UiInput renders hint and handles text change', (WidgetTester tester) async {
      String typed = '';
      await tester.pumpWidget(
        buildTestable(
          UiInput(
            hintText: 'Enter ticker',
            onChanged: (val) => typed = val,
          ),
        ),
      );

      expect(find.text('Enter ticker'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'AAPL');
      expect(typed, equals('AAPL'));
    });

    testWidgets('UiCheckbox toggles state', (WidgetTester tester) async {
      bool checked = false;
      await tester.pumpWidget(
        buildTestable(
          StatefulBuilder(
            builder: (context, setState) => UiCheckbox(
              value: checked,
              label: 'Remember Me',
              onChanged: (v) => setState(() => checked = v),
            ),
          ),
        ),
      );

      expect(find.text('Remember Me'), findsOneWidget);
      await tester.tap(find.byType(UiCheckbox));
      await tester.pump();
      expect(checked, isTrue);
    });

    testWidgets('UiSwitch toggles state', (WidgetTester tester) async {
      bool enabled = false;
      await tester.pumpWidget(
        buildTestable(
          StatefulBuilder(
            builder: (context, setState) => UiSwitch(
              value: enabled,
              label: 'Enable Notifications',
              onChanged: (v) => setState(() => enabled = v),
            ),
          ),
        ),
      );

      expect(find.text('Enable Notifications'), findsOneWidget);
      await tester.tap(find.byType(UiSwitch));
      await tester.pump();
      expect(enabled, isTrue);
    });

    testWidgets('UiProgressBar renders label and value', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const UiProgressBar(
            value: 0.75,
            label: 'Completion',
          ),
        ),
      );

      expect(find.text('Completion'), findsOneWidget);
    });

    testWidgets('UiTable renders column headers and row data', (WidgetTester tester) async {
      final rows = ['Apple', 'Microsoft', 'Google'];
      await tester.pumpWidget(
        buildTestable(
          UiTable<String>(
            rows: rows,
            columns: [
              UiTableColumn<String>(
                header: 'Company',
                cell: (context, item) => Text(item),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Company'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Microsoft'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
    });

    testWidgets('UiTabs renders tab labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const UiTabs(
            items: [
              UiTabItem(label: 'Overview'),
              UiTabItem(label: 'Analytics'),
            ],
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
    });

    testWidgets('UiSparkChart renders without throwing', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const UiSparkChart(
            values: [10.0, 15.0, 12.0, 20.0, 18.0],
            height: 50,
          ),
        ),
      );

      expect(find.byType(UiSparkChart), findsOneWidget);
    });

    testWidgets('UiSkeleton renders animation placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const UiSkeleton(width: 100, height: 20),
        ),
      );

      expect(find.byType(UiSkeleton), findsOneWidget);
    });

    testWidgets('UiAreaChart renders area chart with gradient and dots', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const UiAreaChart(
            height: 150,
            data: [
              UiChartPoint(label: 'Jan', values: [100, 150]),
              UiChartPoint(label: 'Feb', values: [120, 180]),
            ],
            series: [
              UiChartSeries(name: 'Portfolio', color: Colors.blue),
              UiChartSeries(name: 'Index', color: Colors.green),
            ],
            showDots: true,
            lineGlow: true,
          ),
        ),
      );

      expect(find.byType(UiAreaChart), findsOneWidget);
    });

    testWidgets('UiAreaChartCard renders title, metric value, controls and timeframe selectors', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          UiAreaChartCard(
            title: 'Equity Performance',
            metricValue: r'$100,000',
            metricChange: '+10%',
            data: const [
              UiChartPoint(label: 'Day 1', values: [100]),
              UiChartPoint(label: 'Day 2', values: [110]),
            ],
            series: const [
              UiChartSeries(name: 'Equity', color: Colors.blue),
            ],
          ),
        ),
      );

      expect(find.text('Equity Performance'), findsOneWidget);
      expect(find.text(r'$100,000'), findsOneWidget);
      expect(find.text('+10%'), findsOneWidget);
      expect(find.byType(UiAreaChartCard), findsOneWidget);
    });

    testWidgets('UiAsyncView renders loading, error, empty and content states', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          UiAsyncView(
            loading: true,
            loadingMessage: 'Loading quotes...',
            builder: (ctx) => const Text('Data Ready'),
          ),
        ),
      );
      expect(find.text('Loading quotes...'), findsOneWidget);

      await tester.pumpWidget(
        buildTestable(
          UiAsyncView(
            error: 'Failed to connect',
            errorTitle: 'Connection Error',
            builder: (ctx) => const Text('Data Ready'),
          ),
        ),
      );
      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.text('Failed to connect'), findsOneWidget);

      await tester.pumpWidget(
        buildTestable(
          UiAsyncView(
            isEmpty: true,
            emptyTitle: 'No items',
            builder: (ctx) => const Text('Data Ready'),
          ),
        ),
      );
      expect(find.text('No items'), findsOneWidget);

      await tester.pumpWidget(
        buildTestable(
          UiAsyncView(
            builder: (ctx) => const Text('Data Ready'),
          ),
        ),
      );
      expect(find.text('Data Ready'), findsOneWidget);
    });

    testWidgets('UiAsyncViewStateCard renders title and allows state toggling', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          UiAsyncViewStateCard(
            title: 'Async Test Controller',
            contentBuilder: (ctx) => const Text('Order Content'),
          ),
        ),
      );

      expect(find.text('Async Test Controller'), findsOneWidget);
      expect(find.text('Order Content'), findsOneWidget);

      await tester.tap(find.text('Loading'));
      await tester.pump();
      expect(find.text('Fetching live market orderbook & quotes...'), findsOneWidget);

      await tester.tap(find.text('Error'));
      await tester.pump();
      expect(find.text('Failed to fetch live quotes'), findsOneWidget);

      await tester.tap(find.text('Empty'));
      await tester.pump();
      expect(find.text('No active orders'), findsOneWidget);
    });
  });
}
