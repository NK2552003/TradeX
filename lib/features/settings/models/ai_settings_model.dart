import 'package:flutter/foundation.dart';

/// Unified AI & Copilot settings consolidated into Settings -> AI & Copilot.
@immutable
class AiSettingsModel {
  const AiSettingsModel({
    this.appearance = 'system',
    this.paused = false,
    this.allowWebResearch = true,
    this.allowMemory = true,
    this.allowConnectedApps = true,
    this.defaultSpecialistId = 'analyst',
    this.responseStyle = 'balanced',
    this.citationsStyle = 'inline',
    this.autoAttachContext = true,
    this.requireToolApproval = true,
    this.voiceAutoSpeak = false,
    this.shareAnonymizedUsage = false,
  });

  /// Theme override for the Copilot panel: `'system'`, `'light'`, or `'dark'`.
  final String appearance;

  /// Pauses background copilot runs and scheduled AI tasks when enabled.
  final bool paused;

  /// Allows Copilot specialists to use live web search and cite URLs.
  final bool allowWebResearch;

  /// Allows Copilot to remember saved trader preferences across threads.
  final bool allowMemory;

  /// Allows Copilot to invoke enabled MCP servers & connected tools.
  final bool allowConnectedApps;

  /// Default specialist id (`'analyst'`, `'coach'`, `'writer'`).
  final String defaultSpecialistId;

  /// Output verbosity style: `'concise'`, `'balanced'`, or `'detailed'`.
  final String responseStyle;

  /// Source link presentation: `'inline'` or `'footnotes'`.
  final String citationsStyle;

  /// Automatically attach currently open journal/strategy/ticker context.
  final bool autoAttachContext;

  /// Always prompt before running tool or isolated computer actions.
  final bool requireToolApproval;

  /// Read finalized assistant responses aloud in voice sessions.
  final bool voiceAutoSpeak;

  /// Opt-in telemetry toggle for improving research answer formatting.
  final bool shareAnonymizedUsage;

  AiSettingsModel copyWith({
    String? appearance,
    bool? paused,
    bool? allowWebResearch,
    bool? allowMemory,
    bool? allowConnectedApps,
    String? defaultSpecialistId,
    String? responseStyle,
    String? citationsStyle,
    bool? autoAttachContext,
    bool? requireToolApproval,
    bool? voiceAutoSpeak,
    bool? shareAnonymizedUsage,
  }) {
    return AiSettingsModel(
      appearance: appearance ?? this.appearance,
      paused: paused ?? this.paused,
      allowWebResearch: allowWebResearch ?? this.allowWebResearch,
      allowMemory: allowMemory ?? this.allowMemory,
      allowConnectedApps: allowConnectedApps ?? this.allowConnectedApps,
      defaultSpecialistId: defaultSpecialistId ?? this.defaultSpecialistId,
      responseStyle: responseStyle ?? this.responseStyle,
      citationsStyle: citationsStyle ?? this.citationsStyle,
      autoAttachContext: autoAttachContext ?? this.autoAttachContext,
      requireToolApproval: requireToolApproval ?? this.requireToolApproval,
      voiceAutoSpeak: voiceAutoSpeak ?? this.voiceAutoSpeak,
      shareAnonymizedUsage: shareAnonymizedUsage ?? this.shareAnonymizedUsage,
    );
  }

  /// Merges workspace `settings` map (`paused`, `research`, `memory`, `apps`, etc.)
  /// on top of existing settings.
  AiSettingsModel mergeWorkspaceSettings(Map<String, dynamic> workspace) {
    final String rawAppearance = (workspace['appearance'] ?? '').toString();
    final String rawSpec =
        (workspace['defaultSpecialistId'] ?? '').toString().trim();
    final String rawStyle =
        (workspace['responseStyle'] ?? '').toString().trim();
    final String rawCitations =
        (workspace['citationsStyle'] ?? '').toString().trim();

    return copyWith(
      appearance: ['system', 'light', 'dark'].contains(rawAppearance)
          ? rawAppearance
          : null,
      paused: workspace.containsKey('paused')
          ? workspace['paused'] == true
          : null,
      allowWebResearch: workspace.containsKey('research')
          ? workspace['research'] == true
          : null,
      allowMemory: workspace.containsKey('memory')
          ? workspace['memory'] == true
          : null,
      allowConnectedApps: workspace.containsKey('apps')
          ? workspace['apps'] == true
          : null,
      defaultSpecialistId: rawSpec.isNotEmpty ? rawSpec : null,
      responseStyle:
          ['concise', 'balanced', 'detailed'].contains(rawStyle)
              ? rawStyle
              : null,
      citationsStyle: ['inline', 'footnotes'].contains(rawCitations)
          ? rawCitations
          : null,
      autoAttachContext: workspace.containsKey('autoAttachContext')
          ? workspace['autoAttachContext'] == true
          : null,
      requireToolApproval: workspace.containsKey('requireToolApproval')
          ? workspace['requireToolApproval'] == true
          : null,
      voiceAutoSpeak: workspace.containsKey('voiceAutoSpeak')
          ? workspace['voiceAutoSpeak'] == true
          : null,
    );
  }

  /// Payload shape matching `copilot_workspaces.state.settings` & `settings.save`.
  Map<String, dynamic> toWorkspaceSettingsPayload() => <String, dynamic>{
    'appearance': appearance,
    'paused': paused,
    'research': allowWebResearch,
    'memory': allowMemory,
    'apps': allowConnectedApps,
    'defaultSpecialistId': defaultSpecialistId,
    'responseStyle': responseStyle,
    'citationsStyle': citationsStyle,
    'autoAttachContext': autoAttachContext,
    'requireToolApproval': requireToolApproval,
    'voiceAutoSpeak': voiceAutoSpeak,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...toWorkspaceSettingsPayload(),
    'shareAnonymizedUsage': shareAnonymizedUsage,
  };

  factory AiSettingsModel.fromJson(Map<String, dynamic> json) {
    final String app = (json['appearance'] ?? 'system').toString();
    final String style = (json['responseStyle'] ?? 'balanced').toString();
    final String cite = (json['citationsStyle'] ?? 'inline').toString();
    return AiSettingsModel(
      appearance: ['system', 'light', 'dark'].contains(app) ? app : 'system',
      paused: json['paused'] == true,
      allowWebResearch: json['research'] as bool? ?? json['allowWebResearch'] as bool? ?? true,
      allowMemory: json['memory'] as bool? ?? json['allowMemory'] as bool? ?? true,
      allowConnectedApps: json['apps'] as bool? ?? json['allowConnectedApps'] as bool? ?? true,
      defaultSpecialistId:
          ((json['defaultSpecialistId'] as String?)?.trim().isNotEmpty ?? false)
              ? (json['defaultSpecialistId'] as String).trim()
              : 'analyst',
      responseStyle: ['concise', 'balanced', 'detailed'].contains(style)
          ? style
          : 'balanced',
      citationsStyle: ['inline', 'footnotes'].contains(cite)
          ? cite
          : 'inline',
      autoAttachContext: json['autoAttachContext'] as bool? ?? true,
      requireToolApproval: json['requireToolApproval'] as bool? ?? true,
      voiceAutoSpeak: json['voiceAutoSpeak'] as bool? ?? false,
      shareAnonymizedUsage: json['shareAnonymizedUsage'] as bool? ?? false,
    );
  }
}
