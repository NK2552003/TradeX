import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// Text input covering Input / Textarea / SearchInput / numeric order entry.
class UiInput extends StatefulWidget {
  const UiInput({
    super.key,
    this.controller,
    this.hintText,
    this.value,
    this.onChanged,
    this.onSubmitted,
    this.leadingIcon,
    this.trailingIcon,
    this.onTrailingTap,
    this.obscure = false,
    this.enabled = true,
    this.readOnly = false,
    this.error = false,
    this.size = UiSize.md,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.autofocus = false,
    this.maxLength,
    this.prefixText,
    this.suffix,
  });

  /// Multiline variant (Textarea).
  const UiInput.multiline({
    super.key,
    this.controller,
    this.hintText,
    this.value,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.error = false,
    this.size = UiSize.md,
    this.maxLines = 6,
    this.minLines = 3,
    this.maxLength,
    this.autofocus = false,
  })  : leadingIcon = null,
        trailingIcon = null,
        onTrailingTap = null,
        obscure = false,
        keyboardType = TextInputType.multiline,
        inputFormatters = null,
        textInputAction = TextInputAction.newline,
        prefixText = null,
        suffix = null;

  /// Search variant used on discovery / symbol lookup screens.
  const UiInput.search({
    super.key,
    this.controller,
    this.hintText = 'Search',
    this.value,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.size = UiSize.md,
    this.autofocus = false,
  })  : leadingIcon = Icons.search,
        trailingIcon = null,
        onTrailingTap = null,
        obscure = false,
        readOnly = false,
        error = false,
        maxLines = 1,
        minLines = null,
        keyboardType = TextInputType.text,
        inputFormatters = null,
        textInputAction = TextInputAction.search,
        maxLength = null,
        prefixText = null,
        suffix = null;

  final TextEditingController? controller;
  final String? hintText;
  final String? value;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final bool obscure;
  final bool enabled;
  final bool readOnly;
  final bool error;
  final UiSize size;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final int? maxLength;
  final String? prefixText;
  final Widget? suffix;

  @override
  State<UiInput> createState() => _UiInputState();
}

class _UiInputState extends State<UiInput> {
  late TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _focused = false;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.value ?? '');
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void didUpdateWidget(UiInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null &&
        widget.value != null &&
        widget.value != _controller.text) {
      _controller.text = widget.value!;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final bool multiline = widget.maxLines > 1;
    final BorderRadius radius = context.radius(theme.radii.lg);
    final Color borderColor = !widget.enabled
        ? c.border
        : widget.error
            ? c.destructive
            : _focused
                ? c.focusRing
                : c.border;

    return AnimatedContainer(
      duration: theme.motion.fast,
      constraints: BoxConstraints(
        minHeight: multiline ? 0 : widget.size.height(context),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: multiline ? context.sp(theme.spacing.md) : 0,
      ),
      decoration: BoxDecoration(
        color: widget.enabled ? c.surface : c.disabledBackground,
        borderRadius: radius,
        border: Border.all(
          color: borderColor,
          width: _focused ? theme.borders.thick : theme.borders.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: <Widget>[
          if (widget.leadingIcon != null) ...<Widget>[
            Icon(
              widget.leadingIcon,
              size: widget.size.icon(context),
              color: c.foregroundSubtle,
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
          ],
          if (widget.prefixText != null) ...<Widget>[
            Text(
              widget.prefixText!,
              style: context.uiText.body.copyWith(color: c.foregroundMuted),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              autofocus: widget.autofocus,
              obscureText: widget.obscure && _obscured,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              maxLength: widget.maxLength,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              cursorColor: c.primary,
              style: context.uiText.body.copyWith(
                color: widget.enabled ? c.foreground : c.disabledForeground,
              ),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hintText,
                hintStyle: context.uiText.body
                    .copyWith(color: c.foregroundSubtle),
              ),
            ),
          ),
          if (widget.suffix != null) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            widget.suffix!,
          ],
          if (widget.obscure)
            GestureDetector(
              onTap: () => setState(() => _obscured = !_obscured),
              child: Icon(
                _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: widget.size.icon(context),
                color: c.foregroundSubtle,
              ),
            )
          else if (widget.trailingIcon != null)
            GestureDetector(
              onTap: widget.onTrailingTap,
              child: Icon(
                widget.trailingIcon,
                size: widget.size.icon(context),
                color: c.foregroundSubtle,
              ),
            ),
        ],
      ),
    );
  }
}
