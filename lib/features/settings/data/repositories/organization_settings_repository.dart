import 'package:tradex/features/settings/models/org_models.dart';

abstract class OrganizationSettingsRepository {
  Future<List<OrgMember>> getMembers();
  Future<void> inviteMember({required String email, required String role});
  Future<void> updateMemberRole({required String userId, required String role});
  Future<void> removeMember(String userId);
  Future<OrgBranding> getBranding();
  Future<OrgBranding> updateBranding({String? logoUrl, String? displayName, String? primaryColor});
}

class OrganizationSettingsRepositoryImpl implements OrganizationSettingsRepository {
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
    OrgMember(
      userId: 'usr_org_trader_2',
      handle: 'marcus_fx',
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List<OrgMember>.from(_members);
  }

  @override
  Future<void> inviteMember({required String email, required String role}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
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
  Future<void> updateMemberRole({required String userId, required String role}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _members.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<OrgBranding> getBranding() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _branding;
  }

  @override
  Future<OrgBranding> updateBranding({
    String? logoUrl,
    String? displayName,
    String? primaryColor,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _branding = _branding.copyWith(
      logoUrl: logoUrl ?? _branding.logoUrl,
      displayName: displayName ?? _branding.displayName,
      primaryColor: primaryColor ?? _branding.primaryColor,
    );
    return _branding;
  }
}
