import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_badge.dart';
import 'ui_common.dart';
import 'ui_input.dart';

/// Chip-based tag entry (journal tags, ticker tags, post cashtags).
class UiTagInput extends StatefulWidget {
  const UiTagInput({
    super.key,
    required this.tags,
    ValueChanged<List<String>>? onChanged,
    ValueChanged<List<String>>? onTagsChanged,
    this.label,
    this.hintText = 'Add a tag',
    this.suggestions = const <String>[],
    this.maxTags,
    this.prefix,
    this.intent = UiIntent.primary,
  }) : onChanged = onTagsChanged ?? onChanged;

  final List<String> tags;
  final ValueChanged<List<String>>? onChanged;
  final String? label;
  final String hintText;
  final List<String> suggestions;
  final int? maxTags;

  /// Prepended to every tag when rendered (e.g. `#` or `\$`).
  final String? prefix;
  final UiIntent intent;

  @override
  State<UiTagInput> createState() => _UiTagInputState();
}

class _UiTagInputState extends State<UiTagInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final String tag = raw.trim().replaceAll(RegExp(r'^[#\$]'), '');
    if (tag.isEmpty) return;
    if (widget.tags.contains(tag)) return;
    if (widget.maxTags != null && widget.tags.length >= widget.maxTags!) return;
    widget.onChanged?.call(<String>[...widget.tags, tag]);
    _controller.clear();
  }

  void _remove(String tag) => widget.onChanged?.call(
    widget.tags.where((String t) => t != tag).toList(),
  );

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool mobile = context.uiRes.isMobile;
    final List<String> unused = widget.suggestions
        .where((String s) => !widget.tags.contains(s))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.tags.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                for (final String tag in widget.tags)
                  UiInteractive(
                    onTap: () => _remove(tag),
                    builder: (BuildContext ctx, UiInteractiveState _) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ctx.sp(
                          mobile ? theme.spacing.xs + 2 : theme.spacing.sm,
                        ),
                        vertical: ctx.sp(theme.spacing.xxs),
                      ),
                      // Tags are typed by the reader, so a chip needs both a
                      // width ceiling and a height floor: one keeps a long tag
                      // inside its pill, the other keeps the pill big enough
                      // to hit with a thumb. The phone floor is the smallest
                      // control height rather than a share of the tap target —
                      // a row of tags is an annotation, and at the old floor it
                      // read as a row of buttons.
                      constraints: BoxConstraints(
                        maxWidth: ctx.sz(mobile ? 180 : 220),
                        minHeight: ctx.sz(
                          mobile
                              ? theme.sizes.controlHeightXs
                              : theme.sizes.controlHeightSm,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: widget.intent.surface(ctx),
                        borderRadius: ctx.radius(theme.radii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              '${widget.prefix ?? ''}$tag',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (mobile
                                          ? ctx.uiText.caption
                                          : ctx.uiText.label)
                                      .copyWith(
                                        color: widget.intent.color(ctx),
                                        fontSize: mobile ? ctx.fs(11.5) : null,
                                      ),
                            ),
                          ),
                          SizedBox(width: ctx.sp(theme.spacing.xxs)),
                          Icon(
                            Icons.close_rounded,
                            size: ctx.sz(
                              mobile ? theme.sizes.iconXs : theme.sizes.iconSm,
                            ),
                            color: widget.intent.color(ctx),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        UiInput(
          label: widget.label,
          controller: _controller,
          hintText: widget.hintText,
          leadingIcon: Icons.sell_outlined,
          onSubmitted: _add,
          textInputAction: TextInputAction.done,
        ),
        if (unused.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final String s in unused)
                UiBadge(
                  label: '${widget.prefix ?? ''}$s',
                  icon: Icons.add,
                  intent: UiIntent.neutral,
                  onTap: () => _add(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
