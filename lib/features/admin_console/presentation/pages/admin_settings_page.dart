import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import '../widgets/admin_access_form.dart';
import '../widgets/admin_action_dialog.dart';
import '../widgets/admin_facts.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key, this.repository});
  final AdminRepository? repository;

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  Map<String, dynamic>? _data;
  Map<String, bool> _savedFeatures = {};
  Map<String, bool> _features = {};
  Map<String, dynamic>? _telemetry;
  String? _error;
  bool _loading = true;

  AdminRepository get _repo => widget.repository ?? AdminRepository.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.settings();
      Map<String, dynamic>? overview;
      try {
        overview = await _repo.overview(days: 7);
      } catch (_) {
        overview = null;
      }
      if (mounted) {
        final mapped = {
          for (final key in adminFeatureLabels.keys)
            key: adminMap(data['features'])[key] != false,
        };
        setState(() {
          _data = data;
          _savedFeatures = Map<String, bool>.from(mapped);
          _features = Map<String, bool>.from(mapped);
          _telemetry = overview;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = adminError(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (await runAdminAction(
      context,
      title: 'Save platform settings',
      description:
          'These feature settings apply to all customer and affiliate accounts.',
      confirmation: 'SAVE',
      submit: (reason) => _repo.apply(
        action: 'settings',
        reason: reason,
        value: {'features': _features},
      ),
    )) {
      await _load();
    }
  }

  List<String> get _changedKeys => [
    for (final key in adminFeatureLabels.keys)
      if (_features[key] != _savedFeatures[key]) key,
  ];

  @override
  Widget build(BuildContext context) => UiPage(
    title: 'App settings',
    subtitle: 'Platform feature availability and administration policy',
    actions: [
      UiButton(
        label: 'Refresh',
        leadingIcon: Icons.refresh,
        variant: UiVariant.outline,
        onPressed: _loading ? null : _load,
      ),
    ],
    child: UiAsyncView<Map<String, dynamic>>(
      loading: _loading,
      error: _error,
      data: _data,
      onRetry: _load,
      dataBuilder: (context, data) {
        final colors = context.ui.colors;
        final enabledCount = _features.values.where((v) => v).length;
        final pausedCount = _features.length - enabledCount;
        final changed = _changedKeys;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiCard(
              variant: UiCardVariant.surface,
              accentColor: changed.isNotEmpty ? colors.warning : colors.success,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live platform surface preview',
                            style: context.uiText.title,
                          ),
                          const UiGap.v(2),
                          Text(
                            changed.isEmpty
                                ? 'All customer and partner switches match saved database policy'
                                : 'Modified: ${changed.map((k) => adminFeatureLabels[k] ?? k).join(', ')}',
                            style: context.uiText.caption,
                          ),
                        ],
                      ),
                      UiBadge(
                        label: changed.isEmpty
                            ? 'Synced'
                            : '${changed.length} unsaved edits',
                        intent: changed.isEmpty
                            ? UiIntent.success
                            : UiIntent.warning,
                      ),
                    ],
                  ),
                  const UiGap.v(14),
                  UiCategoryBar(
                    categories: [
                      UiCategorySegment(
                        label: 'Live features ($enabledCount)',
                        value: enabledCount.toDouble(),
                        color: colors.success,
                      ),
                      UiCategorySegment(
                        label: 'Paused features ($pausedCount)',
                        value: pausedCount.toDouble(),
                        color: colors.danger,
                      ),
                    ],
                  ),
                  if (_telemetry != null) ...[
                    const UiGap.v(14),
                    UiStatStrip(
                      minCellWidth: 140,
                      stats: [
                        UiStat(
                          label: 'Impacted accounts',
                          value: '${_telemetry!['active_accounts'] ?? 0}',
                          hint: 'Active platform users',
                          intent: UiIntent.primary,
                          icon: Icons.people_outline,
                        ),
                        UiStat(
                          label: 'AI requests (7d)',
                          value: '${_telemetry!['ai_requests'] ?? 0}',
                          hint: _features['ai'] == true
                              ? 'AI enabled'
                              : 'AI writes paused',
                          intent: _features['ai'] == true
                              ? UiIntent.success
                              : UiIntent.warning,
                          icon: Icons.auto_awesome_outlined,
                        ),
                        UiStat(
                          label: 'Active partners',
                          value: '${_telemetry!['affiliates'] ?? 0}',
                          hint: _features['affiliate'] == true
                              ? 'Campaigns enabled'
                              : 'Campaign writes paused',
                          intent: _features['affiliate'] == true
                              ? UiIntent.success
                              : UiIntent.warning,
                          icon: Icons.handshake_outlined,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const UiGap.v(20),
            AdminSection(
              title: 'Feature availability',
              description:
                  'Disabled features reject new activity for customer and affiliate accounts. User permissions can further restrict access; they cannot override a disabled platform feature.',
              child: UiCardGrid(
                minTileWidth: 270,
                children: [
                  for (final entry in adminFeatureLabels.entries)
                    UiSwitch(
                      label: entry.value,
                      asCard: true,
                      value: _features[entry.key]!,
                      description: _features[entry.key] == _savedFeatures[entry.key]
                          ? (_features[entry.key]!
                                ? 'Live for active accounts'
                                : 'Blocked across platform')
                          : 'Pending save',
                      onChanged: (value) =>
                          setState(() => _features[entry.key] = value),
                    ),
                ],
              ),
            ),
            const UiGap.v(16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                UiButton(label: 'Save app settings', onPressed: _save),
                if (changed.isNotEmpty)
                  UiButton(
                    label: 'Reset changes',
                    variant: UiVariant.outline,
                    onPressed: () => setState(
                      () => _features = Map<String, bool>.from(_savedFeatures),
                    ),
                  ),
              ],
            ),
            const UiGap.v(20),
            const UiCallout(
              title: 'Community review',
              message:
                  'User posts and comments require approval before public visibility. Content edits reopen review.',
            ),
            const UiGap.v(16),
            const UiCallout(
              title: 'Activity history',
              message:
                  'User record changes, reviews, restrictions and administrator decisions are recorded automatically. Past changes from before tracking began are not reconstructed.',
            ),
            const UiGap.v(12),
            Text(
              'Last updated ${adminDate(data['updated_at'])}',
              style: context.uiText.caption,
            ),
          ],
        );
      },
    ),
  );
}
