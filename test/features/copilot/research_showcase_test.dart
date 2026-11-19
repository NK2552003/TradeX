import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/copilot/presentation/research_welcome.dart';

const showcase = '''
## The opportunity, and what could change it
A strong business can still be a demanding investment. Start with cash generation, check what the valuation assumes, and keep the downside case visible.

```company
{"name":"Atlas Computing","ticker":"ATLS","exchange":"Illustrative company","sector":"Enterprise infrastructure","price":"128.40","currency":"USD","asOf":"Illustrative snapshot • not live data","changePercent":2.4,"marketCap":"42.8B","pe":"28.4×","revenue":"8.2B","margin":"24.1%","summary":"Recurring enterprise demand supports the thesis. The key question is whether reinvestment can sustain growth without eroding cash conversion.","highlights":["Recurring revenue creates visibility","Cash generation supports reinvestment"],"risks":["Valuation assumes durable growth","Customer concentration needs monitoring"]}
```

```compare
{"title":"A balanced view","mode":"bull_bear","leftTitle":"The opportunity","leftItems":["Durable customer relationships","Improving operating leverage"],"rightTitle":"The challenge","rightItems":["Higher expectations leave less room for error","Execution risk in new markets"]}
```

```earnings
{"company":"Atlas Computing","ticker":"ATLS","quarter":"Illustrative quarter","epsActual":"1.42","epsEstimate":"1.36","epsSurprise":"+4.4%","revenueActual":"2.1B","revenueEstimate":"2.0B","revenueSurprise":"+5.0%","summary":"This is a UI example using fictional data, not a market recommendation."}
```
''';

void main() {
  setUpAll(() async {
    final regular = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final mono = FontLoader('NotoSansMono')
      ..addFont(rootBundle.load('assets/fonts/NotoSansMono-Regular.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([regular.load(), mono.load(), icons.load()]);
  });
  for (final width in [390.0, 1100.0]) {
    for (final welcome in [true, false]) {
      testWidgets('research showcase ${welcome ? 'welcome' : 'answer'} $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, welcome ? 1000 : 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final theme = UiTheme.dark();
        await tester.pumpWidget(
          UiThemeScope(
            theme: theme,
            child: MaterialApp(
              theme: theme.toThemeData(),
              home: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: theme.colors.background,
                    child: SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: 840,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: welcome
                                ? ResearchWelcome(
                                    onPrompt: (_) {},
                                    onFormats: () {},
                                    onSkills: () {},
                                  )
                                : AppAiMessageBubble(
                                    message: const AppAiMessage(
                                      id: 'showcase',
                                      role: AppAiRole.assistant,
                                      body: showcase,
                                      mode: 'research',
                                    ),
                                    minimal: true,
                                    onFollowUpTap: (_) {},
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('COPILOT_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final capture = await boundary.toImage();
            final bytes = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('artifacts/copilot-research');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/${welcome ? 'welcome' : 'answer'}-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            capture.dispose();
          });
        }
      });
    }
  }
}
