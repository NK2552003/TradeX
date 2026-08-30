import 'package:flutter/foundation.dart';

@immutable
class DeskRiskModel {
  const DeskRiskModel({
    required this.maxFirmDrawdownPercent,
    required this.maxPositionPerTrader,
    required this.enforcePreTradeChecklistAllTraders,
    required this.requireManagerApprovalAboveAmount,
    required this.auditLoggingEnabled,
    required this.allowedAssetClasses,
  });

  final double maxFirmDrawdownPercent;
  final double maxPositionPerTrader;
  final bool enforcePreTradeChecklistAllTraders;

  /// Order notional above which a desk admin has to approve. Zero means no
  /// approval step at all.
  final double requireManagerApprovalAboveAmount;
  final bool auditLoggingEnabled;
  final List<String> allowedAssetClasses;

  /// Ranges a desk admin can move each limit between. They live on the model so
  /// the controls that set a limit and the backend that validates it are working
  /// from the same bounds.
  static const double firmDrawdownMinPercent = 1;
  static const double firmDrawdownMaxPercent = 15;
  static const double positionPerTraderMin = 1000000;
  static const double positionPerTraderMax = 50000000;
  static const double approvalThresholdMin = 100000;
  static const double approvalThresholdMax = 10000000;

  /// True when large orders route through a desk admin.
  bool get requiresManagerApproval => requireManagerApprovalAboveAmount > 0;

  factory DeskRiskModel.defaultConfig() {
    return const DeskRiskModel(
      maxFirmDrawdownPercent: 5.0,
      maxPositionPerTrader: 5000000.0,
      enforcePreTradeChecklistAllTraders: true,
      requireManagerApprovalAboveAmount: 1000000.0,
      auditLoggingEnabled: true,
      allowedAssetClasses: [
        'NSE Equities',
        'F&O Derivatives',
        'Commodities (MCX)',
        'Currency Pairs',
      ],
    );
  }

  DeskRiskModel copyWith({
    double? maxFirmDrawdownPercent,
    double? maxPositionPerTrader,
    bool? enforcePreTradeChecklistAllTraders,
    double? requireManagerApprovalAboveAmount,
    bool? auditLoggingEnabled,
    List<String>? allowedAssetClasses,
  }) {
    return DeskRiskModel(
      maxFirmDrawdownPercent:
          maxFirmDrawdownPercent ?? this.maxFirmDrawdownPercent,
      maxPositionPerTrader: maxPositionPerTrader ?? this.maxPositionPerTrader,
      enforcePreTradeChecklistAllTraders:
          enforcePreTradeChecklistAllTraders ??
          this.enforcePreTradeChecklistAllTraders,
      requireManagerApprovalAboveAmount:
          requireManagerApprovalAboveAmount ??
          this.requireManagerApprovalAboveAmount,
      auditLoggingEnabled: auditLoggingEnabled ?? this.auditLoggingEnabled,
      allowedAssetClasses: allowedAssetClasses ?? this.allowedAssetClasses,
    );
  }

  /// Reads a desk policy from the backend. Anything the payload leaves out falls
  /// back to [defaultConfig] rather than to a second set of numbers — otherwise a
  /// partial response would quietly hand the desk different limits from the ones
  /// the app documents as its defaults.
  factory DeskRiskModel.fromJson(Map<String, dynamic> json) {
    final DeskRiskModel defaults = DeskRiskModel.defaultConfig();
    return DeskRiskModel(
      maxFirmDrawdownPercent:
          (json['max_firm_drawdown_percent'] as num?)?.toDouble() ??
          defaults.maxFirmDrawdownPercent,
      maxPositionPerTrader:
          (json['max_position_per_trader'] as num?)?.toDouble() ??
          defaults.maxPositionPerTrader,
      enforcePreTradeChecklistAllTraders:
          json['enforce_pre_trade_checklist'] as bool? ??
          defaults.enforcePreTradeChecklistAllTraders,
      requireManagerApprovalAboveAmount:
          (json['manager_approval_threshold'] as num?)?.toDouble() ??
          defaults.requireManagerApprovalAboveAmount,
      auditLoggingEnabled:
          json['audit_logging_enabled'] as bool? ??
          defaults.auditLoggingEnabled,
      allowedAssetClasses:
          (json['allowed_asset_classes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          defaults.allowedAssetClasses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_firm_drawdown_percent': maxFirmDrawdownPercent,
      'max_position_per_trader': maxPositionPerTrader,
      'enforce_pre_trade_checklist': enforcePreTradeChecklistAllTraders,
      'manager_approval_threshold': requireManagerApprovalAboveAmount,
      'audit_logging_enabled': auditLoggingEnabled,
      'allowed_asset_classes': allowedAssetClasses,
    };
  }
}
