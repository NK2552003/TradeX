import 'package:flutter/material.dart';
import 'package:alphajournal/core/navigation/customer_routes.dart';
import 'package:alphajournal/core/navigation/share_links.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';

/// Filter categories for the right-side Feature Showcase overlay.
enum FeatureShowcaseCategory {
  all('All', Icons.grid_view_rounded),
  workspace('Workspace', Icons.dashboard_customize_outlined),
  markets('Markets', Icons.candlestick_chart_outlined),
  social('Social & DM', Icons.forum_outlined),
  ai('AI & Voice', Icons.auto_awesome_outlined),
  growth('Growth & Admin', Icons.verified_user_outlined);

  const FeatureShowcaseCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Interactive preview template rendered inside the Feature Showcase overlay.
enum FeaturePreviewKind {
  workspace,
  journal,
  notes,
  strategies,
  calculators,
  market,
  community,
  messages,
  aiCopilot,
  notifications,
  affiliate,
  settings,
  admin,
}

@immutable
class FeatureShowcaseStep {
  const FeatureShowcaseStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

@immutable
class FeatureSpecRow {
  const FeatureSpecRow({required this.label, required this.value});

  final String label;
  final String value;
}

@immutable
class FeatureShowcaseItem {
  const FeatureShowcaseItem({
    required this.id,
    required this.title,
    required this.tagline,
    required this.category,
    required this.previewKind,
    required this.destinationId,
    required this.icon,
    required this.subdomain,
    required this.tierBadge,
    required this.summary,
    required this.detailedParagraphs,
    required this.specs,
    required this.helperTips,
    required this.highlights,
    required this.reviewNote,
    required this.demoSteps,
    this.searchKeywords = const <String>[],
    this.requiresAffiliateAccess = false,
    this.requiresAdminAccess = false,
    this.supportsPageTour = false,
  });

  final String id;
  final String title;
  final String tagline;
  final FeatureShowcaseCategory category;
  final FeaturePreviewKind previewKind;
  final String destinationId;
  final IconData icon;
  final CustomerSubdomain subdomain;
  final String tierBadge;
  final String summary;
  final List<String> detailedParagraphs;
  final List<FeatureSpecRow> specs;
  final List<String> helperTips;
  final List<String> highlights;
  final String reviewNote;
  final List<FeatureShowcaseStep> demoSteps;
  final List<String> searchKeywords;
  final bool requiresAffiliateAccess;
  final bool requiresAdminAccess;
  final bool supportsPageTour;

  String canonicalUrl({UserRole? activeRole}) => AppShareLinks.destinationUrl(
    destinationId,
    activeRole: activeRole,
    currentHost: subdomain.host,
  );

  bool matchesDestination(String destination) {
    final normalized = destination.trim().toLowerCase();
    if (normalized == destinationId.toLowerCase()) return true;
    if (id == 'market' && normalized.startsWith('market')) return true;
    if (id == 'community' && normalized.startsWith('community')) return true;
    if (id == 'settings' && normalized.startsWith('settings')) return true;
    if (id == 'affiliate' &&
        (normalized == 'affiliate_application' ||
            normalized == 'referrals' ||
            normalized == 'marketing' ||
            normalized == 'payouts' ||
            normalized == 'overview')) {
      return !requiresAdminAccess;
    }
    if (id == 'admin' &&
        (normalized.startsWith('admin_') ||
            normalized == 'affiliate_reviews' ||
            normalized == 'overview')) {
      return requiresAdminAccess;
    }
    return false;
  }

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q) ||
        tagline.toLowerCase().contains(q) ||
        summary.toLowerCase().contains(q) ||
        subdomain.host.toLowerCase().contains(q)) {
      return true;
    }
    return searchKeywords.any((kw) => kw.toLowerCase().contains(q)) ||
        highlights.any((h) => h.toLowerCase().contains(q)) ||
        detailedParagraphs.any((p) => p.toLowerCase().contains(q));
  }
}

/// Builds the full in-app catalog of every AlphaJournal feature.
List<FeatureShowcaseItem> buildFeatureShowcaseCatalog({
  required bool hasAffiliateAccess,
  required bool hasAdminAccess,
}) {
  return <FeatureShowcaseItem>[
    const FeatureShowcaseItem(
      id: 'workspace',
      title: 'Writing Desk & Workspace',
      tagline:
          'Unified daily command center linking trades, notes & playbooks.',
      category: FeatureShowcaseCategory.workspace,
      previewKind: FeaturePreviewKind.workspace,
      destinationId: 'workspace',
      icon: Icons.home_outlined,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'Free · Basic · Pro',
      summary:
          'Start every market session from one workspace with a horizontal calendar strip, quick-create actions, and cross-linked records.',
      detailedParagraphs: <String>[
        'Writing Desk replaces scattered spreadsheets and disconnected note apps with a single chronological timeline of your trading life. Pick any date on the horizontal calendar strip to inspect all Journal executions, Research Notes, and Strategy edits recorded on that day.',
        'Every edge stored inside AlphaJournal is bidirectional: linking a Trade to a Strategy Playbook automatically surfaces that execution inside the Strategy dossier, while mentioning a \$SYMBOL or [[Note]] builds an interactive knowledge graph.',
        'Press ⌘K (or tap Search) from anywhere to jump instantaneously between documents, calculators, tickers, and community handles without losing context.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(label: 'Canonical Host', value: 'app.alphajournal.in'),
        FeatureSpecRow(
          label: 'Free Plan Access',
          value: 'Full Desk + Calendar',
        ),
        FeatureSpecRow(
          label: 'Link Graph',
          value: 'Bidirectional (Notes / Trades / Playbooks)',
        ),
        FeatureSpecRow(
          label: 'Command Palette',
          value: '⌘K / Ctrl+K Global Search',
        ),
      ],
      helperTips: <String>[
        'Press ⌘K anywhere to search records, symbols, or jump tools',
        'Use [[Note Title]] inside any doc to auto-link across your desk',
        'Activity dots on calendar dates highlight heavy trading days',
      ],
      highlights: <String>[
        'Horizontal calendar strip with active trade, note, and playbook activity dots',
        'Zero-orphan bidirectional graph connecting setups, theses, and outcomes',
        'Instant post-login workspace synced seamlessly across *.alphajournal.in',
      ],
      reviewNote:
          'Strongest as your morning & closing-bell home screen. Log pre-market levels in Notes, track executions in Journal, and audit everything per calendar day.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Pick a trading day on the calendar strip',
          detail:
              'Inspect trades, notes, and strategy revisions logged for that market session.',
        ),
        FeatureShowcaseStep(
          title: 'Launch a quick-create record from the Desk',
          detail:
              'Create a Trade Entry, Thesis Note, or Playbook without switching sections.',
        ),
        FeatureShowcaseStep(
          title: 'Traverse linked records via ⌘K or inline chips',
          detail:
              'Hop seamlessly between a losing trade and its parent Strategy Playbook.',
        ),
      ],
      searchKeywords: <String>['home', 'calendar', 'desk', 'overview', 'cmd+k'],
    ),
    const FeatureShowcaseItem(
      id: 'journal',
      title: 'Trade Execution Journal',
      tagline:
          'Capture entries, exits, R-multiples, psychology & chart setups.',
      category: FeatureShowcaseCategory.workspace,
      previewKind: FeaturePreviewKind.journal,
      destinationId: 'journal',
      icon: Icons.book_outlined,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'Free (15) · Basic (100) · Pro (50,000)',
      summary:
          'Capture every execution with 7 structured templates, entry/stop/target metrics, R-multiple & P&L calculation, chart attachments, and mistake tags.',
      detailedParagraphs: <String>[
        'Consistent profitability comes from reviewing process quality alongside P&L. Trade Execution Journal captures side (Long/Short), entry price, stop loss, exit target, quantity, slippage/charges, and conviction score in one responsive ticket.',
        'Instead of manually calculating expectancy in Excel, AlphaJournal derives net P&L, Realized R-multiple, Win Rate, and Profit Factor automatically across 1W, 1M, and All-Time windows—and correlates losses against custom mistake tags like FOMO, Over-sizing, or Early Exit.',
        'Each trade can attach chart snapshots, connect back to a Strategy Playbook, export cleanly as a publication-grade PDF (Pro), share privately in E2EE Messages, or publish publicly via `?public=true` links.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Included in Free Plan',
          value: '15 entries total',
        ),
        FeatureSpecRow(
          label: 'Basic Plan (₹299/mo)',
          value: '100 entries total',
        ),
        FeatureSpecRow(
          label: 'Pro Plan (₹499/mo)',
          value: '50,000 entries + PDF Export',
        ),
        FeatureSpecRow(
          label: 'Built-in Templates',
          value: '7 Execution Templates',
        ),
        FeatureSpecRow(
          label: 'Exports & Sharing',
          value: 'PDF + E2EE DM + Public Web Link',
        ),
      ],
      helperTips: <String>[
        'Use Calculators -> "Draft to Journal" to pre-fill quantity & stop loss',
        'Tag at least 1 mistake or emotion per trade to spot behavioral patterns',
        'Mark setups Public to share ?public=true cards with mentors or peers',
      ],
      highlights: <String>[
        '7 structured templates: Intraday, Swing, Options, Scalp, Review & more',
        'Automatic net P&L, expectancy, profit factor & R-multiple telemetry',
        'One-click AI Copilot debriefing on any logged execution',
      ],
      reviewNote:
          'Standout discipline builder: pairs numerical execution telemetry with mistake/emotion tags and AI debriefing. Monthly entry limits reset cleanly per billing cycle.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Open a new entry & select an execution template',
          detail:
              'Fill symbol, Long/Short direction, entry, stop loss, target, and quantity.',
        ),
        FeatureShowcaseStep(
          title: 'Link a Strategy Playbook & attach chart proof',
          detail:
              'Record setup quality and tag emotional state or execution mistakes.',
        ),
        FeatureShowcaseStep(
          title: 'Audit expectancy or share a public breakdown',
          detail:
              'Export PDF or share directly to WhatsApp, X, Telegram, or E2EE DM.',
        ),
      ],
      searchKeywords: <String>[
        'trades',
        'pnl',
        'execution',
        'r-multiple',
        'log',
      ],
      supportsPageTour: true,
    ),
    const FeatureShowcaseItem(
      id: 'notes',
      title: 'Linked Trading Notes',
      tagline: 'Markdown research wiki with [[wiki links]] & AI Note Refactor.',
      category: FeatureShowcaseCategory.workspace,
      previewKind: FeaturePreviewKind.notes,
      destinationId: 'notes',
      icon: Icons.note_alt_outlined,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'Free (3) · Basic (25) · Pro (10,000)',
      summary:
          'Write pre-market plans, earnings research, macro notes, and ticker theses in Markdown with inline symbol chips and AI Note Refactor.',
      detailedParagraphs: <String>[
        'Trading research happens at speed: central bank commentary, quarterly numbers, key support/resistance bands, and sector rotation clues. Linked Trading Notes gives you a clean Markdown editor with 8 ready-made research templates.',
        'Insert `\$TICKER` cashtags or `[[Backlinks]]` to weave notes together with active strategies and logged executions. Any ticker chip opens its live Market dossier on click without losing your draft.',
        'After market hours, run AI Note Refactor to transform messy intraday bullets into crisp headings, bull/bear scenarios, and key invalidation triggers ready for PDF export or community sharing.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(label: 'Included in Free Plan', value: '3 notes'),
        FeatureSpecRow(label: 'Basic Plan (₹299/mo)', value: '25 notes'),
        FeatureSpecRow(
          label: 'Pro Plan (₹499/mo)',
          value: '10,000 notes + PDF Export',
        ),
        FeatureSpecRow(
          label: 'Research Templates',
          value: '8 Templates (Pre-Market, Earnings, etc.)',
        ),
        FeatureSpecRow(
          label: 'AI Integration',
          value: 'One-Click Note Refactor & Summarizer',
        ),
      ],
      helperTips: <String>[
        'Type \$NIFTY50 or \$RELIANCE to embed live navigable symbol pills',
        'Run AI Refactor on chaotic live-market bullets after closing bell',
        'Community posts can be clipped straight into Notes from Share menus',
      ],
      highlights: <String>[
        '8 institutional templates plus Markdown checklists and tables',
        'Cross-links seamlessly into Strategies, Trades, and Market Dossiers',
        'Publish research memos via public web links or PDF exports',
      ],
      reviewNote:
          'Best workflow: capture unstructured observations fast during the session, then click AI Refactor post-close to standardize your archive.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Choose Pre-Market, Earnings, or Blank Note template',
          detail:
              'Outline key price zones, catalysts, and invalidation triggers in Markdown.',
        ),
        FeatureShowcaseStep(
          title: 'Add \$SYMBOL cashtags and [[Strategy]] links',
          detail:
              'Build clickable edges into live quotes and existing workspace playbooks.',
        ),
        FeatureShowcaseStep(
          title: 'Clean up with AI Refactor & publish or export',
          detail: 'Save polished Markdown/PDF or share with fellow traders.',
        ),
      ],
      searchKeywords: <String>[
        'markdown',
        'wiki',
        'research',
        'thesis',
        'refactor',
      ],
      supportsPageTour: true,
    ),
    const FeatureShowcaseItem(
      id: 'strategies',
      title: 'Strategy Playbooks',
      tagline:
          'Systematize entry/exit checklists, lifecycle stages & rule revisions.',
      category: FeatureShowcaseCategory.workspace,
      previewKind: FeaturePreviewKind.strategies,
      destinationId: 'strategies',
      icon: Icons.architecture_outlined,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'Free (1 Live) · Basic (3 Live) · Pro (250 Live)',
      summary:
          'Codify repeatable setups across Draft, Backtesting, Live, and Archived stages with risk rules, versioned revisions, and linked execution stats.',
      detailedParagraphs: <String>[
        'Discretionary mistakes shrink dramatically when every setup lives inside a concrete Playbook. Define exact market-regime filters, entry triggers, stop-loss placement logic, scaling rules, and invalidation warnings across 8 institutional templates.',
        'Promote each Playbook through explicit lifecycle stages—Draft, Backtesting, Live, or Archived—while preserving full revision history so you always know how your rules evolved over time.',
        'Because Journal trades attach directly to Playbooks, AlphaJournal measures empirical win rate, average R-multiple, and max drawdown per strategy—and lets AI Playbook Reviewer detect rule drift.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Included in Free Plan',
          value: '1 live playbook',
        ),
        FeatureSpecRow(
          label: 'Basic Plan (₹299/mo)',
          value: '3 live playbooks',
        ),
        FeatureSpecRow(
          label: 'Pro Plan (₹499/mo)',
          value: '250 live playbooks',
        ),
        FeatureSpecRow(
          label: 'Lifecycle Stages',
          value: 'Draft · Backtesting · Live · Archived',
        ),
        FeatureSpecRow(
          label: 'Audit Trail',
          value: 'Revision History + Linked Trade Telemetry',
        ),
      ],
      helperTips: <String>[
        'Keep experimental setups in Draft or Backtesting before sizing live',
        'Log a revision entry whenever you widen stops or tweak timeframes',
        'Use AI Reviewer to compare actual Journal trades against Playbook rules',
      ],
      highlights: <String>[
        '8 battle-tested templates (ORB, VWAP Pullback, Momentum, Options Income)',
        'Versioned rule revisions correlated with live trade expectancy',
        'Full PDF/link sharing for team reviews or mentor feedback',
      ],
      reviewNote:
          'Essential for separating validated statistical edge from impulse trades. Only promote a strategy to Live after validating positive expectancy across sample trades.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Define setup triggers, invalidation & position sizing rules',
          detail:
              'Start from an ORB, VWAP Pullback, Momentum, or Options Income playbook.',
        ),
        FeatureShowcaseStep(
          title: 'Tag lifecycle stage & track rule revisions',
          detail:
              'Move between Backtesting and Live with dated rule changelog notes.',
        ),
        FeatureShowcaseStep(
          title: 'Audit linked Journal executions',
          detail:
              'Compare realized win rate and R-multiple against target expectancy.',
        ),
      ],
      searchKeywords: <String>[
        'playbook',
        'rules',
        'setup',
        'backtest',
        'edge',
      ],
      supportsPageTour: true,
    ),
    const FeatureShowcaseItem(
      id: 'calculators',
      title: '22 Risk, Options & Tax Calculators',
      tagline:
          'Position size, Black-Scholes Greeks, Brokerage, LTCG & 44AB Audit.',
      category: FeatureShowcaseCategory.markets,
      previewKind: FeaturePreviewKind.calculators,
      destinationId: 'calculators',
      icon: Icons.calculate_outlined,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'Core Free · Advanced Basic / Pro',
      summary:
          'Interactive suite of 22 deterministic calculators covering Trading Risk (7), Options Greeks & IV (3), Investing (7), Currency (2), and Indian Tax/Turnover (3).',
      detailedParagraphs: <String>[
        'Never guess lot sizes or breakeven slippage mid-session. All 22 financial, derivatives, and tax calculators run deterministically right inside your workspace with interactive sliders, scenario comparison tables, and clear mathematical breakdowns.',
        'Trading & Options modules cover Position Size, Risk/Reward, Kelly Criterion, Margin Leverage, Black-Scholes Fair Value + Delta/Gamma/Theta/Vega Greeks, and multi-leg Options P&L curves.',
        'India-specific Brokerage & Tax modules compute NSE/BSE STT, Stamp Duty, SEBI fees, GST, LTCG/STCG liability, and Section 44AB F&O speculative/non-speculative audit turnover automatically.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Plan Access',
          value: 'Core: Free · Advanced: Basic / Pro',
        ),
        FeatureSpecRow(
          label: 'Trading Risk Suite',
          value: '7 Calculators (Position Size, Kelly, R:R...)',
        ),
        FeatureSpecRow(
          label: 'Options & Greeks',
          value: '3 Calculators (Black-Scholes, IV, Payoff)',
        ),
        FeatureSpecRow(
          label: 'Investing & SIP',
          value: '7 Calculators (CAGR, XIRR, SIP, EMI...)',
        ),
        FeatureSpecRow(
          label: 'Currency & Tax',
          value: '5 Calculators (FX, Brokerage, LTCG, STCG, 44AB)',
        ),
        FeatureSpecRow(
          label: 'Execution Handoff',
          value: 'One-Click "Draft to Journal" Pre-fill',
        ),
      ],
      helperTips: <String>[
        'Cap risk per trade at 0.5%–1.0% via Position Size before placing orders',
        'Check Brokerage breakeven points when scalping tight intraday targets',
        'Run Section 44AB turnover estimation quarterly before advance tax dates',
      ],
      highlights: <String>[
        'Zero-latency offline calculation with instant preset sliders',
        'Indian equity & F&O charges (STT, Stamp, Exchange Txn, SEBI, GST)',
        'Send sized setups directly into a pre-filled Trade Journal draft',
      ],
      reviewNote:
          'Core tools remain available on Free. Basic and Pro unlock the advanced trading, options, forex, and tax set. Calculations run locally and are ideal pre-trade sanity checks.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Select Trading, Options, Investing, Currency, or Tax',
          detail:
              'Pick any of the 22 calculators using quick category pills or search.',
        ),
        FeatureShowcaseStep(
          title: 'Tune capital, entry, stop-loss, IV, or tax inputs',
          detail:
              'Inspect exact share quantity, margin utilization %, and net breakeven.',
        ),
        FeatureShowcaseStep(
          title: 'Click "Draft to Journal" to log the sized setup',
          detail:
              'Pre-populates ticker levels and calculated position size in Journal.',
        ),
      ],
      searchKeywords: <String>[
        'position size',
        'greeks',
        'black scholes',
        'ltcg',
        'brokerage',
        'kelly',
      ],
    ),
    const FeatureShowcaseItem(
      id: 'market',
      title: 'Live Markets, News & Screeners',
      tagline:
          'Real-time index breadth, movers, sector screeners & shareable tickers.',
      category: FeatureShowcaseCategory.markets,
      previewKind: FeaturePreviewKind.market,
      destinationId: 'market',
      icon: Icons.candlestick_chart_outlined,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'Basic / Pro · Free Community Preview',
      summary:
          'Monitor global & Indian indices, top gainers/losers, fundamental screeners, curated financial news, and shareable `/market/:symbol` dossiers.',
      detailedParagraphs: <String>[
        'Live Markets brings together real-time index ribbons, advance/decline breadth, volume movers, curated financial news topics, and multi-factor fundamental screeners—all without switching out to separate terminals.',
        'Click any stock, ETF, or index to open its dedicated Market Instrument Dossier featuring live quote telemetry, valuation multiples (P/E, PEG, EPS, 52W range), institutional holders, options snapshot, and company-specific news.',
        'Every instrument has a canonical URL (`https://app.alphajournal.in/market/<SYMBOL>`) complete with dynamic Open Graph metadata, ready to share via WhatsApp, X, Telegram, LinkedIn, or Encrypted DM.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Plan Access',
          value: 'Full: Basic / Pro · Limited Community preview: Free',
        ),
        FeatureSpecRow(
          label: 'Market Views',
          value:
              '6 Tabs (Overview, News, Movers, Instruments, Screeners, Coverage)',
        ),
        FeatureSpecRow(
          label: 'Canonical Deep Link',
          value: 'app.alphajournal.in/market/<SYMBOL>',
        ),
        FeatureSpecRow(
          label: 'Quote Pipeline',
          value: 'Authenticated Edge Proxy (No Key Exposure)',
        ),
        FeatureSpecRow(
          label: 'Search Indexing',
          value: 'Dynamic Title & OG Cards per Symbol',
        ),
      ],
      helperTips: <String>[
        'Use the top-right Share icon inside any instrument view to send its live URL',
        'Click article cashtags to jump straight into that ticker’s fundamentals',
        'Pair Screener shortlists with Notes or AI Copilot for fast due diligence',
      ],
      highlights: <String>[
        'Live index pulse with sparklines and top gainer/loser rankings',
        'Deep instrument dossiers with financials, holders, and news feeds',
        'Topic filters and saved bookmark/like state for market news articles',
      ],
      reviewNote:
          'Powered by an authenticated edge proxy (`market-quote-proxy`) with clean subdomain routing so vendor credentials never touch browser clients.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Review Overview breadth & Movers momentum',
          detail: 'Spot leading sectors and unusual volume across indices.',
        ),
        FeatureShowcaseStep(
          title: 'Open an Instrument Dossier by tapping any ticker',
          detail:
              'Inspect valuation metrics, institutional ownership, and latest headlines.',
        ),
        FeatureShowcaseStep(
          title: 'Share ticker link via app.alphajournal.in/market/SYMBOL',
          detail:
              'Tap the Share button to send into Messages, WhatsApp, X, or Telegram.',
        ),
      ],
      searchKeywords: <String>[
        'stocks',
        'quotes',
        'screener',
        'movers',
        'news',
        'nifty',
        'ticker',
      ],
    ),
    const FeatureShowcaseItem(
      id: 'community',
      title: 'Trader Community & Public Profiles',
      tagline:
          'Trade setups, polls, nested threads & SEO-indexed @handle profiles.',
      category: FeatureShowcaseCategory.social,
      previewKind: FeaturePreviewKind.community,
      destinationId: 'community_feed',
      icon: Icons.public_rounded,
      subdomain: CustomerSubdomain.community,
      tierBadge: 'community.alphajournal.in · Public OG',
      summary:
          'Dedicated community host for publishing trade setups (Long/Short entry/target/stop), polls, reactions, nested comments, snapshots, and verified `@handle` profiles.',
      detailedParagraphs: <String>[
        'Trader Community operates on its own canonical host (`community.alphajournal.in`) so public trade setups, macro threads, and verified trader `@handle` profiles are cleanly discoverable and crawlable while keeping your private Workspace completely isolated.',
        'Publish rich setups featuring directional badges (`LONG` / `SHORT`), Entry/Target/Stop/R-multiple tiles, cashtags (`\$NIFTY50`), interactive multi-option polls, chart attachments, emoji reactions, nested replies, Reposts, and Quote Posts.',
        'Every post and profile generates rich dynamic Open Graph link previews at Cloudflare Edge (`@handle`, post excerpts, attached setup images) and can be exported as branded PNG snapshot cards.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Canonical Host',
          value: 'community.alphajournal.in',
        ),
        FeatureSpecRow(
          label: 'Daily Post Limits',
          value: 'Free: 2/day · Basic: 15/day · Pro: 100/day',
        ),
        FeatureSpecRow(
          label: 'Daily Comment Limits',
          value: 'Free: 10/day · Basic: 50/day · Pro: 500/day',
        ),
        FeatureSpecRow(
          label: 'Social Share Channels',
          value: 'WhatsApp · X · Telegram · LinkedIn · PNG Card',
        ),
        FeatureSpecRow(
          label: 'Cross-Workflow Hooks',
          value: 'Clip to Notes · Analyze with AI Copilot',
        ),
      ],
      helperTips: <String>[
        'Click "Clip to Notes" in any post’s Share menu to save setups locally',
        'Use Export Post Snapshot to download a clean 16:9 PNG setup card',
        'Customize public stats visibility in Settings -> Privacy',
      ],
      highlights: <String>[
        'Dedicated public community host with dynamic SSR/Worker OG previews',
        'Branded PNG setup snapshots & full cross-channel external share menu',
        'Quote, Repost, Bookmark, Nested Comments, and Reaction filters',
      ],
      reviewNote:
          'Sign-in sessions stay synchronized seamlessly between `app.alphajournal.in` and `community.alphajournal.in` via cross-subdomain session persistence—zero re-login prompts.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Publish a trade commentary, chart, setup tile, or poll',
          detail:
              'Include Entry, Target, Stop, R-multiple, and \$TICKER cashtags.',
        ),
        FeatureShowcaseStep(
          title: 'React, reply, bookmark, or quote-post on feed',
          detail:
              'Engage with verified setups or save valuable insights to Trader Notes.',
        ),
        FeatureShowcaseStep(
          title: 'Open Share Sheet for community.alphajournal.in links',
          detail:
              'Copy canonical URL, export PNG card, or share directly on X/WhatsApp.',
        ),
      ],
      searchKeywords: <String>[
        'feed',
        'posts',
        'poll',
        'profile',
        'setup',
        'social',
        'handle',
      ],
    ),
    const FeatureShowcaseItem(
      id: 'messages',
      title: 'End-to-End Encrypted Messaging',
      tagline:
          'Zero-knowledge X25519 + AES-256-GCM trader DMs & record sharing.',
      category: FeatureShowcaseCategory.social,
      previewKind: FeaturePreviewKind.messages,
      destinationId: 'messages',
      icon: Icons.lock_outline_rounded,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'E2EE · Basic / Pro',
      summary:
          'Private 1:1 and group trader chats encrypted client-side using X25519 ECDH key exchange, AES-256-GCM payloads, HMAC-SHA256 signatures, and 16-char recovery keys.',
      detailedParagraphs: <String>[
        'Trading theses and position sizing are sensitive. Before any message, voice note, or image leaves your browser or phone, AlphaJournal encrypts it using WebCrypto/native X25519 ECDH shared keys, AES-256-GCM authenticated encryption, and per-message HMAC-SHA256 verification.',
        'Even database administrators and API servers only ever observe ciphertext envelopes—only participating devices holding the matching identity private key can unwrap the thread.',
        'Inside chats, share live clickable cards referencing your Trade Journal entries, Notes, Strategy Playbooks, Market tickers, or Community posts, alongside typing indicators and message forwarding.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Key Exchange',
          value: 'X25519 Elliptic-Curve Diffie-Hellman',
        ),
        FeatureSpecRow(
          label: 'Cipher & Integrity',
          value: 'AES-256-GCM + HMAC-SHA256',
        ),
        FeatureSpecRow(
          label: 'Key Backup',
          value: '16-Character Recovery Passphrase',
        ),
        FeatureSpecRow(
          label: 'Plan Access',
          value: 'Basic / Pro only; Free receives an upgrade notice',
        ),
      ],
      helperTips: <String>[
        'Back up your 16-char recovery key in Settings -> Security right after setup',
        'Enter your recovery key on a new browser so older threads decrypt cleanly',
        'Long-press or click "..." on any chat message to Forward or Analyze with AI',
      ],
      highlights: <String>[
        'Zero-knowledge client encryption with per-device identity verification',
        'Interactive Journal, Note, Strategy & Ticker cards inside private threads',
        'Voice notes, file attachments, read receipts & forwarding overlay',
      ],
      reviewNote:
          'Always store your 16-character E2EE recovery passphrase safely when using multiple browsers or devices so message HMAC signatures match cleanly across sessions.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Generate identity keys & back up 16-char recovery code',
          detail:
              'Ensures you can unlock encrypted chats if you clear storage or change devices.',
        ),
        FeatureShowcaseStep(
          title: 'Start a direct thread with any trader handle',
          detail:
              'Send encrypted text, chart screenshots, or quick voice memos.',
        ),
        FeatureShowcaseStep(
          title: 'Share linked Journal or Strategy cards inline',
          detail:
              'Use Share -> Send via AlphaJournal Messages from any record.',
        ),
      ],
      searchKeywords: <String>[
        'dm',
        'chat',
        'encrypted',
        'e2ee',
        'x25519',
        'recovery',
      ],
    ),
    const FeatureShowcaseItem(
      id: 'ai_copilot',
      title: 'AI Copilot, Live Search & Voice',
      tagline:
          'Real-time web_search, 11 /trader-* workflows, Voice Calls & memory.',
      category: FeatureShowcaseCategory.ai,
      previewKind: FeaturePreviewKind.aiCopilot,
      destinationId: 'ai_copilot',
      icon: Icons.auto_awesome_rounded,
      subdomain: CustomerSubdomain.app,
      tierBadge: '5 Free · 20 Basic · 5,000 Pro / mo',
      summary:
          'Conversational trading analyst featuring Auto / Live Search / Deep Research modes, authenticated AI Voice Calls, 11 `/trader-*` skills, tool approvals, and schedules.',
      detailedParagraphs: <String>[
        'AI Copilot operates as your quantitative research assistant directly inside `app.alphajournal.in`. Switch dynamically between **Auto** (fast synthesis), **Web Search** (real-time OpenAI `web_search` citations for breaking news & macro prints), and **Deep Research** (multi-step structured reasoning).',
        'Type `/` in the composer to invoke 11 specialized trading workflows—including `/trader-analyst`, `/trader-risk`, `/trader-debrief`, `/trader-macro`, and `/trader-playbook`—all routed securely through Supabase Edge proxies with zero client-side secret exposure.',
        'Start an authenticated **AI Voice Call** for hands-free conversational briefings using browser/mic speech recognition plus natural OpenAI TTS audio playback, or pin Copilot Notes & scheduled morning digests.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Included in Free Plan',
          value: '5 AI prompts / mo',
        ),
        FeatureSpecRow(
          label: 'Basic Plan (₹299/mo)',
          value: '20 AI prompts / mo',
        ),
        FeatureSpecRow(
          label: 'Pro Plan (₹499/mo)',
          value: '5,000 AI prompts / mo',
        ),
        FeatureSpecRow(
          label: 'Specialized Skills',
          value: '11 /trader-* Slash Commands',
        ),
        FeatureSpecRow(
          label: 'Voice & Search',
          value: 'Authenticated TTS/STT Proxy + Live web_search',
        ),
      ],
      helperTips: <String>[
        'Type "/" in Copilot composer to browse all 11 /trader-* structured skills',
        'Switch to Search mode before market open for cited macro & earnings catalysts',
        'Use "Analyze with AI Copilot" directly from Journal trades or Community posts',
      ],
      highlights: <String>[
        'Live web citations during chat and voice conversations',
        'Structured human-in-the-loop tool approvals before modifying workspace records',
        'Persistent Copilot Pages, Memory, Specialists, and Automated Schedules',
      ],
      reviewNote:
          'Runs through authenticated `ai-proxy` and `ai-voice-proxy` Edge Functions so your OpenAI API keys stay protected server-side at all times.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Pick Auto, Web Search, or Research mode in Copilot',
          detail:
              'Select Search when asking about current earnings, RBI/Fed dates, or spot levels.',
        ),
        FeatureShowcaseStep(
          title: 'Invoke a /trader-* skill or start a Voice Call',
          detail:
              'Run structured trade debriefs or speak hands-free with voice synthesis.',
        ),
        FeatureShowcaseStep(
          title: 'Promote answers into Copilot Pages or Trader Notes',
          detail:
              'Save briefings permanently and link them to your workspace graph.',
        ),
      ],
      searchKeywords: <String>[
        'ai',
        'copilot',
        'voice',
        'search',
        'research',
        'skills',
        'tts',
      ],
    ),
    const FeatureShowcaseItem(
      id: 'notifications',
      title: 'Activity Inbox & Web Push Alerts',
      tagline:
          'Instant replies, mentions, security events & background VAPID push.',
      category: FeatureShowcaseCategory.social,
      previewKind: FeaturePreviewKind.notifications,
      destinationId: 'notifications',
      icon: Icons.notifications_none_rounded,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'Web Push + In-App Inbox',
      summary:
          'Real-time notification drawer & inbox uniting community replies, mentions, security key alerts, trade events, and encrypted browser Web Push notifications.',
      detailedParagraphs: <String>[
        'Stay responsive without constantly polling tabs. The Activity Inbox aggregates every comment reply, `@mention`, new follower, trade milestone, affiliate decision, and E2EE security event into one structured stream.',
        'Clicking any notification opens a cross-subdomain deep link that takes you straight to the exact post, trader profile, or workspace record.',
        'Enable VAPID Web Push inside Notification Settings so critical alerts arrive smoothly even when AlphaJournal is minimized or closed.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Delivery Channels',
          value: 'In-App Toast + Drawer + Web Push (VAPID)',
        ),
        FeatureSpecRow(
          label: 'Deep-Link Routing',
          value: 'Cross-Subdomain Aware (app / community / affiliate)',
        ),
        FeatureSpecRow(
          label: 'Granular Controls',
          value: 'Per-Category Mutes in Settings',
        ),
      ],
      helperTips: <String>[
        'Click the header bell icon anytime for the quick slide-over feed',
        'Authorize browser Web Push once in Settings -> Notifications for background pings',
        'Tapping security notifications jumps straight to E2EE key management',
      ],
      highlights: <String>[
        'Real-time unread counter synchronized via Supabase Realtime',
        'Privacy-preserving Web Push dispatch with server-held VAPID keys',
        'Direct jump-to-source links across posts, comments, profiles & records',
      ],
      reviewNote:
          'If Web Push permission was previously blocked in browser site settings, re-enable Notifications in your browser address bar lock menu.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Open the Bell icon in the header bar',
          detail:
              'Filter between unread mentions, replies, trade alerts, and security updates.',
        ),
        FeatureShowcaseStep(
          title: 'Enable Web Push in Notification Settings',
          detail: 'Subscribe the active device to encrypted background alerts.',
        ),
        FeatureShowcaseStep(
          title: 'Tap any alert to navigate cleanly to its source',
          detail:
              'Crosses smoothly to community.alphajournal.in or app.alphajournal.in.',
        ),
      ],
      searchKeywords: <String>['alerts', 'push', 'inbox', 'mentions', 'vapid'],
    ),
    FeatureShowcaseItem(
      id: 'affiliate',
      title: hasAffiliateAccess
          ? 'Affiliate Partner Console'
          : 'Affiliate Partner Program',
      tagline:
          'Custom /r/:slug links, 30-day attribution & INR UPI/bank payouts.',
      category: FeatureShowcaseCategory.growth,
      previewKind: FeaturePreviewKind.affiliate,
      destinationId: hasAffiliateAccess ? 'overview' : 'affiliate_application',
      icon: Icons.campaign_outlined,
      subdomain: CustomerSubdomain.affiliate,
      tierBadge: hasAffiliateAccess
          ? 'Partner Unlocked'
          : 'affiliate.alphajournal.in',
      summary:
          'Apply in 2 minutes or manage active campaigns on `affiliate.alphajournal.in`: custom `/r/:slug` referral links with 30-day cookie attribution, UTM campaigns, and INR payouts.',
      detailedParagraphs: <String>[
        'Educators, trading mentors, and financial creators can monetize high-intent referrals seamlessly via `affiliate.alphajournal.in`. Every partner receives a branded `alphajournal.in/r/:slug` link plus support for `?utm_campaign=...` tracking.',
        'When a visitor clicks your referral link, a 30-day cross-subdomain attribution cookie persists cleanly through signup and checkout (`alphajournal.in`, `app.`, and `community.`). Referred subscribers also receive a 20% lifetime partner perk.',
        'Track clicks, pending signups, 7-day refund-guard clearances, creative banners, and settle recurring INR commissions directly to verified Indian UPI VPAs or NEFT/IMPS bank accounts.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Partner Host',
          value: 'affiliate.alphajournal.in',
        ),
        FeatureSpecRow(
          label: 'Referral Link Format',
          value: 'https://alphajournal.in/r/<slug>',
        ),
        FeatureSpecRow(
          label: 'Attribution Window',
          value: '30-Day Cross-Subdomain Cookie',
        ),
        FeatureSpecRow(
          label: 'Referral Bonus',
          value: '20% Lifetime Subscriber Perk',
        ),
        FeatureSpecRow(
          label: 'Payout Rails',
          value: 'INR via UPI VPA & Bank IFSC',
        ),
      ],
      helperTips: const <String>[
        'Append ?utm_campaign=youtube or ?utm_campaign=telegram to compare sources',
        'Customize your clean partner slug inside Settings -> Affiliate',
        'Switch between Trader & Affiliate views anytime from the top role switcher',
      ],
      highlights: const <String>[
        'Instant referral attribution preserved across subdomains and signups',
        'Dedicated Overview, Referrals, Marketing Assets, and Payouts tabs',
        'Transparent 7-day clearance status per subscription conversion',
      ],
      reviewNote: hasAffiliateAccess
          ? 'Your Partner workspace is active. Use custom campaign slugs (?utm_campaign=...) to track YouTube, Telegram, and X conversion rates independently.'
          : 'Any customer can submit an Affiliate Application right inside the app and continue using their trading workspace while under Admin review.',
      demoSteps: const <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Submit partner application or open Partner Overview',
          detail:
              'Verify your creator channel, niche, and INR UPI or Bank payout details.',
        ),
        FeatureShowcaseStep(
          title: 'Copy your canonical alphajournal.in/r/:slug link',
          detail:
              'Share across WhatsApp, X, Telegram, LinkedIn, or video descriptions.',
        ),
        FeatureShowcaseStep(
          title: 'Monitor clicks, conversions & INR payout batches',
          detail:
              'Inspect active referrals, clearance timers, and completed payouts.',
        ),
      ],
      searchKeywords: const <String>[
        'referral',
        'partner',
        'commission',
        'inr',
        'payout',
        'utm',
      ],
      requiresAffiliateAccess: hasAffiliateAccess,
    ),
    const FeatureShowcaseItem(
      id: 'settings',
      title: 'Security, Billing & Workspace Tiers',
      tagline:
          'Cross-subdomain SSO, E2EE backup, themes, privacy & INR billing.',
      category: FeatureShowcaseCategory.growth,
      previewKind: FeaturePreviewKind.settings,
      destinationId: 'settings',
      icon: Icons.tune_rounded,
      subdomain: CustomerSubdomain.app,
      tierBadge: 'Free (₹0) · Basic (₹299) · Pro (₹499)',
      summary:
          'Manage profile visibility, dark/light themes, density, E2EE recovery passphrases, blocked traders, data compliance, and plan billing.',
      detailedParagraphs: <String>[
        'Settings centralizes your identity, visual preferences, security posture, and subscription entitlements. Signing in once writes secure cross-subdomain cookies scoped to `.alphajournal.in`, keeping your session continuous across `app.`, `community.`, `affiliate.`, and `admin.`.',
        'Upgrade between **Free (₹0/mo)**, **Basic (₹299/mo)**, and **Pro (₹499/mo)** cleanly to scale monthly Journal entries, Trading Notes, Playbooks, E2EE DM volume, and AI Copilot prompts immediately in the same frame.',
        'Privacy & Security panes let you audit consent preferences, block/unblock handles, rotate or verify E2EE recovery passphrases, and initiate compliant account deletion.',
      ],
      specs: <FeatureSpecRow>[
        FeatureSpecRow(
          label: 'Free Plan',
          value: '₹0 / mo · 3 Notes · 15 Trades · 5 AI Prompts',
        ),
        FeatureSpecRow(
          label: 'Basic Plan',
          value: '₹299 / mo · 25 Notes · 100 Trades · 20 AI Prompts',
        ),
        FeatureSpecRow(
          label: 'Pro Plan',
          value: '₹499 / mo · 10K Notes · 50K Trades · 5K AI + PDF',
        ),
        FeatureSpecRow(
          label: 'Session Scope',
          value: 'Single Sign-On across *.alphajournal.in',
        ),
      ],
      helperTips: <String>[
        'Save your 16-char E2EE recovery key inside Security before switching browsers',
        'Toggle Public Statistics & Journal Visibility inside Profile Settings',
        'Switch Comfort vs Compact UI density in Appearance Settings',
      ],
      highlights: <String>[
        'Single sign-on session persistence across every AlphaJournal subdomain',
        'Instant tier entitlement updates across Workspace, DMs & AI Copilot',
        'Granular profile visibility, privacy consent & account export controls',
      ],
      reviewNote:
          'Changes to subscription tier or E2EE keys sync immediately into `AppSession`, unlocking upgraded quotas without signing out.',
      demoSteps: <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Configure @handle, bio & public visibility toggles',
          detail:
              'Control what fellow traders see on community.alphajournal.in/@yourhandle.',
        ),
        FeatureShowcaseStep(
          title: 'Back up your E2EE recovery passphrase in Security',
          detail:
              'Protect encrypted DM history across browser clears and mobile devices.',
        ),
        FeatureShowcaseStep(
          title: 'Compare Free, Basic & Pro tiers in Billing',
          detail: 'Switch plans or inspect invoices anytime.',
        ),
      ],
      searchKeywords: <String>[
        'billing',
        'pro',
        'basic',
        'security',
        'theme',
        'privacy',
        'password',
      ],
    ),
    FeatureShowcaseItem(
      id: 'admin',
      title: 'Institutional Admin Console',
      tagline:
          'Affiliate approvals, moderation queues, seats & audit compliance.',
      category: FeatureShowcaseCategory.growth,
      previewKind: FeaturePreviewKind.admin,
      destinationId: 'overview',
      icon: Icons.admin_panel_settings_outlined,
      subdomain: CustomerSubdomain.admin,
      tierBadge: hasAdminAccess ? 'Admin Authorized' : 'Admin Role Only',
      summary:
          'Dedicated `admin.alphajournal.in` operations suite for approving affiliate applications, moderating platform records, auditing deletions, and managing seats.',
      detailedParagraphs: const <String>[
        'Admin operations are isolated on `admin.alphajournal.in` with strict Cloudflare Worker `X-Robots-Tag: noindex, nofollow` and `robots.txt Disallow: /` protection plus server-verified role enforcement.',
        'Authorized admins can approve or reject incoming Affiliate applications, inspect reported community comments/posts, review shared notes/journals/strategies, monitor subscription telemetry, and oversee audit logs.',
        'Non-admin users attempting to open Admin URLs are gracefully redirected back to their standard workspace without exposing administrative data.',
      ],
      specs: const <FeatureSpecRow>[
        FeatureSpecRow(label: 'Admin Host', value: 'admin.alphajournal.in'),
        FeatureSpecRow(
          label: 'Crawler Policy',
          value: 'Strict noindex, nofollow + Disallow: /',
        ),
        FeatureSpecRow(
          label: 'Moderation Surfaces',
          value: 'Comments · Journals · Notes · Strategies · AI',
        ),
        FeatureSpecRow(
          label: 'Access Requirement',
          value: 'Verified user_admin Server Role',
        ),
      ],
      helperTips: const <String>[
        'Use top-bar role switcher to jump between Trader and Admin views cleanly',
        'Review Affiliate Approvals & Payouts from dedicated left-rail tabs',
        'Audit Deletion requests retain traceable timestamps for compliance',
      ],
      highlights: const <String>[
        'Edge-isolated subdomain with strict search-engine exclusion',
        'End-to-end Affiliate onboarding, review, and INR payout governance',
        'Centralized content moderation, platform settings & analytics',
      ],
      reviewNote: hasAdminAccess
          ? 'You hold Admin clearance. Switch to the Admin Console to review pending affiliate applications, moderation items, and platform telemetry.'
          : 'Locked to standard accounts. Only verified `user_admin` accounts can unlock `admin.alphajournal.in`.',
      demoSteps: const <FeatureShowcaseStep>[
        FeatureShowcaseStep(
          title: 'Authenticate with verified user_admin credentials',
          detail: 'Enforced both in Edge routing and Supabase RLS policies.',
        ),
        FeatureShowcaseStep(
          title: 'Process pending Affiliate Applications & Moderation queues',
          detail:
              'Approve qualified creator partners and audit community flags.',
        ),
        FeatureShowcaseStep(
          title: 'Inspect platform subscriptions, deletions & analytics',
          detail:
              'Adjust system tier limits and monitor overall workspace health.',
        ),
      ],
      searchKeywords: const <String>[
        'admin',
        'moderation',
        'approvals',
        'seats',
        'audit',
        'governance',
      ],
      requiresAdminAccess: true,
    ),
  ];
}
