import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/data/session_trader.dart';
// Required unified primitive import for application layouts.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/features/affiliate_program/affiliate_program.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_marketing_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_overview_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_referrals_page.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/calculators/ui/calculators_screen.dart';
import 'package:tradex/features/journal/ui/journal_screen.dart';
import 'package:tradex/features/notes/ui/notes_screen.dart';


import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';
import 'package:tradex/features/strategies/ui/strategies_screen.dart';

/// The signed-in application shell: chrome, navigation and the active page.
///
/// Everything role-specific is a lookup rather than a branch — the sidebar comes
/// from [RoleNavigationConfig], the plan from [AppSession] and the identity from
/// the profile repository — so adding a destination never means editing three
/// places that can disagree.
class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    this.userRole = UserRole.customer,
    this.userEmail = '',
    this.onLogout,
    this.onRoleChanged,
    this.onReturnToAuth,
    this.showDevelopmentRoleSwitcher = false,
    this.subscriptionTier = AppTier.free,
    this.userId = '',
    this.userDisplayName = '',
    this.initialDestination = 'overview',
  });

  final UserRole userRole;
  final String initialDestination;

  /// Identity handed down by the auth layer. All three default to empty rather
  /// than to a stand-in name: the chrome falls back to the profile repository,
  /// so an unset value shows the seeded demo identity instead of a fictional
  /// person baked into the shell.
  final String userEmail;
  final VoidCallback? onLogout;
  final ValueChanged<UserRole>? onRoleChanged;
  final VoidCallback? onReturnToAuth;
  final bool showDevelopmentRoleSwitcher;
  final AppTier subscriptionTier;
  final String userId;
  final String userDisplayName;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  /// Surfaces the shell owns rather than the sidebar. They are reached from the
  /// top bar, so no role lists them and [RoleNavigationConfig.allows] would
  /// refuse them — which is exactly the bug this set exists to prevent.
  static const Map<String, String> _shellDestinations = <String, String>{
    'notifications': 'Notifications',
    'search': 'Search',
    'affiliate_application': 'Affiliate Application',
  };

  final AppSession _session = AppSession.instance;
  final ProfileSettingsRepository _profiles = ProfileSettingsRepositoryImpl();

  String _selectedId = 'overview';
  AppTrader? _identity;
  int _unread = 0;
  bool _showAffiliateApplication = false;
  AffiliateApplicationStatus? _affiliateApplicationStatus;

  UserRole? _previewRoleOverride;
  UserRole get _effectiveRole => _previewRoleOverride ?? widget.userRole;

  RoleNavigationConfig get _navigation =>
      RoleNavigationConfig.forRole(_effectiveRole);

  @override
  void initState() {
    super.initState();
    if (_navigation.allows(widget.initialDestination)) {
      _selectedId = widget.initialDestination;
    }
    // The plan arrives with the profile but every gate in the app reads it from
    // the session, so the session adopts it here. That makes entitlement
    // single-owner: upgrading in billing unlocks DMs and copilot credits in the
    // same frame instead of leaving each surface with its own stale copy.
    _session.changeTier(widget.subscriptionTier);
    // Painted from the cached profile on the first frame so the avatar, handle
    // and sidebar footer are never blank, then refreshed from the repository.
    _identity = appTraderFromProfile(_profiles.cachedProfile);
    _loadIdentity();
    _loadUnread();
    _loadAffiliateApplicationStatus();
  }

  @override
  void didUpdateWidget(AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userRole != widget.userRole) {
      _previewRoleOverride = widget.userRole;
      _resetToOverview();
      _loadAffiliateApplicationStatus();
    }
    if (oldWidget.subscriptionTier != widget.subscriptionTier) {
      _session.changeTier(widget.subscriptionTier);
    }
    if (oldWidget.userId != widget.userId ||
        oldWidget.userEmail != widget.userEmail) {
      _loadIdentity();
    }
  }

  Future<void> _loadIdentity() async {
    final UserProfileModel profile = await _profiles.getProfile();
    if (!mounted) return;
    setState(() => _identity = appTraderFromProfile(profile));
  }

  Future<void> _loadUnread() async {
    if (!mounted) return;
    setState(() => _unread = 0);
  }

  Future<void> _loadAffiliateApplicationStatus() async {
    final AffiliateApplicationModel? application =
        await AffiliateApplicationRepositoryImpl.instance.getForUser(
          widget.userId,
        );
    if (!mounted) return;
    setState(() => _affiliateApplicationStatus = application?.status);
  }

  /// Identity for the chrome: who from the profile, which plan from the session.
  /// Until the profile lands the fields fall back to the values the shell was
  /// handed, so the avatar and menu never show someone who does not exist.
  /// Identity for the chrome. The profile the repository returned wins, then
  /// whatever the auth layer handed down, so a field the backend has not filled
  /// in yet still shows something true rather than a blank. The tier always
  /// comes from the session — the profile copy of it is advisory.
  AppTrader get _chromeIdentity {
    final AppTrader? profile = _identity;
    String pick(String? fromProfile, String fromWidget) {
      final String owned = (fromProfile ?? '').trim();
      if (owned.isNotEmpty) return owned;
      return fromWidget.trim();
    }

    return AppTrader(
      id: pick(profile?.id, widget.userId),
      handle: pick(profile?.handle, widget.userEmail),
      displayName: pick(profile?.displayName, widget.userDisplayName),
      avatarUrl: profile?.avatarUrl,
      bio: profile?.bio,
      tier: _session.tier.value,
      followers: profile?.followers ?? 0,
      following: profile?.following ?? 0,
      winRate: profile?.winRate,
      verified: profile?.verified ?? false,
      tradingStyle: profile?.tradingStyle,
    );
  }

  String? _activeSubpageTitle;
  IconData? _activeSubpageIcon;
  VoidCallback? _activeSubpageOnBack;

  void _onSubpageChanged(String? title, IconData? icon, VoidCallback? onBack) {
    if (!mounted) return;
    setState(() {
      _activeSubpageTitle = title;
      _activeSubpageIcon = icon;
      _activeSubpageOnBack = onBack;
    });
  }

  /// Sends the reader home and forgets every pending deep link. Written without
  /// [setState] because the only caller is [didUpdateWidget], where a rebuild is
  /// already on the way.
  void _resetToOverview() {
    _selectedId = 'overview';
    _showAffiliateApplication = false;
    _activeSubpageTitle = null;
    _activeSubpageIcon = null;
    _activeSubpageOnBack = null;
    _linkRequest = null;
  }

  void _switchRole(UserRole role) {
    setState(() {
      _previewRoleOverride = role;
      _resetToOverview();
    });
    _loadAffiliateApplicationStatus();
    widget.onRoleChanged?.call(role);
  }

  bool _canReach(String id) =>
      _shellDestinations.containsKey(id) || _navigation.allows(id);

  void _openAffiliateApplication() {
    setState(() {
      _showAffiliateApplication = true;
      _activeSubpageTitle = null;
      _activeSubpageIcon = null;
      _activeSubpageOnBack = null;
    });
  }

  /// The one way a destination changes.
  void _go(String id) {
    if (!_canReach(id)) return;
    setState(() {
      _selectedId = id;
      _showAffiliateApplication = id == 'affiliate_application';
      _activeSubpageTitle = null;
      _activeSubpageIcon = null;
      _activeSubpageOnBack = null;
      // Cleared, or walking back to a destination by hand would re-open the
      // record a link sent the reader to an hour ago: the screens apply their
      // request in `initState`, and a remount cannot tell a fresh one from a
      // spent one.
      _linkRequest = null;
    });
  }

  /// A handler for a destination, or null when this role cannot reach it — so a
  /// cross-link renders as absent rather than as a button that does nothing.
  VoidCallback? _jump(String id) => _canReach(id) ? () => _go(id) : null;

  /// The record a linked destination should open on arrival, and the counter
  /// that makes two clicks on the same link two distinct requests.
  ///
  /// The shell holds this rather than the screens because a link is followed
  /// *across* destinations: the note being clicked is unmounted a frame later,
  /// and the journal that must show its trade has not been built yet.
  AppLinkOpenRequest? _linkRequest;
  int _linkSeq = 0;

  /// Follows a link from one destination into another.
  ///
  /// Role permissions still govern the destination. Writing screens handle
  /// same-kind links locally; ticker links arrive at the matching Markets detail.
  void _openLinkRef(AppLinkRef ref, {bool writing = false}) {
    final String? destination = writing ? 'notes' : ref.kind.destinationId;
    if (destination == null || !_canReach(destination)) return;
    setState(() {
      _selectedId = destination;
      _showAffiliateApplication = false;
      _activeSubpageTitle = null;
      _activeSubpageIcon = null;
      _activeSubpageOnBack = null;
      _linkRequest = AppLinkOpenRequest(
        kind: ref.kind,
        id: ref.id,
        seq: ++_linkSeq,
        editWriting: writing,
      );
    });
  }

  /// Breadcrumb leaf when the active surface has no sidebar entry to name it.
  String? get _pageTitleOverride => _showAffiliateApplication
      ? 'Affiliate application'
      : _activeSubpageTitle ?? _shellDestinations[_selectedId];

  IconData? get _pageIconOverride =>
      _showAffiliateApplication ? Icons.handshake_outlined : _activeSubpageIcon;

  VoidCallback? get _pageBackOverride => _showAffiliateApplication
      ? () => setState(() => _showAffiliateApplication = false)
      : _activeSubpageOnBack;

  Widget _buildActivePage() {
    if (_showAffiliateApplication) return _affiliateApplicationPage();
    if (_selectedId == 'search') return _searchPage();
    if (_selectedId == 'notifications') return _notificationsPage();
    if (_selectedId.startsWith('settings')) return _settingsPage();

    return switch (_effectiveRole) {
      UserRole.customer => _traderPage(),
      UserRole.affiliate => _affiliatePage(),
      UserRole.userAdmin => _adminPage(),
    };
  }

  Widget _affiliateApplicationPage() => AffiliateApplicationPage(
    key: const ValueKey<String>('affiliate_application_page'),
    userId: widget.userId.isNotEmpty
        ? widget.userId
        : (_chromeIdentity.id.isNotEmpty
              ? _chromeIdentity.id
              : 'usr_preview_trader'),
    email: widget.userEmail.isNotEmpty
        ? widget.userEmail
        : (_chromeIdentity.handle.isNotEmpty
              ? _chromeIdentity.handle
              : 'trader@tradex.ai'),
    displayName: widget.userDisplayName.isNotEmpty
        ? widget.userDisplayName
        : ((_chromeIdentity.displayName?.isNotEmpty ?? false)
              ? _chromeIdentity.displayName!
              : 'Pro Trader'),
    isExistingCustomer: true,
    onSubmitted: (AffiliateApplicationModel application) =>
        setState(() => _affiliateApplicationStatus = application.status),
    onCancel: () => setState(() => _showAffiliateApplication = false),
    onDone: () {
      setState(() => _showAffiliateApplication = false);
      _go('settings_profile');
    },
  );

  Widget _placeholderPage(String title, String description, IconData icon) =>
      AppPageBlock(
        title: title,
        subtitle: '$title Surface',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: UiEmptyState(icon: icon, title: title, message: description),
          ),
        ),
      );

  Widget _searchPage() => UiSkeleton.search();

  Widget _notificationsPage() => UiSkeleton.notifications();

  /// Loading shape for a destination the reader has not arrived at yet.
  ///
  /// The phone shell shows this in the dock slots either side of the live one,
  /// so a swipe reveals the next screen taking shape instead of a second copy of
  /// the one being dragged away.
  Widget _destinationSkeleton(String id) {
    // Settings is two different shapes: the bare `settings` slot is the grouped
    // drill-in list, while `settings_<section>` lands straight on a detail form.
    // Showing the overview shape for a section would rearrange itself the moment
    // the real page arrived.
    if (id == 'settings') return UiSkeleton.settings();
    if (id.startsWith('settings_')) {
      final String section = id.replaceFirst('settings_', '');
      return switch (section) {
        'profile' => UiSkeleton.settingsDetail(showIdentity: true, sections: 3),
        'organization' => UiSkeleton.settingsDetail(
          showIdentity: true,
          sections: 2,
        ),
        'billing' => UiSkeleton.settingsList(
          showSummary: true,
          showHeader: false,
          rows: 3,
        ),
        _ => UiSkeleton.settingsDetail(sections: 3),
      };
    }
    return switch (id) {
      'overview' => UiSkeleton.dashboard(),
      'journal' => UiSkeleton.journal(),
      // No notes preset in flutter-ui, and adding one there for a single caller
      // would be the wrong layer: the journal list is the same shape.
      'notes' => UiSkeleton.journal(),
      'strategies' => UiSkeleton.strategies(),
      'watchlists' => UiSkeleton.watchlists(),
      // The hub is a filter bar over a card grid, which is the watchlist shape
      // too — close enough that nothing jumps when the real page lands.
      'calculators' => UiSkeleton.watchlists(),
      'portfolio' => UiSkeleton.portfolio(),
      'community' => UiSkeleton.community(),
      'messages' => UiSkeleton.messages(),
      'ai_copilot' => UiSkeleton.ai(),
      'notifications' => UiSkeleton.notifications(),
      'search' => UiSkeleton.search(),
      'referrals' || 'payouts' || 'marketing' => UiSkeleton.dashboard(),
      _ => UiSkeleton.page(),
    };
  }

  Widget _settingsPage() {
    final String sectionId = _selectedId == 'settings'
        ? 'profile'
        : _selectedId.replaceFirst('settings_', '');
    return SettingsRootPage(
      key: ValueKey<String>('settings_${_effectiveRole.id}_$sectionId'),
      userRole: _effectiveRole,
      initialSectionId: sectionId,
      showNavigationPane: context.uiRes.isMobile && _selectedId == 'settings',
      onLogout: widget.onLogout,
      subscriptionTier: _session.tier.value,
      // Straight into the session: billing is not allowed a private copy of the
      // plan, or the gates elsewhere would stay shut after an upgrade.
      onSubscriptionTierChanged: _session.changeTier,
      onApplyForAffiliate: _openAffiliateApplication,
      onSubpageChanged: _onSubpageChanged,
    );
  }

  Widget _traderPage() => switch (_selectedId) {
    'overview' => UiSkeleton.dashboard(),
    // The three linked writing surfaces. Each is handed the same three
    // affordances so a link followed out of one lands correctly in the next:
    // `onOpenRef` to leave, `openRequest` to arrive, and — for the two that put
    // a document behind a real back step on a phone — `onSubpageChanged` so the
    // app bar names what is open.
    'journal' => JournalScreen(
      onSubpageChanged: _onSubpageChanged,
      onOpenRef: _openLinkRef,
      onOpenWriting: (ref) => _openLinkRef(ref, writing: true),
      openRequest: _linkRequest,
    ),
    'notes' => NotesScreen(onOpenRef: _openLinkRef, openRequest: _linkRequest),
    'strategies' => StrategiesScreen(
      onSubpageChanged: _onSubpageChanged,
      onOpenRef: _openLinkRef,
      onOpenWriting: (ref) => _openLinkRef(ref, writing: true),
      openRequest: _linkRequest,
    ),

    'calculators' => CalculatorsScreen(onSubpageChanged: _onSubpageChanged),
    'portfolio' => UiSkeleton.portfolio(),
    'community' => UiSkeleton.community(),
    'messages' => UiSkeleton.messages(),
    'ai_copilot' => UiSkeleton.ai(),
    _ => _unknownPage(),
  };

  Widget _affiliatePage() => switch (_selectedId) {
    'notes' => const NotesScreen(),
    'overview' => AffiliateOverviewPage(
      onOpenReferrals: _jump('referrals'),
      onOpenPayouts: _jump('payouts'),
      onOpenMarketing: _jump('marketing'),
    ),
    'referrals' => AffiliateReferralsPage(
      onOpenPayouts: _jump('payouts'),
      onOpenMarketing: _jump('marketing'),
    ),
    'marketing' => AffiliateMarketingPage(
      onOpenReferrals: _jump('referrals'),
      onOpenPayouts: _jump('payouts'),
    ),
    'payouts' => AffiliatePayoutsPage(
      onOpenReferrals: _jump('referrals'),
      onOpenSettings: _jump('settings_affiliate'),
    ),
    'community' => _placeholderPage(
      'Community',
      'This screen will feature affiliate partner forums and leaderboards.',
      Icons.groups_outlined,
    ),
    'messages' => _placeholderPage(
      'Messages',
      'This screen will provide direct communication channels with your affiliate manager.',
      Icons.chat_bubble_outline_rounded,
    ),
    'ai_copilot' => _placeholderPage(
      'AI Assistant',
      'This screen will provide AI-powered marketing copy generation and conversion tips.',
      Icons.auto_awesome_outlined,
    ),
    _ => _unknownPage(),
  };

  Widget _adminPage() => switch (_selectedId) {
    'notes' => const NotesScreen(),
    'overview' => _placeholderPage(
      'Desk Overview',
      'This screen will display the trading firm executive summary and risk metrics.',
      Icons.business_outlined,
    ),
    'org_team' => _placeholderPage(
      'Team & Seats',
      'This screen will manage trader seats, account provisioning, and role assignments.',
      Icons.badge_outlined,
    ),
    'org_risk' => _placeholderPage(
      'Risk Management',
      'This screen will enforce margin rules, daily loss caps, and max position limits.',
      Icons.shield_outlined,
    ),
    'org_audit' => _placeholderPage(
      'Audit Log',
      'This screen will track compliance logs, trade modifications, and login events.',
      Icons.history_rounded,
    ),
    'org_analytics' => _placeholderPage(
      'Analytics',
      'This screen will aggregate firm-wide P&L, Sharpe ratios, and trader scorecards.',
      Icons.analytics_outlined,
    ),
    'affiliate_reviews' => const AffiliateApprovalsPage(),
    'ai_copilot' => _placeholderPage(
      'AI Assistant',
      'This screen will analyze organizational risk patterns and trader compliance.',
      Icons.auto_awesome_outlined,
    ),
    _ => _unknownPage(),
  };

  /// Reached only if a destination is added to the sidebar before it has a page.
  /// Saying so beats a blank pane that looks like a loading failure.
  Widget _unknownPage() => AppPageBlock(
    title: _navigation.labelFor(_selectedId) ?? 'Not available',
    subtitle:
        'This surface is not part of the ${_effectiveRole.label} '
        'workspace yet',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: UiEmptyState(
          icon: Icons.construction_rounded,
          title: 'Nothing here yet',
          message:
              'The navigation lists this destination but no page answers it. Pick '
              'another item from the sidebar.',
          action: UiButton(
            label: 'Back to ${_navigation.labelFor('overview') ?? 'the start'}',
            leadingIcon: Icons.arrow_back_rounded,
            variant: UiVariant.outline,
            onPressed: _jump('overview'),
          ),
        ),
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // Prototype chrome
  // -------------------------------------------------------------------------

  Widget _buildDesktopPreviewControls() {
    final bool isAffiliate = _effectiveRole == UserRole.affiliate;
    final bool isPending =
        _affiliateApplicationStatus == AffiliateApplicationStatus.pending;
    final bool isApproved =
        _affiliateApplicationStatus == AffiliateApplicationStatus.approved;
    final bool isAdmin = _effectiveRole == UserRole.userAdmin;
    return UiCard(
      padding: EdgeInsets.all(context.sp(context.ui.spacing.xs)),
      variant: UiCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'DESIGN PREVIEW',
            style: context.uiText.caption.copyWith(
              color: context.ui.colors.foregroundSubtle,
              fontSize: context.fs(9),
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: context.sp(context.ui.spacing.xxs)),
          if (!isAdmin)
            UiButton(
              label: isAffiliate
                  ? 'Switch to Trader'
                  : isPending
                  ? 'Review in progress'
                  : isApproved
                  ? 'Switch to Affiliate'
                  : 'Apply for Affiliate',
              leadingIcon: isPending
                  ? Icons.hourglass_top_rounded
                  : isAffiliate
                  ? Icons.candlestick_chart_rounded
                  : Icons.handshake_outlined,
              variant: isAffiliate || isApproved
                  ? UiVariant.soft
                  : UiVariant.outline,
              intent: UiIntent.warning,
              size: UiSize.xs,
              onPressed: () {
                if (isAffiliate) {
                  _switchRole(UserRole.customer);
                } else if (isApproved) {
                  _switchRole(UserRole.affiliate);
                } else {
                  _openAffiliateApplication();
                }
              },
            ),
          if (!isAdmin) SizedBox(height: context.sp(context.ui.spacing.xxs)),
          if (!isAffiliate && !isAdmin) ...<Widget>[
            UiButton(
              label: 'Preview Affiliate',
              leadingIcon: Icons.visibility_outlined,
              variant: UiVariant.outline,
              intent: UiIntent.warning,
              size: UiSize.xs,
              onPressed: () => _switchRole(UserRole.affiliate),
            ),
            SizedBox(height: context.sp(context.ui.spacing.xxs)),
          ],
          UiButton(
            label: isAdmin ? 'Exit Admin' : 'Admin',
            leadingIcon: Icons.admin_panel_settings_outlined,
            variant: isAdmin ? UiVariant.soft : UiVariant.outline,
            intent: UiIntent.danger,
            size: UiSize.xs,
            onPressed: () =>
                _switchRole(isAdmin ? UserRole.customer : UserRole.userAdmin),
          ),
        ],
      ),
    );
  }

  void _showRoleSwitcherDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: 'Switch User Role',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: UserRole.values.map((UserRole role) {
            final bool isSelected = _effectiveRole == role;
            return Padding(
              padding: EdgeInsets.only(
                bottom: context.sp(context.ui.spacing.sm),
              ),
              child: UiInteractive(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _switchRole(role);
                  UiToast.show(
                    context,
                    title: 'Role Switch',
                    message: 'Switched session to ${role.label} mode.',
                    intent: UiIntent.info,
                  );
                },
                builder: (BuildContext context, UiInteractiveState state) =>
                    Container(
                      padding: EdgeInsets.all(
                        context.sp(context.ui.spacing.md),
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.ui.colors.primary.withValues(alpha: 0.12)
                            : (state.hovered
                                  ? context.ui.colors.surfaceHover
                                  : Colors.transparent),
                        borderRadius: context.radius(context.ui.radii.md),
                        border: Border.all(
                          color: isSelected
                              ? context.ui.colors.primary
                              : context.ui.colors.border,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(role.icon, color: context.ui.colors.primary),
                          UiGap.h(context.ui.spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  role.label,
                                  style: context.uiText.bodyStrong,
                                ),
                                Text(
                                  role.subtitle,
                                  style: context.uiText.caption.copyWith(
                                    color: context.ui.colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          UiBadge(
                            label: role.shortTitle,
                            intent: role.badgeIntent,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                    ),
              ),
            );
          }).toList(),
        ),
        actions: <Widget>[
          UiButton(
            label: 'Close',
            variant: UiVariant.outline,
            intent: UiIntent.neutral,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  /// Listens to the session plan so a change in billing repaints the workspace
  /// name, the tier chip and every gate below in the same frame.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppTier>(
    valueListenable: _session.tier,
    builder: (BuildContext context, AppTier tier, Widget? _) =>
        _buildWorkspace(tier),
  );

  Widget _buildWorkspace(AppTier tier) {
    final RoleNavigationConfig navigation = _navigation;
    final Widget scaffoldContent = Column(
      children: <Widget>[
        if (widget.showDevelopmentRoleSwitcher) _buildSessionBanner(),
        Expanded(
          child: AppShell(
            key: ValueKey<String>(
              '${AppConstants.appName}_${_effectiveRole.id}',
            ),
            sections: navigation.sections,
            mobilePrimaryItems: navigation.mobilePrimaryItems,
            mobileMoreItems: navigation.mobileMoreItems,
            userMenuItems: navigation.userMenuItems,
            selectedId: _showAffiliateApplication
                ? 'affiliate_application'
                : _selectedId,
            onSelect: _go,
            onSearch: () => _go('search'),
            onSettings: () => _go('settings_profile'),
            onAi: () => _go('ai_copilot'),
            onNotifications: () => _go('notifications'),
            onLogout: widget.onLogout,
            trader: _chromeIdentity,
            tier: tier,
            workspaceName: _effectiveRole == UserRole.customer
                ? switch (tier) {
                    AppTier.free => 'TradeX Basic',
                    AppTier.premium => 'TradeX Pro',
                    AppTier.enterprise => 'TradeX Enterprise',
                  }
                : navigation.workspaceName,
            tierLabel: _effectiveRole == UserRole.customer
                ? switch (tier) {
                    AppTier.free => 'Basic Plan',
                    AppTier.premium => 'Pro Plan',
                    AppTier.enterprise => 'Enterprise Plan',
                  }
                : navigation.workspaceLabel,
            unreadNotifications: _unread,
            pageTitle: _pageTitleOverride,
            pageIcon: _pageIconOverride,
            onBack: _pageBackOverride,
            pagePlaceholderBuilder: (BuildContext context, AppNavItem item) =>
                _destinationSkeleton(item.id),
            primaryAction: _buildDesktopPreviewControls(),
            researchPanelBuilder: null,
            child: _buildActivePage(),
          ),
        ),
      ],
    );

    return scaffoldContent;
  }

  /// Prototype-only strip that names the previewed session and offers a way out
  /// of it. Never shown when the shell is driven by a real signed-in account.
  Widget _buildSessionBanner() {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isAdmin = _effectiveRole == UserRole.userAdmin;
    final Color accent = isAdmin ? colors.bearish : colors.warning;
    return Container(
      height: context.sz(36),
      padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: accent.withValues(alpha: 0.22),
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          // The pill shares this row with two buttons and the subtitle, and it
          // is the only member sized by its own text — an uppercase role at a
          // large text scale pushed the whole banner past the screen edge.
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.xs),
                vertical: context.sp(theme.spacing.xxs),
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: context.radius(theme.radii.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _effectiveRole.icon,
                    size: context.sz(theme.sizes.iconSm - 2),
                    color: accent,
                  ),
                  UiGap.h(theme.spacing.xxs),
                  Flexible(
                    child: Text(
                      _effectiveRole.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        fontSize: context.fs(10),
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          UiGap.h(theme.spacing.xs),
          Expanded(
            child: Text(
              _effectiveRole.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.foregroundMuted,
              ),
            ),
          ),
          UiButton(
            label: 'Switch Role',
            leadingIcon: Icons.swap_horiz_rounded,
            variant: UiVariant.ghost,
            intent: UiIntent.primary,
            size: UiSize.xs,
            hideLabelOnMobile: true,
            onPressed: _showRoleSwitcherDialog,
          ),
          UiGap.h(theme.spacing.xs),
          UiButton(
            label: 'Logout',
            leadingIcon: Icons.logout_rounded,
            variant: UiVariant.soft,
            intent: UiIntent.danger,
            size: UiSize.xs,
            hideLabelOnMobile: true,
            onPressed: widget.onLogout,
          ),
        ],
      ),
    );
  }
}
