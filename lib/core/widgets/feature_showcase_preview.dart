import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/widgets/feature_showcase_catalog.dart';

/// Interactive rich mini-preview of the selected feature rendered using
/// TraderHub UI components (`app_ui.dart` / `flutter_ui.dart`).
class FeatureShowcasePreviewPanel extends StatefulWidget {
  const FeatureShowcasePreviewPanel({
    super.key,
    required this.item,
  });

  final FeatureShowcaseItem item;

  @override
  State<FeatureShowcasePreviewPanel> createState() =>
      _FeatureShowcasePreviewPanelState();
}

class _FeatureShowcasePreviewPanelState
    extends State<FeatureShowcasePreviewPanel> {
  String _journalRange = '1W';
  String _notesView = 'thesis';
  String _strategyStage = 'Live';
  String _calcPreset = 'Aggressive';
  double _riskPercent = 1.0;
  String _marketTab = 'indices';
  bool _postLiked = false;
  bool _postSaved = false;
  String _cipherView = 'encrypted';
  String _aiMode = 'search';
  String _aiSkill = '/trader-analyst';
  String _notifFilter = 'all';
  String _planTier = 'pro';
  int _selectedDay = 2;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      key: ValueKey<String>('feature-preview-${widget.item.id}'),
      variant: UiCardVariant.surface,
      accentColor: theme.colors.primary,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.auto_graph_rounded,
                size: context.sz(15),
                color: theme.colors.primary,
              ),
              UiGap.h(theme.spacing.xs),
              Expanded(
                child: Text(
                  'INTERACTIVE PREVIEW · LIVE SIMULATOR',
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontSize: context.fs(10.5),
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const UiBadge(
                label: 'Interactive',
                intent: UiIntent.primary,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
            ],
          ),
          UiGap.v(theme.spacing.sm),
          switch (widget.item.previewKind) {
            FeaturePreviewKind.workspace => _buildWorkspacePreview(context),
            FeaturePreviewKind.journal => _buildJournalPreview(context),
            FeaturePreviewKind.notes => _buildNotesPreview(context),
            FeaturePreviewKind.strategies => _buildStrategiesPreview(context),
            FeaturePreviewKind.calculators => _buildCalculatorsPreview(context),
            FeaturePreviewKind.market => _buildMarketPreview(context),
            FeaturePreviewKind.community => _buildCommunityPreview(context),
            FeaturePreviewKind.messages => _buildMessagesPreview(context),
            FeaturePreviewKind.aiCopilot => _buildAiPreview(context),
            FeaturePreviewKind.notifications => _buildNotificationsPreview(context),
            FeaturePreviewKind.affiliate => _buildAffiliatePreview(context),
            FeaturePreviewKind.settings => _buildSettingsPreview(context),
            FeaturePreviewKind.admin => _buildAdminPreview(context),
          },
        ],
      ),
    );
  }

  Widget _buildWorkspacePreview(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    const days = <String>['Mon 12', 'Tue 13', 'Wed 14', 'Thu 15', 'Fri 16'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            for (int i = 0; i < days.length; i++)
              UiButton(
                label: days[i],
                size: UiSize.xs,
                variant: _selectedDay == i ? UiVariant.solid : UiVariant.outline,
                intent: _selectedDay == i ? UiIntent.primary : UiIntent.neutral,
                onPressed: () => setState(() => _selectedDay = i),
              ),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiBarChart(
          height: context.sz(124),
          showGrid: false,
          showLegend: true,
          interactive: false,
          series: <UiChartSeries>[
            UiChartSeries(name: 'Trades', color: colors.primary),
            UiChartSeries(name: 'Notes', color: colors.success),
          ],
          data: const <UiChartPoint>[
            UiChartPoint(label: 'Mon', values: <double>[3, 2]),
            UiChartPoint(label: 'Tue', values: <double>[2, 4]),
            UiChartPoint(label: 'Wed', values: <double>[5, 3]),
            UiChartPoint(label: 'Thu', values: <double>[4, 2]),
            UiChartPoint(label: 'Fri', values: <double>[3, 5]),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiTimeline(
          entries: <UiTimelineEntry>[
            UiTimelineEntry(
              title: '${days[_selectedDay]} · RELIANCE Opening Breakout',
              subtitle: 'Linked to ORB Playbook · +₹4,850 (+2.1R)',
              timestamp: '09:35 IST',
              intent: UiIntent.success,
              icon: Icons.trending_up_rounded,
            ),
            const UiTimelineEntry(
              title: 'Research Note · Banking Sector Flows',
              subtitle: r'2 linked symbols · $HDFCBANK · $ICICIBANK',
              timestamp: '11:10 IST',
              intent: UiIntent.primary,
              icon: Icons.link_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJournalPreview(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final bool weekly = _journalRange == '1W';
    final List<UiChartPoint> points = weekly
        ? const <UiChartPoint>[
            UiChartPoint(label: 'Mon', values: <double>[4200]),
            UiChartPoint(label: 'Tue', values: <double>[6800]),
            UiChartPoint(label: 'Wed', values: <double>[5900]),
            UiChartPoint(label: 'Thu', values: <double>[11400]),
            UiChartPoint(label: 'Fri', values: <double>[18420]),
          ]
        : const <UiChartPoint>[
            UiChartPoint(label: 'W1', values: <double>[14200]),
            UiChartPoint(label: 'W2', values: <double>[28500]),
            UiChartPoint(label: 'W3', values: <double>[41900]),
            UiChartPoint(label: 'W4', values: <double>[64900]),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            UiToggleGroup<String>(
              size: UiSize.xs,
              value: _journalRange,
              onChanged: (v) => setState(() => _journalRange = v),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: '1W', label: '1W'),
                UiToggleOption<String>(value: '1M', label: '1M'),
              ],
            ),
            UiBadge(
              label: weekly ? '68% Win · 2.4R Avg' : '71% Win · 3.1R Avg',
              intent: UiIntent.success,
              size: UiSize.xs,
            ),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiAreaChart(
          height: context.sz(138),
          showLegend: false,
          glow: true,
          interactive: false,
          series: <UiChartSeries>[
            UiChartSeries(name: 'Equity', color: colors.success, lineGlow: true),
          ],
          data: points,
        ),
        UiGap.v(theme.spacing.sm),
        UiMetricCard(
          title: 'Realized Expectancy ($_journalRange)',
          value: weekly ? '+₹18,420' : '+₹64,900',
          change: weekly ? 'Profit Factor 2.8' : 'Profit Factor 3.2',
          isPositive: true,
          subtitle: 'Mistake Filter: Zero Over-Sizing · Ready for PDF Export',
          intent: UiIntent.success,
        ),
      ],
    );
  }

  Widget _buildNotesPreview(BuildContext context) {
    final theme = context.ui;
    final bool refactored = _notesView == 'refactor';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<String>(
          size: UiSize.xs,
          value: _notesView,
          onChanged: (v) => setState(() => _notesView = v),
          options: const <UiToggleOption<String>>[
            UiToggleOption<String>(value: 'thesis', label: 'Raw Draft'),
            UiToggleOption<String>(value: 'refactor', label: 'AI Refactored'),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        const Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            UiBadge(label: r'$NIFTY50', intent: UiIntent.primary, size: UiSize.xs),
            UiBadge(label: r'$RELIANCE', intent: UiIntent.info, size: UiSize.xs),
            UiBadge(label: '[[ORB v2 Playbook]]', intent: UiIntent.success, size: UiSize.xs),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiCallout(
          title: refactored
              ? 'Structured Memo · Ready to Publish'
              : 'Live Intraday Scratchpad',
          message: refactored
              ? '• Bull Trigger: Sustained 15m close > 24,420 targeting 24,650\n'
                  '• Invalidation: VWAP breakdown on rising India VIX\n'
                  '• Linked Strategy: [[ORB v2 Playbook]]'
              : 'watch 24420 level nifty banks strong rely on vwap pullback before sizing...',
          intent: refactored ? UiIntent.success : UiIntent.primary,
          icon: refactored ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
        ),
      ],
    );
  }

  Widget _buildStrategiesPreview(BuildContext context) {
    final theme = context.ui;
    final DateTime base = DateTime(2026, 11, 10, 9, 15);
    final List<UiCandle> candles = <UiCandle>[
      UiCandle(time: base, open: 2820, high: 2848, low: 2812, close: 2842),
      UiCandle(time: base.add(const Duration(minutes: 15)), open: 2842, high: 2864, low: 2834, close: 2858),
      UiCandle(time: base.add(const Duration(minutes: 30)), open: 2858, high: 2868, low: 2844, close: 2849),
      UiCandle(time: base.add(const Duration(minutes: 45)), open: 2849, high: 2888, low: 2847, close: 2884),
      UiCandle(time: base.add(const Duration(minutes: 60)), open: 2884, high: 2912, low: 2879, close: 2906),
    ];
    final String stageStat = switch (_strategyStage) {
      'Draft' => 'Checklist 6/6 Rules · Pending Sample Validation',
      'Backtesting' => '24 Sample Setups · Simulated 2.3R · DD 4.1%',
      _ => '48 Linked Trades · 69% Win Rate · Realized +2.6R Avg',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<String>(
          size: UiSize.xs,
          value: _strategyStage,
          onChanged: (v) => setState(() => _strategyStage = v),
          options: const <UiToggleOption<String>>[
            UiToggleOption<String>(value: 'Draft', label: 'Draft'),
            UiToggleOption<String>(value: 'Backtesting', label: 'Backtest'),
            UiToggleOption<String>(value: 'Live', label: 'Live'),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiCandleChart(
          candles: candles,
          height: context.sz(142),
          showVolume: false,
          interactive: false,
          priceLines: const <UiPriceLine>[
            UiPriceLine(price: 2855, label: 'Entry', intent: UiIntent.primary),
            UiPriceLine(price: 2822, label: 'Stop', intent: UiIntent.danger),
            UiPriceLine(price: 2910, label: 'Target', intent: UiIntent.success),
          ],
        ),
        UiGap.v(theme.spacing.xs),
        Text(
          stageStat,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatorsPreview(BuildContext context) {
    final theme = context.ui;
    // ₹5,00,000 capital · Entry ₹1,420 · Stop ₹1,357.50 (₹62.50 risk/share)
    final double riskBudget = 500000 * (_riskPercent / 100.0);
    final int qty = (riskBudget / 62.5).round();
    final double capitalAllocated = (qty * 1420) / 500000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            UiToggleGroup<String>(
              size: UiSize.xs,
              value: _calcPreset,
              onChanged: (v) => setState(() {
                _calcPreset = v;
                _riskPercent = v == 'Conservative' ? 0.5 : 1.0;
              }),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'Conservative', label: '0.5% Risk'),
                UiToggleOption<String>(value: 'Aggressive', label: '1.0% Risk'),
              ],
            ),
            const UiBadge(
              label: '22 Tools Ready',
              intent: UiIntent.primary,
              size: UiSize.xs,
            ),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiSlider(
          label: 'Risk Per Trade Slider',
          value: _riskPercent,
          min: 0.25,
          max: 2.0,
          divisions: 7,
          size: UiSize.sm,
          valueFormatter: (v) => '${v.toStringAsFixed(2)}%',
          onChanged: (v) => setState(() {
            _riskPercent = v;
            _calcPreset = v <= 0.6 ? 'Conservative' : 'Aggressive';
          }),
        ),
        UiGap.v(theme.spacing.sm),
        UiMetricCard(
          title: 'Position Size · Capital ₹5,00,000',
          value: '$qty Shares',
          change: 'Max Risk ₹${riskBudget.round()} (${_riskPercent.toStringAsFixed(2)}%)',
          subtitle: 'Entry ₹1,420 · Stop ₹1,357.50 · Ready to draft into Journal',
          intent: UiIntent.primary,
        ),
        UiGap.v(theme.spacing.xs),
        UiProgressBar(
          value: capitalAllocated.clamp(0.0, 1.0),
          label: 'Capital Utilization',
          intent: capitalAllocated > 0.35 ? UiIntent.warning : UiIntent.success,
        ),
      ],
    );
  }

  Widget _buildMarketPreview(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final bool indices = _marketTab == 'indices';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<String>(
          size: UiSize.xs,
          value: _marketTab,
          onChanged: (v) => setState(() => _marketTab = v),
          options: const <UiToggleOption<String>>[
            UiToggleOption<String>(value: 'indices', label: 'Index Pulse'),
            UiToggleOption<String>(value: 'sectors', label: 'Sector Breadth'),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiMetricCard(
          title: indices
              ? 'NIFTY 50 · app.alphajournal.in/market/NIFTY50'
              : 'RELIANCE · app.alphajournal.in/market/RELIANCE',
          value: indices ? '24,548.60' : '₹2,942.40',
          delta: indices ? 1.42 : 2.18,
          subtitle: indices
              ? 'Advancers 38 · Decliners 12 · Screeners Active'
              : 'P/E 28.4 · Institutional Holders & Live News Ready',
          sparkline: indices
              ? const <double>[24180, 24250, 24210, 24380, 24470, 24548]
              : const <double>[2860, 2882, 2875, 2908, 2925, 2942],
          intent: UiIntent.bullish,
        ),
        UiGap.v(theme.spacing.sm),
        if (indices)
          const UiCategoryBar(
            showLegend: true,
            categories: <UiCategorySegment>[
              UiCategorySegment(value: 56, label: 'IT & Banks'),
              UiCategorySegment(value: 28, label: 'Energy'),
              UiCategorySegment(value: 16, label: 'Auto'),
            ],
          )
        else
          UiBarChart(
            height: context.sz(110),
            showGrid: false,
            showLegend: false,
            interactive: false,
            series: <UiChartSeries>[
              UiChartSeries(name: 'Change %', color: colors.success),
            ],
            data: const <UiChartPoint>[
              UiChartPoint(label: 'IT', values: <double>[2.4]),
              UiChartPoint(label: 'Bank', values: <double>[1.6]),
              UiChartPoint(label: 'Auto', values: <double>[1.2]),
              UiChartPoint(label: 'FMCG', values: <double>[0.8]),
            ],
          ),
      ],
    );
  }

  Widget _buildCommunityPreview(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const UiAvatar(name: 'Aarav Mehta', size: UiSize.sm),
            UiGap.h(theme.spacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Aarav Mehta', style: context.uiText.bodyStrong),
                  Text(
                    'community.alphajournal.in/@aarav',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const UiBadge(
              label: r'LONG $TATAMOTORS',
              intent: UiIntent.success,
              size: UiSize.xs,
            ),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        Text(
          'Clean flag breakout on rising delivery volume. Entry ₹942 · Target ₹998 · Stop ₹918 (2.3R).',
          style: context.uiText.body,
        ),
        UiGap.v(theme.spacing.sm),
        const Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            UiBadge(label: 'Entry ₹942', variant: UiBadgeVariant.outline, size: UiSize.xs),
            UiBadge(label: 'Target ₹998', intent: UiIntent.success, variant: UiBadgeVariant.soft, size: UiSize.xs),
            UiBadge(label: 'Stop ₹918', intent: UiIntent.danger, variant: UiBadgeVariant.soft, size: UiSize.xs),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            UiButton(
              label: _postLiked ? 'Bullish (43)' : 'Bullish (42)',
              icon: _postLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              size: UiSize.xs,
              variant: _postLiked ? UiVariant.solid : UiVariant.outline,
              intent: _postLiked ? UiIntent.success : UiIntent.neutral,
              onPressed: () => setState(() => _postLiked = !_postLiked),
            ),
            UiButton(
              label: _postSaved ? 'Saved to Notes' : 'Bookmark',
              icon: _postSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: UiSize.xs,
              variant: _postSaved ? UiVariant.soft : UiVariant.outline,
              intent: _postSaved ? UiIntent.primary : UiIntent.neutral,
              onPressed: () => setState(() => _postSaved = !_postSaved),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagesPreview(BuildContext context) {
    final theme = context.ui;
    final bool encrypted = _cipherView == 'encrypted';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<String>(
          size: UiSize.xs,
          value: _cipherView,
          onChanged: (v) => setState(() => _cipherView = v),
          options: const <UiToggleOption<String>>[
            UiToggleOption<String>(value: 'plaintext', label: 'Your Device'),
            UiToggleOption<String>(value: 'encrypted', label: 'Server Wire Payload'),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiCallout(
          title: encrypted
              ? 'Zero-Knowledge AES-256-GCM Envelope'
              : 'Decrypted Only With Your X25519 Key',
          message: encrypted
              ? 'ciphertext: "v1.gcm.9f4a81c2e7b0..."\nhmac_sha256: "verified_device_signature"'
              : 'Shared Journal: LONG NIFTY 24,450 · Stop 24,380 · +2.4R execution attached.',
          intent: encrypted ? UiIntent.primary : UiIntent.success,
          icon: encrypted ? Icons.lock_outline_rounded : Icons.verified_user_outlined,
        ),
      ],
    );
  }

  Widget _buildAiPreview(BuildContext context) {
    final theme = context.ui;
    final String summary = switch (_aiMode) {
      'search' =>
          'Live web_search verified today’s RBI liquidity stance, US CPI release window, and FII cash flow before calculating overnight option hedges.',
      'research' =>
          'Multi-step deep synthesis audited your last 30 swing trades against your VWAP Playbook rules and surfaced a 14% expectancy boost when avoiding first-5-min entries.',
      _ =>
          'Instant workspace copilot with 11 /trader-* workflows and hands-free Voice Call mode.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<String>(
          size: UiSize.xs,
          value: _aiMode,
          onChanged: (v) => setState(() => _aiMode = v),
          options: const <UiToggleOption<String>>[
            UiToggleOption<String>(value: 'auto', label: 'Auto'),
            UiToggleOption<String>(value: 'search', label: 'Web Search'),
            UiToggleOption<String>(value: 'research', label: 'Research'),
          ],
        ),
        UiGap.v(theme.spacing.xs),
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            for (final skill in const <String>[
              '/trader-analyst',
              '/trader-risk',
              '/trader-debrief',
            ])
              UiButton(
                label: skill,
                size: UiSize.xs,
                variant: _aiSkill == skill ? UiVariant.soft : UiVariant.outline,
                intent: _aiSkill == skill ? UiIntent.primary : UiIntent.neutral,
                onPressed: () => setState(() => _aiSkill = skill),
              ),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiCallout(
          title: '$_aiSkill · Live Voice & Citations Active',
          message: summary,
          intent: UiIntent.primary,
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );
  }

  Widget _buildNotificationsPreview(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<String>(
          size: UiSize.xs,
          value: _notifFilter,
          onChanged: (v) => setState(() => _notifFilter = v),
          options: const <UiToggleOption<String>>[
            UiToggleOption<String>(value: 'all', label: 'All Alerts'),
            UiToggleOption<String>(value: 'security', label: 'Security & Push'),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiTimeline(
          entries: _notifFilter == 'security'
              ? const <UiTimelineEntry>[
                  UiTimelineEntry(
                    title: 'Web Push VAPID Delivery Active',
                    subtitle: 'Background browser notifications enabled for DMs & alerts.',
                    timestamp: 'Active',
                    intent: UiIntent.success,
                    icon: Icons.notifications_active_outlined,
                  ),
                  UiTimelineEntry(
                    title: 'E2EE Key Sync Verified',
                    subtitle: 'New browser session verified across *.alphajournal.in.',
                    timestamp: '10m ago',
                    intent: UiIntent.primary,
                    icon: Icons.security_rounded,
                  ),
                ]
              : const <UiTimelineEntry>[
                  UiTimelineEntry(
                    title: r'New reply on LONG $NIFTY50 setup',
                    subtitle: '@kiran: Watching 24,500 OI buildup too — clean 2.4R.',
                    timestamp: 'Just now',
                    intent: UiIntent.primary,
                    icon: Icons.forum_outlined,
                  ),
                  UiTimelineEntry(
                    title: 'Web Push VAPID Delivery Active',
                    subtitle: 'Background browser notifications enabled for DMs & alerts.',
                    timestamp: '2m ago',
                    intent: UiIntent.success,
                    icon: Icons.notifications_active_outlined,
                  ),
                ],
        ),
      ],
    );
  }

  Widget _buildAffiliatePreview(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiMetricCard(
          title: '30-Day Referral Link · alphajournal.in/r/nitish',
          value: '₹42,800',
          change: '142 Active Traders',
          isPositive: true,
          intent: UiIntent.success,
        ),
        UiGap.v(theme.spacing.sm),
        UiBarChart(
          height: context.sz(116),
          showGrid: false,
          showLegend: false,
          interactive: false,
          series: <UiChartSeries>[
            UiChartSeries(name: 'INR Payouts', color: colors.success),
          ],
          data: const <UiChartPoint>[
            UiChartPoint(label: 'Jul', values: <double>[14200]),
            UiChartPoint(label: 'Aug', values: <double>[21800]),
            UiChartPoint(label: 'Sep', values: <double>[31500]),
            UiChartPoint(label: 'Oct', values: <double>[42800]),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        const UiProgressBar(
          value: 0.78,
          label: 'UPI / Bank INR Payout Clearance Cycle',
          intent: UiIntent.primary,
        ),
      ],
    );
  }

  Widget _buildSettingsPreview(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final ({String price, String limits, double aiQuota, double journalQuota})
    tier = switch (_planTier) {
      'free' => (
          price: '₹0 / month',
          limits: '15 Journal · 20 Notes · 15 Strategies · 15 AI Prompts',
          aiQuota: 15,
          journalQuota: 15,
        ),
      'basic' => (
          price: '₹299 / month',
          limits: '75 Journal · 100 Notes · 40 Strategies · 120 AI Prompts',
          aiQuota: 120,
          journalQuota: 75,
        ),
      _ => (
          price: '₹499 / month',
          limits: 'Unlimited Workspace · 500 AI Prompts · All Pro Workflows',
          aiQuota: 500,
          journalQuota: 300,
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<String>(
          size: UiSize.xs,
          value: _planTier,
          onChanged: (v) => setState(() => _planTier = v),
          options: const <UiToggleOption<String>>[
            UiToggleOption<String>(value: 'free', label: 'Free'),
            UiToggleOption<String>(value: 'basic', label: 'Basic'),
            UiToggleOption<String>(value: 'pro', label: 'Pro'),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        UiMetricCard(
          title: 'alphajournal ${_planTier.toUpperCase()}',
          value: tier.price,
          subtitle: tier.limits,
          intent: UiIntent.primary,
        ),
        UiGap.v(theme.spacing.sm),
        UiDonutChart(
          size: 128,
          showLegend: true,
          centerLabel: _planTier.toUpperCase(),
          slices: <UiDonutSlice>[
            UiDonutSlice(
              label: 'AI Quota (${tier.aiQuota.round()})',
              value: tier.aiQuota,
              color: colors.primary,
            ),
            UiDonutSlice(
              label: 'Workspace Capacity',
              value: tier.journalQuota,
              color: colors.success,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminPreview(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiCallout(
          title: 'admin.alphajournal.in · Edge Isolated',
          message:
              'Approve affiliate creators, audit platform deletions, inspect community reports, and manage workspace team seats.',
          intent: UiIntent.warning,
          icon: Icons.admin_panel_settings_outlined,
        ),
        UiGap.v(theme.spacing.sm),
        UiBarChart(
          height: context.sz(112),
          showGrid: false,
          showLegend: false,
          interactive: false,
          series: <UiChartSeries>[
            UiChartSeries(name: 'Queue Items', color: colors.warning),
          ],
          data: const <UiChartPoint>[
            UiChartPoint(label: 'Affiliates', values: <double>[8]),
            UiChartPoint(label: 'Comments', values: <double>[3]),
            UiChartPoint(label: 'Audit', values: <double>[5]),
            UiChartPoint(label: 'Seats', values: <double>[12]),
          ],
        ),
      ],
    );
  }
}
