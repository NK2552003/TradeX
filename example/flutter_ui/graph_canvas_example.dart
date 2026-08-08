import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class GraphCanvasExampleView extends StatelessWidget {
  const GraphCanvasExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiGraphCanvas - Interactive Node Graph Canvas', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiGraphCanvas(
            height: 200,
            nodes: const <UiGraphNode>[
              UiGraphNode(id: 'n1', label: 'NVDA', weight: 1.5, intent: UiIntent.bullish),
              UiGraphNode(id: 'n2', label: 'AI Strategy', weight: 1.2, intent: UiIntent.primary),
            ],
            edges: const <UiGraphEdge>[
              UiGraphEdge(from: 'n1', to: 'n2'),
            ],
          ),
        ],
      ),
    );
  }
}
