import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/platform/browser_install.dart';
import 'publication_reader.dart';

class InstallAppCard extends StatefulWidget {
  const InstallAppCard({super.key, this.prompt = false});
  final bool prompt;

  @override
  State<InstallAppCard> createState() => _InstallAppCardState();
}

class _InstallAppCardState extends State<InstallAppCard> {
  String? _message;
  bool _busy = false;

  Future<void> _install() async {
    setState(() => _busy = true);
    String result;
    try {
      result = await BrowserInstall.instance.prompt();
    } catch (_) {
      result = 'error';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (result) {
        'accepted' => 'Installation requested. Follow your browser to finish.',
        'dismissed' =>
          'Installation dismissed. You can continue in this browser.',
        'error' =>
          'Installation could not start. Try your browser menu or the guide.',
        _ =>
          'Your browser is not offering an install prompt. See the installation guide.',
      };
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: BrowserInstall.instance,
    builder: (context, _) {
      final installer = BrowserInstall.instance;
      final description = installer.installed
          ? 'AlphaJournal is running as an installed app or installation was confirmed by this browser.'
          : kIsWeb
          ? 'Open AlphaJournal from your device. Installation is optional and does not change your plan or privacy choices.'
          : 'You are using the device app. Browser installation is available from a supported web browser.';
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(description, style: context.uiText.body),
          UiGap.v(context.ui.spacing.md),
          if (!installer.available && !installer.installed && kIsWeb)
            Text(
              'iPhone or iPad: Safari → Share → Add to Home Screen. Desktop: check your browser’s Install app or Add to Dock menu.',
              style: context.uiText.body,
            ),
          if (_message != null) ...[
            UiGap.v(context.ui.spacing.sm),
            UiCallout(title: 'Installation', message: _message!),
          ],
          UiGap.v(context.ui.spacing.md),
          Wrap(
            spacing: context.sp(context.ui.spacing.sm),
            runSpacing: context.sp(context.ui.spacing.sm),
            children: [
              if (installer.available)
                UiButton(
                  label: 'Install app',
                  loading: _busy,
                  onPressed: _busy ? null : _install,
                ),
              UiButton(
                label: 'Installation guide',
                variant: UiVariant.outline,
                onPressed: () => PublicationReader.open(context, 'install'),
              ),
              if (widget.prompt)
                UiButton(
                  label: 'Not now',
                  variant: UiVariant.ghost,
                  onPressed: _busy
                      ? null
                      : () {
                          installer.dismiss();
                          Navigator.of(context).pop();
                        },
                ),
            ],
          ),
        ],
      );
      if (widget.prompt) {
        return UiDialog(title: 'Install AlphaJournal', content: content);
      }
      return AppSettingsSectionBlock(
        title: 'AlphaJournal on your device',
        children: [UiCard(child: content)],
      );
    },
  );
}
