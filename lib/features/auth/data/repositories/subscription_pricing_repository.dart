import 'package:tradex/core/app-ui/theme/app_tokens.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';

abstract class SubscriptionPricingRepository {
  /// Fetches the complete pricing catalogue including plans, matrix categories, and FAQs.
  Future<PricingCatalogueResponse> getPricingCatalogue({bool annual = false});

  /// Selects or triggers checkout for [tierId] under [billingCycle].
  Future<void> selectPlan({
    required String tierId,
    required String billingCycle,
  });
}

class SubscriptionPricingRepositoryImpl
    implements SubscriptionPricingRepository {
  SubscriptionPricingRepositoryImpl({
    DemoDataSource? source,
    AppSession? session,
  }) : _source = source ?? DemoDataSource.instance,
       _session = session ?? AppSession.instance;

  final DemoDataSource _source;
  final AppSession _session;

  @override
  Future<PricingCatalogueResponse> getPricingCatalogue({
    bool annual = false,
  }) async {
    // Simulate brief network retrieval for backend alignment
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final AppTier currentTier = _session.tier.value;

    final List<PricingPlanModel> plans = <PricingPlanModel>[
      PricingPlanModel(
        id: 'tier_free',
        tier: AppTier.free,
        name: 'Free',
        subtitle: 'For individuals exploring quantitative markets & charting',
        monthlyAmount: 0,
        annualMonthlyAmount: 0,
        currencySymbol: '₹',
        isCurrent: currentTier == AppTier.free,
        ctaLabel: currentTier == AppTier.free
            ? 'Current Plan'
            : 'Continue with Free',
        featuresSummary: const <String>[
          'Up to 100 quantitative journal logs',
          'Standard NSE / BSE candlestick charting',
          'Basic technical indicators (RSI, MACD, EMA)',
          'Community social feed & strategy sharing',
          '1 Custom Watchlist (up to 20 instruments)',
          '20 AI copilot queries / month',
          'Standard end-of-day market data feed',
          'Community forum & public knowledgebase',
        ],
      ),
      PricingPlanModel(
        id: 'tier_pro',
        tier: AppTier.premium,
        name: 'Pro',
        subtitle: 'For active traders & quants scaling their market edge',
        monthlyAmount: 2499,
        annualMonthlyAmount: 1999, // ~20% discount (₹1,999/mo billed as ₹23,988/yr)
        currencySymbol: '₹',
        highlighted: true,
        badgeLabel: 'MOST POPULAR',
        isCurrent: currentTier == AppTier.premium,
        ctaLabel: currentTier == AppTier.premium
            ? 'Current Plan'
            : 'Upgrade to Pro',
        featuresSummary: const <String>[
          'Unlimited quantitative journal entries',
          'Auto-screenshot chart capture & auto-fill',
          'AI Trade Assistant & Chart Vision recognition',
          'Real-time Level 2 multi-timeframe scanner',
          'Equity curve analytics & Sharpe drawdown',
          'Unlimited watchlists with real-time alerts',
          'Strategy backtester & version history logs',
          '500 AI copilot queries / month',
          'Priority email & dedicated trader support',
        ],
      ),
      PricingPlanModel(
        id: 'tier_enterprise',
        tier: AppTier.enterprise,
        name: 'Enterprise',
        subtitle: 'For prop trading desks, funds & institutional teams',
        monthlyAmount: 7999,
        annualMonthlyAmount: 6499, // ~20% discount (₹6,499/mo billed annually)
        currencySymbol: '₹',
        isCurrent: currentTier == AppTier.enterprise,
        ctaLabel: currentTier == AppTier.enterprise
            ? 'Current Plan'
            : 'Get Enterprise',
        featuresSummary: const <String>[
          'Everything in Pro, plus:',
          '10 Desk seats with granular role controls',
          'Desk-wide daily loss guardrails & hard stops',
          'Low-latency dedicated VPS gateway & bridges',
          'REST & FIX Webhook API for automated orders',
          'Custom AI model fine-tuning on playbooks',
          '5,000 AI copilot requests / month',
          'Institutional audit trail & CSV/PDF export',
          'Dedicated account manager & 99.9% uptime SLA',
        ],
      ),
    ];

    final List<PlanFeatureCategory> categories = <PlanFeatureCategory>[
      const PlanFeatureCategory(
        id: 'cat_trading',
        name: 'Core Trading & Analysis',
        rows: <PlanComparisonRow>[
          PlanComparisonRow(
            id: 'feat_data_feed',
            title: 'Indian Market Data Feed (NSE / BSE / MCX)',
            tooltip: 'Live tick-by-tick real-time quotes and depth.',
            freeValue: '15m Delayed',
            proValue: 'Real-time Tick',
            enterpriseValue: 'Ultra-low Latency VPS',
          ),
          PlanComparisonRow(
            id: 'feat_chart_layouts',
            title: 'Multi-Timeframe Chart Layouts',
            tooltip: 'Simultaneous synchronized chart panels per workspace.',
            freeValue: '1 Chart',
            proValue: 'Up to 8 Charts',
            enterpriseValue: 'Unlimited Multi-Monitor',
          ),
          PlanComparisonRow(
            id: 'feat_indicators',
            title: 'Technical Indicators & Pine Scripts',
            tooltip: 'Access to custom indicators, overlays, and quant tools.',
            freeValue: '15 Basic',
            proValue: '100+ Indicators & Custom Scripts',
            enterpriseValue: 'Full Quant Library & Pine Engine',
          ),
          PlanComparisonRow(
            id: 'feat_scanners',
            title: 'Live Market Screener & Scanner',
            tooltip: 'Screening for breakouts, momentum, and volume surges.',
            freeValue: 'Top 20 Gainers/Losers',
            proValue: 'Live Multi-Filter Scanner',
            enterpriseValue: 'Continuous Algorithmic Scanner',
          ),
        ],
      ),
      const PlanFeatureCategory(
        id: 'cat_journaling',
        name: 'Quantitative Journaling & Backtesting',
        rows: <PlanComparisonRow>[
          PlanComparisonRow(
            id: 'feat_journal_logs',
            title: 'Monthly Journal Entries',
            tooltip: 'Maximum trade executions logged per month.',
            freeValue: '100 entries / mo',
            proValue: 'Unlimited',
            enterpriseValue: 'Unlimited Multi-Trader',
          ),
          PlanComparisonRow(
            id: 'feat_screenshot_sync',
            title: 'Chart Screenshot Auto-Capture',
            tooltip: 'Automatically binds broker execution charts to journals.',
            freeValue: false,
            proValue: true,
            enterpriseValue: true,
            isBoolean: true,
          ),
          PlanComparisonRow(
            id: 'feat_analytics',
            title: 'Equity Curve & Risk Statistics (Sharpe, Drawdown)',
            tooltip: 'Calculates performance metrics, win rates, and R-multiples.',
            freeValue: 'Basic PnL',
            proValue: 'Full Quant Analytics',
            enterpriseValue: 'Desk Exposure & VaR Analytics',
          ),
          PlanComparisonRow(
            id: 'feat_backtest',
            title: 'Strategy Backtester & Version History',
            tooltip: 'Simulate playbooks across historical price datasets.',
            freeValue: '1 Playbook',
            proValue: 'Unlimited Backtests',
            enterpriseValue: 'Walk-Forward Optimization Engine',
          ),
          PlanComparisonRow(
            id: 'feat_export',
            title: 'Tax & Compliance CSV / PDF Export',
            tooltip: 'Download audit-ready trade execution and PnL sheets.',
            freeValue: false,
            proValue: true,
            enterpriseValue: true,
            isBoolean: true,
          ),
        ],
      ),
      const PlanFeatureCategory(
        id: 'cat_ai',
        name: 'AI Copilot & Market Intelligence',
        rows: <PlanComparisonRow>[
          PlanComparisonRow(
            id: 'feat_ai_queries',
            title: 'Monthly AI Copilot Queries',
            tooltip: 'AI chart pattern, sentiment, and setup analysis queries.',
            freeValue: '20 queries / mo',
            proValue: '500 queries / mo',
            enterpriseValue: '5,000 queries / mo',
          ),
          PlanComparisonRow(
            id: 'feat_vision_pattern',
            title: 'Chart Vision Pattern Recognition',
            tooltip: 'Detects flags, double tops, orderblocks, and fair value gaps.',
            freeValue: false,
            proValue: true,
            enterpriseValue: true,
            isBoolean: true,
          ),
          PlanComparisonRow(
            id: 'feat_sentiment',
            title: 'Real-Time Macro News Sentiment Engine',
            tooltip: 'Instant sentiment score for RBI decisions, earnings, and news.',
            freeValue: 'Headline Feed',
            proValue: 'Real-time Sentiment Scoring',
            enterpriseValue: 'High-Frequency Sentiment API',
          ),
        ],
      ),
      const PlanFeatureCategory(
        id: 'cat_desk',
        name: 'Desk Governance, Risk & Support',
        rows: <PlanComparisonRow>[
          PlanComparisonRow(
            id: 'feat_seats',
            title: 'Team Seats & Organization Roster',
            tooltip: 'Included seats with role-based permission hierarchy.',
            freeValue: '1 Trader',
            proValue: '1 Trader',
            enterpriseValue: '10 Seats Included (Add more)',
          ),
          PlanComparisonRow(
            id: 'feat_risk_guards',
            title: 'Prop Desk Hard Risk Stops & Daily Loss Caps',
            tooltip: 'Automated circuit breaker halts trading on limit breach.',
            freeValue: false,
            proValue: 'Alerts Only',
            enterpriseValue: 'Automated Broker Hard Stop',
          ),
          PlanComparisonRow(
            id: 'feat_api_access',
            title: 'REST, WebSocket & FIX Webhooks',
            tooltip: 'Automated programmatic execution and data extraction.',
            freeValue: false,
            proValue: 'Read-only API',
            enterpriseValue: 'Full Read & Write Webhooks',
          ),
          PlanComparisonRow(
            id: 'feat_support',
            title: 'Customer & Technical Support SLA',
            tooltip: 'Direct access to market specialists and quant team.',
            freeValue: 'Community Forum',
            proValue: 'Priority Chat & Email',
            enterpriseValue: 'Dedicated Account Manager (99.9% SLA)',
          ),
        ],
      ),
    ];

    final List<PricingFaqItem> faqs = const <PricingFaqItem>[
      PricingFaqItem(
        id: 'faq_1',
        category: 'billing',
        question: 'Can I change or cancel my plan at any time?',
        answer:
            'Yes. You can upgrade, downgrade, or cancel your subscription at any time directly from Account Settings. If you cancel, you will maintain full access through the end of your prepaid billing period.',
      ),
      PricingFaqItem(
        id: 'faq_2',
        category: 'billing',
        question: 'Are prices in Indian Rupees (INR) and do they include GST?',
        answer:
            'All prices are listed in Indian Rupees (INR ₹). At checkout, standard 18% Indian GST is itemized transparently with tax invoices provided for business input tax credit (ITC).',
      ),
      PricingFaqItem(
        id: 'faq_3',
        category: 'billing',
        question: 'What payment methods do you accept?',
        answer:
            'We accept UPI (Google Pay, PhonePe, Paytm), all major Indian Credit and Debit Cards (Visa, Mastercard, RuPay), Net Banking across 50+ Indian banks, and international cards via Stripe/Razorpay.',
      ),
      PricingFaqItem(
        id: 'faq_4',
        category: 'features',
        question: 'How does the AI Trading Copilot work?',
        answer:
            'TradeX AI evaluates chart images, technical indicator states, and market structure using neural vision models. It highlights high-probability risk-to-reward invalidation levels and detects complex pattern formations.',
      ),
      PricingFaqItem(
        id: 'faq_5',
        category: 'features',
        question: 'Can I connect my existing Indian broker account?',
        answer:
            'Yes. TradeX supports direct auto-sync integration with major Indian brokers including Zerodha Kite, Upstox, Angel One, Dhan, and Groww for automated journal logging and order execution.',
      ),
      PricingFaqItem(
        id: 'faq_6',
        category: 'enterprise',
        question: 'What is included in the Enterprise plan for prop desks?',
        answer:
            'Enterprise provides multi-seat manager dashboards, desk-wide daily loss limits, low-latency dedicated VPS connectivity, audit logs, and custom webhook API access for automated algorithmic systems.',
      ),
    ];

    return PricingCatalogueResponse(
      plans: plans,
      categories: categories,
      faqs: faqs,
      annualDiscountPercent: 20,
      annualMonthsBilled: _source.annualMonthsBilled,
    );
  }

  @override
  Future<void> selectPlan({
    required String tierId,
    required String billingCycle,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final AppTier pickedTier = switch (tierId) {
      'tier_pro' || 'premium' => AppTier.premium,
      'tier_enterprise' || 'enterprise' => AppTier.enterprise,
      _ => AppTier.free,
    };
    _session.startPeriod(pickedTier, billingCycle);
  }
}
