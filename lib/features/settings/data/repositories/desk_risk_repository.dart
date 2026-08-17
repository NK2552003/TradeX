import 'package:tradex/features/settings/models/desk_risk_model.dart';

abstract class DeskRiskRepository {
  Future<DeskRiskModel> getDeskRiskConfig();
  Future<DeskRiskModel> updateDeskRiskConfig(DeskRiskModel updated);
}

class DeskRiskRepositoryImpl implements DeskRiskRepository {
  DeskRiskModel _config = DeskRiskModel.defaultConfig();

  @override
  Future<DeskRiskModel> getDeskRiskConfig() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _config;
  }

  @override
  Future<DeskRiskModel> updateDeskRiskConfig(DeskRiskModel updated) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _config = updated;
    return _config;
  }
}
