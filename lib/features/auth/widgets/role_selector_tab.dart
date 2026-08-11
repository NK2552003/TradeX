import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Role selector switcher for Customer, Affiliate, and User Admin roles.
class RoleSelectorTab extends StatelessWidget {
  const RoleSelectorTab({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final roles = UserRole.values;
    final int selectedIndex = roles.indexOf(selectedRole);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiTabs(
          items: roles.map((r) => UiTabItem(label: '', icon: r.icon)).toList(),
          selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
          variant: UiTabsVariant.segmented,
          size: UiSize.sm,
          density: UiDensity.compact,
          stretch: false,
          onChanged: (idx) {
            if (idx >= 0 && idx < roles.length) {
              onRoleChanged(roles[idx]);
            }
          },
        ),
      ],
    );
  }
}
