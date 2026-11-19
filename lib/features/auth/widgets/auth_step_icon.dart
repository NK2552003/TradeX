import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

/// Small circular icon lockup used at the top of every step's card across
/// the security-sensitive auth flows (forgot password, OTP verification).
class AuthStepIcon extends StatelessWidget {
  const AuthStepIcon({
    super.key,
    required this.icon,
    required this.intent,
    this.large = false,
  });

  final IconData icon;
  final UiIntent intent;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final Color tint = switch (intent) {
      UiIntent.bullish => colors.bullish,
      UiIntent.warning => colors.warning,
      UiIntent.info => colors.info,
      UiIntent.danger => colors.destructive,
      _ => colors.primary,
    };
    final double dim = context.sz(large ? 56 : 44);

    return Center(
      child: Container(
        width: dim,
        height: dim,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tint.withValues(alpha: 0.12),
          border: Border.all(color: tint.withValues(alpha: 0.24)),
        ),
        child: Icon(icon, color: tint, size: context.sz(large ? 26 : 20)),
      ),
    );
  }
}
