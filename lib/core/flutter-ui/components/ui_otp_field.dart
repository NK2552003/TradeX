import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_theme.dart';
import '../theme/ui_tokens.dart';
import 'ui_common.dart';

/// Lightweight controller so callers can read, set or clear the code from
/// outside the widget — e.g. clearing the field after a failed verify call,
/// or pre-filling it from a deep link / SMS payload.
class UiOtpFieldController extends ChangeNotifier {
  UiOtpFieldController({String initialValue = ''}) : _value = initialValue;

  String _value;
  String get value => _value;

  set value(String v) {
    if (_value == v) return;
    _value = v;
    notifyListeners();
  }

  void clear() => value = '';
}

/// Segmented one-time-passcode input — [length] single-character boxes with
/// auto-advance, backspace-to-previous and paste / SMS-autofill support.
///
/// Implementation note: a single invisible [TextField] captures all
/// keyboard, paste and autofill input (including OS one-time-code
/// autofill); the boxes underneath are a pure visual projection of its
/// value. This keeps behaviour reliable across platforms without manually
/// juggling focus between N separate fields.
///
/// States: default, hover, focus (active box gets the accent ring),
/// filled, invalid, disabled.
class UiOtpField extends StatefulWidget {
  const UiOtpField({
    super.key,
    this.controller,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.autofocus = false,
    this.enabled = true,
    this.obscure = false,
    this.error = false,
    this.validation = UiValidationState.none,
    this.size = UiSize.lg,
    this.gap,
    this.semanticLabel = 'Verification code',
  });

  /// Optional external controller. When omitted the widget manages its own.
  final UiOtpFieldController? controller;

  /// Number of digits expected (defaults to a standard 6-digit OTP).
  final int length;
  final ValueChanged<String>? onChanged;

  /// Fired once when the code reaches [length] digits — the natural place
  /// to auto-submit a verify request.
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final bool enabled;

  /// Masks entered digits as dots, like a PIN field.
  final bool obscure;

  /// Legacy flag — equivalent to [UiValidationState.invalid].
  final bool error;
  final UiValidationState validation;

  /// Controls box size; [UiSize.lg] matches the default auth-flow inputs.
  final UiSize size;

  /// Space between boxes in logical points (scaled internally). Defaults to the
  /// `sm` spacing token.
  final double? gap;
  final String semanticLabel;

  @override
  State<UiOtpField> createState() => _UiOtpFieldState();
}

class _UiOtpFieldState extends State<UiOtpField> {
  late final TextEditingController _text;
  late final FocusNode _focus;
  UiOtpFieldController? _ownedController;
  bool _focused = false;

  UiOtpFieldController get _ctrl =>
      widget.controller ?? (_ownedController ??= UiOtpFieldController());

  UiValidationState get _validation =>
      widget.error ? UiValidationState.invalid : widget.validation;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _ctrl.value);
    _focus = FocusNode(debugLabel: 'UiOtpField');
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    _ctrl.addListener(_syncFromController);
  }

  void _syncFromController() {
    if (_text.text == _ctrl.value) return;
    _text.value = TextEditingValue(
      text: _ctrl.value,
      selection: TextSelection.collapsed(offset: _ctrl.value.length),
    );
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant UiOtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncFromController);
      _ctrl.addListener(_syncFromController);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_syncFromController);
    _ownedController?.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _handleChanged(String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final String trimmed = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
    if (trimmed != raw) {
      _text.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    _ctrl.value = trimmed;
    widget.onChanged?.call(trimmed);
    if (trimmed.length == widget.length) {
      widget.onCompleted?.call(trimmed);
    }
    setState(() {});
  }

  Color _accent(BuildContext context) {
    final UiColors c = context.uiColors;
    switch (_validation) {
      case UiValidationState.invalid:
        return c.destructive;
      case UiValidationState.valid:
        return UiIntent.success.color(context);
      case UiValidationState.warning:
        return c.warning;
      case UiValidationState.none:
        return c.focusRing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final double defaultBoxSize = widget.size.height(context);
    final double defaultSpacing = context.sp(widget.gap ?? theme.spacing.sm);
    final Color accent = _accent(context);
    final String value = _ctrl.value;
    final bool showRing = _validation != UiValidationState.none;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth;
        final double naturalTotalWidth =
            (defaultBoxSize * widget.length) +
            (defaultSpacing * (widget.length - 1));

        double boxSize = defaultBoxSize;
        double spacing = defaultSpacing;

        // Auto-scale boxSize and gap if parent bounds are constrained
        if (maxW.isFinite && maxW > 0 && naturalTotalWidth > maxW) {
          final double scale = maxW / naturalTotalWidth;
          spacing = (defaultSpacing * scale).clamp(2.0, defaultSpacing);
          boxSize = (maxW - (widget.length - 1) * spacing) / widget.length;
        }

        final double totalWidth =
            (boxSize * widget.length) + (spacing * (widget.length - 1));

        final List<Widget> boxes = List<Widget>.generate(widget.length, (
          int i,
        ) {
          final bool filled = i < value.length;
          final bool isCursor = _focused && widget.enabled && i == value.length;
          final Color borderColor = (isCursor || showRing)
              ? accent
              : (filled ? c.borderStrong : c.border);

          return AnimatedContainer(
            duration: theme.motion.fast,
            curve: theme.motion.curve,
            width: boxSize,
            height: boxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.enabled ? c.surface : c.disabledBackground,
              borderRadius: context.radius(
                boxSize < 38 ? theme.radii.md : theme.radii.lg,
              ),
              border: Border.all(
                color: borderColor,
                width: isCursor ? theme.borders.thick : theme.borders.hairline,
              ),
              boxShadow: isCursor ? uiGlow(context, accent, alpha: 0.18) : null,
            ),
            child: Text(
              filled ? (widget.obscure ? '•' : value[i]) : '',
              style: context.uiText.display.copyWith(
                fontSize: boxSize * 0.45,
                fontWeight: FontWeight.w600,
                color: widget.enabled ? c.foreground : c.disabledForeground,
              ),
            ),
          );
        });

        return Semantics(
          textField: true,
          label: widget.semanticLabel,
          child: SizedBox(
            width: totalWidth,
            height: boxSize,
            child: Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < boxes.length; i++) ...<Widget>[
                      if (i > 0) SizedBox(width: spacing),
                      boxes[i],
                    ],
                  ],
                ),
                // Invisible field capturing keyboard / paste / OS one-time-code
                // autofill. Visually transparent — the boxes above are what the
                // user sees; this only exists to own focus and text input.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      maxLength: widget.length,
                      autofillHints: const <String>[AutofillHints.oneTimeCode],
                      onChanged: _handleChanged,
                      showCursor: false,
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
