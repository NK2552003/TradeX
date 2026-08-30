import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_input.dart';

/// Password strength buckets used by the sign-up screen.
enum UiPasswordStrength { empty, weak, fair, good, strong }

UiPasswordStrength uiPasswordStrength(String value) {
  if (value.isEmpty) return UiPasswordStrength.empty;
  int score = 0;
  if (value.length >= 8) score++;
  if (value.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(value)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
  if (score <= 1) return UiPasswordStrength.weak;
  if (score == 2) return UiPasswordStrength.fair;
  if (score == 3 || score == 4) return UiPasswordStrength.good;
  return UiPasswordStrength.strong;
}

/// Password input with reveal toggle and a strength meter.
class UiPasswordField extends StatefulWidget {
  const UiPasswordField({
    super.key,
    this.controller,
    this.hintText = 'Password',
    this.onChanged,
    this.showStrength = true,
    this.error,
    this.size = UiSize.md,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool showStrength;
  final String? error;
  final UiSize size;

  @override
  State<UiPasswordField> createState() => _UiPasswordFieldState();
}

class _UiPasswordFieldState extends State<UiPasswordField> {
  String _value = '';
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiPasswordStrength strength = uiPasswordStrength(_value);
    final int filled =
        <UiPasswordStrength, int>{
          UiPasswordStrength.empty: 0,
          UiPasswordStrength.weak: 1,
          UiPasswordStrength.fair: 2,
          UiPasswordStrength.good: 3,
          UiPasswordStrength.strong: 4,
        }[strength] ??
        0;
    final UiIntent intent = switch (strength) {
      UiPasswordStrength.empty => UiIntent.neutral,
      UiPasswordStrength.weak => UiIntent.bearish,
      UiPasswordStrength.fair => UiIntent.warning,
      UiPasswordStrength.good => UiIntent.info,
      UiPasswordStrength.strong => UiIntent.bullish,
    };
    final String label = switch (strength) {
      UiPasswordStrength.empty => '',
      UiPasswordStrength.weak => 'Weak',
      UiPasswordStrength.fair => 'Fair',
      UiPasswordStrength.good => 'Good',
      UiPasswordStrength.strong => 'Strong',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UiInput(
          controller: widget.controller,
          hintText: widget.hintText,
          leadingIcon: Icons.lock_outline,
          trailingIcon: _obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onTrailingTap: () => setState(() => _obscure = !_obscure),
          obscure: _obscure,
          error: widget.error != null,
          size: widget.size,
          onChanged: (String v) {
            setState(() => _value = v);
            widget.onChanged?.call(v);
          },
        ),
        if (widget.error != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            widget.error!,
            style: context.uiText.caption.copyWith(
              color: theme.colors.destructive,
            ),
          ),
        ],
        if (widget.showStrength &&
            strength != UiPasswordStrength.empty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              // The meter keeps two thirds of the row and the word one third.
              // Letting the four bars flex against a fixed-width label meant a
              // large text scale could squeeze them to nothing, leaving a strength
              // reading with no strength bar under it.
              Expanded(
                flex: 2,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < 4; i++)
                      Expanded(
                        child: Container(
                          height: context.sz(4),
                          margin: EdgeInsets.only(
                            right: i == 3 ? 0 : context.sp(theme.spacing.xxs),
                          ),
                          decoration: BoxDecoration(
                            color: i < filled
                                ? intent.color(context)
                                : theme.colors.surfaceMuted,
                            borderRadius: context.radius(theme.radii.pill),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.uiText.caption.copyWith(
                    color: intent.color(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
