import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

/// Predefined AI chart analysis templates for instant simulation.
class AiChartPreset {
  const AiChartPreset({
    required this.id,
    required this.title,
    required this.symbol,
    required this.timeframe,
    required this.pattern,
    required this.direction,
    required this.entry,
    required this.stopLoss,
    required this.target1,
    required this.target2,
    required this.confidence,
    required this.rationale,
    required this.previewUrl,
  });

  final String id;
  final String title;
  final String symbol;
  final String timeframe;
  final String pattern;
  final String direction; // 'Long' or 'Short'
  final double entry;
  final double stopLoss;
  final double target1;
  final double target2;
  final int confidence;
  final String rationale;
  final String previewUrl;

  double get risk => (entry - stopLoss).abs();
  double get reward => (target1 - entry).abs();
  double get rrRatio => risk > 0 ? (reward / risk) : 1.0;
}

final List<AiChartPreset> kAiChartPresets = <AiChartPreset>[
  const AiChartPreset(
    id: 'preset_nifty',
    title: 'Nifty Bull Flag Breakout',
    symbol: 'NIFTY 50',
    timeframe: '15m',
    pattern: 'Bull Flag Retest',
    direction: 'Long',
    entry: 24850.00,
    stopLoss: 24780.00,
    target1: 24990.00,
    target2: 25120.00,
    confidence: 89,
    rationale:
        'Clean impulsive pole followed by a tight 3-day descending flag. 15m candle close confirmed breakout above VWAP with aggressive absorption at the 24,780 demand block.',
    previewUrl:
        'https://images.unsplash.com/photo-1642543492481-44e81e3914a7?w=600',
  ),
  const AiChartPreset(
    id: 'preset_banknifty',
    title: 'BankNifty FVG & Liquidity Grab',
    symbol: 'BANKNIFTY',
    timeframe: '5m',
    pattern: 'Liquidity Sweep + Fair Value Gap',
    direction: 'Short',
    entry: 52400.00,
    stopLoss: 52580.00,
    target1: 52040.00,
    target2: 51800.00,
    confidence: 93,
    rationale:
        'Morning highs tapped into previous week unmitigated FVG. Immediate rejection printed a bearish market structure shift (MSS) with institutional sell volume delta.',
    previewUrl:
        'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=600',
  ),
  const AiChartPreset(
    id: 'preset_nvda',
    title: 'NVDA Ascending Triangle',
    symbol: 'NVDA',
    timeframe: '1h',
    pattern: 'Ascending Triangle Compression',
    direction: 'Long',
    entry: 128.50,
    stopLoss: 123.20,
    target1: 139.00,
    target2: 148.00,
    confidence: 87,
    rationale:
        'Higher lows pressing into the persistent \$128.50 supply zone. Call open interest building significantly at the \$135 strike with positive RSI divergence.',
    previewUrl:
        'https://images.unsplash.com/photo-1642790106117-e829e14a795f?w=600',
  ),
];

/// Full-featured AI Floating Assistant Dialog with Chart Screenshot Analyzer.
///
/// Features:
/// 1. Drag & drop or sample chart selection.
/// 2. Multi-step automated pattern detection pipeline.
/// 3. Visual trade setup preview with calculated R:R and win probability.
/// 4. One-click export to: Community Post, Notes, Journal, or Playbook Strategy.
class CommunityAiAssistantDialog extends StatefulWidget {
  const CommunityAiAssistantDialog({
    super.key,
    this.repository,
    this.onPostCreated,
    this.initialPreset,
  });

  final CommunityRepository? repository;
  final ValueChanged<CommunityPost>? onPostCreated;
  final AiChartPreset? initialPreset;

  static Future<void> show(
    BuildContext context, {
    CommunityRepository? repository,
    ValueChanged<CommunityPost>? onPostCreated,
    AiChartPreset? initialPreset,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => CommunityAiAssistantDialog(
        repository: repository,
        onPostCreated: onPostCreated,
        initialPreset: initialPreset,
      ),
    );
  }

  @override
  State<CommunityAiAssistantDialog> createState() =>
      _CommunityAiAssistantDialogState();
}

class _CommunityAiAssistantDialogState
    extends State<CommunityAiAssistantDialog> {
  late final CommunityRepository _communityRepo =
      widget.repository ?? CommunityRepository();

  AiChartPreset? _selectedPreset;
  bool _analyzing = false;
  int _analysisStep = 0;
  bool _completed = false;
  bool _exporting = false;

  final List<String> _pipelineSteps = <String>[
    'Scanning candlestick structure & price action...',
    'Detecting order blocks, swing points & Fair Value Gaps...',
    'Extracting high-probability Entry, Stop Loss & Take Profits...',
    'Synthesizing risk-to-reward matrix & statistical confidence...',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPreset != null) {
      _selectPreset(widget.initialPreset!);
    } else {
      _selectedPreset = kAiChartPresets.first;
      _completed = true;
    }
  }

  void _selectPreset(AiChartPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _completed = false;
      _analyzing = false;
      _analysisStep = 0;
    });
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _analyzing = true;
      _completed = false;
      _analysisStep = 0;
    });

    for (int i = 0; i < _pipelineSteps.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      setState(() => _analysisStep = i);
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _completed = true;
    });
  }

  // ---------------------------------------------------------------------------
  // 1-Click Export Actions
  // ---------------------------------------------------------------------------

  Future<void> _exportToCommunityPost() async {
    final AiChartPreset setup = _selectedPreset!;
    setState(() => _exporting = true);

    try {
      _communityRepo.createPost(
        body:
            '🤖 **AI Chart Scan [${setup.symbol}]**: Detected ${setup.pattern} on the ${setup.timeframe} timeframe.\n\n${setup.rationale}\n\n#TradeSetup #${setup.symbol.replaceAll(' ', '')} #AITrading',
        author: const CommunityAuthor(
          id: 'usr_current',
          handle: 'alex_vance',
          displayName: 'Alex Vance',
          userRole: UserRole.userAdmin,
          avatarUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
          verified: true,
          followers: 4890,
          following: 512,
          winRate: 71.2,
        ),
        tradeSetup: CommunityTradeSetup(
          ticker: setup.symbol,
          side: setup.direction.toUpperCase(),
          entry: setup.entry.toStringAsFixed(2),
          stopLoss: setup.stopLoss.toStringAsFixed(2),
          target: setup.target1.toStringAsFixed(2),
        ),
        imageUrls: setup.previewUrl.isNotEmpty
            ? <String>[setup.previewUrl]
            : const <String>[],
        tickers: <String>[setup.symbol],
        tags: <String>['AI Setup', setup.symbol, setup.direction],
      );

      if (widget.onPostCreated != null && _communityRepo.feedPosts.isNotEmpty) {
        widget.onPostCreated!(_communityRepo.feedPosts.first);
      }

      if (mounted) {
        UiToast.success(
          context,
          title: 'Shared to Community',
          message: 'Your AI trade setup has been published to the feed!',
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportToNotes() async {
    final AiChartPreset setup = _selectedPreset!;
    setState(() => _exporting = true);

    try {
      final AppNote note = AppNote(
        id: 'note_ai_${DateTime.now().millisecondsSinceEpoch}',
        title: '${setup.symbol} ${setup.pattern} Analysis',
        content:
            '# ${setup.symbol} ${setup.pattern}\n\n'
            '**Direction**: ${setup.direction.toUpperCase()}\n'
            '**Timeframe**: ${setup.timeframe}\n'
            '**AI Confidence**: ${setup.confidence}%\n\n'
            '## Key Levels\n'
            '- **Entry**: ${setup.entry}\n'
            '- **Stop Loss**: ${setup.stopLoss}\n'
            '- **Target 1**: ${setup.target1}\n'
            '- **Target 2**: ${setup.target2}\n'
            '- **Risk/Reward**: 1 : ${setup.rrRatio.toStringAsFixed(2)}\n\n'
            '## Setup Rationale\n'
            '${setup.rationale}\n',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavorite: true,
      );

      await NotesRepositoryScope.repository.create(note);

      if (mounted) {
        UiToast.success(
          context,
          title: 'Saved to Notes',
          message: 'Created technical research note for ${setup.symbol}.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportToJournal() async {
    final AiChartPreset setup = _selectedPreset!;
    setState(() => _exporting = true);

    try {
      final AppTrade trade = AppTrade(
        id: 'trade_ai_${DateTime.now().millisecondsSinceEpoch}',
        ticker: setup.symbol,
        side: setup.direction.toLowerCase() == 'long'
            ? AppSide.long
            : AppSide.short,
        openedAt: DateTime.now(),
        entry: setup.entry,
        exit: null,
        stopLoss: setup.stopLoss,
        target: setup.target1,
        size: 50,
        rMultiple: setup.rrRatio,
        title: '${setup.symbol} ${setup.pattern}',
        content:
            'AI setup logged from automated chart scan. ${setup.pattern} with R:R of 1 : ${setup.rrRatio.toStringAsFixed(2)}.\n\n${setup.rationale}',
        strategy: setup.pattern,
      );

      await JournalRepositoryScope.repository.create(trade);

      if (mounted) {
        UiToast.success(
          context,
          title: 'Logged to Journal',
          message: '${setup.symbol} trade setup added to your active journal.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportToStrategy() async {
    final AiChartPreset setup = _selectedPreset!;
    setState(() => _exporting = true);

    try {
      final AppStrategy strategy = AppStrategy(
        id: 'strat_ai_${DateTime.now().millisecondsSinceEpoch}',
        name: '${setup.symbol} ${setup.pattern} Playbook',
        summary:
            'Automated execution playbook derived from ${setup.pattern} setups.',
        content:
            '## Core Rules\n\n'
            '1. **Trigger Condition**: Wait for ${setup.timeframe} candle close beyond breakout pivot.\n'
            '2. **Risk Invalidation**: Fixed Stop Loss at invalidation pivot ${setup.stopLoss}.\n'
            '3. **Target Scaling**: Scale 50% at ${setup.target1}, trail remainder to ${setup.target2}.\n\n'
            '## Statistical Model\n'
            '- Confidence: ${setup.confidence}%\n'
            '- Minimum R:R: 1 : ${setup.rrRatio.toStringAsFixed(2)}\n',
        status: AppStrategyStatus.draft,
        createdAt: DateTime.now(),
      );

      await StrategiesRepositoryScope.repository.create(strategy);

      if (mounted) {
        UiToast.success(
          context,
          title: 'Playbook Created',
          message: 'Saved "${strategy.name}" to your active strategies.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final AiChartPreset setup = _selectedPreset ?? kAiChartPresets.first;

    return Dialog(
      backgroundColor: theme.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radii.lg),
        side: BorderSide(color: theme.colors.border),
      ),
      insetPadding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.sz(760),
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.colors.border)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                    decoration: BoxDecoration(
                      color: theme.colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(theme.radii.sm),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: context.sz(20),
                      color: theme.colors.primary,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'AI Chart Copilot & Pattern Analyzer',
                          style: context.uiText.subheading.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Drop any chart screenshot to extract entry, stop loss, targets & 1-click export',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiIconButton(
                    icon: Icons.close_rounded,
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Preset selection pill bar
                    Text(
                      'Select Sample Chart or Upload Screenshot:',
                      style: context.uiText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          for (final AiChartPreset preset in kAiChartPresets) ...<Widget>[
                            Padding(
                              padding: EdgeInsets.only(
                                right: context.sp(theme.spacing.xs),
                              ),
                              child: UiButton(
                                label: preset.title,
                                leadingIcon:
                                    preset.direction.toLowerCase() == 'long'
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                variant: _selectedPreset?.id == preset.id
                                    ? UiVariant.primary
                                    : UiVariant.outline,
                                size: UiSize.sm,
                                onPressed: () => _selectPreset(preset),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.md)),

                    // Dropzone
                    UiDropzone(
                      title: 'Drag & drop technical chart screenshot',
                      message: 'Supports TradingView, MT5, Zerodha, Dhan charts',
                      icon: Icons.add_photo_alternate_outlined,
                      height: 120,
                      onFilesDropped: (List<String> files) {
                        _runAnalysis();
                      },
                      onPick: () {
                        _runAnalysis();
                      },
                    ),
                    SizedBox(height: context.sp(theme.spacing.md)),

                    // Analysis progress or detected setup
                    if (_analyzing) ...<Widget>[
                      UiCard(
                        variant: UiCardVariant.surface,
                        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                        child: Column(
                          children: <Widget>[
                            const UiTypingIndicator(),
                            SizedBox(height: context.sp(theme.spacing.sm)),
                            Text(
                              _pipelineSteps[_analysisStep],
                              style: context.uiText.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colors.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: context.sp(theme.spacing.sm)),
                            UiProgressBar(
                              value: (_analysisStep + 1) / _pipelineSteps.length,
                              intent: UiIntent.primary,
                            ),
                          ],
                        ),
                      ),
                    ] else if (_completed) ...<Widget>[
                      // Setup Result Card
                      UiCard(
                        variant: UiCardVariant.elevated,
                        accentColor: setup.direction.toLowerCase() == 'long'
                            ? theme.colors.success
                            : theme.colors.danger,
                        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Top badges row
                            Row(
                              children: <Widget>[
                                UiBadge(
                                  label: setup.symbol,
                                  variant: UiBadgeVariant.solid,
                                  intent: UiIntent.primary,
                                ),
                                SizedBox(width: context.sp(theme.spacing.xs)),
                                UiBadge(
                                  label: setup.timeframe,
                                  variant: UiBadgeVariant.outline,
                                  intent: UiIntent.neutral,
                                ),
                                SizedBox(width: context.sp(theme.spacing.xs)),
                                UiBadge(
                                  label: setup.direction.toUpperCase(),
                                  variant: UiBadgeVariant.soft,
                                  intent: setup.direction.toLowerCase() == 'long'
                                      ? UiIntent.success
                                      : UiIntent.danger,
                                ),
                                const Spacer(),
                                UiBadge(
                                  label: '${setup.confidence}% AI Probability',
                                  icon: Icons.verified_rounded,
                                  variant: UiBadgeVariant.soft,
                                  intent: UiIntent.success,
                                ),
                              ],
                            ),
                            SizedBox(height: context.sp(theme.spacing.sm)),

                            // Pattern name & R:R
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  setup.pattern,
                                  style: context.uiText.heading.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                UiBadge(
                                  label:
                                      '1 : ${setup.rrRatio.toStringAsFixed(2)} R:R',
                                  variant: UiBadgeVariant.solid,
                                  intent: UiIntent.primary,
                                ),
                              ],
                            ),
                            SizedBox(height: context.sp(theme.spacing.xs)),
                            Text(
                              setup.rationale,
                              style: context.uiText.body.copyWith(
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.md)),

                            // Key price levels grid
                            Container(
                              padding: EdgeInsets.all(
                                context.sp(theme.spacing.sm),
                              ),
                              decoration: BoxDecoration(
                                color: theme.colors.surface,
                                borderRadius: BorderRadius.circular(
                                  theme.radii.md,
                                ),
                                border: Border.all(color: theme.colors.border),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _levelItem(
                                      context,
                                      label: 'Entry Trigger',
                                      value: setup.entry.toStringAsFixed(2),
                                      color: theme.colors.foreground,
                                    ),
                                  ),
                                  Expanded(
                                    child: _levelItem(
                                      context,
                                      label: 'Stop Loss',
                                      value: setup.stopLoss.toStringAsFixed(2),
                                      color: theme.colors.danger,
                                    ),
                                  ),
                                  Expanded(
                                    child: _levelItem(
                                      context,
                                      label: 'Take Profit 1',
                                      value: setup.target1.toStringAsFixed(2),
                                      color: theme.colors.success,
                                    ),
                                  ),
                                  Expanded(
                                    child: _levelItem(
                                      context,
                                      label: 'Take Profit 2',
                                      value: setup.target2.toStringAsFixed(2),
                                      color: theme.colors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.md)),

                      // 1-Click Action Hub
                      Text(
                        'Instant 1-Click Exports:',
                        style: context.uiText.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Wrap(
                        spacing: context.sp(theme.spacing.sm),
                        runSpacing: context.sp(theme.spacing.xs),
                        children: <Widget>[
                          UiButton(
                            label: 'Share to Community',
                            leadingIcon: Icons.forum_outlined,
                            variant: UiVariant.primary,
                            size: UiSize.sm,
                            onPressed: _exporting ? null : _exportToCommunityPost,
                          ),
                          UiButton(
                            label: 'Save to Notes',
                            leadingIcon: Icons.note_alt_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: _exporting ? null : _exportToNotes,
                          ),
                          UiButton(
                            label: 'Log to Journal',
                            leadingIcon: Icons.book_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: _exporting ? null : _exportToJournal,
                          ),
                          UiButton(
                            label: 'Create Strategy Playbook',
                            leadingIcon: Icons.menu_book_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: _exporting ? null : _exportToStrategy,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          value,
          style: context.uiText.subheading.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// High-tech, glassmorphic floating command dock for the AI Trade Copilot.
///
/// Features:
/// - Real-time market telemetry ticker (Bullish/Bearish bias, FII flows, Alpha signals).
/// - Multi-action command dock:
///   1. 📊 Scan Chart Vision (Technical pattern & FVG detector)
///   2. ⚡ Alpha Signals Radar (Live institutional setups)
///   3. 💬 Ask Copilot (Institutional Q&A assistant)
///   4. 🧮 Risk Sizer (Capital preservation & lot sizing calculator)
///   5. 🎙️ Audio Brief (AI morning market briefing player)
/// - Interactive Expand / Collapse / Minimize modes with smooth glassmorphism.
/// - Full mobile and desktop responsiveness.
class CommunityAiFloatingBar extends StatefulWidget {
  const CommunityAiFloatingBar({
    super.key,
    this.repository,
    this.onPostCreated,
  });

  final CommunityRepository? repository;
  final ValueChanged<CommunityPost>? onPostCreated;

  @override
  State<CommunityAiFloatingBar> createState() => _CommunityAiFloatingBarState();
}

class _CommunityAiFloatingBarState extends State<CommunityAiFloatingBar> {
  bool _minimized = false;
  int _telemetryIndex = 0;
  Timer? _telemetryTimer;

  static const List<String> _telemetryMessages = <String>[
    '🟢 Nifty Bias: 72% Bullish',
    '⚡ FII Flow: +₹1,420 Cr Inflow',
    '🔥 3 Alpha Breakouts Active',
    '🎯 BankNifty FVG Retest in Play',
  ];

  @override
  void initState() {
    super.initState();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _telemetryIndex = (_telemetryIndex + 1) % _telemetryMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    if (_minimized) {
      return _buildMinimizedPill(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colors.surface.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(theme.radii.pill),
            border: Border.all(
              color: theme.colors.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.colors.primary.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Radiant Glowing AI Icon
              Container(
                padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colors.primary,
                      theme.colors.primary.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: context.sz(15),
                  color: Colors.white,
                ),
              ),

              SizedBox(width: context.sp(theme.spacing.xs)),

              // Title & Rotating Live Telemetry
              InkWell(
                onTap: () => CommunityAiSignalsDialog.show(
                  context,
                  repository: widget.repository,
                  onPostCreated: widget.onPostCreated,
                ),
                borderRadius: BorderRadius.circular(theme.radii.sm),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.xxs)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI Copilot',
                            style: context.uiText.label.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colors.foreground,
                              fontSize: context.fs(12.5),
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          Container(
                            width: context.sz(6),
                            height: context.sz(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _telemetryMessages[_telemetryIndex],
                          key: ValueKey<int>(_telemetryIndex),
                          style: context.uiText.caption.copyWith(
                            fontSize: context.fs(10),
                            color: theme.colors.foregroundMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: context.sp(theme.spacing.sm)),
              Container(
                height: context.sz(22),
                width: 1,
                color: theme.colors.border.withValues(alpha: 0.6),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),

              // Action 1: Scan Chart (Primary action)
              UiButton(
                label: 'Scan Chart',
                leadingIcon: Icons.document_scanner_outlined,
                variant: UiVariant.primary,
                size: UiSize.xs,
                onPressed: () => CommunityAiAssistantDialog.show(
                  context,
                  repository: widget.repository,
                  onPostCreated: widget.onPostCreated,
                ),
              ),

              SizedBox(width: context.sp(theme.spacing.xxs)),

              if (!isMobile) ...[
                // Action 2: Alpha Signals
                UiButton(
                  label: 'Signals (3)',
                  leadingIcon: Icons.local_fire_department_rounded,
                  variant: UiVariant.soft,
                  size: UiSize.xs,
                  onPressed: () => CommunityAiSignalsDialog.show(
                    context,
                    repository: widget.repository,
                    onPostCreated: widget.onPostCreated,
                  ),
                ),

                SizedBox(width: context.sp(theme.spacing.xxs)),

                // Action 3: Ask Copilot
                UiIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Ask AI Copilot',
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  onPressed: () => CommunityAiQuickPromptDialog.show(
                    context,
                    repository: widget.repository,
                    onPostCreated: widget.onPostCreated,
                  ),
                ),

                // Action 4: Risk Sizer
                UiIconButton(
                  icon: Icons.calculate_outlined,
                  tooltip: 'Risk & Position Sizer',
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  onPressed: () => CommunityAiRiskCalcDialog.show(context),
                ),

                // Action 5: Audio Brief
                UiIconButton(
                  icon: Icons.graphic_eq_rounded,
                  tooltip: 'AI Market Audio Brief',
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  onPressed: () => CommunityAiAudioBriefDialog.show(context),
                ),
              ] else ...[
                // Mobile Overflow Menu
                UiDropdownMenu(
                  items: [
                    UiMenuItem(
                      label: 'Alpha Signals (3 Active)',
                      icon: Icons.local_fire_department_rounded,
                      onTap: () => CommunityAiSignalsDialog.show(
                        context,
                        repository: widget.repository,
                        onPostCreated: widget.onPostCreated,
                      ),
                    ),
                    UiMenuItem(
                      label: 'Ask AI Copilot',
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () => CommunityAiQuickPromptDialog.show(
                        context,
                        repository: widget.repository,
                        onPostCreated: widget.onPostCreated,
                      ),
                    ),
                    UiMenuItem(
                      label: 'Position Sizing Calculator',
                      icon: Icons.calculate_outlined,
                      onTap: () => CommunityAiRiskCalcDialog.show(context),
                    ),
                    UiMenuItem(
                      label: 'AI Market Audio Brief',
                      icon: Icons.graphic_eq_rounded,
                      onTap: () => CommunityAiAudioBriefDialog.show(context),
                    ),
                    const UiMenuItem.divider(),
                    UiMenuItem(
                      label: 'Minimize Dock',
                      icon: Icons.unfold_less_rounded,
                      onTap: () => setState(() => _minimized = true),
                    ),
                  ],
                  child: UiIconButton(
                    icon: Icons.more_vert_rounded,
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                  ),
                ),
              ],

              // Minimize Pill Button (Desktop)
              if (!isMobile) ...[
                SizedBox(width: context.sp(theme.spacing.xxs)),
                UiIconButton(
                  icon: Icons.unfold_less_rounded,
                  tooltip: 'Minimize Dock',
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  onPressed: () => setState(() => _minimized = true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedPill(UiTheme theme) {
    return InkWell(
      onTap: () => setState(() => _minimized = false),
      borderRadius: BorderRadius.circular(theme.radii.pill),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colors.surface.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(theme.radii.pill),
              border: Border.all(
                color: theme.colors.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colors.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
                  decoration: BoxDecoration(
                    color: theme.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: context.sz(13),
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'AI Copilot (3 Signals)',
                  style: context.uiText.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colors.foreground,
                    fontSize: context.fs(12),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Icon(
                  Icons.unfold_more_rounded,
                  size: context.sz(14),
                  color: theme.colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Companion Dialog 1: AI Quick Prompt & Institutional Q&A
// ---------------------------------------------------------------------------

class CommunityAiQuickPromptDialog extends StatefulWidget {
  const CommunityAiQuickPromptDialog({
    super.key,
    this.repository,
    this.onPostCreated,
  });

  final CommunityRepository? repository;
  final ValueChanged<CommunityPost>? onPostCreated;

  static Future<void> show(
    BuildContext context, {
    CommunityRepository? repository,
    ValueChanged<CommunityPost>? onPostCreated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CommunityAiQuickPromptDialog(
        repository: repository,
        onPostCreated: onPostCreated,
      ),
    );
  }

  @override
  State<CommunityAiQuickPromptDialog> createState() => _CommunityAiQuickPromptDialogState();
}

class _CommunityAiQuickPromptDialogState extends State<CommunityAiQuickPromptDialog> {
  final TextEditingController _promptCtrl = TextEditingController();
  bool _generating = false;
  String? _generatedResponse;
  String? _selectedPresetPrompt;

  static const List<String> _promptPresets = <String>[
    '📊 Nifty & BankNifty Key Pivot Levels',
    '⚡ High R:R Momentum Breakouts',
    '🏦 Institutional FII Derivative Positioning',
    '🛡️ Max Lot Sizing for ₹15,000 Risk',
    '📉 Option Greeks & Expiry Volatility Skew',
  ];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _runPrompt(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() {
      _generating = true;
      _generatedResponse = null;
      _selectedPresetPrompt = q;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final String synthesized;
    if (q.contains('Pivot Levels') || q.contains('Nifty')) {
      synthesized = '🎯 **NIFTY 50 Institutional Levels**\n'
          '• Current Spot: 24,820 | Trend: Strong Bullish Above VWAP\n'
          '• Critical Support 1: 24,780 (Order Block Mitigation)\n'
          '• Key Resistance: 24,940 - 25,000 (Major Call Open Interest Wall)\n'
          '• Strategy: Accumulate Long on 15m dips towards 24,790 with tight SL at 24,750. Target: 24,960.';
    } else if (q.contains('Breakouts')) {
      synthesized = '🚀 **Top High R:R Momentum Breakouts**\n'
          '1. **RELIANCE**: Long above ₹3,020. Flag breakout with 2.4x volume surge. Target: ₹3,110 (R:R 1:2.8).\n'
          '2. **HDFCBANK**: Consolidating at 50-EMA support. Reversal trigger at ₹1,680. Target: ₹1,735.\n'
          '3. **NVDA**: Ascending triangle compression. Breakout trigger \$128.50. Target: \$139.00.';
    } else if (q.contains('FII')) {
      synthesized = '🏦 **FII & DII Derivative Positioning**\n'
          '• FII Net Long Index Futures: 64.2% (+4,800 contracts today)\n'
          '• Put-Call Ratio (PCR): 1.18 (Bullish Contango)\n'
          '• DII Cash Inflow: +₹1,420 Crores absorbing retail profit booking.\n'
          '• Key takeaway: Institutional smart money remains biased towards upside continuation into weekly expiry.';
    } else if (q.contains('Risk')) {
      synthesized = '🛡️ **Capital Preservation & Position Sizer**\n'
          '• Max Risk: ₹15,000 | Account Equity: ₹5,00,000 (3.0% Risk Limit)\n'
          '• NIFTY Setup: Entry 24,850 | SL 24,780 (70 points at risk)\n'
          '• Nifty Lot Size: 50 | Risk per Lot: 70 * 50 = ₹3,500\n'
          '• Recommended Sizing: **4 Lots (200 qty)** = ₹14,000 Max Loss (Within risk limit!).';
    } else {
      synthesized = '💡 **Institutional Market Synthesis**\n'
          '• Price Action Analysis for: "$q"\n'
          '• Market Bias: Moderately Bullish with positive breadth (68% advances).\n'
          '• Key Rule: Trade pullbacks to key Fair Value Gaps rather than chasing extended breakouts.';
    }

    setState(() {
      _generating = false;
      _generatedResponse = synthesized;
    });
  }

  void _shareToCommunity() {
    if (_generatedResponse == null) return;
    final repo = widget.repository ?? CommunityRepository();
    repo.createPost(
      body: '🤖 **AI Copilot Intelligence**:\n\n$_generatedResponse\n\n#TradeX #AICopilot #TradingThesis',
      author: const CommunityAuthor(
        id: 'usr_current',
        handle: 'alex_vance',
        displayName: 'Alex Vance',
        userRole: UserRole.userAdmin,
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        verified: true,
      ),
      tags: const ['AICopilot', 'MarketAlpha'],
    );
    UiToast.show(
      context,
      title: 'Shared to Feed!',
      message: 'AI intelligence posted to the community feed.',
      intent: UiIntent.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);

    return UiDialog(
      title: 'AI Copilot Institutional Intelligence',
      content: SizedBox(
        width: context.sz(520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select a preset trading query or ask the AI copilot for instant market intelligence:',
              style: context.uiText.caption.copyWith(color: theme.colors.foregroundMuted),
            ),
            SizedBox(height: gap),

            // Preset Chips
            Wrap(
              spacing: gapXs,
              runSpacing: gapXs,
              children: [
                for (final p in _promptPresets)
                  InkWell(
                    onTap: _generating ? null : () => _runPrompt(p),
                    borderRadius: context.radius(theme.radii.pill),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.sm),
                        vertical: context.sp(theme.spacing.xxs),
                      ),
                      decoration: BoxDecoration(
                        color: _selectedPresetPrompt == p
                            ? theme.colors.primary.withValues(alpha: 0.15)
                            : theme.colors.surfaceMuted,
                        borderRadius: context.radius(theme.radii.pill),
                        border: Border.all(
                          color: _selectedPresetPrompt == p ? theme.colors.primary : theme.colors.border,
                        ),
                      ),
                      child: Text(
                        p,
                        style: context.uiText.caption.copyWith(
                          fontSize: context.fs(11),
                          fontWeight: _selectedPresetPrompt == p ? FontWeight.w700 : FontWeight.w500,
                          color: _selectedPresetPrompt == p ? theme.colors.primary : theme.colors.foreground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: gap),

            // Prompt Input
            Row(
              children: [
                Expanded(
                  child: UiInput(
                    controller: _promptCtrl,
                    hintText: 'Ask Copilot anything (e.g. NIFTY call ratio, SL calculation)...',
                    size: UiSize.sm,
                    onSubmitted: _runPrompt,
                  ),
                ),
                SizedBox(width: gapXs),
                UiButton(
                  label: 'Send',
                  leadingIcon: Icons.send_rounded,
                  size: UiSize.sm,
                  loading: _generating,
                  onPressed: () => _runPrompt(_promptCtrl.text),
                ),
              ],
            ),

            // Generating Progress
            if (_generating) ...[
              SizedBox(height: gap),
              const UiProgressBar(
                value: 0.72,
                label: 'Synthesizing market depth & order flow delta...',
              ),
            ],

            // Response Box
            if (_generatedResponse != null) ...[
              SizedBox(height: gap),
              Container(
                padding: EdgeInsets.all(gap),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.sm),
                  border: Border.all(
                    color: theme.colors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: context.sz(14), color: theme.colors.primary),
                        SizedBox(width: gapXs),
                        Text(
                          'Synthesized Intelligence',
                          style: context.uiText.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colors.primary,
                          ),
                        ),
                        const Spacer(),
                        UiButton(
                          label: 'Share to Feed',
                          leadingIcon: Icons.share_rounded,
                          size: UiSize.xs,
                          variant: UiVariant.soft,
                          onPressed: _shareToCommunity,
                        ),
                      ],
                    ),
                    SizedBox(height: gapXs),
                    SelectableText(
                      _generatedResponse!,
                      style: context.uiText.body.copyWith(
                        fontSize: context.fs(12.5),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        UiButton(
          label: 'Close',
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Companion Dialog 2: Live AI Alpha Signals Radar
// ---------------------------------------------------------------------------

class CommunityAiSignalsDialog extends StatelessWidget {
  const CommunityAiSignalsDialog({
    super.key,
    this.repository,
    this.onPostCreated,
  });

  final CommunityRepository? repository;
  final ValueChanged<CommunityPost>? onPostCreated;

  static Future<void> show(
    BuildContext context, {
    CommunityRepository? repository,
    ValueChanged<CommunityPost>? onPostCreated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CommunityAiSignalsDialog(
        repository: repository,
        onPostCreated: onPostCreated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);

    return UiDialog(
      title: 'Live AI Alpha Signals Radar',
      content: SizedBox(
        width: context.sz(560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Real-time institutional trade setups detected across indices and large-cap equities:',
              style: context.uiText.caption.copyWith(color: theme.colors.foregroundMuted),
            ),
            SizedBox(height: gap),

            for (final preset in kAiChartPresets) ...[
              Container(
                margin: EdgeInsets.only(bottom: gapXs),
                padding: EdgeInsets.all(gap),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.sm),
                  border: Border.all(
                    color: preset.direction.toUpperCase() == 'LONG'
                        ? theme.colors.success.withValues(alpha: 0.3)
                        : theme.colors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        UiBadge(
                          label: preset.direction.toUpperCase(),
                          intent: preset.direction.toUpperCase() == 'LONG'
                              ? UiIntent.success
                              : UiIntent.danger,
                          variant: UiBadgeVariant.solid,
                          size: UiSize.xs,
                        ),
                        SizedBox(width: gapXs),
                        Text(
                          preset.symbol,
                          style: context.uiText.label.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colors.foreground,
                          ),
                        ),
                        SizedBox(width: gapXs),
                        Text(
                          '· ${preset.timeframe} · ${preset.pattern}',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                        const Spacer(),
                        UiBadge(
                          label: '${preset.confidence}% Win Rate',
                          intent: UiIntent.primary,
                          variant: UiBadgeVariant.soft,
                          size: UiSize.xs,
                        ),
                      ],
                    ),
                    SizedBox(height: gapXs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Entry: ₹${preset.entry}', style: context.uiText.caption),
                        Text('SL: ₹${preset.stopLoss}', style: context.uiText.caption.copyWith(color: theme.colors.danger)),
                        Text('Target: ₹${preset.target1}', style: context.uiText.caption.copyWith(color: theme.colors.success)),
                        Text('R:R 1:${preset.rrRatio.toStringAsFixed(1)}', style: context.uiText.caption.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    SizedBox(height: gapXs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        UiButton(
                          label: 'Inspect in Vision',
                          leadingIcon: Icons.document_scanner_outlined,
                          size: UiSize.xs,
                          variant: UiVariant.outline,
                          onPressed: () {
                            Navigator.of(context).pop();
                            CommunityAiAssistantDialog.show(
                              context,
                              initialPreset: preset,
                              repository: repository,
                              onPostCreated: onPostCreated,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        UiButton(
          label: 'Close',
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Companion Dialog 3: Position Sizing & Risk Calculator
// ---------------------------------------------------------------------------

class CommunityAiRiskCalcDialog extends StatefulWidget {
  const CommunityAiRiskCalcDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const CommunityAiRiskCalcDialog(),
    );
  }

  @override
  State<CommunityAiRiskCalcDialog> createState() => _CommunityAiRiskCalcDialogState();
}

class _CommunityAiRiskCalcDialogState extends State<CommunityAiRiskCalcDialog> {
  final TextEditingController _capitalCtrl = TextEditingController(text: '500000');
  final TextEditingController _entryCtrl = TextEditingController(text: '24850');
  final TextEditingController _slCtrl = TextEditingController(text: '24780');
  final TextEditingController _lotSizeCtrl = TextEditingController(text: '50');
  double _riskPercent = 1.5;

  @override
  void dispose() {
    _capitalCtrl.dispose();
    _entryCtrl.dispose();
    _slCtrl.dispose();
    _lotSizeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);

    final capital = double.tryParse(_capitalCtrl.text) ?? 500000;
    final entry = double.tryParse(_entryCtrl.text) ?? 24850;
    final sl = double.tryParse(_slCtrl.text) ?? 24780;
    final lotSize = int.tryParse(_lotSizeCtrl.text) ?? 50;

    final maxLossAllowed = capital * (_riskPercent / 100);
    final pointsAtRisk = (entry - sl).abs();
    final riskPerLot = pointsAtRisk * lotSize;
    final recommendedLots = riskPerLot > 0 ? (maxLossAllowed / riskPerLot).floor() : 0;
    final totalQty = recommendedLots * lotSize;
    final totalActualRisk = totalQty * pointsAtRisk;

    return UiDialog(
      title: 'Institutional Position Sizer & Risk Guard',
      content: SizedBox(
        width: context.sz(460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Never risk more than your capital preservation rules allow:',
              style: context.uiText.caption.copyWith(color: theme.colors.foregroundMuted),
            ),
            SizedBox(height: gap),

            // Capital Input
            UiInput(
              controller: _capitalCtrl,
              label: 'Account Capital (₹)',
              prefixText: '₹',
              size: UiSize.sm,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: gapXs),

            // Risk % Selection
            Row(
              children: [
                Text('Risk Limit: ', style: context.uiText.caption),
                for (final r in [1.0, 1.5, 2.0, 3.0]) ...[
                  InkWell(
                    onTap: () => setState(() => _riskPercent = r),
                    borderRadius: context.radius(theme.radii.pill),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.xs),
                        vertical: 2,
                      ),
                      margin: EdgeInsets.only(right: gapXs),
                      decoration: BoxDecoration(
                        color: _riskPercent == r
                            ? theme.colors.primary.withValues(alpha: 0.15)
                            : theme.colors.surfaceMuted,
                        borderRadius: context.radius(theme.radii.pill),
                        border: Border.all(
                          color: _riskPercent == r ? theme.colors.primary : theme.colors.border,
                        ),
                      ),
                      child: Text(
                        '$r%',
                        style: context.uiText.caption.copyWith(
                          fontSize: context.fs(11),
                          fontWeight: _riskPercent == r ? FontWeight.w700 : FontWeight.w500,
                          color: _riskPercent == r ? theme.colors.primary : theme.colors.foreground,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: gap),

            // Entry + SL
            Row(
              children: [
                Expanded(
                  child: UiInput(
                    controller: _entryCtrl,
                    label: 'Entry Price',
                    size: UiSize.sm,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: gapXs),
                Expanded(
                  child: UiInput(
                    controller: _slCtrl,
                    label: 'Stop Loss',
                    size: UiSize.sm,
                    intent: UiIntent.bearish,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: gapXs),
                Expanded(
                  child: UiInput(
                    controller: _lotSizeCtrl,
                    label: 'Lot Size',
                    size: UiSize.sm,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            SizedBox(height: gap),

            // Calculated Output Card
            Container(
              padding: EdgeInsets.all(gap),
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.sm),
                border: Border.all(
                  color: theme.colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Max Risk Budget:', style: context.uiText.caption),
                      Text('₹${maxLossAllowed.toStringAsFixed(0)} ($_riskPercent%)', style: context.uiText.bodyStrong.copyWith(color: theme.colors.danger)),
                    ],
                  ),
                  SizedBox(height: gapXs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Stop Loss Distance:', style: context.uiText.caption),
                      Text('${pointsAtRisk.toStringAsFixed(1)} points', style: context.uiText.bodyStrong),
                    ],
                  ),
                  SizedBox(height: gapXs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recommended Lots:', style: context.uiText.label.copyWith(fontWeight: FontWeight.w700)),
                      Text('$recommendedLots Lots ($totalQty Qty)', style: context.uiText.subheading.copyWith(color: theme.colors.primary, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  SizedBox(height: gapXs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Actual Risk Exposure:', style: context.uiText.caption),
                      Text('₹${totalActualRisk.toStringAsFixed(0)}', style: context.uiText.caption.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        UiButton(
          label: 'Close',
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Companion Dialog 4: AI Market Morning Audio Briefing
// ---------------------------------------------------------------------------

class CommunityAiAudioBriefDialog extends StatefulWidget {
  const CommunityAiAudioBriefDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const CommunityAiAudioBriefDialog(),
    );
  }

  @override
  State<CommunityAiAudioBriefDialog> createState() => _CommunityAiAudioBriefDialogState();
}

class _CommunityAiAudioBriefDialogState extends State<CommunityAiAudioBriefDialog> {
  bool _isPlaying = false;
  double _speed = 1.0;
  double _progress = 0.25;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);

    return UiDialog(
      title: 'AI Market Audio Briefing',
      content: SizedBox(
        width: context.sz(460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UiBadge(label: 'TODAY 08:30 AM', intent: UiIntent.primary, size: UiSize.xs),
                SizedBox(width: gapXs),
                Text(
                  'Institutional Pre-Market Synthesis',
                  style: context.uiText.caption.copyWith(color: theme.colors.foregroundMuted),
                ),
              ],
            ),
            SizedBox(height: gap),

            // Soundwave Visualizer
            Container(
              height: context.sz(60),
              padding: EdgeInsets.symmetric(horizontal: gap),
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.sm),
                border: Border.all(color: theme.colors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(24, (index) {
                  final double h = _isPlaying
                      ? ((index * 7 + 13) % 40 + 12).toDouble()
                      : ((index * 3) % 25 + 8).toDouble();
                  return Container(
                    width: context.sz(3),
                    height: context.sz(h),
                    decoration: BoxDecoration(
                      color: index < 6 ? theme.colors.primary : theme.colors.foregroundMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),

            SizedBox(height: gapXs),

            // Progress slider
            UiSlider(
              value: _progress,
              min: 0,
              max: 1,
              onChanged: (v) => setState(() => _progress = v),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('01:08', style: context.uiText.caption),
                Text('04:30', style: context.uiText.caption),
              ],
            ),

            SizedBox(height: gap),

            // Player Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                UiIconButton(
                  icon: Icons.replay_10_rounded,
                  size: UiSize.sm,
                  variant: UiVariant.ghost,
                  onPressed: () => setState(() => _progress = (_progress - 0.05).clamp(0.0, 1.0)),
                ),
                SizedBox(width: gap),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: UiIconButton(
                    icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: UiSize.md,
                    variant: UiVariant.ghost,
                    onPressed: () => setState(() => _isPlaying = !_isPlaying),
                  ),
                ),
                SizedBox(width: gap),
                UiIconButton(
                  icon: Icons.forward_10_rounded,
                  size: UiSize.sm,
                  variant: UiVariant.ghost,
                  onPressed: () => setState(() => _progress = (_progress + 0.05).clamp(0.0, 1.0)),
                ),
                SizedBox(width: gap),
                UiButton(
                  label: '${_speed}x',
                  size: UiSize.xs,
                  variant: UiVariant.soft,
                  onPressed: () {
                    setState(() {
                      if (_speed == 1.0) {
                        _speed = 1.25;
                      } else if (_speed == 1.25) {
                        _speed = 1.5;
                      } else {
                        _speed = 1.0;
                      }
                    });
                  },
                ),
              ],
            ),

            SizedBox(height: gap),
            UiDivider(spacing: gapXs),
            SizedBox(height: gapXs),

            Text(
              'Topics Covered:',
              style: context.uiText.label.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: gapXs),
            Text(
              '• 00:00 - Global Equity Contango & GIFT Nifty Gap-Up Bias\n'
              '• 01:15 - Major Call & Put OI Resistance at 25,000 Strike\n'
              '• 02:40 - Sector Momentum: Banking & Metals Relative Strength\n'
              '• 03:50 - Top 3 Asymmetric Setups for Today\'s Session',
              style: context.uiText.caption.copyWith(
                height: 1.5,
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
      actions: [
        UiButton(
          label: 'Close',
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

