import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class LightboxExampleView extends StatelessWidget {
  const LightboxExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiLightbox - Image / Chart Fullscreen Viewer', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const SizedBox(
            height: 250,
            child: UiLightbox(
              imageUrls: <String>[
                'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3',
              ],
            ),
          ),
        ],
      ),
    );
  }
}
