import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Shared responsive geometry for the mobile floating dock and all flanking
/// floating action buttons (left search/writing desk, right copilot/compose,
/// right workspace `+`) so height, corner radius, icon size, edge inset, and
/// non-stretched pill proportions stay 100% unified across every phone width.
@immutable
class AppMobileDockMetrics {
  const AppMobileDockMetrics({
    required this.height,
    required this.dockWidth,
    required this.iconSize,
    required this.edgeInset,
  });

  final double height;
  final double dockWidth;
  final double iconSize;
  final double edgeInset;

  double get radius => height / 2;

  double get indicatorSize => math.max(0.0, height - 8.0);

  double get indicatorRadius => indicatorSize / 2;

  double widthForSlots(int slots) => height * math.max(1, slots);

  static AppMobileDockMetrics of(BuildContext context, {int slots = 5}) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double edgeInset = screenWidth < 380 ? 10.0 : 12.0;
    final double minSideGap = screenWidth < 380 ? 8.0 : 10.0;
    final int effectiveSlots = math.max(2, slots);
    // Reserve space for the two flanking circular buttons (2 * height), the
    // dock (effectiveSlots * height), and side margins so every slot in the
    // dock is an exact 1:1 square (height × height) and the active indicator
    // is always a true circle ((height - 8) × (height - 8)).
    final double maxFittingHeight =
        (screenWidth - 2 * (edgeInset + minSideGap)) / (effectiveSlots + 2);
    final int rawEvenHeight =
        (maxFittingHeight.clamp(38.0, 50.0).floor() ~/ 2) * 2;
    final double height = rawEvenHeight.toDouble();
    final double iconSize = height <= 44.0
        ? 19.0
        : (height <= 48.0 ? 20.0 : 21.0);
    final double dockWidth = height * effectiveSlots;
    return AppMobileDockMetrics(
      height: height,
      dockWidth: dockWidth,
      iconSize: iconSize,
      edgeInset: edgeInset,
    );
  }

  /// Bottom scroll padding needed on mobile screens so the final items in a
  /// scrollable view clear the floating dock and its bottom margin cleanly.
  static double bottomClearance(BuildContext context, {double extra = 16.0}) {
    if (!context.uiRes.isMobile) return 0.0;
    final AppMobileDockMetrics metrics = of(context);
    final double dockMargin =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? 8.0 : 16.0;
    return MediaQuery.paddingOf(context).bottom +
        metrics.height +
        dockMargin +
        extra;
  }
}

/// Shared visibility state for the floating mobile dock so every floating
/// action button (left search/writing desk, right compose/copilot, right
/// workspace `+`) hides and reveals in lockstep on scroll.
class AppDockVisibility {
  AppDockVisibility._();
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);
}

/// Edge from which a dock-synced floating control enters and exits on scroll.
enum AppDockRevealEdge { bottom, left, right }

/// Wraps any mobile floating action button so it slides from [edge] (with an
/// optional stagger [delay]), fades, and scales in sync with
/// [AppQuietDockScaffold] on scroll up/down.
class AppDockSyncedFab extends StatefulWidget {
  const AppDockSyncedFab({
    super.key,
    required this.child,
    this.edge = AppDockRevealEdge.right,
    this.delay = Duration.zero,
  });

  final Widget child;
  final AppDockRevealEdge edge;
  final Duration delay;

  @override
  State<AppDockSyncedFab> createState() => _AppDockSyncedFabState();
}

class _AppDockSyncedFabState extends State<AppDockSyncedFab>
    with SingleTickerProviderStateMixin {
  Timer? _delayTimer;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    value: AppDockVisibility.hidden.value ? 0.0 : 1.0,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1.0,
  ).animate(_curve);

  Offset get _hiddenOffset => switch (widget.edge) {
    AppDockRevealEdge.bottom => const Offset(0, 1.35),
    AppDockRevealEdge.left => const Offset(-1.45, 0),
    AppDockRevealEdge.right => const Offset(1.45, 0),
  };

  Alignment get _scaleAlignment => switch (widget.edge) {
    AppDockRevealEdge.bottom => Alignment.bottomCenter,
    AppDockRevealEdge.left => Alignment.centerLeft,
    AppDockRevealEdge.right => Alignment.centerRight,
  };

  @override
  void initState() {
    super.initState();
    AppDockVisibility.hidden.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    _delayTimer?.cancel();
    final bool isHidden = AppDockVisibility.hidden.value;
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.value = isHidden ? 0.0 : 1.0;
      setState(() {});
      return;
    }
    void run() {
      if (!mounted) return;
      if (isHidden) {
        _anim.reverse();
      } else {
        _anim.forward();
      }
      setState(() {});
    }

    if (widget.delay > Duration.zero) {
      _delayTimer = Timer(widget.delay, run);
    } else {
      run();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    AppDockVisibility.hidden.removeListener(_onChanged);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isHidden = AppDockVisibility.hidden.value;
    final Animation<Offset> slide = Tween<Offset>(
      begin: _hiddenOffset,
      end: Offset.zero,
    ).animate(_curve);
    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: _curve,
        child: ScaleTransition(
          scale: _scale,
          alignment: _scaleAlignment,
          child: IgnorePointer(
            ignoring: isHidden,
            child: ExcludeSemantics(excluding: isHidden, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Enhanced mobile dock shell wrapping [QuietDock], adding frosted glass blur
/// to every quick-grid tile opened by the center button and full-bleed
/// edge-to-edge body layering beneath the floating dock.
class AppQuietDockScaffold extends StatefulWidget {
  const AppQuietDockScaffold({
    super.key,
    required this.activeDestination,
    required this.destinations,
    required this.pageBuilder,
    this.controller,
    this.initialIndex = 0,
    this.onDestinationTap,
    this.onDestinationSelected,
    this.centerAction,
    this.centerActionActive = false,
    this.primaryDestinationActive = true,
    this.leftActionIcon,
    this.leftActionTooltip,
    this.onLeftActionPressed,
    this.lockedDestinationIndices = const <int>{},
    this.lockedCenterIndices = const <int>{},
    this.swipeEnabled = false,
    this.lazy = true,
    this.keepAlive = false,
    this.backgroundColor,
    this.theme = const QuietDockTheme(),
  }) : assert(destinations.length > 1, 'Provide at least two destinations');

  final List<QuietDockDestination> destinations;
  final String activeDestination;
  final IndexedWidgetBuilder pageBuilder;
  final QuietDockController? controller;
  final int initialIndex;

  /// Returns true when the parent handles a tap outside this dock.
  final bool Function(int)? onDestinationTap;
  final ValueChanged<int>? onDestinationSelected;
  final QuietDockCenterAction? centerAction;
  final bool centerActionActive;
  final bool primaryDestinationActive;
  final IconData? leftActionIcon;
  final String? leftActionTooltip;
  final VoidCallback? onLeftActionPressed;
  final Set<int> lockedDestinationIndices;
  final Set<int> lockedCenterIndices;
  final bool swipeEnabled;
  final bool lazy;
  final bool keepAlive;
  final Color? backgroundColor;
  final QuietDockTheme theme;

  @override
  State<AppQuietDockScaffold> createState() => _AppQuietDockScaffoldState();
}

class _AppQuietDockScaffoldState extends State<AppQuietDockScaffold>
    with SingleTickerProviderStateMixin {
  late QuietDockController _controller;
  PageController? _pageController;
  late final AnimationController _dockAnim = AnimationController(
    vsync: this,
    value: 1.0,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _dockCurve = CurvedAnimation(
    parent: _dockAnim,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _dockSlide = Tween<Offset>(
    begin: const Offset(0, 1.35),
    end: Offset.zero,
  ).animate(_dockCurve);
  late final Animation<double> _dockScale = Tween<double>(
    begin: 0.94,
    end: 1.0,
  ).animate(_dockCurve);
  late int _index;
  final Set<int> _visited = <int>{};
  bool _menuOpen = false;
  bool _dockHidden = false;
  double _scrollDelta = 0.0;

  static const double _hideThreshold = 28.0;
  static const double _revealThreshold = 16.0;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        QuietDockController(initialIndex: widget.initialIndex);
    _index = _controller.index;
    _visited.add(_index);
    _controller.handler = _select;
    _pageController = PageController(initialPage: _index);
  }

  void _setDockHidden(bool hidden, {bool immediate = false}) {
    if (_dockHidden == hidden) return;
    setState(() => _dockHidden = hidden);
    AppDockVisibility.hidden.value = hidden;
    final bool reduced =
        mounted && MediaQuery.disableAnimationsOf(context);
    if (immediate || reduced) {
      _dockAnim.value = hidden ? 0.0 : 1.0;
    } else if (hidden) {
      _dockAnim.reverse();
    } else {
      _dockAnim.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AppQuietDockScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeDestination != oldWidget.activeDestination ||
        widget.theme.height != oldWidget.theme.height) {
      _scrollDelta = 0.0;
      _menuOpen = false;
      if (_dockHidden) {
        _dockHidden = false;
        AppDockVisibility.hidden.value = false;
        _dockAnim.forward();
      }
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.handler = null;
      _controller = widget.controller ?? _controller;
      _controller.handler = _select;
      if (_controller.index != _index) _select(_controller.index);
    }
  }

  @override
  void dispose() {
    AppDockVisibility.hidden.value = false;
    _dockAnim.dispose();
    if (_controller.handler == _select) _controller.handler = null;
    if (widget.controller == null) _controller.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  void _select(int index, {bool fromSwipe = false}) {
    if (index < 0 || index >= widget.destinations.length) return;
    final int previous = _index;
    setState(() {
      _menuOpen = false;
      _scrollDelta = 0.0;
      _visited.add(index);
      _index = index;
    });
    _setDockHidden(false);
    _controller.syncIndex(index);

    final PageController? page = _pageController;
    if (!fromSwipe && page != null && page.hasClients) {
      if ((index - previous).abs() > 1) {
        page.jumpToPage(index);
      } else if (index != previous) {
        page.animateToPage(
          index,
          duration: widget.theme.pageDuration,
          curve: Curves.fastOutSlowIn,
        );
      }
    }

    if (index != previous ||
        widget.centerActionActive ||
        !widget.primaryDestinationActive) {
      widget.onDestinationSelected?.call(index);
    }
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
    if (_menuOpen) _setDockHidden(false);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_menuOpen ||
        widget.theme.height == 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= metrics.minScrollExtent + 32) {
      if (_dockHidden) _setDockHidden(false);
      return false;
    }
    if (notification is ScrollEndNotification) {
      _scrollDelta = 0.0;
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    final double? delta = notification.scrollDelta;
    if (delta == null || delta == 0) return false;

    final bool reversed = metrics.axisDirection == AxisDirection.up;
    final double effectiveDelta = reversed ? -delta : delta;
    final double distanceFromStart = reversed
        ? metrics.maxScrollExtent - metrics.pixels
        : metrics.pixels - metrics.minScrollExtent;

    if (distanceFromStart <= 16.0) {
      _scrollDelta = 0.0;
      if (_dockHidden) _setDockHidden(false);
      return false;
    }

    // Ignore overscroll bounce past either edge.
    if (metrics.outOfRange) return false;

    if ((effectiveDelta > 0 && _scrollDelta < 0) ||
        (effectiveDelta < 0 && _scrollDelta > 0)) {
      _scrollDelta = 0.0;
    }
    _scrollDelta += effectiveDelta;

    if (!_dockHidden && _scrollDelta >= _hideThreshold) {
      _scrollDelta = 0.0;
      _setDockHidden(true);
    } else if (_dockHidden && _scrollDelta <= -_revealThreshold) {
      _scrollDelta = 0.0;
      _setDockHidden(false);
    }
    return false;
  }

  void _handleDestinationTap(int index) {
    final bool isAlreadyActive =
        index == _index &&
        !widget.centerActionActive &&
        widget.primaryDestinationActive;
    if (!isAlreadyActive && widget.onDestinationTap?.call(index) == true) {
      return;
    }
    _select(index);
  }

  Widget _buildPage(BuildContext context, int index) {
    if (widget.lazy && !_visited.contains(index)) {
      return const SizedBox.shrink();
    }
    final Widget child = RepaintBoundary(
      child: widget.pageBuilder(context, index),
    );
    return widget.keepAlive ? _KeepAlivePage(child: child) : child;
  }

  @override
  Widget build(BuildContext context) {
    final QuietDockTheme t = widget.theme.resolve(context);
    final Color background =
        widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final QuietDockCenterAction? action = widget.centerAction;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget pages = PageView.builder(
      controller: _pageController,
      physics: widget.swipeEnabled
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.destinations.length,
      onPageChanged: (int index) {
        if (index != _index) _select(index, fromSwipe: true);
      },
      itemBuilder: _buildPage,
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: pages,
            ),
          ),
          if (_menuOpen && action != null) ...<Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _menuOpen = false),
                child: ColoredBox(
                  color: (isDark ? Colors.black : Colors.black).withValues(
                    alpha: isDark ? 0.38 : 0.22,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom:
                  t.height +
                  t.margin * 2 +
                  MediaQuery.paddingOf(context).bottom,
              child: _FrostedQuickGrid(
                action: action,
                theme: t,
                lockedIndices: widget.lockedCenterIndices,
                onClose: () => setState(() => _menuOpen = false),
              ),
            ),
          ],
          if (t.height > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildDock(context, t),
            ),
          if (t.height > 0 &&
              widget.leftActionIcon != null &&
              widget.onLeftActionPressed != null)
            Builder(
              builder: (BuildContext ctx) {
                final AppMobileDockMetrics m = AppMobileDockMetrics.of(ctx);
                return Positioned(
                  left: m.edgeInset,
                  bottom: MediaQuery.paddingOf(ctx).bottom + t.margin,
                  child: AppDockSyncedFab(
                    edge: AppDockRevealEdge.left,
                    child: _DockLeftGlassButton(
                      icon: widget.leftActionIcon!,
                      tooltip: widget.leftActionTooltip ?? 'Search',
                      size: m.height,
                      iconSize: m.iconSize,
                      onPressed: widget.onLeftActionPressed!,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDock(BuildContext context, QuietDockTheme theme) {
    final int slotCount =
        widget.destinations.length + (widget.centerAction != null ? 1 : 0);
    final double h = theme.height;
    final double exactWidth = h > 0 ? h * slotCount : theme.width;
    final double exactRadius = h > 0 ? h / 2 : theme.radius;
    final double exactIndicatorRadius = h > 8
        ? (h - 8) / 2
        : theme.indicatorRadius;
    final QuietDockTheme normalizedTheme = widget.theme.copyWith(
      width: exactWidth,
      radius: exactRadius,
      indicatorRadius: exactIndicatorRadius,
    );
    return SlideTransition(
      key: const ValueKey('app-dock-slide'),
      position: _dockSlide,
      child: FadeTransition(
        opacity: _dockCurve,
        child: ScaleTransition(
          scale: _dockScale,
          alignment: Alignment.bottomCenter,
          child: ExcludeFocus(
            excluding: _dockHidden,
            child: ExcludeSemantics(
              excluding: _dockHidden,
              child: IgnorePointer(
                ignoring: _dockHidden,
                child: RepaintBoundary(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                    QuietDock(
                      destinations: widget.destinations,
                      selectedIndex: _index,
                      onDestinationSelected: _handleDestinationTap,
                      centerAction: widget.centerAction,
                      centerActionActive:
                          _menuOpen || widget.centerActionActive,
                      onCenterActionPressed: _toggleMenu,
                      theme: normalizedTheme,
                    ),
                    if (widget.lockedDestinationIndices.isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: SafeArea(
                            top: false,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: exactWidth,
                                height: theme.height,
                                margin: EdgeInsets.only(bottom: theme.margin),
                                child: _DockLockOverlayRow(
                                  destinationCount: widget.destinations.length,
                                  hasCenter: widget.centerAction != null,
                                  lockedIndices:
                                      widget.lockedDestinationIndices,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.centerActionActive)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom:
                            MediaQuery.paddingOf(context).bottom + theme.margin,
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: theme.height,
                              height: theme.height,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  right: 8,
                                ),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: context.sz(11),
                                    color: context.ui.colors.primary,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockLeftGlassButton extends StatelessWidget {
  const _DockLeftGlassButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 56,
    this.iconSize = 22,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final uiTheme = context.ui;
    final bool isDark = uiTheme.brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(size / 2);
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: uiTheme.colors.surface.withValues(
                  alpha: isDark ? 0.62 : 0.74,
                ),
                borderRadius: radius,
                border: Border.all(
                  color: uiTheme.colors.borderStrong.withValues(
                    alpha: isDark ? 0.65 : 0.75,
                  ),
                  width: 1.2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: tooltip,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: onPressed,
                    child: Center(
                      child: Icon(
                        icon,
                        size: iconSize,
                        color: uiTheme.colors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockLockBadge extends StatelessWidget {
  const _DockLockBadge();

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: ui.colors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: ui.colors.borderStrong,
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.lock_rounded,
        size: 9,
        color: ui.colors.foregroundMuted,
      ),
    );
  }
}

class _DockLockOverlayRow extends StatelessWidget {
  const _DockLockOverlayRow({
    required this.destinationCount,
    required this.hasCenter,
    required this.lockedIndices,
  });

  final int destinationCount;
  final bool hasCenter;
  final Set<int> lockedIndices;

  @override
  Widget build(BuildContext context) {
    final int centerSlot = destinationCount ~/ 2;
    final int slots = destinationCount + (hasCenter ? 1 : 0);
    return Row(
      children: <Widget>[
        for (int slot = 0; slot < slots; slot++)
          Expanded(
            child: () {
              if (hasCenter && slot == centerSlot) {
                return const SizedBox.shrink();
              }
              final int index =
                  hasCenter && slot > centerSlot ? slot - 1 : slot;
              if (!lockedIndices.contains(index)) {
                return const SizedBox.shrink();
              }
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        top: -2,
                        right: -4,
                        child: _DockLockBadge(),
                      ),
                    ],
                  ),
                ),
              );
            }(),
          ),
      ],
    );
  }
}

class _FrostedQuickGrid extends StatelessWidget {
  const _FrostedQuickGrid({
    required this.action,
    required this.theme,
    required this.lockedIndices,
    required this.onClose,
  });

  final QuietDockCenterAction action;
  final QuietDockTheme theme;
  final Set<int> lockedIndices;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final List<QuickGridItem> items = action.items;
    final int columns = action.columns;
    final int rows = (items.length / columns).ceil();

    return TweenAnimationBuilder<double>(
      duration: theme.gridDuration,
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.scale(
          scale: 0.5 + (0.5 * value),
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int row = 0; row < rows; row++) ...<Widget>[
            if (row != 0) const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (int col = 0; col < columns; col++) ...<Widget>[
                  if (col != 0) const SizedBox(width: 8),
                  Expanded(
                    child: (row * columns + col) < items.length
                        ? _FrostedQuickGridTile(
                            item: items[row * columns + col],
                            locked: lockedIndices.contains(row * columns + col),
                            theme: theme,
                            onClose: onClose,
                          )
                        : const SizedBox(height: 68),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FrostedQuickGridTile extends StatelessWidget {
  const _FrostedQuickGridTile({
    required this.item,
    required this.locked,
    required this.theme,
    required this.onClose,
  });

  final QuickGridItem item;
  final bool locked;
  final QuietDockTheme theme;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderRadius tileRadius = BorderRadius.circular(20);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: tileRadius,
        border: Border.all(color: theme.borderColor!, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: tileRadius,
          onTap: () {
            onClose();
            item.onTap();
          },
          child: SizedBox(
            height: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, size: 18, color: colors.primary),
                    ),
                    if (locked)
                      const Positioned(
                        top: -3,
                        right: -4,
                        child: _DockLockBadge(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (theme.frosted && theme.blur > 0) {
      final double sigma = theme.blur.clamp(0.0, 12.0);
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: item.label,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: tileRadius,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.shadowColor!,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(borderRadius: tileRadius, child: content),
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
