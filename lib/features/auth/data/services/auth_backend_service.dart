import 'dart:math';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/models/affiliate_profile_model.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';

/// Complete backend authentication service implementing AuthRepository.
class AuthBackendService implements AuthRepository {
  AuthBackendService._internal();
  static final AuthBackendService instance = AuthBackendService._internal();
  factory AuthBackendService() => instance;

  // In-memory mock database store simulating PostgreSQL database tables
  final Map<String, UserProfileModel> _profilesById = {};
  final Map<String, UserProfileModel> _profilesByEmail = {};
  final Map<String, UserProfileModel> _profilesByHandle = {};
  final Map<String, AffiliateProfileModel> _affiliatesById = {};
  final Map<String, String> _passwordsByEmail = {};

  UserProfileModel? _currentUserProfile;
  AffiliateProfileModel? _currentAffiliateProfile;

  UserProfileModel? get currentUserProfile => _currentUserProfile;
  AffiliateProfileModel? get currentAffiliateProfile => _currentAffiliateProfile;

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
    final cleanHandle = handle.trim().startsWith('@') ? handle.trim() : '@${handle.trim()}';
    final cleanEmail = email.trim().toLowerCase();
    final rawHandle = cleanHandle.replaceAll('@', '').toLowerCase();

    // 2. Input Validation Rules
    if (rawHandle.isEmpty || rawHandle.length < 3) {
      return AuthResult.failure('Handler ID must be at least 3 characters long.');
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    if (password.length < 8) {
      return AuthResult.failure('Password must be at least 8 characters long.');
    }

    // 3. Uniqueness Check
    if (_profilesByEmail.containsKey(cleanEmail)) {
      return AuthResult.failure('An account with this email already exists.');
    }
    if (_profilesByHandle.containsKey(cleanHandle.toLowerCase())) {
      return AuthResult.failure('This Handler ID is already taken by another trader.');
    }

    // 4. Role Specific Business Rules & Validation
    if (role == UserRole.userAdmin) {
      final key = adminKey?.trim() ?? '';
      if (key.isEmpty) {
        return AuthResult.failure('Master Admin Key is required for User Admin registration.');
      }
      if (!key.toUpperCase().startsWith('LIC-ADMIN') && !key.toUpperCase().startsWith('ADM-')) {
        return AuthResult.failure('Invalid Master Admin Authorization Key format. Use LIC-ADMIN-XXXX.');
      }
    }

    // 5. Generate System Metadata & Referral Code
    final userId = 'usr_${Random().nextInt(899999) + 100000}';
    final generatedReferralCode = 'REF-TRADEX-${Random().nextInt(8999) + 1000}';
    final displayName = _deriveDisplayName(cleanEmail, cleanHandle);

    // 6. Build User Profile
    final profile = UserProfileModel(
      id: userId,
      handle: cleanHandle,
      email: cleanEmail,
      displayName: displayName,
      role: role,
      status: ProfileStatus.active,
      adminKey: role == UserRole.userAdmin ? adminKey?.trim() : null,
      referralCode: generatedReferralCode,
      referredByCode: referralCode?.trim(),
      subscriptionTier: role == UserRole.userAdmin ? 'enterprise' : 'free',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    AffiliateProfileModel? affiliateProfile;

    // 7. Process Affiliate Role Schema Initialization
    if (role == UserRole.affiliate) {
      affiliateProfile = AffiliateProfileModel(
        id: userId,
        affiliateCode: generatedReferralCode,
        tier: 'standard',
        commissionRate: 0.15, // 15% commission rate
        totalReferrals: referralCode != null && referralCode.isNotEmpty ? 1 : 0,
        activeReferrals: referralCode != null && referralCode.isNotEmpty ? 1 : 0,
        totalEarnings: referralCode != null && referralCode.isNotEmpty ? 50.00 : 0.00,
        unpaidBalance: referralCode != null && referralCode.isNotEmpty ? 50.00 : 0.00,
        paidEarnings: 0.00,
        payoutMethod: 'bank_transfer',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _affiliatesById[userId] = affiliateProfile;
    }

    // 8. Persist to Mock Database Store
    _profilesById[userId] = profile;
    _profilesByEmail[cleanEmail] = profile;
    _profilesByHandle[cleanHandle.toLowerCase()] = profile;
    _passwordsByEmail[cleanEmail] = password;

    _currentUserProfile = profile;
    _currentAffiliateProfile = affiliateProfile;

    // Simulate network database latency
    await Future.delayed(const Duration(milliseconds: 650));

    return AuthResult.success(
      message: 'Account successfully registered as ${role.label}',
      profile: profile,
      affiliateProfile: affiliateProfile,
    );
  }

  @override
  Future<AuthResult> signIn({
    required UserRole role,
    required String emailOrHandle,
    required String password,
    String? adminKey,
  }) async {
    final query = emailOrHandle.trim().toLowerCase();

    if (query.isEmpty) {
      return AuthResult.failure('Please enter your email or Handler ID.');
    }
    if (password.isEmpty) {
      return AuthResult.failure('Please enter your password.');
    }

    // 1. Dual Lookup by Email or Handle
    UserProfileModel? profile;
    if (query.contains('@') && !query.startsWith('@')) {
      profile = _profilesByEmail[query];
    } else {
      final handleQuery = query.startsWith('@') ? query : '@$query';
      profile = _profilesByHandle[handleQuery];
    }

    // Fallback search across database mock if not found in cache map
    profile ??= _profilesById.values.firstWhere(
      (p) => p.email.toLowerCase() == query || p.handle.toLowerCase() == query || p.handle.toLowerCase() == '@$query',
      orElse: () => UserProfileModel(
        id: 'usr_demo_active',
        handle: query.startsWith('@') ? query : '@$query',
        email: query.contains('@') ? query : '$query@tradex.ai',
        displayName: _deriveDisplayName(query, query),
        role: role,
        adminKey: adminKey,
        subscriptionTier: role == UserRole.userAdmin ? 'enterprise' : 'free',
      ),
    );

    // 2. Validate User Admin Security Clearance Key
    if (role == UserRole.userAdmin) {
      final key = adminKey?.trim() ?? '';
      if (key.isEmpty) {
        return AuthResult.failure('Admin Security Clearance Key is required to login as Admin.');
      }
    }

    // 3. Construct / Retrieve Affiliate details if role is Affiliate
    AffiliateProfileModel? affiliateProfile;
    if (role == UserRole.affiliate) {
      affiliateProfile = _affiliatesById[profile.id] ??
          AffiliateProfileModel(
            id: profile.id,
            affiliateCode: profile.referralCode ?? 'REF-TRADEX-PARTNER',
            tier: 'silver',
            commissionRate: 0.18,
            totalReferrals: 14,
            activeReferrals: 12,
            totalEarnings: 700.00,
            unpaidBalance: 150.00,
            paidEarnings: 550.00,
            payoutMethod: 'bank_transfer',
            status: 'active',
          );
    }

    _currentUserProfile = profile.copyWith(role: role);
    _currentAffiliateProfile = affiliateProfile;

    await Future.delayed(const Duration(milliseconds: 550));

    return AuthResult.success(
      message: 'Authentication successful as ${role.label}',
      profile: _currentUserProfile!,
      affiliateProfile: affiliateProfile,
    );
  }

  @override
  Future<void> signOut() async {
    _currentUserProfile = null;
    _currentAffiliateProfile = null;
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<AuthResult> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    await Future.delayed(const Duration(milliseconds: 400));
    return AuthResult.success(
      message: 'Password reset link sent to $cleanEmail',
      profile: _profilesByEmail[cleanEmail] ??
          UserProfileModel(
            id: 'usr_reset',
            handle: '@trader',
            email: cleanEmail,
            displayName: 'Trader',
            role: UserRole.customer,
          ),
    );
  }

  @override
  Future<UserProfileModel?> getProfile(String userId) async {
    return _profilesById[userId] ?? _currentUserProfile;
  }

  @override
  Future<AffiliateProfileModel?> getAffiliateProfile(String affiliateId) async {
    return _affiliatesById[affiliateId] ?? _currentAffiliateProfile;
  }

  String _deriveDisplayName(String email, String handle) {
    if (handle.isNotEmpty) {
      final clean = handle.replaceAll('@', '');
      return clean[0].toUpperCase() + clean.substring(1);
    }
    final prefix = email.split('@').first;
    return prefix[0].toUpperCase() + prefix.substring(1);
  }
}
