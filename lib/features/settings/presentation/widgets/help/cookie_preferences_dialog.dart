import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/privacy/consent_preferences.dart';
import 'publication_reader.dart';

class CookiePreferencesDialog extends StatefulWidget {
  const CookiePreferencesDialog({
    super.key,
    required this.controller,
    this.manage = false,
  });
  final ConsentController controller;
  final bool manage;

  static Future<void> show(BuildContext context, {bool manage = true}) async {
    final controller = ConsentController.instance;
    await controller.initialize();
    await controller.refresh();
    if (!context.mounted) return;
    await UiDialog.show<void>(
      context,
      maxWidth: 620,
      child: CookiePreferencesDialog(controller: controller, manage: manage),
    );
  }

  @override
  State<CookiePreferencesDialog> createState() =>
      _CookiePreferencesDialogState();
}

class _CookiePreferencesDialogState extends State<CookiePreferencesDialog> {
  late bool _manage = widget.manage;
  late bool _analytics = widget.controller.value.analytics;
  late bool _advertising = widget.controller.value.advertising;
  late bool _personalized = widget.controller.value.personalizedAds;
  late bool _affiliate = widget.controller.value.affiliate;

  Future<void> _save(ConsentPreferences choice) async {
    final saved = await widget.controller.save(choice);
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final busy = widget.controller.saving;
      return UiDialog(
        title: 'Your privacy choices',
        description:
            'Essential storage supports sign-in, security and your choices. Optional tracking is your decision. Closing this notice does not accept it.',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Google AdSense is planned for the free version and is not active in this release. Change your choices any time in Help and policies.',
              style: context.uiText.body,
            ),
            UiGap.v(context.ui.spacing.sm),
            UiButton(
              label: 'Read cookie policy',
              variant: UiVariant.link,
              onPressed: busy
                  ? null
                  : () => PublicationReader.open(context, 'cookies'),
            ),
            if (_manage) ...[
              if (widget.controller.value.savedAt != null)
                Text(
                  'Choices saved on this device. Change any option below.',
                  style: context.uiText.caption,
                ),
              const UiSwitch(
                asCard: true,
                value: true,
                enabled: false,
                label: 'Essential storage',
                description:
                    'Required for the service and remembering your choices.',
              ),
              UiSwitch(
                asCard: true,
                value: _analytics,
                enabled: !busy,
                label: 'Analytics',
                description: 'Optional usage measurement when enabled.',
                onChanged: (v) => setState(() => _analytics = v),
              ),
              UiSwitch(
                asCard: true,
                value: _advertising,
                enabled: !busy,
                label: 'Advertising',
                description:
                    'Ad delivery, measurement and related storage when enabled.',
                onChanged: (v) => setState(() {
                  _advertising = v;
                  if (!v) _personalized = false;
                }),
              ),
              UiSwitch(
                asCard: true,
                value: _personalized,
                enabled: !busy && _advertising,
                label: 'Personalised ads',
                description:
                    'Requires advertising permission. Off keeps personalisation disabled.',
                onChanged: (v) => setState(() => _personalized = v),
              ),
              UiSwitch(
                asCard: true,
                value: _affiliate,
                enabled: !busy,
                label: 'Affiliate attribution',
                description:
                    'Remember referral links and measure campaign clicks for up to 30 days.',
                onChanged: (v) => setState(() => _affiliate = v),
              ),
              UiGap.v(context.ui.spacing.sm),
              Text(
                'Saved on this browser or device for 180 days. These choices do not accept terms or grant device permissions.',
                style: context.uiText.caption,
              ),
            ],
            if (widget.controller.error != null) ...[
              UiGap.v(context.ui.spacing.sm),
              UiCallout(
                title: 'Optional tracking is off',
                message: widget.controller.error!,
                intent: UiIntent.warning,
              ),
              UiButton(
                label: 'Continue with essential storage',
                variant: UiVariant.ghost,
                onPressed: busy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
        actions: [
          UiButton(
            label: 'Reject optional',
            variant: UiVariant.outline,
            onPressed: busy ? null : () => _save(const ConsentPreferences()),
          ),
          UiButton(
            label: 'Accept optional',
            variant: UiVariant.outline,
            onPressed: busy
                ? null
                : () => _save(
                    const ConsentPreferences(
                      analytics: true,
                      advertising: true,
                      personalizedAds: true,
                      affiliate: true,
                    ),
                  ),
          ),
          UiButton(
            label: _manage ? 'Save choices' : 'Manage choices',
            loading: busy,
            onPressed: busy
                ? null
                : () {
                    if (!_manage) {
                      setState(() => _manage = true);
                      return;
                    }
                    _save(
                      ConsentPreferences(
                        analytics: _analytics,
                        advertising: _advertising,
                        personalizedAds: _personalized,
                        affiliate: _affiliate,
                      ),
                    );
                  },
          ),
        ],
      );
    },
  );
}
