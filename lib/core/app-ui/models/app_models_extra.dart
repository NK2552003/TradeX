import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// A single OHLCV bar for [UiCandleChart].
@immutable
class AppCandle {
  const AppCandle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  bool get isBullish => close >= open;
}

/// Author of a message in the AI assistant thread.
enum AppAiRole { user, assistant, system }

@immutable
class AppAiMessage {
  const AppAiMessage({
    required this.id,
    required this.role,
    required this.body,
    this.sentAt,
    this.pending = false,
    this.error,
    this.sources = const <String>[],
    this.attachments = const <String>[],
  });

  final String id;
  final AppAiRole role;
  final String body;
  final DateTime? sentAt;
  final bool pending;
  final String? error;
  final List<String> sources;
  final List<String> attachments;
}

/// A suggested prompt chip shown above the AI composer.
@immutable
class AppAiPrompt {
  const AppAiPrompt({required this.label, required this.prompt, this.icon});

  final String label;
  final String prompt;
  final IconData? icon;
}

/// Node in the strategy / ticker relationship graph.
@immutable
class AppGraphNode {
  const AppGraphNode({
    required this.id,
    required this.label,
    this.group,
    this.weight = 1,
    this.intent = UiIntent.primary,
  });

  final String id;
  final String label;
  final String? group;
  final double weight;
  final UiIntent intent;
}

@immutable
class AppGraphLink {
  const AppGraphLink({
    required this.source,
    required this.target,
    this.strength = 1,
    this.label,
  });

  final String source;
  final String target;
  final double strength;
  final String? label;
}

/// Kinds of results the global search surface can return.
enum AppSearchKind { trade, strategy, ticker, trader, post, note }

@immutable
class AppSearchResult {
  const AppSearchResult({
    required this.id,
    required this.title,
    required this.kind,
    this.subtitle,
    this.meta,
    this.avatarUrl,
  });

  final String id;
  final String title;
  final AppSearchKind kind;
  final String? subtitle;
  final String? meta;
  final String? avatarUrl;
}

/// Backtest / strategy simulation output.
@immutable
class AppBacktestResult {
  const AppBacktestResult({
    required this.id,
    required this.name,
    required this.netPnl,
    required this.winRate,
    required this.trades,
    required this.equityCurve,
    this.maxDrawdown = 0,
    this.profitFactor,
    this.sharpe,
    this.runAt,
  });

  final String id;
  final String name;
  final double netPnl;
  final double winRate;
  final int trades;
  final List<double> equityCurve;
  final double maxDrawdown;
  final double? profitFactor;
  final double? sharpe;
  final DateTime? runAt;
}

// ---------------------------------------------------------------------------
// Enterprise / team
// ---------------------------------------------------------------------------

enum AppTeamRole { owner, admin, analyst, member, viewer }

enum AppMemberStatus { active, invited, suspended }

@immutable
class AppTeamMember {
  const AppTeamMember({
    required this.id,
    required this.name,
    required this.email,
    this.role = AppTeamRole.member,
    this.status = AppMemberStatus.active,
    this.avatarUrl,
    this.lastActiveAt,
  });

  final String id;
  final String name;
  final String email;
  final AppTeamRole role;
  final AppMemberStatus status;
  final String? avatarUrl;
  final DateTime? lastActiveAt;
}

@immutable
class AppAuditEntry {
  const AppAuditEntry({
    required this.id,
    required this.actor,
    required this.action,
    required this.at,
    this.target,
    this.ip,
  });

  final String id;
  final String actor;
  final String action;
  final DateTime at;
  final String? target;
  final String? ip;
}

@immutable
class AppApiKey {
  const AppApiKey({
    required this.id,
    required this.label,
    required this.maskedKey,
    required this.createdAt,
    this.lastUsedAt,
    this.revoked = false,
    this.scopes = const <String>[],
  });

  final String id;
  final String label;
  final String maskedKey;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final bool revoked;
  final List<String> scopes;
}

@immutable
class AppUsageMetric {
  const AppUsageMetric({
    required this.label,
    required this.used,
    required this.limit,
    this.unit,
  });

  final String label;
  final double used;
  final double limit;
  final String? unit;

  double get ratio => limit <= 0 ? 0 : (used / limit).clamp(0, 1).toDouble();
}
