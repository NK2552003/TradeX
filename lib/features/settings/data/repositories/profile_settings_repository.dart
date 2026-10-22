import 'package:tradex/core/config/customer_data_policy.dart';
import 'dart:convert';
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
    String? avatarUrl,
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
  Future<void> removeAvatar();
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
  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';

  static final ProfileSettingsRepositoryImpl instance =
      ProfileSettingsRepositoryImpl._();
  ProfileSettingsRepositoryImpl._() {
    if (!CustomerDataPolicy.allowDemo) {
      _profile = UserProfileModel(
        id: '',
        handle: '',
        email: '',
        role: UserRole.customer,
        displayName: 'Your account',
      );
    }
  }
  factory ProfileSettingsRepositoryImpl() => instance;

  UserProfileModel _profile = UserProfileModel(
    id: _demoUserId,
    handle: 'demo_trader',
    email: 'demo@tradex.ai',
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

  @override
  UserProfileModel get cachedProfile =>
      _profile.copyWith(subscriptionTier: AppSession.instance.tier.value.name);

  @override
  Future<UserProfileModel> getProfile() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final res = await client
            .from('profiles')
            .select()
            .eq('id', targetUserId)
            .maybeSingle();

        if (res != null) {
          _profile = UserProfileModel.fromJson(res);
          return _profile.copyWith(
            subscriptionTier: AppSession.instance.tier.value.name,
          );
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
    String? avatarUrl,
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
    final String? effectiveAvatarUrl = avatarUrl ?? _profile.avatarUrl;
    _profile = _profile.copyWith(
      displayName: displayName,
      bio: bio,
      avatarUrl: effectiveAvatarUrl,
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
        final targetUserId = user?.id ?? _demoUserId;

        final updateData = <String, dynamic>{
          'display_name': _profile.displayName,
          'bio': _profile.bio,
          'avatar_url':
              (effectiveAvatarUrl != null && effectiveAvatarUrl.isNotEmpty)
              ? effectiveAvatarUrl
              : null,
          'experience_level': _profile.experienceLevel,
          'trading_style': _profile.tradingStyle,
          'location': _profile.location,
          'website': _profile.website,
          'avg_hold_duration': _profile.avgHoldDuration,
          'primary_market': _profile.primaryMarket,
          'top_strategy': _profile.topStrategy,
          'risk_mantra': _profile.riskMantra,
          'public_journals': _profile.publicJournals,
          'updated_at': DateTime.now().toIso8601String(),
        };

        final res = await client
            .from('profiles')
            .update(updateData)
            .eq('id', targetUserId)
            .select()
            .single();

        final fetchedProfile = UserProfileModel.fromJson(res);
        _profile = fetchedProfile.copyWith(
          avatarUrl: fetchedProfile.avatarUrl?.isNotEmpty == true
              ? fetchedProfile.avatarUrl
              : effectiveAvatarUrl,
        );
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] updateProfile error: $e');
      }
    }

    return _profile;
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType) async {
    String finalAvatarUrl = '';
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final user = client.auth.currentUser;
      final targetUserId = user?.id ?? _demoUserId;

      try {
        final ext = contentType.contains('jpeg') || contentType.contains('jpg')
            ? 'jpg'
            : 'png';
        final fileName =
            '${targetUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              imageBytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
        final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
        if (publicUrl.isNotEmpty) {
          finalAvatarUrl = publicUrl;
        }
      } catch (e) {
        debugPrint(
          '[ProfileSettingsRepository] uploadAvatar storage error: $e',
        );
      }

      if (finalAvatarUrl.isEmpty) {
        finalAvatarUrl = 'data:$contentType;base64,${base64Encode(imageBytes)}';
      }

      try {
        await client
            .from('profiles')
            .update({'avatar_url': finalAvatarUrl})
            .eq('id', targetUserId);
      } catch (e) {
        debugPrint(
          '[ProfileSettingsRepository] uploadAvatar database update error: $e',
        );
      }
    } else {
      finalAvatarUrl = 'data:$contentType;base64,${base64Encode(imageBytes)}';
    }

    _profile = _profile.copyWith(avatarUrl: finalAvatarUrl);
    return finalAvatarUrl;
  }

  @override
  Future<void> removeAvatar() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;
        await client
            .from('profiles')
            .update({'avatar_url': null})
            .eq('id', targetUserId);
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] removeAvatar error: $e');
      }
    }
    _profile = _profile.copyWith(avatarUrl: '');
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
        final email = client.auth.currentUser?.email;
        if (email == null) {
          throw StateError('Sign in before changing your email.');
        }
        await client.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
        await client.auth.updateUser(UserAttributes(email: newEmail));
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] requestEmailChange error: $e');
        rethrow;
      }
    }
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Email changes are unavailable in this environment.');
    }
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
        final email = client.auth.currentUser?.email;
        if (email == null) {
          throw StateError('Sign in before changing your password.');
        }
        await client.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
        await client.auth.updateUser(UserAttributes(password: newPassword));
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] changePassword error: $e');
        rethrow;
      }
    }
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Password changes are unavailable in this environment.');
    }
  }

  @override
  Future<List<ConnectedAccount>> getConnectedAccounts() async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured || client?.auth.currentUser == null) {
      return [];
    }
    final identities = await client!.auth.getUserIdentities();
    return [
      for (final identity in identities.where(
        (i) => i.provider == 'google' || i.provider == 'apple',
      ))
        ConnectedAccount(
          provider: identity.provider,
          linkedAt:
              DateTime.tryParse(identity.createdAt ?? '') ?? DateTime.now(),
          email: identity.identityData?['email'] as String?,
        ),
    ];
  }

  @override
  Future<void> unlinkConnectedAccount(String provider) async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured || client?.auth.currentUser == null) {
      throw StateError('Sign in to manage connected accounts.');
    }
    final identities = await client!.auth.getUserIdentities();
    final identity = identities
        .where((i) => i.provider == provider)
        .firstOrNull;
    if (identity == null) {
      throw StateError('This identity is no longer connected.');
    }
    await client.auth.unlinkIdentity(identity);
  }

  @override
  Future<void> linkConnectedAccount(String provider) async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured || client?.auth.currentUser == null) {
      throw StateError('Sign in to manage connected accounts.');
    }
    final oauth = switch (provider) {
      'google' => OAuthProvider.google,
      'apple' => OAuthProvider.apple,
      _ => throw ArgumentError('Unsupported identity provider'),
    };
    if (!await client!.auth.linkIdentity(
      oauth,
      redirectTo: kIsWeb ? null : 'tradex://auth/callback',
    )) {
      throw StateError('Could not open the identity provider. Please retry.');
    }
  }

  @override
  Future<void> requestAccountDeletion({String? reason}) async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      throw StateError('Account deletion requests are unavailable.');
    }
    // The existing backend supports a review request, not completed erasure.
    // Require a returned row so denied/no-op writes cannot report success.
    await client
        .from('profiles')
        .update({'status': 'pending_approval'})
        .eq('id', user.id)
        .select('id')
        .single();
  }
}
