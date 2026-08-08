import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_common.dart';

/// Upload target for screenshots / chart images / avatars.
///
/// Presentation-only: the caller wires [onPick] to its own file picker and
/// passes back a preview URL through [previewUrls].
class UiDropzone extends StatelessWidget {
  const UiDropzone({
    super.key,
    this.onPick,
    this.previewUrls = const <String>[],
    this.onRemove,
    this.title = 'Upload a screenshot',
    this.message = 'PNG or JPG, up to 10 MB',
    this.icon = Icons.image_outlined,
    this.uploading = false,
    this.progress,
    this.error,
    this.height,
  });

  final VoidCallback? onPick;
  final List<String> previewUrls;
  final ValueChanged<String>? onRemove;
  final String title;
  final String message;
  final IconData icon;
  final bool uploading;
  final double? progress;
  final String? error;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color borderColor =
        error != null ? theme.colors.destructive : theme.colors.borderStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UiInteractive(
          onTap: uploading ? null : onPick,
          builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
            duration: theme.motion.fast,
            height: height ?? ctx.sz(150),
            decoration: BoxDecoration(
              color: s.hovered
                  ? theme.colors.surfaceHover
                  : theme.colors.surfaceMuted,
              borderRadius: ctx.radius(theme.radii.xl),
              border: Border.all(
                color: s.hovered ? theme.colors.primary : borderColor,
                width: theme.borders.thick,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    uploading ? Icons.cloud_upload_outlined : icon,
                    size: ctx.sz(theme.sizes.iconLg * 1.6),
                    color: theme.colors.foregroundMuted,
                  ),
                  SizedBox(height: ctx.sp(theme.spacing.sm)),
                  Text(
                    uploading ? 'Uploading…' : title,
                    style: ctx.uiText.bodyStrong,
                  ),
                  SizedBox(height: ctx.sp(theme.spacing.xxs)),
                  Text(
                    error ?? message,
                    style: ctx.uiText.caption.copyWith(
                      color: error != null
                          ? theme.colors.destructive
                          : theme.colors.foregroundMuted,
                    ),
                  ),
                  if (uploading) ...<Widget>[
                    SizedBox(height: ctx.sp(theme.spacing.sm)),
                    SizedBox(
                      width: ctx.sz(160),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: ctx.sz(4),
                        backgroundColor: theme.colors.surface,
                        color: theme.colors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (previewUrls.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.sm),
            children: <Widget>[
              for (final String url in previewUrls)
                Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: context.radius(theme.radii.lg),
                      child: Image.network(
                        url,
                        width: context.sz(88),
                        height: context.sz(64),
                        fit: BoxFit.cover,
                        errorBuilder: (BuildContext ctx, Object err, StackTrace? stack) => Container(
                          width: context.sz(88),
                          height: context.sz(64),
                          color: theme.colors.surfaceMuted,
                        ),
                      ),
                    ),
                    if (onRemove != null)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: UiInteractive(
                          onTap: () => onRemove!(url),
                          builder: (BuildContext ctx, UiInteractiveState _) =>
                              Container(
                            padding: EdgeInsets.all(ctx.sp(theme.spacing.xxs)),
                            decoration: BoxDecoration(
                              color: theme.colors.overlay,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: ctx.sz(theme.sizes.iconSm),
                              color: theme.colors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
        if (onPick != null && previewUrls.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiButton(
            label: 'Add another',
            variant: UiVariant.outline,
            leadingIcon: Icons.add_photo_alternate_outlined,
            expandOnMobile: false,
            onPressed: onPick,
          ),
        ],
      ],
    );
  }
}
