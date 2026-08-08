import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_icon_button.dart';

/// Full-screen image viewer: pinch/scroll zoom, swipe between images,
/// swipe-down to dismiss, optional download/share action.
class UiLightbox extends StatefulWidget {
  const UiLightbox({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.caption,
    this.onDownload,
    this.onShare,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? caption;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  @override
  State<UiLightbox> createState() => _UiLightboxState();
}

class _UiLightboxState extends State<UiLightbox> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Material(
      color: theme.colors.overlay,
      child: Stack(
        children: <Widget>[
          GestureDetector(
            onVerticalDragEnd: (DragEndDetails d) {
              if ((d.primaryVelocity ?? 0).abs() > 300) {
                Navigator.of(context).maybePop();
              }
            },
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.imageUrls.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext ctx, int i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.imageUrls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      size: ctx.sz(theme.sizes.iconLg * 2),
                      color: theme.colors.foregroundSubtle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + context.sp(theme.spacing.sm),
            left: context.sp(theme.spacing.md),
            right: context.sp(theme.spacing.md),
            child: Row(
              children: <Widget>[
                UiIconButton(
                  icon: Icons.close_rounded,
                  variant: UiVariant.ghost,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (widget.onShare != null)
                  UiIconButton(
                    icon: Icons.ios_share,
                    variant: UiVariant.ghost,
                    tooltip: 'Share',
                    onPressed: widget.onShare,
                  ),
                if (widget.onDownload != null)
                  UiIconButton(
                    icon: Icons.download_outlined,
                    variant: UiVariant.ghost,
                    tooltip: 'Download',
                    onPressed: widget.onDownload,
                  ),
              ],
            ),
          ),
          if (widget.caption != null || widget.imageUrls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom +
                  context.sp(theme.spacing.lg),
              child: Column(
                children: <Widget>[
                  if (widget.caption != null)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.xl),
                      ),
                      child: Text(
                        widget.caption!,
                        textAlign: TextAlign.center,
                        style: context.uiText.caption
                            .copyWith(color: theme.colors.onPrimary),
                      ),
                    ),
                  if (widget.imageUrls.length > 1) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (int i = 0; i < widget.imageUrls.length; i++)
                          Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: context.sp(theme.spacing.xxs),
                            ),
                            width: context.sz(6),
                            height: context.sz(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _index
                                  ? theme.colors.onPrimary
                                  : theme.colors.onPrimary
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens [UiLightbox] as a dismissible full-screen route.
Future<void> showUiLightbox(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? caption,
  VoidCallback? onDownload,
  VoidCallback? onShare,
}) =>
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, _, _) => UiLightbox(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          caption: caption,
          onDownload: onDownload,
          onShare: onShare,
        ),
        transitionsBuilder: (_, Animation<double> a, _, Widget child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
