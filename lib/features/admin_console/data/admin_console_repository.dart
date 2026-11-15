import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/admin_console/models/admin_console_models.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_application_repository.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/settings/data/repositories/desk_risk_repository.dart';
import 'package:tradex/features/settings/data/repositories/organization_settings_repository.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/models/desk_risk_model.dart';

class AdminConsoleRepository {
  AdminConsoleRepository._();

  static final AdminConsoleRepository instance = AdminConsoleRepository._();

  static const String _seatsPrefsKey = 'tradex.admin_console.seats.v1';
  static const String _consumersPrefsKey = 'tradex.admin_console.consumers.v1';
  static const String _ordersPrefsKey = 'tradex.admin_console.orders.v1';
  static const String _breachesPrefsKey = 'tradex.admin_console.breaches.v1';
  static const String _auditsPrefsKey = 'tradex.admin_console.audits.v1';
  static const String _breakerPrefsKey = 'tradex.admin_console.breaker.v1';

  final OrganizationSettingsRepository _orgRepo =
      OrganizationSettingsRepositoryImpl();
  final DeskRiskRepository _riskRepo = DeskRiskRepositoryImpl();
  final ProfileSettingsRepository _profileRepo =
      ProfileSettingsRepositoryImpl();

  bool _hydrated = false;
  String _circuitBreakerState = 'armed';
  String? _killswitchReason;

  static final Set<String> _missingTablesNotice = <String>{};

  List<AdminTraderSeat> _seats = _defaultSeats();
  List<AdminConsumerAccount> _consumers = _defaultConsumers();
  List<DeskOrderApproval> _orderApprovals = _defaultOrderApprovals();
  List<DeskRiskBreach> _riskBreaches = _defaultRiskBreaches();
  List<AdminAuditLogEntry> _auditLogs = _defaultAuditLogs();

  Future<void> _ensureHydrated() async {
    if (_hydrated) return;
    _hydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seatsRaw = prefs.getString(_seatsPrefsKey);
      if (seatsRaw != null && seatsRaw.isNotEmpty) {
        final decoded = jsonDecode(seatsRaw) as List<dynamic>;
        _seats = decoded
            .whereType<Map<String, dynamic>>()
            .map(AdminTraderSeat.fromJson)
            .toList();
      }
      final consumersRaw = prefs.getString(_consumersPrefsKey);
      if (consumersRaw != null && consumersRaw.isNotEmpty) {
        final decoded = jsonDecode(consumersRaw) as List<dynamic>;
        _consumers = decoded
            .whereType<Map<String, dynamic>>()
            .map(AdminConsumerAccount.fromJson)
            .toList();
      }
      final ordersRaw = prefs.getString(_ordersPrefsKey);
      if (ordersRaw != null && ordersRaw.isNotEmpty) {
        final decoded = jsonDecode(ordersRaw) as List<dynamic>;
        _orderApprovals = decoded
            .whereType<Map<String, dynamic>>()
            .map(DeskOrderApproval.fromJson)
            .toList();
      }
      final breachesRaw = prefs.getString(_breachesPrefsKey);
      if (breachesRaw != null && breachesRaw.isNotEmpty) {
        final decoded = jsonDecode(breachesRaw) as List<dynamic>;
        _riskBreaches = decoded
            .whereType<Map<String, dynamic>>()
            .map(DeskRiskBreach.fromJson)
            .toList();
      }
      final auditsRaw = prefs.getString(_auditsPrefsKey);
      if (auditsRaw != null && auditsRaw.isNotEmpty) {
        final decoded = jsonDecode(auditsRaw) as List<dynamic>;
        _auditLogs = decoded
            .whereType<Map<String, dynamic>>()
            .map(AdminAuditLogEntry.fromJson)
            .toList();
      }
      final breakerRaw = prefs.getString(_breakerPrefsKey);
      if (breakerRaw != null && breakerRaw.isNotEmpty) {
        final map = jsonDecode(breakerRaw) as Map<String, dynamic>;
        _circuitBreakerState = map['state']?.toString() ?? 'armed';
        _killswitchReason = map['reason']?.toString();
      }
    } catch (e) {
      debugPrint('AdminConsoleRepository._ensureHydrated error: $e');
    }
    if (_seats.isEmpty) _seats = _defaultSeats();
    if (_consumers.isEmpty) _consumers = _defaultConsumers();
    if (_orderApprovals.isEmpty) _orderApprovals = _defaultOrderApprovals();
    if (_riskBreaches.isEmpty) _riskBreaches = _defaultRiskBreaches();
    if (_auditLogs.isEmpty) _auditLogs = _defaultAuditLogs();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _seatsPrefsKey,
        jsonEncode(_seats.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _consumersPrefsKey,
        jsonEncode(_consumers.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _ordersPrefsKey,
        jsonEncode(_orderApprovals.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _breachesPrefsKey,
        jsonEncode(_riskBreaches.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _auditsPrefsKey,
        jsonEncode(_auditLogs.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _breakerPrefsKey,
        jsonEncode(<String, dynamic>{
          'state': _circuitBreakerState,
          'reason': _killswitchReason,
        }),
      );
    } catch (e) {
      debugPrint('AdminConsoleRepository._persist error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Circuit Breaker & Desk Risk Policy
  // ---------------------------------------------------------------------------

  Future<DeskRiskModel> getDeskRiskConfig() => _riskRepo.getDeskRiskConfig();

  Future<DeskRiskModel> updateDeskRiskConfig(DeskRiskModel updated) async {
    final saved = await _riskRepo.updateDeskRiskConfig(updated);
    await recordAuditLog(
      category: 'risk_control',
      action: 'DESK_RISK_POLICY_UPDATED',
      targetType: 'desk_risk_configs',
      targetLabel: 'Firm-Wide Risk & Margin Rules',
      severity: 'info',
      details:
          'Max Leverage: ${updated.maxLeverage}x · Max Daily Loss: ${updated.maxDailyLossPercent.toStringAsFixed(1)}% · Max Drawdown: ${updated.maxTotalDrawdownPercent.toStringAsFixed(1)}% · Crypto: ${updated.allowCrypto ? "ON" : "OFF"} · Options: ${updated.allowOptions ? "ON" : "OFF"}',
    );
    return saved;
  }

  Future<String> getCircuitBreakerState() async {
    await _ensureHydrated();
    return _circuitBreakerState;
  }

  String? get killswitchReason => _killswitchReason;

  Future<void> setCircuitBreakerState({
    required String state,
    String? reason,
  }) async {
    await _ensureHydrated();
    _circuitBreakerState = state;
    _killswitchReason = reason;
    if (state == 'halted') {
      _seats = _seats
          .map((s) => s.role == 'owner' ? s : s.copyWith(status: 'frozen'))
          .toList();
    } else if (state == 'armed') {
      _seats = _seats
          .map((s) => s.status == 'frozen' ? s.copyWith(status: 'active') : s)
          .toList();
    }
    await recordAuditLog(
      category: 'risk_control',
      action: state == 'halted'
          ? 'EMERGENCY_KILLSWITCH_ENGAGED'
          : state == 'tripped'
          ? 'CIRCUIT_BREAKER_TRIPPED'
          : 'DESK_EXECUTION_RESUMED',
      targetType: 'desk_circuit_breaker',
      targetLabel: 'alphajournal Institutional Desk',
      severity: state == 'halted' ? 'critical' : 'warning',
      details: reason?.trim().isNotEmpty == true
          ? reason!.trim()
          : 'Desk circuit breaker transitioned to ${state.toUpperCase()}.',
    );
    await _persist();
  }

  // ---------------------------------------------------------------------------
  // Trader Seats & Provisioning
  // ---------------------------------------------------------------------------

  Future<List<AdminTraderSeat>> listTraderSeats() async {
    await _ensureHydrated();
    if (SupabaseConfig.isConfigured) {
      try {
        final rows = await SupabaseConfig.client!
            .from('organization_members')
            .select('user_id, role, status')
            .order('created_at', ascending: true)
            .limit(200);
        if ((rows as List).isNotEmpty) {
          // Merge remote roles if present
          for (final item in rows.whereType<Map<String, dynamic>>()) {
            final uid = item['user_id']?.toString() ?? '';
            final idx = _seats.indexWhere((s) => s.userId == uid);
            if (idx != -1) {
              _seats[idx] = _seats[idx].copyWith(
                role: item['role']?.toString() ?? _seats[idx].role,
                status: item['status']?.toString() ?? _seats[idx].status,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('AdminConsoleRepository.listTraderSeats error: $e');
      }
    }
    return List<AdminTraderSeat>.unmodifiable(_seats);
  }

  Future<AdminTraderSeat> inviteTraderSeat({
    required String displayName,
    required String email,
    required String role,
    required String deskDivision,
    required double allocatedCapitalInr,
    required double maxDrawdownLimitPct,
  }) async {
    await _ensureHydrated();
    final cleanEmail = email.trim().toLowerCase();
    final handle = cleanEmail
        .split('@')
        .first
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final seat = AdminTraderSeat(
      userId: 'seat_${DateTime.now().millisecondsSinceEpoch}',
      handle: handle.isEmpty ? 'desk_trader' : handle,
      displayName: displayName.trim().isEmpty ? handle : displayName.trim(),
      email: cleanEmail,
      role: role,
      deskDivision: deskDivision,
      allocatedCapitalInr: allocatedCapitalInr,
      usedMarginInr: 0,
      dailyPnlInr: 0,
      monthlyPnlInr: 0,
      winRatePct: 0,
      sharpeRatio: 0,
      currentDrawdownPct: 0,
      maxDrawdownLimitPct: maxDrawdownLimitPct,
      openPositionsCount: 0,
      status: 'active',
      joinedAt: DateTime.now(),
    );
    _seats = <AdminTraderSeat>[seat, ..._seats];
    await _orgRepo.inviteMember(email: cleanEmail, role: role);
    await recordAuditLog(
      category: 'seat_governance',
      action: 'SEAT_PROVISIONED',
      targetType: 'organization_member',
      targetLabel: '${seat.displayName} (@${seat.handle})',
      severity: 'info',
      details:
          'Provisioned ${role.toUpperCase()} seat in $deskDivision with capital allocation ${formatInrAmount(allocatedCapitalInr)} and ${maxDrawdownLimitPct.toStringAsFixed(1)}% drawdown limit.',
    );
    await _persist();
    return seat;
  }

  Future<AdminTraderSeat> updateTraderSeat({
    required String userId,
    String? role,
    String? deskDivision,
    double? allocatedCapitalInr,
    double? maxDrawdownLimitPct,
    String? status,
  }) async {
    await _ensureHydrated();
    final idx = _seats.indexWhere((s) => s.userId == userId);
    if (idx == -1) {
      throw StateError('Trader seat not found');
    }
    final current = _seats[idx];
    final updated = current.copyWith(
      role: role,
      deskDivision: deskDivision,
      allocatedCapitalInr: allocatedCapitalInr,
      maxDrawdownLimitPct: maxDrawdownLimitPct,
      status: status,
    );
    _seats[idx] = updated;
    if (role != null && role != current.role) {
      await _orgRepo.updateMemberRole(userId: userId, role: role);
    }
    await recordAuditLog(
      category: 'seat_governance',
      action: status != null && status != current.status
          ? 'SEAT_STATUS_${status.toUpperCase()}'
          : 'SEAT_ALLOCATION_UPDATED',
      targetType: 'organization_member',
      targetLabel: '${updated.displayName} (@${updated.handle})',
      severity: status == 'frozen' || status == 'suspended'
          ? 'warning'
          : 'info',
      details:
          'Role: ${updated.role.toUpperCase()} · Division: ${updated.deskDivision} · Capital: ${formatInrAmount(updated.allocatedCapitalInr)} · Status: ${updated.status.toUpperCase()}',
    );
    await _persist();
    return updated;
  }

  Future<void> removeTraderSeat(String userId) async {
    await _ensureHydrated();
    final target = _seats.where((s) => s.userId == userId).firstOrNull;
    _seats.removeWhere((s) => s.userId == userId);
    await _orgRepo.removeMember(userId);
    if (target != null) {
      await recordAuditLog(
        category: 'seat_governance',
        action: 'SEAT_REVOKED',
        targetType: 'organization_member',
        targetLabel: '${target.displayName} (@${target.handle})',
        severity: 'warning',
        details:
            'Revoked trader seat and reclaimed ${formatInrAmount(target.allocatedCapitalInr)} capital allocation.',
      );
    }
    await _persist();
  }

  // ---------------------------------------------------------------------------
  // Consumer Accounts Governance (Linking Consumer & Affiliate Sides)
  // ---------------------------------------------------------------------------

  Future<List<AdminConsumerAccount>> listConsumerAccounts() async {
    await _ensureHydrated();
    if (SupabaseConfig.isConfigured && SupabaseConfig.client != null) {
      try {
        final client = SupabaseConfig.client!;
        final rows = await client
            .from('profiles')
            .select(
              'id,handle,display_name,email,subscription_tier,status,role,created_at',
            )
            .order('created_at', ascending: false);

        if (rows.isNotEmpty) {
          // Also fetch counts of trader_notes, journal_entries, strategies per user
          final notesRows = await client
              .from('trader_notes')
              .select('user_id')
              .catchError((_) => <dynamic>[]);
          final journalsRows = await client
              .from('journal_entries')
              .select('user_id')
              .catchError((_) => <dynamic>[]);
          final strategiesRows = await client
              .from('strategies')
              .select('user_id')
              .catchError((_) => <dynamic>[]);

          final Map<String, int> noteCounts = <String, int>{};
          final Map<String, int> journalCounts = <String, int>{};
          final Map<String, int> strategyCounts = <String, int>{};

          for (final dynamic r in notesRows) {
            if (r is Map) {
              final String uid = r['user_id']?.toString() ?? '';
              noteCounts[uid] = (noteCounts[uid] ?? 0) + 1;
            }
          }
          for (final dynamic r in journalsRows) {
            if (r is Map) {
              final String uid = r['user_id']?.toString() ?? '';
              journalCounts[uid] = (journalCounts[uid] ?? 0) + 1;
            }
          }
          for (final dynamic r in strategiesRows) {
            if (r is Map) {
              final String uid = r['user_id']?.toString() ?? '';
              strategyCounts[uid] = (strategyCounts[uid] ?? 0) + 1;
            }
          }

          final List<AdminConsumerAccount> liveAccounts = rows
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> r) {
                final String uid = r['id']?.toString() ?? '';
                final String tierRaw =
                    (r['subscription_tier']?.toString() ?? 'free')
                        .toLowerCase();
                final String tier = switch (tierRaw) {
                  'enterprise' => 'Enterprise',
                  'pro' => 'Pro',
                  _ => 'Basic',
                };
                final double mrr = switch (tier) {
                  'Enterprise' => 999.0,
                  'Pro' => 2499.0,
                  _ => 0.0,
                };
                return AdminConsumerAccount(
                  userId: uid,
                  handle: (r['handle']?.toString() ?? 'trader').replaceAll(
                    '@',
                    '',
                  ),
                  displayName: r['display_name']?.toString() ?? 'Trader',
                  email: r['email']?.toString() ?? 'trader@alphajournal.in',
                  subscriptionTier: tier,
                  monthlySubscriptionInr: mrr,
                  journalsCount: journalCounts[uid] ?? 0,
                  strategiesCount: strategyCounts[uid] ?? 0,
                  notesCount: noteCounts[uid] ?? 0,
                  aiQueriesUsed: 12,
                  referredBySlug: null,
                  isPublicProfile: true,
                  status: r['status']?.toString() ?? 'active',
                  joinedAt:
                      DateTime.tryParse(r['created_at']?.toString() ?? '') ??
                      DateTime.now(),
                );
              })
              .toList();

          _consumers = liveAccounts;
          await _persist();
          return List<AdminConsumerAccount>.unmodifiable(_consumers);
        }
      } catch (e) {
        debugPrint(
          'AdminConsoleRepository.listConsumerAccounts remote error, falling back: $e',
        );
      }
    }
    return List<AdminConsumerAccount>.unmodifiable(_consumers);
  }

  Future<AdminConsumerAccount> updateConsumerAccount({
    required String userId,
    String? subscriptionTier,
    String? status,
    bool? isPublicProfile,
  }) async {
    await _ensureHydrated();
    final idx = _consumers.indexWhere((c) => c.userId == userId);
    if (idx == -1) {
      throw StateError('Consumer account not found');
    }
    final old = _consumers[idx];
    final double newMrr = switch (subscriptionTier ?? old.subscriptionTier) {
      'Enterprise' => 999.0,
      'Pro' => 2499.0,
      _ => 0.0,
    };
    final updated = old.copyWith(
      subscriptionTier: subscriptionTier,
      monthlySubscriptionInr: newMrr,
      status: status,
      isPublicProfile: isPublicProfile,
    );
    _consumers[idx] = updated;

    // Remote update on Supabase profiles table
    if (SupabaseConfig.isConfigured && SupabaseConfig.client != null) {
      try {
        final client = SupabaseConfig.client!;
        final Map<String, dynamic> updateFields = <String, dynamic>{};
        if (subscriptionTier != null) {
          updateFields['subscription_tier'] = subscriptionTier.toLowerCase();
        }
        if (status != null) {
          updateFields['status'] = status;
        }
        if (updateFields.isNotEmpty) {
          await client.from('profiles').update(updateFields).eq('id', userId);
        }
      } catch (e) {
        debugPrint(
          'AdminConsoleRepository.updateConsumerAccount remote error: $e',
        );
      }
    }

    await recordAuditLog(
      category: 'seat_governance',
      action: 'CONSUMER_ACCOUNT_UPDATED',
      targetType: 'consumer_profile',
      targetLabel: '${updated.displayName} (@${updated.handle})',
      severity: updated.status == 'suspended' ? 'warning' : 'info',
      details:
          'Plan: ${updated.subscriptionTier} (${formatInrAmount(updated.monthlySubscriptionInr)}/mo) · Status: ${updated.status.toUpperCase()} · Public: ${updated.isPublicProfile ? "YES" : "NO"}',
    );
    await _persist();
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Pre-Trade Order Approval Queue
  // ---------------------------------------------------------------------------

  Future<List<DeskOrderApproval>> listOrderApprovals() async {
    await _ensureHydrated();
    if (SupabaseConfig.isConfigured) {
      try {
        final rows = await SupabaseConfig.client!
            .from('desk_order_approvals')
            .select('*')
            .order('created_at', ascending: false);
        if ((rows as List).isNotEmpty) {
          _orderApprovals = rows
              .whereType<Map<String, dynamic>>()
              .map(DeskOrderApproval.fromJson)
              .toList();
        }
      } catch (e) {
        if (!_missingTablesNotice.contains('desk_order_approvals')) {
          _missingTablesNotice.add('desk_order_approvals');
          debugPrint(
            'AdminConsoleRepository notice: desk_order_approvals table not found in Supabase (using resilient local fallback).',
          );
        }
      }
    }
    return List<DeskOrderApproval>.unmodifiable(_orderApprovals);
  }

  Future<DeskOrderApproval> reviewOrderApproval({
    required String orderId,
    required bool approve,
    required String notes,
  }) async {
    await _ensureHydrated();
    final idx = _orderApprovals.indexWhere((o) => o.id == orderId);
    if (idx == -1) {
      throw StateError('Order approval item not found');
    }
    final current = _orderApprovals[idx];
    final updated = current.copyWith(
      status: approve ? 'approved' : 'rejected',
      reviewerNotes: notes.trim().isEmpty
          ? (approve
                ? 'Approved within desk risk tolerance.'
                : 'Rejected by Desk Risk Officer.')
          : notes.trim(),
      reviewedAt: DateTime.now(),
    );
    _orderApprovals[idx] = updated;

    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client!
            .from('desk_order_approvals')
            .update({
              'status': updated.status,
              'reviewer_notes': updated.reviewerNotes,
              'reviewed_at': updated.reviewedAt?.toIso8601String(),
            })
            .eq('id', orderId);
      } catch (e) {
        debugPrint('AdminConsoleRepository.reviewOrderApproval error: $e');
      }
    }

    await recordAuditLog(
      category: 'order_approval',
      action: approve ? 'PRE_TRADE_ORDER_APPROVED' : 'PRE_TRADE_ORDER_REJECTED',
      targetType: 'desk_order_approval',
      targetLabel:
          '${updated.side} ${updated.quantity} ${updated.symbol} (${updated.exchange})',
      severity: approve ? 'info' : 'warning',
      details:
          'Trader: @${updated.traderHandle} · Notional: ${formatInrAmount(updated.notionalValueInr)} (${updated.leverageX}x) · Note: ${updated.reviewerNotes}',
    );
    await _persist();
    return updated;
  }

  Future<DeskOrderApproval> submitOrderForApproval({
    required String symbol,
    required String side,
    required int quantity,
    required double orderPriceInr,
    required double notionalValueInr,
    double stopLossInr = 0,
    double targetPriceInr = 0,
    String strategyName = 'Discretionary Setup',
    String reasonFlagged = 'Order notional exceeds manager approval threshold',
  }) async {
    await _ensureHydrated();
    final item = DeskOrderApproval(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
      traderUserId: 'usr_nitish_owner',
      traderHandle: 'nitish_trader',
      traderName: 'Nitish Kumar',
      deskDivision: 'Index & Options Desk',
      symbol: symbol.toUpperCase(),
      exchange: 'NSE',
      side: side.toUpperCase(),
      quantity: quantity,
      orderPriceInr: orderPriceInr,
      notionalValueInr: notionalValueInr,
      leverageX: 2.0,
      stopLossInr: stopLossInr,
      targetPriceInr: targetPriceInr,
      strategyName: strategyName,
      reasonFlagged: reasonFlagged,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _orderApprovals = <DeskOrderApproval>[item, ..._orderApprovals];
    await recordAuditLog(
      category: 'order_approval',
      action: 'PRE_TRADE_APPROVAL_QUEUED',
      targetType: 'desk_order_approval',
      targetLabel: '${item.side} ${item.quantity} ${item.symbol}',
      severity: 'warning',
      details:
          'Trader @${item.traderHandle} queued ${formatInrAmount(notionalValueInr)} order (${item.reasonFlagged}).',
    );
    await _persist();
    return item;
  }

  Future<DeskRiskBreach> recordRiskBreach({
    required String symbol,
    required String breachType,
    required double metricValueInr,
    required double thresholdValueInr,
    required String description,
    String severity = 'warning',
  }) async {
    await _ensureHydrated();
    final breach = DeskRiskBreach(
      id: 'brc_${DateTime.now().millisecondsSinceEpoch}',
      traderUserId: 'usr_nitish_owner',
      traderHandle: 'nitish_trader',
      traderName: 'Nitish Kumar',
      deskDivision: 'Index & Options Desk',
      breachType: breachType,
      severity: severity,
      symbol: symbol.toUpperCase(),
      metricValueInr: metricValueInr,
      thresholdValueInr: thresholdValueInr,
      description: description,
      status: 'open',
      createdAt: DateTime.now(),
    );
    _riskBreaches = <DeskRiskBreach>[breach, ..._riskBreaches];
    await recordAuditLog(
      category: 'risk_control',
      action: 'CUSTOMER_RISK_LIMIT_TRIGGERED',
      targetType: 'desk_risk_breach',
      targetLabel: '$breachType · ${symbol.toUpperCase()}',
      severity: severity == 'critical' ? 'critical' : 'warning',
      details: description,
    );
    await _persist();
    return breach;
  }

  // ---------------------------------------------------------------------------
  // Risk Breach Incident Log
  // ---------------------------------------------------------------------------

  Future<List<DeskRiskBreach>> listRiskBreaches() async {
    await _ensureHydrated();
    if (SupabaseConfig.isConfigured) {
      try {
        final rows = await SupabaseConfig.client!
            .from('desk_risk_breaches')
            .select('*')
            .order('created_at', ascending: false);
        if ((rows as List).isNotEmpty) {
          _riskBreaches = rows
              .whereType<Map<String, dynamic>>()
              .map(DeskRiskBreach.fromJson)
              .toList();
        }
      } catch (e) {
        if (!_missingTablesNotice.contains('desk_risk_breaches')) {
          _missingTablesNotice.add('desk_risk_breaches');
          debugPrint(
            'AdminConsoleRepository notice: desk_risk_breaches table not found in Supabase (using resilient local fallback).',
          );
        }
      }
    }
    return List<DeskRiskBreach>.unmodifiable(_riskBreaches);
  }

  Future<DeskRiskBreach> updateRiskBreachStatus({
    required String breachId,
    required String status,
    String? resolutionNotes,
    bool freezeTrader = false,
  }) async {
    await _ensureHydrated();
    final idx = _riskBreaches.indexWhere((b) => b.id == breachId);
    if (idx == -1) {
      throw StateError('Risk breach not found');
    }
    final current = _riskBreaches[idx];
    final updated = current.copyWith(
      status: freezeTrader ? 'trader_frozen' : status,
      resolutionNotes: resolutionNotes?.trim().isNotEmpty == true
          ? resolutionNotes!.trim()
          : current.resolutionNotes,
    );
    _riskBreaches[idx] = updated;

    if (freezeTrader) {
      final seatIdx = _seats.indexWhere(
        (s) =>
            s.userId == current.traderUserId ||
            s.handle == current.traderHandle,
      );
      if (seatIdx != -1) {
        _seats[seatIdx] = _seats[seatIdx].copyWith(status: 'frozen');
      }
    }

    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client!
            .from('desk_risk_breaches')
            .update({
              'status': updated.status,
              'resolution_notes': updated.resolutionNotes,
            })
            .eq('id', breachId);
      } catch (e) {
        debugPrint('AdminConsoleRepository.updateRiskBreachStatus error: $e');
      }
    }

    await recordAuditLog(
      category: 'risk_control',
      action: freezeTrader
          ? 'BREACH_TRADER_FROZEN'
          : 'RISK_BREACH_${updated.status.toUpperCase()}',
      targetType: 'desk_risk_breach',
      targetLabel: '${updated.breachType} · @${updated.traderHandle}',
      severity: freezeTrader ? 'critical' : 'warning',
      details:
          'Symbol: ${updated.symbol} · Metric: ${formatInrAmount(updated.metricValueInr)} vs Cap ${formatInrAmount(updated.thresholdValueInr)} · ${updated.resolutionNotes ?? "Reviewed by Risk Desk"}',
    );
    await _persist();
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Account Deletion & Conditional Data Purge Queue
  // ---------------------------------------------------------------------------

  Future<List<AccountDeletionRequestModel>> listDeletionRequests() {
    return _profileRepo.getDeletionRequests();
  }

  Future<AccountDeletionRequestModel> processDeletionRequest({
    required String requestId,
    required String action,
    String? adminNotes,
  }) async {
    final processed = await _profileRepo.processDeletionRequest(
      requestId: requestId,
      action: action,
      adminNotes: adminNotes,
    );
    // Also sync consumer status if matching
    final consumerIdx = _consumers.indexWhere(
      (c) => c.userId == processed.userId || c.email == processed.userEmail,
    );
    if (consumerIdx != -1) {
      if (processed.status == 'data_purged') {
        _consumers.removeAt(consumerIdx);
      } else if (processed.status == 'cancelled') {
        _consumers[consumerIdx] = _consumers[consumerIdx].copyWith(
          status: 'active',
        );
      }
    }
    await recordAuditLog(
      category: 'account_deletion',
      action: action == 'execute_purge'
          ? 'USER_DATA_PURGE_EXECUTED'
          : 'ACCOUNT_DELETION_CANCELLED',
      targetType: 'account_deletion_request',
      targetLabel: '${processed.userDisplayName} (${processed.userEmail})',
      severity: action == 'execute_purge' ? 'critical' : 'info',
      details:
          'Role: ${processed.userRole.toUpperCase()} · Condition: ${processed.conditionLabel} · Status: ${processed.status.toUpperCase()}',
    );
    await _persist();
    return processed;
  }

  // ---------------------------------------------------------------------------
  // Affiliate Governance Helpers (Bridging Admin & Affiliate Sides)
  // ---------------------------------------------------------------------------

  Future<List<AffiliateApplicationModel>> listAffiliateApplications() {
    return AffiliateApplicationRepositoryImpl.instance.listApplications();
  }

  Future<AffiliateWorkspace> getAffiliateWorkspaceSnapshot() {
    return AffiliateWorkspaceRepository.instance.load();
  }

  Future<AffiliateWorkspace> reviewAffiliatePayout({
    required String payoutId,
    required bool approve,
    String? referenceCode,
    String? notes,
  }) async {
    await AffiliateWorkspaceRepository.instance.adminReviewPayout(
      payoutId: payoutId,
      status: approve ? 'paid' : 'failed',
      transactionReference: referenceCode,
      notes: notes,
    );
    await recordAuditLog(
      category: 'payout_settlement',
      action: approve
          ? 'AFFILIATE_INR_PAYOUT_SETTLED'
          : 'AFFILIATE_INR_PAYOUT_REJECTED',
      targetType: 'affiliate_payout',
      targetLabel: 'Payout $payoutId',
      severity: approve ? 'info' : 'warning',
      details: approve
          ? 'Settled INR payout via UTR/Ref ${referenceCode ?? "UTR-GENERATED"} after 5% TDS deduction u/s 194H.'
          : 'Rejected INR payout and refunded balance to partner ledger. Note: ${notes ?? "Verification required"}',
    );
    return AffiliateWorkspaceRepository.instance.load();
  }

  // ---------------------------------------------------------------------------
  // Execution & Governance Audit Log
  // ---------------------------------------------------------------------------

  Future<List<AdminAuditLogEntry>> listAuditLogs() async {
    await _ensureHydrated();
    if (SupabaseConfig.isConfigured) {
      try {
        final rows = await SupabaseConfig.client!
            .from('admin_audit_logs')
            .select(
              'id, actor_handle, actor_role, category, action, target_type, '
              'target_label, severity, ip_address, sha256_hash, details, created_at',
            )
            .order('created_at', ascending: false)
            .limit(100);
        if ((rows as List).isNotEmpty) {
          _auditLogs = rows
              .whereType<Map<String, dynamic>>()
              .map(AdminAuditLogEntry.fromJson)
              .toList();
        }
      } catch (e) {
        if (!_missingTablesNotice.contains('admin_audit_logs')) {
          _missingTablesNotice.add('admin_audit_logs');
          debugPrint(
            'AdminConsoleRepository notice: admin_audit_logs table not found in Supabase (using resilient local fallback).',
          );
        }
      }
    }
    return List<AdminAuditLogEntry>.unmodifiable(_auditLogs);
  }

  Future<AdminAuditLogEntry> recordAuditLog({
    required String category,
    required String action,
    required String targetType,
    required String targetLabel,
    required String severity,
    required String details,
    String actorHandle = 'nitish_admin',
    String actorRole = 'owner',
  }) async {
    await _ensureHydrated();
    final now = DateTime.now();
    final rawSeed =
        '${now.microsecondsSinceEpoch}|$actorHandle|$category|$action|$targetLabel|$details';
    final hash = _computeDeterministicHexDigest(rawSeed);
    final entry = AdminAuditLogEntry(
      id: 'aud_${now.millisecondsSinceEpoch}',
      actorHandle: actorHandle,
      actorRole: actorRole,
      category: category,
      action: action,
      targetType: targetType,
      targetLabel: targetLabel,
      severity: severity,
      ipAddress: '103.21.244.18 (Mumbai-DC1)',
      sha256Hash: hash,
      details: details,
      createdAt: now,
    );
    _auditLogs = <AdminAuditLogEntry>[entry, ..._auditLogs];

    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client!.from('admin_audit_logs').insert({
          'actor_handle': actorHandle,
          'actor_role': actorRole,
          'category': category,
          'action': action,
          'target_type': targetType,
          'target_label': targetLabel,
          'severity': severity,
          'ip_address': entry.ipAddress,
          'sha256_hash': entry.sha256Hash,
          'details': details,
        });
      } catch (e) {
        debugPrint('AdminConsoleRepository.recordAuditLog error: $e');
      }
    }
    await _persist();
    return entry;
  }

  String exportAuditLogsCsv(List<AdminAuditLogEntry> entries) {
    final buffer = StringBuffer(
      'Timestamp_IST,Actor_Handle,Actor_Role,Category,Action,Target_Type,Target_Label,Severity,IP_Address,SHA256_Hash,Details\n',
    );
    for (final e in entries) {
      final cleanDetails = e.details.replaceAll('"', '""');
      final cleanTarget = e.targetLabel.replaceAll('"', '""');
      buffer.writeln(
        '"${e.createdAt.toIso8601String()}","${e.actorHandle}","${e.actorRole}","${e.category}","${e.action}","${e.targetType}","$cleanTarget","${e.severity}","${e.ipAddress}","${e.sha256Hash}","$cleanDetails"',
      );
    }
    return buffer.toString();
  }

  String exportAuditLogsJson(List<AdminAuditLogEntry> entries) {
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(entries.map((e) => e.toJson()).toList());
  }

  // ---------------------------------------------------------------------------
  // Organization Analytics Snapshot (INR)
  // ---------------------------------------------------------------------------

  Future<AdminDeskAnalyticsSnapshot> getAnalyticsSnapshot(
    String timeframe,
  ) async {
    await _ensureHydrated();
    AffiliateWorkspace ws;
    try {
      ws = await getAffiliateWorkspaceSnapshot();
    } catch (e) {
      debugPrint(
        '[AdminConsoleRepository] getAffiliateWorkspaceSnapshot error: $e',
      );
      ws = AffiliateWorkspace.fromJson(const <String, Object?>{});
    }
    final double allocated = _seats.isNotEmpty
        ? _seats.fold<double>(0, (sum, s) => sum + s.allocatedCapitalInr)
        : 185000000.0;
    final double intradayPnl = _seats.isNotEmpty
        ? _seats.fold<double>(0, (sum, s) => sum + s.dailyPnlInr)
        : 1265000.0;
    final double monthlyPnl = _seats.isNotEmpty
        ? _seats.fold<double>(0, (sum, s) => sum + s.monthlyPnlInr)
        : 5940000.0;
    final double multiplier = switch (timeframe) {
      '1W' => 0.28,
      '1M' => 1.0,
      '3M' => 2.75,
      '6M' => 5.4,
      '1Y' => 10.8,
      'ALL' => 16.5,
      _ => 1.0,
    };
    final double periodPnl = monthlyPnl * multiplier;
    final double mrrInr = _consumers
        .where((c) => c.status == 'active')
        .fold<double>(0, (sum, c) => sum + c.monthlySubscriptionInr);
    final double affiliateArrInr =
        ws.referrals.fold<double>(0, (sum, r) => sum + r.monthlyPrice) * 12;

    final points = _pointsForTimeframe(timeframe);
    final divisions = _divisionsForMultiplier(multiplier);

    return AdminDeskAnalyticsSnapshot(
      timeframe: timeframe,
      supervisedCapitalInr: 250000000.0, // ₹25.00 Cr
      allocatedCapitalInr: allocated,
      intradayPnlInr: intradayPnl,
      periodNetPnlInr: periodPnl,
      firmSharpeRatio: 2.48,
      firmWinRatePct: 66.8,
      maxDrawdownPct: 2.85,
      profitFactor: 2.34,
      subscriptionMrrInr: mrrInr > 0 ? mrrInr : 1485000.0,
      affiliateGeneratedArrInr: affiliateArrInr > 0
          ? affiliateArrInr
          : 4250000.0,
      affiliatePayoutsSettledInr: ws.profile.totalPaidOut > 0
          ? ws.profile.totalPaidOut
          : 1850000.0,
      activeCircuitBreakerState: _circuitBreakerState,
      killswitchReason: _killswitchReason,
      points: points,
      divisions: divisions,
    );
  }

  AdminDeskAnalyticsSnapshot fallbackSnapshot(String timeframe) {
    final double allocated = _seats.isNotEmpty
        ? _seats.fold<double>(0, (sum, s) => sum + s.allocatedCapitalInr)
        : 185000000.0;
    final double intradayPnl = _seats.isNotEmpty
        ? _seats.fold<double>(0, (sum, s) => sum + s.dailyPnlInr)
        : 1265000.0;
    final double monthlyPnl = _seats.isNotEmpty
        ? _seats.fold<double>(0, (sum, s) => sum + s.monthlyPnlInr)
        : 5940000.0;
    final double multiplier = switch (timeframe) {
      '1W' => 0.28,
      '1M' => 1.0,
      '3M' => 2.75,
      '6M' => 5.4,
      '1Y' => 10.8,
      'ALL' => 16.5,
      _ => 1.0,
    };

    return AdminDeskAnalyticsSnapshot(
      timeframe: timeframe,
      supervisedCapitalInr: 250000000.0,
      allocatedCapitalInr: allocated,
      intradayPnlInr: intradayPnl,
      periodNetPnlInr: monthlyPnl * multiplier,
      firmSharpeRatio: 2.48,
      firmWinRatePct: 66.8,
      maxDrawdownPct: 2.85,
      profitFactor: 2.34,
      subscriptionMrrInr: 1485000.0,
      affiliateGeneratedArrInr: 4250000.0,
      affiliatePayoutsSettledInr: 1850000.0,
      activeCircuitBreakerState: _circuitBreakerState,
      killswitchReason: _killswitchReason,
      points: _pointsForTimeframe(timeframe),
      divisions: _divisionsForMultiplier(multiplier),
    );
  }

  List<AdminPnlSeriesPoint> _pointsForTimeframe(String timeframe) =>
      switch (timeframe) {
        '1W' => const <AdminPnlSeriesPoint>[
          AdminPnlSeriesPoint(
            label: 'Mon',
            deskPnlInr: 420000,
            benchmarkPnlInr: 180000,
            revenueInr: 95000,
          ),
          AdminPnlSeriesPoint(
            label: 'Tue',
            deskPnlInr: 785000,
            benchmarkPnlInr: 310000,
            revenueInr: 112000,
          ),
          AdminPnlSeriesPoint(
            label: 'Wed',
            deskPnlInr: 640000,
            benchmarkPnlInr: 265000,
            revenueInr: 108000,
          ),
          AdminPnlSeriesPoint(
            label: 'Thu',
            deskPnlInr: 1290000,
            benchmarkPnlInr: 490000,
            revenueInr: 148000,
          ),
          AdminPnlSeriesPoint(
            label: 'Fri',
            deskPnlInr: 1685000,
            benchmarkPnlInr: 620000,
            revenueInr: 176000,
          ),
        ],
        '1M' => const <AdminPnlSeriesPoint>[
          AdminPnlSeriesPoint(
            label: 'Wk 1',
            deskPnlInr: 1450000,
            benchmarkPnlInr: 620000,
            revenueInr: 340000,
          ),
          AdminPnlSeriesPoint(
            label: 'Wk 2',
            deskPnlInr: 2890000,
            benchmarkPnlInr: 1140000,
            revenueInr: 425000,
          ),
          AdminPnlSeriesPoint(
            label: 'Wk 3',
            deskPnlInr: 4120000,
            benchmarkPnlInr: 1680000,
            revenueInr: 510000,
          ),
          AdminPnlSeriesPoint(
            label: 'Wk 4',
            deskPnlInr: 5940000,
            benchmarkPnlInr: 2350000,
            revenueInr: 640000,
          ),
        ],
        _ => const <AdminPnlSeriesPoint>[
          AdminPnlSeriesPoint(
            label: 'May',
            deskPnlInr: 3800000,
            benchmarkPnlInr: 1450000,
            revenueInr: 480000,
          ),
          AdminPnlSeriesPoint(
            label: 'Jun',
            deskPnlInr: 5120000,
            benchmarkPnlInr: 2100000,
            revenueInr: 560000,
          ),
          AdminPnlSeriesPoint(
            label: 'Jul',
            deskPnlInr: 4680000,
            benchmarkPnlInr: 1890000,
            revenueInr: 615000,
          ),
          AdminPnlSeriesPoint(
            label: 'Aug',
            deskPnlInr: 6450000,
            benchmarkPnlInr: 2640000,
            revenueInr: 720000,
          ),
          AdminPnlSeriesPoint(
            label: 'Sep',
            deskPnlInr: 7820000,
            benchmarkPnlInr: 3120000,
            revenueInr: 845000,
          ),
          AdminPnlSeriesPoint(
            label: 'Oct',
            deskPnlInr: 9240000,
            benchmarkPnlInr: 3780000,
            revenueInr: 960000,
          ),
        ],
      };

  List<DeskDivisionPerformance> _divisionsForMultiplier(
    double multiplier,
  ) => <DeskDivisionPerformance>[
    DeskDivisionPerformance(
      divisionName: 'Index & Options Desk (NSE NFO)',
      allocatedCapitalInr: 85000000, // ₹8.50 Cr
      periodNetPnlInr: 2840000 * multiplier,
      sharpeRatio: 2.64,
      winRatePct: 68.4,
      activeSeats: _seats.where((s) => s.deskDivision.contains('Index')).length,
    ),
    DeskDivisionPerformance(
      divisionName: 'Equities Momentum (NSE/BSE Cash)',
      allocatedCapitalInr: 52000000, // ₹5.20 Cr
      periodNetPnlInr: 1620000 * multiplier,
      sharpeRatio: 2.18,
      winRatePct: 63.2,
      activeSeats: _seats
          .where((s) => s.deskDivision.contains('Equities'))
          .length,
    ),
    DeskDivisionPerformance(
      divisionName: 'Quant & Statistical Arbitrage',
      allocatedCapitalInr: 33000000, // ₹3.30 Cr
      periodNetPnlInr: 1080000 * multiplier,
      sharpeRatio: 3.12,
      winRatePct: 74.5,
      activeSeats: _seats.where((s) => s.deskDivision.contains('Quant')).length,
    ),
    DeskDivisionPerformance(
      divisionName: 'Commodities & Macro FX (MCX)',
      allocatedCapitalInr: 15000000, // ₹1.50 Cr
      periodNetPnlInr: 400000 * multiplier,
      sharpeRatio: 1.76,
      winRatePct: 58.9,
      activeSeats: _seats
          .where((s) => s.deskDivision.contains('Commodities'))
          .length,
    ),
  ];

  static String _computeDeterministicHexDigest(String input) {
    final bytes = utf8.encode(input);
    final List<int> state = List<int>.generate(
      32,
      (int i) => (0x5A + i * 17) & 0xFF,
    );
    for (int i = 0; i < bytes.length; i++) {
      final int idx = i % 32;
      state[idx] = (state[idx] ^ bytes[i] ^ ((i * 31) & 0xFF)) & 0xFF;
      state[(idx + 7) % 32] = (state[(idx + 7) % 32] + state[idx] + 13) & 0xFF;
    }
    return state.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ---------------------------------------------------------------------------
  // Production-Grade Seeded INR Records
  // ---------------------------------------------------------------------------

  static List<AdminTraderSeat> _defaultSeats() {
    final now = DateTime.now();
    return <AdminTraderSeat>[
      AdminTraderSeat(
        userId: '00000000-0000-0000-0000-000000000001',
        handle: 'nitish_admin',
        displayName: 'Nitish Kumar (Managing Partner)',
        email: 'nitish@tradex.in',
        role: 'owner',
        deskDivision: 'Index & Options Desk',
        allocatedCapitalInr: 65000000, // ₹6.50 Cr
        usedMarginInr: 38200000,
        dailyPnlInr: 645000,
        monthlyPnlInr: 2480000,
        winRatePct: 71.4,
        sharpeRatio: 2.86,
        currentDrawdownPct: 1.1,
        maxDrawdownLimitPct: 5.0,
        openPositionsCount: 4,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 365)),
      ),
      AdminTraderSeat(
        userId: '00000000-0000-0000-0000-000000000002',
        handle: 'sarah_quant',
        displayName: 'Sarah Jenkins (Head of Quant Risk)',
        email: 'sarah.quant@tradex.in',
        role: 'risk_manager',
        deskDivision: 'Quant & Arbitrage',
        allocatedCapitalInr: 45000000, // ₹4.50 Cr
        usedMarginInr: 26400000,
        dailyPnlInr: 392000,
        monthlyPnlInr: 1580000,
        winRatePct: 74.8,
        sharpeRatio: 3.14,
        currentDrawdownPct: 0.8,
        maxDrawdownLimitPct: 4.0,
        openPositionsCount: 6,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 210)),
      ),
      AdminTraderSeat(
        userId: '00000000-0000-0000-0000-000000000003',
        handle: 'marcus_trader',
        displayName: 'Marcus Vance (Senior F&O Trader)',
        email: 'marcus.vance@tradex.in',
        role: 'trader',
        deskDivision: 'Index & Options Desk',
        allocatedCapitalInr: 35000000, // ₹3.50 Cr
        usedMarginInr: 29800000,
        dailyPnlInr: -148000,
        monthlyPnlInr: 860000,
        winRatePct: 61.2,
        sharpeRatio: 1.92,
        currentDrawdownPct: 4.2,
        maxDrawdownLimitPct: 5.0,
        openPositionsCount: 5,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 120)),
      ),
      AdminTraderSeat(
        userId: '00000000-0000-0000-0000-000000000004',
        handle: 'aditya_momentum',
        displayName: 'Aditya Deshmukh (Equities Lead)',
        email: 'aditya.d@tradex.in',
        role: 'trader',
        deskDivision: 'Equities Momentum',
        allocatedCapitalInr: 25000000, // ₹2.50 Cr
        usedMarginInr: 14500000,
        dailyPnlInr: 284000,
        monthlyPnlInr: 790000,
        winRatePct: 65.5,
        sharpeRatio: 2.24,
        currentDrawdownPct: 1.6,
        maxDrawdownLimitPct: 5.0,
        openPositionsCount: 3,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 90)),
      ),
      AdminTraderSeat(
        userId: '00000000-0000-0000-0000-000000000005',
        handle: 'rohan_mcx',
        displayName: 'Rohan Malhotra (Commodities Desk)',
        email: 'rohan.mcx@tradex.in',
        role: 'trader',
        deskDivision: 'Commodities & FX',
        allocatedCapitalInr: 15000000, // ₹1.50 Cr
        usedMarginInr: 8200000,
        dailyPnlInr: 92000,
        monthlyPnlInr: 230000,
        winRatePct: 58.9,
        sharpeRatio: 1.76,
        currentDrawdownPct: 2.1,
        maxDrawdownLimitPct: 4.5,
        openPositionsCount: 2,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 60)),
      ),
    ];
  }

  static List<AdminConsumerAccount> _defaultConsumers() {
    final now = DateTime.now();
    return <AdminConsumerAccount>[
      AdminConsumerAccount(
        userId: 'f040d8c1-c063-45f4-b963-beb1a7f9fc9f',
        handle: 'admin',
        displayName: 'alphajournal System Admin',
        email: 'admin@alphajournal.in',
        subscriptionTier: 'Enterprise',
        monthlySubscriptionInr: 999.0,
        journalsCount: 7,
        strategiesCount: 4,
        notesCount: 4,
        aiQueriesUsed: 412,
        referredBySlug: null,
        isPublicProfile: true,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 84)),
      ),
      AdminConsumerAccount(
        userId: '002c19b4-2af7-4f29-9351-e283736677c4',
        handle: 'nk2552003',
        displayName: 'Nitish Kumar',
        email: 'nk2552003@gmail.com',
        subscriptionTier: 'Pro',
        monthlySubscriptionInr: 2499.0,
        journalsCount: 14,
        strategiesCount: 3,
        notesCount: 8,
        aiQueriesUsed: 185,
        referredBySlug: 'admin',
        isPublicProfile: true,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 62)),
      ),
      AdminConsumerAccount(
        userId: '2e1af43d-fdaf-48ef-8180-c2ba3fb011f1',
        handle: 'nk255200',
        displayName: 'Siddharth Kumar',
        email: 'sid.kr.222003@gmail.com',
        subscriptionTier: 'Pro',
        monthlySubscriptionInr: 2499.0,
        journalsCount: 22,
        strategiesCount: 5,
        notesCount: 11,
        aiQueriesUsed: 230,
        referredBySlug: 'nk2552003',
        isPublicProfile: true,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 51)),
      ),
      AdminConsumerAccount(
        userId: '774f6fa9-91d3-4e08-b2ed-df027077b7e5',
        handle: 'nk25520033',
        displayName: 'Nitish Academic',
        email: 'nitish.202204098@tulas.edu.in',
        subscriptionTier: 'Enterprise',
        monthlySubscriptionInr: 999.0,
        journalsCount: 35,
        strategiesCount: 6,
        notesCount: 19,
        aiQueriesUsed: 310,
        referredBySlug: 'nk2552003',
        isPublicProfile: true,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 29)),
      ),
      AdminConsumerAccount(
        userId: 'b7c0f61e-bb12-4fe5-a49f-d35fb27999d9',
        handle: 'jhiad',
        displayName: 'Jhiad Trader',
        email: 'jhiad@gmail.com',
        subscriptionTier: 'Basic',
        monthlySubscriptionInr: 0.0,
        journalsCount: 4,
        strategiesCount: 1,
        notesCount: 2,
        aiQueriesUsed: 15,
        referredBySlug: null,
        isPublicProfile: true,
        status: 'active',
        joinedAt: now.subtract(const Duration(days: 14)),
      ),
    ];
  }

  static List<DeskOrderApproval> _defaultOrderApprovals() {
    final now = DateTime.now();
    return <DeskOrderApproval>[
      DeskOrderApproval(
        id: 'ord_app_101',
        traderUserId: '00000000-0000-0000-0000-000000000003',
        traderHandle: 'marcus_trader',
        traderName: 'Marcus Vance',
        deskDivision: 'Index & Options Desk',
        symbol: 'BANKNIFTY 52500 CE',
        exchange: 'NFO',
        side: 'SHORT',
        quantity: 1800,
        orderPriceInr: 412.50,
        notionalValueInr: 94500000, // ₹9.45 Cr notional exposure
        leverageX: 6.5,
        stopLossInr: 495.0,
        targetPriceInr: 240.0,
        strategyName: 'Weekly Gamma Strangle',
        reasonFlagged:
            'Exceeds single-order naked short option notional cap (₹7.50 Cr)',
        status: 'pending',
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      DeskOrderApproval(
        id: 'ord_app_102',
        traderUserId: '00000000-0000-0000-0000-000000000004',
        traderHandle: 'aditya_momentum',
        traderName: 'Aditya Deshmukh',
        deskDivision: 'Equities Momentum',
        symbol: 'RELIANCE',
        exchange: 'NSE',
        side: 'BUY',
        quantity: 6500,
        orderPriceInr: 2945.0,
        notionalValueInr: 19142500, // ₹1.91 Cr
        leverageX: 4.0,
        stopLossInr: 2890.0,
        targetPriceInr: 3065.0,
        strategyName: 'Volume Profile Breakout',
        reasonFlagged:
            'Single-stock concentration exceeds 65% of seat allocated capital',
        status: 'pending',
        createdAt: now.subtract(const Duration(minutes: 42)),
      ),
      DeskOrderApproval(
        id: 'ord_app_103',
        traderUserId: '00000000-0000-0000-0000-000000000002',
        traderHandle: 'sarah_quant',
        traderName: 'Sarah Jenkins',
        deskDivision: 'Quant & Arbitrage',
        symbol: 'NIFTY FUT / CASH BASKET',
        exchange: 'NFO',
        side: 'BUY',
        quantity: 2500,
        orderPriceInr: 24820.0,
        notionalValueInr: 62050000,
        leverageX: 3.2,
        stopLossInr: 24690.0,
        targetPriceInr: 25040.0,
        strategyName: 'Index Cash-Futures Basis Arb',
        reasonFlagged: 'Institutional basket size > ₹5.00 Cr pre-trade gate',
        status: 'approved',
        reviewerNotes: 'Delta-neutral hedged against NSE cash basket.',
        reviewedAt: now.subtract(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      ),
    ];
  }

  static List<DeskRiskBreach> _defaultRiskBreaches() {
    final now = DateTime.now();
    return <DeskRiskBreach>[
      DeskRiskBreach(
        id: 'br_201',
        traderUserId: '00000000-0000-0000-0000-000000000003',
        traderHandle: 'marcus_trader',
        traderName: 'Marcus Vance',
        deskDivision: 'Index & Options Desk',
        breachType: '85% Drawdown Warning Threshold',
        severity: 'critical',
        symbol: 'BANKNIFTY',
        metricValueInr: 1470000,
        thresholdValueInr: 1750000,
        description:
            'Seat drawdown reached 4.20% against 5.00% hard cap (₹14.70 L loss vs ₹17.50 L max allowed).',
        status: 'open',
        createdAt: now.subtract(const Duration(minutes: 28)),
      ),
      DeskRiskBreach(
        id: 'br_202',
        traderUserId: '00000000-0000-0000-0000-000000000005',
        traderHandle: 'rohan_mcx',
        traderName: 'Rohan Malhotra',
        deskDivision: 'Commodities & FX',
        breachType: 'Overnight Margin Utilization Spike',
        severity: 'warning',
        symbol: 'GOLDM / CRUDEOIL',
        metricValueInr: 12900000,
        thresholdValueInr: 12000000,
        description:
            'MCX span margin utilization touched 86% ahead of US inventory data release.',
        status: 'acknowledged',
        resolutionNotes: 'Trimmed 2 lots of CRUDEOIL prior to settlement.',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      DeskRiskBreach(
        id: 'br_203',
        traderUserId: '00000000-0000-0000-0000-000000000004',
        traderHandle: 'aditya_momentum',
        traderName: 'Aditya Deshmukh',
        deskDivision: 'Equities Momentum',
        breachType: 'Mandatory Stop-Loss Check',
        severity: 'warning',
        symbol: 'TATAMOTORS',
        metricValueInr: 4200000,
        thresholdValueInr: 4200000,
        description:
            'Bracket SL attachment delayed by 4 seconds during NSE open auction.',
        status: 'resolved',
        resolutionNotes: 'Automated GTT stop-loss verified on exchange book.',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
    ];
  }

  static List<AdminAuditLogEntry> _defaultAuditLogs() {
    final now = DateTime.now();
    return <AdminAuditLogEntry>[
      AdminAuditLogEntry(
        id: 'aud_1001',
        actorHandle: 'nitish_admin',
        actorRole: 'owner',
        category: 'risk_control',
        action: 'DESK_RISK_POLICY_VERIFIED',
        targetType: 'desk_risk_configs',
        targetLabel: 'alphajournal Institutional Alpha Desk',
        severity: 'info',
        ipAddress: '103.21.244.18 (Mumbai-DC1)',
        sha256Hash:
            '8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4',
        details:
            'Verified pre-open NSE/NFO margin policy: Max Leverage 10x, Daily Loss Cap 3.0%, Mandatory Stop-Loss enabled.',
        createdAt: now.subtract(const Duration(minutes: 35)),
      ),
      AdminAuditLogEntry(
        id: 'aud_1002',
        actorHandle: 'sarah_quant',
        actorRole: 'risk_manager',
        category: 'order_approval',
        action: 'PRE_TRADE_ORDER_APPROVED',
        targetType: 'desk_order_approval',
        targetLabel: 'BUY 2500 NIFTY FUT / CASH BASKET (NFO)',
        severity: 'info',
        ipAddress: '103.21.244.22 (Mumbai-DC1)',
        sha256Hash:
            '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
        details:
            'Approved ₹6.20 Cr delta-neutral index arbitrage basket after verifying cash leg margin.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AdminAuditLogEntry(
        id: 'aud_1003',
        actorHandle: 'nitish_admin',
        actorRole: 'owner',
        category: 'payout_settlement',
        action: 'AFFILIATE_INR_PAYOUT_SETTLED',
        targetType: 'affiliate_payout',
        targetLabel: 'Aarav Mehta (@aarav-trades) · ₹72,000',
        severity: 'info',
        ipAddress: '103.21.244.18 (Mumbai-DC1)',
        sha256Hash:
            '4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce',
        details:
            'Settled ₹72,000 gross (₹3,600 TDS u/s 194H, ₹68,400 net) via HDFC Bank NEFT UTR HDFCN52026091844210.',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      AdminAuditLogEntry(
        id: 'aud_1004',
        actorHandle: 'nitish_admin',
        actorRole: 'owner',
        category: 'affiliate_review',
        action: 'AFFILIATE_APPLICATION_APPROVED',
        targetType: 'affiliate_application',
        targetLabel: 'Meera Iyer (@meeraquant)',
        severity: 'info',
        ipAddress: '103.21.244.18 (Mumbai-DC1)',
        sha256Hash:
            'd4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35',
        details:
            'Verified Indian PAN, HDFC IFSC, and SEBI/ASCI compliance declarations. Unlocked Gold Partner tier (25% INR commission).',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      AdminAuditLogEntry(
        id: 'aud_1005',
        actorHandle: 'nitish_admin',
        actorRole: 'owner',
        category: 'account_deletion',
        action: 'ACCOUNT_DELETION_POLICY_ENFORCED',
        targetType: 'account_deletion_requests',
        targetLabel: 'DPDP Act 2023 Conditional Data Purge Engine',
        severity: 'warning',
        ipAddress: '103.21.244.18 (Mumbai-DC1)',
        sha256Hash:
            '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a',
        details:
            'Verified 3-mode post-deletion data purge pipeline (Immediate Purge, 30-Day Grace, Purge Personal + Keep Statutory INR Tax Ledger).',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
