import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

// ===========================================================================
// Community design foundations
// ---------------------------------------------------------------------------
// A tiny, self-contained design layer shared by every community widget, view
// and page. Three jobs:
//
//   1. Density. [kCommunityScale] is the single knob that makes the whole
//      section noticeably denser than the rest of the app. Wrapping the
//      community subtree in one [CommunityDensityScope] rescales every
//      `context.sp/sz/fs`, `uiText` and responsive read beneath it. Dialogs
//      and bottom sheets push to the root overlay, so their `show()` builders
//      wrap their body in [CommunityDensityScope] too.
//
//   2. Consistency. [CommunitySectionHeader], [CommunityEmptyState],
//      [CommunityTile] and [CommunityPageScaffold] are the shared primitives
//      every component is built on, so headers, cards, empty states and
//      standalone pages look identical everywhere.
//
//   3. Retunability. Dialling the section bigger or smaller later is a
//      one-line edit to [kCommunityScale]; the page width is [kCommunityMaxWidth].
// ===========================================================================

/// The single density knob for the community section.
///
/// Deliberately tighter than the app defaults (mobile 1.0 / tablet 1.1 /
/// desktop 1.2 / large 1.3 space multipliers) so the feed reads at
/// Twitter/X grade. Text is compressed less than space to stay legible, and
/// the a11y min/max text-scale clamps are left at their defaults.
const UiScaleConfig kCommunityScale = UiScaleConfig(
  mobile: UiScale(space: 0.92, text: 0.97, size: 0.94),
  tablet: UiScale(space: 0.94, text: 0.98, size: 0.96),
  desktop: UiScale(space: 0.98, text: 1.0, size: 1.0),
  largeDesktop: UiScale(space: 1.02, text: 1.02, size: 1.02),
);

/// Maximum content width for centred standalone community pages / feeds.
const double kCommunityMaxWidth = 700;

/// Wraps [child] in a [UiThemeScope] carrying [kCommunityScale] so the entire
/// subtree renders at community density. A no-op if the scale is already
/// applied (safe to nest).
class CommunityDensityScope extends StatelessWidget {
  const CommunityDensityScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final UiTheme base = context.ui;
    if (identical(base.scaleConfig, kCommunityScale)) return child;
    return UiThemeScope(
      theme: base.copyWith(scaleConfig: kCommunityScale),
      child: child,
    );
  }
}

/// Compact, consistent section heading used across sidebars, views and pages.
///
/// A short, slightly tracked-in [subheading]-weight title with an optional
/// leading [icon] and a trailing action (widget or text button).
class CommunitySectionHeader extends StatelessWidget {
  const CommunitySectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.onActionTap,
    this.actionLabel,
    this.padding,
  });

  final String title;
  final IconData? icon;

  /// Explicit trailing widget. Takes precedence over [actionLabel].
  final Widget? trailing;

  /// Convenience text action rendered as a compact link when [trailing] is null.
  final String? actionLabel;
  final VoidCallback? onActionTap;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    Widget? action = trailing;
    if (action == null && actionLabel != null) {
      action = InkWell(
        onTap: onActionTap,
        borderRadius: context.radius(theme.radii.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.xs),
            vertical: context.sp(theme.spacing.xxs),
          ),
          child: Text(
            actionLabel!,
            style: context.uiText.caption.copyWith(
              color: theme.colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: context.sz(theme.sizes.iconSm),
              color: theme.colors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Expanded(
            child: Text(
              title,
              style: context.uiText.subheading.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Compact empty-state block — smaller than the app-wide [UiEmptyState] so it
/// sits comfortably inside dense feed columns and sidebars.
class CommunityEmptyState extends StatelessWidget {
  const CommunityEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.lg),
          vertical: context.sp(theme.spacing.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: context.sz(theme.sizes.iconMd),
                color: theme.colors.foregroundMuted,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.uiText.subheading.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
            if (action != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The shared card base for every community tile — hairline border, `radii.md`
/// corners, compact `spacing.sm` padding and a subtle hover state. Renders a
/// static bordered surface when no tap handler is supplied.
class CommunityTile extends StatelessWidget {
  const CommunityTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.intent,
    this.selected = false,
    this.background,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;

  /// Tints the border + fill when [selected] (defaults to the primary accent).
  final UiIntent? intent;
  final bool selected;
  final Color? background;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool interactive = onTap != null || onLongPress != null;
    final Color accent = intent?.color(context) ?? theme.colors.primary;
    final EdgeInsetsGeometry pad =
        padding ?? EdgeInsets.all(context.sp(theme.spacing.sm));

    return UiInteractive(
      enabled: interactive,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      semanticLabel: semanticLabel,
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      builder: (BuildContext context, UiInteractiveState state) {
        final bool active = state.hovered || state.pressed || selected;
        final Color border =
            borderColor ??
            (selected
                ? accent.withValues(alpha: 0.55)
                : active
                ? theme.colors.border
                : theme.colors.border.withValues(alpha: 0.6));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: pad,
          decoration: BoxDecoration(
            color:
                background ??
                (selected
                    ? accent.withValues(alpha: 0.06)
                    : theme.colors.surface),
            borderRadius: context.radius(theme.radii.md),
            border: Border.all(color: border, width: theme.borders.hairline),
          ),
          child: child,
        );
      },
    );
  }
}

/// Standardised chrome for community *standalone* pages (post detail, hashtag,
/// search, inbox, moderation, notification settings): a compact [AppBar] plus a
/// centred [kCommunityMaxWidth] body, wrapped in [CommunityDensityScope] so the
/// page stays dense even when pushed as its own route.
class CommunityPageScaffold extends StatelessWidget {
  const CommunityPageScaffold({
    super.key,
    required this.child,
    this.title,
    this.titleWidget,
    this.actions,
    this.onBack,
    this.bottom,
    this.centered = true,
    this.backgroundColor,
  });

  final Widget child;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final bool centered;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return CommunityDensityScope(
      child: Builder(
        builder: (BuildContext context) {
          final UiTheme theme = context.ui;
          final Widget body = centered
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kCommunityMaxWidth,
                    ),
                    child: child,
                  ),
                )
              : child;

          return Scaffold(
            backgroundColor: backgroundColor ?? theme.colors.background,
            appBar: AppBar(
              backgroundColor: theme.colors.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: onBack != null ? 0 : context.sp(theme.spacing.md),
              leading: onBack != null
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        size: context.sz(theme.sizes.iconMd),
                      ),
                      onPressed: onBack,
                      tooltip: 'Back',
                    )
                  : null,
              title:
                  titleWidget ??
                  (title != null
                      ? Text(
                          title!,
                          style: context.uiText.subheading.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null),
              actions: actions,
              bottom:
                  bottom ??
                  PreferredSize(
                    preferredSize: Size.fromHeight(theme.borders.hairline),
                    child: Container(
                      color: theme.colors.border.withValues(alpha: 0.6),
                      height: theme.borders.hairline,
                    ),
                  ),
            ),
            body: SafeArea(child: body),
          );
        },
      ),
    );
  }
}

/// Feed-style frosted glass capsule pill tab bar shared across Community views
/// (Feed, Explore, Network, Bookmarks) for consistent visual hierarchy.
class CommunityPillTabBar extends StatelessWidget {
  const CommunityPillTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.trailing,
    this.expandTabs = false,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Widget? trailing;
  final bool expandTabs;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    return Container(
      height: context.sz(44),
      decoration: BoxDecoration(
        borderRadius: context.radius(theme.radii.pill),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: context.radius(theme.radii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colors.surface.withValues(alpha: 0.88),
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: theme.colors.border.withValues(alpha: 0.7),
                width: theme.borders.hairline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: expandTabs
                      ? Row(
                          children: <Widget>[
                            for (int i = 0; i < tabs.length; i++)
                              Expanded(
                                child: _CommunityPillTabItem(
                                  label: tabs[i],
                                  selected: i == selectedIndex,
                                  isMobile: isMobile,
                                  onTap: () => onChanged(i),
                                ),
                              ),
                          ],
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (int i = 0; i < tabs.length; i++)
                                _CommunityPillTabItem(
                                  label: tabs[i],
                                  selected: i == selectedIndex,
                                  isMobile: isMobile,
                                  onTap: () => onChanged(i),
                                ),
                            ],
                          ),
                        ),
                ),
                if (trailing != null) ...<Widget>[
                  Container(
                    height: context.sz(18),
                    width: theme.borders.hairline,
                    color: theme.colors.border.withValues(alpha: 0.6),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityPillTabItem extends StatelessWidget {
  const _CommunityPillTabItem({
    required this.label,
    required this.selected,
    required this.isMobile,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isMobile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final BorderRadius pillRadius = context.radius(theme.radii.pill);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: pillRadius,
        onTap: onTap,
        hoverColor: selected
            ? Colors.transparent
            : theme.colors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: theme.motion.fast,
          height: context.sz(34),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm) + 2,
          ),
          decoration: BoxDecoration(
            color: selected
                ? theme.colors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: pillRadius,
            border: selected
                ? Border.all(
                    color: theme.colors.primary.withValues(alpha: 0.4),
                    width: 1,
                  )
                : Border.all(color: Colors.transparent, width: 1),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: theme.colors.primary.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            style: (selected ? context.uiText.bodyStrong : context.uiText.body)
                .copyWith(
                  fontSize: context.fs(isMobile ? 12.5 : 13.5),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? theme.colors.primary
                      : theme.colors.foregroundMuted,
                ),
          ),
        ),
      ),
    );
  }
}

/// Floats a frosted-glass pill tab bar over a full-bleed scrollable body so
/// posts and cards glide cleanly beneath both the tab bar and the floating
/// mobile header with tight, consistent spacing.
class CommunityFloatingTabShell extends StatelessWidget {
  const CommunityFloatingTabShell({
    super.key,
    required this.tabBar,
    required this.body,
    this.banner,
  });

  final Widget tabBar;
  final Widget body;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final MediaQueryData media = MediaQuery.of(context);
    final double safeTop = isMobile ? media.padding.top : 0.0;
    final double topGap = isMobile ? 6.0 : context.sp(theme.spacing.md);
    final double hPad = isMobile ? 12.0 : context.sp(theme.spacing.md);
    final double barHeight = context.sz(44);
    final double contentTopOffset =
        safeTop + topGap + barHeight + context.sp(theme.spacing.xs);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(top: contentTopOffset),
            ),
            child: body,
          ),
        ),
        Positioned(
          top: safeTop + topGap,
          left: hPad,
          right: hPad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (banner != null) ...<Widget>[
                banner!,
                SizedBox(height: context.sp(theme.spacing.xs)),
              ],
              tabBar,
            ],
          ),
        ),
      ],
    );
  }
}
