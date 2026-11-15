import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

void main() {
  group('UiRemoteImage / AppNetworkImage optimization', () {
    test('AppNetworkImage typedef aliases UiRemoteImage', () {
      expect(AppNetworkImage, equals(UiRemoteImage));
    });

    test('resizeImageUrl injects transforms for Cloudinary URLs', () {
      const src =
          'https://res.cloudinary.com/demo/image/upload/v1234/sample.jpg';
      final resized = UiRemoteImage.resizeImageUrl(src, targetWidthPx: 300);
      expect(
        resized,
        'https://res.cloudinary.com/demo/image/upload/w_320,c_limit,q_auto,f_auto/v1234/sample.jpg',
      );
    });

    test('resizeImageUrl appends w/auto/q for imgix and Unsplash', () {
      const imgixSrc = 'https://cdn.imgix.net/charts/setup.png?fit=crop';
      final imgixResized = Uri.parse(
        UiRemoteImage.resizeImageUrl(imgixSrc, targetWidthPx: 410),
      );
      expect(imgixResized.queryParameters['fit'], 'crop');
      expect(imgixResized.queryParameters['w'], '480');
      expect(imgixResized.queryParameters['auto'], 'format');
      expect(imgixResized.queryParameters['q'], '80');

      const unsplashSrc = 'https://images.unsplash.com/photo-123';
      final unsplashResized = Uri.parse(
        UiRemoteImage.resizeImageUrl(unsplashSrc, targetWidthPx: 200),
      );
      expect(unsplashResized.queryParameters['w'], '240');
    });

    test('resizeImageUrl leaves Supabase Storage and arbitrary hosts untouched', () {
      const supaSrc =
          'https://xyz.supabase.co/storage/v1/object/public/avatars/a.png';
      expect(
        UiRemoteImage.resizeImageUrl(supaSrc, targetWidthPx: 160),
        supaSrc,
      );

      const thirdPartySrc = 'https://example.com/chart.png?token=abc';
      expect(
        UiRemoteImage.resizeImageUrl(thirdPartySrc, targetWidthPx: 160),
        thirdPartySrc,
      );
    });

    testWidgets('resolveCacheWidth caps devicePixelRatio at 2x', (tester) async {
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.resetDevicePixelRatio);

      int? resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = UiRemoteImage.resolveCacheWidth(
                context,
                logicalWidth: 100,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, 200);
    });
  });
}
