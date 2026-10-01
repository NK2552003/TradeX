import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

class UiTrackerBlock {
  const UiTrackerBlock({required this.intent, this.tooltip});

  final UiIntent intent;
  final String? tooltip;
}

/// Uptime/streak tracker (e.g. daily trading streak, signal accuracy history).
class UiTracker extends StatelessWidget {
  UiTracker({
    super.key,
    List<UiTrackerBlock>? blocks,
    List<dynamic>? values,
    this.height,
  }) : blocks = blocks ?? _mapValues(values ?? const <dynamic>[]);

  final List<UiTrackerBlock> blocks;
  final double? height;

  static List<UiTrackerBlock> _mapValues(List<dynamic> items) {
    return items.map((dynamic item) {
      if (item is UiTrackerBlock) return item;
      if (item is UiIntent) return UiTrackerBlock(intent: item);
      if (item is bool) {
        return UiTrackerBlock(
          intent: item ? UiIntent.success : UiIntent.danger,
          tooltip: item ? 'Active' : 'Inactive',
        );
      }
      if (item is num) {
        return UiTrackerBlock(
          intent: item > 0
              ? UiIntent.success
              : (item < 0 ? UiIntent.danger : UiIntent.neutral),
          tooltip: item.toString(),
        );
      }
      return const UiTrackerBlock(intent: UiIntent.neutral);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SizedBox(
      height: context.sz(height ?? 28),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < blocks.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.sz(1)),
                child: Tooltip(
                  message: blocks[i].tooltip ?? '',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: blocks[i].intent.color(context),
                      borderRadius: context.radius(theme.radii.sm),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
