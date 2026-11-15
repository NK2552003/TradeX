import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/public_site/models/public_site_content.dart';

abstract class PublicSiteRepository {
  Future<PublicSiteContent> landing();
  Future<Map<String, dynamic>> pricing();
}

/// In-memory fallback fixtures matching database schema.
class MockPublicSiteRepository implements PublicSiteRepository {
  MockPublicSiteRepository({AssetBundle? bundle});

  static Map<String, dynamic> get defaultLanding =>
      jsonDecode(jsonEncode(_defaultLanding)) as Map<String, dynamic>;

  static Map<String, dynamic> get defaultPricing =>
      jsonDecode(jsonEncode(_defaultPricing)) as Map<String, dynamic>;

  static const Map<String, dynamic> _defaultLanding = {
    'brand': 'alphajournal',
    'title': 'The Foundation for your Trading System',
    'description':
        'AI analysis, quantitative journaling, market intelligence, and community in one workspace. Built for precision, clarity, and disciplined execution.',
    'signin_label': 'Sign in',
    'start_label': 'Get Started Free',
    'pricing_label': 'Explore Plans',
    'features_title': 'Tools for Every Trading Decision',
    'roles_title': 'Choose Your Workspace',
    'pricing_title': 'Plans for Your Trading Workspace',
    'faq_title': 'Frequently Asked Questions',
    'footer':
        'alphajournal · A workspace for disciplined traders. Market information is provided for research; it is not investment advice.',
    'retry_label': 'Try again',
    'error_title': 'Unable to load page content',
    'features': [
      {
        'title': 'Institutional Community',
        'description':
            'Share setups, discuss markets, and follow traders across a curated community.',
        'icon': 'forum',
      },
      {
        'title': 'Quantitative Journaling',
        'description':
            'Record execution, review equity curves, and connect notes with your trading playbooks.',
        'icon': 'book',
      },
      {
        'title': 'Market Intelligence',
        'description':
            'Browse market news, instrument snapshots, price history, and company fundamentals.',
        'icon': 'news',
      },
      {
        'title': 'AI Trading Assistant',
        'description':
            'Review charts and trading ideas with context from your workspace.',
        'icon': 'ai',
      },
    ],
    'roles': [
      {
        'id': 'customer',
        'title': 'Trader',
        'description':
            'Build discipline with journals, strategies, notes, and a trading community.',
        'cta': 'Get Started as Trader',
      },
      {
        'id': 'affiliate',
        'title': 'Affiliate',
        'description':
            'Grow your audience with referral links, campaign tracking, and transparent commissions.',
        'cta': 'Apply as Affiliate',
      },
    ],
    'faqs': [
      {
        'id': 'landing_records',
        'category': 'features',
        'question': 'How do notes, journals, and strategies connect?',
        'answer':
            'Link your private writing records and selectively publish individual records to the community.',
      },
      {
        'id': 'landing_roles',
        'category': 'general',
        'question': 'Can I use AlphaJournal on mobile and web?',
        'answer':
            'Yes, AlphaJournal is fully responsive and synced across web and mobile.',
      },
    ],
  };

  static const Map<String, dynamic> _defaultPricing = {
    'copy': {
      'title': 'Select a Plan',
      'subtitle':
          'Start on Free with 3 notes and community view access. Monthly subscriptions for Basic and Pro are disabled for now.',
      'annual_badge': 'Save 20%',
      'billed_annually': 'Billed annually',
      'monthly': 'Monthly',
      'Recommended': 'MONTHLY SUBSCRIPTIONS DISABLED',
      'current': 'Current Plan',
      'selected': 'Selected Plan',
      'select': 'Select',
      'footer':
          'Free includes up to 3 notes, community view, and core tools. Paid monthly subscriptions are temporarily disabled.',
    },
    'plans': [
      {
        'id': 'tier_free',
        'tier': 'free',
        'name': 'Free',
        'tagline':
            'Essential starter workspace with 3 notes, community view access, and core trading tools.',
        'monthly_amount': 0.0,
        'annual_monthly_amount': 0.0,
        'currency_symbol': '₹',
        'is_popular': false,
        'is_purchasable': true,
        'badge_label': 'AVAILABLE NOW',
        'cta_label': 'Continue with Free',
        'limits': {
          'notes': 3,
          'trades': 15,
          'live_playbooks': 1,
          'watchlists': 1,
          'alerts': 3,
          'community_posts_per_day': 2,
          'community_comments_per_day': 10,
          'ai_queries_per_month': 5,
          'allow_pdf_export': false,
          'allow_advanced_backtest': false,
        },
        'features': [
          'Up to 3 research notes',
          'Up to 15 logged trades (total)',
          '1 active playbook, 1 watchlist & 3 price alerts',
          'Up to 2 community posts/day & 10 comments/day',
          'Up to 5 AI prompts per month',
          'Core calculators & market view',
        ],
      },
      {
        'id': 'tier_pro',
        'tier': 'premium',
        'name': 'Basic',
        'tagline':
            'Expanded trading workspace with 25 notes, 100 trades, 5 watchlists, and 20 AI prompts/mo.',
        'monthly_amount': 299.0,
        'annual_monthly_amount': 239.0,
        'currency_symbol': '₹',
        'is_popular': true,
        'is_purchasable': false,
        'badge_label': 'MONTHLY SUBSCRIPTIONS DISABLED',
        'cta_label': 'Monthly subscriptions disabled',
        'limits': {
          'notes': 25,
          'trades': 100,
          'live_playbooks': 3,
          'watchlists': 5,
          'alerts': 25,
          'community_posts_per_day': 15,
          'community_comments_per_day': 50,
          'ai_queries_per_month': 20,
          'allow_pdf_export': false,
          'allow_advanced_backtest': false,
        },
        'features': [
          'Up to 25 research notes & 100 logged trades',
          'Up to 3 active playbooks, 5 watchlists & 25 alerts',
          'Up to 15 community posts/day & 50 comments/day',
          'Up to 20 AI prompts per month',
          'Full community participation & market data',
          'Monthly subscriptions disabled for now',
        ],
      },
      {
        'id': 'tier_enterprise',
        'tier': 'enterprise',
        'name': 'Pro',
        'tagline':
            'High-capacity professional workspace with 10,000 notes, 50,000 trades, and 5,000 AI prompts.',
        'monthly_amount': 499.0,
        'annual_monthly_amount': 399.0,
        'currency_symbol': '₹',
        'is_popular': false,
        'is_purchasable': false,
        'badge_label': 'MONTHLY SUBSCRIPTIONS DISABLED',
        'cta_label': 'Monthly subscriptions disabled',
        'limits': {
          'notes': 10000,
          'trades': 50000,
          'live_playbooks': 250,
          'watchlists': 100,
          'alerts': 500,
          'community_posts_per_day': 100,
          'community_comments_per_day': 500,
          'ai_queries_per_month': 5000,
          'allow_pdf_export': true,
          'allow_advanced_backtest': true,
        },
        'features': [
          'Up to 10,000 notes & 50,000 logged trades',
          'Up to 250 playbooks, 100 watchlists & 500 alerts',
          'Up to 100 community posts/day & 500 comments/day',
          'Up to 5,000 AI prompts per month',
          'PDF & CSV exports + advanced analytics',
          'Monthly subscriptions disabled for now',
        ],
      },
    ],
    'categories': [
      {
        'id': 'workspace_quotas',
        'name': 'Workspace & Playbooks',
        'rows': [
          {
            'id': 'notes',
            'title': 'Research Notes',
            'free_value': '3',
            'pro_value': '25',
            'enterprise_value': '10,000',
          },
          {
            'id': 'trades',
            'title': 'Journal Trades',
            'free_value': '15',
            'pro_value': '100',
            'enterprise_value': '50,000',
          },
          {
            'id': 'live_playbooks',
            'title': 'Live Playbooks',
            'free_value': '1',
            'pro_value': '3',
            'enterprise_value': '250',
          },
          {
            'id': 'watchlists',
            'title': 'Watchlists',
            'free_value': '1',
            'pro_value': '5',
            'enterprise_value': '100',
          },
          {
            'id': 'alerts',
            'title': 'Price Alerts',
            'free_value': '3',
            'pro_value': '25',
            'enterprise_value': '500',
          },
        ],
      },
      {
        'id': 'ai_community',
        'name': 'AI Copilot, Community & Exports',
        'rows': [
          {
            'id': 'ai_queries_per_month',
            'title': 'AI Prompts / Month',
            'free_value': '5',
            'pro_value': '20',
            'enterprise_value': '5,000',
          },
          {
            'id': 'community_posts_per_day',
            'title': 'Community Posts / Day',
            'free_value': '2',
            'pro_value': '15',
            'enterprise_value': '100',
          },
          {
            'id': 'community_comments_per_day',
            'title': 'Comments / Day',
            'free_value': '10',
            'pro_value': '50',
            'enterprise_value': '500',
          },
          {
            'id': 'pdf_export',
            'title': 'PDF & CSV Exports',
            'is_boolean': true,
            'free_value': false,
            'pro_value': false,
            'enterprise_value': true,
          },
          {
            'id': 'advanced_backtest',
            'title': 'Advanced Backtest & Analytics',
            'is_boolean': true,
            'free_value': false,
            'pro_value': false,
            'enterprise_value': true,
          },
        ],
      },
    ],
  };

  @override
  Future<PublicSiteContent> landing() async =>
      PublicSiteContent.fromJson(Map<String, dynamic>.from(_defaultLanding));

  @override
  Future<Map<String, dynamic>> pricing() async =>
      Map<String, dynamic>.from(_defaultPricing);
}

class DatabasePublicSiteRepository implements PublicSiteRepository {
  DatabasePublicSiteRepository(
    this.client, {
    PublicSiteRepository? fallback,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _fallback = fallback ?? MockPublicSiteRepository();
  final SupabaseClient client;
  final PublicSiteRepository _fallback;
  final Duration requestTimeout;
  @override
  Future<PublicSiteContent> landing() async {
    try {
      final row = await client
          .from('public_site_pages')
          .select('content')
          .eq('id', 'landing')
          .eq('published', true)
          .maybeSingle()
          .timeout(requestTimeout);
      final content = row?['content'];
      if (content is! Map || content.isEmpty) return await _fallback.landing();
      return PublicSiteContent.fromJson(Map<String, dynamic>.from(content));
    } catch (_) {
      return await _fallback.landing();
    }
  }

  @override
  Future<Map<String, dynamic>> pricing() async {
    final row = await client
        .from('pricing_catalogues')
        .select('catalogue')
        .eq('id', 'default')
        .eq('published', true)
        .maybeSingle()
        .timeout(requestTimeout);
    final content = row?['catalogue'];
    if (content is! Map || (content['plans'] as List? ?? []).isEmpty) {
      throw StateError('No published pricing catalogue is available.');
    }
    return Map<String, dynamic>.from(content);
  }
}

PublicSiteRepository publicSiteRepository() => SupabaseConfig.isConfigured
    ? DatabasePublicSiteRepository(SupabaseConfig.client!)
    : _UnconfiguredPublicSiteRepository();

class _UnconfiguredPublicSiteRepository extends MockPublicSiteRepository {
  @override
  Future<Map<String, dynamic>> pricing() {
    if (CustomerDataPolicy.allowDemo) {
      return super.pricing();
    }
    return Future<Map<String, dynamic>>.error(
      StateError('Supabase is required to load subscription pricing.'),
    );
  }
}
