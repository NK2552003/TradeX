import 'package:flutter/foundation.dart';

@immutable
class TradingPrefsModel {
  const TradingPrefsModel({
    this.defaultPositionSizePercent = 2.0,
    this.defaultRMultipleTarget = 2.5,
    this.defaultWatchlistSymbols = const <String>[
      'NIFTY50',
      'BANKNIFTY',
      'RELIANCE',
      'TCS',
      'HDFCBANK',
    ],
    this.watchlistRefreshIntervalSeconds = 15,
    this.preferredCurrency = 'INR',
    this.marketTimezone = 'Asia/Kolkata (IST)',
    this.defaultAssetClass = 'Equities',
    this.requireChecklistConfirmation = false,
    this.deductEstimatedFeesFromPnl = true,
  });

  final double defaultPositionSizePercent;
  final double defaultRMultipleTarget;
  final List<String> defaultWatchlistSymbols;
  final int watchlistRefreshIntervalSeconds;
  final String preferredCurrency;
  final String marketTimezone;
  final String defaultAssetClass;
  final bool requireChecklistConfirmation;
  final bool deductEstimatedFeesFromPnl;

  factory TradingPrefsModel.defaultPrefs() {
    return const TradingPrefsModel(
      defaultPositionSizePercent: 2.0,
      defaultRMultipleTarget: 2.5,
      defaultWatchlistSymbols: <String>[
        'NIFTY50',
        'BANKNIFTY',
        'RELIANCE',
        'TCS',
        'HDFCBANK',
      ],
      watchlistRefreshIntervalSeconds: 15,
      preferredCurrency: 'INR',
      marketTimezone: 'Asia/Kolkata (IST)',
      defaultAssetClass: 'Equities',
      requireChecklistConfirmation: false,
      deductEstimatedFeesFromPnl: true,
    );
  }

  factory TradingPrefsModel.fromJson(Map<String, dynamic> json) {
    return TradingPrefsModel(
      defaultPositionSizePercent:
          (json['default_position_size_pct'] as num?)?.toDouble() ?? 2.0,
      defaultRMultipleTarget:
          (json['default_r_multiple'] as num?)?.toDouble() ?? 2.5,
      defaultWatchlistSymbols:
          (json['default_watchlist_symbols'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          TradingPrefsModel.defaultPrefs().defaultWatchlistSymbols,
      watchlistRefreshIntervalSeconds:
          json['watchlist_refresh_interval_seconds'] as int? ?? 15,
      preferredCurrency: (json['preferred_currency'] as String?) ?? 'INR',
      marketTimezone:
          (json['market_timezone'] as String?) ?? 'Asia/Kolkata (IST)',
      defaultAssetClass:
          (json['default_asset_class'] as String?) ?? 'Equities',
      requireChecklistConfirmation:
          json['require_checklist_confirmation'] as bool? ?? false,
      deductEstimatedFeesFromPnl:
          json['deduct_estimated_fees_pnl'] as bool? ?? true,
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

  Map<String, dynamic> toExtrasJson() {
    return <String, dynamic>{
      'preferred_currency': preferredCurrency,
      'market_timezone': marketTimezone,
      'default_asset_class': defaultAssetClass,
      'require_checklist_confirmation': requireChecklistConfirmation,
      'deduct_estimated_fees_pnl': deductEstimatedFeesFromPnl,
    };
  }

  TradingPrefsModel mergeExtrasJson(Map<String, dynamic> json) {
    final String? currency = (json['preferred_currency'] as String?)?.trim();
    final String? tz = (json['market_timezone'] as String?)?.trim();
    final String? assetClass = (json['default_asset_class'] as String?)?.trim();
    return copyWith(
      preferredCurrency:
          currency != null && currency.isNotEmpty ? currency : null,
      marketTimezone: tz != null && tz.isNotEmpty ? tz : null,
      defaultAssetClass:
          assetClass != null && assetClass.isNotEmpty ? assetClass : null,
      requireChecklistConfirmation:
          json['require_checklist_confirmation'] as bool?,
      deductEstimatedFeesFromPnl:
          json['deduct_estimated_fees_pnl'] as bool?,
    );
  }

  TradingPrefsModel copyWith({
    double? defaultPositionSizePercent,
    double? defaultRMultipleTarget,
    List<String>? defaultWatchlistSymbols,
    int? watchlistRefreshIntervalSeconds,
    String? preferredCurrency,
    String? marketTimezone,
    String? defaultAssetClass,
    bool? requireChecklistConfirmation,
    bool? deductEstimatedFeesFromPnl,
  }) {
    return TradingPrefsModel(
      defaultPositionSizePercent:
          defaultPositionSizePercent ?? this.defaultPositionSizePercent,
      defaultRMultipleTarget:
          defaultRMultipleTarget ?? this.defaultRMultipleTarget,
      defaultWatchlistSymbols:
          defaultWatchlistSymbols ?? this.defaultWatchlistSymbols,
      watchlistRefreshIntervalSeconds:
          watchlistRefreshIntervalSeconds ??
          this.watchlistRefreshIntervalSeconds,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      marketTimezone: marketTimezone ?? this.marketTimezone,
      defaultAssetClass: defaultAssetClass ?? this.defaultAssetClass,
      requireChecklistConfirmation:
          requireChecklistConfirmation ?? this.requireChecklistConfirmation,
      deductEstimatedFeesFromPnl:
          deductEstimatedFeesFromPnl ?? this.deductEstimatedFeesFromPnl,
    );
  }
}
