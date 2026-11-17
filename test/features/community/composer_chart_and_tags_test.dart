import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';
import 'package:tradex/features/community/data/community_chart_detector.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_highlighted_text.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_tile.dart';

class _Picker extends ImagePickerPlatform {
  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => [
    XFile.fromData(
      Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 20))),
      name: 'chart.png',
      mimeType: 'image/png',
    ),
  ];
}

class _Detector extends CommunityChartDetector {
  int calls = 0;
  @override
  Future<CommunityChartDetection> detect(String imageDataUrl) async {
    calls++;
    return CommunityChartDetection(
      isChart: true,
      setup: const {
        'ticker': 'XAUUSD',
        'side': 'SHORT',
        'entry': '3900',
        'stopLoss': '3920',
        'target': '3850',
      },
      candles: [
        UiCandle(
          time: DateTime.utc(2026, 11, 17),
          open: 3900,
          high: 3910,
          low: 3880,
          close: 3890,
          volume: 0,
        ),
      ],
    );
  }
}

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('tags leave prose unchanged and markdown previews at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = CommunityRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityComposerCard(
                author: repo.currentAuthor,
                repository: repo,
              ),
            ),
          ),
        ),
      );
      final editor = find.descendant(
        of: find.byType(UiTextarea).first,
        matching: find.byType(EditableText),
      );
      await tester.enterText(editor, '**My thesis**');
      await tester.tap(find.text('Writing tools & tags'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('+\$NIFTY'));
      await tester.tap(find.text('+\$NIFTY'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(editor).controller.text,
        '**My thesis**',
      );
      expect(find.widgetWithText(UiBadge, '\$NIFTY'), findsOneWidget);
      await tester.ensureVisible(find.text('Preview'));
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(RichMarkdownPreview), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      'chart upload detects then fills setup with reviewed candles at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final oldPicker = ImagePickerPlatform.instance;
        ImagePickerPlatform.instance = _Picker();
        addTearDown(() => ImagePickerPlatform.instance = oldPicker);
        final repo = CommunityRepository();
        addTearDown(repo.dispose);
        final detector = _Detector();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunityComposerCard(
                  author: repo.currentAuthor,
                  repository: repo,
                  initialMode: ComposerMode.chart,
                  chartDetector: detector,
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.byType(UiDropzone));
        await tester.runAsync(() async {
          await tester.tap(find.byType(UiDropzone));
          for (var i = 0; i < 200; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (!tester.widget<UiDropzone>(find.byType(UiDropzone)).uploading) {
              break;
            }
          }
        });
        await tester.pumpAndSettle();
        expect(detector.calls, 1);
        expect(find.text('Chart detected'), findsOneWidget);
        await tester.ensureVisible(find.text('Use detected setup'));
        await tester.tap(find.text('Use detected setup'));
        await tester.pumpAndSettle();
        final fields = tester.widgetList<UiInput>(find.byType(UiInput));
        expect(fields.any((f) => f.controller?.text == '3900'), isTrue);
        expect(fields.any((f) => f.controller?.text == 'XAUUSD'), isTrue);
        final candleField = tester.widget<UiTextarea>(
          find.byKey(const ValueKey('setup-candles-input')),
        );
        expect(candleField.controller!.text, contains('2026-11-17'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('attachment title and long tags fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityAttachmentTile(
              attachment: AppWritingPostAttachment.note(
                AppNote(
                  id: 'note',
                  title: 'A detailed trading thesis with a long title',
                  content: 'An explanation of the setup.',
                  isPublic: true,
                  tags: ['price_action', 'multi_timeframe_analysis'],
                  linkedTickers: ['XAUUSD'],
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('plain tags retain interactive text rendering', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityHighlightedText(text: 'Watch \$GOLD #breakout'),
        ),
      ),
    );
    expect(find.byType(RichMarkdownPreview), findsNothing);
    expect(find.textContaining('#breakout'), findsOneWidget);
  });
}
