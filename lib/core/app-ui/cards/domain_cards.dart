import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../theme/app_tokens.dart';
import 'community_cards.dart';
import 'notes_cards.dart';

/// 1. PortfolioSummaryCard — Net worth, PnL, cash balance, and daily gain summary card.
class PortfolioSummaryCard extends StatelessWidget {
  const PortfolioSummaryCard({
    super.key,
    this.netWorth = 124500.0,
    this.totalPnl = 14250.0,
    this.pnlPercent = 12.9,
    this.cashBalance = 32100.0,
    this.dailyGain = 1250.0,
    this.dailyGainPercent = 1.02,
    this.sparklineData = const <double>[10, 15, 12, 18, 22, 21, 28],
    this.onDeposit,
    this.onWithdraw,
  });

  final double netWorth;
  final double totalPnl;
  final double pnlPercent;
  final double cashBalance;
  final double dailyGain;
  final double dailyGainPercent;
  final List<double> sparklineData;
  final VoidCallback? onDeposit;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isBullish = dailyGain >= 0;

    return UiCard(
      accentColor: isBullish ? theme.colors.success : theme.colors.destructive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              Text(
                'Total Net Worth',
                style: context.uiText.label.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              UiBadge(
                label:
                    '${isBullish ? '+' : ''}${dailyGainPercent.toStringAsFixed(2)}% Today',
                intent: isBullish ? UiIntent.success : UiIntent.danger,
                variant: UiBadgeVariant.soft,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.md),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              Text(
                AppTokens.price(netWorth.round()),
                style: context.uiText.title.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foreground,
                ),
              ),
              if (sparklineData.isNotEmpty)
                SizedBox(
                  width: context.sz(96),
                  height: context.sz(28),
                  child: UiSparkChart(
                    data: sparklineData,
                    color: isBullish
                        ? theme.colors.success
                        : theme.colors.destructive,
                  ),
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiDivider(),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.lg),
            runSpacing: context.sp(theme.spacing.sm),
            children: <Widget>[
              _subMetric(
                context,
                'Total Profit/Loss',
                '${totalPnl >= 0 ? '+' : ''}${AppTokens.price(totalPnl.round())}',
                totalPnl >= 0 ? theme.colors.success : theme.colors.destructive,
              ),
              _subMetric(
                context,
                'Available Cash',
                AppTokens.price(cashBalance.round()),
                theme.colors.foreground,
              ),
            ],
          ),
          if (onDeposit != null || onWithdraw != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Row(
              children: <Widget>[
                if (onDeposit != null)
                  Expanded(
                    child: UiButton(
                      label: 'Deposit',
                      size: UiSize.sm,
                      variant: UiVariant.solid,
                      intent: UiIntent.primary,
                      onPressed: onDeposit,
                    ),
                  ),
                if (onDeposit != null && onWithdraw != null)
                  SizedBox(width: context.sp(theme.spacing.sm)),
                if (onWithdraw != null)
                  Expanded(
                    child: UiButton(
                      label: 'Withdraw',
                      size: UiSize.sm,
                      variant: UiVariant.outline,
                      onPressed: onWithdraw,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _subMetric(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: context.ui.colors.foregroundSubtle,
          ),
        ),
        Text(
          value,
          style: context.uiText.bodyStrong.copyWith(color: valueColor),
        ),
      ],
    );
  }
}

/// 2. AssetAllocationCard — Portfolio asset breakdown (stocks, crypto, options, cash).
class AssetAllocationCard extends StatelessWidget {
  const AssetAllocationCard({
    super.key,
    this.title = 'Asset Allocation',
    this.slices = const <DonutSlice>[
      DonutSlice(label: 'Stocks', value: 55, color: Color(0xFF2563EB)),
      DonutSlice(label: 'Crypto', value: 25, color: Color(0xFF10B981)),
      DonutSlice(label: 'Options', value: 12, color: Color(0xFFF59E0B)),
      DonutSlice(label: 'Cash', value: 8, color: Color(0xFF6B7280)),
    ],
    this.totalValue = r'$124,500',
  });

  final String title;
  final List<DonutSlice> slices;
  final String totalValue;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: title,
      child: Column(
        children: <Widget>[
          UiDonutChart(slices: slices, centerLabel: totalValue),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCategoryBar(
            categories: slices
                .map(
                  (DonutSlice s) => UiCategoryItem(
                    label: s.label,
                    value: s.value,
                    color: s.color,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// 3. PerformanceCard — Annual/monthly return matrix with win-rate stats.
class PerformanceCard extends StatelessWidget {
  const PerformanceCard({
    super.key,
    this.title = 'Trading Performance',
    this.winRate = 68.4,
    this.profitFactor = 2.14,
    this.totalTrades = 142,
    this.annualReturn = 34.2,
    this.monthlyReturns = const <double>[3.2, 5.1, -1.4, 4.8, 2.9, 6.2],
  });

  final String title;
  final double winRate;
  final double profitFactor;
  final int totalTrades;
  final double annualReturn;
  final List<double> monthlyReturns;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: UiMetricCard(
                  title: 'Win Rate',
                  value: '${winRate.toStringAsFixed(1)}%',
                  change: '+$winRate%',
                  isPositive: winRate >= 50,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: UiMetricCard(
                  title: 'Profit Factor',
                  value: profitFactor.toStringAsFixed(2),
                  change: '$totalTrades trades',
                  isPositive: profitFactor >= 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(
            'Target Completion (Annual $annualReturn%)',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          UiProgressBar(
            value: (annualReturn / 50.0).clamp(0.0, 1.0),
            label: '${annualReturn.toStringAsFixed(1)}% / 50.0% Target',
          ),
        ],
      ),
    );
  }
}

/// 4. TradeHistoryCard — Executed trade log card with entry/exit, quantity, PnL badge.
class TradeHistoryCard extends StatelessWidget {
  const TradeHistoryCard({
    super.key,
    this.title = 'Recent Executions',
    this.trades,
    this.onViewAll,
  });

  final String title;
  final List<AppTrade>? trades;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppTrade> list =
        trades ??
        <AppTrade>[
          AppTrade(
            id: '1',
            ticker: 'NVDA',
            side: AppSide.long,
            entry: 124.5,
            exit: 138.2,
            pnl: 1370.0,
            pnlPercent: 11.0,
            openedAt: DateTime.now().subtract(const Duration(hours: 3)),
          ),
          AppTrade(
            id: '2',
            ticker: 'TSLA',
            side: AppSide.short,
            entry: 215.0,
            exit: 202.4,
            pnl: 840.0,
            pnlPercent: 5.86,
            openedAt: DateTime.now().subtract(const Duration(hours: 6)),
          ),
          AppTrade(
            id: '3',
            ticker: 'AAPL',
            side: AppSide.long,
            entry: 228.0,
            exit: 225.1,
            pnl: -290.0,
            pnlPercent: -1.27,
            openedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];

    return UiCard(
      title: title,
      action: onViewAll != null
          ? UiButton(
              label: 'View All',
              size: UiSize.xs,
              variant: UiVariant.ghost,
              onPressed: onViewAll,
            )
          : null,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < list.length; i++) ...<Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.sp(theme.spacing.sm),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          list[i].ticker,
                          style: context.uiText.bodyStrong.copyWith(
                            color: theme.colors.foreground,
                          ),
                        ),
                        Text(
                          '${list[i].side == AppSide.long ? "BUY" : "SELL"} @ \$${list[i].entry.toStringAsFixed(2)}',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge(
                    label:
                        '${list[i].pnl >= 0 ? "+" : ""}\$${list[i].pnl.toStringAsFixed(2)}',
                    intent: list[i].pnl >= 0
                        ? UiIntent.success
                        : UiIntent.danger,
                    variant: UiBadgeVariant.soft,
                  ),
                ],
              ),
            ),
            if (i < list.length - 1)
              Divider(height: 1, color: theme.colors.border),
          ],
        ],
      ),
    );
  }
}

/// 5. PositionCard — Open position card with live market price, liquidation level, and PnL.
class PositionCard extends StatelessWidget {
  const PositionCard({
    super.key,
    this.ticker = 'BTC/USDT',
    this.side = 'LONG 5X',
    this.entryPrice = 64200.0,
    this.markPrice = 67800.0,
    this.liquidationPrice = 52100.0,
    this.pnl = 3600.0,
    this.pnlPercent = 28.03,
    this.onClose,
    this.onAdjust,
  });

  final String ticker;
  final String side;
  final double entryPrice;
  final double markPrice;
  final double liquidationPrice;
  final double pnl;
  final double pnlPercent;
  final VoidCallback? onClose;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isBullish = pnl >= 0;

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    ticker,
                    style: context.uiText.subheading.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colors.foreground,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  UiBadge(
                    label: side,
                    intent: UiIntent.primary,
                    variant: UiBadgeVariant.soft,
                  ),
                ],
              ),
              UiBadge(
                label:
                    '${isBullish ? "+" : ""}${pnlPercent.toStringAsFixed(2)}%',
                intent: isBullish ? UiIntent.success : UiIntent.danger,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiRangeMeter(
            min: liquidationPrice,
            max: markPrice * 1.1,
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: liquidationPrice,
                label: 'Liq',
                intent: UiIntent.danger,
              ),
              UiRangeMarker(
                value: entryPrice,
                label: 'Entry',
                intent: UiIntent.neutral,
              ),
              UiRangeMarker(
                value: markPrice,
                label: 'Spot',
                intent: UiIntent.primary,
                strong: true,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              if (onAdjust != null)
                Expanded(
                  child: UiButton(
                    label: 'Adjust Margin',
                    size: UiSize.sm,
                    variant: UiVariant.outline,
                    onPressed: onAdjust,
                  ),
                ),
              if (onAdjust != null && onClose != null)
                SizedBox(width: context.sp(theme.spacing.sm)),
              if (onClose != null)
                Expanded(
                  child: UiButton(
                    label: 'Close Position',
                    size: UiSize.sm,
                    intent: UiIntent.danger,
                    variant: UiVariant.soft,
                    onPressed: onClose,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 6. WatchlistCard — Custom symbol watchlist card with sparklines and price changes.
class WatchlistCard extends StatelessWidget {
  const WatchlistCard({
    super.key,
    this.title = 'Watchlist',
    this.symbols = const <Map<String, dynamic>>[
      {
        'symbol': 'NVDA',
        'price': 128.5,
        'change': 3.42,
        'spark': [10.0, 12.0, 14.0, 16.0],
      },
      {
        'symbol': 'AAPL',
        'price': 224.2,
        'change': -0.84,
        'spark': [15.0, 14.0, 13.0, 12.0],
      },
      {
        'symbol': 'TSLA',
        'price': 218.9,
        'change': 5.12,
        'spark': [8.0, 10.0, 14.0, 18.0],
      },
    ],
    this.onSelectSymbol,
  });

  final String title;
  final List<Map<String, dynamic>> symbols;
  final ValueChanged<String>? onSelectSymbol;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: title,
      child: Column(
        children: <Widget>[
          for (final Map<String, dynamic> item in symbols) ...<Widget>[
            UiInteractive(
              onTap: onSelectSymbol != null
                  ? () => onSelectSymbol!(item['symbol'] as String)
                  : null,
              builder: (BuildContext ctx, UiInteractiveState state) => Container(
                padding: EdgeInsets.symmetric(
                  vertical: ctx.sp(theme.spacing.sm),
                  horizontal: ctx.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: state.hovered
                      ? theme.colors.surfaceHover
                      : Colors.transparent,
                  borderRadius: ctx.radius(theme.radii.sm),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item['symbol'] as String,
                        style: ctx.uiText.bodyStrong,
                      ),
                    ),
                    if (item['spark'] != null)
                      SizedBox(
                        width: ctx.sz(60),
                        height: ctx.sz(20),
                        child: UiSparkChart(
                          data: List<double>.from(
                            item['spark'] as List<dynamic>,
                          ),
                          color: (item['change'] as num) >= 0
                              ? theme.colors.success
                              : theme.colors.destructive,
                        ),
                      ),
                    SizedBox(width: ctx.sp(theme.spacing.md)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '\$${(item['price'] as num).toStringAsFixed(2)}',
                          style: ctx.uiText.bodyStrong,
                        ),
                        Text(
                          '${(item['change'] as num) >= 0 ? "+" : ""}${(item['change'] as num).toStringAsFixed(2)}%',
                          style: ctx.uiText.caption.copyWith(
                            color: (item['change'] as num) >= 0
                                ? theme.colors.success
                                : theme.colors.destructive,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (item != symbols.last)
              Divider(height: 1, color: theme.colors.border),
          ],
        ],
      ),
    );
  }
}

/// 7. JournalEntryCard — Trade journal record card with chart thumbnail, notes, and tags.
class JournalEntryCard extends StatelessWidget {
  const JournalEntryCard({
    super.key,
    this.ticker = 'NVDA',
    this.strategy = 'Earnings Breakout',
    this.date = 'Sep 8, 2026',
    this.notes =
        'Clean volume confirmation upon crossing 125 resistance. Scaled out at target.',
    this.tags = const <String>['bullish', 'breakout', 'tech'],
    this.pnl = 1450.0,
    this.onTap,
  });

  final String ticker;
  final String strategy;
  final String date;
  final String notes;
  final List<String> tags;
  final double pnl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isPositive = pnl >= 0;

    return UiCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    ticker,
                    style: context.uiText.heading.copyWith(
                      color: theme.colors.foreground,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  UiBadge(
                    label: strategy,
                    intent: UiIntent.primary,
                    variant: UiBadgeVariant.soft,
                  ),
                ],
              ),
              UiBadge(
                label: '${isPositive ? "+" : ""}\$${pnl.toStringAsFixed(2)}',
                intent: isPositive ? UiIntent.success : UiIntent.danger,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            date,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            markdownToPlainText(notes),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.body.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xxs),
            children: <Widget>[
              for (final String t in tags)
                UiBadge(
                  label: '#$t',
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 8. MarketOverviewCard — Major market indices summary card (S&P 500, Nasdaq, BTC, Gold).
class MarketOverviewCard extends StatelessWidget {
  const MarketOverviewCard({
    super.key,
    this.title = 'Global Markets',
    this.indices = const <Map<String, dynamic>>[
      {'name': 'S&P 500', 'value': '5,842.10', 'change': '+0.42%', 'pos': true},
      {
        'name': 'Nasdaq 100',
        'value': '20,410.50',
        'change': '+0.88%',
        'pos': true,
      },
      {
        'name': 'Bitcoin',
        'value': '\$67,420',
        'change': '-1.20%',
        'pos': false,
      },
      {'name': 'Gold', 'value': '\$2,640.80', 'change': '+0.15%', 'pos': true},
    ],
  });

  final String title;
  final List<Map<String, dynamic>> indices;

  @override
  Widget build(BuildContext context) {
    return UiCard(
      title: title,
      child: UiCardGrid(
        mobileColumns: 2,
        tabletColumns: 4,
        desktopColumns: 4,
        largeColumns: 4,
        children: <Widget>[
          for (final Map<String, dynamic> idx in indices)
            UiMetricCard(
              title: idx['name'] as String,
              value: idx['value'] as String,
              change: idx['change'] as String,
              isPositive: idx['pos'] as bool,
            ),
        ],
      ),
    );
  }
}

/// 9. StrategyCard — Quantitative strategy card with Sharpe ratio, win rate, and drawdown.
class StrategyCard extends StatelessWidget {
  const StrategyCard({
    super.key,
    this.name = 'Momentum Volatility Breakout',
    this.author = 'QuantCore Lab',
    this.sharpeRatio = 2.45,
    this.winRate = 71.2,
    this.maxDrawdown = 8.4,
    this.active = true,
    this.onToggle,
    this.onTap,
  });

  final String name;
  final String author;
  final double sharpeRatio;
  final double winRate;
  final double maxDrawdown;
  final bool active;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: context.uiText.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'by $author',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              UiSwitch(value: active, onChanged: onToggle),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              Expanded(
                child: _stat(context, 'Sharpe', sharpeRatio.toStringAsFixed(2)),
              ),
              Expanded(
                child: _stat(
                  context,
                  'Win Rate',
                  '${winRate.toStringAsFixed(1)}%',
                ),
              ),
              Expanded(
                child: _stat(
                  context,
                  'Max DD',
                  '-${maxDrawdown.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.caption.copyWith(
            color: context.ui.colors.foregroundMuted,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.bodyStrong,
        ),
      ],
    );
  }
}

/// 10. AccountCard — User profile summary card with tier badge and security status.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    this.name = 'Alex Thorne',
    this.email = 'alex.thorne@tradex.internal',
    this.tier = 'PRO TRADER',
    this.securityLevel = '2FA ACTIVE',
    this.onSettings,
  });

  final String name;
  final String email;
  final String tier;
  final String securityLevel;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      child: Row(
        children: <Widget>[
          UiAvatar(name: name, size: UiSize.lg),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xxs),
                  children: <Widget>[
                    Text(
                      name,
                      style: context.uiText.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    UiBadge(
                      label: tier,
                      intent: UiIntent.primary,
                      size: UiSize.xs,
                    ),
                  ],
                ),
                Text(
                  email,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                UiBadge(
                  label: securityLevel,
                  intent: UiIntent.success,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              ],
            ),
          ),
          if (onSettings != null)
            UiIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Account Settings',
              onPressed: onSettings,
            ),
        ],
      ),
    );
  }
}

/// 11. AiInsightCard — AI trade signal card with confidence score and trade setup rationale.
class AiInsightCard extends StatelessWidget {
  const AiInsightCard({
    super.key,
    this.symbol = 'NVDA',
    this.signal = 'BULLISH BREAKOUT',
    this.confidence = 92,
    this.headline = 'Volume Expansion Above \$125 Pivot',
    this.rationale =
        'Statistical pattern match across 84 historical earnings pre-runs indicates 78% probability of continued impulse towards \$138.',
    this.target = '\$138.00',
    this.stopLoss = '\$121.50',
    this.onExecute,
  });

  final String symbol;
  final String signal;
  final int confidence;
  final String headline;
  final String rationale;
  final String target;
  final String stopLoss;
  final VoidCallback? onExecute;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      accentColor: theme.colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome,
                    size: context.sz(theme.sizes.iconSm),
                    color: theme.colors.primary,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Text(
                    'AI SIGNAL — $symbol',
                    style: context.uiText.label.copyWith(
                      color: theme.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              UiBadge(
                label: '$confidence% CONFIDENCE',
                intent: UiIntent.primary,
                variant: UiBadgeVariant.soft,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            headline,
            style: context.uiText.subheading.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            rationale,
            style: context.uiText.body.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.md),
            runSpacing: context.sp(theme.spacing.sm),
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Target', style: context.uiText.caption),
                      Text(
                        target,
                        style: context.uiText.bodyStrong.copyWith(
                          color: theme.colors.success,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: context.sp(theme.spacing.lg)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Stop Loss', style: context.uiText.caption),
                      Text(
                        stopLoss,
                        style: context.uiText.bodyStrong.copyWith(
                          color: theme.colors.destructive,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (onExecute != null)
                UiButton(
                  label: 'Execute Order',
                  size: UiSize.sm,
                  variant: UiVariant.solid,
                  intent: UiIntent.primary,
                  onPressed: onExecute,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 12. CommunityPostCard — Social post card with trader comments, likes, and chart attachments.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    this.authorName = 'Sarah Jenkins',
    this.authorTier = 'TOP TRADER',
    this.timeAgo = '2h ago',
    this.content =
        'Closed my swing position on NVDA with +18% gain! Locking profits ahead of CPI release tomorrow.',
    this.likes = 42,
    this.comments = 11,
    this.onLike,
    this.onComment,
    this.onShare,
  });

  final String authorName;
  final String authorTier;
  final String timeAgo;
  final String content;
  final int likes;
  final int comments;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              UiAvatar(name: authorName, size: UiSize.sm),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: context.sp(theme.spacing.xs),
                      runSpacing: context.sp(theme.spacing.xxs),
                      children: <Widget>[
                        Text(authorName, style: context.uiText.bodyStrong),
                        UiBadge(
                          label: authorTier,
                          size: UiSize.xs,
                          intent: UiIntent.primary,
                        ),
                      ],
                    ),
                    Text(
                      timeAgo,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(content, style: context.uiText.body),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              UiButton(
                label: '$likes',
                icon: Icons.thumb_up_outlined,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: onLike,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiButton(
                label: '$comments',
                icon: Icons.mode_comment_outlined,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: onComment,
              ),
              const Spacer(),
              UiIconButton(
                icon: Icons.share_outlined,
                size: UiSize.xs,
                tooltip: 'Share',
                onPressed:
                    onShare ??
                    () => AppPostShareModal.showSimple(
                      context,
                      authorName: authorName,
                      authorBadge: authorTier,
                      body: content,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
