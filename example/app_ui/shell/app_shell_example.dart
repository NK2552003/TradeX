import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Interactive showcase view displaying AppShell, AppSidebar, AppBottomDock & AppTopBar.
class AppShellExampleView extends StatefulWidget {
  const AppShellExampleView({super.key});

  @override
  State<AppShellExampleView> createState() => _AppShellExampleViewState();
}

class _AppShellExampleViewState extends State<AppShellExampleView> {
  String _selectedNavId = 'journal';
  String _activeLayoutMode = 'shell'; // 'shell', 'sidebar', 'dock', 'topbar'
  bool _sidebarCollapsed = false;

  final List<AppNavSection> _navSections = const <AppNavSection>[
    AppNavSection(
      title: 'Main Workspace',
      items: <AppNavItem>[
        AppNavItem(id: 'journal', label: 'Trade Journal', icon: Icons.book_outlined),
        AppNavItem(id: 'analytics', label: 'Performance Analytics', icon: Icons.analytics_outlined),
        AppNavItem(id: 'strategies', label: 'Playbook Strategies', icon: Icons.psychology_outlined),
      ],
    ),
    AppNavSection(
      title: 'Community & AI',
      items: <AppNavItem>[
        AppNavItem(id: 'community', label: 'Trader Social Feed', icon: Icons.people_outline, badgeCount: 3),
        AppNavItem(id: 'ai', label: 'AI Copilot Assistant', icon: Icons.auto_awesome_outlined),
      ],
    ),
    AppNavSection(
      title: 'Account Settings',
      items: <AppNavItem>[
        AppNavItem(id: 'settings', label: 'System Settings', icon: Icons.settings_outlined),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppShell & Layout Architecture', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Select a layout view mode below to inspect reusable shell components in action:',
            style: context.uiText.caption,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          
          // Layout Mode Selector Toggles
          UiToggleGroup<String>(
            value: _activeLayoutMode,
            onChanged: (mode) => setState(() => _activeLayoutMode = mode),
            options: const <UiToggleOption<String>>[
              UiToggleOption(value: 'shell', label: 'Adaptive AppShell'),
              UiToggleOption(value: 'sidebar', label: 'Desktop Sidebar'),
              UiToggleOption(value: 'dock', label: 'Mobile Bottom Dock'),
              UiToggleOption(value: 'topbar', label: 'Top Header Bar'),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Render Output Container according to mode
          Container(
            height: 520,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colors.surface,
              borderRadius: context.radius(theme.radii.xl),
              border: Border.all(color: theme.colors.border),
            ),
            child: _buildOutputContainer(context),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputContainer(BuildContext context) {
    final theme = context.ui;

    switch (_activeLayoutMode) {
      case 'sidebar':
        return Row(
          children: <Widget>[
            AppSidebar(
              sections: _navSections,
              selectedId: _selectedNavId,
              collapsed: _sidebarCollapsed,
              onSelect: (id) => setState(() => _selectedNavId = id),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                color: theme.colors.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        UiButton(
                          label: _sidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                          variant: UiVariant.outline,
                          leadingIcon: _sidebarCollapsed ? Icons.menu : Icons.menu_open,
                          onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.lg)),
                    Text('Active Page output for navigation item: "$_selectedNavId"', style: context.uiText.subheading),
                    SizedBox(height: context.sp(theme.spacing.md)),
                    const UiCard(
                      title: 'Sidebar Interactive Preview',
                      subtitle: 'Click navigation items on the left to switch active state.',
                      child: Text('Desktop AppSidebar supports collapsible sections, badge counts, and lock icons.'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case 'dock':
        final flatItems = _navSections.expand((s) => s.items).toList();
        return Scaffold(
          backgroundColor: theme.colors.background,
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Active Dock Tab: "$_selectedNavId"', style: context.uiText.heading),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Text('Mobile Bottom Dock rendered below with active item indicators.', style: context.uiText.caption),
                ],
              ),
            ),
          ),
          bottomNavigationBar: AppBottomDock(
            items: flatItems.take(5).toList(),
            selectedId: _selectedNavId,
            onSelect: (id) => setState(() => _selectedNavId = id),
          ),
        );

      case 'topbar':
        return Scaffold(
          backgroundColor: theme.colors.background,
          body: Column(
            children: <Widget>[
              AppTopBar(
                showLogo: true,
                unread: 4,
                trader: const AppTrader(
                  id: 'u1',
                  handle: '@nitish',
                  displayName: 'Nitish Kumar',
                  tier: AppTier.premium,
                ),
                onSearch: () {},
                onNotifications: () {},
              ),
              Expanded(
                child: Center(
                  child: Text('Top Navigation Bar Header Preview', style: context.uiText.bodyStrong),
                ),
              ),
            ],
          ),
        );

      case 'shell':
      default:
        return AppShell(
          sections: _navSections,
          selectedId: _selectedNavId,
          onSelect: (id) => setState(() => _selectedNavId = id),
          trader: const AppTrader(
            id: 'u1',
            handle: '@nitish',
            displayName: 'Nitish Kumar',
            tier: AppTier.premium,
          ),
          unreadNotifications: 3,
          child: Padding(
            padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Active Section: "$_selectedNavId"', style: context.uiText.heading),
                SizedBox(height: context.sp(theme.spacing.md)),
                AppStatGridBlock(
                  stats: <AppStat>[
                    AppStat(label: 'Total P/L', value: 14250, formatter: (v) => '+\$$v'),
                    AppStat(label: 'Win Rate', value: 74.2, formatter: (v) => '$v%'),
                    const AppStat(label: 'Trades Logged', value: 142),
                  ],
                ),
              ],
            ),
          ),
        );
    }
  }
}
