import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/billing/revenuecat_billing.dart';
import 'package:tradex/core/data/session_trader.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_application_page.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/data/services/auth_session_storage.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
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
    this.onDestinationChanged,
    this.onOpenRecord,
    this.onStageChanged,
  });

  final AuthStage initialStage;
  final String? initialDestination;
  final AppLinkOpenRequest? openRequest;
  final ValueChanged<String>? onDestinationChanged;
  final ValueChanged<AppLinkRef>? onOpenRecord;
  final ValueChanged<AuthStage>? onStageChanged;
  final AuthRepository? authRepository;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late AuthSessionState _sessionState;
  late final AuthRepository _authRepository;
  bool _isAuthLoading = true;
  String _initialAppDestination = 'workspace';
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

    final AuthStage initialStage = switch (preview) {
      'application' => AuthStage.affiliateApplication,
      'pricing' || 'subscription' => AuthStage.subscription,
      'customer' || 'affiliate' || 'admin' => AuthStage.authenticated,
      _ => widget.initialStage,
    };

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

    if (preview != null) {
      _isAuthLoading = false;
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
                _sessionState =
                    _sessionState.copyWith(stage: AuthStage.forgotPassword);
              });
              widget.onStageChanged?.call(AuthStage.forgotPassword);
            }
          }
          if (event == AuthChangeEvent.signedIn &&
              (_sessionState.stage == AuthStage.login ||
                  _sessionState.stage == AuthStage.signup ||
                  _sessionState.stage == AuthStage.onboarding)) {
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
            if (mounted) {
              setState(() {
                _sessionState = _sessionState.copyWith(stage: AuthStage.login);
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[AuthWrapper] Auth listener error: $e');
    }
  }

  Future<void> _restoreActiveSession() async {
    try {
      // 1. Live Supabase Session Check
      if (SupabaseConfig.isConfigured) {
        final signedInId = SupabaseConfig.client?.auth.currentUser?.id;
        if (signedInId != null) {
          unawaited(RevenueCatBilling.identify(signedInId));
        }
        final client = SupabaseConfig.client;
        if (client != null) {
          final session = client.auth.currentSession;
          final user = client.auth.currentUser ?? session?.user;

          if (session != null && user != null) {
            // Check if current session token has expired
            if (session.isExpired) {
              try {
                final refreshRes = await client.auth.refreshSession();
                if (refreshRes.session == null) {
                  // Expired token could not be refreshed -> redirect to login
                  await AuthSessionStorage.clearSession();
                  if (mounted) {
                    setState(() {
                      _isAuthLoading = false;
                      _sessionState = _sessionState.copyWith(
                        stage: AuthStage.login,
                      );
                    });
                  }
                  return;
                }
              } catch (e) {
                debugPrint('[AuthWrapper] Token refresh failed: $e');
                await AuthSessionStorage.clearSession();
                if (mounted) {
                  setState(() {
                    _isAuthLoading = false;
                    _sessionState = _sessionState.copyWith(
                      stage: AuthStage.login,
                    );
                  });
                }
                return;
              }
            }

            // Valid active Supabase session confirmed: fetch profile
            UserProfileModel? profile = await _authRepository.getProfile(
              user.id,
            );
            profile ??= await AuthSessionStorage.getStoredProfile();

            if (profile != null && mounted) {
              final affProfile = profile.role == UserRole.affiliate
                  ? await _authRepository.getAffiliateProfile(user.id)
                  : await AuthSessionStorage.getStoredAffiliateProfile();

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

              final workspaceRole = await AuthSessionStorage.workspaceRoleFor(
                profile,
              );
              final lastDest = await AuthSessionStorage.getLastDestination();
              if (lastDest != null && lastDest.isNotEmpty) {
                _initialAppDestination = lastDest;
              }

              setState(() {
                _isAuthLoading = false;
                _sessionState = _sessionState.copyWith(
                  stage: AuthStage.authenticated,
                  userId: profile!.id,
                  email: profile.email,
                  displayName: profile.displayName,
                  role: workspaceRole,
                  profile: profile,
                  affiliateProfile: affProfile,
                );
              });
              return;
            }
          }
        }
      }

      // 2. Persistent Local Storage Fallback (offline mode / local mock store)
      final storedProfile = await AuthSessionStorage.getStoredProfile();
      if (storedProfile != null) {
        if ((!SupabaseConfig.isConfigured && CustomerDataPolicy.allowDemo) ||
            SupabaseConfig.client?.auth.currentUser != null) {
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

          if (mounted) {
            setState(() {
              _isAuthLoading = false;
              _sessionState = _sessionState.copyWith(
                stage: AuthStage.authenticated,
                userId: storedProfile.id,
                email: storedProfile.email,
                displayName: storedProfile.displayName,
                role: workspaceRole,
                profile: storedProfile,
                affiliateProfile: affProfile,
              );
            });
            return;
          }
        }
      }

      // 3. No active or valid session found -> redirect to login (or onboarding on fresh install)
      final hasSeenOnboarding =
          await AuthSessionStorage.hasCompletedOnboarding();
      if (mounted) {
        setState(() {
          _isAuthLoading = false;
          _sessionState = _sessionState.copyWith(
            stage: widget.initialStage != AuthStage.splash
                ? widget.initialStage
                : hasSeenOnboarding
                ? AuthStage.login
                : AuthStage.onboarding,
          );
        });
      }
    } catch (e) {
      debugPrint('[AuthWrapper] _restoreActiveSession caught error: $e');
      if (mounted) {
        setState(() {
          _isAuthLoading = false;
          _sessionState = _sessionState.copyWith(stage: AuthStage.login);
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AuthWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStage != widget.initialStage &&
        widget.initialStage != AuthStage.splash &&
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
    widget.onStageChanged?.call(stage);
  }

  void _handleLogout() async {
    await _authRepository.signOut();
    try {
      await RevenueCatBilling.clearIdentity();
    } catch (e) {
      debugPrint('[AuthWrapper] RevenueCat logout unavailable: $e');
    }
    await AuthSessionStorage.clearSession();
    if (mounted) {
      setState(() {
        _sessionState = _sessionState.copyWith(stage: AuthStage.login);
      });
    }
  }

  void _handleSwitchRole(UserRole newRole) {
    final profile = SupabaseAuthBackendService.instance.currentUserProfile;
    final id = profile?.id ?? _sessionState.userId;
    AuthSessionStorage.saveWorkspaceRole(id, newRole);
    setState(() {
      _sessionState = _sessionState.copyWith(role: newRole);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;

    // Route Guard Loading State:
    // Prevents flashing the login page while persistent session is being restored.
    if (_isAuthLoading) {
      return ColoredBox(
        color: colors.background,
        child: const _AuthLoadingScreen(),
      );
    }

    if (_sessionState.stage == AuthStage.splash) {
      return ColoredBox(
        color: colors.background,
        child: SplashScreen(
          onFinish: () => _navigateToStage(AuthStage.onboarding),
        ),
      );
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
                initialRole: _sessionState.role,
                authRepository: _authRepository,
                onLoginSuccess: (role, email) async {
                  await AuthSessionStorage.markOnboardingCompleted();
                  final effectiveRole = (role == UserRole.userAdmin)
                      ? (AuthBackendService.instance.currentUserProfile?.role ==
                                  UserRole.userAdmin ||
                              SupabaseAuthBackendService
                                      .instance.currentUserProfile?.role ==
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
                onVerified: (token) {
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

/// Minimalist, high-performance loading screen matching the design system
/// shown during auth session verification to prevent UI flashing.
class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoMark(size: 40, progress: 1.0),
            SizedBox(height: context.sp(theme.spacing.lg)),
            Text(
              'alphajournal',
              style: context.uiText.display.copyWith(
                fontSize: 32,
                color: colors.foreground,
                fontWeight: FontWeight.w500,
                letterSpacing: -1.0,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              'Restoring secure session...',
              style: context.uiText.caption.copyWith(
                color: colors.foregroundSubtle,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xl)),
            SizedBox(
              width: context.sz(120),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
