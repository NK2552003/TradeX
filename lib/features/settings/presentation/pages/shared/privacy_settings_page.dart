import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/data/repositories/privacy_repository.dart';
import 'package:tradex/features/settings/models/privacy_settings_model.dart';
import 'package:tradex/features/settings/presentation/pages/shared/blocked_users_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/delete_account_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({
    super.key,
    this.userRole = UserRole.customer,
    this.repository,
    this.onAccountDeleted,
  });

  final UserRole userRole;
  final PrivacyRepository? repository;
  final VoidCallback? onAccountDeleted;

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

  Future<void> _updateMessagePermission(String val) async {
    final old = _settings;
    setState(() => _settings = _settings.copyWith(messagePermission: val));
    try {
      await _repo.setMessagePermission(val);
      if (mounted) {
        final label = val == 'invited'
            ? 'Only Invited Traders'
            : val == 'followers'
            ? 'Followers Only'
            : 'Everyone';
        UiToast.show(
          context,
          title: 'Messaging Privacy Updated',
          message: 'Direct messaging restricted to: $label.',
          intent: UiIntent.info,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _settings = old);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: 'Could not update direct messaging permissions.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _toggleAllowMessageRequests(bool val) async {
    final old = _settings;
    setState(() => _settings = _settings.copyWith(allowMessageRequests: val));
    try {
      await _repo.setAllowMessageRequests(val);
    } catch (e) {
      if (mounted) {
        setState(() => _settings = old);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: 'Could not update message requests preference.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _toggleShowReadReceipts(bool val) async {
    final old = _settings;
    setState(() => _settings = _settings.copyWith(showReadReceipts: val));
    try {
      await _repo.setShowReadReceipts(val);
    } catch (e) {
      if (mounted) {
        setState(() => _settings = old);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: 'Could not update read receipts preference.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _toggleShowActivityStatus(bool val) async {
    final old = _settings;
    setState(() => _settings = _settings.copyWith(showActivityStatus: val));
    try {
      await _repo.setShowActivityStatus(val);
    } catch (e) {
      if (mounted) {
        setState(() => _settings = old);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: 'Could not update online activity status preference.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _toggleFilterSpamRequests(bool val) async {
    final old = _settings;
    setState(() => _settings = _settings.copyWith(filterSpamRequests: val));
    try {
      await _repo.setFilterSpamRequests(val);
    } catch (e) {
      if (mounted) {
        setState(() => _settings = old);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: 'Could not update spam filtering preference.',
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

              // Direct Messages & Chat Privacy (Instagram-like message controls)
              AppSettingsSectionBlock(
                title: 'Direct Messages & Chat Privacy',
                description:
                    'Instagram-style message controls: decide who can send you direct messages, manage message requests, read receipts, and online status.',
                children: [
                  AppSettingCard(
                    title: 'Who Can Send You Messages',
                    description: _settings.messagePermission == 'invited'
                        ? 'Private mode: Only invited traders or accounts you follow can message you.'
                        : _settings.messagePermission == 'followers'
                        ? 'Followers only: Traders who don\'t follow you must submit a message request.'
                        : 'Public mode: Anyone in the trading network can send you direct messages.',
                    icon: Icons.chat_bubble_outline_rounded,
                    control: UiToggleGroup<String>(
                      expand: true,
                      value: _settings.messagePermission,
                      options: const <UiToggleOption<String>>[
                        UiToggleOption<String>(
                          label: 'Everyone',
                          value: 'everyone',
                          icon: Icons.public_rounded,
                        ),
                        UiToggleOption<String>(
                          label: 'Followers Only',
                          value: 'followers',
                          icon: Icons.people_outline_rounded,
                        ),
                        UiToggleOption<String>(
                          label: 'Only Invited',
                          value: 'invited',
                          icon: Icons.lock_outline_rounded,
                        ),
                      ],
                      onChanged: _updateMessagePermission,
                    ),
                  ),
                  AppSettingCard(
                    title: 'Allow Message Requests',
                    description:
                        'When enabled, traders you do not follow can send message requests for your approval.',
                    icon: Icons.mark_email_unread_outlined,
                    control: UiSwitch(
                      value: _settings.allowMessageRequests,
                      onChanged: _toggleAllowMessageRequests,
                    ),
                  ),
                  AppSettingCard(
                    title: 'Show Read Receipts (Seen Status)',
                    description:
                        'Allow other traders to see when you have viewed their incoming messages.',
                    icon: Icons.done_all_rounded,
                    control: UiSwitch(
                      value: _settings.showReadReceipts,
                      onChanged: _toggleShowReadReceipts,
                    ),
                  ),
                  AppSettingCard(
                    title: 'Show Active / Online Status',
                    description:
                        'Let accounts you message see when you are currently online and active on hejournal.in.',
                    icon: Icons.circle,
                    control: UiSwitch(
                      value: _settings.showActivityStatus,
                      onChanged: _toggleShowActivityStatus,
                    ),
                  ),
                  AppSettingCard(
                    title: 'Spam & Low-Quality Message Filter',
                    description:
                        'Automatically filter out suspicious promotional spam, unverified pump bots, and scam messages.',
                    icon: Icons.filter_alt_outlined,
                    control: UiSwitch(
                      value: _settings.filterSpamRequests,
                      onChanged: _toggleFilterSpamRequests,
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
                  SettingsNavRow(
                    title: 'Delete Account & Conditional Data Purge',
                    subtitle:
                        'Permanently delete your account and select whether data is purged immediately or after a 30-day window',
                    icon: Icons.delete_forever_outlined,
                    isDestructive: true,
                    onTap: () {
                      openSettingsSubpage(
                        context,
                        title: 'Delete Account & Data Purge',
                        subtitle:
                            'Configure post-deletion data purge condition and close account',
                        icon: Icons.delete_forever_outlined,
                        page: DeleteAccountPage(
                          userRole: widget.userRole,
                          privacyRepository: _repo,
                          onAccountDeleted: widget.onAccountDeleted,
                        ),
                      );
                    },
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
