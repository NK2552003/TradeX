import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_common.dart';
import 'ui_remote_image.dart';

/// Upload target for screenshots / chart images / avatars.
///
/// Presentation-only: the caller wires [onPick] to its own file picker and
/// passes back a preview URL through [previewUrls].
class UiDropzone extends StatelessWidget {
  UiDropzone({
    super.key,
    VoidCallback? onPick,
    this.onFilesDropped,
    this.previewUrls = const <String>[],
    this.onRemove,
    this.title = 'Upload a screenshot',
    this.message = 'PNG or JPG, up to 10 MB',
    this.icon = Icons.image_outlined,
    this.uploading = false,
    this.progress,
    this.error,
    this.height,
  }) : onPick = onPick ?? (onFilesDropped != null ? () => onFilesDropped(const <String>[]) : null);

  final VoidCallback? onPick;
  final ValueChanged<List<String>>? onFilesDropped;
  final List<String> previewUrls;
  final ValueChanged<String>? onRemove;
  final String title;
  final String message;
  final IconData icon;
  final bool uploading;
  final double? progress;
  final String? error;

  /// Minimum height of the drop target in logical points (scaled internally).
  /// The zone grows past this if the copy needs more room.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color borderColor = error != null
        ? theme.colors.destructive
        : theme.colors.borderStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UiInteractive(
          onTap: uploading ? null : onPick,
          builder: (BuildContext ctx, UiInteractiveState s) =>
              AnimatedContainer(
                duration: theme.motion.fast,
                // A floor rather than a fixed height, and scaled here so the
                // caller can pass a plain logical number: at a large text scale
                // the icon and two lines of copy grow past 150pt, and a hard
                // height clipped the hint line right when it mattered most.
                constraints: BoxConstraints(
                  minHeight: ctx.sz(height ?? 150),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: ctx.sp(theme.spacing.md),
                  vertical: ctx.sp(theme.spacing.md),
                ),
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
                      // Both lines are caller-supplied, and the second doubles as
                      // the error slot ("File is larger than the 10 MB limit"),
                      // so they wrap and then truncate instead of overrunning.
                      Text(
                        uploading ? 'Uploading…' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: ctx.uiText.bodyStrong,
                      ),
                      SizedBox(height: ctx.sp(theme.spacing.xxs)),
                      Text(
                        error ?? message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
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
                      child: SizedBox(
                        width: context.sz(88),
                        height: context.sz(64),
                        child: UiRemoteImage(
                          url: url,
                          semanticLabel: 'Selected upload preview',
                        ),
                      ),
                    ),
                    if (onRemove != null)
                      Positioned(
                        top: context.sz(2),
                        right: context.sz(2),
                        child: UiInteractive(
                          onTap: () => onRemove!(url),
                          builder: (BuildContext ctx, UiInteractiveState _) =>
                              Container(
                                padding: EdgeInsets.all(
                                  ctx.sp(theme.spacing.xxs),
                                ),
                                // Sized against the thumbnail, not the 44pt tap
                                // guideline: the preview is only 64pt tall, so a
                                // full-size target would cover the image it is
                                // meant to let you inspect before removing.
                                constraints: ctx.uiRes.isMobile
                                    ? BoxConstraints(
                                        minWidth: ctx.sz(32),
                                        minHeight: ctx.sz(32),
                                      )
                                    : const BoxConstraints(),
                                alignment: Alignment.center,
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
