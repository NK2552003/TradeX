import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Network image with the states a network image actually has.
///
/// A bare [Image.network] renders a red error box the moment a URL 404s or the
/// device drops off the network, and shows nothing at all while the bytes are in
/// flight — so a feed of them flickers on scroll and breaks outright offline.
/// This keeps the frame occupied throughout: a muted panel while loading, a
/// muted panel with a broken-image glyph if it fails, and a short fade once the
/// first frame decodes.
///
/// Size comes from the parent (an [AspectRatio], [SizedBox] or grid cell), and
/// rounding from a [ClipRRect] around it, so this widget only owns the states.
class UiRemoteImage extends StatelessWidget {
  const UiRemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.errorIcon = Icons.broken_image_outlined,
  });

  final String? url;
  final BoxFit fit;

  /// Describes the picture to a screen reader. Leave null for decoration.
  final String? semanticLabel;
  final IconData errorIcon;

  @override
  Widget build(BuildContext context) {
    final String? src = url?.trim();
    if (src == null || src.isEmpty) {
      return _Panel(icon: Icons.image_not_supported_outlined);
    }
    return Image.network(
      src,
      // Publishers often allow browser <img> embedding but not canvas CORS.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      fit: fit,
      semanticLabel: semanticLabel,
      // Fade only when the frame arrived asynchronously. A cached image is
      // already decoded, so fading it in would flash a panel that never had to
      // be there — the usual cause of a "blinking" feed on scroll.
      frameBuilder:
          (
            BuildContext ctx,
            Widget child,
            int? frame,
            bool wasSynchronouslyLoaded,
          ) {
            if (wasSynchronouslyLoaded) return child;
            return _ImageFade(shown: frame != null, child: child);
          },
      loadingBuilder:
          (BuildContext ctx, Widget child, ImageChunkEvent? progress) =>
              progress == null ? child : const _Panel(),
      errorBuilder: (BuildContext ctx, Object _, StackTrace? _) =>
          _Panel(icon: errorIcon),
    );
  }
}

/// Cross-fades the decoded picture over the loading panel.
class _ImageFade extends StatelessWidget {
  const _ImageFade({required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: shown ? 1 : 0,
    duration: context.ui.motion.fast,
    curve: Curves.easeOut,
    child: shown ? child : const _Panel(),
  );
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
