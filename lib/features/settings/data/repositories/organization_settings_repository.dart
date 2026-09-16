import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/settings/models/org_models.dart';

abstract class OrganizationSettingsRepository {
  Future<List<OrgMember>> getMembers();
  Future<void> inviteMember({required String email, required String role});
  Future<void> updateMemberRole({required String userId, required String role});
  Future<void> removeMember(String userId);
  Future<OrgBranding> getBranding();
  Future<OrgBranding> updateBranding({
    String? logoUrl,
    String? displayName,
    String? primaryColor,
  });
}

class OrganizationSettingsRepositoryImpl
    implements OrganizationSettingsRepository {
  final List<OrgMember> _members = <OrgMember>[
    OrgMember(
      userId: 'usr_org_owner',
      handle: 'nitish_admin',
      displayName: 'Nitish Kumar (Owner)',
      role: 'owner',
      avatarUrl: null,
      joinedAt: DateTime.now().subtract(const Duration(days: 365)),
    ),
    OrgMember(
      userId: 'usr_org_trader_1',
      handle: 'sarah_quant',
      displayName: 'Sarah Jenkins',
      role: 'admin',
      avatarUrl: null,
      joinedAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
  ];

  OrgBranding _branding = const OrgBranding(
    displayName: 'TradeX Institutional Alpha',
    logoUrl: null,
    primaryColor: '#00F0FF',
  );

  SupabaseClient? get _client {
    if (SupabaseConfig.isConfigured) {
      try {
        return SupabaseConfig.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? get _currentUserId => _client?.auth.currentUser?.id;

  @override
  Future<List<OrgMember>> getMembers() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List<OrgMember>.from(_members);
  }

  @override
  Future<void> inviteMember({
    required String email,
    required String role,
  }) async {
    final String handle = email.split('@').first;
    _members.add(
      OrgMember(
        userId: 'usr_org_${DateTime.now().millisecondsSinceEpoch}',
        handle: handle,
        displayName: handle,
        role: role,
        avatarUrl: null,
        joinedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateMemberRole({
    required String userId,
    required String role,
  }) async {
    final index = _members.indexWhere((m) => m.userId == userId);
    if (index != -1) {
      final old = _members[index];
      _members[index] = OrgMember(
        userId: old.userId,
        handle: old.handle,
        displayName: old.displayName,
        role: role,
        avatarUrl: old.avatarUrl,
        joinedAt: old.joinedAt,
      );
    }
  }

  @override
  Future<void> removeMember(String userId) async {
    _members.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<OrgBranding> getBranding() async {
    final client = _client;
    final userId = _currentUserId;
    if (client != null && userId != null) {
      try {
        final data = await client
            .from('organizations')
            .select('*')
            .eq('owner_id', userId)
            .maybeSingle();

        if (data != null) {
          final settings = data['settings'] as Map<String, dynamic>? ?? {};
          _branding = OrgBranding(
            displayName: data['name'] as String? ?? 'TradeX Institutional',
            logoUrl: settings['logo_url'] as String?,
            primaryColor: settings['primary_color'] as String? ?? '#00F0FF',
          );
        }
      } catch (e) {
        debugPrint('OrganizationSettingsRepositoryImpl.getBranding error: $e');
      }
    }
    return _branding;
  }

  @override
  Future<OrgBranding> updateBranding({
    String? logoUrl,
    String? displayName,
    String? primaryColor,
  }) async {
    _branding = _branding.copyWith(
      logoUrl: logoUrl ?? _branding.logoUrl,
      displayName: displayName ?? _branding.displayName,
      primaryColor: primaryColor ?? _branding.primaryColor,
    );

    final client = _client;
    final userId = _currentUserId;
    if (client != null && userId != null) {
      try {
        final slug = _branding.displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
        await client.from('organizations').upsert({
          'owner_id': userId,
          'name': _branding.displayName,
          'slug': slug,
          'settings': {
            'logo_url': _branding.logoUrl,
            'primary_color': _branding.primaryColor,
          },
        });
      } catch (e) {
        debugPrint('OrganizationSettingsRepositoryImpl.updateBranding error: $e');
      }
    }
    return _branding;
  }
}
