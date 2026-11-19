import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/settings/models/org_models.dart';

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
  String _resolveUserId() => SupabaseConfig.client?.auth.currentUser?.id ?? '';

  final List<OrgMember> _demoMembers = <OrgMember>[
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

  OrgBranding _demoBranding = const OrgBranding(
    displayName: 'AlphaJournal Workspace',
    logoUrl: null,
    primaryColor: '#00F0FF',
  );

  @override
  Future<List<OrgMember>> getMembers() async {
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final res = await client
          .from('organization_members')
          .select(
            'user_id, role, created_at, profiles(handle, display_name, avatar_url)',
          )
          .order('created_at', ascending: true);

      final List<OrgMember> list = [];
      for (final row in (res as List)) {
        final prof = row['profiles'] as Map<String, dynamic>?;
        list.add(
          OrgMember(
            userId: row['user_id'] as String,
            handle: prof?['handle'] as String? ?? 'trader',
            displayName:
                prof?['display_name'] as String? ??
                (prof?['handle'] as String? ?? 'Trader'),
            role: row['role'] as String? ?? 'trader',
            avatarUrl: prof?['avatar_url'] as String?,
            joinedAt:
                DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      }
      return list;
    }
    return List<OrgMember>.from(_demoMembers);
  }

  @override
  Future<void> inviteMember({
    required String email,
    required String role,
  }) async {
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty) {
        throw StateError('Sign in to invite team members.');
      }

      final org = await client
          .from('organizations')
          .select('id')
          .eq('owner_id', targetUserId)
          .maybeSingle();

      if (org == null) {
        throw StateError(
          'Save your organization name first before inviting members.',
        );
      }

      final invitedProfile = await client
          .from('profiles')
          .select('id')
          .ilike('email', email.trim())
          .maybeSingle();

      final invitedUserId = invitedProfile?['id'] as String?;
      if (invitedUserId == null || invitedUserId.isEmpty) {
        throw StateError('No registered account found for $email.');
      }

      await client.from('organization_members').upsert({
        'organization_id': org['id'] as String,
        'user_id': invitedUserId,
        'role': role,
      });
      return;
    }

    final String handle = email.split('@').first;
    _demoMembers.add(
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
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      await client
          .from('organization_members')
          .update({
            'role': role,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return;
    }

    final index = _demoMembers.indexWhere((m) => m.userId == userId);
    if (index != -1) {
      final old = _demoMembers[index];
      _demoMembers[index] = OrgMember(
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
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      await client.from('organization_members').delete().eq('user_id', userId);
      return;
    }
    _demoMembers.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<OrgBranding> getBranding() async {
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty) {
        return const OrgBranding(displayName: 'Organization Workspace');
      }

      final data = await client
          .from('organizations')
          .select('id, owner_id, name, slug, settings')
          .eq('owner_id', targetUserId)
          .maybeSingle();

      if (data == null) {
        return const OrgBranding(displayName: 'Organization Workspace');
      }

      final settings = data['settings'] as Map<String, dynamic>? ?? {};
      return OrgBranding(
        displayName: data['name'] as String? ?? 'Organization Workspace',
        logoUrl: settings['logo_url'] as String?,
        primaryColor: settings['primary_color'] as String? ?? '#00F0FF',
      );
    }
    return _demoBranding;
  }

  @override
  Future<OrgBranding> updateBranding({
    String? logoUrl,
    String? displayName,
    String? primaryColor,
  }) async {
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty) {
        throw StateError('Sign in to update organization branding.');
      }

      final next = (await getBranding()).copyWith(
        logoUrl: logoUrl,
        displayName: displayName,
        primaryColor: primaryColor,
      );

      final slug = next.displayName.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '-',
      );
      await client.from('organizations').upsert({
        'owner_id': targetUserId,
        'name': next.displayName,
        'slug': slug,
        'settings': {
          'logo_url': next.logoUrl,
          'primary_color': next.primaryColor,
        },
        'updated_at': DateTime.now().toIso8601String(),
      });
      return next;
    }

    _demoBranding = _demoBranding.copyWith(
      logoUrl: logoUrl ?? _demoBranding.logoUrl,
      displayName: displayName ?? _demoBranding.displayName,
      primaryColor: primaryColor ?? _demoBranding.primaryColor,
    );
    return _demoBranding;
  }
}
