import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Animated vector emblem + surface banner shown while opening a linked record
/// (journal trade, strategy playbook, research note) or switching subdomains.
class RecordOpeningBanner extends StatefulWidget {
  const RecordOpeningBanner({
    super.key,
    required this.title,
    this.subtitle = 'Loading record details...',
    this.badgeLabel = 'Opening',
    this.icon = Icons.auto_awesome_rounded,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final IconData icon;
  final VoidCallback? onBack;

  @override
  State<RecordOpeningBanner> createState() => _RecordOpeningBannerState();
}

class _RecordOpeningBannerState extends State<RecordOpeningBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(480)),
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.94, end: 1.0),
            duration: theme.motion.normal,
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: UiCard(
              variant: UiCardVariant.surface,
              accentColor: theme.colors.primary,
              padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: context.sz(96),
                    height: context.sz(96),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: _AnimatedEmblemPainter(
                          progress: _controller.value,
                          primary: theme.colors.primary,
                          accent: theme.colors.info,
                          surface: theme.colors.surfaceMuted,
                        ),
                        child: Center(
                          child: Icon(
                            widget.icon,
                            size: context.sz(30),
                            color: theme.colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  UiGap.v(theme.spacing.md),
                  UiBadge(
                    label: widget.badgeLabel,
                    intent: UiIntent.primary,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                  UiGap.v(theme.spacing.sm),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: context.uiText.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  UiGap.v(theme.spacing.xs),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                  UiGap.v(theme.spacing.lg),
                  ClipRRect(
                    borderRadius: context.radius(theme.radii.pill),
                    child: LinearProgressIndicator(
                      minHeight: context.sz(3),
                      backgroundColor: theme.colors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colors.primary,
                      ),
                    ),
                  ),
                  if (widget.onBack != null) ...[
                    UiGap.v(theme.spacing.md),
                    UiButton(
                      label: 'Cancel',
                      leadingIcon: Icons.arrow_back_rounded,
                      variant: UiVariant.ghost,
                      size: UiSize.sm,
                      onPressed: widget.onBack,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedEmblemPainter extends CustomPainter {
  const _AnimatedEmblemPainter({
    required this.progress,
    required this.primary,
    required this.accent,
    required this.surface,
  });

  final double progress;
  final Color primary;
  final Color accent;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final angle = progress * 2 * math.pi;
    final pulse = 0.85 + 0.15 * math.sin(angle);

    // Outer ambient glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.22 * pulse),
          primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glowPaint);

    // Inner badge disc
    canvas.drawCircle(
      center,
      radius * 0.56,
      Paint()..color = surface,
    );
    canvas.drawCircle(
      center,
      radius * 0.56,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = primary.withValues(alpha: 0.35),
    );

    // Orbiting primary arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: angle,
        endAngle: angle + math.pi * 1.4,
        colors: [
          primary.withValues(alpha: 0.0),
          primary,
          accent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.78));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.78),
      angle,
      math.pi * 1.25,
      false,
      arcPaint,
    );

    // Counter-rotating subtle outer arc
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.92),
      -angle * 0.7,
      math.pi * 0.65,
      false,
      outerPaint,
    );

    // Orbiting spark dot
    final dotOffset = Offset(
      center.dx + radius * 0.78 * math.cos(angle + math.pi * 1.25),
      center.dy + radius * 0.78 * math.sin(angle + math.pi * 1.25),
    );
    canvas.drawCircle(dotOffset, 3.2, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _AnimatedEmblemPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.accent != accent ||
      oldDelegate.surface != surface;
}

class RecordUnavailable extends StatelessWidget {
  const RecordUnavailable({
    super.key,
    required this.message,
    this.title = 'Record unavailable',
    required this.onBack,
  });

  final String message;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      width: double.infinity,
      height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
      child: UiCard(
        padding: EdgeInsets.zero,
        child: Center(
          child: UiEmptyState(
            icon: Icons.article_outlined,
            title: title,
            message: message,
            action: UiButton(
              label: 'Go back',
              leadingIcon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
          ),
        ),
      ),
    ),
  );
}
