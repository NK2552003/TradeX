import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

/// Precision SVG-grade vector iPhone 16 Pro hardware frame rendered with a
/// pure-Dart [CustomPainter] so it stays razor-sharp across HiDPI displays,
/// themes, and platforms with zero external asset latency.
///
/// The [screen] child is rendered at [virtualScreenWidth] (default `372`) and
/// scaled crisply into the OLED viewport, allowing real AlphaJournal reusable
/// widgets (`AppPostCard`, `AppAiMessageBubble`, `AppTradeCard`, `QuietDock`,
/// etc.) to render authentically with zero layout overflow.
class AppleIphoneSvgFrame extends StatelessWidget {
  const AppleIphoneSvgFrame({
    super.key,
    required this.screen,
    this.width = 256,
    this.aspectRatio = 0.488,
    this.virtualScreenWidth = 372,
    this.statusTime = '9:41',
    this.showDock = true,
    this.dockActiveIndex = 0,
    this.communityDock = false,
    this.leftFabIcon,
    this.rightFabIcon,
    this.onDockSelected,
    this.backgroundColor,
    this.elevated = true,
  });

  final Widget screen;
  final double width;
  final double aspectRatio;
  final double virtualScreenWidth;
  final String statusTime;
  final bool showDock;
  final int dockActiveIndex;
  final bool communityDock;
  final IconData? leftFabIcon;
  final IconData? rightFabIcon;
  final ValueChanged<int>? onDockSelected;
  final Color? backgroundColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isDark = theme.brightness == Brightness.dark;
    final double height = width / aspectRatio;
    final double bezel = width * 0.036;
    final double outerRadius = width * 0.168;
    final double screenRadius = (outerRadius - bezel).clamp(12.0, outerRadius);
    final double screenWidth = width - (bezel * 2);
    final double screenHeight = height - (bezel * 2);
    final double scale = screenWidth / virtualScreenWidth;
    final double virtualHeight = screenHeight / scale;
    final Color screenBg = backgroundColor ?? theme.colors.background;

    return RepaintBoundary(
      child: SizedBox(
        width: width + (width * 0.03),
        height: height,
        child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          // Soft multi-layer studio shadow behind hardware frame
          if (elevated)
            Positioned(
              left: width * 0.015,
              right: width * 0.015,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(outerRadius),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.56 : 0.16,
                      ),
                      blurRadius: 38,
                      spreadRadius: -8,
                      offset: const Offset(0, 22),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.34 : 0.08,
                      ),
                      blurRadius: 14,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),

          // Vector SVG-geometry iPhone titanium body + side buttons
          Positioned.fill(
            child: CustomPaint(
              painter: _IphoneSvgHardwarePainter(
                isDark: isDark,
                outerRadius: outerRadius,
                bezel: bezel,
                sideInset: width * 0.015,
              ),
            ),
          ),

          // Live OLED screen viewport
          Positioned(
            left: (width * 0.015) + bezel,
            top: bezel,
            width: screenWidth,
            height: screenHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(screenRadius),
              child: ColoredBox(
                color: screenBg,
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.topCenter,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(virtualScreenWidth, virtualHeight),
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: SizedBox(
                      width: virtualScreenWidth,
                      height: virtualHeight,
                      child: Stack(
                      children: <Widget>[
                        // Screen content positioned cleanly beneath status bar & Dynamic Island
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 48,
                              bottom: showDock ? 72 : 16,
                            ),
                            child: ClipRect(child: screen),
                          ),
                        ),

                        // Bottom gradient scrim so content glides smoothly under the frosted dock
                        if (showDock)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 92,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      screenBg.withValues(alpha: 0.0),
                                      screenBg.withValues(alpha: 0.88),
                                      screenBg,
                                    ],
                                    stops: const <double>[0.0, 0.58, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Real reusable AlphaJournal QuietDock + flanking circular buttons
                        if (showDock)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 18,
                            child: ApplePreviewQuietDock(
                              activeIndex: dockActiveIndex,
                              communityMode: communityDock,
                              leftFabIcon: leftFabIcon,
                              rightFabIcon: rightFabIcon,
                              onSelected: onDockSelected,
                            ),
                          ),

                        // Top iOS Status Bar + Dynamic Island
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 46,
                          child: _IphoneStatusBarOverlay(
                            time: statusTime,
                            foreground: theme.colors.foreground,
                          ),
                        ),

                        // Home indicator pill
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 6,
                          child: Center(
                            child: Container(
                              width: 118,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colors.foreground.withValues(
                                  alpha: isDark ? 0.34 : 0.24,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

          // Inner glass specular rim highlight
          Positioned(
            left: (width * 0.015) + bezel,
            top: bezel,
            width: screenWidth,
            height: screenHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(screenRadius),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isDark ? 0.08 : 0.22,
                    ),
                    width: 0.75,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Vector SVG-grade iPad Pro hardware frame for wide workspace previews.
class AppleIpadSvgFrame extends StatelessWidget {
  const AppleIpadSvgFrame({
    super.key,
    required this.screen,
    this.width = 480,
    this.height = 560,
    this.virtualWidth = 680,
    this.statusTime = '9:41 AM  NSE LIVE',
  });

  final Widget screen;
  final double width;
  final double height;
  final double virtualWidth;
  final String statusTime;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isDark = theme.brightness == Brightness.dark;
    final double bezel = (width * 0.028).clamp(10.0, 16.0);
    final double outerRadius = (width * 0.058).clamp(22.0, 32.0);
    final double screenRadius = (outerRadius - bezel * 0.7).clamp(14.0, 24.0);
    final double screenWidth = width - (bezel * 2);
    final double screenHeight = height - (bezel * 2);
    final double scale = screenWidth / virtualWidth;
    final double virtualHeight = screenHeight / scale;

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Studio elevation shadow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(outerRadius),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.16),
                    blurRadius: 44,
                    spreadRadius: -8,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
            ),
          ),

          // Vector iPad Pro titanium bezel + camera sensor
          Positioned.fill(
            child: CustomPaint(
              painter: _IpadSvgHardwarePainter(
                isDark: isDark,
                outerRadius: outerRadius,
                bezel: bezel,
              ),
            ),
          ),

          // Live clipped iPadOS viewport
          Positioned(
            left: bezel,
            top: bezel,
            width: screenWidth,
            height: screenHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(screenRadius),
              child: ColoredBox(
                color: theme.colors.background,
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.topCenter,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(virtualWidth, virtualHeight),
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: SizedBox(
                      width: virtualWidth,
                      height: virtualHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _IpadStatusBarOverlay(
                            statusTime: statusTime,
                            foreground: theme.colors.foreground,
                          ),
                          Expanded(child: ClipRect(child: screen)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Renders the exact reusable [QuietDock] + flanking circular frosted glass
/// buttons used by [AppShell] on mobile, scaled cleanly for landing previews.
class ApplePreviewQuietDock extends StatelessWidget {
  const ApplePreviewQuietDock({
    super.key,
    required this.activeIndex,
    this.communityMode = false,
    this.leftFabIcon,
    this.rightFabIcon,
    this.onSelected,
  });

  final int activeIndex;
  final bool communityMode;
  final IconData? leftFabIcon;
  final IconData? rightFabIcon;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isDark = theme.brightness == Brightness.dark;
    const double dockHeight = 44.0;
    const double iconSize = 19.0;

    final List<QuietDockDestination> destinations = communityMode
        ? const <QuietDockDestination>[
            QuietDockDestination(
              icon: Icons.dynamic_feed_outlined,
              selectedIcon: Icons.dynamic_feed_rounded,
              label: 'Feed',
            ),
            QuietDockDestination(
              icon: Icons.explore_outlined,
              selectedIcon: Icons.explore_rounded,
              label: 'Explore',
            ),
            QuietDockDestination(
              icon: Icons.people_outline_rounded,
              selectedIcon: Icons.people_rounded,
              label: 'Network',
            ),
            QuietDockDestination(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ]
        : const <QuietDockDestination>[
            QuietDockDestination(
              icon: Icons.edit_note_outlined,
              selectedIcon: Icons.edit_note_rounded,
              label: 'Journal',
            ),
            QuietDockDestination(
              icon: Icons.forum_outlined,
              selectedIcon: Icons.forum_rounded,
              label: 'Community',
            ),
            QuietDockDestination(
              icon: Icons.calculate_outlined,
              selectedIcon: Icons.calculate_rounded,
              label: 'Calculators',
            ),
            QuietDockDestination(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: 'Settings',
            ),
          ];

    final QuietDockTheme dockTheme = QuietDockTheme(
      background: theme.colors.surface.withValues(alpha: isDark ? 0.72 : 0.84),
      borderColor: theme.colors.borderStrong.withValues(
        alpha: isDark ? 0.65 : 0.75,
      ),
      selectedColor: theme.colors.primary,
      unselectedColor: theme.colors.foregroundMuted,
      indicatorColor: theme.colors.primary.withValues(alpha: 0.14),
      indicatorBorderColor: theme.colors.primary.withValues(alpha: 0.30),
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.36 : 0.12),
      width: dockHeight * (destinations.length + 1),
      height: dockHeight,
      radius: dockHeight / 2,
      indicatorRadius: (dockHeight - 8) / 2,
      margin: 0,
      iconSize: iconSize,
      blur: 14,
      frosted: true,
      showLabels: false,
    );

    final IconData resolvedLeft =
        leftFabIcon ??
        (communityMode ? Icons.edit_note_rounded : Icons.search_rounded);
    final IconData resolvedRight = rightFabIcon ?? Icons.auto_awesome_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _FrostedPreviewCircleFab(
            icon: resolvedLeft,
            size: dockHeight,
            iconSize: iconSize,
          ),
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: SizedBox(
              width: dockHeight * (destinations.length + 1),
              height: dockHeight,
              child: QuietDock(
                destinations: destinations,
                selectedIndex: activeIndex.clamp(0, destinations.length - 1),
                onDestinationSelected: onSelected ?? (int _) {},
                centerAction: QuietDockCenterAction(
                  semanticLabel: communityMode ? 'Switch to App' : 'More tools',
                  icon: communityMode
                      ? Icons.apps_rounded
                      : Icons.grid_view_rounded,
                  items: const <QuickGridItem>[],
                ),
                onCenterActionPressed: () {},
                theme: dockTheme,
              ),
            ),
          ),
          _FrostedPreviewCircleFab(
            icon: resolvedRight,
            size: dockHeight,
            iconSize: iconSize,
          ),
        ],
      ),
    );
  }
}

class _FrostedPreviewCircleFab extends StatelessWidget {
  const _FrostedPreviewCircleFab({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isDark = theme.brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(size / 2);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surface.withValues(
                alpha: isDark ? 0.72 : 0.84,
              ),
              borderRadius: radius,
              border: Border.all(
                color: theme.colors.borderStrong.withValues(
                  alpha: isDark ? 0.65 : 0.75,
                ),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: theme.colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scales a real AlphaJournal reusable widget cleanly from [virtualWidth] into
/// any showcase card visual slot without wrapping or overflow artifacts.
class AppleScaledPreview extends StatelessWidget {
  const AppleScaledPreview({
    super.key,
    required this.child,
    this.virtualWidth = 360,
    this.alignment = Alignment.topCenter,
    this.interactive = false,
  });

  final Widget child;
  final double virtualWidth;
  final Alignment alignment;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final Widget fitted = FittedBox(
      fit: BoxFit.fitWidth,
      alignment: alignment,
      child: SizedBox(width: virtualWidth, child: child),
    );
    return interactive ? fitted : IgnorePointer(child: fitted);
  }
}

class _IphoneStatusBarOverlay extends StatelessWidget {
  const _IphoneStatusBarOverlay({
    required this.time,
    required this.foreground,
  });

  final String time;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            time,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: foreground,
            ),
          ),
          // Dynamic Island pill with optical camera lens detail
          Container(
            width: 108,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.07),
                width: 0.6,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: <Color>[
                      Color(0xFF2B3B6B),
                      Color(0xFF101526),
                      Color(0xFF070910),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 0.6,
                  ),
                ),
              ),
            ),
          ),
          // Vector status icons (signal, Wi-Fi, battery)
          SizedBox(
            width: 58,
            height: 14,
            child: CustomPaint(
              painter: _IosStatusIconsPainter(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _IpadStatusBarOverlay extends StatelessWidget {
  const _IpadStatusBarOverlay({
    required this.statusTime,
    required this.foreground,
  });

  final String statusTime;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            statusTime,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: foreground.withValues(alpha: 0.85),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: foreground.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 52,
                height: 12,
                child: CustomPaint(
                  painter: _IosStatusIconsPainter(color: foreground),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IphoneSvgHardwarePainter extends CustomPainter {
  const _IphoneSvgHardwarePainter({
    required this.isDark,
    required this.outerRadius,
    required this.bezel,
    required this.sideInset,
  });

  final bool isDark;
  final double outerRadius;
  final double bezel;
  final double sideInset;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bodyRect = Rect.fromLTWH(
      sideInset,
      0,
      size.width - (sideInset * 2),
      size.height,
    );
    final RRect outerRRect = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(outerRadius),
    );

    // 1. Hardware side buttons (Action, Volume Up, Volume Down, Power)
    final Paint buttonPaint = Paint()
      ..color = isDark ? const Color(0xFF474440) : const Color(0xFF6B6864);
    final double btnWidth = sideInset * 0.92;
    // Action button (top-left)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0.4, size.height * 0.165, btnWidth, size.height * 0.036),
        topLeft: const Radius.circular(2),
        bottomLeft: const Radius.circular(2),
      ),
      buttonPaint,
    );
    // Volume up
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0.4, size.height * 0.225, btnWidth, size.height * 0.068),
        topLeft: const Radius.circular(2),
        bottomLeft: const Radius.circular(2),
      ),
      buttonPaint,
    );
    // Volume down
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0.4, size.height * 0.308, btnWidth, size.height * 0.068),
        topLeft: const Radius.circular(2),
        bottomLeft: const Radius.circular(2),
      ),
      buttonPaint,
    );
    // Side power button (right)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(
          size.width - btnWidth - 0.4,
          size.height * 0.255,
          btnWidth,
          size.height * 0.105,
        ),
        topRight: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      buttonPaint,
    );

    // 2. Titanium outer shell with metallic sweep gradient
    final Paint titaniumPaint = Paint()
      ..shader = ui.Gradient.linear(
        bodyRect.topLeft,
        bodyRect.bottomRight,
        isDark
            ? const <Color>[
                Color(0xFF4B4743),
                Color(0xFF282523),
                Color(0xFF3E3A36),
                Color(0xFF1D1B1A),
              ]
            : const <Color>[
                Color(0xFF5D5955),
                Color(0xFF2B2826),
                Color(0xFF47433F),
                Color(0xFF1E1C1A),
              ],
        const <double>[0.0, 0.32, 0.70, 1.0],
      );
    canvas.drawRRect(outerRRect, titaniumPaint);

    // 3. Outer specular titanium edge stroke
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: isDark ? 0.18 : 0.28);
    canvas.drawRRect(outerRRect.deflate(0.6), rimPaint);

    // 4. Inner black ceramic OLED glass bezel
    final Rect glassRect = bodyRect.deflate(bezel * 0.28);
    final RRect glassRRect = RRect.fromRectAndRadius(
      glassRect,
      Radius.circular((outerRadius - bezel * 0.28).clamp(10, outerRadius)),
    );
    canvas.drawRRect(glassRRect, Paint()..color = const Color(0xFF0A0A0A));
  }

  @override
  bool shouldRepaint(covariant _IphoneSvgHardwarePainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.outerRadius != outerRadius ||
      oldDelegate.bezel != bezel ||
      oldDelegate.sideInset != sideInset;
}

class _IpadSvgHardwarePainter extends CustomPainter {
  const _IpadSvgHardwarePainter({
    required this.isDark,
    required this.outerRadius,
    required this.bezel,
  });

  final bool isDark;
  final double outerRadius;
  final double bezel;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bodyRect = Offset.zero & size;
    final RRect outerRRect = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(outerRadius),
    );

    final Paint shellPaint = Paint()
      ..shader = ui.Gradient.linear(
        bodyRect.topLeft,
        bodyRect.bottomRight,
        const <Color>[
          Color(0xFF45423E),
          Color(0xFF1D1B1A),
          Color(0xFF363330),
          Color(0xFF151413),
        ],
        const <double>[0.0, 0.35, 0.72, 1.0],
      );
    canvas.drawRRect(outerRRect, shellPaint);

    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: isDark ? 0.16 : 0.26);
    canvas.drawRRect(outerRRect.deflate(0.6), rimPaint);

    // Inner obsidian glass bezel
    final RRect innerGlass = RRect.fromRectAndRadius(
      bodyRect.deflate(2.5),
      Radius.circular((outerRadius - 2.5).clamp(14, outerRadius)),
    );
    canvas.drawRRect(innerGlass, Paint()..color = const Color(0xFF090909));

    // Top centered camera dot
    canvas.drawCircle(
      Offset(size.width / 2, bezel * 0.5),
      2.6,
      Paint()..color = const Color(0xFF232C4A),
    );
  }

  @override
  bool shouldRepaint(covariant _IpadSvgHardwarePainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.outerRadius != outerRadius ||
      oldDelegate.bezel != bezel;
}

class _IosStatusIconsPainter extends CustomPainter {
  const _IosStatusIconsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = color;
    final double h = size.height;

    // 4 cellular signal bars
    for (int i = 0; i < 4; i++) {
      final double barH = h * (0.34 + (i * 0.17));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 4.2, h - barH, 2.7, barH),
          const Radius.circular(1),
        ),
        fill,
      );
    }

    // Wi-Fi arcs
    final Offset wifiCenter = Offset(25.5, h - 1.5);
    final Paint arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: wifiCenter, radius: 7.4),
      -2.35,
      1.55,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: wifiCenter, radius: 4.5),
      -2.35,
      1.55,
      false,
      arcPaint,
    );
    canvas.drawCircle(wifiCenter.translate(0, -1.2), 1.2, fill);

    // Battery shell + fill + cap
    final Rect battery = Rect.fromLTWH(size.width - 21, 1.5, 18.5, h - 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(battery, const Radius.circular(3.2)),
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        battery.deflate(2.0),
        const Radius.circular(1.6),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 1.6, h * 0.34, 1.6, h * 0.32),
        const Radius.circular(0.8),
      ),
      Paint()..color = color.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _IosStatusIconsPainter oldDelegate) =>
      oldDelegate.color != color;
}
