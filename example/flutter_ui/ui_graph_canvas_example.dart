import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiGraphCanvasExampleView extends StatelessWidget {
  const UiGraphCanvasExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiGraphCanvas Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiGraphCanvas(height: 120, nodes: const <UiGraphNode>[UiGraphNode(id: 'n1', label: 'NVDA', weight: 1.2)], edges: const <UiGraphEdge>[]),
        ],
      ),
    );
  }
}
