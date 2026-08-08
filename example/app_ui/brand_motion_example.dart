import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class BrandMotionExampleView extends StatelessWidget {
  const BrandMotionExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('App Brand Assets', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: const <Widget>[
              AppLogo(size: 40),
              SizedBox(width: 16),
              AppWordmark(fontSize: 24),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('App Motion Helpers', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppFadeIn(
            child: Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.md),
              ),
              child: const Text('AppFadeIn Motion: Smooth entrance timing applied.'),
            ),
          ),
        ],
      ),
    );
  }
}
