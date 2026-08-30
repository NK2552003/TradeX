import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/models/privacy_settings_model.dart';

abstract class PrivacyRepository {
  Future<PrivacySettingsModel> getPrivacySettings();
  Future<void> setPublicJournalsDefault(bool enabled);
  Future<void> setPublicStatsEnabled(bool enabled);
  Future<List<AppTrader>> getBlockedUsers();
  Future<void> unblockUser(String userId);
  Future<DataExportRequest> requestDataExport();
  Future<DataExportRequest> getDataExportStatus();
}

class PrivacyRepositoryImpl implements PrivacyRepository {
  PrivacySettingsModel _settings = const PrivacySettingsModel(
    publicJournals: true,
    publicStatsEnabled: false,
  );

  final List<AppTrader> _blockedUsers = <AppTrader>[
    const AppTrader(
      id: 'blk_1',
      handle: 'spammer_bot99',
      displayName: 'Free Signals Official',
      bio: 'DM for 1000% daily returns telegram link',
      tier: AppTier.free,
    ),
    const AppTrader(
      id: 'blk_2',
      handle: 'toxic_scalper',
      displayName: 'Rage Trader',
      bio: 'Crypto maximalist. No DMs.',
      tier: AppTier.free,
    ),
  ];

  DataExportRequest _exportRequest = DataExportRequest(
    status: 'pending',
    requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
  );

  @override
  Future<PrivacySettingsModel> getPrivacySettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _settings;
  }

  @override
  Future<void> setPublicJournalsDefault(bool enabled) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _settings = _settings.copyWith(publicJournals: enabled);
  }

  @override
  Future<void> setPublicStatsEnabled(bool enabled) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _settings = _settings.copyWith(publicStatsEnabled: enabled);
  }

  @override
  Future<List<AppTrader>> getBlockedUsers() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List<AppTrader>.from(_blockedUsers);
  }

  @override
  Future<void> unblockUser(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _blockedUsers.removeWhere((u) => u.id == userId);
  }

  @override
  Future<DataExportRequest> requestDataExport() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _exportRequest = DataExportRequest(
      status: 'processing',
      requestedAt: DateTime.now(),
    );
    return _exportRequest;
  }

  @override
  Future<DataExportRequest> getDataExportStatus() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Simulated state machine: if processing, after 1 cycle mark ready
    if (_exportRequest.status == 'processing') {
      _exportRequest = DataExportRequest(
        status: 'ready',
        requestedAt: _exportRequest.requestedAt,
        completedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        downloadUrl: 'https://tradex.ai/exports/tradex_export_usr_mock_01.zip',
      );
    }
    return _exportRequest;
  }
}
