import 'package:flutter/foundation.dart';
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
  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';

  final List<OrgMember> _members = <OrgMember>[
    OrgMember(
      userId: '00000000-0000-0000-0000-000000000001',
      handle: 'nitish_admin',
      displayName: 'Nitish Kumar (Owner)',
      role: 'owner',
      avatarUrl: null,
      joinedAt: DateTime.now().subtract(const Duration(days: 365)),
    ),
    OrgMember(
      userId: '00000000-0000-0000-0000-000000000002',
      handle: 'sarah_quant',
      displayName: 'Sarah Jenkins',
      role: 'admin',
      avatarUrl: null,
      joinedAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
    OrgMember(
      userId: '00000000-0000-0000-0000-000000000003',
      handle: 'marcus_trader',
      displayName: 'Marcus Vance',
      role: 'trader',
      avatarUrl: null,
      joinedAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];

  OrgBranding _branding = const OrgBranding(
    displayName: 'TradeX Institutional Alpha',
    logoUrl: null,
    primaryColor: '#00F0FF',
  );

  @override
  Future<List<OrgMember>> getMembers() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('organization_members')
            .select('user_id, role, created_at, profiles(handle, display_name, avatar_url)')
            .order('created_at', ascending: true);

        if ((res as List).isNotEmpty) {
          final list = <OrgMember>[];
          for (final item in res) {
            final profilesMap = item['profiles'] as Map<String, dynamic>? ?? {};
            list.add(
              OrgMember(
                userId: item['user_id'] as String,
                handle: profilesMap['handle'] as String? ?? 'trader',
                displayName: profilesMap['display_name'] as String? ?? profilesMap['handle'] as String? ?? 'Trader',
                role: item['role'] as String? ?? 'trader',
                avatarUrl: profilesMap['avatar_url'] as String?,
                joinedAt: DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now(),
              ),
            );
          }
          return list;
        }
      } catch (e) {
        debugPrint('OrganizationSettingsRepositoryImpl.getMembers error: $e');
      }
    }
    return List<OrgMember>.from(_members);
  }

  @override
  Future<void> inviteMember({
    required String email,
    required String role,
  }) async {
    final String handle = email.split('@').first;
    final newMember = OrgMember(
      userId: 'usr_org_${DateTime.now().millisecondsSinceEpoch}',
      handle: handle,
      displayName: handle,
      role: role,
      avatarUrl: null,
      joinedAt: DateTime.now(),
    );
    _members.add(newMember);

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final org = await client
            .from('organizations')
            .select('id')
            .eq('owner_id', targetUserId)
            .maybeSingle();

        if (org != null) {
          final orgId = org['id'] as String;
          await client.from('organization_members').upsert({
            'organization_id': orgId,
            'user_id': targetUserId,
            'role': role,
          });
        }
      } catch (e) {
        debugPrint('OrganizationSettingsRepositoryImpl.inviteMember error: $e');
      }
    }
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

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('organization_members')
            .update({'role': role, 'updated_at': DateTime.now().toIso8601String()})
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('OrganizationSettingsRepositoryImpl.updateMemberRole error: $e');
      }
    }
  }

  @override
  Future<void> removeMember(String userId) async {
    _members.removeWhere((m) => m.userId == userId);
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('organization_members')
            .delete()
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('OrganizationSettingsRepositoryImpl.removeMember error: $e');
      }
    }
  }

  @override
  Future<OrgBranding> getBranding() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final data = await client
            .from('organizations')
            .select('*')
            .eq('owner_id', targetUserId)
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

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final slug = _branding.displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
        await client.from('organizations').upsert({
          'owner_id': targetUserId,
          'name': _branding.displayName,
          'slug': slug,
          'settings': {
            'logo_url': _branding.logoUrl,
            'primary_color': _branding.primaryColor,
          },
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('OrganizationSettingsRepositoryImpl.updateBranding error: $e');
      }
    }
    return _branding;
  }
}
