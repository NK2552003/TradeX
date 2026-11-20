import 'dart:async';
import 'package:alphajournal/features/market_data/presentation/market_root_screen.dart'
    deferred as deferred_market_root;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:alphajournal/features/community/presentation/widgets/public_record_detail_modal.dart';
import 'package:alphajournal/core/ads/ad_config.dart';
import 'package:alphajournal/core/ads/ad_scope.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/app_constants.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/data/app_entitlements.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/data/account_access_repository.dart';
import 'package:alphajournal/core/widgets/account_access_gate.dart';
import 'package:alphajournal/core/data/session_trader.dart';
// Required unified primitive import for application layouts.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/core/navigation/customer_routes.dart';
import 'package:alphajournal/core/navigation/role_navigation_config.dart';
import 'package:alphajournal/core/security/private_messaging_gate.dart';
import 'package:alphajournal/features/admin_console/presentation/pages/admin_analytics_page.dart'
    deferred as deferred_admin_analytics;
import 'package:alphajournal/features/admin_console/presentation/pages/admin_audit_log_page.dart'
    deferred as deferred_admin_audit_log;
import 'package:alphajournal/features/admin_console/presentation/pages/admin_overview_page.dart'
    deferred as deferred_admin_overview;
import 'package:alphajournal/features/admin_console/presentation/pages/admin_publishing_page.dart'
    deferred as deferred_admin_publishing;
import 'package:alphajournal/features/admin_console/presentation/pages/admin_records_page.dart'
    deferred as deferred_admin_records;
import 'package:alphajournal/features/admin_console/presentation/pages/admin_settings_page.dart'
    deferred as deferred_admin_settings;
import 'package:alphajournal/features/admin_console/models/admin_records.dart';
import 'package:alphajournal/features/admin_console/presentation/pages/admin_team_seats_page.dart'
    deferred as deferred_admin_team_seats;
import 'package:alphajournal/features/affiliate_program/data/affiliate_application_repository.dart';
import 'package:alphajournal/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_application_page.dart';
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_approvals_page.dart'
    deferred as deferred_aff_approvals;
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_marketing_page.dart'
    deferred as deferred_aff_marketing;
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_overview_page.dart'
    deferred as deferred_aff_overview;
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart'
    deferred as deferred_aff_payouts;
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_referrals_page.dart'
    deferred as deferred_aff_referrals;
import 'package:alphajournal/features/auth/data/services/auth_session_storage.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/user_profile_model.dart';
import 'package:alphajournal/features/calculators/ui/calculators_screen.dart'
    deferred as deferred_calculators;
import 'package:alphajournal/features/journal/ui/journal_screen.dart';
import 'package:alphajournal/features/notes/ui/notes_screen.dart';
import 'package:alphajournal/features/workspace/ui/workspace_screen.dart';

import 'package:alphajournal/features/settings/data/repositories/ai_settings_repository.dart';
import 'package:alphajournal/features/settings/data/repositories/notification_prefs_repository.dart';
import 'package:alphajournal/features/settings/data/repositories/privacy_repository.dart';
import 'package:alphajournal/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/settings_root_page.dart';
import 'package:alphajournal/features/strategies/ui/strategies_screen.dart';
import 'package:alphajournal/features/community/community.dart';
import 'package:alphajournal/features/messages/messages.dart';
import 'package:alphajournal/features/copilot/copilot.dart';
import 'package:alphajournal/core/widgets/app_global_notifications_page.dart';
import 'package:alphajournal/core/widgets/app_notifications_overlay.dart';
import 'package:alphajournal/core/widgets/feature_showcase_catalog.dart';
import 'package:alphajournal/core/widgets/feature_showcase_sheet.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';
import 'package:alphajournal/features/community/presentation/views/shared_profile_page.dart';

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
    this.initialDestination = 'workspace',
    this.initialOpenRequest,
    this.profileHandle,
    this.onDestinationChanged,
    this.onOpenRecord,
  });

  final UserRole userRole;
  final String initialDestination;
  final AppLinkOpenRequest? initialOpenRequest;
  final String? profileHandle;
  final ValueChanged<String>? onDestinationChanged;
  final ValueChanged<AppLinkRef>? onOpenRecord;

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
    'workspace': 'Workspace',
    'overview': 'Overview',
    'notifications': 'Notifications',
    'search': 'Search',
    'affiliate_application': 'Affiliate Application',
    'market': 'Market Data',
    'journal': 'Journal',
    'community': 'Community',
    'community_feed': 'Community Feed',
    'public_profile': 'Trader Profile',
  };

  final AppSession _session = AppSession.instance;
  final ProfileSettingsRepository _profiles = ProfileSettingsRepositoryImpl();
  final GlobalKey<WorkspaceScreenState> _workspaceKey =
      GlobalKey<WorkspaceScreenState>();
  final GlobalKey<JournalScreenState> _journalKey =
      GlobalKey<JournalScreenState>();
  final GlobalKey<StrategiesScreenState> _strategiesKey =
      GlobalKey<StrategiesScreenState>();
  final GlobalKey<NotesScreenState> _notesKey = GlobalKey<NotesScreenState>();
  final GlobalKey _workspaceSearchKey = GlobalKey();

  String _selectedId = 'workspace';
  int _communityNavigationRevision = 0;

  /// Shell-level destination history. Feature screens keep their own detail
  /// history, while this stack preserves where a cross-feature jump came from.
  final List<String> _destinationHistory = <String>[];
  final List<({String destination, AppLinkOpenRequest? request})>
  _linkedOrigins = [];

  String _workspaceQuery = '';
  WorkspaceViewState? _workspaceViewState;
  String _communityQuery = '';
  String _marketQuery = '';
  AppTrader? _identity;
  int _unread = 0;
  bool _showAffiliateApplication = false;
  AffiliateApplicationStatus? _affiliateApplicationStatus;
  late final CommunityRepository _communityRepo = CommunityRepository();
  late final MessagesRepository _messagesRepo = MessagesRepository(
    autoConnect: false,
  );
  late final CopilotController _aiRepo = CopilotController();
  bool _aiRepoWasConnected = false;
  final GlobalKey<MessagesRootScreenState> _messagesKey =
      GlobalKey<MessagesRootScreenState>();
  final GlobalKey<CopilotScreenState> _aiKey = GlobalKey<CopilotScreenState>();
  String _messagesQuery = '';
  String _aiQuery = '';
  String? _aiInitialPrompt;

  UserRole? _previewRoleOverride;
  AccountAccess? _liveAccess;
  late final _accessRepository = AccountAccessRepository();

  bool _isRoleAllowedByLiveAccess(UserRole role, AccountAccess live) {
    if (!live.isActive) return role == UserRole.customer;
    return switch (role) {
      UserRole.customer => true,
      UserRole.affiliate =>
        live.role == UserRole.userAdmin ||
            live.role == UserRole.affiliate ||
            (live.affiliateApproved && live.allows('affiliate')),
      UserRole.userAdmin => live.role == UserRole.userAdmin,
    };
  }

  UserRole get _effectiveRole {
    final UserRole desired = _previewRoleOverride ?? widget.userRole;
    final AccountAccess? live = _liveAccess;
    if (live != null && !widget.showDevelopmentRoleSwitcher) {
      if (!_isRoleAllowedByLiveAccess(desired, live)) {
        return live.isActive ? live.role : UserRole.customer;
      }
      return desired;
    }
    return desired;
  }

  bool _hasEverOwnedAdminRole = false;
  bool _hasEverOwnedAffiliateRole = false;

  RoleNavigationConfig get _navigation => RoleNavigationConfig.forRole(
    _effectiveRole,
    includeProfileModeToggle: widget.showDevelopmentRoleSwitcher,
  );

  void _syncSessionEligibility([UserProfileModel? loadedProfile]) {
    final live = _liveAccess;
    if (live != null && !widget.showDevelopmentRoleSwitcher) {
      _hasEverOwnedAdminRole = live.isActive && live.role == UserRole.userAdmin;
      _hasEverOwnedAffiliateRole =
          _hasEverOwnedAdminRole ||
          (live.affiliateApproved && live.allows('affiliate'));
      _session.hasCustomProfileModeOverride = false;
      _session.syncEligibility(
        baseRole: _hasEverOwnedAdminRole
            ? UserRole.userAdmin
            : UserRole.customer,
        isApprovedAffiliate: _hasEverOwnedAffiliateRole,
        isAdmin: _hasEverOwnedAdminRole,
      );
      return;
    }
    if (widget.userRole == UserRole.userAdmin ||
        loadedProfile?.role == UserRole.userAdmin) {
      _hasEverOwnedAdminRole = true;
      _hasEverOwnedAffiliateRole = true;
    }
    if (widget.userRole == UserRole.affiliate ||
        loadedProfile?.role == UserRole.affiliate ||
        _affiliateApplicationStatus == AffiliateApplicationStatus.approved) {
      _hasEverOwnedAffiliateRole = true;
    }
    if (widget.showDevelopmentRoleSwitcher) {
      return;
    }
    _session.syncEligibility(
      baseRole: widget.userRole,
      isApprovedAffiliate: _hasEverOwnedAffiliateRole,
      isAdmin: _hasEverOwnedAdminRole,
    );
  }

  void _applyLiveAccess(AccountAccess access) {
    if (!mounted) return;
    setState(() {
      _liveAccess = access;
      _session.changeTier(access.tier);
      _syncSessionEligibility();
      if (!_session.profileMode.value.supportsRole(_effectiveRole)) {
        _previewRoleOverride = UserRole.customer;
        _resetToOverview();
      } else if (!_isDestinationHandledByRole(_selectedId, _effectiveRole)) {
        _resetToOverview();
      }
      if (!access.isActive || !access.allows('ai')) _aiRepo.stop();
    });
  }

  @override
  void initState() {
    super.initState();
    _syncSessionEligibility(_profiles.cachedProfile);
    // The plan arrives with the profile but every gate in the app reads it from
    // the session, so the session adopts it here. That makes entitlement
    // single-owner: upgrading in billing unlocks DMs and copilot credits in the
    // same frame instead of leaving each surface with its own stale copy.
    final cachedSubTier = _profiles.cachedProfile.subscriptionTier;
    if (cachedSubTier.isNotEmpty && cachedSubTier.toLowerCase() != 'free') {
      _session.changeTier(appTierFromId(cachedSubTier));
    } else {
      _session.changeTier(widget.subscriptionTier);
    }
    final AppEntitlement? blockedInitial = _blockedEntitlement(
      widget.initialDestination,
    );
    if (_canReach(widget.initialDestination)) {
      _selectedId = widget.initialDestination;
      _showAffiliateApplication = _selectedId == 'affiliate_application';
    } else {
      _resetToOverview();
      if (blockedInitial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showEntitlementUpgrade(blockedInitial));
        });
      }
    }
    _session.tier.addListener(_onTierChanged);
    _syncPaidRepositoryAccess();
    CustomerTierQuota.refreshPublishedCatalogue().catchError((Object _) {});
    // Painted from the cached profile on the first frame so the avatar, handle
    // and sidebar footer are never blank, then refreshed from the repository.
    _linkRequest = widget.initialOpenRequest;
    _identity = appTraderFromProfile(_profiles.cachedProfile);
    _communityRepo.addListener(_onCommunityRepoChanged);
    _communityRepo.onLiveNotificationReceived = _handleLiveNotification;
    _unread = _communityRepo.unreadNotifications;

    // Share the local repository instances with the global scope singletons so
    // cross-feature callers (ShareToConversationDialog, CommunitySendDmDialog,
    // AI chat "send as DM", message_actions_sheet "Analyze with AI Copilot",
    // etc.) all write to the exact same instance that the Messages and AI
    // Assistant screens read from. Without this, each scope lazily creates its
    // own detached repository and messages sent from other features never
    // appear in the Messages tab.
    MessagesRepositoryScope.repository = _messagesRepo;
    CopilotScope.repository = _aiRepo;

    _loadIdentity();
    _loadUnread();
    _loadAffiliateApplicationStatus();
    NotificationPrefsRepositoryImpl.instance.getPreferences().catchError(
      (Object _) => NotificationPrefsRepositoryImpl.instance.cachedPreferences,
    );
    PrivacyRepositoryImpl.instance.getPrivacySettings().catchError(
      (Object _) => PrivacyRepositoryImpl.instance.cachedSettings,
    );
    ProfileSettingsRepositoryImpl.instance
        .registerCurrentDeviceSession()
        .catchError((Object _) => null);
    _aiRepo.addListener(_onAiRepoChanged);
    AiSettingsRepositoryImpl.instance
        .getSettings(copilotController: _aiRepo)
        .catchError(
          (Object _) => AiSettingsRepositoryImpl.instance.cachedSettings,
        );
  }

  void _onAiRepoChanged() {
    if (_aiRepoWasConnected == _aiRepo.connected) return;
    _aiRepoWasConnected = _aiRepo.connected;
    if (_aiRepo.connected) {
      unawaited(
        AiSettingsRepositoryImpl.instance.syncCopilotWorkspace(_aiRepo),
      );
    }
  }

  AppEntitlement? _blockedEntitlement(String destination, [AppTier? tier]) {
    final entitlement = AppEntitlement.forDestination(destination);
    final effectiveTier = tier ?? _session.tier.value;
    if (entitlement == null || entitlement.allows(effectiveTier)) {
      return null;
    }
    return entitlement;
  }

  AppNavItem _withTierLocks(AppNavItem item, AppTier tier) => AppNavItem(
    id: item.id,
    label: item.label,
    icon: item.icon,
    selectedIcon: item.selectedIcon,
    badgeCount: item.badgeCount,
    tierLocked: item.tierLocked || _blockedEntitlement(item.id, tier) != null,
    subItems: item.subItems
        ?.map((AppNavItem sub) => _withTierLocks(sub, tier))
        .toList(growable: false),
    actionItems: item.actionItems,
    url: item.url,
  );

  List<AppNavSection> _sectionsWithTierLocks(
    List<AppNavSection> sections,
    AppTier tier,
  ) => sections
      .map(
        (AppNavSection section) => AppNavSection(
          title: section.title,
          items: section.items
              .map((AppNavItem item) => _withTierLocks(item, tier))
              .toList(growable: false),
        ),
      )
      .toList(growable: false);

  Future<void> _showEntitlementUpgrade(AppEntitlement entitlement) =>
      CustomerLimitations.showPlanUpgradeDialog(
        context,
        featureTitle: '${entitlement.title} · Basic or Pro',
        reason: entitlement.reason,
      );

  bool _guardEntitledDestination(String destination) {
    final blocked = _blockedEntitlement(destination);
    if (blocked == null) return true;
    unawaited(_showEntitlementUpgrade(blocked));
    return false;
  }

  void _syncPaidRepositoryAccess() {
    _messagesRepo.setAccessEnabled(
      AppEntitlement.messages.allows(_session.tier.value),
    );
  }

  void _onTierChanged() {
    _syncPaidRepositoryAccess();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final blocked = _blockedEntitlement(_selectedId);
      if (blocked == null) return;
      setState(_resetToOverview);
      unawaited(_showEntitlementUpgrade(blocked));
    });
  }

  void _onCommunityRepoChanged() {
    if (mounted) {
      setState(() => _unread = _communityRepo.unreadNotifications);
    }
  }

  void _openNotificationsOverlay() {
    AppNotificationsOverlay.show(
      context,
      repository: _communityRepo,
      currentUser: _chromeIdentity,
      onOpenRef: _openLinkRef,
      onOpenAuthor: _openAuthorProfile,
      onOpenSecuritySettings: () => _go('settings_security'),
    );
  }

  void _handleLiveNotification(CommunityNotificationItem item) {
    if (!mounted) return;
    if (!NotificationPrefsRepositoryImpl.instance.shouldSurfaceInApp(
      item.type,
    )) {
      return;
    }
    UiToast.show(
      context,
      title: item.title ?? item.label,
      message: item.body ?? item.postSnippet,
      icon: item.icon,
      intent: item.type == CommunityNotificationType.security
          ? UiIntent.warning
          : (item.type == CommunityNotificationType.tradeExecution
                ? UiIntent.success
                : UiIntent.info),
      actionLabel: 'View',
      onAction: _openNotificationsOverlay,
    );
  }

  void _openAuthorProfile(CommunityAuthor author) {
    final profile = TraderProfilePreviewPage(
      repository: _communityRepo,
      displayName: author.displayName,
      handle: author.handle,
      userRole: author.userRole,
      forceTraderView: true,
      avatarUrl: author.avatarUrl,
      bio: author.bio,
      author: author,
      subscriptionTier: author.subscriptionTier,
      verified: author.verified,
      location: author.location,
      website: author.website,
      avgHoldDuration: author.avgHoldDuration,
      primaryMarket: author.primaryMarket,
      topStrategy: author.tradingStyle,
      riskMantra: author.riskMantra,
      isCurrentUser: author.id.isNotEmpty && author.id == _chromeIdentity.id,
      onOpenRef: _openLinkRef,
    );
    if (context.uiRes.isDesktop) {
      showSettingsSideSheet<void>(
        context,
        title: author.displayName,
        desktopWidthRatio: 0.48,
        minDesktopWidth: 540,
        maxWidth: 760,
        child: LayoutBuilder(
          builder: (panelContext, constraints) => MediaQuery(
            data: MediaQuery.of(
              panelContext,
            ).copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
            child: profile,
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final theme = ctx.ui;
        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ctx.sp(theme.radii.xl)),
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.88,
            child: profile,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _session.tier.removeListener(_onTierChanged);
    _communityRepo.removeListener(_onCommunityRepoChanged);
    _communityRepo.dispose();
    _messagesRepo.dispose();
    _aiRepo.removeListener(_onAiRepoChanged);
    _aiRepo.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A post opened in Explore/Profile/Bookmarks updates the browser URL to
    // community_feed. That echo must not remount the feed and its open panel.
    final request = widget.initialOpenRequest;
    final isOpenPostEcho =
        _isCommunityFeature &&
        widget.initialDestination == 'community_feed' &&
        request?.kind == AppLinkKind.communityPost &&
        _linkRequest?.kind == request?.kind &&
        _linkRequest?.id == request?.id;
    if (oldWidget.initialDestination != widget.initialDestination &&
        !isOpenPostEcho &&
        _canReach(widget.initialDestination)) {
      if (_selectedId != widget.initialDestination) {
        _destinationHistory.clear();
        _linkedOrigins.clear();
      }
      _selectedId = widget.initialDestination;
      _showAffiliateApplication = _selectedId == 'affiliate_application';
      _activeSubpageTitle = null;
      _activeSubpageIcon = null;
      _activeSubpageOnBack = null;
      _linkRequest = widget.initialOpenRequest;
    } else if (oldWidget.initialDestination != widget.initialDestination) {
      final blocked = _blockedEntitlement(widget.initialDestination);
      if (blocked != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showEntitlementUpgrade(blocked));
        });
      }
    }
    if (request != null &&
        (request.id != _linkRequest?.id ||
            request.kind != _linkRequest?.kind ||
            request.publicContext != _linkRequest?.publicContext)) {
      _linkRequest = request;
    }
    if (oldWidget.userRole != widget.userRole) {
      _previewRoleOverride = widget.userRole;
      _syncSessionEligibility();
      _resetToOverview();
      _loadAffiliateApplicationStatus();
    }
    if (oldWidget.subscriptionTier != widget.subscriptionTier) {
      _session.changeTier(widget.subscriptionTier);
    }
    if (oldWidget.userId != widget.userId ||
        oldWidget.userEmail != widget.userEmail) {
      _hasEverOwnedAdminRole = widget.userRole == UserRole.userAdmin;
      _hasEverOwnedAffiliateRole = widget.userRole == UserRole.affiliate;
      _syncSessionEligibility();
      _loadIdentity();
    }
  }

  Future<void> _loadIdentity() async {
    final UserProfileModel profile = await _profiles.getProfile();
    if (!mounted) return;
    _syncSessionEligibility(profile);
    setState(() => _identity = appTraderFromProfile(profile));
  }

  Future<void> _loadUnread() async {
    if (!mounted) return;
    setState(() => _unread = _communityRepo.unreadNotifications);
  }

  Future<void> _loadAffiliateApplicationStatus() async {
    try {
      final application = await AffiliateApplicationRepositoryImpl.instance
          .getForUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _affiliateApplicationStatus = application?.status;
        _syncSessionEligibility();
      });
    } catch (_) {
      // Retain the last known status. The application page offers a retry and
      // partner access is checked again when the reader opens the workspace.
    }
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
      location: profile?.location,
      website: profile?.website,
      avgHoldDuration: profile?.avgHoldDuration,
      primaryMarket: profile?.primaryMarket,
      topStrategy: profile?.topStrategy,
      riskMantra: profile?.riskMantra,
      createdAt: profile?.createdAt,
      postsCount: profile?.postsCount ?? 0,
    );
  }

  String? _activeSubpageTitle;
  IconData? _activeSubpageIcon;
  VoidCallback? _activeSubpageOnBack;

  void _onSubpageChanged(String? title, IconData? icon, VoidCallback? onBack) {
    if (!mounted) return;
    final destination = _selectedId;
    // Feature screens can announce a reader/editor while their own frame is
    // still building. Updating AppScaffold synchronously there causes the
    // framework's "setState during build" error, so coalesce the shell update
    // to the next safe frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || destination != _selectedId) return;
      final ref = switch (destination) {
        'notes' => _notesKey.currentState?.openedRef,
        'journal' => _journalKey.currentState?.openedRef,
        'strategies' => _strategiesKey.currentState?.openedRef,
        _ => null,
      };
      if (ref != null &&
          (ref.id != _linkRequest?.id ||
              ref.kind != _linkRequest?.kind ||
              ref.isPublicContext != _linkRequest?.publicContext)) {
        _linkRequest = AppLinkOpenRequest(
          kind: ref.kind,
          id: ref.id,
          seq: ++_linkSeq,
          publicContext: ref.isPublicContext,
        );
        widget.onOpenRecord?.call(ref);
      } else if (ref == null &&
          title == null &&
          const {
            'notes',
            'journal',
            'strategies',
            'community',
            'community_feed',
          }.contains(destination) &&
          _linkRequest != null) {
        _linkRequest = null;
        widget.onDestinationChanged?.call(destination);
      }
      if (_activeSubpageTitle == title &&
          _activeSubpageIcon == icon &&
          identical(_activeSubpageOnBack, onBack)) {
        return;
      }
      setState(() {
        _activeSubpageTitle = title;
        _activeSubpageIcon = icon;
        _activeSubpageOnBack = onBack;
      });
    });
  }

  bool get _isWritingFeature => const <String>{
    'workspace',
    'journal',
    'strategies',
    'notes',
  }.contains(_selectedId);

  String get _writingSearchHint => switch (_selectedId) {
    'workspace' => 'Search desk records, notes, trades, playbooks...',
    'journal' => 'Search entries, tickers, playbooks, tags...',
    'strategies' => 'Search playbooks, rules or instruments...',
    'notes' => 'Search notes, tags or linked records...',
    _ => 'Search entries, tickers, playbooks, tags...',
  };

  void _updateWorkspaceQuery(String value) {
    setState(() => _workspaceQuery = value);
    switch (_selectedId) {
      case 'workspace':
        _workspaceKey.currentState?.setSearchQuery(value);
      case 'journal':
        _journalKey.currentState?.setSearchQuery(value);
      case 'strategies':
        _strategiesKey.currentState?.setSearchQuery(value);
      case 'notes':
        _notesKey.currentState?.setSearchQuery(value);
    }
  }

  Future<void> _showWorkspaceSearch() => UiDrawer.show<void>(
    context,
    title: _writingSearchHint,
    child: StatefulBuilder(
      builder: (BuildContext drawerContext, StateSetter updateDrawer) =>
          UiInput.search(
            value: _workspaceQuery,
            hintText: _writingSearchHint,
            autofocus: true,
            onChanged: (String value) {
              _updateWorkspaceQuery(value);
              updateDrawer(() {});
            },
          ),
    ),
  );

  bool get _isCommunityFeature =>
      _selectedId == 'community' || _selectedId.startsWith('community_');
  bool get _isMarketFeature =>
      _selectedId == 'market' || _selectedId.startsWith('market_');

  Future<void> _showMarketSearch() => UiDrawer.show<void>(
    context,
    title: 'Search market intelligence',
    child: StatefulBuilder(
      builder: (drawerContext, updateDrawer) => UiInput.search(
        value: _marketQuery,
        hintText: 'Search news, companies, symbols...',
        autofocus: true,
        onChanged: (value) {
          setState(() => _marketQuery = value);
          updateDrawer(() {});
        },
        onClear: () {
          setState(() => _marketQuery = '');
          updateDrawer(() {});
        },
      ),
    ),
  );

  bool get _isMessagesFeature => _selectedId == 'messages';

  void _updateMessagesQuery(String value) {
    setState(() => _messagesQuery = value);
    _messagesKey.currentState?.setSearchQuery(value);
  }

  void _openMessagesThread(String threadId) {
    if (!_guardEntitledDestination('messages')) return;
    _go('messages');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messagesKey.currentState?.openThreadById(threadId);
    });
  }

  void _startDirectMessage(AppTrader trader) {
    if (!_guardEntitledDestination('messages')) return;
    if (_messagesRepo.isMessagingRestricted(trader)) {
      _go('messages');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messagesKey.currentState?.openThreadWithTrader(trader);
      });
      return;
    }
    final String threadId = _messagesRepo.startConversation(trader);
    _go('messages');
    if (mounted) {
      setState(() {
        _linkRequest = AppLinkOpenRequest(
          kind: AppLinkKind.messageThread,
          id: threadId,
          seq: ++_linkSeq,
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messagesKey.currentState?.openThreadById(threadId);
    });
  }

  bool get _isAiFeature => _selectedId == 'ai_copilot';

  void _updateAiQuery(String value) {
    setState(() => _aiQuery = value);
    _aiKey.currentState?.setSearchQuery(value);
  }

  void _showActiveWritingGuide() {
    showFeatureShowcaseOverlay(
      context,
      currentDestination: _selectedId,
      activeRole: _effectiveRole,
      hasAffiliateAccess:
          _effectiveRole == UserRole.affiliate || _hasEverOwnedAffiliateRole,
      hasAdminAccess:
          _effectiveRole == UserRole.userAdmin || _hasEverOwnedAdminRole,
      onOpenFeature: _openShowcaseFeature,
      onStartPageTour: _startShowcasePageTour,
    );
  }

  void _openShowcaseFeature(FeatureShowcaseItem item) {
    if (item.requiresAdminAccess) {
      if (_effectiveRole != UserRole.userAdmin) {
        _switchRole(UserRole.userAdmin);
      } else {
        _go('overview');
      }
      return;
    }
    if (item.id == 'affiliate') {
      if (_effectiveRole == UserRole.affiliate) {
        _go('overview');
      } else if (_hasEverOwnedAffiliateRole) {
        _switchRole(UserRole.affiliate);
      } else {
        _go('affiliate_application');
      }
      return;
    }
    _go(item.destinationId);
  }

  void _startShowcasePageTour(FeatureShowcaseItem item) {
    final List<GlobalKey> targets = <GlobalKey>[_workspaceSearchKey];
    if (_selectedId != item.destinationId) {
      _go(item.destinationId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (item.destinationId) {
        case 'journal':
          _journalKey.currentState?.showGuide();
        case 'strategies':
          _strategiesKey.currentState?.showGuideWithTargets(targets);
        case 'notes':
          _notesKey.currentState?.showGuideWithTargets(targets);
      }
    });
  }

  /// Sends the reader home and forgets every pending deep link. Written without
  /// [setState] because the only caller is [didUpdateWidget], where a rebuild is
  /// already on the way.
  void _resetToOverview() {
    _selectedId = _effectiveRole == UserRole.customer
        ? 'workspace'
        : 'overview';
    _showAffiliateApplication = false;
    _activeSubpageTitle = null;
    _activeSubpageIcon = null;
    _activeSubpageOnBack = null;
    _linkRequest = null;
    _destinationHistory.clear();
    _linkedOrigins.clear();
  }

  Future<void> _openPartnerWorkspace() async {
    await _loadAffiliateApplicationStatus();
    if (!mounted) return;
    if (_affiliateApplicationStatus != AffiliateApplicationStatus.approved &&
        widget.userRole != UserRole.affiliate &&
        !_hasEverOwnedAffiliateRole) {
      _openAffiliateApplication();
      return;
    }
    _hasEverOwnedAffiliateRole = true;
    _syncSessionEligibility();
    _switchRole(UserRole.affiliate);
  }

  bool _switchRole(UserRole role) {
    if (!_session.profileMode.value.supportsRole(role)) {
      if (widget.showDevelopmentRoleSwitcher) {
        _session.setProfileMode(UserProfileMode.traderAffiliateAdmin);
      } else {
        if (mounted) {
          UiToast.warning(
            context,
            title: 'Role Not Eligible',
            message:
                'Your account is not eligible for the ${role.label} workspace.',
          );
        }
        return false;
      }
    }
    final UserRole targetRole = role;
    final String nextDest = targetRole == UserRole.customer
        ? 'workspace'
        : 'overview';
    _previewRoleOverride = role;
    if (kIsWeb &&
        widget.onDestinationChanged != null &&
        CustomerRoute.crossOriginRedirectUri(
              Uri(path: '/$nextDest'),
              currentHost: Uri.base.host,
              activeRole: targetRole,
            ) !=
            null) {
      _session.activeRole.value = role;
      widget.onRoleChanged?.call(role);
      AuthSessionStorage.saveLastDestination(nextDest);
      widget.onDestinationChanged?.call(nextDest);
      return true;
    }
    _session.activeRole.value = role;
    setState(() {
      _previewRoleOverride = role;
      _resetToOverview();
    });
    _loadAffiliateApplicationStatus();
    widget.onRoleChanged?.call(role);
    AuthSessionStorage.saveLastDestination(_selectedId);
    widget.onDestinationChanged?.call(_selectedId);
    return true;
  }

  bool _isDestinationHandledByRole(String id, UserRole role) {
    if (id == 'notifications' ||
        id == 'search' ||
        id == 'public_profile' ||
        id == 'affiliate_application' ||
        id == 'market' ||
        id.startsWith('market_') ||
        id.startsWith('settings') ||
        id == 'ai_copilot' ||
        id == 'messages' ||
        id == 'workspace' ||
        id == 'overview') {
      return true;
    }
    return switch (role) {
      UserRole.customer =>
        const <String>{
              'journal',
              'notes',
              'strategies',
              'calculators',
              'community',
            }.contains(id) ||
            id.startsWith('community_'),
      UserRole.affiliate => const <String>{
        'referrals',
        'marketing',
        'payouts',
      }.contains(id),
      UserRole.userAdmin =>
        id == 'admin_console' ||
            id == 'affiliate_reviews' ||
            id.startsWith('admin_') ||
            id.startsWith('org_'),
    };
  }

  bool _canReach(String id) {
    if (_blockedEntitlement(id) != null) return false;
    if (!_isDestinationHandledByRole(id, _effectiveRole)) {
      return false;
    }
    if ((id == 'admin_console' || id.startsWith('admin_')) &&
        _effectiveRole != UserRole.userAdmin &&
        !_hasEverOwnedAdminRole) {
      return false;
    }
    if (id.startsWith('affiliate_') &&
        id != 'affiliate_application' &&
        _effectiveRole != UserRole.affiliate &&
        _effectiveRole != UserRole.userAdmin &&
        !_hasEverOwnedAffiliateRole &&
        !_hasEverOwnedAdminRole) {
      return false;
    }
    return _shellDestinations.containsKey(id) || _navigation.allows(id);
  }

  void _openAffiliateApplication() => _go('affiliate_application');

  void _closeAffiliateApplication() {
    if (_destinationHistory.isNotEmpty) {
      _goBack();
    } else {
      _go('settings_affiliate_perks');
    }
  }

  void _rememberDestination(String next) {
    final int existing = _destinationHistory.lastIndexOf(next);
    if (existing >= 0) {
      _destinationHistory.removeRange(existing, _destinationHistory.length);
    } else if (_destinationHistory.isEmpty ||
        _destinationHistory.last != _selectedId) {
      _destinationHistory.add(_selectedId);
    }
  }

  bool _navigateAcrossSubdomains(String id) {
    final onDestinationChanged = widget.onDestinationChanged;
    if (!kIsWeb ||
        onDestinationChanged == null ||
        Uri.base.queryParameters.containsKey('preview') ||
        !_canReach(id) ||
        CustomerRoute.crossOriginRedirectUri(
              Uri(path: '/$id'),
              currentHost: Uri.base.host,
              activeRole: _effectiveRole,
            ) ==
            null) {
      return false;
    }
    AuthSessionStorage.saveLastDestination(id);
    onDestinationChanged(id);
    return true;
  }

  /// The one way a destination changes.
  void _go(String id, {String? aiPrompt}) {
    if (id == 'switch_role_customer') {
      if (_switchRole(UserRole.customer) && mounted) {
        UiToast.info(
          context,
          title: 'Workspace Switched',
          message: 'Active workspace: Trader Terminal',
        );
      }
      return;
    }
    if (id == 'switch_role_affiliate') {
      if (_switchRole(UserRole.affiliate) && mounted) {
        UiToast.info(
          context,
          title: 'Workspace Switched',
          message: 'Active workspace: Affiliate Partner Hub (INR)',
        );
      }
      return;
    }
    if (id == 'switch_role_admin') {
      if (_switchRole(UserRole.userAdmin) && mounted) {
        UiToast.info(
          context,
          title: 'Workspace Switched',
          message: 'Active workspace: Institutional Admin Console',
        );
      }
      return;
    }
    if (id == 'toggle_profile_mode') {
      if (!widget.showDevelopmentRoleSwitcher) return;
      _session.cycleProfileMode();
      final UserProfileMode nextMode = _session.profileMode.value;
      if (!nextMode.supportsRole(_effectiveRole)) {
        _switchRole(UserRole.customer);
      } else {
        setState(() {});
      }
      if (mounted) {
        UiToast.info(
          context,
          title: 'Profile Mode Updated',
          message: 'Active profile bundle: ${nextMode.label}',
        );
      }
      return;
    }
    if (!_guardEntitledDestination(id)) return;
    if (!_canReach(id)) return;
    if (_selectedId == id &&
        !_showAffiliateApplication &&
        !id.startsWith('community')) {
      return;
    }
    if (_navigateAcrossSubdomains(id)) return;
    _linkedOrigins.clear();
    AuthSessionStorage.saveLastDestination(id);
    setState(() {
      if (_selectedId != id) _rememberDestination(id);
      if (id.startsWith('community')) _communityNavigationRevision++;
      _aiInitialPrompt = aiPrompt;
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
    widget.onDestinationChanged?.call(id);
  }

  void _goBack() {
    if (_linkedOrigins.isNotEmpty) {
      _returnFromLinkedRecord();
      return;
    }
    if (_destinationHistory.isEmpty) return;
    setState(() {
      _selectedId = _destinationHistory.removeLast();
      _communityQuery = '';
      _messagesQuery = '';
      _aiQuery = '';
      _aiInitialPrompt = null;
      _showAffiliateApplication = false;
      _activeSubpageTitle = null;
      _activeSubpageIcon = null;
      _activeSubpageOnBack = null;
      _linkRequest = null;
    });
    widget.onDestinationChanged?.call(_selectedId);
  }

  void _returnFromLinkedRecord() {
    if (_linkedOrigins.isEmpty) return;
    final origin = _linkedOrigins.removeLast();
    setState(() {
      _selectedId = origin.destination;
      _linkRequest = origin.request == null
          ? null
          : AppLinkOpenRequest(
              kind: origin.request!.kind,
              id: origin.request!.id,
              seq: ++_linkSeq,
              publicContext: origin.request!.publicContext,
            );
      _activeSubpageTitle = null;
      _activeSubpageIcon = null;
      _activeSubpageOnBack = null;
      if (_destinationHistory.isNotEmpty &&
          _destinationHistory.last == origin.destination) {
        _destinationHistory.removeLast();
      }
    });
    final request = _linkRequest;
    if (request == null) {
      widget.onDestinationChanged?.call(_selectedId);
    } else {
      widget.onOpenRecord?.call(
        AppLinkRef(
          kind: request.kind,
          id: request.id,
          title: '',
          isPublicContext: request.publicContext,
        ),
      );
    }
  }

  void _communityRecordOpened(AppLinkRef ref) {
    if (_linkRequest?.kind == ref.kind && _linkRequest?.id == ref.id) return;
    _linkRequest = AppLinkOpenRequest(
      kind: ref.kind,
      id: ref.id,
      seq: ++_linkSeq,
      publicContext: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _selectedId.startsWith('community') &&
          _linkRequest?.id == ref.id) {
        widget.onOpenRecord?.call(ref);
      }
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

  AppLinkKind _resolveRefKind(AppLinkRef ref) {
    if (ref.kind == AppLinkKind.communityPost ||
        ref.id.startsWith('post_') ||
        ref.id.startsWith('pst_') ||
        ref.id.startsWith('community')) {
      return AppLinkKind.communityPost;
    }
    if (ref.kind == AppLinkKind.journal ||
        ref.id.startsWith('trade_') ||
        ref.id.startsWith('entry_') ||
        ref.id.startsWith('trn_') ||
        ref.id.startsWith('trd_') ||
        ref.id.startsWith('journal_')) {
      return AppLinkKind.journal;
    }
    if (ref.kind == AppLinkKind.strategy ||
        ref.id.startsWith('strat_') ||
        ref.id.startsWith('stg_') ||
        ref.id.startsWith('strategy_')) {
      return AppLinkKind.strategy;
    }
    if (ref.kind == AppLinkKind.ticker) {
      return AppLinkKind.ticker;
    }
    if (ref.kind == AppLinkKind.aiCopilot || ref.id == 'ai_copilot') {
      return AppLinkKind.aiCopilot;
    }
    if (ref.kind == AppLinkKind.messageThread ||
        ref.id == 'messages' ||
        ref.id.startsWith('thread_') ||
        ref.id.startsWith('conv_')) {
      return AppLinkKind.messageThread;
    }
    return ref.kind;
  }

  /// Follows a link from one destination into another.
  ///
  /// Role permissions still govern the destination. Writing screens handle
  /// same-kind links locally; ticker links arrive at the matching Markets detail.
  void _openLinkRef(AppLinkRef ref, {bool writing = false}) {
    final AppLinkKind resolvedKind = _resolveRefKind(ref);
    final bool isPublic =
        !writing &&
        (ref.isPublicContext ||
            _selectedId == 'community' ||
            _selectedId.startsWith('community_'));

    // Public reading stays inside the current surface and never redirects to
    // the author's private Workspace destination.
    if (!writing &&
        isPublic &&
        (resolvedKind == AppLinkKind.note ||
            resolvedKind == AppLinkKind.journal ||
            resolvedKind == AppLinkKind.strategy)) {
      final String? originPostId = ref.originPostId;
      final CommunityPost? originPost = originPostId == null
          ? null
          : _communityRepo.loadPostById(originPostId);
      PublicRecordDetailModal.show(
        context,
        ref: ref.copyWith(kind: resolvedKind, isPublicContext: true),
        onOpenEditor: () => _openLinkRef(
          ref.copyWith(kind: resolvedKind, isPublicContext: false),
          writing: true,
        ),
        onOpenRef: _openLinkRef,
        initiallySaved: originPost?.bookmarked ?? false,
        onSaveChanged: originPostId == null
            ? null
            : (bool saved) async {
                final CommunityPost? current = _communityRepo.loadPostById(
                  originPostId,
                );
                if (current?.bookmarked != saved) {
                  await _communityRepo.setBookmark(originPostId, saved);
                }
              },
      );
      return;
    }

    final String destination = writing
        ? (resolvedKind == AppLinkKind.journal
              ? 'journal'
              : (resolvedKind == AppLinkKind.strategy ? 'strategies' : 'notes'))
        : (resolvedKind == AppLinkKind.aiCopilot
              ? 'ai_copilot'
              : (resolvedKind == AppLinkKind.messageThread
                    ? 'messages'
                    : switch (resolvedKind) {
                        AppLinkKind.journal => 'journal',
                        AppLinkKind.strategy => 'strategies',
                        AppLinkKind.aiCopilot => 'ai_copilot',
                        AppLinkKind.communityPost => 'community_feed',
                        AppLinkKind.messageThread => 'messages',
                        AppLinkKind.ticker => 'market',
                        AppLinkKind.note => 'notes',
                      }));
    if (!_guardEntitledDestination(destination)) return;
    final bool needsTraderWorkspace =
        !_canReach(destination) &&
        _effectiveRole != UserRole.customer &&
        _session.profileMode.value.supportsRole(UserRole.customer) &&
        _isDestinationHandledByRole(destination, UserRole.customer);
    if (!_canReach(destination) && !needsTraderWorkspace) return;
    final linkedRef = ref.copyWith(
      kind: resolvedKind,
      isPublicContext: isPublic,
    );
    if (kIsWeb &&
        widget.onOpenRecord != null &&
        CustomerRoute.crossOriginRedirectUri(
              CustomerRoute.forRecord(linkedRef),
              currentHost: Uri.base.host,
              activeRole: needsTraderWorkspace
                  ? UserRole.customer
                  : _effectiveRole,
            ) !=
            null) {
      if (needsTraderWorkspace) {
        _previewRoleOverride = UserRole.customer;
        _session.activeRole.value = UserRole.customer;
        widget.onRoleChanged?.call(UserRole.customer);
      }
      widget.onOpenRecord?.call(linkedRef);
      return;
    }
    if (needsTraderWorkspace) {
      _previewRoleOverride = UserRole.customer;
      _session.activeRole.value = UserRole.customer;
      widget.onRoleChanged?.call(UserRole.customer);
    }
    _linkedOrigins.add((destination: _selectedId, request: _linkRequest));
    final bool isRecordSurface = const <String>{
      'journal',
      'strategies',
      'notes',
    }.contains(destination);
    setState(() {
      if (_selectedId != destination) _rememberDestination(destination);
      _selectedId = destination;
      _showAffiliateApplication = false;
      _activeSubpageTitle = isRecordSurface
          ? (ref.title.trim().isNotEmpty
                ? ref.title.trim()
                : switch (resolvedKind) {
                    AppLinkKind.journal => 'Opening trade entry...',
                    AppLinkKind.strategy => 'Opening strategy...',
                    AppLinkKind.note => 'Opening note...',
                    _ => null,
                  })
          : null;
      _activeSubpageIcon = isRecordSurface ? resolvedKind.icon : null;
      _activeSubpageOnBack = isRecordSurface ? _returnFromLinkedRecord : null;
      _linkRequest = AppLinkOpenRequest(
        kind: resolvedKind,
        id: ref.id,
        seq: ++_linkSeq,
        editWriting: writing,
        publicContext: isPublic,
      );
    });
    widget.onOpenRecord?.call(
      ref.copyWith(kind: resolvedKind, isPublicContext: isPublic),
    );
  }

  /// Breadcrumb leaf when the active surface has no sidebar entry to name it.
  String? get _pageTitleOverride => _showAffiliateApplication
      ? 'Affiliate application'
      : _activeSubpageTitle ?? _shellDestinations[_selectedId];

  IconData? get _pageIconOverride =>
      _showAffiliateApplication ? Icons.handshake_outlined : _activeSubpageIcon;

  VoidCallback? get _pageBackOverride => _showAffiliateApplication
      ? _closeAffiliateApplication
      : _activeSubpageOnBack ??
            (_linkedOrigins.isNotEmpty ? _returnFromLinkedRecord : null);

  Widget _buildActivePage() {
    final blocked = _blockedEntitlement(_selectedId);
    if (blocked != null) {
      return UiEmptyState(
        icon: Icons.lock_outline_rounded,
        title: '${blocked.title} requires Basic or Pro',
        message: blocked.reason,
        actionLabel: 'View plans',
        onActionPressed: () => _go('settings_billing'),
      );
    }
    if (_selectedId == 'public_profile') {
      return SharedProfilePage(
        key: ValueKey('shared-profile-${widget.profileHandle}'),
        handle: widget.profileHandle ?? '',
        repository: _communityRepo,
        onOpenRef: _openLinkRef,
      );
    }
    if (_showAffiliateApplication) return _affiliateApplicationPage();
    if (_selectedId == 'search') return _searchPage();
    if (_selectedId == 'notifications') return _notificationsPage();
    if (_selectedId.startsWith('settings')) return _settingsPage();
    if (_selectedId == 'market' || _selectedId.startsWith('market_')) {
      return _DeferredFeatureView(
        libraryId: 'market_root',
        loadLibrary: deferred_market_root.loadLibrary,
        placeholder: UiSkeleton.market(),
        builder: (BuildContext _) => deferred_market_root.MarketRootScreen(
          key: const ValueKey('market-root'),
          destination: _selectedId,
          searchQuery: _marketQuery,
          openRequest: _linkRequest,
          onNavigate: _go,
          onSubpageChanged: _onSubpageChanged,
        ),
      );
    }

    return switch (_effectiveRole) {
      UserRole.customer => _traderPage(),
      UserRole.affiliate => _affiliatePage(),
      UserRole.userAdmin => _adminPage(),
    };
  }

  Widget _affiliateApplicationPage() => AffiliateApplicationPage(
    key: const ValueKey<String>('affiliate_application_page'),
    userId: widget.userId.isNotEmpty ? widget.userId : _chromeIdentity.id,
    email: widget.userEmail.isNotEmpty
        ? widget.userEmail
        : _chromeIdentity.handle,
    displayName: widget.userDisplayName.isNotEmpty
        ? widget.userDisplayName
        : ((_chromeIdentity.displayName?.isNotEmpty ?? false)
              ? _chromeIdentity.displayName!
              : 'Pro Trader'),
    isExistingCustomer: true,
    onSubmitted: (AffiliateApplicationModel application) =>
        setState(() => _affiliateApplicationStatus = application.status),
    onCancel: _closeAffiliateApplication,
    onDone: () {
      setState(() => _showAffiliateApplication = false);
      _loadAffiliateApplicationStatus();
      _go('settings_affiliate_perks');
    },
    onOpenPartnerHub: _openPartnerWorkspace,
  );

  Widget _searchPage() => UiSkeleton.search();

  Widget _notificationsPage() => AppGlobalNotificationsPage(
    repository: _communityRepo,
    currentUser: _chromeIdentity,
    onOpenRef: _openLinkRef,
    onNavigateToCommunity: () => _go('community_feed'),
    onSubpageChanged: _onSubpageChanged,
  );

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
    if (id == 'market' || id.startsWith('market_')) {
      return UiSkeleton.market();
    }
    if (id == 'community' || id.startsWith('community_')) {
      return UiSkeleton.community();
    }
    return switch (id) {
      'overview' => UiSkeleton.dashboard(),
      'workspace' => UiSkeleton.journal(),
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
      'market' => UiSkeleton.market(),
      'community' => UiSkeleton.community(),
      'messages' => UiSkeleton.messages(),
      'ai_copilot' => UiSkeleton.ai(),
      'notifications' => UiSkeleton.notifications(),
      'search' => UiSkeleton.search(),
      'referrals' ||
      'payouts' ||
      'marketing' ||
      'org_analytics' => UiSkeleton.dashboard(),
      'org_team' ||
      'org_risk' ||
      'org_audit' ||
      'affiliate_reviews' => UiSkeleton.page(),
      _ => UiSkeleton.page(),
    };
  }

  Widget _settingsPage() {
    final String sectionId = _selectedId == 'settings'
        ? 'profile'
        : _selectedId.replaceFirst('settings_', '');
    return SettingsRootPage(
      communityRepository: _communityRepo,
      copilotController: _aiRepo,
      onOpenCopilot: () => _go('ai_copilot'),
      onOpenUpgrade: () => _go('settings_billing'),
      key: ValueKey<String>('settings_${_effectiveRole.id}_$sectionId'),
      userRole: _effectiveRole,
      initialSectionId: sectionId,
      // The tablet rail intentionally keeps only the parent Settings icon.
      // Selecting that parent must therefore open the same section chooser as
      // mobile, rather than silently treating Profile as the destination.
      showNavigationPane: _selectedId == 'settings',
      onLogout: widget.onLogout,
      subscriptionTier: _session.tier.value,
      // Straight into the session: billing is not allowed a private copy of the
      // plan, or the gates elsewhere would stay shut after an upgrade.
      onSubscriptionTierChanged: _session.changeTier,
      onApplyForAffiliate: _openAffiliateApplication,
      affiliateApplicationStatus: _affiliateApplicationStatus,
      onOpenPartnerHub: _openPartnerWorkspace,
      onRefreshAffiliateStatus: _loadAffiliateApplicationStatus,
      onOpenPayouts: _effectiveRole == UserRole.affiliate
          ? _jump('payouts')
          : null,
      onOpenMarketing: _effectiveRole == UserRole.affiliate
          ? _jump('marketing')
          : null,
      onSwitchToTrader:
          (_effectiveRole == UserRole.affiliate ||
              _effectiveRole == UserRole.userAdmin)
          ? () => _switchRole(UserRole.customer)
          : null,
      onSubpageChanged: _onSubpageChanged,
      onOpenRef: _openLinkRef,
    );
  }

  static String _monthName(int month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  Widget _communityPage({int initialTabIndex = 0}) {
    final trader = _chromeIdentity;
    final cached = _profiles.cachedProfile;
    final int myPosts = _communityRepo.postsForAuthor(trader.id).length;
    final String? joined = trader.createdAt != null
        ? 'Joined ${_monthName(trader.createdAt!.month)} ${trader.createdAt!.year}'
        : (cached.createdAt != null
              ? 'Joined ${_monthName(cached.createdAt!.month)} ${cached.createdAt!.year}'
              : null);
    _communityRepo.updateCurrentAuthor(
      CommunityAuthor(
        id: trader.id,
        handle: trader.handle,
        displayName: (trader.displayName?.isNotEmpty ?? false)
            ? trader.displayName!
            : trader.handle,
        userRole: _effectiveRole,
        avatarUrl: trader.avatarUrl,
        verified: trader.verified,
        tier: _session.tier.value,
        followers: trader.followers,
        following: trader.following,
        winRate: trader.winRate,
        tradingStyle: trader.tradingStyle ?? cached.tradingStyle,
        primaryMarket: trader.primaryMarket ?? cached.primaryMarket,
        avgHoldDuration: trader.avgHoldDuration ?? cached.avgHoldDuration,
        riskMantra: trader.riskMantra ?? cached.riskMantra,
        location: trader.location ?? cached.location,
        website: trader.website ?? cached.website,
        joinedDate: joined,
        bio: trader.bio ?? cached.bio,
        postsCount: myPosts > 0 ? myPosts : trader.postsCount,
      ),
    );
    return CommunityRootScreen(
      key: ValueKey<String>(
        'community_root_${_effectiveRole.id}_${initialTabIndex}_$_communityNavigationRevision',
      ),
      userRole: _effectiveRole,
      currentTrader: _chromeIdentity,
      onSubpageChanged: _onSubpageChanged,
      onOpenRef: _openLinkRef,
      onOpenWriting: (ref) => _openLinkRef(ref, writing: true),
      onNavigateToMessages: () => _go('messages'),
      onOpenThread: _openMessagesThread,
      onStartDirectMessage: _startDirectMessage,
      initialTabIndex: initialTabIndex,
      onTabChanged: (index) => _go(
        const [
          'community_feed',
          'community_explore',
          'community_network',
          'community_profile',
          'community_bookmarks',
        ][index],
      ),
      onOpenRecord: _communityRecordOpened,
      repository: _communityRepo,
      searchQuery: _communityQuery,
      openRequest: _linkRequest,
    );
  }

  Widget _messagesPage() {
    return PrivateMessagingGate(
      key: ValueKey('e2ee-messages-${widget.userId}'),
      onLogout: widget.onLogout,
      onUnlocked: () => _messagesRepo.redecryptLockedMessages(),
      builder: (BuildContext _) => MessagesRootScreen(
        communityRepository: _communityRepo,
        key: _messagesKey,
        userRole: _effectiveRole,
        currentUser: _chromeIdentity,
        onSubpageChanged: _onSubpageChanged,
        onOpenRef: _openLinkRef,
        repository: _messagesRepo,
        searchQuery: _messagesQuery,
        openRequest: _linkRequest,
      ),
    );
  }

  Widget _aiAssistantPage() {
    return PrivateMessagingGate(
      key: ValueKey('e2ee-ai-${widget.userId}'),
      onLogout: widget.onLogout,
      builder: (BuildContext _) => CopilotScreen(
        key: _aiKey,
        userRole: _effectiveRole,
        currentUser: _chromeIdentity,
        onSubpageChanged: _onSubpageChanged,
        onOpenRef: _openLinkRef,
        onOpenSettings: () => _go('settings_ai'),
        repository: _aiRepo,
        initialPrompt: _aiInitialPrompt,
        searchQuery: _aiQuery,
        openRequest: _linkRequest,
      ),
    );
  }

  Widget _traderPage() => switch (_selectedId) {
    // The three linked writing surfaces. Each is handed the same three
    // affordances so a link followed out of one lands correctly in the next:
    // `onOpenRef` to leave, `openRequest` to arrive, and — for the two that put
    // a document behind a real back step on a phone — `onSubpageChanged` so the
    // app bar names what is open.
    'workspace' || 'overview' => WorkspaceScreen(
      key: _workspaceKey,
      onOpenFeature: _go,
      onOpenTraderSkill: (skill) =>
          _go('ai_copilot', aiPrompt: '${skill.command} '),
      onOpenRef: _openLinkRef,
      onOpenWriting: (ref) => _openLinkRef(ref, writing: true),
      onSubpageChanged: _onSubpageChanged,
      searchQuery: _workspaceQuery,
      viewState: _workspaceViewState,
      onViewStateChanged: (saved) => _workspaceViewState = saved,
    ),
    'journal' => AppWritingDeskScope(
      child: JournalScreen(
        onReturnToOrigin: _linkedOrigins.isNotEmpty
            ? _returnFromLinkedRecord
            : null,
        key: _journalKey,
        onSubpageChanged: _onSubpageChanged,
        onOpenRef: _openLinkRef,
        onOpenWriting: (ref) => _openLinkRef(ref, writing: true),
        openRequest: _linkRequest,
      ),
    ),
    'notes' => AppWritingDeskScope(
      child: NotesScreen(
        onReturnToOrigin: _linkedOrigins.isNotEmpty
            ? _returnFromLinkedRecord
            : null,
        key: _notesKey,
        onSubpageChanged: _onSubpageChanged,
        onOpenRef: _openLinkRef,
        onOpenWriting: (ref) => _openLinkRef(ref, writing: true),
        openRequest: _linkRequest,
      ),
    ),
    'strategies' => AppWritingDeskScope(
      child: StrategiesScreen(
        onReturnToOrigin: _linkedOrigins.isNotEmpty
            ? _returnFromLinkedRecord
            : null,
        key: _strategiesKey,
        onSubpageChanged: _onSubpageChanged,
        onOpenRef: _openLinkRef,
        onOpenWriting: (ref) => _openLinkRef(ref, writing: true),
        openRequest: _linkRequest,
      ),
    ),

    'calculators' => _DeferredFeatureView(
      libraryId: 'calculators',
      loadLibrary: deferred_calculators.loadLibrary,
      placeholder: UiSkeleton.watchlists(),
      builder: (BuildContext _) => deferred_calculators.CalculatorsScreen(
        key: const PageStorageKey<String>('calculators_screen'),
        onSubpageChanged: _onSubpageChanged,
      ),
    ),
    'community' => _communityPage(initialTabIndex: 0),
    'community_feed' => _communityPage(initialTabIndex: 0),
    'community_explore' => _communityPage(initialTabIndex: 1),
    'community_network' => _communityPage(initialTabIndex: 2),
    'community_profile' => _communityPage(initialTabIndex: 3),
    'community_bookmarks' => _communityPage(initialTabIndex: 4),
    'messages' => _messagesPage(),
    'ai_copilot' => _aiAssistantPage(),
    _ => _unknownPage(),
  };

  Widget _affiliatePage() => switch (_selectedId) {
    'workspace' || 'overview' => _DeferredFeatureView(
      libraryId: 'aff_overview',
      loadLibrary: deferred_aff_overview.loadLibrary,
      builder: (BuildContext _) => deferred_aff_overview.AffiliateOverviewPage(
        onNavigate: _go,
        onSwitchToTraderView: () => _switchRole(UserRole.customer),
        onOpenReferrals: _jump('referrals'),
        onOpenPayouts: _jump('payouts'),
        onOpenMarketing: _jump('marketing'),
      ),
    ),
    'referrals' => _DeferredFeatureView(
      libraryId: 'aff_referrals',
      loadLibrary: deferred_aff_referrals.loadLibrary,
      builder: (BuildContext _) =>
          deferred_aff_referrals.AffiliateReferralsPage(
            onNavigate: _go,
            onSwitchToTraderView: () => _switchRole(UserRole.customer),
            onOpenPayouts: _jump('payouts'),
            onOpenMarketing: _jump('marketing'),
          ),
    ),
    'marketing' => _DeferredFeatureView(
      libraryId: 'aff_marketing',
      loadLibrary: deferred_aff_marketing.loadLibrary,
      builder: (BuildContext _) =>
          deferred_aff_marketing.AffiliateMarketingPage(
            onNavigate: _go,
            onSwitchToTraderView: () => _switchRole(UserRole.customer),
            onOpenReferrals: _jump('referrals'),
            onOpenPayouts: _jump('payouts'),
          ),
    ),
    'payouts' => _DeferredFeatureView(
      libraryId: 'aff_payouts',
      loadLibrary: deferred_aff_payouts.loadLibrary,
      builder: (BuildContext _) => deferred_aff_payouts.AffiliatePayoutsPage(
        onNavigate: _go,
        onSwitchToTraderView: () => _switchRole(UserRole.customer),
        onOpenReferrals: _jump('referrals'),
        onOpenSettings: _jump('settings_affiliate'),
      ),
    ),
    'messages' => _messagesPage(),
    'ai_copilot' => _aiAssistantPage(),
    _ => _unknownPage(),
  };

  Widget _adminPage() => switch (_selectedId) {
    'admin_console' || 'workspace' || 'overview' => _DeferredFeatureView(
      libraryId: 'admin_overview',
      loadLibrary: deferred_admin_overview.loadLibrary,
      builder: (BuildContext _) =>
          deferred_admin_overview.AdminOverviewPage(onNavigate: _go),
    ),
    'org_team' => _DeferredFeatureView(
      libraryId: 'admin_team_seats',
      loadLibrary: deferred_admin_team_seats.loadLibrary,
      builder: (BuildContext _) =>
          deferred_admin_team_seats.AdminTeamSeatsPage(onNavigate: _go),
    ),
    'org_risk' => _DeferredFeatureView(
      libraryId: 'admin_settings',
      loadLibrary: deferred_admin_settings.loadLibrary,
      builder: (BuildContext _) => deferred_admin_settings.AdminSettingsPage(),
    ),
    'org_audit' => _DeferredFeatureView(
      libraryId: 'admin_audit_log',
      loadLibrary: deferred_admin_audit_log.loadLibrary,
      builder: (BuildContext _) => deferred_admin_audit_log.AdminAuditLogPage(),
    ),
    'org_analytics' => _DeferredFeatureView(
      libraryId: 'admin_analytics',
      loadLibrary: deferred_admin_analytics.loadLibrary,
      builder: (BuildContext _) =>
          deferred_admin_analytics.AdminAnalyticsPage(onNavigate: _go),
    ),
    'affiliate_reviews' => _DeferredFeatureView(
      libraryId: 'aff_approvals',
      loadLibrary: deferred_aff_approvals.loadLibrary,
      builder: (BuildContext _) =>
          deferred_aff_approvals.AffiliateApprovalsPage(),
    ),
    'org_publishing' => _DeferredFeatureView(
      libraryId: 'admin_publishing',
      loadLibrary: deferred_admin_publishing.loadLibrary,
      builder: (BuildContext _) =>
          deferred_admin_publishing.AdminPublishingPage(),
    ),
    'admin_comments' => _DeferredFeatureView(
      libraryId: 'admin_records',
      loadLibrary: deferred_admin_records.loadLibrary,
      builder: (BuildContext _) => deferred_admin_records.AdminRecordsPage(
        resource: AdminResource.comments,
      ),
    ),
    'admin_subscriptions' => _DeferredFeatureView(
      libraryId: 'admin_records',
      loadLibrary: deferred_admin_records.loadLibrary,
      builder: (BuildContext _) => deferred_admin_records.AdminRecordsPage(
        resource: AdminResource.subscriptions,
      ),
    ),
    'admin_notes' => _DeferredFeatureView(
      libraryId: 'admin_records',
      loadLibrary: deferred_admin_records.loadLibrary,
      builder: (BuildContext _) => deferred_admin_records.AdminRecordsPage(
        resource: AdminResource.notes,
      ),
    ),
    'admin_journal' => _DeferredFeatureView(
      libraryId: 'admin_records',
      loadLibrary: deferred_admin_records.loadLibrary,
      builder: (BuildContext _) => deferred_admin_records.AdminRecordsPage(
        resource: AdminResource.journal,
      ),
    ),
    'admin_strategies' => _DeferredFeatureView(
      libraryId: 'admin_records',
      loadLibrary: deferred_admin_records.loadLibrary,
      builder: (BuildContext _) => deferred_admin_records.AdminRecordsPage(
        resource: AdminResource.strategies,
      ),
    ),
    'admin_deletions' => _DeferredFeatureView(
      libraryId: 'admin_records',
      loadLibrary: deferred_admin_records.loadLibrary,
      builder: (BuildContext _) => deferred_admin_records.AdminRecordsPage(
        resource: AdminResource.deletions,
      ),
    ),
    'admin_messages' || 'messages' => _DeferredFeatureView(
      libraryId: 'admin_records',
      loadLibrary: deferred_admin_records.loadLibrary,
      builder: (BuildContext _) => deferred_admin_records.AdminRecordsPage(
        resource: AdminResource.messages,
      ),
    ),
    'admin_ai' => _DeferredFeatureView(
      libraryId: 'admin_records',
      loadLibrary: deferred_admin_records.loadLibrary,
      builder: (BuildContext _) => deferred_admin_records.AdminRecordsPage(
        resource: AdminResource.ai,
        resources: const [AdminResource.ai, AdminResource.aiRequests],
        title: 'AI control',
      ),
    ),
    'ai_copilot' => _aiAssistantPage(),
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
            label:
                'Back to ${_navigation.labelFor('workspace') ?? _navigation.labelFor('overview') ?? 'the start'}',
            leadingIcon: Icons.arrow_back_rounded,
            variant: UiVariant.outline,
            onPressed: _jump(
              _navigation.allows('workspace') ? 'workspace' : 'overview',
            ),
          ),
        ),
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // Multi-role profile & workspace switcher chrome
  // -------------------------------------------------------------------------

  Widget _buildHeaderRoleSwitcherAction() {
    final UserProfileMode mode = _session.profileMode.value;
    if (mode.allowedRoles.length <= 1 && !widget.showDevelopmentRoleSwitcher) {
      return const SizedBox.shrink();
    }
    final bool isMobile = context.uiRes.isMobile;
    if (isMobile) {
      return UiIconButton(
        key: const ValueKey<String>('header-role-switcher-button'),
        icon: Icons.swap_horiz_rounded,
        size: UiSize.sm,
        tooltip: 'Switch Workspace Role (${_effectiveRole.shortTitle})',
        onPressed: _showRoleSwitcherDialog,
      );
    }
    return Padding(
      padding: EdgeInsets.only(right: context.sp(context.ui.spacing.xxs)),
      child: UiButton(
        key: const ValueKey<String>('header-role-switcher-button'),
        label: _effectiveRole.shortTitle,
        leadingIcon: _effectiveRole.icon,
        trailingIcon: Icons.swap_horiz_rounded,
        variant: UiVariant.soft,
        intent: _effectiveRole.badgeIntent,
        size: UiSize.xs,
        hideLabelOnMobile: true,
        onPressed: _showRoleSwitcherDialog,
      ),
    );
  }

  Widget _buildDesktopPreviewControls() {
    if (context.uiRes.isTablet) {
      return Center(
        child: UiIconButton(
          icon: Icons.swap_horiz_rounded,
          size: UiSize.sm,
          tooltip: 'Switch Workspace Role (${_effectiveRole.shortTitle})',
          onPressed: _showRoleSwitcherDialog,
        ),
      );
    }
    final UserProfileMode mode = _session.profileMode.value;
    final List<UserRole> roles = mode.allowedRoles;
    final bool isCustomer = _effectiveRole == UserRole.customer;
    final bool isAffiliate = _effectiveRole == UserRole.affiliate;
    final bool isAdmin = _effectiveRole == UserRole.userAdmin;
    return UiCard(
      padding: EdgeInsets.all(context.sp(context.ui.spacing.xs)),
      variant: UiCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  mode.shortLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: context.ui.colors.foregroundSubtle,
                    fontSize: context.fs(9),
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.showDevelopmentRoleSwitcher)
                UiIconButton(
                  icon: Icons.switch_account_outlined,
                  size: UiSize.xs,
                  tooltip:
                      'Toggle Profile Bundle (Trader+Affiliate / Trader+Affiliate+Admin)',
                  onPressed: () => _go('toggle_profile_mode'),
                ),
            ],
          ),
          SizedBox(height: context.sp(context.ui.spacing.xxs)),
          if (roles.contains(UserRole.customer)) ...<Widget>[
            UiButton(
              label: isCustomer ? 'Trader (Active)' : 'Switch to Trader',
              leadingIcon: Icons.candlestick_chart_rounded,
              variant: isCustomer ? UiVariant.soft : UiVariant.outline,
              intent: UiIntent.primary,
              size: UiSize.xs,
              onPressed: isCustomer ? null : () => _go('switch_role_customer'),
            ),
            SizedBox(height: context.sp(context.ui.spacing.xxs)),
          ],
          if (roles.contains(UserRole.affiliate)) ...<Widget>[
            UiButton(
              label: isAffiliate ? 'Affiliate (Active)' : 'Switch to Affiliate',
              leadingIcon: Icons.handshake_outlined,
              variant: isAffiliate ? UiVariant.soft : UiVariant.outline,
              intent: UiIntent.warning,
              size: UiSize.xs,
              onPressed: isAffiliate
                  ? null
                  : () => _go('switch_role_affiliate'),
            ),
            if (roles.contains(UserRole.userAdmin))
              SizedBox(height: context.sp(context.ui.spacing.xxs)),
          ],
          if (roles.contains(UserRole.userAdmin))
            UiButton(
              label: isAdmin ? 'Admin (Active)' : 'Switch to Admin',
              leadingIcon: Icons.admin_panel_settings_outlined,
              variant: isAdmin ? UiVariant.soft : UiVariant.outline,
              intent: UiIntent.danger,
              size: UiSize.xs,
              onPressed: isAdmin ? null : () => _go('switch_role_admin'),
            ),
        ],
      ),
    );
  }

  void _showRoleSwitcherDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) {
          final UserProfileMode mode = _session.profileMode.value;
          final List<UserRole> availableRoles = mode.allowedRoles;
          final AppTier activeTier = _session.tier.value;
          return UiDialog(
            title: widget.showDevelopmentRoleSwitcher
                ? 'Switch Workspace & Profile Mode'
                : 'Switch Active Workspace',
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (widget.showDevelopmentRoleSwitcher) ...<Widget>[
                    Text(
                      'MULTI-ROLE PROFILE BUNDLE (DEV PREVIEW)',
                      style: context.uiText.caption.copyWith(
                        color: context.ui.colors.foregroundSubtle,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: context.sp(context.ui.spacing.xs)),
                    UiToggleGroup<UserProfileMode>(
                      options: const <UiToggleOption<UserProfileMode>>[
                        UiToggleOption<UserProfileMode>(
                          value: UserProfileMode.traderOnly,
                          label: 'Trader Only',
                          icon: Icons.candlestick_chart_outlined,
                        ),
                        UiToggleOption<UserProfileMode>(
                          value: UserProfileMode.traderAffiliate,
                          label: 'Trader + Affiliate',
                          icon: Icons.handshake_outlined,
                        ),
                        UiToggleOption<UserProfileMode>(
                          value: UserProfileMode.traderAdmin,
                          label: 'Trader + Admin',
                          icon: Icons.security_outlined,
                        ),
                        UiToggleOption<UserProfileMode>(
                          value: UserProfileMode.traderAffiliateAdmin,
                          label: 'Trader + Affiliate + Admin',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                      ],
                      value: mode,
                      onChanged: (UserProfileMode selectedMode) {
                        _session.setProfileMode(selectedMode);
                        if (!selectedMode.supportsRole(_effectiveRole)) {
                          _switchRole(UserRole.customer);
                        } else {
                          setState(() {});
                        }
                        setModalState(() {});
                      },
                      size: UiSize.xs,
                      expand: true,
                      allowEmpty: false,
                    ),
                    SizedBox(height: context.sp(context.ui.spacing.md)),
                  ],
                  Text(
                    'ELIGIBLE WORKSPACES (${mode.shortLabel.toUpperCase()})',
                    style: context.uiText.caption.copyWith(
                      color: context.ui.colors.foregroundSubtle,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(height: context.sp(context.ui.spacing.xs)),
                  ...availableRoles.map((UserRole role) {
                    final bool isSelected = _effectiveRole == role;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(context.ui.spacing.sm),
                      ),
                      child: UiInteractive(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          if (_switchRole(role)) {
                            UiToast.show(
                              context,
                              title: 'Workspace Switched',
                              message:
                                  'Switched session to ${role.label} mode.',
                              intent: UiIntent.info,
                            );
                          }
                        },
                        builder:
                            (BuildContext context, UiInteractiveState state) =>
                                Container(
                                  padding: EdgeInsets.all(
                                    context.sp(context.ui.spacing.md),
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? context.ui.colors.primary.withValues(
                                            alpha: 0.12,
                                          )
                                        : (state.hovered
                                              ? context.ui.colors.surfaceHover
                                              : Colors.transparent),
                                    borderRadius: context.radius(
                                      context.ui.radii.md,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? context.ui.colors.primary
                                          : context.ui.colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        role.icon,
                                        color: context.ui.colors.primary,
                                      ),
                                      UiGap.h(context.ui.spacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              role.label,
                                              style: context.uiText.bodyStrong,
                                            ),
                                            Text(
                                              role.subtitle,
                                              style: context.uiText.caption
                                                  .copyWith(
                                                    color: context
                                                        .ui
                                                        .colors
                                                        .foregroundMuted,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      UiBadge(
                                        label: isSelected
                                            ? 'Active'
                                            : role.shortTitle,
                                        intent: isSelected
                                            ? UiIntent.success
                                            : role.badgeIntent,
                                        size: UiSize.xs,
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    );
                  }),
                  if (widget.showDevelopmentRoleSwitcher) ...<Widget>[
                    SizedBox(height: context.sp(context.ui.spacing.xs)),
                    Text(
                      'CUSTOMER SUBSCRIPTION TIER (INR)',
                      style: context.uiText.caption.copyWith(
                        color: context.ui.colors.foregroundSubtle,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: context.sp(context.ui.spacing.xs)),
                    UiToggleGroup<AppTier>(
                      options: const <UiToggleOption<AppTier>>[
                        UiToggleOption<AppTier>(
                          value: AppTier.free,
                          label: 'Free (₹0)',
                        ),
                        UiToggleOption<AppTier>(
                          value: AppTier.premium,
                          label: 'Basic (₹299)',
                        ),
                        UiToggleOption<AppTier>(
                          value: AppTier.enterprise,
                          label: 'Pro (₹499)',
                        ),
                      ],
                      value: activeTier,
                      onChanged: (AppTier nextTier) {
                        _session.changeTier(nextTier);
                        setModalState(() {});
                      },
                      size: UiSize.xs,
                      expand: true,
                      allowEmpty: false,
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              UiButton(
                label: 'Close',
                variant: UiVariant.outline,
                intent: UiIntent.neutral,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  /// Listens to the session plan and multi-role profile bundle so changes in
  /// billing or role bundle repaint the workspace, dock and gates immediately.
  @override
  Widget build(BuildContext context) =>
      SupabaseConfig.isConfigured && !widget.showDevelopmentRoleSwitcher
      ? AccountAccessGate(
          key: ValueKey('access-${widget.userId}'),
          repository: _accessRepository,
          destination: _selectedId,
          onAccess: _applyLiveAccess,
          onLogout: widget.onLogout,
          builder: _buildEntitledShell,
        )
      : _buildEntitledShell(context);

  Widget _buildEntitledShell(BuildContext context) =>
      ValueListenableBuilder<AppTier>(
        valueListenable: _session.tier,
        builder: (BuildContext context, AppTier tier, Widget? _) =>
            ValueListenableBuilder<UserProfileMode>(
              valueListenable: _session.profileMode,
              builder: (BuildContext context, UserProfileMode _, Widget? _) =>
                  _buildWorkspace(tier),
            ),
      );

  Widget _buildWorkspace(AppTier tier) {
    final RoleNavigationConfig navigation = _navigation;
    final bool showMultiRoleFooter =
        _session.profileMode.value.allowedRoles.length > 1 ||
        widget.showDevelopmentRoleSwitcher;
    final bool publicSurface =
        !_showAffiliateApplication &&
        AdEligibility.publicDestination(
          _selectedId,
          publicRecord:
              _selectedId == 'notes' && (_linkRequest?.publicContext ?? false),
        );
    final bool adsEligible =
        !widget.showDevelopmentRoleSwitcher &&
        publicSurface &&
        AdEligibility.freeAccount(_liveAccess, tier, widget.userId);
    final bool adsPreviewEligible = publicSurface && tier == AppTier.free;
    final Widget scaffoldContent = Column(
      children: <Widget>[
        if (widget.showDevelopmentRoleSwitcher) _buildSessionBanner(),
        Expanded(
          child: AppShell(
            key: ValueKey<String>(
              '${AppConstants.appName}_${_effectiveRole.id}',
            ),
            sections: _sectionsWithTierLocks(navigation.sections, tier),
            mobilePrimaryItems: navigation.mobilePrimaryItems
                .map((AppNavItem item) => _withTierLocks(item, tier))
                .toList(growable: false),
            mobileMoreItems: navigation.mobileMoreItems
                .map((AppNavItem item) => _withTierLocks(item, tier))
                .toList(growable: false),
            userMenuItems: navigation.userMenuItems,
            selectedId: _showAffiliateApplication
                ? 'affiliate_application'
                : _selectedId,
            onSelect: _go,
            onExternalSelect: _navigateAcrossSubdomains,
            onSearch: _isMarketFeature
                ? _showMarketSearch
                : _isWritingFeature
                ? _showWorkspaceSearch
                : (_isCommunityFeature ? null : () => _go('search')),
            searchQuery: _isMarketFeature
                ? _marketQuery
                : _isWritingFeature
                ? _workspaceQuery
                : (_isCommunityFeature
                      ? null
                      : (_isMessagesFeature
                            ? _messagesQuery
                            : (_isAiFeature ? _aiQuery : null))),
            searchHint: _isMarketFeature
                ? 'Search market news, companies, symbols...'
                : _isWritingFeature
                ? _writingSearchHint
                : (_isCommunityFeature
                      ? null
                      : (_isMessagesFeature
                            ? 'Search conversations, traders...'
                            : (_isAiFeature
                                  ? 'Search copilot chats and prompts...'
                                  : null))),
            onSearchChanged: _isMarketFeature
                ? (value) => setState(() => _marketQuery = value)
                : _isWritingFeature
                ? _updateWorkspaceQuery
                : (_isCommunityFeature
                      ? null
                      : (_isMessagesFeature
                            ? _updateMessagesQuery
                            : (_isAiFeature ? _updateAiQuery : null))),
            searchTargetKey: _isWritingFeature ? _workspaceSearchKey : null,
            headerActions: <Widget>[_buildHeaderRoleSwitcherAction()],
            onSettings: () => _go('settings'),
            onAi: () => _go('ai_copilot'),
            onNotifications: _openNotificationsOverlay,
            onLogout: widget.onLogout,
            trader: _chromeIdentity,
            tier: tier,
            workspaceName: _effectiveRole == UserRole.customer
                ? switch (tier) {
                    AppTier.free => 'AlphaJournal Free',
                    AppTier.premium => 'AlphaJournal Basic',
                    AppTier.enterprise => 'AlphaJournal Pro',
                  }
                : navigation.workspaceName,
            tierLabel: _effectiveRole == UserRole.customer
                ? switch (tier) {
                    AppTier.free => 'Free Plan',
                    AppTier.premium => 'Basic Plan',
                    AppTier.enterprise => 'Pro Plan',
                  }
                : navigation.workspaceLabel,
            unreadNotifications: _unread,
            pageTitle: _pageTitleOverride,
            pageIcon: _pageIconOverride,
            onBack:
                context.uiRes.isMobile &&
                    _isWritingFeature &&
                    _activeSubpageOnBack != null
                ? null
                : _pageBackOverride,
            pagePlaceholderBuilder: (BuildContext context, AppNavItem item) =>
                _destinationSkeleton(item.id),
            primaryActionLabel: null,
            onPrimaryAction: null,
            onHelp: _showActiveWritingGuide,
            showStatusBadge: false,
            sidebarFooter: showMultiRoleFooter
                ? _buildDesktopPreviewControls()
                : null,
            researchPanelBuilder: null,
            hideMobileTopBar:
                _isMessagesFeature && _activeSubpageOnBack != null,
            child: _buildActivePage(),
          ),
        ),
      ],
    );

    // Intercept the Android back button / edge swipe: when a subpage (message
    // thread, community post detail, AI history panel, etc.) declares a back
    // handler via onSubpageChanged, the system back gesture should invoke that
    // handler instead of popping the root route and closing the application.
    return AdSenseScope(
      eligible: adsEligible,
      previewEligible: adsPreviewEligible,
      child: PopScope(
        canPop:
            _activeSubpageOnBack == null &&
            !_showAffiliateApplication &&
            _linkedOrigins.isEmpty &&
            _destinationHistory.isEmpty,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          if (_showAffiliateApplication) {
            setState(() => _showAffiliateApplication = false);
          } else if (_activeSubpageOnBack != null) {
            _activeSubpageOnBack?.call();
          } else {
            _goBack();
          }
        },
        child: scaffoldContent,
      ),
    );
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

/// Loads a deferred feature library on first visit and renders synchronously on
/// all subsequent rebuilds without flicker.
class _DeferredFeatureView extends StatefulWidget {
  const _DeferredFeatureView({
    required this.libraryId,
    required this.loadLibrary,
    required this.builder,
    this.placeholder,
  });

  final String libraryId;
  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;
  final Widget? placeholder;

  static final Set<String> _loaded = <String>{};
  static final Map<String, Future<void>> _inFlight = <String, Future<void>>{};

  @override
  State<_DeferredFeatureView> createState() => _DeferredFeatureViewState();
}

class _DeferredFeatureViewState extends State<_DeferredFeatureView> {
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  @override
  void didUpdateWidget(covariant _DeferredFeatureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.libraryId != widget.libraryId) {
      _ensureLoaded();
    }
  }

  void _ensureLoaded() {
    if (_DeferredFeatureView._loaded.contains(widget.libraryId)) {
      _loadFuture = null;
      return;
    }
    _loadFuture = _DeferredFeatureView._inFlight.putIfAbsent(
      widget.libraryId,
      () => Zone.root.run(widget.loadLibrary).then((_) {
        _DeferredFeatureView._loaded.add(widget.libraryId);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_DeferredFeatureView._loaded.contains(widget.libraryId)) {
      return widget.builder(context);
    }
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (BuildContext ctx, AsyncSnapshot<void> snap) {
        if (snap.connectionState == ConnectionState.done && !snap.hasError) {
          return widget.builder(ctx);
        }
        if (snap.hasError) {
          return UiEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to load section',
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onActionPressed: () {
              _DeferredFeatureView._inFlight.remove(widget.libraryId);
              setState(_ensureLoaded);
            },
          );
        }
        return widget.placeholder ?? UiSkeleton.page();
      },
    );
  }
}
