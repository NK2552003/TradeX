import 'dart:typed_data';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/settings/models/connected_account_model.dart';

abstract class ProfileSettingsRepository {
  /// The profile as last known, without waiting on the wire. Chrome that has to
  /// paint on the first frame — the top-bar avatar, the sidebar footer — reads
  /// this so it never shows a blank identity while [getProfile] is in flight.
  UserProfileModel get cachedProfile;

  Future<UserProfileModel> getProfile();
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? bio,
    String? experienceLevel,
    String? tradingStyle,
    bool? publicStatsEnabled,
  });
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType);
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<List<ConnectedAccount>> getConnectedAccounts();
  Future<void> unlinkConnectedAccount(String provider);
  Future<void> linkConnectedAccount(String provider);
  Future<void> requestAccountDeletion({String? reason});
}

class ProfileSettingsRepositoryImpl implements ProfileSettingsRepository {
  UserProfileModel _profile = UserProfileModel(
    id: 'usr_mock_01',
    handle: 'nitish_trader',
    email: 'nitish@tradex.ai',
    displayName: 'Nitish Kumar',
    role: UserRole.customer,
    bio:
        'Quantitative momentum trader focused on US Equities and Crypto breakouts.',
    avatarUrl: null,
    experienceLevel: 'Advanced (3-5 years)',
    tradingStyle: 'Swing Trading',
    publicJournals: true,
    createdAt: DateTime.now().subtract(const Duration(days: 180)),
  );

  final List<ConnectedAccount> _connectedAccounts = <ConnectedAccount>[
    ConnectedAccount(
      provider: 'google',
      linkedAt: DateTime.now().subtract(const Duration(days: 90)),
      email: 'nitish@tradex.ai',
    ),
    ConnectedAccount(
      provider: 'apple',
      linkedAt: DateTime.now().subtract(const Duration(days: 45)),
      email: 'nitish@privaterelay.appleid.com',
    ),
  ];

  @override
  UserProfileModel get cachedProfile =>
      _profile.copyWith(subscriptionTier: AppSession.instance.tier.value.name);

  @override
  Future<UserProfileModel> getProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // The plan is entitlement, not profile copy: read it from the shared
    // session so a change made on the billing page is visible here too.
    return _profile.copyWith(
      subscriptionTier: AppSession.instance.tier.value.name,
    );
  }

  @override
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? bio,
    String? experienceLevel,
    String? tradingStyle,
    bool? publicStatsEnabled,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _profile = _profile.copyWith(
      displayName: displayName,
      bio: bio,
      experienceLevel: experienceLevel,
      tradingStyle: tradingStyle,
      publicJournals: publicStatsEnabled,
    );
    return _profile;
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final mockUrl =
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
    _profile = _profile.copyWith(avatarUrl: mockUrl);
    return mockUrl;
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      throw Exception('Please provide a valid email address.');
    }
    if (currentPassword.isEmpty) {
      throw Exception('Current password is required.');
    }
    _profile = _profile.copyWith(email: newEmail);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (newPassword.length < 8) {
      throw Exception('New password must be at least 8 characters long.');
    }
    if (currentPassword.isEmpty) {
      throw Exception('Current password cannot be empty.');
    }
  }

  @override
  Future<List<ConnectedAccount>> getConnectedAccounts() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<ConnectedAccount>.from(_connectedAccounts);
  }

  @override
  Future<void> unlinkConnectedAccount(String provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _connectedAccounts.removeWhere((a) => a.provider == provider);
  }

  @override
  Future<void> linkConnectedAccount(String provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _connectedAccounts.add(
      ConnectedAccount(
        provider: provider,
        linkedAt: DateTime.now(),
        email: 'nitish@${provider == 'apple' ? 'icloud.com' : 'gmail.com'}',
      ),
    );
  }

  @override
  Future<void> requestAccountDeletion({String? reason}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }
}
