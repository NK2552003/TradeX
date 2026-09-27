import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// Avatar with an optional presence dot painted over its lower-right corner.
///
/// A thin domain wrapper over [UiAvatar] so Messages, the AI assistant thread
/// rail and anywhere else that shows "who is online" all render presence the
/// same way. The dot colour is passed in rather than derived from a feature
/// enum, which keeps this a generic core primitive that no single feature owns.
///
/// Pass [presenceColor] `null` to hide the dot entirely (e.g. group threads or
/// records without a live person behind them).
class AppPresenceAvatar extends StatelessWidget {
  const AppPresenceAvatar({
    super.key,
    this.imageUrl,
    this.name = '',
    this.size = UiSize.md,
    this.presenceColor,
    this.presenceLabel,
    this.verified = false,
    this.gradient,
    this.badgeCount = 0,
    this.onTap,
  });

  final String? imageUrl;
  final String name;
  final UiSize size;

  /// Colour of the presence dot. `null` hides it.
  final Color? presenceColor;

  /// Optional tooltip on the presence dot ("Online", "Away"…).
  final String? presenceLabel;

  final bool verified;
  final Gradient? gradient;

  /// Small unread counter drawn as a pill on the top-right. `0` hides it.
  final int badgeCount;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double dim = size.avatar(context);
    // Dot scales with the avatar but is clamped so it never dwarfs an xs avatar
    // nor disappears on a large one.
    final double dot = (dim * 0.30).clamp(context.sz(8), context.sz(16));
    final double ring = (dot * 0.18).clamp(1.5, 3.0);

    Widget avatar = UiAvatar(
      imageUrl: imageUrl,
      name: name,
      size: size,
      verified: verified,
      gradient: gradient,
      onTap: onTap,
    );

    final List<Widget> layers = <Widget>[avatar];

    if (presenceColor != null) {
      Widget dotWidget = Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(
          color: presenceColor,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colors.surface, width: ring),
        ),
      );
      if (presenceLabel != null) {
        dotWidget = UiTooltip(message: presenceLabel!, child: dotWidget);
      }
      layers.add(Positioned(right: 0, bottom: 0, child: dotWidget));
    }

    if (badgeCount > 0) {
      layers.add(
        Positioned(
          right: -context.sz(4),
          top: -context.sz(4),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xxs),
              vertical: context.sz(1),
            ),
            constraints: BoxConstraints(minWidth: context.sz(16)),
            decoration: BoxDecoration(
              color: theme.colors.primary,
              borderRadius: BorderRadius.circular(context.sz(999)),
              border: Border.all(
                color: theme.colors.surface,
                width: context.sz(1.5),
              ),
            ),
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              textAlign: TextAlign.center,
              style: context.uiText.caption.copyWith(
                color: theme.colors.onPrimary,
                fontSize: context.fs(9),
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(clipBehavior: Clip.none, children: layers);
  }
}
