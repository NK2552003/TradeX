import 'package:tradex/core/config/cross_subdomain_storage.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/config/startup_ready.dart';
import 'package:tradex/core/security/private_message_service.dart';
import 'package:tradex/core/billing/revenuecat_billing.dart';
import 'package:tradex/core/data/session_trader.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_application_page.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/data/services/auth_session_storage.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/auth/models/affiliate_profile_model.dart';
import 'package:tradex/features/auth/models/auth_state.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/otp_purpose.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:tradex/features/auth/presentation/pages/get_started_page.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';
import 'package:tradex/features/auth/presentation/pages/otp_verification_page.dart';
import 'package:tradex/features/auth/presentation/pages/signup_page.dart';
import 'package:tradex/features/auth/presentation/pages/splash_screen.dart';
import 'package:tradex/features/auth/data/repositories/supabase_auth_otp_repository.dart';
import 'package:tradex/features/auth/presentation/pages/subscription_pricing_page.dart';

/// Central Auth Wrapper controlling the dynamic navigation flow across:
/// Splash -> Onboarding (Get Started) -> Login / Signup / Forgot Password -> Subscription -> Authenticated AppScaffold Shell.
///
/// Features persistent session restoration, route guarding with loading states
/// (eliminating login page flashing), and stateful page recovery upon reload.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({
    super.key,
    this.initialStage = AuthStage.splash,
    this.authRepository,
    this.initialDestination,
    this.openRequest,
    this.profileHandle,
    this.onDestinationChanged,
    this.onOpenRecord,
    this.onStageChanged,
    this.onRoleChanged,
    this.loginNotice,
  });

  final AuthStage initialStage;
  final String? initialDestination;
  final AppLinkOpenRequest? openRequest;
  final String? profileHandle;
  final ValueChanged<String>? onDestinationChanged;
  final ValueChanged<AppLinkRef>? onOpenRecord;
  final ValueChanged<AuthStage>? onStageChanged;
  final ValueChanged<UserRole>? onRoleChanged;

  /// Context message shown on the login screen (e.g. deep-link sign-in prompt).
  final String? loginNotice;

  static String? _pendingOAuthLinkError;

  /// Returns and clears any OAuth callback error recorded while a session was
  /// already active (for example during connected-account linking).
  static String? consumePendingOAuthError() {
    final error = _pendingOAuthLinkError;
    _pendingOAuthLinkError = null;
    return error;
  }
  final AuthRepository? authRepository;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late AuthSessionState _sessionState;
  late final AuthRepository _authRepository;
  bool _isAuthLoading = true;
  bool _splashCompleted = false;
  AuthStage? _pendingResolvedStage;
  UserProfileModel? _authenticatedProfile;
  AffiliateProfileModel? _authenticatedAffProfile;
  UserRole? _authenticatedRole;
  String _initialAppDestination = 'workspace';
  String? _oauthErrorNotice;
  int _restoreGeneration = 0;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authRepository =
        widget.authRepository ?? SupabaseAuthBackendService.instance;

    final String? preview = CustomerDataPolicy.developmentPreview(
      Uri.base,
      debug: kDebugMode,
    );

    final AuthStage resolvedStage = switch (preview) {
      'application' => AuthStage.affiliateApplication,
      'pricing' || 'subscription' => AuthStage.subscription,
      'customer' || 'affiliate' || 'admin' => AuthStage.authenticated,
      _ => widget.initialStage,
    };
    final AuthStage initialStage = (kIsWeb && resolvedStage == AuthStage.splash)
        ? AuthStage.login
        : resolvedStage;

    final String currentHost = Uri.base.host.toLowerCase();
    final UserRole? subdomainRole = CustomerRoute.requiredRoleForSubdomain(
      currentHost,
    );
    final bool isAdminDestination =
        widget.initialDestination == 'admin_console' ||
        (widget.initialDestination?.startsWith('admin_') ?? false);

    final UserRole initialRole = switch (preview) {
      'affiliate' => UserRole.affiliate,
      'admin' => UserRole.userAdmin,
      'application' => UserRole.affiliate,
      _ =>
        isAdminDestination
            ? UserRole.userAdmin
            : (subdomainRole ?? UserRole.customer),
    };

    _sessionState = AuthSessionState(
      stage: initialStage,
      role: initialRole,
      email: preview == null ? '' : 'design.preview@tradex.local',
      userId: preview == null ? '' : 'usr_design_preview',
      displayName: preview == null ? '' : 'Design Preview',
    );

    if (preview != null || kIsWeb) {
      _isAuthLoading = preview == null;
      _splashCompleted = true;
      if (preview == null) {
        _setupAuthStateListener();
        _restoreActiveSession();
      }
    } else {
      _isAuthLoading = true;
      _setupAuthStateListener();
      _restoreActiveSession();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthStateListener() {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = SupabaseConfig.client;
      if (client != null) {
        _authSubscription = client.auth.onAuthStateChange.listen((data) {
          final event = data.event;
          if (event == AuthChangeEvent.passwordRecovery) {
            if (mounted) {
              setState(() {
                _sessionState = _sessionState.copyWith(
                  stage: AuthStage.forgotPassword,
                );
              });
              widget.onStageChanged?.call(AuthStage.forgotPassword);
            }
          }
          if (event == AuthChangeEvent.signedIn &&
              (_sessionState.stage != AuthStage.authenticated ||
                  data.session?.user.id != _sessionState.userId)) {
            unawaited(
              _restoreActiveSession().then((_) {
                if (mounted && _sessionState.stage == AuthStage.authenticated) {
                  widget.onStageChanged?.call(AuthStage.authenticated);
                }
              }),
            );
          }
          if (event == AuthChangeEvent.signedIn &&
              data.session?.user.id != null) {
            unawaited(RevenueCatBilling.identify(data.session!.user.id));
          }
          if (event == AuthChangeEvent.signedOut &&
              _sessionState.stage != AuthStage.forgotPassword) {
            _resetToLoggedOutState();
          }
        });
      }
    } catch (e) {
      debugPrint('[AuthWrapper] Auth listener error: $e');
    }
  }

  void _resolveTo(AuthStage stage) {
    _pendingResolvedStage = stage;
    if (_splashCompleted || widget.initialStage != AuthStage.splash || kIsWeb) {
      _applyPendingStage();
    }
  }

  void _onSplashFinish() {
    _splashCompleted = true;
    if (_pendingResolvedStage != null) {
      _applyPendingStage();
    }
  }

  void _applyPendingStage() {
    if (!mounted) return;
    final stage = _pendingResolvedStage ?? AuthStage.login;
    setState(() {
      _isAuthLoading = false;
      if (stage == AuthStage.authenticated && _authenticatedProfile != null) {
        _sessionState = _sessionState.copyWith(
          stage: AuthStage.authenticated,
          userId: _authenticatedProfile!.id,
          email: _authenticatedProfile!.email,
          displayName: _authenticatedProfile!.displayName,
          role: _authenticatedRole ?? _sessionState.role,
          profile: _authenticatedProfile,
          affiliateProfile: _authenticatedAffProfile,
        );
      } else {
        _sessionState = _sessionState.copyWith(stage: stage);
      }
    });
    if (stage == AuthStage.authenticated) {
      widget.onRoleChanged?.call(_sessionState.role);
      widget.onStageChanged?.call(AuthStage.authenticated);
    }
  }

  String _sanitizeOAuthHandle(User user, {bool withSuffix = false}) {
    final userMeta = user.userMetadata ?? <String, dynamic>{};
    final email = user.email ?? '';
    final rawCandidate =
        (userMeta['user_name'] as String?) ??
        (userMeta['preferred_username'] as String?) ??
        (email.isNotEmpty ? email.split('@').first : null) ??
        (userMeta['full_name'] as String?) ??
        (userMeta['name'] as String?) ??
        '';
    var normalized = rawCandidate
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'^@+'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final suffix = user.id.replaceAll('-', '').substring(0, 6).toLowerCase();
    if (normalized.length < 3) {
      normalized = 'trader_$suffix';
    } else if (withSuffix) {
      final prefix = normalized.length > 20
          ? normalized.substring(0, 20)
          : normalized;
      normalized = '${prefix}_$suffix';
    }
    return '@$normalized';
  }

  Future<UserProfileModel> _ensureOAuthUserProfile(
    SupabaseClient client,
    User user,
  ) async {
    try {
      await client.rpc('ensure_own_profile');
    } catch (e) {
      debugPrint('[AuthWrapper] ensure_own_profile rpc skipped: $e');
    }

    final existing = await _authRepository.getProfile(user.id);
    if (existing != null) return existing;

    final userMeta = user.userMetadata ?? <String, dynamic>{};
    final email = user.email ?? '';
    final fullName =
        (userMeta['full_name'] as String?) ??
        (userMeta['name'] as String?) ??
        (email.isNotEmpty ? email.split('@').first : 'Trader');
    final avatar =
        (userMeta['avatar_url'] as String?) ??
        (userMeta['picture'] as String?);
    final referralSuffix = user.id.replaceAll('-', '').substring(0, 6).toUpperCase();
    var handle = _sanitizeOAuthHandle(user);

    for (final useUniqueSuffix in const <bool>[false, true]) {
      handle = _sanitizeOAuthHandle(user, withSuffix: useUniqueSuffix);
      try {
        await client.from('profiles').upsert({
          'id': user.id,
          'email': email,
          'display_name': fullName,
          'handle': handle,
          'role': 'customer',
          'status': 'active',
          'referral_code': 'REF-TRADEX-$referralSuffix',
          'avatar_url': avatar,
          'updated_at': DateTime.now().toIso8601String(),
        });
        break;
      } catch (e) {
        debugPrint(
          '[AuthWrapper] Auto-upsert profile warning (suffix=$useUniqueSuffix): $e',
        );
      }
    }

    final verified = await _authRepository.getProfile(user.id);
    if (verified != null) return verified;

    return UserProfileModel(
      id: user.id,
      email: email,
      displayName: fullName,
      handle: handle,
      role: UserRole.customer,
      status: ProfileStatus.active,
      referralCode: 'REF-TRADEX-$referralSuffix',
      avatarUrl: avatar,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _restoreActiveSession() async {
    final int gen = ++_restoreGeneration;
    try {
      // 0. On Web, if URL contains OAuth callback code or access token, exchange it first:
      if (kIsWeb && SupabaseConfig.isConfigured) {
        final uri = Uri.base;
        final fragmentParams = uri.fragment.contains('=')
            ? Uri.splitQueryString(uri.fragment)
            : const <String, String>{};
        final oauthError =
            uri.queryParameters['error_description'] ??
            uri.queryParameters['error'] ??
            fragmentParams['error_description'] ??
            fragmentParams['error'];
        final hasActiveSession =
            SupabaseConfig.client?.auth.currentSession != null;
        if (oauthError != null && oauthError.isNotEmpty) {
          if (hasActiveSession) {
            AuthWrapper._pendingOAuthLinkError = oauthError;
          } else {
            _oauthErrorNotice = oauthError;
          }
        }
        final hasOAuthPayload =
            uri.queryParameters.containsKey('code') ||
            (uri.fragment.isNotEmpty && uri.fragment.contains('access_token='));
        if (hasOAuthPayload) {
          try {
            await SupabaseConfig.client?.auth.getSessionFromUrl(uri);
          } catch (e) {
            debugPrint('[AuthWrapper] getSessionFromUrl error: $e');
          }
        }
      }
      if (!mounted || gen != _restoreGeneration) return;

      // 1. Live Supabase Session Check
      if (SupabaseConfig.isConfigured) {
        final client = SupabaseConfig.client;
        if (client != null) {
          final session = client.auth.currentSession;
          final user = client.auth.currentUser ?? session?.user;

          if (session != null && user != null) {
            // Check if current session token has expired
            if (session.isExpired) {
              try {
                final refreshRes = await client.auth.refreshSession();
                if (!mounted || gen != _restoreGeneration) return;
                if (refreshRes.session == null) {
                  // Expired token could not be refreshed -> redirect to login
                  await AuthSessionStorage.clearSession();
                  _resolveTo(AuthStage.login);
                  return;
                }
              } catch (e) {
                debugPrint('[AuthWrapper] Token refresh failed: $e');
                if (!mounted || gen != _restoreGeneration) return;
                await AuthSessionStorage.clearSession();
                _resolveTo(AuthStage.login);
                return;
              }
            }

            final signedInId = user.id;
            _oauthErrorNotice = null;
            unawaited(RevenueCatBilling.identify(signedInId));
            unawaited(PrivateMessageService.instance.warmFromCache());

            // Valid active Supabase session confirmed: fetch profile, or ignore
            // stale cached profile if a different account just signed in.
            UserProfileModel? profile = await _authRepository.getProfile(
              user.id,
            );
            if (!mounted || gen != _restoreGeneration) return;
            if (profile == null) {
              final storedProfile = await AuthSessionStorage.getStoredProfile();
              if (storedProfile?.id == user.id) {
                profile = storedProfile;
              }
            }

            // Provision DB profile cleanly for brand-new Google OAuth users
            // (handling handle collisions so FK/RLS checks never block them).
            profile ??= await _ensureOAuthUserProfile(client, user);
            if (!mounted || gen != _restoreGeneration) return;

            final affProfile = profile.role == UserRole.affiliate
                ? await _authRepository.getAffiliateProfile(user.id)
                : await AuthSessionStorage.getStoredAffiliateProfile().then(
                    (stored) => stored?.id == user.id ? stored : null,
                  );
            if (!mounted || gen != _restoreGeneration) return;

            // Synchronize process-wide services
            SupabaseAuthBackendService.instance.setCurrentProfile(
              profile,
              affiliateProfile: affProfile,
            );
            AuthBackendService.instance.setCurrentProfile(
              profile,
              affiliateProfile: affProfile,
            );

            // Update persistent session storage
            await AuthSessionStorage.saveSession(
              profile: profile,
              affiliateProfile: affProfile,
              token: client.auth.currentSession?.accessToken,
            );

            var workspaceRole = await AuthSessionStorage.workspaceRoleFor(
              profile,
            );
            final currentSubdomain = kIsWeb
                ? CustomerRoute.subdomainFromHost(Uri.base.host)
                : CustomerSubdomain.root;
            if (currentSubdomain == CustomerSubdomain.app &&
                workspaceRole != UserRole.userAdmin) {
              workspaceRole = UserRole.customer;
            } else if (currentSubdomain == CustomerSubdomain.affiliate &&
                profile.role == UserRole.affiliate) {
              workspaceRole = UserRole.affiliate;
            } else if (currentSubdomain == CustomerSubdomain.admin &&
                profile.role == UserRole.userAdmin) {
              workspaceRole = UserRole.userAdmin;
            }
            final lastDest = await AuthSessionStorage.getLastDestination();
            if (lastDest != null && lastDest.isNotEmpty) {
              _initialAppDestination = lastDest;
            }

            _authenticatedProfile = profile;
            _authenticatedAffProfile = affProfile;
            _authenticatedRole = workspaceRole;

            _resolveTo(AuthStage.authenticated);
            return;
          }
        }
      }

      // 2. Persistent Local Storage Fallback (offline mode / local mock store)
      final storedProfile = await AuthSessionStorage.getStoredProfile();
      if (storedProfile != null) {
        final token = await AuthSessionStorage.getStoredToken();
        if (token != null ||
            (!SupabaseConfig.isConfigured && CustomerDataPolicy.allowDemo)) {
          final affProfile =
              await AuthSessionStorage.getStoredAffiliateProfile();

          SupabaseAuthBackendService.instance.setCurrentProfile(
            storedProfile,
            affiliateProfile: affProfile,
          );
          AuthBackendService.instance.setCurrentProfile(
            storedProfile,
            affiliateProfile: affProfile,
          );

          final workspaceRole = await AuthSessionStorage.workspaceRoleFor(
            storedProfile,
          );
          final lastDest = await AuthSessionStorage.getLastDestination();
          if (lastDest != null && lastDest.isNotEmpty) {
            _initialAppDestination = lastDest;
          }

          _authenticatedProfile = storedProfile;
          _authenticatedAffProfile = affProfile;
          _authenticatedRole = workspaceRole;

          _resolveTo(AuthStage.authenticated);
          return;
        }
      }

      // 3. No active or valid session found -> redirect to login (or onboarding on fresh install)
      final hasSeenOnboarding =
          await AuthSessionStorage.hasCompletedOnboarding();
      final targetStage = widget.initialStage != AuthStage.splash
          ? widget.initialStage
          : hasSeenOnboarding
          ? AuthStage.login
          : AuthStage.onboarding;

      _resolveTo(targetStage);
    } catch (e) {
      debugPrint('[AuthWrapper] _restoreActiveSession caught error: $e');
      _resolveTo(AuthStage.login);
    }
  }

  @override
  void didUpdateWidget(covariant AuthWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStage != widget.initialStage &&
        widget.initialStage != AuthStage.splash &&
        _sessionState.stage != AuthStage.authenticated &&
        !_isAuthLoading) {
      _sessionState = _sessionState.copyWith(stage: widget.initialStage);
    }
  }

  void _navigateToStage(AuthStage stage, {UserRole? role, String? email}) {
    final activeService = SupabaseAuthBackendService.instance;
    if (stage == AuthStage.authenticated && role != null) {
      AuthSessionStorage.saveWorkspaceRole(
        activeService.currentUserProfile?.id ?? _sessionState.userId,
        role,
      );
    }
    setState(() {
      _sessionState = _sessionState.copyWith(
        stage: stage,
        role: role ?? _sessionState.role,
        email: email ?? _sessionState.email,
        profile: activeService.currentUserProfile,
        affiliateProfile: activeService.currentAffiliateProfile,
      );
    });
    widget.onRoleChanged?.call(_sessionState.role);
    widget.onStageChanged?.call(stage);
  }

  void _resetToLoggedOutState({UserRole? preservedRole}) {
    _restoreGeneration++;
    _authenticatedProfile = null;
    _authenticatedAffProfile = null;
    _authenticatedRole = null;
    _pendingResolvedStage = AuthStage.login;
    _initialAppDestination = 'workspace';
    SupabaseAuthBackendService.instance.setCurrentProfile(
      null,
      affiliateProfile: null,
    );
    AuthBackendService.instance.setCurrentProfile(
      null,
      affiliateProfile: null,
    );
    CrossSubdomainState.removeFlag('ax_silent_nav');
    final nextRole =
        preservedRole ??
        (_sessionState.role == UserRole.userAdmin
            ? UserRole.userAdmin
            : UserRole.customer);
    if (!mounted) return;
    setState(() {
      _isAuthLoading = false;
      _splashCompleted = true;
      _sessionState = AuthSessionState(stage: AuthStage.login, role: nextRole);
    });
    widget.onRoleChanged?.call(nextRole);
    widget.onStageChanged?.call(AuthStage.login);
  }

  Future<void> _handleLogout() async {
    _restoreGeneration++;
    SupabaseAuthBackendService.instance.clearPendingSignupEncryption();
    try {
      await _authRepository.signOut();
    } catch (e) {
      debugPrint('[AuthWrapper] signOut error: $e');
    }
    try {
      await RevenueCatBilling.clearIdentity();
    } catch (e) {
      debugPrint('[AuthWrapper] RevenueCat logout unavailable: $e');
    }
    await AuthSessionStorage.clearSession();
    _resetToLoggedOutState();
  }

  void _handleSwitchRole(UserRole newRole) {
    final profile = SupabaseAuthBackendService.instance.currentUserProfile;
    final id = profile?.id ?? _sessionState.userId;
    AuthSessionStorage.saveWorkspaceRole(id, newRole);
    setState(() {
      _sessionState = _sessionState.copyWith(role: newRole);
    });
    widget.onRoleChanged?.call(newRole);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;

    // Keep the same brand splash visible until session restoration resolves.
    // Completing its animation never bypasses the pending authentication check.
    if (_isAuthLoading || _sessionState.stage == AuthStage.splash) {
      return ColoredBox(
        color: colors.background,
        child: SplashScreen(onFinish: _onSplashFinish),
      );
    }

    if (_sessionState.stage != AuthStage.authenticated ||
        !SupabaseConfig.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) finishWebStartup();
      });
    }

    if (_sessionState.stage == AuthStage.authenticated &&
        !SupabaseConfig.isConfigured &&
        !CustomerDataPolicy.allowDemo) {
      return const UiEmptyState(
        title: 'Customer service unavailable',
        message:
            'The server connection is not configured. Please try again after configuration is restored.',
      );
    }
    final activeProfile =
        _sessionState.profile ??
        SupabaseAuthBackendService.instance.currentUserProfile;

    final Widget stageWidget = KeyedSubtree(
      key: ValueKey<AuthStage>(_sessionState.stage),
      child: Builder(
        builder: (context) {
          switch (_sessionState.stage) {
            case AuthStage.splash:
              return const SizedBox.shrink();

            case AuthStage.onboarding:
              return AppBlurFade(
                child: GetStartedPage(
                  onGetStarted: (role) async {
                    AuthSessionStorage.markOnboardingCompleted();
                    final open = await _authRepository.isSignupOpen();
                    if (!context.mounted) return;
                    if (!open) {
                      UiToast.warning(
                        context,
                        title: 'Registration Capacity Reached',
                        message:
                            'Maximum capacity of ${AuthRepository.maxRegisteredUsersCap} users reached. Please sign in with an existing account.',
                      );
                      _navigateToStage(AuthStage.login, role: role);
                      return;
                    }
                    _navigateToStage(AuthStage.signup, role: role);
                  },
                  onSignIn: () {
                    AuthSessionStorage.markOnboardingCompleted();
                    _navigateToStage(AuthStage.login);
                  },
                  onViewFullPricing: () =>
                      _navigateToStage(AuthStage.subscription),
                ),
              );

            case AuthStage.login:
              return LoginPage(
                notice: _oauthErrorNotice ?? widget.loginNotice,
                initialRole: _sessionState.role,
                authRepository: _authRepository,
                onLoginSuccess: (role, email) async {
                  await AuthSessionStorage.markOnboardingCompleted();
                  final effectiveRole = (role == UserRole.userAdmin)
                      ? (AuthBackendService.instance.currentUserProfile?.role ==
                                    UserRole.userAdmin ||
                                SupabaseAuthBackendService
                                        .instance
                                        .currentUserProfile
                                        ?.role ==
                                    UserRole.userAdmin
                            ? UserRole.userAdmin
                            : UserRole.customer)
                      : role;
                  _navigateToStage(
                    AuthStage.authenticated,
                    role: effectiveRole,
                    email: email,
                  );
                },
                onRequiresVerification: (role, email) {
                  _navigateToStage(
                    AuthStage.signupVerification,
                    role: role,
                    email: email,
                  );
                },
                onNavigateToSignup: (role) {
                  _navigateToStage(AuthStage.signup, role: role);
                },
                onNavigateToForgotPassword: () {
                  _navigateToStage(AuthStage.forgotPassword);
                },
                onNavigateBack: () => _navigateToStage(AuthStage.onboarding),
              );

            case AuthStage.signup:
              return SignupPage(
                initialRole: _sessionState.role,
                authRepository: _authRepository,
                onSignupSuccess:
                    (role, email, {bool requiresVerification = false}) {
                      if (requiresVerification) {
                        _navigateToStage(
                          AuthStage.signupVerification,
                          role: role,
                          email: email,
                        );
                      } else {
                        _navigateToStage(
                          role == UserRole.affiliate
                              ? AuthStage.affiliateApplication
                              : AuthStage.subscription,
                          role: role,
                          email: email,
                        );
                      }
                    },
                onNavigateToLogin: (role) {
                  _navigateToStage(AuthStage.login, role: role);
                },
                onNavigateBack: () => _navigateToStage(AuthStage.onboarding),
              );

            case AuthStage.signupVerification:
              return OtpVerificationPage(
                identifier: _sessionState.email,
                purpose: OtpPurpose.signupVerification,
                repository: SupabaseAuthOtpRepository(),
                onVerified: (token) async {
                  await SupabaseAuthBackendService.instance
                      .completePendingSignupEncryption(_sessionState.email);
                  _navigateToStage(
                    _sessionState.role == UserRole.affiliate
                        ? AuthStage.affiliateApplication
                        : AuthStage.subscription,
                    role: _sessionState.role,
                    email: _sessionState.email,
                  );
                },
                onBack: () => _navigateToStage(
                  AuthStage.signup,
                  role: _sessionState.role,
                ),
              );

            case AuthStage.affiliateApplication:
              return AffiliateApplicationPage(
                userId: activeProfile?.id ?? _sessionState.userId,
                email: activeProfile?.email ?? _sessionState.email,
                displayName:
                    activeProfile?.displayName ?? _sessionState.displayName,
                onCancel: () => _navigateToStage(
                  AuthStage.subscription,
                  role: UserRole.customer,
                ),
                onDone: () => _navigateToStage(
                  AuthStage.subscription,
                  role: UserRole.customer,
                ),
              );

            case AuthStage.subscription:
              return SubscriptionPricingPage(
                isPostSignup: true,
                onBack: () => _navigateToStage(AuthStage.onboarding),
                onContinue: () => _navigateToStage(
                  AuthStage.authenticated,
                  role: _sessionState.role,
                  email: _sessionState.email,
                ),
              );

            case AuthStage.forgotPassword:
              return ForgotPasswordPage(
                authRepository: _authRepository,
                onBackToLogin: () => _navigateToStage(AuthStage.login),
              );

            case AuthStage.authenticated:
              final String host = Uri.base.host.toLowerCase();
              final bool isAdminUser =
                  _sessionState.role == UserRole.userAdmin ||
                  activeProfile?.role == UserRole.userAdmin ||
                  (activeProfile?.adminKey?.trim().isNotEmpty ?? false);
              final bool isAffiliateUser =
                  isAdminUser ||
                  _sessionState.role == UserRole.affiliate ||
                  activeProfile?.role == UserRole.affiliate ||
                  (_sessionState.affiliateProfile != null);
              final String requestedDest =
                  widget.initialDestination ?? _initialAppDestination;

              if ((host.startsWith('admin.') ||
                      requestedDest == 'admin_console' ||
                      requestedDest.startsWith('admin_')) &&
                  !isAdminUser) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) finishWebStartup();
                });
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: UiEmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Administrator Access Required',
                      message:
                          'The Admin Console (admin.alphajournal.in) is restricted to verified institutional administrators. Please sign in with an authorized Admin account and Admin Key.',
                      action: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UiButton(
                            label: 'Sign In as Admin',
                            variant: UiVariant.solid,
                            intent: UiIntent.primary,
                            onPressed: () {
                              _handleLogout();
                              setState(() {
                                _sessionState = _sessionState.copyWith(
                                  stage: AuthStage.login,
                                  role: UserRole.userAdmin,
                                );
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          UiButton(
                            label: 'Open Trader Workspace',
                            variant: UiVariant.outline,
                            onPressed: () {
                              widget.onDestinationChanged?.call('workspace');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final String safeInitialDestination =
                  (requestedDest.startsWith('affiliate_') &&
                      requestedDest != 'affiliate_application' &&
                      !isAffiliateUser)
                  ? 'affiliate_application'
                  : (host.startsWith('affiliate.') &&
                          requestedDest == 'affiliate_application' &&
                          isAffiliateUser &&
                          Uri.base.path == '/')
                      ? 'overview'
                      : requestedDest;

              return AppScaffold(
                userRole: _sessionState.role,
                userId: activeProfile?.id ?? _sessionState.userId,
                userDisplayName:
                    activeProfile?.displayName ?? _sessionState.displayName,
                subscriptionTier: appTierFromId(
                  activeProfile?.subscriptionTier ?? '',
                ),
                userEmail: activeProfile?.email ?? _sessionState.email,
                initialDestination: safeInitialDestination,
                initialOpenRequest: widget.openRequest,
                profileHandle: widget.profileHandle,
                onDestinationChanged: widget.onDestinationChanged,
                onOpenRecord: widget.onOpenRecord,
                onLogout: _handleLogout,
                onRoleChanged: _handleSwitchRole,
                onReturnToAuth: () => _navigateToStage(AuthStage.login),
              );
          }
        },
      ),
    );

    return ColoredBox(
      color: colors.background,
      child: UiStaggeredPageTransition(child: stageWidget),
    );
  }
}
