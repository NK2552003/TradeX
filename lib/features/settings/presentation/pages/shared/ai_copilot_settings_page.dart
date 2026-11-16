import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/app_session.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/copilot/data/copilot_controller.dart';
import 'package:tradex/features/copilot/models/workspace.dart';
import 'package:tradex/features/copilot/presentation/connection_settings.dart';
import 'package:tradex/features/copilot/presentation/memory_settings.dart';
import 'package:tradex/features/settings/data/repositories/ai_settings_repository.dart';
import 'package:tradex/features/settings/models/ai_settings_model.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

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

  void _onExternalChanged() {
    if (!mounted) return;
    setState(() {
      if (_copilot.connected) {
        _settings = _settings.mergeWorkspaceSettings(
          _copilot.workspace.settings,
        );
      } else {
        _settings = _repo.cachedSettings;
      }
    });
  }

  Future<void> _loadSettings() async {
    final loaded = await _repo.getSettings(copilotController: _copilot);
    if (!mounted) return;
    setState(() {
      _settings = loaded;
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
    if (!mounted || toastTitle == null) return;
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
    if (!mounted) return;
    setState(() {
      _reconnecting = false;
      if (_copilot.connected) {
        _settings = _settings.mergeWorkspaceSettings(
          _copilot.workspace.settings,
        );
      }
    });
    UiToast.show(
      context,
      title: _copilot.connected
          ? 'Copilot Connected'
          : 'Copilot Service Offline',
      message: _copilot.connected
          ? 'Workspace settings and specialists synced.'
          : (_copilot.error ??
                'Changes remain saved locally and will sync when online.'),
      intent: _copilot.connected ? UiIntent.success : UiIntent.warning,
    );
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
      for (final flag in const ['research', 'memory', 'code', 'apps', 'learning'])
        flag: flag == field ? value : _specialistAllows(specialist, flag),
    };
    final res = await _copilot.action(body, refresh: true, reportError: false);
    if (!mounted) return;
    if (res == null) {
      specialist.json[field] = value;
      setState(() {});
    }
    UiToast.show(
      context,
      title: '${specialist.name} Updated',
      message:
          '${_permissionLabel(field)} ${value ? 'enabled' : 'disabled'} for ${specialist.name}.',
      intent: UiIntent.info,
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(isMobile ? theme.spacing.md : theme.spacing.lg),
        context.sp(isMobile ? theme.spacing.md : theme.spacing.lg),
        context.sp(isMobile ? theme.spacing.md : theme.spacing.lg),
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
                                  label: _copilot.connected
                                      ? 'Connected'
                                      : 'Local Sync',
                                  intent: _copilot.connected
                                      ? UiIntent.success
                                      : UiIntent.neutral,
                                  size: UiSize.xs,
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: context.sp(theme.spacing.xs),
                              runSpacing: context.sp(theme.spacing.xs),
                              children: [
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
                                    ? 'Connected to encrypted Copilot workspace. Settings apply across all devices.'
                                    : 'Preferences save immediately on this device and sync to cloud workspace when connected.'),
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
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
                        UiToggleOption(
                          label: 'Footnotes',
                          value: 'footnotes',
                        ),
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
                    subtitle:
                        'Configure external MCP endpoints, allowed tools, and Slack integration',
                    icon: Icons.hub_outlined,
                    badgeLabel:
                        '${_copilot.workspace.connections.length} connected',
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
    return Padding(
      padding: EdgeInsets.all(
        context.sp(isMobile ? theme.spacing.md : theme.spacing.lg),
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
