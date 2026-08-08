import 'package:flutter/material.dart';

import '../flutter-ui/flutter_ui.dart';
import 'state_gallery.dart';

/// Batch 3 — foundation inputs. Every gallery renders the component across
/// its full state matrix (variants, sizes, validation, density, slots).
class InputShowcaseSection extends StatelessWidget {
  const InputShowcaseSection({super.key, this.startIndex = 5});

  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiShowcaseSection(
          title: 'Inputs',
          subtitle:
              'Text entry, selection and range controls — including every '
              'validation, density and slot combination.',
        ),
        SizedBox(height: gap),
        _InputGallery(index: startIndex),
        SizedBox(height: gap),
        _FieldGallery(index: startIndex + 1),
        SizedBox(height: gap),
        _TextareaGallery(index: startIndex + 2),
        SizedBox(height: gap),
        _CheckboxGallery(index: startIndex + 3),
        SizedBox(height: gap),
        _SwitchGallery(index: startIndex + 4),
        SizedBox(height: gap),
        _SliderGallery(index: startIndex + 5),
      ],
    );
  }
}

class _InputGallery extends StatelessWidget {
  const _InputGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiInput',
      description:
          'Chrome variants, sizes, validation states, prefixes/suffixes, '
          'clearable and loading affordances, password reveal and numeric '
          'order entry.',
      tags: const <String>['form', 'validation', 'responsive'],
      minCaseWidth: 280,
      codeSnippet:
          "UiInput.number(\n  prefixText: '\$',\n  suffixText: 'USD',\n"
          "  validation: UiValidationState.valid,\n  onChanged: setPrice,\n)",
      cases: <UiStateCase>[
        for (final UiInputVariant v in UiInputVariant.values)
          UiStateCase(
            'variant · ${v.name}',
            builder: (BuildContext _) => UiInput(
              variant: v,
              density: density,
              hintText: 'Symbol or company',
              leadingIcon: Icons.search,
            ),
          ),
        UiStateCase(
          'sizes',
          span: 2,
          builder: (BuildContext ctx) => Column(
            children: <Widget>[
              for (final UiSize s in UiSize.values)
                Padding(
                  padding: EdgeInsets.only(bottom: ctx.sp(ctx.ui.spacing.xs)),
                  child: UiInput(
                    size: s,
                    density: density,
                    hintText: 'Size ${s.name}',
                  ),
                ),
            ],
          ),
        ),
        UiStateCase(
          'filled value',
          builder: (BuildContext _) =>
              UiInput(value: 'AAPL', density: density, clearable: true),
        ),
        UiStateCase(
          'invalid',
          builder: (BuildContext _) => UiInput(
            value: 'not-an-email',
            validation: UiValidationState.invalid,
            density: density,
          ),
        ),
        UiStateCase(
          'valid',
          builder: (BuildContext _) => UiInput(
            value: 'trader@example.com',
            validation: UiValidationState.valid,
            density: density,
          ),
        ),
        UiStateCase(
          'warning',
          builder: (BuildContext _) => UiInput(
            value: 'High leverage',
            validation: UiValidationState.warning,
            density: density,
          ),
        ),
        UiStateCase(
          'read-only',
          builder: (BuildContext _) =>
              UiInput(value: 'Locked value', readOnly: true, density: density),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) =>
              UiInput(value: 'Unavailable', enabled: false, density: density),
        ),
        UiStateCase(
          'loading',
          note: 'Async symbol lookup in flight.',
          builder: (BuildContext _) => UiInput.search(
            value: 'NVDA',
            loading: true,
            density: density,
          ),
        ),
        UiStateCase(
          'password',
          builder: (BuildContext _) => UiInput(
            value: 'super-secret',
            obscure: true,
            leadingIcon: Icons.lock_outline,
            density: density,
          ),
        ),
        UiStateCase(
          'prefix + suffix',
          builder: (BuildContext _) => UiInput.number(
            value: '182.40',
            prefixText: '\$',
            suffixText: 'USD',
            density: density,
          ),
        ),
        UiStateCase(
          'counter',
          builder: (BuildContext _) => UiInput(
            value: 'Trade idea',
            maxLength: 40,
            showCounter: true,
            density: density,
          ),
        ),
        UiStateCase(
          'widget slots',
          span: 2,
          builder: (BuildContext _) => UiInput(
            value: '1.00',
            textAlign: TextAlign.end,
            density: density,
            leading: const UiBadge(
              label: 'BTC',
              size: UiSize.xs,
              variant: UiBadgeVariant.solid,
              intent: UiIntent.warning,
            ),
            trailing: UiButton(
              label: 'Max',
              size: UiSize.xs,
              variant: UiVariant.soft,
              expandOnMobile: false,
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldGallery extends StatelessWidget {
  const _FieldGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiField',
      description:
          'Label, required/optional markers, tooltip, header action, helper, '
          'error/warning/success messages, counters and inline layout.',
      tags: const <String>['form', 'layout'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase(
          'label + helper',
          builder: (BuildContext _) => const UiField(
            label: 'Order quantity',
            helper: 'Shares are rounded to the nearest whole unit.',
            child: UiInput(hintText: '0'),
          ),
        ),
        UiStateCase(
          'required + tooltip',
          builder: (BuildContext _) => const UiField(
            label: 'Limit price',
            required: true,
            tooltip: 'The maximum price you are willing to pay.',
            child: UiInput(hintText: '0.00'),
          ),
        ),
        UiStateCase(
          'optional + header action',
          builder: (BuildContext _) => UiField(
            label: 'Password',
            optionalLabel: 'Optional',
            headerAction: UiButton(
              label: 'Forgot?',
              variant: UiVariant.link,
              size: UiSize.xs,
              expandOnMobile: false,
              onPressed: () {},
            ),
            child: const UiInput(obscure: true, hintText: '••••••••'),
          ),
        ),
        UiStateCase(
          'error',
          builder: (BuildContext _) => const UiField(
            label: 'Email',
            error: 'Enter a valid email address.',
            child: UiInput(
              value: 'not-an-email',
              validation: UiValidationState.invalid,
            ),
          ),
        ),
        UiStateCase(
          'warning',
          builder: (BuildContext _) => const UiField(
            label: 'Leverage',
            warning: 'Above 5x increases liquidation risk.',
            child: UiInput(
              value: '10x',
              validation: UiValidationState.warning,
            ),
          ),
        ),
        UiStateCase(
          'success + counter',
          builder: (BuildContext _) => const UiField(
            label: 'Username',
            success: 'Available.',
            counter: '7/20',
            child: UiInput(
              value: 'trader7',
              validation: UiValidationState.valid,
            ),
          ),
        ),
        UiStateCase(
          'inline layout',
          span: 2,
          note: 'Falls back to stacked on mobile.',
          builder: (BuildContext _) => const UiField(
            label: 'Take profit',
            orientation: UiOrientation.horizontal,
            helper: 'Triggered as a market order.',
            child: UiInput(hintText: '0.00'),
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => const UiField(
            label: 'Account tier',
            enabled: false,
            helper: 'Contact support to change.',
            child: UiInput(value: 'Pro', enabled: false),
          ),
        ),
      ],
    );
  }
}

class _TextareaGallery extends StatelessWidget {
  const _TextareaGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiTextarea',
      description:
          'Auto-growing multiline entry with counter, toolbar and footer '
          'slots, validation states and read-only/disabled modes.',
      tags: const <String>['form', 'multiline'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'default',
          builder: (BuildContext _) => const UiTextarea(
            label: 'Trade thesis',
            hintText: 'Why this setup?',
            maxLength: 280,
          ),
        ),
        UiStateCase(
          'filled + helper',
          builder: (BuildContext _) => const UiTextarea(
            label: 'Notes',
            value: 'Breakout above 182 with volume confirmation.',
            helper: 'Visible only to you.',
            rows: 3,
          ),
        ),
        UiStateCase(
          'invalid',
          builder: (BuildContext _) => const UiTextarea(
            label: 'Reason',
            errorText: 'Please add at least 20 characters.',
            value: 'Too short',
            validation: UiValidationState.invalid,
          ),
        ),
        UiStateCase(
          'read-only',
          builder: (BuildContext _) => const UiTextarea(
            label: 'System note',
            value: 'Position auto-closed by risk engine.',
            readOnly: true,
            showCounter: false,
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => const UiTextarea(
            label: 'Archived',
            value: 'This entry can no longer be edited.',
            enabled: false,
            showCounter: false,
          ),
        ),
        UiStateCase(
          'toolbar + footer',
          span: 2,
          builder: (BuildContext ctx) => UiTextarea(
            label: 'Post an idea',
            hintText: 'Share your analysis…',
            maxLength: 500,
            rows: 3,
            toolbar: Wrap(
              spacing: ctx.sp(ctx.ui.spacing.xs),
              children: <Widget>[
                UiButton.icon(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  onPressed: () {},
                ),
                UiButton.icon(
                  icon: Icons.show_chart,
                  label: 'Chart',
                  onPressed: () {},
                ),
                UiButton.icon(
                  icon: Icons.tag,
                  label: 'Symbol',
                  onPressed: () {},
                ),
              ],
            ),
            footer: Align(
              alignment: Alignment.centerRight,
              child: UiButton(
                label: 'Publish',
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckboxGallery extends StatelessWidget {
  const _CheckboxGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    void noopBool(bool _) {}

    return UiStateGallery(
      index: index,
      name: 'UiCheckbox',
      description:
          'Checked, unchecked, indeterminate, sizes, intents, error state, '
          'description and trailing slots, plus selectable card mode.',
      tags: const <String>['form', 'selection'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase(
          'unchecked',
          builder: (BuildContext _) => UiCheckbox(
            value: false,
            label: 'Enable trailing stop',
            density: density,
            onChanged: noopBool,
          ),
        ),
        UiStateCase(
          'checked',
          builder: (BuildContext _) => UiCheckbox(
            value: true,
            label: 'Enable trailing stop',
            density: density,
            onChanged: noopBool,
          ),
        ),
        UiStateCase(
          'indeterminate',
          builder: (BuildContext _) => UiCheckbox(
            value: false,
            indeterminate: true,
            label: 'Select all positions',
            density: density,
            onChanged: noopBool,
          ),
        ),
        UiStateCase(
          'with description',
          builder: (BuildContext _) => UiCheckbox(
            value: true,
            label: 'Email alerts',
            description: 'Sent when a price target is hit.',
            density: density,
            onChanged: noopBool,
          ),
        ),
        UiStateCase(
          'sizes',
          span: 2,
          builder: (BuildContext ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final UiSize s in UiSize.values)
                Padding(
                  padding: EdgeInsets.only(bottom: ctx.sp(ctx.ui.spacing.xs)),
                  child: UiCheckbox(
                    value: true,
                    size: s,
                    label: s.name,
                    onChanged: noopBool,
                  ),
                ),
            ],
          ),
        ),
        UiStateCase(
          'intents',
          span: 2,
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.md),
            runSpacing: ctx.sp(ctx.ui.spacing.xs),
            children: <Widget>[
              for (final UiIntent i in UiIntent.values)
                SizedBox(
                  width: ctx.sz(150),
                  child: UiCheckbox(
                    value: true,
                    intent: i,
                    label: i.name,
                    onChanged: noopBool,
                  ),
                ),
            ],
          ),
        ),
        UiStateCase(
          'error',
          builder: (BuildContext _) => UiCheckbox(
            value: false,
            error: true,
            label: 'Accept risk disclosure',
            errorText: 'You must accept to continue.',
            onChanged: noopBool,
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => const UiCheckbox(
            value: true,
            enabled: false,
            label: 'Locked by administrator',
          ),
        ),
        UiStateCase(
          'trailing slot',
          builder: (BuildContext _) => UiCheckbox(
            value: true,
            label: 'Level 2 data',
            trailing: const UiBadge(label: '\$9/mo', size: UiSize.xs),
            onChanged: noopBool,
          ),
        ),
        UiStateCase(
          'card mode',
          span: 2,
          builder: (BuildContext _) => UiCheckbox(
            value: true,
            asCard: true,
            label: 'Options trading',
            description: 'Unlocks spreads, greeks and IV charts.',
            trailing: UiBadge.status('Enabled'),
            onChanged: noopBool,
          ),
        ),
      ],
    );
  }
}

class _SwitchGallery extends StatelessWidget {
  const _SwitchGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    void noopBool(bool _) {}
    return UiStateGallery(
      index: index,
      name: 'UiSwitch',
      description:
          'On/off states, sizes, intents, track icons, async loading knob, '
          'label positioning, leading slot and card mode.',
      tags: const <String>['form', 'toggle'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase(
          'off / on',
          builder: (BuildContext ctx) => Row(
            children: <Widget>[
              UiSwitch(value: false, onChanged: noopBool),
              SizedBox(width: ctx.sp(ctx.ui.spacing.md)),
              UiSwitch(value: true, onChanged: noopBool),
            ],
          ),
        ),
        UiStateCase(
          'sizes',
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.sm),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final UiSize s in UiSize.values)
                UiSwitch(value: true, size: s, onChanged: noopBool),
            ],
          ),
        ),
        UiStateCase(
          'intents',
          span: 2,
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.sm),
            runSpacing: ctx.sp(ctx.ui.spacing.xs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final UiIntent i in UiIntent.values)
                UiSwitch(value: true, intent: i, onChanged: noopBool),
            ],
          ),
        ),
        UiStateCase(
          'track icons',
          builder: (BuildContext _) => UiSwitch(
            value: true,
            onIcon: Icons.dark_mode,
            offIcon: Icons.light_mode,
            size: UiSize.lg,
            onChanged: noopBool,
          ),
        ),
        UiStateCase(
          'loading',
          builder: (BuildContext _) =>
              UiSwitch(value: true, loading: true, onChanged: noopBool),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext ctx) => Row(
            children: <Widget>[
              const UiSwitch(value: false, enabled: false),
              SizedBox(width: ctx.sp(ctx.ui.spacing.md)),
              const UiSwitch(value: true, enabled: false),
            ],
          ),
        ),
        UiStateCase(
          'label row',
          span: 2,
          builder: (BuildContext _) => UiSwitch(
            value: true,
            label: 'Push notifications',
            description: 'Price alerts and order fills.',
            onChanged: noopBool,
          ),
        ),
        UiStateCase(
          'card mode + leading',
          span: 2,
          builder: (BuildContext ctx) => UiSwitch(
            value: false,
            asCard: true,
            leading: Icon(
              Icons.shield_outlined,
              color: ctx.uiColors.foregroundMuted,
            ),
            label: 'Two-factor authentication',
            description: 'Require a code on every sign-in.',
            onChanged: noopBool,
          ),
        ),
      ],
    );
  }
}

class _SliderGallery extends StatelessWidget {
  const _SliderGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    void noopDouble(double _) {}
    String pct(num v) => '${v.toStringAsFixed(0)}%';

    return UiStateGallery(
      index: index,
      name: 'UiSlider',
      description:
          'Value bubble, bounds, tick marks, preset stops, intents, sizes, '
          'slot affordances and disabled state.',
      tags: const <String>['form', 'range'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase(
          'default',
          builder: (BuildContext _) => UiSlider(
            value: 40,
            label: 'Position size',
            onChanged: noopDouble,
          ),
        ),
        UiStateCase(
          'bounds + ticks',
          builder: (BuildContext _) => UiSlider(
            value: 3,
            min: 1,
            max: 10,
            divisions: 9,
            showTicks: true,
            showBounds: true,
            label: 'Leverage',
            valueFormatter: (num v) => '${v.toStringAsFixed(0)}x',
            onChanged: noopDouble,
          ),
        ),
        UiStateCase(
          'presets',
          span: 2,
          builder: (BuildContext _) => UiSlider(
            value: 50,
            label: 'Allocate',
            valueFormatter: pct,
            presetFormatter: pct,
            presets: const <double>[25, 50, 75, 100],
            helper: 'Percentage of available buying power.',
            onChanged: noopDouble,
          ),
        ),
        UiStateCase(
          'intents',
          span: 2,
          builder: (BuildContext ctx) => Column(
            children: <Widget>[
              for (final UiIntent i in <UiIntent>[
                UiIntent.primary,
                UiIntent.bullish,
                UiIntent.bearish,
                UiIntent.warning,
              ])
                UiSlider(
                  value: 60,
                  intent: i,
                  label: i.name,
                  onChanged: noopDouble,
                ),
            ],
          ),
        ),
        UiStateCase(
          'sizes',
          span: 2,
          builder: (BuildContext ctx) => Column(
            children: <Widget>[
              for (final UiSize s in UiSize.values)
                UiSlider(
                  value: 55,
                  size: s,
                  showValue: false,
                  label: s.name,
                  onChanged: noopDouble,
                ),
            ],
          ),
        ),
        UiStateCase(
          'with slots',
          builder: (BuildContext _) => UiSlider(
            value: 70,
            label: 'Zoom',
            showValue: false,
            leading: const Icon(Icons.zoom_out, size: 18),
            trailing: const Icon(Icons.zoom_in, size: 18),
            onChanged: noopDouble,
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => const UiSlider(
            value: 30,
            enabled: false,
            label: 'Locked',
            onChanged: null,
          ),
        ),
      ],
    );
  }
}
