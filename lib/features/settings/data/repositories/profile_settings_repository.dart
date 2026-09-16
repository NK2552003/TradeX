import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/settings/models/connected_account_model.dart';

abstract class ProfileSettingsRepository {
  UserProfileModel get cachedProfile;

  Future<UserProfileModel> getProfile();
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? bio,
    String? experienceLevel,
    String? tradingStyle,
    String? location,
    String? website,
    String? avgHoldDuration,
    String? primaryMarket,
    String? topStrategy,
    String? riskMantra,
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
    location: 'Mumbai, IN',
    website: 'tradex.io/@nitish_trader',
    avgHoldDuration: '45 mins',
    primaryMarket: 'Equities & Index Options',
    topStrategy: 'ORB Breakout',
    riskMantra: 'Focus on risk management over FOMO',
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
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (res != null) {
            _profile = UserProfileModel.fromJson(res);
            return _profile.copyWith(
              subscriptionTier: AppSession.instance.tier.value.name,
            );
          }
        }
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] getProfile error: $e');
      }
    }

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
    String? location,
    String? website,
    String? avgHoldDuration,
    String? primaryMarket,
    String? topStrategy,
    String? riskMantra,
    bool? publicStatsEnabled,
  }) async {
    _profile = _profile.copyWith(
      displayName: displayName,
      bio: bio,
      experienceLevel: experienceLevel,
      tradingStyle: tradingStyle,
      location: location,
      website: website,
      avgHoldDuration: avgHoldDuration,
      primaryMarket: primaryMarket,
      topStrategy: topStrategy,
      riskMantra: riskMantra,
      publicJournals: publicStatsEnabled,
    );

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('profiles')
              .update(_profile.toJson())
              .eq('id', user.id)
              .select()
              .single();

          _profile = UserProfileModel.fromJson(res);
        }
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] updateProfile error: $e');
      }
    }

    return _profile;
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.png';
          await client.storage.from('avatars').uploadBinary(fileName, imageBytes, fileOptions: FileOptions(contentType: contentType));
          final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
          _profile = _profile.copyWith(avatarUrl: publicUrl);
          await client.from('profiles').update({'avatar_url': publicUrl}).eq('id', user.id);
          return publicUrl;
        }
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] uploadAvatar error: $e');
      }
    }
    const mockUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
    _profile = _profile.copyWith(avatarUrl: mockUrl);
    return mockUrl;
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      throw Exception('Please provide a valid email address.');
    }
    if (currentPassword.isEmpty) {
      throw Exception('Current password is required.');
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        await client.auth.updateUser(UserAttributes(email: newEmail));
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] requestEmailChange error: $e');
        rethrow;
      }
    }
    _profile = _profile.copyWith(email: newEmail);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw Exception('New password must be at least 8 characters long.');
    }
    if (currentPassword.isEmpty) {
      throw Exception('Current password cannot be empty.');
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        await client.auth.updateUser(UserAttributes(password: newPassword));
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] changePassword error: $e');
        rethrow;
      }
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
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from('profiles').update({'status': 'pending_approval'}).eq('id', user.id);
        }
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] requestAccountDeletion error: $e');
      }
    }
  }
}
