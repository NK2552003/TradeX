import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Shared network image alias so callers can use either [UiRemoteImage] or
/// [AppNetworkImage] interchangeably.
typedef AppNetworkImage = UiRemoteImage;

/// Network image with the states a network image actually has.
///
/// A bare [Image.network] renders a red error box the moment a URL 404s or the
/// device drops off the network, and shows nothing at all while the bytes are in
/// flight — so a feed of them flickers on scroll and breaks outright offline.
/// This keeps the frame occupied throughout: a muted panel while loading, a
/// muted panel with a broken-image glyph if it fails, and a short fade once the
/// first frame decodes.
///
/// Automatically caps decoded bitmap dimensions (`cacheWidth` at up to 2x DPR)
/// and appends host-verified resize parameters for CDNs that support them
/// (Cloudinary, imgix, Unsplash) to cut memory and network egress.
class UiRemoteImage extends StatelessWidget {
  const UiRemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.maxWidth,
    this.semanticLabel,
    this.errorIcon = Icons.broken_image_outlined,
    this.placeholder,
    this.fallback,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double? maxWidth;

  /// Describes the picture to a screen reader. Leave null for decoration.
  final String? semanticLabel;
  final IconData errorIcon;
  final Widget? placeholder;
  final Widget? fallback;

  /// Calculates target physical pixel width capped at 2x device pixel ratio.
  static int? resolveCacheWidth(BuildContext context, {double? logicalWidth}) {
    if (logicalWidth == null || !logicalWidth.isFinite || logicalWidth <= 0) {
      return null;
    }
    final double dpr = (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0)
        .clamp(1.0, 2.0);
    final int px = (logicalWidth * dpr).round();
    return px > 0 ? px : null;
  }

  /// Appends width/format parameters for image hosts known to support
  /// dynamic URL resizing (Cloudinary, imgix, Unsplash) and canonicalizes
  /// Supabase Storage public Smart CDN buckets (`avatars`,
  /// `community-attachments`) to `/storage/v1/object/public/...` so requests hit
  /// Cached Egress instead of uncached signed origin URLs.
  static String resizeImageUrl(String src, {int? targetWidthPx}) {
    final Uri? uri = Uri.tryParse(src);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return src;
    }

    // Upgrade legacy signed URLs for public Smart CDN buckets only.
    const Set<String> publicCdnBuckets = <String>{
      'avatars',
      'community-attachments',
    };
    final List<String> segs = uri.pathSegments;
    final int objIdx = segs.indexOf('object');
    if (objIdx != -1 &&
        segs.contains('storage') &&
        objIdx + 2 < segs.length &&
        (segs[objIdx + 1] == 'sign' || segs[objIdx + 1] == 'authenticated') &&
        publicCdnBuckets.contains(segs[objIdx + 2])) {
      final List<String> publicSegs = List<String>.from(segs);
      publicSegs[objIdx + 1] = 'public';
      return Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        pathSegments: publicSegs,
      ).toString();
    }

    if (targetWidthPx == null || targetWidthPx <= 0) return src;
    final int bucketWidth = (((targetWidthPx + 79) ~/ 80) * 80).clamp(80, 1600);
    final String host = uri.host.toLowerCase();

    if (host.contains('res.cloudinary.com') &&
        uri.path.contains('/image/upload/')) {
      const String marker = '/image/upload/';
      final int idx = uri.path.indexOf(marker);
      final String suffix = uri.path.substring(idx + marker.length);
      final String firstSeg = suffix.split('/').first;
      if (!firstSeg.contains('w_') && !firstSeg.contains('c_')) {
        final String newPath =
            '${uri.path.substring(0, idx + marker.length)}w_$bucketWidth,c_limit,q_auto,f_auto/$suffix';
        return uri.replace(path: newPath).toString();
      }
      return src;
    }

    if (host.endsWith('.imgix.net') || host == 'images.unsplash.com') {
      final Map<String, String> qp = Map<String, String>.from(
        uri.queryParameters,
      );
      qp.putIfAbsent('w', () => '$bucketWidth');
      qp.putIfAbsent('auto', () => 'format');
      qp.putIfAbsent('q', () => '80');
      return uri.replace(queryParameters: qp).toString();
    }

    return src;
  }

  @override
  Widget build(BuildContext context) {
    final String? src = url?.trim();
    final Widget resolvedFallback = fallback ?? _Panel(icon: errorIcon);
    if (src == null || src.isEmpty) {
      return fallback ?? const _Panel(icon: Icons.image_not_supported_outlined);
    }
    if (src.startsWith('data:image/')) {
      try {
        return Image.memory(
          Uri.parse(src).data!.contentAsBytes(),
          width: width,
          height: height,
          fit: fit,
          cacheWidth: resolveCacheWidth(
            context,
            logicalWidth: width ?? maxWidth,
          ),
          semanticLabel: semanticLabel,
          errorBuilder: (_, _, _) => resolvedFallback,
        );
      } on FormatException {
        return resolvedFallback;
      }
    }
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        double? boundedW = width;
        if (boundedW == null &&
            constraints.hasBoundedWidth &&
            constraints.maxWidth > 0) {
          boundedW = maxWidth != null
              ? math.min(constraints.maxWidth, maxWidth!)
              : constraints.maxWidth;
        } else {
          boundedW ??= maxWidth;
        }
        final int? cacheW = resolveCacheWidth(ctx, logicalWidth: boundedW);
        final String resolvedSrc = resizeImageUrl(src, targetWidthPx: cacheW);
        return Image.network(
          resolvedSrc,
          // Publishers often allow browser <img> embedding but not canvas CORS.
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          width: width,
          height: height,
          cacheWidth: cacheW,
          fit: fit,
          semanticLabel: semanticLabel,
          // Fade only when the frame arrived asynchronously. A cached image is
          // already decoded, so fading it in would flash a panel that never had to
          // be there — the usual cause of a "blinking" feed on scroll.
          frameBuilder:
              (
                BuildContext fCtx,
                Widget child,
                int? frame,
                bool wasSynchronouslyLoaded,
              ) {
                if (wasSynchronouslyLoaded) return child;
                return _ImageFade(
                  shown: frame != null,
                  placeholder: placeholder,
                  child: child,
                );
              },
          loadingBuilder:
              (BuildContext lCtx, Widget child, ImageChunkEvent? progress) =>
                  progress == null ? child : (placeholder ?? const _Panel()),
          errorBuilder: (BuildContext eCtx, Object _, StackTrace? _) =>
              resolvedFallback,
        );
      },
    );
  }
}

/// Cross-fades the decoded picture over the loading panel.
class _ImageFade extends StatelessWidget {
  const _ImageFade({
    required this.shown,
    required this.child,
    this.placeholder,
  });

  final bool shown;
  final Widget child;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (!shown && placeholder != null) return placeholder!;
    return AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: context.ui.motion.fast,
      curve: Curves.easeOut,
      child: shown ? child : const _Panel(),
    );
  }
}

/// The neutral stand-in shown while loading and when loading fails.
class _Panel extends StatelessWidget {
  const _Panel({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return ColoredBox(
      color: theme.colors.surfaceMuted,
      child: icon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(
                icon,
                size: context.sz(theme.sizes.iconLg),
                color: theme.colors.foregroundSubtle,
              ),
            ),
    );
  }
}
