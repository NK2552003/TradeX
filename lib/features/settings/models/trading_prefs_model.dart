import 'package:flutter/foundation.dart';

@immutable
class TradingPrefsModel {
  const TradingPrefsModel({
    this.defaultPositionSizePercent = 2.0,
    this.defaultRMultipleTarget = 2.5,
    this.defaultWatchlistSymbols = const <String>['NIFTY50', 'BANKNIFTY', 'RELIANCE', 'TCS', 'HDFCBANK'],
    this.watchlistRefreshIntervalSeconds = 15,
  });

  final double defaultPositionSizePercent;
  final double defaultRMultipleTarget;
  final List<String> defaultWatchlistSymbols;
  final int watchlistRefreshIntervalSeconds;

  factory TradingPrefsModel.defaultPrefs() {
    return const TradingPrefsModel(
      defaultPositionSizePercent: 2.0,
      defaultRMultipleTarget: 2.5,
      defaultWatchlistSymbols: <String>['NIFTY50', 'BANKNIFTY', 'RELIANCE', 'TCS', 'HDFCBANK'],
      watchlistRefreshIntervalSeconds: 15,
    );
  }

  factory TradingPrefsModel.fromJson(Map<String, dynamic> json) {
    return TradingPrefsModel(
      defaultPositionSizePercent: (json['default_position_size_pct'] as num?)?.toDouble() ?? 2.0,
      defaultRMultipleTarget: (json['default_r_multiple'] as num?)?.toDouble() ?? 2.5,
      defaultWatchlistSymbols: (json['default_watchlist_symbols'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          TradingPrefsModel.defaultPrefs().defaultWatchlistSymbols,
      watchlistRefreshIntervalSeconds:
          json['watchlist_refresh_interval_seconds'] as int? ?? 15,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'default_position_size_pct': defaultPositionSizePercent,
      'default_r_multiple': defaultRMultipleTarget,
      'default_watchlist_symbols': defaultWatchlistSymbols,
      'watchlist_refresh_interval_seconds': watchlistRefreshIntervalSeconds,
    };
  }

  TradingPrefsModel copyWith({
    double? defaultPositionSizePercent,
    double? defaultRMultipleTarget,
    List<String>? defaultWatchlistSymbols,
    int? watchlistRefreshIntervalSeconds,
  }) {
    return TradingPrefsModel(
      defaultPositionSizePercent:
          defaultPositionSizePercent ?? this.defaultPositionSizePercent,
      defaultRMultipleTarget:
          defaultRMultipleTarget ?? this.defaultRMultipleTarget,
      defaultWatchlistSymbols:
          defaultWatchlistSymbols ?? this.defaultWatchlistSymbols,
      watchlistRefreshIntervalSeconds:
          watchlistRefreshIntervalSeconds ?? this.watchlistRefreshIntervalSeconds,
    );
  }
}
