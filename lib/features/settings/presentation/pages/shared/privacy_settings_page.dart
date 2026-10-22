import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/settings/data/repositories/privacy_repository.dart';
import 'package:tradex/features/settings/models/privacy_settings_model.dart';
import 'package:tradex/features/settings/presentation/pages/shared/blocked_users_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key, this.repository});

  final PrivacyRepository? repository;

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  late final PrivacyRepository _repo;
  PrivacySettingsModel _settings = const PrivacySettingsModel();
  DataExportRequest? _exportRequest;
  bool _loading = true;
  bool _requestingExport = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PrivacyRepositoryImpl();
    _loadPrivacyData();
  }

  Future<void> _loadPrivacyData() async {
    setState(() => _loading = true);
    try {
      final s = await _repo.getPrivacySettings();
      final exp = await _repo.getDataExportStatus();
      if (mounted) {
        setState(() {
          _settings = s;
          _exportRequest = exp;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePublicJournals(bool val) async {
    final old = _settings;
    setState(() => _settings = _settings.copyWith(publicJournals: val));
    try {
      await _repo.setPublicJournalsDefault(val);
    } catch (e) {
      if (mounted) {
        setState(() => _settings = old);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: 'Could not update public journal default setting.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _togglePublicStats(bool val) async {
    final old = _settings;
    setState(() => _settings = _settings.copyWith(publicStatsEnabled: val));
    try {
      await _repo.setPublicStatsEnabled(val);
    } catch (e) {
      if (mounted) {
        setState(() => _settings = old);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: 'Could not update public statistics sharing setting.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _handleRequestExport() async {
    setState(() => _requestingExport = true);
    try {
      final req = await _repo.requestDataExport();
      if (mounted) {
        setState(() {
          _exportRequest = req;
          _requestingExport = false;
        });
        UiToast.show(
          context,
          title: 'Export Requested',
          message: 'We are packaging your trading data archive.',
          intent: UiIntent.info,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _requestingExport = false);
        UiToast.show(
          context,
          title: 'Export Failed',
          message: 'Unable to initiate export request.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Widget _buildDataExportControl() {
    if (_exportRequest == null || _exportRequest!.status == 'none') {
      return UiButton(
        label: 'Request Archive',
        variant: UiVariant.outline,
        size: UiSize.sm,
        loading: _requestingExport,
        onPressed: _handleRequestExport,
      );
    }

    if (_exportRequest!.isProcessing) {
      return Wrap(
        spacing: context.sp(context.ui.spacing.xs),
        runSpacing: context.sp(context.ui.spacing.xs),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const UiBadge(
            label: 'Processing Archive...',
            intent: UiIntent.warning,
            size: UiSize.xs,
          ),
          UiButton(
            label: 'Check Status',
            variant: UiVariant.ghost,
            size: UiSize.xs,
            onPressed: _loadPrivacyData,
          ),
        ],
      );
    }

    if (_exportRequest!.isReady) {
      return Wrap(
        spacing: context.sp(context.ui.spacing.xs),
        runSpacing: context.sp(context.ui.spacing.xs),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const UiBadge(
            label: 'Ready (ZIP)',
            intent: UiIntent.bullish,
            size: UiSize.xs,
          ),
          UiButton(
            label: 'Download ZIP',
            leadingIcon: Icons.download_rounded,
            variant: UiVariant.primary,
            intent: UiIntent.primary,
            size: UiSize.sm,
            onPressed: () async {
              final request = _exportRequest!;
              final uri = Uri.tryParse(request.downloadUrl ?? '');
              final valid =
                  uri != null &&
                  uri.scheme == 'https' &&
                  uri.host.isNotEmpty &&
                  (request.expiresAt == null ||
                      request.expiresAt!.isAfter(DateTime.now()));
              try {
                if (!valid ||
                    !await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                  throw StateError('Export unavailable');
                }
              } catch (_) {
                if (mounted) {
                  UiToast.show(
                    context,
                    title: 'Download unavailable',
                    message:
                        'This archive link is missing or expired. Request a new export.',
                    intent: UiIntent.warning,
                  );
                }
              }
            },
          ),
        ],
      );
    }

    return UiButton(
      label: _exportRequest?.status == 'none'
          ? 'Request Export'
          : 'Retry Export',
      variant: UiVariant.outline,
      size: UiSize.sm,
      onPressed: _handleRequestExport,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.settingsDetail(sections: 3, rowsPerSection: 3);
    }
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool isMobile = context.uiRes.isMobile;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Visibility Section
              AppSettingsSectionBlock(
                title: 'Journal & Profile Visibility',
                description:
                    'Control who can discover and view your trades, strategies, and performance numbers.',
                children: [
                  AppSettingCard(
                    title: 'Make New Journals Public by Default',
                    description:
                        'When enabled, newly created trade logs will be shared to the community feed.',
                    icon: Icons.public_rounded,
                    control: UiSwitch(
                      value: _settings.publicJournals,
                      onChanged: _togglePublicJournals,
                    ),
                  ),
                  AppSettingCard(
                    title: 'Share P&L and Win Rate on Public Profile',
                    description:
                        'Display your overall verified Sharpe ratio, win rate, and profit factor to other users.',
                    icon: Icons.query_stats_rounded,
                    control: UiSwitch(
                      value: _settings.publicStatsEnabled,
                      onChanged: _togglePublicStats,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // User Moderation Section
              AppSettingsSectionBlock(
                title: 'User Moderation & Blocking',
                description:
                    'Manage traders you have blocked from messaging you or seeing your activity.',
                children: [
                  SettingsNavRow(
                    title: 'Blocked Users',
                    subtitle:
                        'Review and unblock accounts you have previously restricted',
                    icon: Icons.block_rounded,
                    onTap: () {
                      openSettingsSubpage(
                        context,
                        title: 'Blocked Users',
                        subtitle: 'Review restricted and muted trader profiles',
                        icon: Icons.block_outlined,
                        page: BlockedUsersPage(repository: _repo),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Data Export Section
              AppSettingsSectionBlock(
                title: 'Data Privacy & GDPR Export',
                description:
                    'Request a complete, machine-readable JSON/CSV archive of all your trades, strategies, and notes.',
                children: [
                  AppSettingCard(
                    title: 'Download Account Data Archive',
                    description: _exportRequest?.isReady == true
                        ? 'Archive generated and ready for secure download. Valid for 7 days.'
                        : 'Generates a ZIP containing journal CSVs, playbook JSONs, and backtest logs.',
                    icon: Icons.cloud_download_outlined,
                    control: _buildDataExportControl(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
