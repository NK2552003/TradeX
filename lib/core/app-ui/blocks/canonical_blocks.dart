import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/domain_cards.dart';

/// 86. DashboardBlocks — Executive portfolio dashboard block with summary cards and active position feeds.
class DashboardBlocks extends StatelessWidget {
  const DashboardBlocks({
    super.key,
    this.onDeposit,
    this.onWithdraw,
    this.onClosePosition,
    this.onSelectSymbol,
  });

  final VoidCallback? onDeposit;
  final VoidCallback? onWithdraw;
  final VoidCallback? onClosePosition;
  final ValueChanged<String>? onSelectSymbol;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PortfolioSummaryCard(
          onDeposit: onDeposit,
          onWithdraw: onWithdraw,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCardGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          largeColumns: 2,
          children: <Widget>[
            const AssetAllocationCard(),
            const PerformanceCard(),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        PositionCard(
          onClose: onClosePosition,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        WatchlistCard(
          onSelectSymbol: onSelectSymbol,
        ),
      ],
    );
  }
}

/// 87. JournalBlocks — Trading journal screen block with calendar heatmap, entry filters, and execution stats.
class JournalBlocks extends StatefulWidget {
  const JournalBlocks({
    super.key,
    this.onFilterChanged,
    this.onNewEntry,
  });

  final ValueChanged<String>? onFilterChanged;
  final VoidCallback? onNewEntry;

  @override
  State<JournalBlocks> createState() => _JournalBlocksState();
}

class _JournalBlocksState extends State<JournalBlocks> {
  String _searchQuery = '';
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.sp(theme.spacing.md),
          runSpacing: context.sp(theme.spacing.sm),
          children: <Widget>[
            SizedBox(
              width: context.uiRes.isMobile ? double.infinity : context.sz(320),
              child: UiInput.search(
                value: _searchQuery,
                hintText: 'Search journal entries, tickers, setups...',
                onChanged: (String val) {
                  setState(() => _searchQuery = val);
                  widget.onFilterChanged?.call(val);
                },
                onClear: () {
                  setState(() => _searchQuery = '');
                  widget.onFilterChanged?.call('');
                },
              ),
            ),
            if (widget.onNewEntry != null)
              UiButton(
                label: 'New Entry',
                icon: Icons.add,
                variant: UiVariant.solid,
                intent: UiIntent.primary,
                onPressed: widget.onNewEntry,
              ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTabs(
          tabs: const <String>['All Trades', 'Winning Trades', 'Losses', 'Reviews'],
          selectedIndex: _selectedTab,
          onChanged: (int idx) => setState(() => _selectedTab = idx),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        const JournalEntryCard(
          ticker: 'NVDA',
          strategy: 'Earnings Momentum',
          date: 'Yesterday, 15:30',
          notes: 'High volume pre-market breakout above pivot. Position exited at 2R target.',
          pnl: 1450.0,
          tags: ['breakout', 'tech', 'momentum'],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        const JournalEntryCard(
          ticker: 'TSLA',
          strategy: 'Mean Reversion',
          date: 'Sep 6, 2026',
          notes: 'Oversold RSI condition triggered entry near key support zone.',
          pnl: 620.0,
          tags: ['support', 'ev', 'reversion'],
        ),
      ],
    );
  }
}

/// 88. MarketBlocks — Live market scanner block with order book, market depth, and top gainers/losers.
class MarketBlocks extends StatelessWidget {
  const MarketBlocks({
    super.key,
    this.tickerText = 'LIVE: NVDA +4.2% | AAPL +1.1% | BTC \$67,420 | ETH \$3,510 | TSLA +5.1%',
    this.onSelectGainer,
  });

  final String tickerText;
  final ValueChanged<String>? onSelectGainer;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(theme.spacing.xs),
            horizontal: context.sp(theme.spacing.sm),
          ),
          decoration: BoxDecoration(
            color: theme.colors.surfaceMuted,
            borderRadius: context.radius(theme.radii.sm),
          ),
          child: UiMarquee(text: tickerText),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        const MarketOverviewCard(),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          title: 'Top Gainers & Relative Volume',
          child: UiBarList(
            items: <UiBarListItem>[
              UiBarListItem(
                label: 'NVDA (+4.2%)',
                value: 94.5,
                percentage: 0.94,
                onTap: onSelectGainer != null ? () => onSelectGainer!('NVDA') : null,
              ),
              UiBarListItem(
                label: 'TSLA (+5.1%)',
                value: 82.0,
                percentage: 0.82,
                onTap: onSelectGainer != null ? () => onSelectGainer!('TSLA') : null,
              ),
              UiBarListItem(
                label: 'AMD (+3.1%)',
                value: 65.4,
                percentage: 0.65,
                onTap: onSelectGainer != null ? () => onSelectGainer!('AMD') : null,
              ),
              UiBarListItem(
                label: 'MSFT (+1.8%)',
                value: 48.2,
                percentage: 0.48,
                onTap: onSelectGainer != null ? () => onSelectGainer!('MSFT') : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 89. ChartBlocks — Technical analysis workspace block combining candlestick charts, indicator controls, and order entry panel.
class ChartBlocks extends StatefulWidget {
  const ChartBlocks({
    super.key,
    this.symbol = 'BTC/USDT',
    this.currentPrice = '\$67,820.50',
    this.onTimeframeChanged,
  });

  final String symbol;
  final String currentPrice;
  final ValueChanged<String>? onTimeframeChanged;

  @override
  State<ChartBlocks> createState() => _ChartBlocksState();
}

class _ChartBlocksState extends State<ChartBlocks> {
  String _timeframe = '1D';

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCard(
          title: '${widget.symbol} — ${widget.currentPrice}',
          action: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: UiToggleGroup<String>(
              value: _timeframe,
              options: const <UiOption<String>>[
                UiOption(label: '1H', value: '1H'),
                UiOption(label: '4H', value: '4H'),
                UiOption(label: '1D', value: '1D'),
                UiOption(label: '1W', value: '1W'),
              ],
              size: UiSize.sm,
              onChanged: (String v) {
                setState(() => _timeframe = v);
                widget.onTimeframeChanged?.call(v);
              },
            ),
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: context.sz(240),
                child: UiAreaChart(
                  series: <UiChartSeries>[
                    UiChartSeries(
                      name: widget.symbol,
                      color: theme.colors.primary,
                      lineGlow: true,
                    ),
                  ],
                  data: const <UiChartPoint>[
                    UiChartPoint(label: '09:00', values: [64200]),
                    UiChartPoint(label: '11:00', values: [65100]),
                    UiChartPoint(label: '13:00', values: [64800]),
                    UiChartPoint(label: '15:00', values: [66900]),
                    UiChartPoint(label: '17:00', values: [67820]),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Wrap(
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.xs),
                children: const <Widget>[
                  UiBadge(label: 'RSI: 64.2 (Bullish)', intent: UiIntent.success, variant: UiBadgeVariant.soft),
                  UiBadge(label: 'EMA 20/50: Golden Cross', intent: UiIntent.primary, variant: UiBadgeVariant.soft),
                  UiBadge(label: 'Volume: +24% vs Avg', intent: UiIntent.neutral, variant: UiBadgeVariant.outline),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 90. AccountBlocks — Account settings block with security configuration, API keys, and notification toggles.
class AccountBlocks extends StatefulWidget {
  const AccountBlocks({super.key});

  @override
  State<AccountBlocks> createState() => _AccountBlocksState();
}

class _AccountBlocksState extends State<AccountBlocks> {
  bool _twoFactor = true;
  bool _emailAlerts = true;
  bool _tradePush = true;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AccountCard(),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          title: 'Security & Verification',
          child: Column(
            children: <Widget>[
              UiSwitch(
                label: 'Two-Factor Authentication (2FA)',
                value: _twoFactor,
                onChanged: (bool v) => setState(() => _twoFactor = v),
              ),
              const UiDivider(),
              UiSwitch(
                label: 'Instant Trade Execution Push Notifications',
                value: _tradePush,
                onChanged: (bool v) => setState(() => _tradePush = v),
              ),
              const UiDivider(),
              UiSwitch(
                label: 'Daily Margin & PnL Email Summary',
                value: _emailAlerts,
                onChanged: (bool v) => setState(() => _emailAlerts = v),
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          title: 'Broker API Integrations',
          subtitle: 'Active Read/Execute API Keys for Automated Strategy Routing',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Binance Futures API (Active)',
                      style: context.uiText.bodyStrong,
                    ),
                  ),
                  const UiBadge(label: 'CONNECTED', intent: UiIntent.success, size: UiSize.xs),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                'Key ID: ************89F2',
                style: context.uiText.caption.copyWith(color: theme.colors.foregroundSubtle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 91. CommunityBlocks — Social trading feed block with trader leaderboards and strategy sharing.
class CommunityBlocks extends StatelessWidget {
  const CommunityBlocks({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCard(
          title: 'Trader Leaderboard (Top 30D Returns)',
          child: UiBarList(
            items: const <UiBarListItem>[
              UiBarListItem(label: '1. @MarcusQuant (+84.2%)', value: 84.2, percentage: 0.84),
              UiBarListItem(label: '2. @ElenaTrades (+67.1%)', value: 67.1, percentage: 0.67),
              UiBarListItem(label: '3. @SigmaVol (+52.8%)', value: 52.8, percentage: 0.52),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        const CommunityPostCard(
          authorName: 'Marcus Vance',
          authorTier: 'MASTER TRADER',
          timeAgo: '45m ago',
          content: 'Just closed 50% of the long position on NVDA. Taking risk off ahead of FOMC. Retaining trailing stop on remaining contracts.',
          likes: 58,
          comments: 14,
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        const CommunityPostCard(
          authorName: 'Sarah Jenkins',
          authorTier: 'PRO',
          timeAgo: '3h ago',
          content: 'Bitcoin holding strong at \$67K pivot zone. Key resistance remains at \$68,500. Eyeing momentum breakout.',
          likes: 31,
          comments: 8,
        ),
      ],
    );
  }
}

/// 92. SearchBlocks — Universal search modal block with instant symbol lookup and command palette.
class SearchBlocks extends StatefulWidget {
  const SearchBlocks({
    super.key,
    this.onSelectSymbol,
    this.onSelectAction,
  });

  final ValueChanged<String>? onSelectSymbol;
  final ValueChanged<String>? onSelectAction;

  @override
  State<SearchBlocks> createState() => _SearchBlocksState();
}

class _SearchBlocksState extends State<SearchBlocks> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiInput.search(
            value: _query,
            hintText: 'Search symbols, strategies, trades, or commands...',
            onChanged: (String val) => setState(() => _query = val),
            onClear: () => setState(() => _query = ''),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(
            'POPULAR SYMBOLS',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final String s in <String>['NVDA', 'BTC/USDT', 'AAPL', 'TSLA', 'ETH/USDT'])
                UiButton(
                  label: s,
                  size: UiSize.xs,
                  variant: UiVariant.soft,
                  onPressed: () => widget.onSelectSymbol?.call(s),
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(
            'QUICK ACTIONS',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          _quickAction(
            context,
            icon: Icons.add_chart,
            label: 'New Trade Journal Entry',
            onTap: () => widget.onSelectAction?.call('new_journal_entry'),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          _quickAction(
            context,
            icon: Icons.analytics_outlined,
            label: 'Run Quantitative Backtest',
            onTap: () => widget.onSelectAction?.call('run_backtest'),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = context.ui;
    return UiInteractive(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.md),
      builder: (BuildContext ctx, UiInteractiveState s) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(theme.spacing.sm),
          vertical: ctx.sp(theme.spacing.sm),
        ),
        decoration: BoxDecoration(
          color: s.hovered ? theme.colors.surfaceHover : Colors.transparent,
          borderRadius: ctx.radius(theme.radii.md),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: ctx.sz(theme.sizes.iconSm),
              color: theme.colors.primary,
            ),
            SizedBox(width: ctx.sp(theme.spacing.sm)),
            Expanded(
              child: Text(
                label,
                style: ctx.uiText.bodyStrong,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: ctx.sz(theme.sizes.iconSm),
              color: theme.colors.foregroundSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

/// 93. AiBlocks — AI trading assistant block with conversational interface and pattern detection.
class AiBlocks extends StatelessWidget {
  const AiBlocks({
    super.key,
    this.onApplySignal,
  });

  final VoidCallback? onApplySignal;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AiInsightCard(
          symbol: 'NVDA',
          confidence: 94,
          headline: 'High Probability Volume Breakout',
          rationale: 'Deep neural network detects 4 concurrent bullish indicators: RSI divergence, OBV expansion, 50-day moving average rebound, and pre-earnings accumulation.',
          onExecute: onApplySignal,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          title: 'AI Trading Assistant',
          subtitle: 'Active market monitoring agent connected to live L2 order flow',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.md),
                ),
                child: Row(
                  children: <Widget>[
                    const UiTypingIndicator(),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Text(
                        'Scanning 4,800 tickers for volatility squeeze patterns...',
                        style: context.uiText.caption.copyWith(color: theme.colors.foregroundMuted),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              UiCallout(
                title: 'Risk Advisory Note',
                message: 'Upcoming CPI release in 18 hours. Volatility index (VIX) is up 4.2%. Maintain strict stops.',
                intent: UiIntent.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 94. EnterpriseBlocks — Institutional risk management and compliance audit block.
class EnterpriseBlocks extends StatelessWidget {
  const EnterpriseBlocks({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCallout(
          title: 'Portfolio Margin Level: 42%',
          message: 'Account operating safely within prime broker initial margin constraints (Max threshold: 75%).',
          intent: UiIntent.success,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          title: 'Institutional Risk Envelope',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Firm Value at Risk (VaR 99% 1D): \$14,200 (1.14% of Net Asset Value)'),
              SizedBox(height: context.sp(theme.spacing.sm)),
              const UiRangeMeter(
                min: 0,
                max: 50000,
                markers: <UiRangeMarker>[
                  UiRangeMarker(value: 14200, label: 'Current VaR', intent: UiIntent.primary, strong: true),
                  UiRangeMarker(value: 35000, label: 'Warning Cap', intent: UiIntent.warning),
                  UiRangeMarker(value: 45000, label: 'Hard Limit', intent: UiIntent.danger),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTable<Map<String, String>>(
          columns: const <UiTableColumn<Map<String, String>>>[
            UiTableColumn(header: 'AUDIT ID', cell: _idCell),
            UiTableColumn(header: 'EVENT', cell: _eventCell),
            UiTableColumn(header: 'COMPLIANCE STATUS', cell: _statusCell),
          ],
          rows: const <Map<String, String>>[
            {'id': 'AUD-901', 'event': 'Pre-trade margin verification', 'status': 'PASSED'},
            {'id': 'AUD-902', 'event': 'Wash-sale detection rule 14B', 'status': 'COMPLIANT'},
            {'id': 'AUD-903', 'event': 'Regulatory order routing check', 'status': 'VERIFIED'},
          ],
        ),
      ],
    );
  }

  static Widget _idCell(BuildContext ctx, Map<String, String> row) =>
      Text(row['id'] ?? '', style: ctx.uiText.caption);

  static Widget _eventCell(BuildContext ctx, Map<String, String> row) =>
      Text(row['event'] ?? '', style: ctx.uiText.bodyStrong);

  static Widget _statusCell(BuildContext ctx, Map<String, String> row) =>
      UiBadge(label: row['status'] ?? '', intent: UiIntent.success, size: UiSize.xs);
}
