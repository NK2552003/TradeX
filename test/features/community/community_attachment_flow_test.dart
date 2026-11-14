import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';

class _Picker extends ImagePickerPlatform {
  _Picker(this.files);
  final List<XFile> files;
  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => files;
}

class _Repository extends CommunityRepository {
  final uploads = <String>[];
  final discarded = <List<String>>[];
  List<String>? saved;
  var failSecond = true;
  var failCreatePostOnce = false;

  @override
  Future<void> discardUnusedAttachments(Iterable<String> urls) async {
    discarded.add(urls.toList());
  }

  @override
  Future<String> uploadAttachment({
    required String postId,
    File? file,
    Uint8List? bytes,
    String? filename,
  }) async {
    expect(img.decodeWebP(bytes!), isNotNull);
    expect(bytes.length, lessThanOrEqualTo(100 * 1024));
    uploads.add(filename!);
    if (uploads.length == 2 && failSecond) {
      failSecond = false;
      throw StateError('Temporary upload failure');
    }
    return 'https://example.com/$postId/$filename';
  }

  @override
  Future<void> createPost({
    required String body,
    List<String> tickers = const [],
    List<String> tags = const [],
    CommunityTradeSetup? tradeSetup,
    String? imageUrl,
    List<String> imageUrls = const [],
    AppWritingPostAttachment? attachment,
    CommunityPoll? poll,
    CommunityPost? quoted,
    CommunitySentiment? sentiment,
    CommunityReplyAudience replyAudience = CommunityReplyAudience.everyone,
    bool isDeskAlert = false,
    DateTime? scheduledFor,
    required CommunityAuthor author,
  }) async {
    if (failCreatePostOnce) {
      failCreatePostOnce = false;
      throw StateError('Post persistence failed');
    }
    saved = imageUrls;
  }
}

void main() {
  for (final clearAfterFailure in [false, true]) {
    testWidgets(
      clearAfterFailure
          ? 'clearing a failed draft requests cleanup of its staged uploads'
          : 'multiple selections stay local, deduplicate, and retry failed uploads',
      (tester) async {
        final originalPicker = ImagePickerPlatform.instance;
        addTearDown(() => ImagePickerPlatform.instance = originalPicker);
        final red = img.Image(width: 20, height: 20);
        final blue = img.Image(width: 20, height: 20);
        img.fill(red, color: img.ColorRgb8(255, 0, 0));
        img.fill(blue, color: img.ColorRgb8(0, 0, 255));
        final first = XFile.fromData(
          img.encodePng(red),
          name: 'red.png',
          mimeType: 'image/png',
        );
        ImagePickerPlatform.instance = _Picker([
          first,
          first,
          XFile.fromData(
            img.encodePng(blue),
            name: 'blue.png',
            mimeType: 'image/png',
          ),
        ]);
        final repo = _Repository();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunityComposerCard(
                  author: repo.currentAuthor,
                  repository: repo,
                  initialMode: ComposerMode.chart,
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.byType(UiDropzone));
        await tester.runAsync(() async {
          await tester.tap(find.byType(UiDropzone));
          for (var i = 0; i < 500; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (!tester.widget<UiDropzone>(find.byType(UiDropzone)).uploading) {
              break;
            }
          }
        });
        await tester.pumpAndSettle();
        expect(find.text('Attached Images (2):'), findsOneWidget);
        expect(repo.uploads, isEmpty);
        final submit = find.widgetWithText(UiButton, 'Post Thesis');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(repo.saved, isNull);
        expect(find.text('Attached Images (2):'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        if (clearAfterFailure) {
          await tester.tap(find.byTooltip('Clear Draft'));
          await tester.pumpAndSettle();
          expect(repo.discarded.single, hasLength(1));
          expect(find.text('Attached Images (2):'), findsNothing);
          expect(repo.saved, isNull);
          return;
        }
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(repo.saved, hasLength(2));
        expect(repo.uploads, hasLength(3));
        expect(repo.uploads[1], repo.uploads[2]);
        expect(repo.saved!.every((url) => url.startsWith('https://')), isTrue);
        expect(find.text('Attached Images (2):'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'all attached photos are visible and open at the selected index',
    (tester) async {
      final repo = _Repository();
      addTearDown(repo.dispose);
      final post = CommunityPost(
        id: 'gallery',
        author: repo.currentAuthor,
        body: 'Two charts',
        createdAt: DateTime(2026),
        imageUrls: const [
          'https://example.com/a.png',
          'https://example.com/b.png',
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CommunityPostCard(post: post)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final images = find.byType(UiRemoteImage);
      expect(images, findsNWidgets(2));
      await tester.ensureVisible(images.last);
      await tester.tap(images.last);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop composer side sheet scrolls without detached scrollbar errors',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _Repository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => UiButton(
                label: 'Open composer',
                onPressed: () {
                  showSettingsSideSheet<void>(
                    context,
                    title: 'Post',
                    scrollable: true,
                    child: CommunityComposerCard(
                      author: repo.currentAuthor,
                      repository: repo,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open composer'));
      await tester.pumpAndSettle();
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(1200, 600),
          scrollDelta: Offset(0, 250),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test('removing all images from a legacy post clears the original image', () {
    final repo = _Repository();
    addTearDown(repo.dispose);
    final post = CommunityPost(
      id: 'legacy',
      author: repo.currentAuthor,
      body: 'Chart',
      createdAt: DateTime(2026),
      imageUrl: 'https://example.com/old.png',
    );
    expect(post.copyWith(imageUrls: []).effectiveImageUrls, isEmpty);
  });

  testWidgets(
    'failed createPost immediately rolls back uploaded attachments and retry re-uploads from memory',
    (tester) async {
      final originalPicker = ImagePickerPlatform.instance;
      addTearDown(() => ImagePickerPlatform.instance = originalPicker);
      final green = img.Image(width: 20, height: 20);
      img.fill(green, color: img.ColorRgb8(0, 255, 0));
      ImagePickerPlatform.instance = _Picker([
        XFile.fromData(
          img.encodePng(green),
          name: 'green.png',
          mimeType: 'image/png',
        ),
      ]);
      final repo = _Repository()
        ..failSecond = false
        ..failCreatePostOnce = true;
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityComposerCard(
                author: repo.currentAuthor,
                repository: repo,
                initialMode: ComposerMode.chart,
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byType(UiDropzone));
      await tester.runAsync(() async {
        await tester.tap(find.byType(UiDropzone));
        for (var i = 0; i < 500; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          if (!tester.widget<UiDropzone>(find.byType(UiDropzone)).uploading) {
            break;
          }
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Attached Images (1):'), findsOneWidget);

      final submit = find.widgetWithText(UiButton, 'Post Thesis');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      // Post save failed: uploaded attachment was immediately scheduled for discard
      expect(repo.saved, isNull);
      expect(repo.uploads, hasLength(1));
      expect(repo.discarded, hasLength(1));
      expect(repo.discarded.first, hasLength(1));

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Retry succeeds by re-uploading from in-memory _preparedImages
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repo.saved, hasLength(1));
      expect(repo.uploads, hasLength(2));
    },
  );
}
