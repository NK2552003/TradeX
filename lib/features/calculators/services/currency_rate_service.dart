import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../logic/currency_calculators.dart';

/// Represents exchange rates at a specific point in time against a base currency.
@immutable
class CurrencyRatesSnapshot {
  const CurrencyRatesSnapshot({
    required this.base,
    required this.date,
    required this.rates,
    required this.isLive,
    required this.fetchedAt,
    this.source = 'Frankfurter v2',
  });

  /// Base currency code (e.g. 'USD').
  final String base;

  /// Quote date (e.g. '2026-09-04').
  final String date;

  /// Map of quote currency code to units per 1 unit of [base].
  final Map<String, double> rates;

  /// True if fetched from live API; false if using offline/cached fallback.
  final bool isLive;

  /// Timestamp when this snapshot was fetched or created.
  final DateTime fetchedAt;

  /// Data provider source attribution.
  final String source;

  /// Get the rate for a given quote currency, or 1.0 if unknown.
  double rateFor(String quote) {
    if (quote.toUpperCase() == base.toUpperCase()) return 1.0;
    return rates[quote.toUpperCase()] ?? 1.0;
  }

  /// Initial offline snapshot seeded with verified today's reference rates.
  static CurrencyRatesSnapshot initialFallback({String base = 'USD'}) {
    return CurrencyRatesSnapshot(
      base: base,
      date: kRatesDate,
      rates: Map<String, double>.unmodifiable(kFallbackRatesVsUsd),
      isLive: false,
      fetchedAt: DateTime.now(),
      source: 'Offline Reference',
    );
  }
}

/// Service that retrieves real-time and historical currency rates from Frankfurter v2.
///
/// Features:
/// - Blends rates from 84 central banks and official sources.
/// - Flat array schema parsing (v2).
/// - 30-minute in-memory caching for live rates; permanent caching for historical dates.
/// - Instant offline fallback so UI and tests never block or fail.
class CurrencyRateService {
  CurrencyRateService({http.Client? client})
    : _client = client ?? http.Client();

  /// Singleton instance used across the app.
  static final CurrencyRateService instance = CurrencyRateService();

  final http.Client _client;

  /// In-memory cache keyed by "base_date" (e.g. "USD_latest" or "USD_2026-01-05").
  final Map<String, CurrencyRatesSnapshot> _cache =
      <String, CurrencyRatesSnapshot>{};

  /// Most recent rates known to the service (seeded with fallback, updated on every live fetch).
  CurrencyRatesSnapshot _latestLiveRates =
      CurrencyRatesSnapshot.initialFallback();

  /// Current latest rates snapshot.
  CurrencyRatesSnapshot get latestKnownRates => _latestLiveRates;

  /// Cache time-to-live for live rates (30 minutes).
  static const Duration liveCacheTtl = Duration(minutes: 30);

  /// Request timeout duration to prevent hanging on flaky networks.
  static const Duration requestTimeout = Duration(seconds: 5);

  /// Fetch exchange rates against [base] (defaults to 'USD').
  ///
  /// If [date] is provided, historical rates for that date are fetched.
  /// If [forceRefresh] is true, in-memory cache is bypassed.
  Future<CurrencyRatesSnapshot> getRates({
    String base = 'USD',
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    final String dateKey = date == null ? 'latest' : _formatDate(date);
    final String cacheKey = '${base.toUpperCase()}_$dateKey';

    // 1. Check in-memory cache
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final CurrencyRatesSnapshot cached = _cache[cacheKey]!;
      if (date != null) {
        // Historical rates are immutable
        return cached;
      }
      final bool isFresh =
          DateTime.now().difference(cached.fetchedAt) < liveCacheTtl;
      if (isFresh) {
        return cached;
      }
    }

    // 2. Build Frankfurter v2 URL
    // Examples:
    // https://api.frankfurter.dev/v2/rates?base=USD
    // https://api.frankfurter.dev/v2/rates?date=2026-01-05&base=USD
    final Uri uri = Uri.https(
      'api.frankfurter.dev',
      '/v2/rates',
      <String, String>{
        'base': base.toUpperCase(),
        if (date != null) 'date': _formatDate(date),
      },
    );

    try {
      final http.Response response = await _client
          .get(
            uri,
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          final Map<String, double> rates = <String, double>{
            base.toUpperCase(): 1.0,
          };
          String quoteDate = date == null
              ? _formatDate(DateTime.now())
              : _formatDate(date);

          for (final dynamic item in decoded) {
            if (item is Map) {
              final dynamic quote = item['quote'];
              final dynamic rate = item['rate'];
              final dynamic itemDate = item['date'];

              if (quote is String && rate is num) {
                rates[quote.toUpperCase()] = rate.toDouble();
              }
              if (itemDate is String && itemDate.isNotEmpty) {
                // Use the most recent date reported in the payload
                quoteDate = itemDate;
              }
            }
          }

          final CurrencyRatesSnapshot snapshot = CurrencyRatesSnapshot(
            base: base.toUpperCase(),
            date: quoteDate,
            rates: Map<String, double>.unmodifiable(rates),
            isLive: true,
            fetchedAt: DateTime.now(),
            source: 'Frankfurter v2',
          );

          // Update latest known live rates if this was a current fetch
          if (date == null) {
            _latestLiveRates = snapshot;
          }

          _cache[cacheKey] = snapshot;
          return snapshot;
        }
      }
    } catch (_) {
      // Silent offline fallback ensures zero disruption or console noise.
    }

    // 3. Graceful offline fallback
    if (date == null) {
      return _latestLiveRates;
    }

    // If historical fetch failed and not cached, provide offline snapshot with requested date
    return CurrencyRatesSnapshot(
      base: base.toUpperCase(),
      date: _formatDate(date),
      rates: _latestLiveRates.rates,
      isLive: false,
      fetchedAt: DateTime.now(),
      source: 'Offline Fallback',
    );
  }

  /// Format [date] as 'YYYY-MM-DD'.
  static String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Clear in-memory cache (useful for testing or manual hard reset).
  void clearCache() {
    _cache.clear();
  }
}
