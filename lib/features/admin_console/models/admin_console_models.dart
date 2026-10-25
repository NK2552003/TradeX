import 'package:flutter/foundation.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';

/// Formats large INR amounts in Indian Lakh (`L`) / Crore (`Cr`) notation or full `₹` commas.
String formatInrCompact(num amount, {bool signed = false}) {
  final bool neg = amount < 0;
  final double abs = amount.abs().toDouble();
  final String prefix = neg
      ? '-₹'
      : signed && amount > 0
      ? '+₹'
      : '₹';
  if (abs >= 10000000) {
    return '$prefix${(abs / 10000000).toStringAsFixed(2)} Cr';
  }
  if (abs >= 100000) {
    return '$prefix${(abs / 100000).toStringAsFixed(2)} L';
  }
  return formatInrAmount(amount, signed: signed);
}

@immutable
class AdminTraderSeat {
  const AdminTraderSeat({
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.email,
    required this.role,
    required this.deskDivision,
    required this.allocatedCapitalInr,
    required this.usedMarginInr,
    required this.dailyPnlInr,
    required this.monthlyPnlInr,
    required this.winRatePct,
    required this.sharpeRatio,
    required this.currentDrawdownPct,
    required this.maxDrawdownLimitPct,
    required this.openPositionsCount,
    required this.status,
    required this.joinedAt,
  });

  final String userId;
  final String handle;
  final String displayName;
  final String email;
  final String role; // owner | admin | risk_manager | trader | analyst
  final String deskDivision;
  final double allocatedCapitalInr;
  final double usedMarginInr;
  final double dailyPnlInr;
  final double monthlyPnlInr;
  final double winRatePct;
  final double sharpeRatio;
  final double currentDrawdownPct;
  final double maxDrawdownLimitPct;
  final int openPositionsCount;
  final String status; // active | invited | frozen | suspended
  final DateTime joinedAt;

  double get marginUtilizationPct => allocatedCapitalInr <= 0
      ? 0
      : ((usedMarginInr / allocatedCapitalInr) * 100).clamp(0.0, 100.0);

  bool get isDrawdownNearLimit =>
      currentDrawdownPct >= (maxDrawdownLimitPct * 0.8);

  AdminTraderSeat copyWith({
    String? role,
    String? deskDivision,
    double? allocatedCapitalInr,
    double? usedMarginInr,
    double? dailyPnlInr,
    double? monthlyPnlInr,
    double? winRatePct,
    double? sharpeRatio,
    double? currentDrawdownPct,
    double? maxDrawdownLimitPct,
    int? openPositionsCount,
    String? status,
  }) {
    return AdminTraderSeat(
      userId: userId,
      handle: handle,
      displayName: displayName,
      email: email,
      role: role ?? this.role,
      deskDivision: deskDivision ?? this.deskDivision,
      allocatedCapitalInr: allocatedCapitalInr ?? this.allocatedCapitalInr,
      usedMarginInr: usedMarginInr ?? this.usedMarginInr,
      dailyPnlInr: dailyPnlInr ?? this.dailyPnlInr,
      monthlyPnlInr: monthlyPnlInr ?? this.monthlyPnlInr,
      winRatePct: winRatePct ?? this.winRatePct,
      sharpeRatio: sharpeRatio ?? this.sharpeRatio,
      currentDrawdownPct: currentDrawdownPct ?? this.currentDrawdownPct,
      maxDrawdownLimitPct: maxDrawdownLimitPct ?? this.maxDrawdownLimitPct,
      openPositionsCount: openPositionsCount ?? this.openPositionsCount,
      status: status ?? this.status,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'handle': handle,
    'display_name': displayName,
    'email': email,
    'role': role,
    'desk_division': deskDivision,
    'allocated_capital_inr': allocatedCapitalInr,
    'used_margin_inr': usedMarginInr,
    'daily_pnl_inr': dailyPnlInr,
    'monthly_pnl_inr': monthlyPnlInr,
    'win_rate_pct': winRatePct,
    'sharpe_ratio': sharpeRatio,
    'current_drawdown_pct': currentDrawdownPct,
    'max_drawdown_limit_pct': maxDrawdownLimitPct,
    'open_positions_count': openPositionsCount,
    'status': status,
    'joined_at': joinedAt.toIso8601String(),
  };

  factory AdminTraderSeat.fromJson(Map<String, dynamic> json) {
    return AdminTraderSeat(
      userId: json['user_id']?.toString() ?? '',
      handle: json['handle']?.toString() ?? 'trader',
      displayName: json['display_name']?.toString() ?? 'Trader',
      email: json['email']?.toString() ?? 'trader@tradex.in',
      role: json['role']?.toString() ?? 'trader',
      deskDivision:
          json['desk_division']?.toString() ?? 'Index & Options Desk',
      allocatedCapitalInr:
          (json['allocated_capital_inr'] as num?)?.toDouble() ?? 2500000.0,
      usedMarginInr: (json['used_margin_inr'] as num?)?.toDouble() ?? 0.0,
      dailyPnlInr: (json['daily_pnl_inr'] as num?)?.toDouble() ?? 0.0,
      monthlyPnlInr: (json['monthly_pnl_inr'] as num?)?.toDouble() ?? 0.0,
      winRatePct: (json['win_rate_pct'] as num?)?.toDouble() ?? 60.0,
      sharpeRatio: (json['sharpe_ratio'] as num?)?.toDouble() ?? 1.8,
      currentDrawdownPct:
          (json['current_drawdown_pct'] as num?)?.toDouble() ?? 1.2,
      maxDrawdownLimitPct:
          (json['max_drawdown_limit_pct'] as num?)?.toDouble() ?? 5.0,
      openPositionsCount:
          (json['open_positions_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'active',
      joinedAt:
          DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

@immutable
class AdminConsumerAccount {
  const AdminConsumerAccount({
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.email,
    required this.subscriptionTier,
    required this.monthlySubscriptionInr,
    required this.journalsCount,
    required this.strategiesCount,
    required this.notesCount,
    required this.aiQueriesUsed,
    required this.referredBySlug,
    required this.isPublicProfile,
    required this.status,
    required this.joinedAt,
  });

  final String userId;
  final String handle;
  final String displayName;
  final String email;
  final String subscriptionTier; // Basic | Pro | Enterprise
  final double monthlySubscriptionInr;
  final int journalsCount;
  final int strategiesCount;
  final int notesCount;
  final int aiQueriesUsed;
  final String? referredBySlug;
  final bool isPublicProfile;
  final String status; // active | suspended | pending_deletion
  final DateTime joinedAt;

  AdminConsumerAccount copyWith({
    String? subscriptionTier,
    double? monthlySubscriptionInr,
    bool? isPublicProfile,
    String? status,
  }) {
    return AdminConsumerAccount(
      userId: userId,
      handle: handle,
      displayName: displayName,
      email: email,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      monthlySubscriptionInr:
          monthlySubscriptionInr ?? this.monthlySubscriptionInr,
      journalsCount: journalsCount,
      strategiesCount: strategiesCount,
      notesCount: notesCount,
      aiQueriesUsed: aiQueriesUsed,
      referredBySlug: referredBySlug,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      status: status ?? this.status,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'handle': handle,
    'display_name': displayName,
    'email': email,
    'subscription_tier': subscriptionTier,
    'monthly_subscription_inr': monthlySubscriptionInr,
    'journals_count': journalsCount,
    'strategies_count': strategiesCount,
    'notes_count': notesCount,
    'ai_queries_used': aiQueriesUsed,
    'referred_by_slug': referredBySlug,
    'is_public_profile': isPublicProfile,
    'status': status,
    'joined_at': joinedAt.toIso8601String(),
  };

  factory AdminConsumerAccount.fromJson(Map<String, dynamic> json) {
    return AdminConsumerAccount(
      userId: json['user_id']?.toString() ?? '',
      handle: json['handle']?.toString() ?? 'trader',
      displayName: json['display_name']?.toString() ?? 'Trader',
      email: json['email']?.toString() ?? 'trader@tradex.in',
      subscriptionTier: json['subscription_tier']?.toString() ?? 'Pro',
      monthlySubscriptionInr:
          (json['monthly_subscription_inr'] as num?)?.toDouble() ?? 2499.0,
      journalsCount: (json['journals_count'] as num?)?.toInt() ?? 0,
      strategiesCount: (json['strategies_count'] as num?)?.toInt() ?? 0,
      notesCount: (json['notes_count'] as num?)?.toInt() ?? 0,
      aiQueriesUsed: (json['ai_queries_used'] as num?)?.toInt() ?? 0,
      referredBySlug: json['referred_by_slug']?.toString(),
      isPublicProfile: json['is_public_profile'] as bool? ?? true,
      status: json['status']?.toString() ?? 'active',
      joinedAt:
          DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

@immutable
class DeskOrderApproval {
  const DeskOrderApproval({
    required this.id,
    required this.traderUserId,
    required this.traderHandle,
    required this.traderName,
    required this.deskDivision,
    required this.symbol,
    required this.exchange,
    required this.side,
    required this.quantity,
    required this.orderPriceInr,
    required this.notionalValueInr,
    required this.leverageX,
    required this.stopLossInr,
    required this.targetPriceInr,
    required this.strategyName,
    required this.reasonFlagged,
    required this.status,
    required this.createdAt,
    this.reviewerNotes,
    this.reviewedAt,
  });

  final String id;
  final String traderUserId;
  final String traderHandle;
  final String traderName;
  final String deskDivision;
  final String symbol;
  final String exchange; // NSE | BSE | NFO | MCX
  final String side; // BUY | SELL | SHORT
  final int quantity;
  final double orderPriceInr;
  final double notionalValueInr;
  final double leverageX;
  final double stopLossInr;
  final double targetPriceInr;
  final String strategyName;
  final String reasonFlagged;
  final String status; // pending | approved | rejected
  final String? reviewerNotes;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  DeskOrderApproval copyWith({
    String? status,
    String? reviewerNotes,
    DateTime? reviewedAt,
  }) {
    return DeskOrderApproval(
      id: id,
      traderUserId: traderUserId,
      traderHandle: traderHandle,
      traderName: traderName,
      deskDivision: deskDivision,
      symbol: symbol,
      exchange: exchange,
      side: side,
      quantity: quantity,
      orderPriceInr: orderPriceInr,
      notionalValueInr: notionalValueInr,
      leverageX: leverageX,
      stopLossInr: stopLossInr,
      targetPriceInr: targetPriceInr,
      strategyName: strategyName,
      reasonFlagged: reasonFlagged,
      status: status ?? this.status,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trader_user_id': traderUserId,
    'trader_handle': traderHandle,
    'trader_name': traderName,
    'desk_division': deskDivision,
    'symbol': symbol,
    'exchange': exchange,
    'side': side,
    'quantity': quantity,
    'order_price_inr': orderPriceInr,
    'notional_value_inr': notionalValueInr,
    'leverage_x': leverageX,
    'stop_loss_inr': stopLossInr,
    'target_price_inr': targetPriceInr,
    'strategy_name': strategyName,
    'reason_flagged': reasonFlagged,
    'status': status,
    'reviewer_notes': reviewerNotes,
    'reviewed_at': reviewedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  factory DeskOrderApproval.fromJson(Map<String, dynamic> json) {
    return DeskOrderApproval(
      id: json['id']?.toString() ?? '',
      traderUserId: json['trader_user_id']?.toString() ?? '',
      traderHandle: json['trader_handle']?.toString() ?? 'trader',
      traderName: json['trader_name']?.toString() ?? 'Trader',
      deskDivision:
          json['desk_division']?.toString() ?? 'Index & Options Desk',
      symbol: json['symbol']?.toString() ?? 'NIFTY',
      exchange: json['exchange']?.toString() ?? 'NFO',
      side: json['side']?.toString() ?? 'BUY',
      quantity: (json['quantity'] as num?)?.toInt() ?? 100,
      orderPriceInr: (json['order_price_inr'] as num?)?.toDouble() ?? 0.0,
      notionalValueInr:
          (json['notional_value_inr'] as num?)?.toDouble() ?? 0.0,
      leverageX: (json['leverage_x'] as num?)?.toDouble() ?? 1.0,
      stopLossInr: (json['stop_loss_inr'] as num?)?.toDouble() ?? 0.0,
      targetPriceInr: (json['target_price_inr'] as num?)?.toDouble() ?? 0.0,
      strategyName: json['strategy_name']?.toString() ?? 'Intraday Breakout',
      reasonFlagged:
          json['reason_flagged']?.toString() ?? 'Exceeds single-order cap',
      status: json['status']?.toString() ?? 'pending',
      reviewerNotes: json['reviewer_notes']?.toString(),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

@immutable
class DeskRiskBreach {
  const DeskRiskBreach({
    required this.id,
    required this.traderUserId,
    required this.traderHandle,
    required this.traderName,
    required this.deskDivision,
    required this.breachType,
    required this.severity,
    required this.symbol,
    required this.metricValueInr,
    required this.thresholdValueInr,
    required this.description,
    required this.status,
    required this.createdAt,
    this.resolutionNotes,
  });

  final String id;
  final String traderUserId;
  final String traderHandle;
  final String traderName;
  final String deskDivision;
  final String breachType;
  final String severity; // warning | critical | halt
  final String symbol;
  final double metricValueInr;
  final double thresholdValueInr;
  final String description;
  final String status; // open | acknowledged | trader_frozen | resolved
  final String? resolutionNotes;
  final DateTime createdAt;

  DeskRiskBreach copyWith({
    String? status,
    String? resolutionNotes,
  }) {
    return DeskRiskBreach(
      id: id,
      traderUserId: traderUserId,
      traderHandle: traderHandle,
      traderName: traderName,
      deskDivision: deskDivision,
      breachType: breachType,
      severity: severity,
      symbol: symbol,
      metricValueInr: metricValueInr,
      thresholdValueInr: thresholdValueInr,
      description: description,
      status: status ?? this.status,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trader_user_id': traderUserId,
    'trader_handle': traderHandle,
    'trader_name': traderName,
    'desk_division': deskDivision,
    'breach_type': breachType,
    'severity': severity,
    'symbol': symbol,
    'metric_value_inr': metricValueInr,
    'threshold_value_inr': thresholdValueInr,
    'description': description,
    'status': status,
    'resolution_notes': resolutionNotes,
    'created_at': createdAt.toIso8601String(),
  };

  factory DeskRiskBreach.fromJson(Map<String, dynamic> json) {
    return DeskRiskBreach(
      id: json['id']?.toString() ?? '',
      traderUserId: json['trader_user_id']?.toString() ?? '',
      traderHandle: json['trader_handle']?.toString() ?? 'trader',
      traderName: json['trader_name']?.toString() ?? 'Trader',
      deskDivision:
          json['desk_division']?.toString() ?? 'Index & Options Desk',
      breachType: json['breach_type']?.toString() ?? 'Daily Loss Limit',
      severity: json['severity']?.toString() ?? 'warning',
      symbol: json['symbol']?.toString() ?? 'BANKNIFTY',
      metricValueInr: (json['metric_value_inr'] as num?)?.toDouble() ?? 0.0,
      thresholdValueInr:
          (json['threshold_value_inr'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      resolutionNotes: json['resolution_notes']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

@immutable
class AdminAuditLogEntry {
  const AdminAuditLogEntry({
    required this.id,
    required this.actorHandle,
    required this.actorRole,
    required this.category,
    required this.action,
    required this.targetType,
    required this.targetLabel,
    required this.severity,
    required this.ipAddress,
    required this.sha256Hash,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final String actorHandle;
  final String actorRole;
  final String category;
  // risk_control | order_approval | seat_governance | affiliate_review | payout_settlement | account_deletion | security_auth
  final String action;
  final String targetType;
  final String targetLabel;
  final String severity; // info | warning | critical
  final String ipAddress;
  final String sha256Hash;
  final String details;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'actor_handle': actorHandle,
    'actor_role': actorRole,
    'category': category,
    'action': action,
    'target_type': targetType,
    'target_label': targetLabel,
    'severity': severity,
    'ip_address': ipAddress,
    'sha256_hash': sha256Hash,
    'details': details,
    'created_at': createdAt.toIso8601String(),
  };

  factory AdminAuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminAuditLogEntry(
      id: json['id']?.toString() ?? '',
      actorHandle: json['actor_handle']?.toString() ?? 'nitish_admin',
      actorRole: json['actor_role']?.toString() ?? 'owner',
      category: json['category']?.toString() ?? 'risk_control',
      action: json['action']?.toString() ?? 'POLICY_UPDATED',
      targetType: json['target_type']?.toString() ?? 'desk',
      targetLabel: json['target_label']?.toString() ?? 'Desk Risk Policy',
      severity: json['severity']?.toString() ?? 'info',
      ipAddress: json['ip_address']?.toString() ?? '103.21.244.18',
      sha256Hash:
          json['sha256_hash']?.toString() ??
          '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
      details: json['details']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

@immutable
class DeskDivisionPerformance {
  const DeskDivisionPerformance({
    required this.divisionName,
    required this.allocatedCapitalInr,
    required this.periodNetPnlInr,
    required this.sharpeRatio,
    required this.winRatePct,
    required this.activeSeats,
  });

  final String divisionName;
  final double allocatedCapitalInr;
  final double periodNetPnlInr;
  final double sharpeRatio;
  final double winRatePct;
  final int activeSeats;
}

@immutable
class AdminPnlSeriesPoint {
  const AdminPnlSeriesPoint({
    required this.label,
    required this.deskPnlInr,
    required this.benchmarkPnlInr,
    required this.revenueInr,
  });

  final String label;
  final double deskPnlInr;
  final double benchmarkPnlInr;
  final double revenueInr;
}

@immutable
class AdminDeskAnalyticsSnapshot {
  const AdminDeskAnalyticsSnapshot({
    required this.timeframe,
    required this.supervisedCapitalInr,
    required this.allocatedCapitalInr,
    required this.intradayPnlInr,
    required this.periodNetPnlInr,
    required this.firmSharpeRatio,
    required this.firmWinRatePct,
    required this.maxDrawdownPct,
    required this.profitFactor,
    required this.subscriptionMrrInr,
    required this.affiliateGeneratedArrInr,
    required this.affiliatePayoutsSettledInr,
    required this.activeCircuitBreakerState,
    required this.killswitchReason,
    required this.points,
    required this.divisions,
  });

  final String timeframe;
  final double supervisedCapitalInr;
  final double allocatedCapitalInr;
  final double intradayPnlInr;
  final double periodNetPnlInr;
  final double firmSharpeRatio;
  final double firmWinRatePct;
  final double maxDrawdownPct;
  final double profitFactor;
  final double subscriptionMrrInr;
  final double affiliateGeneratedArrInr;
  final double affiliatePayoutsSettledInr;
  final String activeCircuitBreakerState; // armed | tripped | halted
  final String? killswitchReason;
  final List<AdminPnlSeriesPoint> points;
  final List<DeskDivisionPerformance> divisions;
}
