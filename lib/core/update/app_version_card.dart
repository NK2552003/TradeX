import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'app_update_models.dart';
import 'app_update_preferences.dart';
import 'app_update_prompt.dart';
import 'app_update_service.dart';

class AppReleaseVersionCard extends StatefulWidget {
  const AppReleaseVersionCard({super.key, this.service});

  final AppUpdateService? service;

  @override
  State<AppReleaseVersionCard> createState() => _AppReleaseVersionCardState();
}

class _AppReleaseVersionCardState extends State<AppReleaseVersionCard> {
  late Future<AppBuildIdentity> _identity = _service.currentIdentity();
  bool _isChecking = false;

  AppUpdateService get _service => widget.service ?? AppUpdateService.instance;

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    late final AppUpdateStatus status;
    try {
      status = await _service.check(force: true);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
    if (!mounted) return;
    if (!status.checkedSuccessfully) {
      UiToast.warning(
        context,
        title: 'Update check unavailable',
        message: 'Check your connection and try again.',
      );
      return;
    }
    if (!status.hasUpdate) {
      UiToast.success(
        context,
        title: 'AlphaJournal is up to date',
        message: 'Installed version ${status.current.displayVersion}.',
      );
      return;
    }
    final result = await showAppUpdatePrompt(context, status);
    if (result != AppUpdatePromptResult.updated) {
      await AppUpdatePreferences.skip(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiCard(
      title: 'Application version',
      subtitle: 'Release channel, build identity, and update status',
      leading: const Icon(Icons.system_update_alt_outlined),
      child: FutureBuilder<AppBuildIdentity>(
        future: _identity,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const UiCallout(
              message: 'Reading application version…',
              intent: UiIntent.info,
            );
          }
          final identity = snapshot.data;
          if (identity == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const UiCallout(
                  title: 'Version unavailable',
                  message:
                      'AlphaJournal could not read this build identity on the current device.',
                  intent: UiIntent.warning,
                ),
                UiGap.v(context.ui.spacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: UiButton(
                    label: 'Retry',
                    variant: UiVariant.outline,
                    expandOnMobile: false,
                    onPressed: () =>
                        setState(() => _identity = _service.currentIdentity()),
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiKeyValueTable(
                showShareBars: false,
                rows: <UiKeyValueRow>[
                  UiKeyValueRow(
                    label: 'Version',
                    value: identity.version.toString(),
                    emphasis: true,
                  ),
                  UiKeyValueRow(label: 'Build', value: identity.buildNumber),
                  UiKeyValueRow(label: 'Platform', value: identity.platform),
                  UiKeyValueRow(label: 'Package', value: identity.packageName),
                ],
              ),
              UiGap.v(context.ui.spacing.md),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: UiButton(
                  label: 'Check for updates',
                  leadingIcon: Icons.refresh_rounded,
                  variant: UiVariant.outline,
                  loading: _isChecking,
                  loadingLabel: 'Checking…',
                  expandOnMobile: false,
                  onPressed: _checkForUpdates,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
