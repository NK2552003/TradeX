import 'package:tradex/core/notifications/push_service.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/security/private_message_service.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/data/services/auth_session_storage.dart';
import 'package:tradex/features/auth/models/affiliate_profile_model.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';

class SupabaseAuthBackendService implements AuthRepository {
  SupabaseAuthBackendService._internal();
  static final SupabaseAuthBackendService instance =
      SupabaseAuthBackendService._internal();
  factory SupabaseAuthBackendService() => instance;

  static const String _profileColumns =
      'id, handle, email, display_name, role, status, admin_key, '
      'referral_code, referred_by_code, bio, avatar_url, experience_level, '
      'trading_style, location, website, avg_hold_duration, primary_market, '
      'top_strategy, risk_mantra, public_stats, public_journals, '
      'notification_settings, subscription_tier, followers_count, '
      'following_count, posts_count, win_rate, verified, created_at, updated_at';

  static const String _affiliateProfileColumns =
      'id, affiliate_code, tier, commission_rate, total_referrals, '
      'active_referrals, total_earnings, unpaid_balance, paid_earnings, '
      'payout_method, payout_details, status, created_at, updated_at';

  UserProfileModel? _currentUserProfile;
  AffiliateProfileModel? _currentAffiliateProfile;
  String? _pendingSignupEmail;
  String? _pendingSignupPassword;
  bool _passwordSignInPending = false;

  bool get passwordSignInPending => _passwordSignInPending;

  /// Clears any ephemeral signup password cached in memory while awaiting OTP
  /// confirmation.
  void clearPendingSignupEncryption() {
    _pendingSignupEmail = null;
    _pendingSignupPassword = null;
  }

  /// Completes automatic E2EE identity setup immediately after signup OTP
  /// confirmation using the password the user just registered with.
  Future<void> completePendingSignupEncryption([String? email]) async {
    final pendingPassword = _pendingSignupPassword;
    final pendingEmail = _pendingSignupEmail;
    _pendingSignupEmail = null;
    _pendingSignupPassword = null;
    if (pendingPassword == null || pendingPassword.isEmpty) return;
    if (email != null &&
        pendingEmail != null &&
        email.trim().toLowerCase() != pendingEmail.trim().toLowerCase()) {
      return;
    }
    await PrivateMessageService.instance.trySilentUnlockWithPassword(
      pendingPassword,
    );
  }

  UserProfileModel? get currentUserProfile =>
      _currentUserProfile ??
      (_useDemoProfile ? AuthBackendService.instance.currentUserProfile : null);

  AffiliateProfileModel? get currentAffiliateProfile =>
      _currentAffiliateProfile ??
      (_useDemoProfile
          ? AuthBackendService.instance.currentAffiliateProfile
          : null);

  bool get _useDemoProfile =>
      CustomerDataPolicy.allowDemo && !SupabaseConfig.isConfigured;

  void setCurrentProfile(
    UserProfileModel? profile, {
    AffiliateProfileModel? affiliateProfile,
  }) {
    _currentUserProfile = profile;
    _currentAffiliateProfile = affiliateProfile;
  }

  @override
  Future<int> getRegisteredUserCount() async {
    if (!SupabaseConfig.isConfigured) {
      return AuthBackendService.instance.getRegisteredUserCount();
    }
    try {
      final client = SupabaseConfig.client;
      if (client == null) return 0;
      final rows = await client
          .from('profiles')
          .select('id')
          .neq('role', 'user_admin')
          .limit(AuthRepository.maxRegisteredUsersCap + 5);
      return (rows as List).length;
    } catch (e) {
      debugPrint(
        '[SupabaseAuthBackendService] getRegisteredUserCount error: $e',
      );
      return 0;
    }
  }

  @override
  Future<bool> isSignupOpen() async {
    final count = await getRegisteredUserCount();
    return count < AuthRepository.maxRegisteredUsersCap;
  }

  @override
  Future<AuthResult> signUp({
    required UserRole role,
    required String handle,
    required String email,
    required String password,
    String? referralCode,
    String? adminKey,
  }) async {
    // 1. Sanitize & Normalize Inputs
    final cleanHandle = handle.trim().startsWith('@')
        ? handle.trim()
        : '@${handle.trim()}';
    final cleanEmail = email.trim().toLowerCase();
    final rawHandle = cleanHandle.replaceAll('@', '').toLowerCase();

    // 2. Input Validation Rules
    if (rawHandle.isEmpty || rawHandle.length < 3) {
      return AuthResult.failure(
        'Handler ID must be at least 3 characters long.',
      );
    }
    if (cleanEmail.isEmpty ||
        !cleanEmail.contains('@') ||
        !cleanEmail.contains('.')) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    if (password.length < 8) {
      return AuthResult.failure('Password must be at least 8 characters long.');
    }

    // Admin identities are provisioned privately and can only sign in.
    if (role == UserRole.userAdmin) {
      return AuthResult.failure(
        'Administrator accounts are provisioned privately. Use Admin sign in.',
        errorCode: 'admin_signup_disabled',
      );
    }

    // 3. Enforce 100-user registration capacity limit
    if (!await isSignupOpen()) {
      return AuthResult.failure(
        'Platform capacity reached (${AuthRepository.maxRegisteredUsersCap} users). New user registration is currently disabled.',
        errorCode: 'signup_capacity_reached',
      );
    }

    // 4. Delegate to local mock service if Supabase is unconfigured
    if (!SupabaseConfig.isConfigured) {
      if (!CustomerDataPolicy.allowDemo) {
        return AuthResult.failure(
          'Authentication service is unavailable. Please try again later.',
        );
      }
      debugPrint(
        '[SupabaseAuthBackendService] Explicit preview/test mode: using local auth.',
      );
      return AuthBackendService.instance.signUp(
        role: role,
        handle: cleanHandle,
        email: cleanEmail,
        password: password,
        referralCode: referralCode,
        adminKey: adminKey,
      );
    }

    final attribution = await AffiliateAttribution.load();
    final effectiveReferral = (referralCode?.trim().isNotEmpty ?? false)
        ? referralCode!.trim()
        : attribution?['code'] as String?;
    final client = SupabaseConfig.client!;

    try {
      // 5. Perform Real Supabase Auth SignUp with User Metadata
      final authResponse = await client.auth.signUp(
        email: cleanEmail,
        password: password,
        emailRedirectTo: kIsWeb ? Uri.base.origin : 'tradex://auth/callback',
        data: {
          'handle': cleanHandle,
          'role': UserRole.customer.id,
          'affiliate_application_requested': role == UserRole.affiliate,
          'display_name': cleanHandle.replaceAll('@', ''),
          'referred_by_code': effectiveReferral,
          'utm_campaign': attribution?['campaign'],
        },
      );

      final user = authResponse.user;
      if (user == null) {
        return AuthResult.failure(
          'Registration failed. Please check network connection and try again.',
        );
      }

      await AffiliateAttribution.clear();

      // 6. Fetch automatically populated user profile from 'profiles' table
      final profileData = await client
          .from('profiles')
          .select(_profileColumns)
          .eq('id', user.id)
          .maybeSingle();

      UserProfileModel userProfile;
      if (profileData != null) {
        userProfile = UserProfileModel.fromJson(profileData);
      } else {
        userProfile = UserProfileModel(
          id: user.id,
          handle: cleanHandle,
          email: cleanEmail,
          displayName: cleanHandle.replaceAll('@', ''),
          role: role == UserRole.affiliate ? UserRole.customer : role,
          status: ProfileStatus.active,
          adminKey: adminKey?.trim(),
          referralCode: 'REF-TRADEX-${user.id.substring(0, 4).toUpperCase()}',
          referredByCode: referralCode?.trim(),
          createdAt: DateTime.now(),
        );
        try {
          await client.from('profiles').upsert(userProfile.toJson());
        } catch (e) {
          debugPrint('[SupabaseAuthBackendService] Profile upsert error: $e');
        }
      }

      setCurrentProfile(userProfile);

      await AuthSessionStorage.saveSession(
        profile: userProfile,
      );

      // Affiliate profile/commission records are created by the admin approval
      // endpoint, never by the public signup path.

      final bool requiresVerification =
          authResponse.session == null && user.emailConfirmedAt == null;

      if (requiresVerification) {
        _pendingSignupEmail = cleanEmail;
        _pendingSignupPassword = password;
      } else {
        clearPendingSignupEncryption();
        await PrivateMessageService.instance.trySilentUnlockWithPassword(
          password,
        );
      }

      return AuthResult.success(
        profile: userProfile,
        affiliateProfile: _currentAffiliateProfile,
        requiresEmailVerification: requiresVerification,
        message: role == UserRole.affiliate
            ? 'Trader account created. Complete the affiliate application for review.'
            : (requiresVerification
                  ? 'Verification code dispatched to your email.'
                  : 'Successfully registered account with Supabase authentication!'),
      );
    } on AuthException catch (e) {
      return AuthResult.failure(e.message, errorCode: e.code);
    } catch (e) {
      debugPrint(
        '[SupabaseAuthBackendService] SignUp Exception: $e. Falling back to local store.',
      );
      if (!CustomerDataPolicy.allowDemo) {
        return AuthResult.failure(
          'Authentication service is unavailable. Please try again later.',
        );
      }
      return AuthBackendService.instance.signUp(
        role: role,
        handle: cleanHandle,
        email: cleanEmail,
        password: password,
        referralCode: referralCode,
        adminKey: adminKey,
      );
    }
  }

  @override
  Future<AuthResult> signIn({
    required UserRole role,
    required String emailOrHandle,
    required String password,
    String? adminKey,
  }) async {
    final cleanInput = emailOrHandle.trim();

    if (cleanInput.isEmpty) {
      return AuthResult.failure(
        'Please enter your email address or Handler ID (@handle).',
      );
    }
    if (password.isEmpty) {
      return AuthResult.failure('Please enter your password.');
    }

    if (role == UserRole.userAdmin) {
      final key = adminKey?.trim() ?? '';
      if (key.isEmpty) {
        return AuthResult.failure(
          'Master Admin Key is required for User Admin authorization.',
        );
      }
    }

    // Delegate to local mock service if Supabase is unconfigured
    if (!SupabaseConfig.isConfigured) {
      if (!CustomerDataPolicy.allowDemo) {
        return AuthResult.failure(
          'Authentication service is unavailable. Please try again later.',
        );
      }
      debugPrint(
        '[SupabaseAuthBackendService] Explicit preview/test mode: using local auth.',
      );
      return AuthBackendService.instance.signIn(
        role: role,
        emailOrHandle: cleanInput,
        password: password,
        adminKey: adminKey,
      );
    }

    final client = SupabaseConfig.client!;
    if (_passwordSignInPending) {
      return AuthResult.failure('Sign-in is already in progress.');
    }
    _passwordSignInPending = true;
    String? signedInUserId;
    var accepted = false;
    String targetEmail = cleanInput.toLowerCase();

    try {
      // 1. Resolve email by handle if input starts with @ or is not an email
      if (cleanInput.startsWith('@') || !cleanInput.contains('@')) {
        final rawHandle = cleanInput.replaceAll('@', '');
        final formattedHandle = '@$rawHandle';
        var profileRes = await client
            .from('profiles')
            .select('email')
            .ilike('handle', formattedHandle)
            .maybeSingle();
        profileRes ??= await client
            .from('profiles')
            .select('email')
            .ilike('handle', rawHandle)
            .maybeSingle();

        if (profileRes == null || profileRes['email'] == null) {
          return AuthResult.failure(
            'No account found with Handler ID $formattedHandle.',
          );
        }
        targetEmail = profileRes['email'] as String;
      }

      // 2. Perform Supabase SignIn with Password
      final authResponse = await client.auth.signInWithPassword(
        email: targetEmail,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        return AuthResult.failure(
          'Authentication failed. Please verify credentials.',
        );
      }
      signedInUserId = user.id;

      // 3. Fetch User Profile from Postgres
      final profileData = await client
          .from('profiles')
          .select(_profileColumns)
          .eq('id', user.id)
          .maybeSingle();

      UserProfileModel userProfile;
      if (profileData != null) {
        userProfile = UserProfileModel.fromJson(profileData);
      } else {
        userProfile = UserProfileModel(
          id: user.id,
          handle: (user.userMetadata?['handle'] as String?) ?? '@trader',
          email: targetEmail,
          displayName:
              (user.userMetadata?['display_name'] as String?) ?? 'Trader',
          role: UserRole.customer,
          status: ProfileStatus.active,
          createdAt: DateTime.now(),
        );
        try {
          await client.from('profiles').upsert(userProfile.toJson());
        } catch (e) {
          debugPrint(
            '[SupabaseAuthBackendService] SignIn profile upsert error: $e',
          );
        }
      }

      // 4. Validate Admin Role Requirement & Security Clearance Key
      if (role == UserRole.userAdmin) {
        if (userProfile.role != UserRole.userAdmin) {
          return AuthResult.failure(
            'Access Denied: Account lacks User Admin security clearance.',
          );
        }
        final suppliedKey = adminKey?.trim() ?? '';
        final expectedKey = userProfile.adminKey?.trim() ?? '';
        if (expectedKey.isEmpty || suppliedKey != expectedKey) {
          return AuthResult.failure(
            'Invalid Admin Security Clearance Key for this administrator account.',
          );
        }
      }

      if (role == UserRole.affiliate) {
        final application = await client
            .from('affiliate_applications')
            .select('status')
            .eq('user_id', user.id)
            .maybeSingle();
        final String status = application?['status'] as String? ?? '';
        final bool approved =
            userProfile.role == UserRole.affiliate ||
            status == 'approved' ||
            status == 'active';
        if (!approved) {
          return AuthResult.failure(
            status == 'pending' || status == 'pending_review'
                ? 'Your affiliate application is still awaiting administrator approval.'
                : 'Affiliate access requires an approved application. Sign in as Customer to apply.',
            errorCode: 'affiliate_not_approved',
          );
        }
      }

      // 5. Fetch Affiliate Profile if role is affiliate
      AffiliateProfileModel? affiliateProfile;
      if (role == UserRole.affiliate) {
        final affData = await client
            .from('affiliate_profiles')
            .select(_affiliateProfileColumns)
            .eq('id', user.id)
            .maybeSingle();

        if (affData != null) {
          affiliateProfile = AffiliateProfileModel.fromJson(affData);
        }
      }

      setCurrentProfile(userProfile, affiliateProfile: affiliateProfile);
      await AuthSessionStorage.saveSession(
        profile: userProfile,
        affiliateProfile: affiliateProfile,
      );

      clearPendingSignupEncryption();
      await PrivateMessageService.instance.trySilentUnlockWithPassword(
        password,
      );

      accepted = true;
      return AuthResult.success(
        profile: userProfile,
        affiliateProfile: affiliateProfile,
        workspaceRole: role,
        message: 'Successfully signed in with Supabase backend!',
      );
    } on AuthException catch (e) {
      final String msg = e.message.toLowerCase();
      final bool isUnconfirmed =
          msg.contains('email not confirmed') ||
          e.code == 'email_not_confirmed';
      if (isUnconfirmed) {
        try {
          await client.auth.resend(type: OtpType.signup, email: targetEmail);
        } catch (_) {}
        return AuthResult.failure(
          'Email not confirmed. A new verification code has been dispatched to your email.',
          errorCode: 'email_not_confirmed',
        );
      }
      return AuthResult.failure(e.message, errorCode: e.code);
    } catch (_) {
      return AuthResult.failure(
        'Authentication service is unavailable. Please try again later.',
      );
    } finally {
      if (!accepted &&
          signedInUserId != null &&
          client.auth.currentUser?.id == signedInUserId) {
        setCurrentProfile(null);
        try {
          await client.auth.signOut();
        } catch (_) {}
        await AuthSessionStorage.clearSession();
      }
      _passwordSignInPending = false;
    }
  }

  @override
  Future<AuthResult> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult.failure('Please enter a valid email address.');
    }

    if (!SupabaseConfig.isConfigured) {
      if (!CustomerDataPolicy.allowDemo) {
        return AuthResult.failure(
          'Authentication service is unavailable. Please try again later.',
        );
      }
      return AuthBackendService.instance.resetPassword(cleanEmail);
    }

    try {
      await SupabaseConfig.client!.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: kIsWeb
            ? '${Uri.base.origin}/auth/forgot-password'
            : 'tradex://auth/callback',
      );
      return AuthResult.success(
        profile:
            _currentUserProfile ??
            UserProfileModel(
              id: 'temp',
              handle: '@trader',
              email: cleanEmail,
              displayName: 'Trader',
              role: UserRole.customer,
              status: ProfileStatus.active,
              createdAt: DateTime.now(),
            ),
        message:
            'Password reset link has been dispatched via Supabase to $cleanEmail.',
      );
    } catch (e) {
      return AuthResult.failure('Password reset error: $e');
    }
  }

  @override
  Future<UserProfileModel?> getProfile(String userId) async {
    if (!SupabaseConfig.isConfigured) {
      return CustomerDataPolicy.allowDemo
          ? AuthBackendService.instance.getProfile(userId)
          : null;
    }
    try {
      final res = await SupabaseConfig.client!
          .from('profiles')
          .select(_profileColumns)
          .eq('id', userId)
          .maybeSingle();
      if (res != null) {
        return UserProfileModel.fromJson(res);
      }
    } catch (_) {}
    return CustomerDataPolicy.allowDemo
        ? AuthBackendService.instance.getProfile(userId)
        : null;
  }

  @override
  Future<AffiliateProfileModel?> getAffiliateProfile(String affiliateId) async {
    if (!SupabaseConfig.isConfigured) {
      return CustomerDataPolicy.allowDemo
          ? AuthBackendService.instance.getAffiliateProfile(affiliateId)
          : null;
    }
    try {
      final res = await SupabaseConfig.client!
          .from('affiliate_profiles')
          .select(_affiliateProfileColumns)
          .eq('id', affiliateId)
          .maybeSingle();
      if (res != null) {
        return AffiliateProfileModel.fromJson(res);
      }
    } catch (_) {}
    return CustomerDataPolicy.allowDemo
        ? AuthBackendService.instance.getAffiliateProfile(affiliateId)
        : null;
  }

  @override
  Future<void> signOut() async {
    try {
      await PushService.instance.disable();
    } catch (_) {}
    _currentUserProfile = null;
    _currentAffiliateProfile = null;

    await AuthSessionStorage.clearSession();

    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client!.auth.signOut();
      } catch (_) {}
    }

    await AuthBackendService.instance.signOut();
  }
}
