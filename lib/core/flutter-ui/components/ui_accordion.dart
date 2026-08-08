import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

class UiAccordionItem {
  const UiAccordionItem({
    required this.title,
    required this.content,
    this.subtitle,
    this.leadingIcon,
  });

  final String title;
  final Widget content;
  final String? subtitle;
  final IconData? leadingIcon;
}

/// Expand/collapse list. Supports single or multiple open sections.
class UiAccordion extends StatefulWidget {
  const UiAccordion({
    super.key,
    required this.items,
    this.allowMultiple = false,
    this.initiallyOpen = const <int>{},
  });

  final List<UiAccordionItem> items;
  final bool allowMultiple;
  final Set<int> initiallyOpen;

  @override
  State<UiAccordion> createState() => _UiAccordionState();
}

class _UiAccordionState extends State<UiAccordion> {
  late Set<int> _open = <int>{...widget.initiallyOpen};

  void _toggle(int index) {
    setState(() {
      if (_open.contains(index)) {
        _open.remove(index);
      } else {
        if (!widget.allowMultiple) _open = <int>{};
        _open.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Container(
      decoration: BoxDecoration(
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: theme.colors.border,
          width: theme.borders.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < widget.items.length; i++)
            _UiAccordionTile(
              item: widget.items[i],
              open: _open.contains(i),
              showDivider: i != widget.items.length - 1,
              onTap: () => _toggle(i),
            ),
        ],
      ),
    );
  }
}

class _UiAccordionTile extends StatelessWidget {
  const _UiAccordionTile({
    required this.item,
    required this.open,
    required this.onTap,
    required this.showDivider,
  });

  final UiAccordionItem item;
  final bool open;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final EdgeInsets pad = EdgeInsets.symmetric(
      horizontal: context.sp(theme.spacing.lg),
      vertical: context.sp(theme.spacing.md),
    );
    return Column(
      children: <Widget>[
        UiInteractive(
          onTap: onTap,
          builder: (BuildContext ctx, UiInteractiveState s) => Container(
            color: s.hovered ? theme.colors.surfaceMuted : Colors.transparent,
            padding: pad,
            child: Row(
              children: <Widget>[
                if (item.leadingIcon != null) ...<Widget>[
                  Icon(
                    item.leadingIcon,
                    size: ctx.sz(theme.sizes.iconMd),
                    color: theme.colors.foregroundMuted,
                  ),
                  SizedBox(width: ctx.sp(theme.spacing.md)),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: ctx.uiText.bodyStrong
                            .copyWith(color: theme.colors.foreground),
                      ),
                      if (item.subtitle != null)
                        Text(
                          item.subtitle!,
                          style: ctx.uiText.caption
                              .copyWith(color: theme.colors.foregroundMuted),
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: theme.motion.normal,
                  curve: theme.motion.curve,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: ctx.sz(theme.sizes.iconMd),
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: theme.motion.normal,
          sizeCurve: theme.motion.curve,
          firstCurve: theme.motion.curve,
          crossFadeState:
              open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            width: double.infinity,
            padding: pad.copyWith(top: 0),
            child: DefaultTextStyle(
              style: context.uiText.body
                  .copyWith(color: theme.colors.foregroundMuted),
              child: item.content,
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
        if (showDivider)
          Container(
            height: theme.borders.hairline,
            color: theme.colors.border,
          ),
      ],
    );
  }
}
