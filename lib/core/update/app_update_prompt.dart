import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'app_update_launcher.dart';
import 'app_update_models.dart';

enum AppUpdatePromptResult { updated, later }

Future<AppUpdatePromptResult?> showAppUpdatePrompt(
  BuildContext context,
  AppUpdateStatus status,
) {
  return UiDialog.show<AppUpdatePromptResult>(
    context,
    dismissible: !status.isRequired,
    blurBackdrop: true,
    child: PopScope(
      canPop: !status.isRequired,
      child: _AppUpdateDialog(status: status),
    ),
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.status});

  final AppUpdateStatus status;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _isLaunching = false;

  Future<void> _update() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    final opened = await installAppUpdate(widget.status.release?.updateUri);
    if (!mounted) return;
    if (!opened) {
      setState(() => _isLaunching = false);
      UiToast.error(
        context,
        title: 'Could not start the update',
        message: 'Open alphajournal.in/download and install the latest build.',
      );
      return;
    }
    if (!widget.status.isRequired && !kIsWeb) {
      Navigator.of(context).pop(AppUpdatePromptResult.updated);
    }
  }

  Future<void> _openReleaseNotes() async {
    final uri = widget.status.releaseNotesUri;
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      UiToast.error(context, title: 'Release notes could not be opened');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final release = status.release!;
    final required = status.isRequired;
    return UiDialog(
      title: required ? 'AlphaJournal update required' : 'Update available',
      description: required
          ? 'This build is no longer supported. Update before continuing.'
          : 'A newer AlphaJournal build is ready for this device.',
      icon: required ? Icons.system_security_update_warning : Icons.update,
      intent: required ? UiIntent.warning : UiIntent.primary,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiCallout(
            title: required ? 'Required for security and compatibility' : null,
            message: release.summary.isEmpty
                ? 'Install the latest release for fixes and improvements.'
                : release.summary,
            intent: required ? UiIntent.warning : UiIntent.info,
          ),
          UiGap.v(context.ui.spacing.md),
          UiKeyValueTable(
            showShareBars: false,
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Installed',
                value: status.current.displayVersion,
              ),
              UiKeyValueRow(
                label: 'Latest',
                value: release.latestDisplay,
                intent: UiIntent.primary,
                emphasis: true,
              ),
              UiKeyValueRow(label: 'Platform', value: status.current.platform),
            ],
          ),
          if (status.releaseNotesUri != null) ...<Widget>[
            UiGap.v(context.ui.spacing.sm),
            UiButton(
              label: 'View release notes',
              variant: UiVariant.ghost,
              leadingIcon: Icons.article_outlined,
              expandOnMobile: false,
              onPressed: _openReleaseNotes,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (!required)
          UiButton(
            label: 'Later',
            variant: UiVariant.outline,
            expandOnMobile: false,
            onPressed: () =>
                Navigator.of(context).pop(AppUpdatePromptResult.later),
          ),
        UiButton(
          label: kIsWeb ? 'Reload latest version' : 'Update now',
          leadingIcon: kIsWeb
              ? Icons.refresh_rounded
              : Icons.system_update_alt_rounded,
          loading: _isLaunching,
          loadingLabel: 'Opening update…',
          expandOnMobile: false,
          onPressed: _update,
        ),
      ],
    );
  }
}
