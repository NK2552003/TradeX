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
  Map<String, bool> _features = {};
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
      if (mounted) {
        setState(() {
          _data = data;
          _features = {
            for (final key in adminFeatureLabels.keys)
              key: adminMap(data['features'])[key] != false,
          };
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

  @override
  Widget build(BuildContext context) => UiPage(
    title: 'App settings',
    subtitle: 'Platform feature availability and administration policy',
    child: UiAsyncView<Map<String, dynamic>>(
      loading: _loading,
      error: _error,
      data: _data,
      onRetry: _load,
      dataBuilder: (context, data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    onChanged: (value) =>
                        setState(() => _features[entry.key] = value),
                  ),
              ],
            ),
          ),
          const UiGap.v(16),
          UiButton(label: 'Save app settings', onPressed: _save),
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
      ),
    ),
  );
}
