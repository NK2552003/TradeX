import 'package:tradex/core/config/customer_data_policy.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';

abstract class AiRepository {
  Future<List<AppAiInsight>> getInsights({String? ticker});
  Future<AppAiInsight> requestInsight({required String kind, String? ticker});
}

class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl();

  List<AppAiInsight> _fallbackInsights() {
    if (!CustomerDataPolicy.allowDemo) return [];
    return <AppAiInsight>[
      AppAiInsight(
        id: 'ai_001',
        title: 'NIFTY50 Volatility Compression',
        body:
            'Bollinger Band width on NIFTY50 daily chart hit a 6-month low. Breakout expected towards 24,600 within 3-5 sessions.',
        confidence: 0.88,
        sentimentScore: 0.75,
        tickers: const ['NIFTY50'],
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      AppAiInsight(
        id: 'ai_002',
        title: 'RELIANCE Institutional Accumulation',
        body:
            'Large block transactions detected on RELIANCE at 2,900 support level coinciding with positive RSI divergence.',
        confidence: 0.82,
        sentimentScore: 0.68,
        tickers: const ['RELIANCE'],
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }

  @override
  Future<List<AppAiInsight>> getInsights({String? ticker}) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        var query = client.from('ai_insights').select('*');
        if (ticker != null && ticker.isNotEmpty) {
          query = query.eq('ticker', ticker.toUpperCase());
        }
        final response = await query
            .order('generated_at', ascending: false)
            .limit(20);

        final insights = (response as List<dynamic>).map((row) {
          final map = row as Map<String, dynamic>;
          final indicators = map['indicators'] as Map<String, dynamic>? ?? {};
          final confidenceVal = indicators['confidence'] as num? ?? 0.85;
          final sentimentVal = indicators['sentiment_score'] as num? ?? 0.72;
          final rowTicker = map['ticker'] as String? ?? 'N/A';

          return AppAiInsight(
            id: map['id'] as String,
            title: '$rowTicker Analysis Signal',
            body: map['summary'] as String? ?? '',
            confidence: confidenceVal.toDouble(),
            sentimentScore: sentimentVal.toDouble(),
            tickers: [rowTicker],
            createdAt: map['generated_at'] != null
                ? DateTime.parse(map['generated_at'] as String)
                : DateTime.now(),
          );
        }).toList();

        if (insights.isNotEmpty) return insights;
      } catch (e) {
        debugPrint('AiRepositoryImpl.getInsights error: $e');
      }
    }
    return _fallbackInsights();
  }

  @override
  Future<AppAiInsight> requestInsight({
    required String kind,
    String? ticker,
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? '';
        if (targetUserId.isNotEmpty) {
          await client.from('ai_insight_requests').insert({
            'user_id': targetUserId,
            'kind': kind,
            'ticker': ticker?.toUpperCase(),
          });
        }
      } catch (e) {
        debugPrint('AiRepositoryImpl.requestInsight insert error: $e');
      }
    }

    if (!CustomerDataPolicy.allowDemo) {
      throw StateError('AI service is unavailable.');
    }
    return AppAiInsight(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      title: ticker != null
          ? '${ticker.toUpperCase()} Dynamic Signal'
          : 'Market Quant Synthesis',
      body: ticker != null
          ? 'Automated pattern scanner detected momentum breakout setup on ${ticker.toUpperCase()} with 1:3.2 Risk/Reward ratio.'
          : 'Broad market breadth indicates high institutional accumulation in Semiconductor & Tech sectors.',
      confidence: 0.89,
      sentimentScore: 0.78,
      tickers: ticker != null ? [ticker.toUpperCase()] : ['NVDA', 'AAPL'],
      createdAt: DateTime.now(),
    );
  }
}
