import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:quiet_dock/quiet_dock.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

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
  final bool swipeEnabled;
  final bool lazy;
  final bool keepAlive;
  final Color? backgroundColor;
  final QuietDockTheme theme;

  @override
  State<AppQuietDockScaffold> createState() => _AppQuietDockScaffoldState();
}

class _AppQuietDockScaffoldState extends State<AppQuietDockScaffold> {
  late QuietDockController _controller;
  PageController? _pageController;
  late int _index;
  final Set<int> _visited = <int>{};
  bool _menuOpen = false;
  bool _dockHidden = false;

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

  @override
  void didUpdateWidget(covariant AppQuietDockScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeDestination != oldWidget.activeDestination ||
        widget.theme.height != oldWidget.theme.height) {
      _dockHidden = false;
      _menuOpen = false;
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
      _dockHidden = false;
      _visited.add(index);
      _index = index;
    });
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

    if (index != previous) widget.onDestinationSelected?.call(index);
  }

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  bool _onUserScroll(UserScrollNotification notification) {
    if (_menuOpen ||
        widget.theme.height == 0 ||
        notification.metrics.axis != Axis.vertical ||
        notification.metrics.maxScrollExtent <=
            notification.metrics.minScrollExtent ||
        notification.direction == ScrollDirection.idle) {
      return false;
    }
    // Reversed lists change their scroll offset in the opposite direction.
    final hide =
        (notification.direction == ScrollDirection.reverse) ==
        (notification.metrics.axisDirection == AxisDirection.down);
    if (hide != _dockHidden) setState(() => _dockHidden = hide);
    return false;
  }

  void _handleDestinationTap(int index) {
    if (index != _index && widget.onDestinationTap?.call(index) == true) return;
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
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onUserScroll,
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
                onClose: () => setState(() => _menuOpen = false),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: t.height == 0 ? null : _buildDock(context, t),
    );
  }

  Widget _buildDock(BuildContext context, QuietDockTheme theme) {
    final motion = context.ui.motion;
    return AnimatedSlide(
      key: const ValueKey('app-dock-slide'),
      offset: _dockHidden ? const Offset(0, 1) : Offset.zero,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion.normal,
      curve: motion.curve,
      child: ExcludeFocus(
        excluding: _dockHidden,
        child: ExcludeSemantics(
          excluding: _dockHidden,
          child: IgnorePointer(
            ignoring: _dockHidden,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                QuietDock(
                  destinations: widget.destinations,
                  selectedIndex: _index,
                  onDestinationSelected: _handleDestinationTap,
                  centerAction: widget.centerAction,
                  centerActionActive: _menuOpen || widget.centerActionActive,
                  onCenterActionPressed: _toggleMenu,
                  theme: widget.theme,
                ),
                if (widget.centerActionActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.paddingOf(context).bottom + theme.margin,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: 56,
                          height: theme.height,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, right: 8),
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
    );
  }
}

class _FrostedQuickGrid extends StatelessWidget {
  const _FrostedQuickGrid({
    required this.action,
    required this.theme,
    required this.onClose,
  });

  final QuietDockCenterAction action;
  final QuietDockTheme theme;
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
    required this.theme,
    required this.onClose,
  });

  final QuickGridItem item;
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 18, color: colors.primary),
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
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: theme.blur, sigmaY: theme.blur),
        child: content,
      );
    }

    return Semantics(
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
