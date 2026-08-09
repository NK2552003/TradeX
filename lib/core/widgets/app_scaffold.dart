import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/core/showcase/numbered_component_showcase_page.dart';
import 'package:tradex/features/journal/presentation/pages/journal_page.dart';
import 'package:tradex/features/portfolio/presentation/pages/portfolio_page.dart';
import 'package:tradex/features/watchlists/presentation/pages/watchlists_page.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  String _selectedId = 'journal';

  static const List<AppNavSection> _navSections = <AppNavSection>[
    AppNavSection(
      title: 'Trading Platform',
      items: <AppNavItem>[
        AppNavItem(
          id: 'journal',
          label: 'Trade Journal',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          subItems: <AppNavItem>[
            AppNavItem(id: 'journal_overview', label: 'Overview', icon: Icons.grid_view_outlined),
            AppNavItem(id: 'journal_analytics', label: 'Analytics', icon: Icons.analytics_outlined),
          ],
        ),
        AppNavItem(
          id: 'watchlists',
          label: 'Watchlists',
          icon: Icons.visibility_outlined,
          selectedIcon: Icons.visibility,
        ),
        AppNavItem(
          id: 'portfolio',
          label: 'Portfolio Dashboard',
          icon: Icons.pie_chart_outline,
          selectedIcon: Icons.pie_chart,
        ),
        AppNavItem(
          id: 'scanner',
          label: 'Market Scanner',
          icon: Icons.candlestick_chart_outlined,
          selectedIcon: Icons.candlestick_chart,
        ),
      ],
    ),
    AppNavSection(
      title: 'Strategies & AI',
      items: <AppNavItem>[
        AppNavItem(
          id: 'strategies',
          label: 'Strategy Playbooks',
          icon: Icons.auto_stories_outlined,
          selectedIcon: Icons.auto_stories,
          subItems: <AppNavItem>[
            AppNavItem(id: 'strategies_list', label: 'Playbook List', icon: Icons.format_list_bulleted_outlined),
            AppNavItem(id: 'strategies_analyzer', label: 'Strategy Analyzer', icon: Icons.insights_outlined),
            AppNavItem(id: 'strategies_graph', label: 'Graph View', icon: Icons.hub_outlined),
          ],
        ),
        AppNavItem(
          id: 'ai_assistant',
          label: 'AI Trading Assistant',
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome,
          subItems: <AppNavItem>[
            AppNavItem(id: 'ai_digest', label: 'Daily Digest', icon: Icons.article_outlined),
            AppNavItem(id: 'ai_review', label: 'Performance Review', icon: Icons.rate_review_outlined),
          ],
        ),
      ],
    ),
    AppNavSection(
      title: 'Community & Messages',
      items: <AppNavItem>[
        AppNavItem(
          id: 'community',
          label: 'Community Feed',
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum,
        ),
        AppNavItem(
          id: 'messages',
          label: 'Direct Messages',
          icon: Icons.mark_chat_read_outlined,
          selectedIcon: Icons.mark_chat_read,
          badgeCount: 2,
        ),
      ],
    ),
    AppNavSection(
      title: 'System & Showcase',
      items: <AppNavItem>[
        AppNavItem(
          id: 'showcase',
          label: 'UI Showcase (133)',
          icon: Icons.grid_view_rounded,
          selectedIcon: Icons.grid_view_rounded,
          subItems: <AppNavItem>[
            AppNavItem(id: 'showcase_foundation', label: 'Foundation Actions', icon: Icons.widgets_outlined),
            AppNavItem(id: 'showcase_inputs', label: 'Form Inputs', icon: Icons.input_outlined),
            AppNavItem(id: 'showcase_selection', label: 'Selection & Nav', icon: Icons.check_box_outlined),
            AppNavItem(id: 'showcase_charts', label: 'Charts & Data', icon: Icons.bar_chart_outlined),
            AppNavItem(id: 'showcase_layout', label: 'Layout Primitives', icon: Icons.dashboard_customize_outlined),
            AppNavItem(id: 'showcase_overlays', label: 'Overlays & Feedback', icon: Icons.layers_outlined),
            AppNavItem(id: 'showcase_cards', label: 'Domain Cards', icon: Icons.subtitles_outlined),
            AppNavItem(id: 'showcase_blocks', label: 'Screen Blocks', icon: Icons.view_quilt_outlined),
          ],
        ),
      ],
    ),
    AppNavSection(
      title: 'Enterprise & Admin',
      items: <AppNavItem>[
        AppNavItem(
          id: 'org_team',
          label: 'Team & Risk',
          icon: Icons.corporate_fare_outlined,
          tierLocked: true,
        ),
        AppNavItem(
          id: 'org_audit',
          label: 'Audit & Compliance',
          icon: Icons.shield_outlined,
          tierLocked: true,
        ),
      ],
    ),
  ];

  Widget _buildActivePage() {
    switch (_selectedId) {
      case 'watchlists':
      case 'scanner':
        return const WatchlistsPage();
      case 'portfolio':
        return const PortfolioPage();
      case 'showcase':
      case 'showcase_foundation':
      case 'showcase_inputs':
      case 'showcase_selection':
      case 'showcase_charts':
      case 'showcase_layout':
      case 'showcase_overlays':
      case 'showcase_cards':
      case 'showcase_blocks':
        return NumberedComponentShowcasePage(selectedId: _selectedId);
      case 'journal':
      case 'journal_overview':
      case 'journal_analytics':
      case 'strategies':
      case 'strategies_list':
      case 'strategies_analyzer':
      case 'strategies_graph':
      case 'ai_assistant':
      case 'ai_digest':
      case 'ai_review':
      case 'community':
      case 'messages':
      case 'org_team':
      case 'org_audit':
      default:
        return const JournalPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      key: const ValueKey<String>(AppConstants.appName),
      sections: _navSections,
      selectedId: _selectedId,
      onSelect: (id) => setState(() => _selectedId = id),
      trader: const AppTrader(
        id: 'u1',
        handle: 'nitish@tradex.ai',
        displayName: 'Nitish Kumar',
        tier: AppTier.premium,
      ),
      unreadNotifications: 4,
      child: _buildActivePage(),
    );
  }
}
