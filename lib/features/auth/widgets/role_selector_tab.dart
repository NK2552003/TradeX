import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Role selector switcher. Public signup passes customer + affiliate only;
/// sign-in can still expose administrator access for provisioned accounts.
class RoleSelectorTab extends StatelessWidget {
  const RoleSelectorTab({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
    this.roles = UserRole.values,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleChanged;
  final List<UserRole> roles;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final int selectedIndex = roles.indexOf(selectedRole);

    final uiTabs = UiTabs(
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
    );

    return IntrinsicWidth(
      child: Stack(
        children: [
          // Background layer: Bulletin (painted first)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Invisible spacer to push the bulletin down
              Opacity(opacity: 0.0, child: uiTabs),
              Transform.translate(
                offset: const Offset(0, -10),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.only(
                    top: context.sp(theme.spacing.xxs) + 10,
                    bottom: context.sp(theme.spacing.xxs),
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.vertical(
                      bottom: context.radius(theme.radii.md).bottomLeft,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: theme.motion.fast,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.5),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      selectedRole.shortTitle,
                      key: ValueKey(selectedRole.id),
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Foreground layer: UiTabs (painted on top, hides the top border of the bulletin)
          uiTabs,
        ],
      ),
    );
  }
}
