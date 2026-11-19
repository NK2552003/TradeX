import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/config/cross_subdomain_storage.dart';
import 'package:alphajournal/core/security/private_message_service.dart';
import 'package:alphajournal/features/auth/models/affiliate_profile_model.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/user_profile_model.dart';

/// Caches profile and workspace preferences across reloads. The auth SDK
/// owns the session credentials.
class AuthSessionStorage {
  AuthSessionStorage._();

  static const String _keyUserId = 'auth_session_user_id';
  static const String _keyEmail = 'auth_session_email';
  static const String _keyRole = 'auth_session_role';
  static const String _keyProfile = 'auth_session_profile';
  static const String _keyAffiliateProfile = 'auth_session_affiliate_profile';
  static const String _keyToken = 'auth_session_token';
  static const String _keyTimestamp = 'auth_session_timestamp';
  static const String _keyLastDestination = 'app_scaffold_last_destination';
  static const String _keyHasSeenOnboarding = 'auth_has_seen_onboarding';

  /// Persists the authenticated user session to device / browser storage.
  static Future<void> saveSession({
    required UserProfileModel profile,
    AffiliateProfileModel? affiliateProfile,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      final sanitizedProfile = profile.adminKey != null
          ? profile.copyWith(adminKey: '')
          : profile;
      await prefs.setString(_keyUserId, sanitizedProfile.id);
      await prefs.setString(_keyEmail, sanitizedProfile.email);
      await prefs.setString(_keyRole, sanitizedProfile.role.id);
      await prefs.setString(_keyProfile, jsonEncode(sanitizedProfile.toJson()));
      await prefs.setBool(_keyHasSeenOnboarding, true);
      CrossSubdomainState.setFlag('ax_onboard', '1');

      if (affiliateProfile != null) {
        await prefs.setString(
          _keyAffiliateProfile,
          jsonEncode(affiliateProfile.toJson()),
        );
      } else {
        await prefs.remove(_keyAffiliateProfile);
      }

      await prefs.setString(_keyTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[AuthSessionStorage] Failed to save session: $e');
    }
  }

  /// Clears all stored session credentials and returns user to unauthenticated state.
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_keyUserId);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyProfile);
      await prefs.remove(_keyAffiliateProfile);
      await prefs.remove(_keyToken);
      await prefs.remove(_keyTimestamp);
      await prefs.remove(_keyLastDestination);
      if (userId != null && userId.isNotEmpty) {
        await prefs.remove('auth_workspace_role_$userId');
      }
      CrossSubdomainState.removeFlag('ax_role');
      CrossSubdomainState.removeFlag('ax_post_auth_next');
      CrossSubdomainState.removeFlag('ax_access_v1');
      await PrivateMessageService.clearLocalUnlockCache(userId: userId);
    } catch (e) {
      debugPrint('[AuthSessionStorage] Failed to clear session: $e');
    }
  }

  /// Retrieves the stored user profile if one exists.
  static Future<UserProfileModel?> getStoredProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyProfile);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserProfileModel.fromJson(map);
    } catch (e) {
      debugPrint('[AuthSessionStorage] Failed to read stored profile: $e');
      return null;
    }
  }

  /// Retrieves the stored affiliate profile if one exists.
  static Future<AffiliateProfileModel?> getStoredAffiliateProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyAffiliateProfile);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AffiliateProfileModel.fromJson(map);
    } catch (e) {
      debugPrint(
        '[AuthSessionStorage] Failed to read stored affiliate profile: $e',
      );
      return null;
    }
  }

  /// Retrieves the stored user role.
  static Future<UserRole?> getStoredRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleStr = prefs.getString(_keyRole);
      if (roleStr == null || roleStr.isEmpty) return null;
      return UserRole.fromId(roleStr);
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeLegacyToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
    } catch (_) {}
  }

  /// Remembers whether the user has finished or dismissed the onboarding flow.
  static Future<bool> hasCompletedOnboarding() async {
    try {
      if (CrossSubdomainState.getFlag('ax_onboard') == '1') {
        return true;
      }
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_keyHasSeenOnboarding) ?? false;
      if (seen) {
        CrossSubdomainState.setFlag('ax_onboard', '1');
      }
      return seen;
    } catch (_) {
      return false;
    }
  }

  /// Flags onboarding as completed.
  static Future<void> markOnboardingCompleted() async {
    CrossSubdomainState.setFlag('ax_onboard', '1');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasSeenOnboarding, true);
    } catch (_) {}
  }

  /// Saves the last active protected destination (e.g. 'journal', 'workspace').
  static Future<void> saveLastDestination(String destination) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastDestination, destination);
    } catch (_) {}
  }

  static Future<void> saveWorkspaceRole(String userId, UserRole role) async {
    if (userId.isEmpty) return;
    // Write cookie synchronously first so immediate cross-subdomain navigation
    // preserves the chosen role on the target host without waiting for async IO.
    CrossSubdomainState.setFlag('ax_role', '$userId:${role.id}');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_workspace_role_$userId', role.id);
  }

  static Future<UserRole> workspaceRoleFor(
    UserProfileModel profile, {
    bool hasAffiliateAccess = false,
  }) async {
    final bool isAdminAccount = profile.role == UserRole.userAdmin;
    final bool isAffiliateEligible =
        isAdminAccount ||
        profile.role == UserRole.affiliate ||
        hasAffiliateAccess;

    // A preference never grants partner/admin access to an ineligible account.
    if (!isAffiliateEligible && !isAdminAccount) {
      return UserRole.customer;
    }

    String? savedRoleId;
    final shared = CrossSubdomainState.getFlag('ax_role');
    if (shared != null && shared.startsWith('${profile.id}:')) {
      savedRoleId = shared.substring(profile.id.length + 1);
    } else {
      final prefs = await SharedPreferences.getInstance();
      savedRoleId = prefs.getString('auth_workspace_role_${profile.id}');
    }

    if (savedRoleId == UserRole.customer.id) {
      return UserRole.customer;
    }
    if (savedRoleId == UserRole.affiliate.id && isAffiliateEligible) {
      return UserRole.affiliate;
    }
    if (savedRoleId == UserRole.userAdmin.id && isAdminAccount) {
      return UserRole.userAdmin;
    }
    return profile.role;
  }

  /// Retrieves the last active destination.
  static Future<String?> getLastDestination() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastDestination);
    } catch (_) {
      return null;
    }
  }
}
