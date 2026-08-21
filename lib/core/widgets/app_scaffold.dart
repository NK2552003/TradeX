import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/data/session_trader.dart';
// Required unified primitive import for application layouts.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/features/affiliate_program/affiliate_program.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_marketing_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_overview_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_referrals_page.dart';
import 'package:tradex/features/ai_assistant/data/repositories/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/presentation/pages/ai_copilot_page.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/community/presentation/pages/community_page.dart';
import 'package:tradex/features/dashboard/presentation/pages/trader_overview_page.dart';
import 'package:tradex/features/enterprise/presentation/pages/desk_analytics_page.dart';
import 'package:tradex/features/enterprise/presentation/pages/desk_audit_page.dart';
import 'package:tradex/features/enterprise/presentation/pages/desk_overview_page.dart';
import 'package:tradex/features/enterprise/presentation/pages/desk_risk_page.dart';
import 'package:tradex/features/enterprise/presentation/pages/desk_team_page.dart';
import 'package:tradex/features/journal/presentation/pages/journal_page.dart';
import 'package:tradex/features/messages/presentation/pages/messages_page.dart';
import 'package:tradex/features/notifications/data/repositories/notifications_repository.dart';
import 'package:tradex/features/notifications/presentation/pages/notifications_page.dart';
import 'package:tradex/features/portfolio/presentation/pages/portfolio_page.dart';
import 'package:tradex/features/search/data/repositories/search_repository.dart';
import 'package:tradex/features/search/presentation/pages/search_page.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';
import 'package:tradex/features/strategies/presentation/pages/strategies_page.dart';
import 'package:tradex/features/watchlists/presentation/pages/watchlists_page.dart';

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
  });

  final UserRole userRole;

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
  };

  /// Which sidebar destination answers each kind of search hit, best first. The
  /// first one the role can actually reach wins, so a partner's trader hit lands
  /// in the community and a desk admin's lands in the seats table — and a kind
  /// with no reachable destination is never searched at all.
  static const Map<AppSearchKind, List<String>> _searchTargets =
      <AppSearchKind, List<String>>{
        AppSearchKind.ticker: <String>['watchlists'],
        AppSearchKind.trade: <String>['journal'],
        AppSearchKind.note: <String>['journal'],
        AppSearchKind.strategy: <String>['strategies'],
        AppSearchKind.trader: <String>['community', 'org_team'],
        AppSearchKind.post: <String>['community'],
      };

  final AppSession _session = AppSession.instance;

  // Shell-owned repositories. They outlive the pages that read them, so the
  // unread badge and the recent-search list survive a page remount.
  final NotificationsRepository _notifications = NotificationsRepositoryImpl();
  final SearchRepository _search = SearchRepositoryImpl();
  final ProfileSettingsRepository _profiles = ProfileSettingsRepositoryImpl();

  String _selectedId = 'overview';
  AppTrader? _identity;
  int _unread = 0;
  bool _showAffiliateApplication = false;
  AffiliateApplicationStatus? _affiliateApplicationStatus;

  // Deep-link intents. Each one is a one-shot instruction for the page that is
  // about to mount, cleared by every navigation so a stale symbol can never
  // re-open a composer the reader already dismissed.
  String? _watchSymbol;
  String? _journalSymbol;
  String? _journalTradeId;
  String? _strategyId;
  String? _postId;
  String? _traderId;
  AppTrader? _messagePeer;
  AiScope? _aiScope;
  String? _aiPrompt;
  String? _searchQuery;

  RoleNavigationConfig get _navigation =>
      RoleNavigationConfig.forRole(widget.userRole);

  @override
  void initState() {
    super.initState();
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
    final int count = await _notifications.getUnreadCount();
    if (!mounted) return;
    setState(() => _unread = count);
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

  /// Sends the reader home and forgets every pending deep link. Written without
  /// [setState] because the only caller is [didUpdateWidget], where a rebuild is
  /// already on the way.
  void _resetToOverview() {
    _selectedId = 'overview';
    _showAffiliateApplication = false;
    _watchSymbol = null;
    _journalSymbol = null;
    _journalTradeId = null;
    _strategyId = null;
    _postId = null;
    _traderId = null;
    _messagePeer = null;
    _aiScope = null;
    _aiPrompt = null;
    _searchQuery = null;
  }

  bool _canReach(String id) =>
      _shellDestinations.containsKey(id) || _navigation.allows(id);

  /// The one way a destination changes. Every intent is reset and only the ones
  /// the caller passed are set, so navigation carries exactly the payload the
  /// jump asked for and nothing left over from the last one.
  void _go(
    String id, {
    String? watchSymbol,
    String? journalSymbol,
    String? journalTradeId,
    String? strategyId,
    String? postId,
    String? traderId,
    AppTrader? messagePeer,
    AiScope? aiScope,
    String? aiPrompt,
    String? searchQuery,
  }) {
    if (!_canReach(id)) return;
    setState(() {
      _selectedId = id;
      _showAffiliateApplication = false;
      _watchSymbol = watchSymbol;
      _journalSymbol = journalSymbol;
      _journalTradeId = journalTradeId;
      _strategyId = strategyId;
      _postId = postId;
      _traderId = traderId;
      _messagePeer = messagePeer;
      _aiScope = aiScope;
      _aiPrompt = aiPrompt;
      _searchQuery = searchQuery;
    });
  }

  /// A handler for a destination, or null when this role cannot reach it — so a
  /// cross-link renders as absent rather than as a button that does nothing.
  VoidCallback? _jump(String id) => _canReach(id) ? () => _go(id) : null;

  /// Where a plan gate sends the reader. Every paywall on every surface arrives
  /// at the same place because the role config decides, not the page.
  void _upgrade() => _go(_navigation.upgradeSectionId);

  /// Sidebar destination that answers hits of [kind] for this role.
  String? _searchDestinationId(AppSearchKind kind) {
    for (final String id in _searchTargets[kind] ?? const <String>[]) {
      if (_navigation.allows(id)) return id;
    }
    return null;
  }

  /// Kind to the label of the surface behind it. Doubles as the allow-list the
  /// search page searches, which is what keeps results and navigation agreeing.
  Map<AppSearchKind, String> get _searchDestinations => <AppSearchKind, String>{
    for (final AppSearchKind kind in AppSearchKind.values)
      if (_searchDestinationId(kind) case final String id)
        if (_navigation.labelFor(id) case final String label) kind: label,
  };

  void _openSearchResult(AppSearchResult result) {
    final String? id = _searchDestinationId(result.kind);
    if (id == null) return;
    final String? entity = result.entityId;
    switch (result.kind) {
      case AppSearchKind.ticker:
        _go(id, watchSymbol: entity);
      case AppSearchKind.trade:
      case AppSearchKind.note:
        _go(id, journalTradeId: entity);
      case AppSearchKind.strategy:
        _go(id, strategyId: entity);
      case AppSearchKind.trader:
        _go(id, traderId: entity);
      case AppSearchKind.post:
        _go(id, postId: entity);
    }
  }

  /// Breadcrumb leaf when the active surface has no sidebar entry to name it.
  String? get _pageTitleOverride => _showAffiliateApplication
      ? 'Affiliate application'
      : _shellDestinations[_selectedId];

  // -------------------------------------------------------------------------
  // Active page
  // -------------------------------------------------------------------------

  Widget _buildActivePage() {
    if (_selectedId == 'search') return _searchPage();
    if (_selectedId == 'notifications') return _notificationsPage();
    if (_selectedId.startsWith('settings')) return _settingsPage();

    return switch (widget.userRole) {
      UserRole.customer => _traderPage(),
      UserRole.affiliate => _affiliatePage(),
      UserRole.userAdmin => _adminPage(),
    };
  }

  Widget _affiliateApplicationPage() => AffiliateApplicationPage(
    userId: widget.userId,
    email: widget.userEmail,
    displayName: widget.userDisplayName,
    isExistingCustomer: true,
    onSubmitted: (AffiliateApplicationModel application) =>
        setState(() => _affiliateApplicationStatus = application.status),
    onCancel: () => setState(() => _showAffiliateApplication = false),
    onDone: () {
      setState(() => _showAffiliateApplication = false);
      _go('settings_profile');
    },
  );

  Widget _searchPage() => SearchPage(
    key: ValueKey<String>('search_${_searchQuery ?? ''}'),
    repository: _search,
    initialQuery: _searchQuery,
    destinations: _searchDestinations,
    onOpen: _openSearchResult,
  );

  Widget _notificationsPage() => NotificationsPage(
    repository: _notifications,
    destinations: _navigation.notificationDestinations,
    onOpenCategory: (String category) {
      final String? target = _navigation.notificationTargets[category];
      if (target != null) _go(target);
    },
    onOpenSettings: () => _go('settings_notifications'),
    onUnreadChanged: (int count) {
      if (mounted) setState(() => _unread = count);
    },
  );

  Widget _settingsPage() {
    final String sectionId = _selectedId == 'settings'
        ? 'profile'
        : _selectedId.replaceFirst('settings_', '');
    return SettingsRootPage(
      key: ValueKey<String>('settings_${widget.userRole.id}_$sectionId'),
      userRole: widget.userRole,
      initialSectionId: sectionId,
      showNavigationPane: context.uiRes.isMobile && _selectedId == 'settings',
      onLogout: widget.onLogout,
      subscriptionTier: _session.tier.value,
      // Straight into the session: billing is not allowed a private copy of the
      // plan, or the gates elsewhere would stay shut after an upgrade.
      onSubscriptionTierChanged: _session.changeTier,
      onApplyForAffiliate: () =>
          setState(() => _showAffiliateApplication = true),
    );
  }

  /// Shared AI surface. Every role gets the copilot; only the lens differs, and
  /// the shell hands over the question that sent the reader there.
  Widget _aiPage() => AiCopilotPage(
    key: ValueKey<String>('ai_${_aiScope?.name ?? ''}_${_aiPrompt ?? ''}'),
    initialScope: _aiScope,
    initialPrompt: _aiPrompt,
    onUpgrade: _upgrade,
    onOpenSymbol: _canReach('watchlists')
        ? (String symbol) => _go('watchlists', watchSymbol: symbol)
        : null,
  );

  Widget _communityPage() => CommunityPage(
    key: ValueKey<String>('community_${_postId ?? ''}_${_traderId ?? ''}'),
    initialPostId: _postId,
    initialTraderId: _traderId,
    onOpenSymbol: _canReach('watchlists')
        ? (String symbol) => _go('watchlists', watchSymbol: symbol)
        : null,
    onMessageTrader: _canReach('messages')
        ? (AppTrader trader) => _go('messages', messagePeer: trader)
        : null,
  );

  Widget _messagesPage() => MessagesPage(
    key: ValueKey<String>('messages_${_messagePeer?.id ?? ''}'),
    initialPeer: _messagePeer,
    onUpgrade: _upgrade,
    onOpenTrader: _canReach('community')
        ? (AppTrader trader) => _go('community', traderId: trader.id)
        : null,
  );

  Widget _traderPage() => switch (_selectedId) {
    'overview' => TraderOverviewPage(
      displayName: _chromeIdentity.displayName,
      onOpenJournal: _jump('journal'),
      onOpenTrade: (AppTrade trade) => _go('journal', journalTradeId: trade.id),
      onOpenWatchlists: _jump('watchlists'),
      onOpenTicker: (AppTicker ticker) =>
          _go('watchlists', watchSymbol: ticker.symbol),
      onOpenAi: _jump('ai_copilot'),
      onOpenPortfolio: _jump('portfolio'),
    ),
    'journal' => JournalPage(
      key: ValueKey<String>(
        'journal_${_journalSymbol ?? ''}_${_journalTradeId ?? ''}',
      ),
      composeSymbol: _journalSymbol,
      focusTradeId: _journalTradeId,
      onOpenAi: () => _go('ai_copilot', aiScope: AiScope.journal),
      onOpenTicker: (String symbol) => _go('watchlists', watchSymbol: symbol),
    ),
    'strategies' => StrategiesPage(
      key: ValueKey<String>('strategies_${_strategyId ?? ''}'),
      initialStrategyId: _strategyId,
      onOpenAi: () => _go('ai_copilot', aiScope: AiScope.strategy),
      onOpenJournal: _jump('journal'),
    ),
    'watchlists' => WatchlistsPage(
      key: ValueKey<String>('watchlists_${_watchSymbol ?? ''}'),
      initialSymbol: _watchSymbol,
      onOpenAi: (String symbol) => _go(
        'ai_copilot',
        aiScope: AiScope.market,
        aiPrompt: 'Read the setup on $symbol and tell me where the risk is.',
      ),
      onLogTrade: (String symbol) => _go('journal', journalSymbol: symbol),
    ),
    'portfolio' => PortfolioPage(
      onOpenJournal: _jump('journal'),
      onOpenStrategies: _jump('strategies'),
      onOpenTrade: (AppTrade trade) => _go('journal', journalTradeId: trade.id),
    ),
    'community' => _communityPage(),
    'messages' => _messagesPage(),
    'ai_copilot' => _aiPage(),
    _ => _unknownPage(),
  };

  Widget _affiliatePage() => switch (_selectedId) {
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
    'community' => _communityPage(),
    'messages' => _messagesPage(),
    'ai_copilot' => _aiPage(),
    _ => _unknownPage(),
  };

  Widget _adminPage() => switch (_selectedId) {
    'overview' => DeskOverviewPage(
      deskName: _navigation.workspaceName,
      onOpenTeam: _jump('org_team'),
      onOpenRisk: _jump('org_risk'),
      onOpenAudit: _jump('org_audit'),
      onOpenAnalytics: _jump('org_analytics'),
      onOpenAffiliateReviews: _jump('affiliate_reviews'),
      onUpgrade: _upgrade,
    ),
    'org_team' => DeskTeamPage(
      onOpenAudit: _jump('org_audit'),
      onUpgrade: _upgrade,
    ),
    'org_risk' => DeskRiskPage(
      onOpenAudit: _jump('org_audit'),
      onOpenTeam: _jump('org_team'),
    ),
    'org_audit' => DeskAuditPage(
      onOpenTeam: _jump('org_team'),
      onOpenRisk: _jump('org_risk'),
    ),
    'org_analytics' => DeskAnalyticsPage(
      onOpenTeam: _jump('org_team'),
      onOpenRisk: _jump('org_risk'),
      onOpenAudit: _jump('org_audit'),
      onUpgrade: _upgrade,
    ),
    'affiliate_reviews' => const AffiliateApprovalsPage(),
    'ai_copilot' => _aiPage(),
    _ => _unknownPage(),
  };

  /// Reached only if a destination is added to the sidebar before it has a page.
  /// Saying so beats a blank pane that looks like a loading failure.
  Widget _unknownPage() => AppPageBlock(
    title: _navigation.labelFor(_selectedId) ?? 'Not available',
    subtitle:
        'This surface is not part of the ${widget.userRole.label} '
        'workspace yet',
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
  );

  // -------------------------------------------------------------------------
  // Prototype chrome
  // -------------------------------------------------------------------------

  Widget _buildDesktopPreviewControls() {
    final bool isAffiliate = widget.userRole == UserRole.affiliate;
    final bool isPending =
        _affiliateApplicationStatus == AffiliateApplicationStatus.pending;
    final bool isApproved =
        _affiliateApplicationStatus == AffiliateApplicationStatus.approved;
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
          if (widget.userRole != UserRole.userAdmin)
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
              onPressed: isPending
                  ? null
                  : () {
                      if (isAffiliate) {
                        widget.onRoleChanged?.call(UserRole.customer);
                      } else if (isApproved) {
                        widget.onRoleChanged?.call(UserRole.affiliate);
                      } else {
                        setState(() => _showAffiliateApplication = true);
                      }
                    },
            ),
          if (widget.userRole != UserRole.userAdmin)
            SizedBox(height: context.sp(context.ui.spacing.xxs)),
          if (!isAffiliate) ...<Widget>[
            UiButton(
              label: 'Preview Affiliate',
              leadingIcon: Icons.visibility_outlined,
              variant: UiVariant.outline,
              intent: UiIntent.warning,
              size: UiSize.xs,
              onPressed: () => widget.onRoleChanged?.call(UserRole.affiliate),
            ),
            SizedBox(height: context.sp(context.ui.spacing.xxs)),
          ],
          UiButton(
            label: widget.userRole == UserRole.userAdmin
                ? 'Exit Admin'
                : 'Admin',
            leadingIcon: Icons.admin_panel_settings_outlined,
            variant: widget.userRole == UserRole.userAdmin
                ? UiVariant.soft
                : UiVariant.outline,
            intent: UiIntent.danger,
            size: UiSize.xs,
            onPressed: () => widget.onRoleChanged?.call(
              widget.userRole == UserRole.userAdmin
                  ? UserRole.customer
                  : UserRole.userAdmin,
            ),
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
            final bool isSelected = widget.userRole == role;
            return Padding(
              padding: EdgeInsets.only(
                bottom: context.sp(context.ui.spacing.sm),
              ),
              child: UiInteractive(
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onRoleChanged?.call(role);
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
              '${AppConstants.appName}_${widget.userRole.id}',
            ),
            sections: navigation.sections,
            mobilePrimaryItems: navigation.mobilePrimaryItems,
            mobileMoreItems: navigation.mobileMoreItems,
            userMenuItems: navigation.userMenuItems,
            selectedId: _selectedId,
            onSelect: _go,
            onSearch: () => _go('search'),
            onSettings: () => _go('settings_profile'),
            onAi: () => _go('ai_copilot'),
            onNotifications: () => _go('notifications'),
            onLogout: widget.onLogout,
            trader: _chromeIdentity,
            tier: tier,
            workspaceName: widget.userRole == UserRole.customer
                ? switch (tier) {
                    AppTier.free => 'TradeX Basic',
                    AppTier.premium => 'TradeX Pro',
                    AppTier.enterprise => 'TradeX Enterprise',
                  }
                : navigation.workspaceName,
            tierLabel: widget.userRole == UserRole.customer
                ? switch (tier) {
                    AppTier.free => 'Basic Plan',
                    AppTier.premium => 'Pro Plan',
                    AppTier.enterprise => 'Enterprise Plan',
                  }
                : navigation.workspaceLabel,
            unreadNotifications: _unread,
            pageTitle: _pageTitleOverride,
            primaryAction: widget.onRoleChanged == null
                ? null
                : _buildDesktopPreviewControls(),
            child: _buildActivePage(),
          ),
        ),
      ],
    );

    if (_showAffiliateApplication) {
      return Stack(
        children: <Widget>[
          scaffoldContent,
          Positioned.fill(
            child: _affiliateApplicationPage(),
          ),
        ],
      );
    }

    return scaffoldContent;
  }

  /// Prototype-only strip that names the previewed session and offers a way out
  /// of it. Never shown when the shell is driven by a real signed-in account.
  Widget _buildSessionBanner() {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isAdmin = widget.userRole == UserRole.userAdmin;
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
                    widget.userRole.icon,
                    size: context.sz(theme.sizes.iconSm - 2),
                    color: accent,
                  ),
                  UiGap.h(theme.spacing.xxs),
                  Flexible(
                    child: Text(
                      widget.userRole.label.toUpperCase(),
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
              widget.userRole.subtitle,
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
