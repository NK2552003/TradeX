import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_tab_navigation.dart';

class UiTabItem {
  const UiTabItem({
    required this.label,
    this.icon,
    this.badge,
    this.content,
  });

  final String label;
  final IconData? icon;
  final String? badge;
  final Widget? content;
}

/// Underline/pill tabs with panels. Scrolls horizontally when tabs overflow.
class UiTabs extends StatefulWidget {
  const UiTabs({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onChanged,
    this.variant = UiTabsVariant.underline,
    this.expand = false,
  });

  final List<UiTabItem> items;
  final int initialIndex;
  final ValueChanged<int>? onChanged;
  final UiTabsVariant variant;
  final bool expand;

  @override
  State<UiTabs> createState() => _UiTabsState();
}

enum UiTabsVariant { underline, pill }

class _UiTabsState extends State<UiTabs> {
  late int _index = widget.initialIndex;

  void _select(int i) {
    setState(() => _index = i);
    widget.onChanged?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Widget bar = UiTabBar(
      items: widget.items,
      selectedIndex: _index,
      onChanged: _select,
      variant: widget.variant,
      expand: widget.expand,
    );
    final Widget? panel = widget.items[_index].content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        bar,
        if (panel != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.lg)),
          panel,
        ],
      ],
    );
  }
}
