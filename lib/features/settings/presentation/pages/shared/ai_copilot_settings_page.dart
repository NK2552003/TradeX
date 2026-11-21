import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/data/app_session.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/security/private_message_service.dart';
import 'package:alphajournal/features/copilot/data/copilot_controller.dart';
import 'package:alphajournal/features/copilot/models/workspace.dart';
import 'package:alphajournal/features/copilot/presentation/connection_settings.dart';
import 'package:alphajournal/features/copilot/presentation/memory_settings.dart';
import 'package:alphajournal/features/settings/data/repositories/ai_settings_repository.dart';
import 'package:alphajournal/features/settings/models/ai_settings_model.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_subpage_scope.dart';

/// Unified AI & Copilot settings page consolidated into Settings.
///
/// Hosts all Copilot controls moved out of the Copilot workspace drawer
/// (appearance override, pause all AI work, web research, memory, connected apps,
/// reconnection) alongside default specialist, response style, context sharing,
/// voice preferences, monthly AI quota status, and subpages for Memory &
/// Connected MCP Servers.
class AiCopilotSettingsPage extends StatefulWidget {
  const AiCopilotSettingsPage({
    super.key,
    this.copilotController,
    this.repository,
    this.onOpenCopilot,
    this.onUpgradePlan,
  });

  final CopilotController? copilotController;
  final AiSettingsRepository? repository;
  final VoidCallback? onOpenCopilot;
  final VoidCallback? onUpgradePlan;

  @override
  State<AiCopilotSettingsPage> createState() => _AiCopilotSettingsPageState();
}

class _AiCopilotSettingsPageState extends State<AiCopilotSettingsPage> {
  late final AiSettingsRepository _repo =
      widget.repository ?? AiSettingsRepositoryImpl.instance;
  late final CopilotController _copilot =
      widget.copilotController ?? CopilotScope.repository;

  late AiSettingsModel _settings = _repo.cachedSettings;
  bool _loading = true;
  bool _reconnecting = false;
  bool _syncingWorkspace = false;
  late bool _wasCopilotConnected = _copilot.connected;

  @override
  void initState() {
    super.initState();
    _copilot.addListener(_onExternalChanged);
    _repo.addListener(_onExternalChanged);
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _copilot.removeListener(_onExternalChanged);
    _repo.removeListener(_onExternalChanged);
    super.dispose();
  }

  bool get _needsE2eeUnlock =>
      SupabaseConfig.isConfigured &&
      SupabaseConfig.client?.auth.currentUser != null &&
      !_copilot.connected &&
      !PrivateMessageService.instance.isLocallyUnlockedFast;

  void _onExternalChanged() {
    if (!mounted) return;
    if (!_wasCopilotConnected && _copilot.connected && !_syncingWorkspace) {
      _wasCopilotConnected = true;
      unawaited(_reconcileWorkspace());
      return;
    }
    _wasCopilotConnected = _copilot.connected;
    setState(() {
      _settings = _repo.cachedSettings;
    });
  }

  Future<void> _reconcileWorkspace() async {
    if (_syncingWorkspace) return;
    _syncingWorkspace = true;
    try {
      await _repo.syncCopilotWorkspace(_copilot);
      if (!mounted) return;
      setState(() {
        _settings = _repo.cachedSettings;
      });
    } finally {
      _syncingWorkspace = false;
    }
  }

  Future<void> _loadSettings() async {
    final loaded = await _repo.getSettings(copilotController: _copilot);
    if (!mounted) return;
    if (_copilot.connected && !_wasCopilotConnected && !_syncingWorkspace) {
      _wasCopilotConnected = true;
      await _reconcileWorkspace();
      if (!mounted) return;
    }
    setState(() {
      _settings = _repo.cachedSettings == loaded
          ? loaded
          : _repo.cachedSettings;
      _loading = false;
    });
  }

  Future<void> _saveSettings(
    AiSettingsModel next, {
    String? toastTitle,
    String? toastMessage,
  }) async {
    setState(() => _settings = next);
    await _repo.updateSettings(
      next,
      copilotController: _copilot,
      syncCopilotWorkspace: true,
    );
    if (!mounted) return;
    final String? syncErr = _repo.lastSyncError;
    if (syncErr != null && syncErr.isNotEmpty) {
      setState(() {});
      UiToast.show(
        context,
        title: 'Saved Locally — Cloud Sync Attention',
        message: syncErr,
        intent: UiIntent.warning,
      );
      return;
    }
    if (toastTitle == null) return;
    UiToast.show(
      context,
      title: toastTitle,
      message: toastMessage ?? 'AI preference updated.',
      intent: UiIntent.success,
    );
  }

  Future<void> _reconnectCopilot() async {
    if (_reconnecting) return;
    setState(() => _reconnecting = true);
    await _copilot.reload();
    if (_copilot.connected) {
      await _repo.syncCopilotWorkspace(_copilot);
    } else {
      await _repo.getSettings(copilotController: _copilot);
    }
    if (!mounted) return;
    setState(() {
      _reconnecting = false;
      _settings = _repo.cachedSettings;
    });
    final String? syncErr = _repo.lastSyncError;
    UiToast.show(
      context,
      title: _copilot.connected && syncErr == null
          ? 'Copilot Connected'
          : (_copilot.connected
                ? 'Workspace Connected (Preferences Pending)'
                : 'Copilot Service Offline'),
      message:
          syncErr ??
          (_copilot.connected
              ? 'Workspace settings and specialists synced.'
              : (_copilot.error ??
                    'Changes remain saved locally and will sync when online.')),
      intent: (_copilot.connected && syncErr == null)
          ? UiIntent.success
          : UiIntent.warning,
    );
  }

  Future<void> _openUnlockWorkspaceDialog() async {
    final bool hasIdentity = await PrivateMessageService.instance
        .hasIdentity()
        .catchError((_) => true);
    if (!mounted) return;
    final TextEditingController passCtrl = TextEditingController();
    String? dialogError;
    bool unlocking = false;
    try {
      final bool? unlocked = await UiDialog.show<bool>(
        context,
        maxWidth: 460,
        child: StatefulBuilder(
          builder: (ctx, setModalState) => UiDialog(
            title: hasIdentity
                ? 'Unlock Encrypted AI Workspace'
                : 'Set Up Encrypted AI Workspace',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasIdentity
                      ? 'Enter your account password or recovery passphrase to decrypt and sync your Copilot threads, memories, and workspace settings.'
                      : 'Create a 16+ character recovery passphrase to encrypt your Copilot history and settings across devices.',
                  style: context.uiText.caption.copyWith(
                    color: context.ui.colors.foregroundMuted,
                  ),
                ),
                SizedBox(height: context.sp(context.ui.spacing.md)),
                UiPasswordField(
                  controller: passCtrl,
                  label: hasIdentity
                      ? 'Password or Recovery Passphrase'
                      : 'Recovery Passphrase (min 16 chars)',
                  hintText: 'Enter passphrase…',
                  onChanged: (_) {
                    if (dialogError != null) {
                      setModalState(() => dialogError = null);
                    }
                  },
                ),
                if (dialogError != null) ...[
                  SizedBox(height: context.sp(context.ui.spacing.sm)),
                  UiCallout(
                    title: 'Unlock Failed',
                    message: dialogError!,
                    intent: UiIntent.danger,
                  ),
                ],
              ],
            ),
            actions: [
              UiButton(
                label: 'Cancel',
                variant: UiVariant.ghost,
                onPressed: unlocking
                    ? null
                    : () => Navigator.of(ctx).pop(false),
              ),
              UiButton(
                label: 'Unlock',
                loading: unlocking,
                onPressed: unlocking
                    ? null
                    : () async {
                        setModalState(() {
                          unlocking = true;
                          dialogError = null;
                        });
                        try {
                          await PrivateMessageService.instance.unlock(
                            passCtrl.text,
                            allowAccountPassword: hasIdentity,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setModalState(() {
                            unlocking = false;
                            dialogError = e is StateError ? e.message : '$e';
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      );
      if (unlocked == true && mounted) {
        await _reconnectCopilot();
      }
    } finally {
      passCtrl.dispose();
    }
  }

  static bool _specialistAllows(Specialist specialist, String flag) =>
      switch (flag) {
        'research' => specialist.research,
        'memory' => specialist.memory,
        'code' => specialist.code,
        'apps' => specialist.apps,
        'learning' => specialist.learning,
        _ => false,
      };

  Future<void> _toggleSpecialistPermission(
    Specialist specialist,
    String field,
    bool value,
  ) async {
    final body = <String, dynamic>{
      'action': 'specialist.save',
      'id': specialist.id,
      'name': specialist.name,
      'role': specialist.role,
      'instructions': specialist.instructions,
      'spaceIds': specialist.spaceIds,
      for (final flag in const [
        'research',
        'memory',
        'code',
        'apps',
        'learning',
      ])
        flag: flag == field ? value : _specialistAllows(specialist, flag),
    };
    bool synced = false;
    try {
      final res = _copilot.connected
          ? await _copilot.action(body, refresh: true, reportError: false)
          : null;
      synced = res != null;
    } catch (_) {
      synced = false;
    }
    if (!synced) {
      specialist.json[field] = value;
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    UiToast.show(
      context,
      title: '${specialist.name} Updated',
      message: synced
          ? '${_permissionLabel(field)} ${value ? 'enabled' : 'disabled'} for ${specialist.name}.'
          : '${_permissionLabel(field)} updated locally; reconnect Copilot workspace to sync.',
      intent: synced ? UiIntent.info : UiIntent.warning,
    );
  }

  static String _permissionLabel(String flag) => switch (flag) {
    'research' => 'Web research',
    'memory' => 'Memory access',
    'code' => 'Code execution',
    'apps' => 'Connected apps',
    'learning' => 'Learning extraction',
    _ => flag,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final bool isMobile = context.uiRes.isMobile;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    if (_loading) {
      return UiSkeleton.settingsDetail(sections: 4, rowsPerSection: 3);
    }

    final int used = _copilot.effectiveAiQueriesUsed;
    final int limit = _copilot.effectiveAiQueriesLimit;
    final double ratio = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final bool hasQuota = limit < 1000000;
    final List<Specialist> specialists = _copilot.workspace.specialists;
    final List<UiOption<String>> specialistOptions = specialists.isNotEmpty
        ? [
            for (final sp in specialists)
              UiOption<String>(label: sp.name, value: sp.id),
          ]
        : const <UiOption<String>>[
            UiOption(label: 'Market Analyst (Atlas)', value: 'analyst'),
            UiOption(label: 'Trading Coach (Sage)', value: 'coach'),
            UiOption(label: 'Desk Writer (Quill)', value: 'writer'),
          ];
    final String selectedSpecialistId =
        specialistOptions.any((o) => o.value == _settings.defaultSpecialistId)
        ? _settings.defaultSpecialistId
        : specialistOptions.first.value;

    final double pagePad = context.sp(
      isMobile ? theme.spacing.md : theme.spacing.lg,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        pagePad,
        MediaQuery.paddingOf(context).top + pagePad,
        pagePad,
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
              // AI Service Status & Quota Overview
              AppSettingsSectionBlock(
                title: 'AI Copilot Workspace Status',
                description:
                    'Manage your AI assistant connectivity, monthly query usage, and workspace availability.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: context.sp(theme.spacing.sm),
                          runSpacing: context.sp(theme.spacing.sm),
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: context.sp(theme.spacing.sm),
                              runSpacing: context.sp(theme.spacing.xs),
                              children: [
                                Icon(
                                  Icons.auto_awesome_outlined,
                                  size: context.sz(20),
                                  color: colors.primary,
                                ),
                                Text(
                                  'AI Service Connection',
                                  style: context.uiText.bodyStrong,
                                ),
                                UiBadge(
                                  label:
                                      _copilot.connected &&
                                          _repo.lastSyncError == null
                                      ? 'Connected'
                                      : (_repo.hasCloudPreferences
                                            ? 'Account Synced'
                                            : (_needsE2eeUnlock
                                                  ? 'Locked'
                                                  : 'Local Sync')),
                                  intent:
                                      _copilot.connected &&
                                          _repo.lastSyncError == null
                                      ? UiIntent.success
                                      : (_repo.lastSyncError != null
                                            ? UiIntent.warning
                                            : UiIntent.neutral),
                                  size: UiSize.xs,
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: context.sp(theme.spacing.xs),
                              runSpacing: context.sp(theme.spacing.xs),
                              children: [
                                if (_needsE2eeUnlock)
                                  UiButton(
                                    label: 'Unlock Workspace',
                                    variant: UiVariant.primary,
                                    size: UiSize.sm,
                                    onPressed: _openUnlockWorkspaceDialog,
                                  ),
                                if (widget.onOpenCopilot != null)
                                  UiButton(
                                    label: 'Open AI Copilot',
                                    variant: UiVariant.ghost,
                                    size: UiSize.sm,
                                    onPressed: widget.onOpenCopilot,
                                  ),
                                UiButton(
                                  label: 'Reconnect',
                                  variant: UiVariant.outline,
                                  size: UiSize.sm,
                                  loading: _reconnecting,
                                  onPressed: _reconnecting
                                      ? null
                                      : _reconnectCopilot,
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        Text(
                          _copilot.error?.isNotEmpty == true
                              ? _copilot.error!
                              : (_copilot.connected
                                    ? (_repo.lastSyncError ??
                                          'Connected to encrypted Copilot workspace and Supabase preferences. Settings apply across all devices.')
                                    : (_repo.hasCloudPreferences
                                          ? 'Saved to your Supabase account preferences. Encrypted Copilot workspace will sync once connected.'
                                          : 'Preferences save immediately on this device and sync to cloud workspace when connected.')),
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                        if (_repo.lastSyncError != null &&
                            _repo.lastSyncError!.isNotEmpty) ...[
                          SizedBox(height: context.sp(theme.spacing.sm)),
                          UiCallout(
                            title: 'Cloud Preferences Sync Issue',
                            message: _repo.lastSyncError!,
                            intent: UiIntent.warning,
                            action: UiButton(
                              label: 'Retry Sync',
                              size: UiSize.xs,
                              variant: UiVariant.outline,
                              onPressed: _reconnectCopilot,
                            ),
                          ),
                        ],
                        if (_needsE2eeUnlock &&
                            _copilot.error != null &&
                            _copilot.error!.isNotEmpty) ...[
                          SizedBox(height: context.sp(theme.spacing.sm)),
                          UiCallout(
                            title: 'Encrypted Copilot Workspace Locked',
                            message:
                                'Unlock with your account password or recovery passphrase to connect threads, memories, and specialists on this browser.',
                            intent: UiIntent.info,
                            action: UiButton(
                              label: 'Unlock Workspace',
                              size: UiSize.xs,
                              variant: UiVariant.primary,
                              onPressed: _openUnlockWorkspaceDialog,
                            ),
                          ),
                        ],
                        SizedBox(height: context.sp(theme.spacing.md)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Monthly AI Prompt Quota',
                              style: context.uiText.bodyStrong,
                            ),
                            Text(
                              hasQuota
                                  ? '$used / $limit prompts'
                                  : '$used prompts used (${AppTokens.tierLabel(AppSession.instance.tier.value)})',
                              style: context.uiText.caption.copyWith(
                                color: _copilot.isAiQuotaBlocked
                                    ? colors.bearish
                                    : colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                        if (hasQuota) ...[
                          SizedBox(height: context.sp(theme.spacing.xs)),
                          UiProgressBar(
                            value: ratio,
                            intent: _copilot.isAiQuotaBlocked
                                ? UiIntent.danger
                                : (ratio > 0.85
                                      ? UiIntent.warning
                                      : UiIntent.primary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Moved Copilot Workspace Controls
              AppSettingsSectionBlock(
                title: 'Copilot Capabilities & Privacy Controls',
                description:
                    'Core Copilot settings previously located in the Copilot panel.',
                children: [
                  AppSettingCard(
                    title: 'Pause All AI Work',
                    description:
                        'Temporarily suspend new scheduled AI tasks and background runs across your workspace.',
                    icon: Icons.pause_circle_outline_rounded,
                    control: UiSwitch(
                      value: _settings.paused,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(paused: val),
                        toastTitle: val ? 'AI Work Paused' : 'AI Work Resumed',
                        toastMessage: val
                            ? 'Scheduled AI runs are paused until re-enabled.'
                            : 'Scheduled AI runs and automations are active.',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Allow Web Research',
                    description:
                        'Let Copilot search live financial news, filings, and market sources with citations.',
                    icon: Icons.travel_explore_rounded,
                    control: UiSwitch(
                      value: _settings.allowWebResearch,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(allowWebResearch: val),
                        toastTitle: 'Web Research Updated',
                        toastMessage: val
                            ? 'Copilot can search live sources and cite links.'
                            : 'Copilot will rely strictly on workspace context.',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Allow Saved Preferences (Memory)',
                    description:
                        'Allow specialists to remember your trading style, rules, and preferences across threads.',
                    icon: Icons.psychology_outlined,
                    control: UiSwitch(
                      value: _settings.allowMemory,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(allowMemory: val),
                        toastTitle: 'Copilot Memory Updated',
                        toastMessage: val
                            ? 'Saved trader preferences will personalize answers.'
                            : 'Memory injection disabled for new AI runs.',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Allow Connected Apps (MCP)',
                    description:
                        'Enable authorized Model Context Protocol tool servers and external workspace connectors.',
                    icon: Icons.extension_outlined,
                    control: UiSwitch(
                      value: _settings.allowConnectedApps,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(allowConnectedApps: val),
                        toastTitle: 'Connected Apps Updated',
                        toastMessage: val
                            ? 'Enabled MCP integrations are available to specialists.'
                            : 'All connected MCP tool servers paused.',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Copilot Panel Appearance',
                    description:
                        'Override the visual theme used inside the AI Copilot screen.',
                    icon: Icons.contrast_rounded,
                    control: UiSelect<String>(
                      width: isMobile ? null : 210,
                      value: _settings.appearance,
                      options: const <UiOption<String>>[
                        UiOption(label: 'Follow app', value: 'system'),
                        UiOption(label: 'Light mode', value: 'light'),
                        UiOption(label: 'Dark mode', value: 'dark'),
                      ],
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(appearance: val),
                        toastTitle: 'Copilot Theme Updated',
                        toastMessage: 'Copilot panel appearance set to $val.',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // AI Behavior, Specialist & Safety Defaults
              AppSettingsSectionBlock(
                title: 'Assistant Behavior, Specialists & Safety',
                description:
                    'Configure default research persona, answer verbosity, context sharing, and action safeguards.',
                children: [
                  AppSettingCard(
                    title: 'Default AI Specialist',
                    description:
                        'Specialist selected automatically when starting a new Copilot thread.',
                    icon: Icons.smart_toy_outlined,
                    control: UiSelect<String>(
                      width: isMobile ? null : 230,
                      value: selectedSpecialistId,
                      options: specialistOptions,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(defaultSpecialistId: val),
                        toastTitle: 'Default Specialist Updated',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Response Depth & Formatting',
                    description:
                        'Control how brief or institutional AI research summaries should be by default.',
                    icon: Icons.format_align_left_rounded,
                    control: UiToggleGroup<String>(
                      expand: isMobile,
                      value: _settings.responseStyle,
                      options: const <UiToggleOption<String>>[
                        UiToggleOption(label: 'Concise', value: 'concise'),
                        UiToggleOption(label: 'Balanced', value: 'balanced'),
                        UiToggleOption(label: 'Detailed', value: 'detailed'),
                      ],
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(responseStyle: val),
                        toastTitle: 'Response Style Saved',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Source Citation Style',
                    description:
                        'Display live research citations inline next to facts or grouped as footnotes.',
                    icon: Icons.format_quote_outlined,
                    control: UiToggleGroup<String>(
                      expand: isMobile,
                      value: _settings.citationsStyle,
                      options: const <UiToggleOption<String>>[
                        UiToggleOption(label: 'Inline links', value: 'inline'),
                        UiToggleOption(label: 'Footnotes', value: 'footnotes'),
                      ],
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(citationsStyle: val),
                        toastTitle: 'Citation Format Saved',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Auto-Attach Workspace Context',
                    description:
                        'Automatically share the active trade journal, strategy, or ticker when opening Copilot.',
                    icon: Icons.link_rounded,
                    control: UiSwitch(
                      value: _settings.autoAttachContext,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(autoAttachContext: val),
                        toastTitle: 'Context Sharing Updated',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Confirm Tool & Computer Actions',
                    description:
                        'Require explicit human approval before executing connected tool mutations or terminal steps.',
                    icon: Icons.verified_user_outlined,
                    control: UiSwitch(
                      value: _settings.requireToolApproval,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(requireToolApproval: val),
                        toastTitle: 'Tool Approval Policy Updated',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Voice Mode Auto-Speak Replies',
                    description:
                        'Automatically read completed voice call responses aloud when audio output is connected.',
                    icon: Icons.record_voice_over_outlined,
                    control: UiSwitch(
                      value: _settings.voiceAutoSpeak,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(voiceAutoSpeak: val),
                        toastTitle: 'Voice Preference Saved',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Share Anonymized Formatting Diagnostics',
                    description:
                        'Help improve structured chart and verdict cards without sharing private trades or notes.',
                    icon: Icons.analytics_outlined,
                    control: UiSwitch(
                      value: _settings.shareAnonymizedUsage,
                      onChanged: (val) => _saveSettings(
                        _settings.copyWith(shareAnonymizedUsage: val),
                        toastTitle: 'Diagnostic Preference Updated',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Memory, Learning & Connected Apps Subpages
              AppSettingsSectionBlock(
                title: 'Memory Library & Connected Tool Servers',
                description:
                    'Manage saved trader preferences, reusable workspace skills, and authorized MCP servers.',
                children: [
                  SettingsNavRow(
                    title: 'Memory & Learning Library',
                    subtitle:
                        'View, edit, or delete saved AI preferences and skills',
                    icon: Icons.psychology_alt_outlined,
                    badgeLabel:
                        '${_copilot.workspace.memories.length} memories',
                    onTap: () => openSettingsSubpage(
                      context,
                      title: 'Memory & Learning Library',
                      subtitle: 'Saved preferences and reusable Copilot skills',
                      icon: Icons.psychology_alt_outlined,
                      page: _CopilotToolSubpage(
                        child: CopilotMemorySettings(
                          controller: _copilot,
                          query: '',
                        ),
                      ),
                    ),
                  ),
                  SettingsNavRow(
                    title: 'Connected Apps & MCP Servers',
                    subtitle: _copilot.workspace.setup['apps'] == true
                        ? 'Configure external MCP endpoints, allowed tools, and Slack integration'
                        : 'In-app Notes, Journal & Watchlist connectors active; external MCP requires COPILOT_API_URL',
                    icon: Icons.hub_outlined,
                    badgeLabel: _copilot.workspace.setup['apps'] == true
                        ? '${_copilot.workspace.connections.length} connected'
                        : (_settings.allowConnectedApps
                              ? 'In-app active'
                              : 'Hosted mode'),
                    onTap: () => openSettingsSubpage(
                      context,
                      title: 'Connected Apps & MCP Servers',
                      subtitle: 'Authorized external tools for AI specialists',
                      icon: Icons.hub_outlined,
                      page: _CopilotToolSubpage(
                        child: CopilotConnections(
                          controller: _copilot,
                          query: '',
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (specialists.isNotEmpty) ...[
                SizedBox(height: context.sp(theme.spacing.lg)),
                AppSettingsSectionBlock(
                  title: 'Specialist Permissions',
                  description:
                      'Control web search, memory, and connected-app permissions per AI specialist.',
                  children: [
                    for (final specialist in specialists)
                      UiCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: context.sp(theme.spacing.sm),
                              runSpacing: context.sp(theme.spacing.xs),
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  specialist.name,
                                  style: context.uiText.bodyStrong,
                                ),
                                if (specialist.role.isNotEmpty)
                                  UiBadge(
                                    label: specialist.role,
                                    size: UiSize.xs,
                                    intent: UiIntent.neutral,
                                  ),
                              ],
                            ),
                            if (specialist.instructions.isNotEmpty) ...[
                              SizedBox(height: context.sp(theme.spacing.xs)),
                              Text(
                                specialist.instructions,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  color: colors.foregroundMuted,
                                ),
                              ),
                            ],
                            SizedBox(height: context.sp(theme.spacing.sm)),
                            Wrap(
                              spacing: context.sp(theme.spacing.md),
                              runSpacing: context.sp(theme.spacing.xs),
                              children: [
                                for (final flag in const [
                                  ('research', 'Web research'),
                                  ('memory', 'Memory'),
                                  ('apps', 'Apps'),
                                  ('learning', 'Learning'),
                                ])
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        flag.$2,
                                        style: context.uiText.caption,
                                      ),
                                      SizedBox(
                                        width: context.sp(theme.spacing.xs),
                                      ),
                                      UiSwitch(
                                        value: _specialistAllows(
                                          specialist,
                                          flag.$1,
                                        ),
                                        onChanged: (val) =>
                                            _toggleSpecialistPermission(
                                              specialist,
                                              flag.$1,
                                              val,
                                            ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CopilotToolSubpage extends StatelessWidget {
  const _CopilotToolSubpage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final double pagePad = context.sp(
      isMobile ? theme.spacing.md : theme.spacing.lg,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        pagePad,
        MediaQuery.paddingOf(context).top + pagePad,
        pagePad,
        isMobile ? context.uiPageBottomInset : pagePad,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: child,
        ),
      ),
    );
  }
}
