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
  final double requireManagerApprovalAboveAmount;
  final bool auditLoggingEnabled;
  final List<String> allowedAssetClasses;

  factory DeskRiskModel.defaultConfig() {
    return const DeskRiskModel(
      maxFirmDrawdownPercent: 5.0,
      maxPositionPerTrader: 5000000.0,
      enforcePreTradeChecklistAllTraders: true,
      requireManagerApprovalAboveAmount: 1000000.0,
      auditLoggingEnabled: true,
      allowedAssetClasses: ['NSE Equities', 'F&O Derivatives', 'Commodities (MCX)', 'Currency Pairs'],
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
      maxPositionPerTrader:
          maxPositionPerTrader ?? this.maxPositionPerTrader,
      enforcePreTradeChecklistAllTraders:
          enforcePreTradeChecklistAllTraders ??
              this.enforcePreTradeChecklistAllTraders,
      requireManagerApprovalAboveAmount:
          requireManagerApprovalAboveAmount ??
              this.requireManagerApprovalAboveAmount,
      auditLoggingEnabled:
          auditLoggingEnabled ?? this.auditLoggingEnabled,
      allowedAssetClasses:
          allowedAssetClasses ?? this.allowedAssetClasses,
    );
  }

  factory DeskRiskModel.fromJson(Map<String, dynamic> json) {
    return DeskRiskModel(
      maxFirmDrawdownPercent:
          (json['max_firm_drawdown_percent'] as num?)?.toDouble() ?? 5.0,
      maxPositionPerTrader:
          (json['max_position_per_trader'] as num?)?.toDouble() ?? 250000.0,
      enforcePreTradeChecklistAllTraders:
          json['enforce_pre_trade_checklist'] as bool? ?? true,
      requireManagerApprovalAboveAmount:
          (json['manager_approval_threshold'] as num?)?.toDouble() ?? 50000.0,
      auditLoggingEnabled:
          json['audit_logging_enabled'] as bool? ?? true,
      allowedAssetClasses: (json['allowed_asset_classes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['US Equities', 'Crypto'],
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
