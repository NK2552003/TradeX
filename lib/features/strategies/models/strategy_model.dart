import 'package:flutter/material.dart';

/// Strategy rule types for defining entry/exit conditions.
enum StrategyRuleType {
  entryLong,
  entryShort,
  exitLong,
  exitShort,
  stopLoss,
  takeProfit,
  positionSizing,
  riskManagement,
}

/// A single rule within a strategy playbook.
class StrategyRule {
  const StrategyRule({
    required this.id,
    required this.type,
    required this.description,
    this.conditions = const [],
    this.priority = 0,
  });

  final String id;
  final StrategyRuleType type;
  final String description;
  final List<String> conditions;
  final int priority;
}

/// Linked item reference (trade or note).
class LinkedItem {
  const LinkedItem({
    required this.id,
    required this.type,
    this.title,
  });

  final String id;
  final LinkedItemType type;
  final String? title;
}

enum LinkedItemType { trade, note }

/// Enhanced strategy model with rules and links.
class Strategy {
  const Strategy({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.rules = const [],
    this.linkedTrades = const [],
    this.linkedNotes = const [],
    this.isPublic = false,
    this.isFavorite = false,
    this.tradesCount = 0,
    this.winRate = 0,
    this.avgR = 0,
    this.netPnl = 0,
    this.createdAt,
    this.updatedAt,
    this.versionCount = 1,
    this.equityCurve = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? category;
  final List<StrategyRule> rules;
  final List<LinkedItem> linkedTrades;
  final List<LinkedItem> linkedNotes;
  final bool isPublic;
  final bool isFavorite;
  final int tradesCount;
  final double winRate;
  final double avgR;
  final double netPnl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int versionCount;
  final List<double> equityCurve;

  Strategy copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    List<StrategyRule>? rules,
    List<LinkedItem>? linkedTrades,
    List<LinkedItem>? linkedNotes,
    bool? isPublic,
    bool? isFavorite,
    int? tradesCount,
    double? winRate,
    double? avgR,
    double? netPnl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? versionCount,
    List<double>? equityCurve,
  }) {
    return Strategy(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      rules: rules ?? this.rules,
      linkedTrades: linkedTrades ?? this.linkedTrades,
      linkedNotes: linkedNotes ?? this.linkedNotes,
      isPublic: isPublic ?? this.isPublic,
      isFavorite: isFavorite ?? this.isFavorite,
      tradesCount: tradesCount ?? this.tradesCount,
      winRate: winRate ?? this.winRate,
      avgR: avgR ?? this.avgR,
      netPnl: netPnl ?? this.netPnl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      versionCount: versionCount ?? this.versionCount,
      equityCurve: equityCurve ?? this.equityCurve,
    );
  }
}
