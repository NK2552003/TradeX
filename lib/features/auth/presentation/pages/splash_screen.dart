import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Elegant, minimalist splash screen inspired by Claude's own launch screen —
/// the animated brand mark is painted in pure Dart (see `AppLogoMark`),
/// there is no logo image or SVG asset anywhere in this screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
      );
  late final Animation<double> _slideAnim = Tween<double>(begin: 16.0, end: 0.0)
      .animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
        ),
      );
  late final Animation<double> _markProgress = CurvedAnimation(
    parent: _animController,
    curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _animController.forward().then((_) {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: GestureDetector(
        onTap: widget.onFinish,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLogoMark(size: 40, progress: _markProgress.value),
                      SizedBox(height: context.sp(theme.spacing.lg)),
                      Text(
                        'TradeX',
                        style: context.uiText.display.copyWith(
                          fontSize: 32,
                          color: colors.foreground,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1.0,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Text(
                        'Intelligent market execution',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundSubtle,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xl)),
                      SizedBox(
                        width: context.sz(120),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _animController.value,
                            backgroundColor: colors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.primary,
                            ),
                            minHeight: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
