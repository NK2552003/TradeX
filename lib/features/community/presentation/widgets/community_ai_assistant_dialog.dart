import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_assistant_overlay_sheet.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/core/config/supabase_config.dart';
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

/// Resolves the authenticated user author for any AI → community share.
CommunityAuthor _resolveCurrentAuthor(CommunityRepository repo) {
  if (repo.currentAuthor.id.isNotEmpty &&
      repo.currentAuthor.id != 'usr_current') {
    return repo.currentAuthor;
  }
  final user = SupabaseConfig.client?.auth.currentUser;
  if (user != null) {
    final meta = user.userMetadata;
    return CommunityAuthor(
      id: user.id,
      handle:
          (meta?['handle'] ?? user.email?.split('@').first ?? 'trader')
              as String,
      displayName:
          (meta?['display_name'] ?? meta?['full_name'] ?? 'Trader') as String,
      avatarUrl: meta?['avatar_url'] as String?,
      userRole: UserRole.customer,
      verified: false,
    );
  }
  return repo.currentAuthor;
}

/// AI persona / model flavour selectable in the conversational copilot. Each
/// persona changes the opening line and the emphasis appended to answers so the
/// same synthesized intelligence reads through a different analytical lens.
enum _AiPersona {
  momentumScalper,
  swingStrategist,
  macroEconomist,
  optionsQuant,
}

extension _AiPersonaX on _AiPersona {
  String get label => switch (this) {
    _AiPersona.momentumScalper => 'Momentum Scalper',
    _AiPersona.swingStrategist => 'Swing Strategist',
    _AiPersona.macroEconomist => 'Macro Economist',
    _AiPersona.optionsQuant => 'Options Quant',
  };

  String get shortLabel => switch (this) {
    _AiPersona.momentumScalper => 'Scalper',
    _AiPersona.swingStrategist => 'Swing',
    _AiPersona.macroEconomist => 'Macro',
    _AiPersona.optionsQuant => 'Quant',
  };

  IconData get icon => switch (this) {
    _AiPersona.momentumScalper => Icons.bolt_rounded,
    _AiPersona.swingStrategist => Icons.timeline_rounded,
    _AiPersona.macroEconomist => Icons.public_rounded,
    _AiPersona.optionsQuant => Icons.functions_rounded,
  };

  /// Opening line prefixed to every answer for this persona.
  String get opener => switch (this) {
    _AiPersona.momentumScalper =>
      '⚡ *Scalper lens — intraday momentum & order flow:*',
    _AiPersona.swingStrategist =>
      '📈 *Swing lens — multi-day structure & positioning:*',
    _AiPersona.macroEconomist =>
      '🌐 *Macro lens — liquidity, rates & cross-asset flow:*',
    _AiPersona.optionsQuant => '🧮 *Quant lens — volatility surface & Greeks:*',
  };

  /// Emphasis note appended to every answer for this persona.
  String get emphasis => switch (this) {
    _AiPersona.momentumScalper =>
      '🎯 Scalper note: only trigger on a confirmed break-and-retest; kill the idea if the 1m momentum stalls.',
    _AiPersona.swingStrategist =>
      '🎯 Swing note: scale in against the higher-timeframe demand and hold for the measured move, not the first target.',
    _AiPersona.macroEconomist =>
      '🎯 Macro note: size down into high-impact prints; the tape follows liquidity, not the narrative.',
    _AiPersona.optionsQuant =>
      '🎯 Quant note: express this via defined-risk spreads while IV rank is elevated to stay theta-neutral.',
  };
}

// ---------------------------------------------------------------------------
// Deepened-analysis value types (all derived deterministically from a preset)
// ---------------------------------------------------------------------------

/// A single weighted confluence factor in the analyzer's transparency panel.
@immutable
class _Confluence {
  const _Confluence(this.label, this.weight);
  final String label;

  /// Percentage contribution to the overall conviction score.
  final int weight;
}

/// Directional bias for a single timeframe in the multi-timeframe grid.
enum _TfBias { bullish, bearish, neutral }

/// Simulated historical-edge statistics for a detected setup.
@immutable
class _BacktestEdge {
  const _BacktestEdge({
    required this.winRate,
    required this.avgR,
    required this.sample,
    required this.profitFactor,
    required this.equity,
  });

  final double winRate;
  final double avgR;
  final int sample;
  final double profitFactor;
  final List<double> equity;
}

/// A single message in the conversational copilot thread.
@immutable
class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.persona,
    this.followUps = const <String>[],
  });

  final String text;
  final bool isUser;

  /// Persona that authored an AI message (null for user messages).
  final _AiPersona? persona;

  /// Suggested follow-up prompts rendered under the latest AI answer.
  final List<String> followUps;
}

/// A ticker discussed inside the community, used by the Market Pulse dialog.
@immutable
class _PulseTicker {
  const _PulseTicker(this.symbol, this.bullishPct, this.mentions);
  final String symbol;

  /// Share of mentions that are bullish (0–100).
  final int bullishPct;
  final int mentions;
}

/// A sector tile for the Market Pulse heatmap.
@immutable
class _PulseSector {
  const _PulseSector(this.name, this.changePct);
  final String name;
  final double changePct;
}

/// Tiny hand-drawn equity curve used inside the backtest edge card.
class _EquitySparkline extends StatelessWidget {
  const _EquitySparkline({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _EquitySparklinePainter(
        points: points,
        color: color,
        fill: color.withValues(alpha: 0.14),
      ),
    );
  }
}

class _EquitySparklinePainter extends CustomPainter {
  _EquitySparklinePainter({
    required this.points,
    required this.color,
    required this.fill,
  });

  final List<double> points;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    double minV = points.first;
    double maxV = points.first;
    for (final double p in points) {
      if (p < minV) minV = p;
      if (p > maxV) maxV = p;
    }
    final double span = (maxV - minV) <= 0 ? 1 : (maxV - minV);
    final double dx = size.width / (points.length - 1);
    Offset at(int i) =>
        Offset(i * dx, size.height - ((points[i] - minV) / span) * size.height);

    final Path line = Path()..moveTo(at(0).dx, at(0).dy);
    for (int i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final Path area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fill,
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Zero baseline.
    final double zeroY = size.height - ((0 - minV) / span) * size.height;
    if (zeroY >= 0 && zeroY <= size.height) {
      canvas.drawLine(
        Offset(0, zeroY),
        Offset(size.width, zeroY),
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..strokeWidth = 1,
      );
    }

    // End marker dot.
    canvas.drawCircle(at(points.length - 1), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EquitySparklinePainter old) =>
      old.points != points || old.color != color;
}

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
    final String? prompt = initialPreset != null
        ? 'Analyze setup for ${initialPreset.symbol}: ${initialPreset.pattern} (${initialPreset.direction}) with Entry: ${initialPreset.entry}, SL: ${initialPreset.stopLoss}, Target: ${initialPreset.target1}. Rationale: ${initialPreset.rationale}'
        : null;

    return AiAssistantOverlaySheet.show(
      context,
      repository: AiAssistantRepositoryScope.repository,
      initialPrompt: prompt,
      contextTitle: initialPreset != null
          ? '${initialPreset.symbol} (${initialPreset.pattern})'
          : 'Community Market Intelligence',
      contextSubtitle: initialPreset != null
          ? 'Confidence: ${initialPreset.confidence}% • R:R: ${initialPreset.rrRatio.toStringAsFixed(1)}'
          : 'Realtime Sentiment & Technical Flow',
      contextIcon: Icons.auto_awesome_rounded,
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
  bool _confluenceExpanded = true;
  final List<String> _armedAlerts = <String>[];

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
        author: _resolveCurrentAuthor(_communityRepo),
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
        tags: <String>['AI Setup', setup.direction],
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
        id: const Uuid().v4(),
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
        id: const Uuid().v4(),
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
        id: const Uuid().v4(),
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
    final bool isMobile = context.uiRes.isMobile;
    final AiChartPreset setup = _selectedPreset ?? kAiChartPresets.first;

    return Dialog(
      backgroundColor: theme.colors.surface,
      alignment: isMobile ? Alignment.bottomCenter : Alignment.center,
      shape: RoundedRectangleBorder(
        borderRadius: isMobile
            ? BorderRadius.vertical(
                top: Radius.circular(context.sz(20)),
                bottom: Radius.zero,
              )
            : BorderRadius.circular(theme.radii.lg),
        side: BorderSide(color: theme.colors.border),
      ),
      insetPadding: isMobile
          ? EdgeInsets.only(top: context.sz(48))
          : EdgeInsets.all(context.sp(theme.spacing.md)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : context.sz(760),
          maxHeight:
              MediaQuery.sizeOf(context).height * (isMobile ? 0.92 : 0.88),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Drawer Drag Handle on Mobile
            if (isMobile) ...<Widget>[
              Center(
                child: Container(
                  width: context.sz(36),
                  height: context.sz(4),
                  margin: EdgeInsets.only(
                    top: context.sp(theme.spacing.xs),
                    bottom: context.sp(theme.spacing.xxs),
                  ),
                  decoration: BoxDecoration(
                    color: theme.colors.border.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(context.sz(2)),
                  ),
                ),
              ),
            ],

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
                          for (final AiChartPreset preset
                              in kAiChartPresets) ...<Widget>[
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
                      message:
                          'Supports TradingView, MT5, Zerodha, Dhan charts',
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
                              value:
                                  (_analysisStep + 1) / _pipelineSteps.length,
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
                                  intent:
                                      setup.direction.toLowerCase() == 'long'
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

                            // Annotated chart preview with Entry/Stop/Target overlays
                            _buildAnnotatedPreview(context, setup),
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

                      // Model transparency: confluence weight breakdown
                      _buildConfluenceSection(context, setup),
                      SizedBox(height: context.sp(theme.spacing.md)),

                      // Multi-timeframe confluence grid
                      _buildTimeframeSection(context, setup),
                      SizedBox(height: context.sp(theme.spacing.md)),

                      // Simulated backtest / historical edge
                      _buildBacktestSection(context, setup),
                      SizedBox(height: context.sp(theme.spacing.md)),

                      // Simulated price alerts
                      _buildAlertSection(context, setup),
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
                            onPressed: _exporting
                                ? null
                                : _exportToCommunityPost,
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

  // ---------------------------------------------------------------------------
  // Deepened analysis (annotated preview, confluence, MTF, backtest, alerts)
  // ---------------------------------------------------------------------------

  Widget _buildAnnotatedPreview(BuildContext context, AiChartPreset s) {
    final UiTheme theme = context.ui;
    final double h = context.sz(190);
    final List<double> prices = <double>[
      s.entry,
      s.stopLoss,
      s.target1,
      s.target2,
    ];
    final double maxP = prices.reduce(math.max);
    final double minP = prices.reduce(math.min);
    final double span = (maxP - minP) <= 0 ? 1 : (maxP - minP);
    double yFor(double price) => ((maxP - price) / span).clamp(0.05, 0.94);

    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radii.md),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.network(
              s.previewUrl,
              fit: BoxFit.cover,
              loadingBuilder:
                  (BuildContext ctx, Widget child, ImageChunkEvent? progress) {
                    if (progress == null) return child;
                    return _previewFallback(context, loading: true);
                  },
              errorBuilder:
                  (BuildContext ctx, Object error, StackTrace? stack) =>
                      _previewFallback(context),
            ),
            // Legibility scrim for the overlays.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
            _priceMarker(
              context,
              height: h,
              yFraction: yFor(s.target1),
              color: theme.colors.success,
              label: 'TP ${s.target1.toStringAsFixed(2)}',
            ),
            _priceMarker(
              context,
              height: h,
              yFraction: yFor(s.entry),
              color: Colors.white,
              label: 'Entry ${s.entry.toStringAsFixed(2)}',
            ),
            _priceMarker(
              context,
              height: h,
              yFraction: yFor(s.stopLoss),
              color: theme.colors.danger,
              label: 'SL ${s.stopLoss.toStringAsFixed(2)}',
            ),
            // Pattern name pill.
            Positioned(
              top: context.sp(theme.spacing.xs),
              left: context.sp(theme.spacing.xs),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                  vertical: context.sp(theme.spacing.xxs),
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: context.radius(theme.radii.sm),
                ),
                child: Text(
                  s.pattern,
                  style: context.uiText.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(10.5),
                  ),
                ),
              ),
            ),
            // Confidence chip.
            Positioned(
              top: context.sp(theme.spacing.xs),
              right: context.sp(theme.spacing.xs),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                  vertical: context.sp(theme.spacing.xxs),
                ),
                decoration: BoxDecoration(
                  color: theme.colors.primary,
                  borderRadius: context.radius(theme.radii.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.auto_awesome,
                      size: context.sz(11),
                      color: theme.colors.onPrimary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      '${s.confidence}%',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: context.fs(10.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceMarker(
    BuildContext context, {
    required double height,
    required double yFraction,
    required Color color,
    required String label,
  }) {
    final UiTheme theme = context.ui;
    final Color labelText =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Positioned(
      left: 0,
      right: 0,
      top: yFraction * height,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(height: 1.5, color: color.withValues(alpha: 0.92)),
          ),
          Container(
            margin: EdgeInsets.only(right: context.sp(theme.spacing.xs)),
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xs),
              vertical: context.sp(theme.spacing.xxs),
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: context.radius(theme.radii.sm),
            ),
            child: Text(
              label,
              style: context.uiText.caption.copyWith(
                color: labelText,
                fontWeight: FontWeight.w700,
                fontSize: context.fs(9.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewFallback(BuildContext context, {bool loading = false}) {
    final UiTheme theme = context.ui;
    return ColoredBox(
      color: theme.colors.surfaceMuted,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading)
              SizedBox(
                width: context.sz(22),
                height: context.sz(22),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colors.primary,
                ),
              )
            else
              Icon(
                Icons.candlestick_chart_rounded,
                size: context.sz(30),
                color: theme.colors.foregroundMuted,
              ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              loading ? 'Loading chart…' : 'Chart preview unavailable',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Confluence> _confluencesFor(AiChartPreset s) {
    final bool long = s.direction.toLowerCase() == 'long';
    return <_Confluence>[
      _Confluence(long ? 'VWAP reclaim & hold' : 'VWAP rejection', 18),
      _Confluence(long ? 'Bullish market-structure shift' : 'Bearish MSS', 15),
      const _Confluence('Volume delta confirmation', 12),
      const _Confluence('HTF trend alignment', 11),
      _Confluence(long ? 'Demand block mitigation' : 'Supply block tap', 9),
      const _Confluence('Momentum / RSI divergence', 7),
    ];
  }

  Widget _buildConfluenceSection(BuildContext context, AiChartPreset s) {
    final UiTheme theme = context.ui;
    final List<_Confluence> items = _confluencesFor(s);
    final int maxW = items.map((_Confluence e) => e.weight).reduce(math.max);
    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiInteractive(
            onTap: () =>
                setState(() => _confluenceExpanded = !_confluenceExpanded),
            borderRadius: context.radius(theme.radii.sm),
            builder: (BuildContext ctx, UiInteractiveState st) => Row(
              children: <Widget>[
                Icon(
                  Icons.insights_rounded,
                  size: context.sz(16),
                  color: theme.colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    'Why the AI is confident — confluence breakdown',
                    style: context.uiText.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                UiBadge(
                  label: '${items.length} factors',
                  variant: UiBadgeVariant.soft,
                  intent: UiIntent.primary,
                  size: UiSize.xs,
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
                Icon(
                  _confluenceExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: context.sz(18),
                  color: theme.colors.foregroundMuted,
                ),
              ],
            ),
          ),
          if (_confluenceExpanded) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            for (final _Confluence c in items) ...<Widget>[
              _weightRow(
                context,
                label: c.label,
                weight: c.weight,
                maxWeight: maxW,
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
            ],
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: theme.colors.danger.withValues(alpha: 0.08),
                borderRadius: context.radius(theme.radii.sm),
                border: Border.all(
                  color: theme.colors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.gpp_maybe_outlined,
                    size: context.sz(15),
                    color: theme.colors.danger,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Expanded(
                    child: Text(
                      'Invalidation: a ${s.timeframe} close beyond ${s.stopLoss.toStringAsFixed(2)} negates the thesis and voids the remaining confluence.',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weightRow(
    BuildContext context, {
    required String label,
    required int weight,
    required int maxWeight,
  }) {
    final UiTheme theme = context.ui;
    return Row(
      children: <Widget>[
        SizedBox(
          width: context.sz(150),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foreground,
            ),
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.sm)),
        Expanded(
          child: UiProgressBar(
            value: maxWeight <= 0 ? 0 : weight / maxWeight,
            showValue: false,
            intent: UiIntent.primary,
            thickness: 6,
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.sm)),
        Text(
          '+$weight%',
          style: context.uiText.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colors.primary,
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, _TfBias>> _timeframeBiasFor(AiChartPreset s) {
    final _TfBias primary = s.direction.toLowerCase() == 'long'
        ? _TfBias.bullish
        : _TfBias.bearish;
    const List<String> tfs = <String>['5m', '15m', '1h', '1D'];
    return <MapEntry<String, _TfBias>>[
      for (int i = 0; i < tfs.length; i++)
        MapEntry<String, _TfBias>(
          tfs[i],
          // The lowest timeframe is the noisiest: only a very high-confidence
          // scan reads it as aligned, otherwise it stays neutral.
          (i == 0 && s.confidence < 92) ? _TfBias.neutral : primary,
        ),
    ];
  }

  Widget _buildTimeframeSection(BuildContext context, AiChartPreset s) {
    final UiTheme theme = context.ui;
    final List<MapEntry<String, _TfBias>> biases = _timeframeBiasFor(s);
    final _TfBias primary = s.direction.toLowerCase() == 'long'
        ? _TfBias.bullish
        : _TfBias.bearish;
    final int aligned = biases
        .where((MapEntry<String, _TfBias> e) => e.value == primary)
        .length;
    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.layers_rounded,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                'Multi-timeframe confluence',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              for (int i = 0; i < biases.length; i++) ...<Widget>[
                Expanded(
                  child: _tfChip(context, biases[i].key, biases[i].value),
                ),
                if (i != biases.length - 1)
                  SizedBox(width: context.sp(theme.spacing.xs)),
              ],
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              Icon(
                Icons.check_circle_rounded,
                size: context.sz(14),
                color: theme.colors.success,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Expanded(
                child: Text(
                  '$aligned of ${biases.length} timeframes aligned with the ${s.direction} thesis',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tfChip(BuildContext context, String tf, _TfBias bias) {
    final UiTheme theme = context.ui;
    final Color color = switch (bias) {
      _TfBias.bullish => theme.colors.success,
      _TfBias.bearish => theme.colors.danger,
      _TfBias.neutral => theme.colors.foregroundMuted,
    };
    final String text = switch (bias) {
      _TfBias.bullish => 'Bullish',
      _TfBias.bearish => 'Bearish',
      _TfBias.neutral => 'Neutral',
    };
    final IconData icon = switch (bias) {
      _TfBias.bullish => Icons.trending_up_rounded,
      _TfBias.bearish => Icons.trending_down_rounded,
      _TfBias.neutral => Icons.trending_flat_rounded,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: context.sp(theme.spacing.xs),
        horizontal: context.sp(theme.spacing.xxs),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: context.radius(theme.radii.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            tf,
            style: context.uiText.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colors.foreground,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Icon(icon, size: context.sz(15), color: color),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: context.fs(10),
            ),
          ),
        ],
      ),
    );
  }

  _BacktestEdge _edgeFor(AiChartPreset s) {
    final double winRate = (40 + s.confidence * 0.45).clamp(50, 88);
    final double avgR = (s.rrRatio * 0.55 + s.confidence / 400).clamp(0.4, 5);
    final int sample = 60 + s.confidence;
    final double lossRate = (100 - winRate) / 100;
    final double profitFactor = lossRate <= 0
        ? 6.0
        : ((winRate / 100) * avgR) / lossRate;
    return _BacktestEdge(
      winRate: winRate,
      avgR: avgR,
      sample: sample,
      profitFactor: profitFactor.clamp(1.1, 3.6),
      equity: _equityCurve(s, winRate, avgR),
    );
  }

  List<double> _equityCurve(AiChartPreset s, double winRate, double avgR) {
    final List<double> pts = <double>[0];
    double v = 0;
    for (int i = 1; i <= 24; i++) {
      final double wobble = math.sin(i * 0.9 + s.confidence) * 0.5;
      final double drift = (winRate / 100 - 0.42) * avgR * 1.4;
      v += drift + wobble;
      pts.add(double.parse(v.toStringAsFixed(3)));
    }
    return pts;
  }

  Widget _buildBacktestSection(BuildContext context, AiChartPreset s) {
    final UiTheme theme = context.ui;
    final _BacktestEdge edge = _edgeFor(s);
    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.history_rounded,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Text(
                  'Simulated historical edge',
                  style: context.uiText.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const UiBadge(
                label: 'Backtest',
                variant: UiBadgeVariant.outline,
                intent: UiIntent.neutral,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Container(
            decoration: BoxDecoration(
              borderRadius: context.radius(theme.radii.md),
              border: Border.all(color: theme.colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: UiStatStrip(
              columns: 2,
              stats: <UiStat>[
                UiStat(
                  label: 'Win Rate',
                  value: '${edge.winRate.toStringAsFixed(1)}%',
                  intent: UiIntent.success,
                  icon: Icons.emoji_events_outlined,
                ),
                UiStat(
                  label: 'Avg R',
                  value: '${edge.avgR.toStringAsFixed(2)}R',
                  intent: UiIntent.primary,
                ),
                UiStat(
                  label: 'Sample',
                  value: '${edge.sample}',
                  hint: 'trades · 12-month',
                ),
                UiStat(
                  label: 'Profit Factor',
                  value: edge.profitFactor.toStringAsFixed(2),
                  intent: UiIntent.info,
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              Text(
                'Equity curve',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${edge.sample} trades · compounded R',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundSubtle,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          SizedBox(
            height: context.sz(56),
            child: _EquitySparkline(
              points: edge.equity,
              color: theme.colors.success,
            ),
          ),
        ],
      ),
    );
  }

  void _armAlert(BuildContext context, AiChartPreset s) {
    final String label = '${s.symbol} @ ${s.entry.toStringAsFixed(2)}';
    if (!_armedAlerts.contains(label)) {
      setState(() => _armedAlerts.add(label));
    }
    UiToast.success(
      context,
      title: 'Alert armed',
      message: 'Alert armed at ${s.entry.toStringAsFixed(2)} for ${s.symbol}.',
    );
  }

  Widget _buildAlertSection(BuildContext context, AiChartPreset s) {
    final UiTheme theme = context.ui;
    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.notifications_active_outlined,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Text(
                  'Price alerts',
                  style: context.uiText.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              UiButton(
                label: 'Set Price Alert',
                leadingIcon: Icons.add_alert_outlined,
                size: UiSize.xs,
                variant: UiVariant.soft,
                onPressed: () => _armAlert(context, s),
              ),
            ],
          ),
          if (_armedAlerts.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                for (final String a in _armedAlerts)
                  UiBadge(
                    label: a,
                    icon: Icons.notifications_active_rounded,
                    intent: UiIntent.warning,
                    variant: UiBadgeVariant.soft,
                    onRemove: () => setState(() => _armedAlerts.remove(a)),
                  ),
              ],
            ),
          ] else ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              'No alerts armed yet. Arm one at the AI entry trigger to get pinged on the retest.',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
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
    this.onCompose,
    this.showCompose = false,
  });

  final CommunityRepository? repository;
  final ValueChanged<CommunityPost>? onPostCreated;
  final VoidCallback? onCompose;
  final bool showCompose;

  @override
  State<CommunityAiFloatingBar> createState() => _CommunityAiFloatingBarState();
}

class _CommunityAiFloatingBarState extends State<CommunityAiFloatingBar> {
  int _telemetryIndex = 0;
  Timer? _telemetryTimer;
  bool _isAiHovered = false;
  bool _isAiPressed = false;
  bool _isComposeHovered = false;
  bool _isComposePressed = false;
  bool _isOpen = false;

  static const List<String> _telemetryMessages = <String>[
    'Review a trading thesis',
    'Explore a setup and its risks',
    'Discuss market research',
    'Review your trading process',
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

  void _openOverlay(BuildContext context) {
    if (_isOpen) return;
    setState(() => _isOpen = true);

    AiAssistantOverlaySheet.show(
      context,
      repository: AiAssistantRepositoryScope.repository,
      contextTitle: 'Community Market Intelligence',
      contextSubtitle: _telemetryMessages[_telemetryIndex],
      contextIcon: Icons.auto_awesome_rounded,
    ).then((_) {
      if (mounted) {
        setState(() => _isOpen = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool hasCompose = widget.onCompose != null && widget.showCompose;

    // Combined Dual-Action Column Dock (Mobile Feed)
    if (hasCompose) {
      final double dockWidth = context.sz(44);
      final double buttonHeight = context.sz(44);

      return Container(
        width: dockWidth,
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: BorderRadius.circular(theme.radii.pill),
          border: Border.all(color: theme.colors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 1. AI Action Segment (Top)
            Tooltip(
              message:
                  'alphajournal AI Terminal (${_telemetryMessages[_telemetryIndex]})',
              child: MouseRegion(
                onEnter: (_) => setState(() => _isAiHovered = true),
                onExit: (_) => setState(() => _isAiHovered = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _isAiPressed = true),
                  onTapUp: (_) {
                    setState(() => _isAiPressed = false);
                    _openOverlay(context);
                  },
                  onTapCancel: () => setState(() => _isAiPressed = false),
                  child: AnimatedScale(
                    scale: _isAiPressed ? 0.90 : (_isAiHovered ? 1.06 : 1.0),
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: dockWidth,
                      height: buttonHeight,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: <Widget>[
                          AnimatedRotation(
                            turns: _isOpen ? 0.125 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              _isOpen
                                  ? Icons.close_rounded
                                  : Icons.auto_awesome_rounded,
                              size: context.sz(20),
                              color: _isAiHovered
                                  ? theme.colors.primary
                                  : theme.colors.foreground,
                            ),
                          ),
                          if (!_isOpen)
                            Positioned(
                              top: -1,
                              right: -3,
                              child: Container(
                                width: context.sz(6),
                                height: context.sz(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Subtle Horizontal Hairline Divider
            Container(
              width: context.sz(20),
              height: 1,
              color: theme.colors.border.withValues(alpha: 0.8),
            ),

            // 2. Compose Action Segment (Bottom)
            Tooltip(
              message: 'Compose New Post',
              child: MouseRegion(
                onEnter: (_) => setState(() => _isComposeHovered = true),
                onExit: (_) => setState(() => _isComposeHovered = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _isComposePressed = true),
                  onTapUp: (_) {
                    setState(() => _isComposePressed = false);
                    widget.onCompose?.call();
                  },
                  onTapCancel: () => setState(() => _isComposePressed = false),
                  child: AnimatedScale(
                    scale: _isComposePressed
                        ? 0.90
                        : (_isComposeHovered ? 1.06 : 1.0),
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: dockWidth,
                      height: buttonHeight,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.edit_rounded,
                        size: context.sz(19),
                        color: _isComposeHovered
                            ? theme.colors.primary
                            : theme.colors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Single Minimal Circular AI Button (Desktop or when Compose is hidden)
    final double buttonSize = context.sz(48);

    return Tooltip(
      message:
          'alphajournal AI Terminal (${_telemetryMessages[_telemetryIndex]})',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isAiHovered = true),
        onExit: (_) => setState(() => _isAiHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isAiPressed = true),
          onTapUp: (_) {
            setState(() => _isAiPressed = false);
            _openOverlay(context);
          },
          onTapCancel: () => setState(() => _isAiPressed = false),
          child: AnimatedScale(
            scale: _isAiPressed ? 0.92 : (_isAiHovered ? 1.04 : 1.0),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedRotation(
              turns: _isOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: _isAiHovered
                      ? theme.colors.surfaceMuted
                      : theme.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isAiHovered
                        ? theme.colors.primary.withValues(alpha: 0.6)
                        : theme.colors.border,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Icon(
                      _isOpen
                          ? Icons.close_rounded
                          : Icons.auto_awesome_rounded,
                      size: context.sz(20),
                      color: _isAiHovered
                          ? theme.colors.primary
                          : theme.colors.foreground,
                    ),
                    // Live Engine Active Dot
                    Positioned(
                      top: context.sz(9),
                      right: context.sz(9),
                      child: Container(
                        width: context.sz(6),
                        height: context.sz(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colors.surface,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Full-View Terminal Overlay
// ---------------------------------------------------------------------------

class CommunityAiFullViewOverlay extends StatefulWidget {
  const CommunityAiFullViewOverlay({
    super.key,
    this.repository,
    this.onPostCreated,
    required this.telemetryMessage,
  });

  final CommunityRepository? repository;
  final ValueChanged<CommunityPost>? onPostCreated;
  final String telemetryMessage;

  @override
  State<CommunityAiFullViewOverlay> createState() =>
      _CommunityAiFullViewOverlayState();
}

class _CommunityAiFullViewOverlayState
    extends State<CommunityAiFullViewOverlay> {
  final TextEditingController _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _dispatchPrompt(String prompt) {
    if (prompt.trim().isEmpty) return;
    Navigator.of(context).pop();
    AiAssistantOverlaySheet.show(
      context,
      repository: AiAssistantRepositoryScope.repository,
      initialPrompt: prompt.trim(),
      contextTitle: 'Community Market Intelligence',
      contextSubtitle: widget.telemetryMessage,
      contextIcon: Icons.auto_awesome_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final Size screenSize = MediaQuery.sizeOf(context);

    final double modalWidth = isMobile
        ? double.infinity
        : math.min(screenSize.width * 0.92, context.sz(920));
    final double modalHeight = isMobile
        ? screenSize.height * 0.92
        : math.min(screenSize.height * 0.88, context.sz(740));

    final double spacingSm = context.sp(theme.spacing.sm);
    final double spacingXs = context.sp(theme.spacing.xs);
    final double spacingXxs = context.sp(theme.spacing.xxs);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          // Dismissible Blurred Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Responsive Dialog / Mobile Bottom Drawer Tile
          Align(
            alignment: isMobile ? Alignment.bottomCenter : Alignment.center,
            child: Container(
              width: modalWidth,
              height: modalHeight,
              margin: isMobile ? EdgeInsets.zero : EdgeInsets.all(spacingSm),
              decoration: BoxDecoration(
                color: theme.colors.surface,
                borderRadius: isMobile
                    ? BorderRadius.vertical(
                        top: Radius.circular(context.sz(20)),
                        bottom: Radius.zero,
                      )
                    : BorderRadius.circular(context.sz(theme.radii.xl)),
                border: Border.all(
                  color: theme.colors.border.withValues(alpha: 0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: isMobile
                    ? BorderRadius.vertical(
                        top: Radius.circular(context.sz(20)),
                        bottom: Radius.zero,
                      )
                    : BorderRadius.circular(context.sz(theme.radii.xl)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Drawer Drag Handle on Mobile
                    if (isMobile) ...<Widget>[
                      Center(
                        child: Container(
                          width: context.sz(36),
                          height: context.sz(4),
                          margin: EdgeInsets.only(
                            top: spacingXs,
                            bottom: spacingXxs,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colors.border.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(context.sz(2)),
                          ),
                        ),
                      ),
                    ],

                    // 1. Top Terminal App Bar
                    _buildTerminalHeader(context, theme, isMobile),

                    const Divider(height: 1, thickness: 1),

                    // 2. Command Prompt & Query Dispatch Bar
                    _buildPromptBar(context, theme, spacingSm, spacingXs),

                    // 3. Bloomberg-grade Real-time Telemetry Ribbon
                    _buildTelemetryRibbon(context, theme, spacingSm),

                    // 4. Main Scrollable Capabilities Grid & Quick Prompts
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(spacingSm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Section: Capabilities Matrix
                            Row(
                              children: <Widget>[
                                Text(
                                  'ALPHA & COPILOT CAPABILITIES',
                                  style: context.uiText.caption.copyWith(
                                    fontSize: context.fs(10.5),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: theme.colors.foregroundMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '6 Modules Active',
                                  style: context.uiText.caption.copyWith(
                                    fontSize: context.fs(10.5),
                                    color: theme.colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: spacingXs),

                            _buildCapabilitiesGrid(
                              context,
                              theme,
                              isMobile,
                              spacingXs,
                            ),

                            SizedBox(height: spacingSm),

                            // Section: Recommended Prompts
                            Text(
                              'RECOMMENDED ALPHA PROMPTS',
                              style: context.uiText.caption.copyWith(
                                fontSize: context.fs(10.5),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                            SizedBox(height: spacingXs),

                            Wrap(
                              spacing: spacingXs,
                              runSpacing: spacingXxs + 2,
                              children: <Widget>[
                                _buildPromptChip(
                                  context,
                                  theme,
                                  '💡 Nifty 24,800 CE / PE Max Pain & OI Shifts',
                                ),
                                _buildPromptChip(
                                  context,
                                  theme,
                                  '🎯 High R:R Breakouts with >2x 20D Volume',
                                ),
                                _buildPromptChip(
                                  context,
                                  theme,
                                  '⚡ FII Index Futures Net Long/Short Positioning',
                                ),
                                _buildPromptChip(
                                  context,
                                  theme,
                                  '🛡️ Optimal Strangle Hedging for Volatility',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1, thickness: 1),

                    // 5. Terminal Status Bar
                    _buildStatusBar(context, theme, spacingSm, isMobile),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalHeader(
    BuildContext context,
    UiTheme theme,
    bool isMobile,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs) + 2,
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(theme.radii.sm),
              border: Border.all(color: theme.colors.border),
            ),
            child: Icon(
              Icons.terminal_rounded,
              size: context.sz(18),
              color: theme.colors.primary,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'alphajournal Alpha Terminal',
                      style: context.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: context.fs(14.5),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const UiBadge(
                      label: 'ENGINE ACTIVE',
                      intent: UiIntent.success,
                      variant: UiBadgeVariant.outline,
                      size: UiSize.xs,
                    ),
                  ],
                ),
                Text(
                  'Real-time Institutional Copilot & Quantitative Vision',
                  style: context.uiText.caption.copyWith(
                    fontSize: context.fs(11),
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) ...<Widget>[
            const UiBadge(
              label: 'CLAUDE 3.5 + GEMINI 1.5',
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(theme.radii.sm),
                border: Border.all(color: theme.colors.border),
              ),
              child: Text(
                'ESC',
                style: context.uiText.caption.copyWith(
                  fontSize: context.fs(10),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          UiIconButton(
            icon: Icons.close_rounded,
            size: UiSize.xs,
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptBar(
    BuildContext context,
    UiTheme theme,
    double spacingSm,
    double spacingXs,
  ) {
    return Container(
      color: theme.colors.surfaceMuted.withValues(alpha: 0.25),
      padding: EdgeInsets.symmetric(horizontal: spacingSm, vertical: spacingXs),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search_rounded,
            size: context.sz(18),
            color: theme.colors.foregroundMuted,
          ),
          SizedBox(width: spacingXs),
          Expanded(
            child: TextField(
              controller: _promptController,
              onSubmitted: _dispatchPrompt,
              style: context.uiText.body.copyWith(fontSize: context.fs(13)),
              decoration: InputDecoration(
                hintText:
                    'Ask Copilot, analyze symbol (e.g. \$NIFTY 24800 CE, \$RELIANCE), or execute command...',
                hintStyle: context.uiText.caption.copyWith(
                  fontSize: context.fs(12.5),
                  color: theme.colors.foregroundMuted,
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SizedBox(width: spacingXs),
          UiButton(
            label: 'Run ⏎',
            size: UiSize.xs,
            variant: UiVariant.solid,
            intent: UiIntent.primary,
            onPressed: () => _dispatchPrompt(_promptController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRibbon(
    BuildContext context,
    UiTheme theme,
    double spacingSm,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: theme.colors.border.withValues(alpha: 0.5)),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: spacingSm,
        vertical: context.sp(theme.spacing.xxs) + 2,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _telemetryItem(
              context,
              theme,
              'NIFTY 50',
              '24,842.20',
              '+0.45%',
              const Color(0xFF10B981),
            ),
            _telemetryDivider(theme),
            _telemetryItem(
              context,
              theme,
              'BANKNIFTY',
              '53,180.40',
              '-0.12%',
              const Color(0xFFEF4444),
            ),
            _telemetryDivider(theme),
            _telemetryItem(
              context,
              theme,
              'INDIA VIX',
              '13.15',
              '-3.80%',
              const Color(0xFF10B981),
            ),
            _telemetryDivider(theme),
            _telemetryItem(
              context,
              theme,
              'FII FLOW',
              '+₹1,420 Cr',
              'Net Long',
              theme.colors.primary,
            ),
            _telemetryDivider(theme),
            _telemetryItem(
              context,
              theme,
              'REGIME',
              'PCR 1.14',
              'Mild Bullish',
              const Color(0xFF10B981),
            ),
          ],
        ),
      ),
    );
  }

  Widget _telemetryItem(
    BuildContext context,
    UiTheme theme,
    String label,
    String value,
    String change,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption.copyWith(
            fontSize: context.fs(10.5),
            fontWeight: FontWeight.w700,
            color: theme.colors.foregroundMuted,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: context.uiText.caption.copyWith(
            fontSize: context.fs(11),
            fontWeight: FontWeight.w700,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          change,
          style: context.uiText.caption.copyWith(
            fontSize: context.fs(10.5),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _telemetryDivider(UiTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '|',
        style: TextStyle(color: theme.colors.border, fontSize: 11),
      ),
    );
  }

  Widget _buildCapabilitiesGrid(
    BuildContext context,
    UiTheme theme,
    bool isMobile,
    double spacingXs,
  ) {
    final List<Widget> items = <Widget>[
      _TerminalModuleCard(
        icon: Icons.document_scanner_rounded,
        iconColor: theme.colors.primary,
        title: 'Scan Chart Vision',
        subtitle:
            'Upload or paste chart. Detects Smart Money Concepts (SMC), Fair Value Gaps (FVG), and liquidity sweeps.',
        badge: 'PRO VISION',
        badgeIntent: UiIntent.primary,
        metric: 'Computer Vision • ~840ms',
        onTap: () {
          Navigator.of(context).pop();
          AiAssistantOverlaySheet.show(
            context,
            repository: AiAssistantRepositoryScope.repository,
            initialPrompt:
                'Scan chart structure for NIFTY 50 and BankNifty. Identify key order blocks, FVG liquidity gaps, and high probability setups.',
            contextTitle: 'Vision AI Chart Scanner',
            contextSubtitle: 'Computer Vision • Automated Setup Detection',
            contextIcon: Icons.center_focus_strong_rounded,
          );
        },
      ),
      _TerminalModuleCard(
        icon: Icons.chat_bubble_outline_rounded,
        iconColor: theme.colors.info,
        title: 'AI Trade Copilot',
        subtitle:
            'Multi-turn conversational strategy assistant. Formulates entry, stop-loss, risk-to-reward, and execution setup.',
        badge: 'INTERACTIVE',
        badgeIntent: UiIntent.info,
        metric: '4 Personas • Multi-turn',
        onTap: () {
          Navigator.of(context).pop();
          AiAssistantOverlaySheet.show(
            context,
            repository: AiAssistantRepositoryScope.repository,
            contextTitle: 'Community Alpha Copilot',
            contextSubtitle: 'Multi-turn Technical & Sentiment Copilot',
            contextIcon: Icons.chat_bubble_outline_rounded,
          );
        },
      ),
      _TerminalModuleCard(
        icon: Icons.local_fire_department_rounded,
        iconColor: theme.colors.warning,
        title: 'Alpha Signals Radar',
        subtitle:
            'Live quantitative momentum breakout alerts, volume anomalies, and institutional block-deal radar.',
        badge: '3 ACTIVE',
        badgeIntent: UiIntent.warning,
        metric: 'Realtime Scanner • High R:R',
        onTap: () {
          Navigator.of(context).pop();
          CommunityAiSignalsDialog.show(
            context,
            repository: widget.repository,
            onPostCreated: widget.onPostCreated,
          );
        },
      ),
      _TerminalModuleCard(
        icon: Icons.radar_rounded,
        iconColor: const Color(0xFF8B5CF6),
        title: 'Market Pulse Radar',
        subtitle:
            'Sentiment meter, sector rotation heatmaps, PCR breadth, Smart Money index, and economic catalyst calendar.',
        badge: '74% GREED',
        badgeIntent: UiIntent.success,
        metric: 'Sentiment Meter • Multi-Asset',
        onTap: () {
          Navigator.of(context).pop();
          CommunityAiMarketPulseDialog.show(
            context,
            repository: widget.repository,
            onPostCreated: widget.onPostCreated,
          );
        },
      ),
      _TerminalModuleCard(
        icon: Icons.calculate_outlined,
        iconColor: theme.colors.success,
        title: 'Risk & Position Sizer',
        subtitle:
            'Institutional 1% risk-of-ruin engine. Dynamic position sizing based on Kelly Criterion and ATR volatility.',
        badge: 'CAPITAL RULE',
        badgeIntent: UiIntent.success,
        metric: 'Capital Preservation • Kelly Formula',
        onTap: () {
          Navigator.of(context).pop();
          CommunityAiRiskCalcDialog.show(context);
        },
      ),
      _TerminalModuleCard(
        icon: Icons.graphic_eq_rounded,
        iconColor: const Color(0xFFF43F5E),
        title: 'AI Market Audio Brief',
        subtitle:
            'Pre-market macro voice podcast, technical breakdown synthesis, and morning trading audio notes.',
        badge: 'VOICE AUDIO',
        badgeIntent: UiIntent.danger,
        metric: 'Audio Synthesis • Morning Brief',
        onTap: () {
          Navigator.of(context).pop();
          CommunityAiAudioBriefDialog.show(context);
        },
      ),
    ];

    if (isMobile) {
      return Column(
        children: items
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: spacingXs),
                child: item,
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double cardWidth = (constraints.maxWidth - spacingXs) / 2;
        return Wrap(
          spacing: spacingXs,
          runSpacing: spacingXs,
          children: items
              .map((item) => SizedBox(width: cardWidth, child: item))
              .toList(),
        );
      },
    );
  }

  Widget _buildPromptChip(BuildContext context, UiTheme theme, String prompt) {
    return InkWell(
      onTap: () => _dispatchPrompt(prompt),
      borderRadius: BorderRadius.circular(theme.radii.pill),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.xs) + 2,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: theme.colors.surfaceMuted.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(theme.radii.pill),
          border: Border.all(color: theme.colors.border.withValues(alpha: 0.7)),
        ),
        child: Text(
          prompt,
          style: context.uiText.caption.copyWith(
            fontSize: context.fs(11.5),
            fontWeight: FontWeight.w600,
            color: theme.colors.foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(
    BuildContext context,
    UiTheme theme,
    double spacingSm,
    bool isMobile,
  ) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      color: theme.colors.surfaceMuted.withValues(alpha: 0.25),
      padding: EdgeInsets.fromLTRB(
        spacingSm,
        context.sp(theme.spacing.xxs) + 2,
        spacingSm,
        isMobile
            ? (context.sp(theme.spacing.xxs) + 2 + safeBottom)
            : (context.sp(theme.spacing.xxs) + 2),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Connected to alphajournal Alpha Gateway • Tick Latency: 12ms',
              style: context.uiText.caption.copyWith(
                fontSize: context.fs(10.5),
                color: theme.colors.foregroundMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile) ...<Widget>[
            Text(
              'Click outside or press ESC to dismiss',
              style: context.uiText.caption.copyWith(
                fontSize: context.fs(10),
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TerminalModuleCard extends StatefulWidget {
  const _TerminalModuleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeIntent,
    this.metric,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final UiIntent? badgeIntent;
  final String? metric;

  @override
  State<_TerminalModuleCard> createState() => _TerminalModuleCardState();
}

class _TerminalModuleCardState extends State<_TerminalModuleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double spacingXs = context.sp(theme.spacing.xs);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.all(spacingXs),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colors.surfaceMuted.withValues(alpha: 0.7)
                : theme.colors.surfaceMuted.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(theme.radii.md),
            border: Border.all(
              color: _isHovered
                  ? widget.iconColor.withValues(alpha: 0.45)
                  : theme.colors.border.withValues(alpha: 0.6),
              width: 1.1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(spacingXs),
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(theme.radii.sm),
                  border: Border.all(
                    color: widget.iconColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: context.sz(18),
                  color: widget.iconColor,
                ),
              ),
              SizedBox(width: spacingXs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            widget.title,
                            style: context.uiText.bodyStrong.copyWith(
                              fontSize: context.fs(13),
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.badge != null) ...<Widget>[
                          const SizedBox(width: 6),
                          UiBadge(
                            label: widget.badge!,
                            intent: widget.badgeIntent ?? UiIntent.primary,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: context.uiText.caption.copyWith(
                        fontSize: context.fs(11),
                        color: theme.colors.foregroundMuted,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.metric != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        widget.metric!,
                        style: context.uiText.caption.copyWith(
                          fontSize: context.fs(10),
                          fontWeight: FontWeight.w600,
                          color: widget.iconColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: context.sz(16),
                color: _isHovered
                    ? theme.colors.foreground
                    : theme.colors.foregroundMuted,
              ),
            ],
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
    String? initialPrompt,
  }) {
    return AiAssistantOverlaySheet.show(
      context,
      repository: AiAssistantRepositoryScope.repository,
      initialPrompt: initialPrompt,
      contextTitle: 'Community Alpha Copilot',
      contextSubtitle: 'Multi-turn Technical & Sentiment Copilot',
      contextIcon: Icons.chat_bubble_outline_rounded,
    );
  }

  @override
  State<CommunityAiQuickPromptDialog> createState() =>
      _CommunityAiQuickPromptDialogState();
}

class _CommunityAiQuickPromptDialogState
    extends State<CommunityAiQuickPromptDialog> {
  final TextEditingController _promptCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  _AiPersona _selectedPersona = _AiPersona.momentumScalper;
  bool _generating = false;
  final List<_ChatMessage> _messages = <_ChatMessage>[];

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
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runPrompt(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return;

    final _AiPersona persona = _selectedPersona;
    setState(() {
      _messages.add(_ChatMessage(text: q, isUser: true));
      _generating = true;
    });
    _promptCtrl.clear();
    _scrollToBottom();

    String body = '';
    List<String> followUps = <String>[
      'What is the risk-adjusted position size?',
      'Show higher timeframe trend bias',
      'Give me entry, stop, and take-profit targets',
    ];

    try {
      final aiRes = await UnifiedAiService.instance.complete(
        prompt: q,
        systemPrompt:
            'You are alphajournal Community Trading Assistant. Persona: ${persona.label}. Focus on high-signal technical analysis, key structural levels, order flow, and risk parameters. Deliver actionable bullet points and concise tables when relevant.',
      );
      if (aiRes.trim().isNotEmpty) {
        body = aiRes.trim();
      }
    } catch (_) {}

    if (!mounted) return;

    if (body.isEmpty) {
      if (q.contains('Pivot Levels') || q.contains('Nifty')) {
        body =
            '• Current Spot: 24,820 | Trend: Bullish Continuation Above VWAP\n'
            '• Critical Support 1: 24,780 (Order Block Mitigation Zone)\n'
            '• Key Resistance: 24,940 - 25,000 (Major Call Open Interest Wall)\n'
            '• Hard Invalidation: 15m candle close below 24,740 flips structure to neutral.';
        followUps = <String>[
          'What is the BankNifty correlation today?',
          'Which call strike has best gamma edge?',
          'Show 15m volume delta',
        ];
      } else if (q.contains('Breakouts')) {
        body =
            '1. **RELIANCE**: Long above ₹3,020. Bull flag breakout with 2.4x volume surge. Target: ₹3,110 (R:R 1:2.8).\n'
            '2. **HDFCBANK**: Consolidating at 50-EMA support. Reversal trigger at ₹1,680. Target: ₹1,735.\n'
            '3. **NVDA**: Ascending triangle compression. Breakout trigger \$128.50. Target: \$139.00.';
        followUps = <String>[
          'What is the stop loss for RELIANCE?',
          'Are institutional blocks participating?',
          'Give me the option strike equivalent',
        ];
      } else if (q.contains('FII') || q.contains('Positioning')) {
        body =
            '• FII Net Long Index Futures: 64.2% (+4,800 contracts today)\n'
            '• Put-Call Ratio (PCR): 1.18 (Bullish Contango)\n'
            '• DII Cash Inflow: +₹1,420 Crores absorbing retail profit booking.\n'
            '• Smart money consensus: Holding long bias into weekly expiry settlement.';
        followUps = <String>[
          'Are FIIs hedging with OTM puts?',
          'What was the proprietary desk delta today?',
          'How does current PCR compare to last expiry?',
        ];
      } else if (q.contains('Risk') || q.contains('Sizing')) {
        body =
            '• Max Risk: ₹15,000 | Account Equity: ₹5,00,000 (3.0% Risk Limit)\n'
            '• NIFTY Setup: Entry 24,850 | SL 24,780 (70 points at risk)\n'
            '• Nifty Lot Size: 50 | Risk per Lot: 70 * 50 = ₹3,500\n'
            '• Recommended Sizing: **4 Lots (200 qty)** = ₹14,000 Max Loss (Within risk limit!).';
        followUps = <String>[
          'Calculate sizing for ₹10,000 max loss',
          'What if I use trailing stop at 1:1.5?',
          'Show position sizing for BankNifty',
        ];
      } else if (q.contains('Greeks') ||
          q.contains('Volatility') ||
          q.contains('Option')) {
        body =
            '• India VIX: 13.85 (-3.2% cooling off post-open)\n'
            '• ATM Implied Volatility: 12.4% (IV Rank at 24th percentile - cheap options)\n'
            '• Gamma Peak: 24,900 CE with heavy pinning expected\n'
            '• Preferred Structure: Bull Call Spread (24,850 / 25,000 CE) to reduce theta decay.';
        followUps = <String>[
          'What is the theta burn rate per hour?',
          'Is debit spread better than naked buying here?',
          'Where is the max pain strike?',
        ];
      } else {
        body =
            '• Analytical scan for: "$q"\n'
            '• Technical structure: Consolidating near key liquidity pool with positive volume divergence.\n'
            '• Actionable rule: Wait for confirmed retest of prior breakout level before executing.';
      }
    }

    final String synthesized =
        '${persona.opener}\n\n$body\n\n${persona.emphasis}';

    setState(() {
      _generating = false;
      _messages.add(
        _ChatMessage(
          text: synthesized,
          isUser: false,
          persona: persona,
          followUps: followUps,
        ),
      );
    });
    _scrollToBottom();
  }

  void _shareToCommunity(String content) {
    final CommunityRepository repo = widget.repository ?? CommunityRepository();
    repo.createPost(
      body:
          '🤖 **AI Copilot Intelligence [${_selectedPersona.label}]**:\n\n$content\n\n#alphajournal #AICopilot #${_selectedPersona.shortLabel}',
      author: _resolveCurrentAuthor(repo),
      tags: <String>['AICopilot', _selectedPersona.shortLabel, 'Alpha'],
    );
    if (widget.onPostCreated != null && repo.feedPosts.isNotEmpty) {
      widget.onPostCreated!(repo.feedPosts.first);
    }
    UiToast.show(
      context,
      title: 'Shared to Feed!',
      message: 'AI intelligence posted to the community feed.',
      intent: UiIntent.success,
    );
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    UiToast.show(
      context,
      title: 'Copied to Clipboard',
      message: 'Intelligence text copied for your trading journal.',
      intent: UiIntent.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);
    final double gapMd = context.sp(theme.spacing.md);

    return UiDialog(
      title: 'AI Conversational Copilot',
      content: SizedBox(
        width: context.sz(560),
        height: context.sz(520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Persona Selector Row
            Container(
              padding: EdgeInsets.all(gapXs),
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.sm),
                border: Border.all(color: theme.colors.border),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    'Persona:',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(width: gapXs),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          for (final _AiPersona p in _AiPersona.values)
                            Padding(
                              padding: EdgeInsets.only(right: gapXs),
                              child: UiButton(
                                label: p.shortLabel,
                                leadingIcon: p.icon,
                                size: UiSize.xs,
                                variant: _selectedPersona == p
                                    ? UiVariant.primary
                                    : UiVariant.ghost,
                                onPressed: () {
                                  setState(() => _selectedPersona = p);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_messages.isNotEmpty)
                    UiIconButton(
                      icon: Icons.delete_sweep_outlined,
                      tooltip: 'Clear Thread',
                      size: UiSize.xs,
                      variant: UiVariant.ghost,
                      onPressed: () {
                        setState(() => _messages.clear());
                      },
                    ),
                ],
              ),
            ),

            SizedBox(height: gapXs),

            // Active Persona description banner
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.sm),
                vertical: context.sp(theme.spacing.xxs),
              ),
              decoration: BoxDecoration(
                color: theme.colors.primary.withValues(alpha: 0.08),
                borderRadius: context.radius(theme.radii.sm),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _selectedPersona.icon,
                    size: context.sz(13),
                    color: theme.colors.primary,
                  ),
                  SizedBox(width: gapXs),
                  Expanded(
                    child: Text(
                      'Lens: ${_selectedPersona.label} — ${_selectedPersona.opener.replaceAll('*', '')}',
                      style: context.uiText.caption.copyWith(
                        fontSize: context.fs(11),
                        fontWeight: FontWeight.w600,
                        color: theme.colors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: gap),

            // Chat Messages / Welcome Area
            Expanded(
              child: _messages.isEmpty
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          UiCard(
                            variant: UiCardVariant.surface,
                            padding: EdgeInsets.all(gapMd),
                            child: Column(
                              children: <Widget>[
                                Icon(
                                  Icons.smart_toy_outlined,
                                  size: context.sz(36),
                                  color: theme.colors.primary,
                                ),
                                SizedBox(height: gapXs),
                                Text(
                                  'Ask the Institutional AI Copilot',
                                  style: context.uiText.heading.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: gapXs),
                                Text(
                                  'Multi-turn market intelligence powered by order book microstructure, gamma pinning, and volume delta.',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.foregroundMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: gap),
                          Text(
                            'Quick Starters:',
                            style: context.uiText.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                          SizedBox(height: gapXs),
                          Wrap(
                            spacing: gapXs,
                            runSpacing: gapXs,
                            children: <Widget>[
                              for (final String p in _promptPresets)
                                InkWell(
                                  onTap: _generating
                                      ? null
                                      : () => _runPrompt(p),
                                  borderRadius: context.radius(
                                    theme.radii.pill,
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: context.sp(theme.spacing.sm),
                                      vertical: context.sp(theme.spacing.xxs),
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colors.surfaceMuted,
                                      borderRadius: context.radius(
                                        theme.radii.pill,
                                      ),
                                      border: Border.all(
                                        color: theme.colors.border,
                                      ),
                                    ),
                                    child: Text(
                                      p,
                                      style: context.uiText.caption.copyWith(
                                        fontSize: context.fs(11),
                                        fontWeight: FontWeight.w600,
                                        color: theme.colors.foreground,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: EdgeInsets.zero,
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext ctx, int index) {
                        final _ChatMessage msg = _messages[index];
                        if (msg.isUser) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: gap,
                              left: context.sp(theme.spacing.xl),
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: EdgeInsets.all(gap),
                                decoration: BoxDecoration(
                                  color: theme.colors.primary,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(theme.radii.md),
                                    topRight: Radius.circular(theme.radii.sm),
                                    bottomLeft: Radius.circular(theme.radii.md),
                                    bottomRight: Radius.circular(
                                      theme.radii.md,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  msg.text,
                                  style: context.uiText.body.copyWith(
                                    color: theme.colors.onPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final _AiPersona p = msg.persona ?? _selectedPersona;
                        final bool isLast = index == _messages.length - 1;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: gap,
                            right: context.sp(theme.spacing.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              UiCard(
                                variant: UiCardVariant.surface,
                                padding: EdgeInsets.all(gap),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        UiBadge(
                                          label: p.label,
                                          variant: UiBadgeVariant.soft,
                                          intent: UiIntent.primary,
                                          size: UiSize.xs,
                                        ),
                                        const Spacer(),
                                        UiIconButton(
                                          icon: Icons.copy_rounded,
                                          tooltip: 'Copy',
                                          size: UiSize.xs,
                                          variant: UiVariant.ghost,
                                          onPressed: () =>
                                              _copyToClipboard(msg.text),
                                        ),
                                        SizedBox(width: gapXs),
                                        UiButton(
                                          label: 'Share',
                                          leadingIcon: Icons.share_rounded,
                                          size: UiSize.xs,
                                          variant: UiVariant.soft,
                                          onPressed: () =>
                                              _shareToCommunity(msg.text),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: gapXs),
                                    SelectableText(
                                      msg.text,
                                      style: context.uiText.body.copyWith(
                                        fontSize: context.fs(12.5),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLast &&
                                  msg.followUps.isNotEmpty) ...<Widget>[
                                SizedBox(height: gapXs),
                                Wrap(
                                  spacing: gapXs,
                                  runSpacing: gapXs,
                                  children: <Widget>[
                                    for (final String followUp in msg.followUps)
                                      InkWell(
                                        onTap: _generating
                                            ? null
                                            : () => _runPrompt(followUp),
                                        borderRadius: context.radius(
                                          theme.radii.pill,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: context.sp(
                                              theme.spacing.xs,
                                            ),
                                            vertical: context.sp(
                                              theme.spacing.xxs,
                                            ),
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colors.surfaceMuted,
                                            borderRadius: context.radius(
                                              theme.radii.pill,
                                            ),
                                            border: Border.all(
                                              color: theme.colors.primary
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Icon(
                                                Icons.auto_awesome,
                                                size: context.sz(11),
                                                color: theme.colors.primary,
                                              ),
                                              SizedBox(width: gapXs),
                                              Text(
                                                followUp,
                                                style: context.uiText.caption
                                                    .copyWith(
                                                      fontSize: context.fs(11),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          theme.colors.primary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),

            if (_generating) ...<Widget>[
              SizedBox(height: gapXs),
              Row(
                children: <Widget>[
                  const UiTypingIndicator(),
                  SizedBox(width: gapXs),
                  Text(
                    '${_selectedPersona.label} is analyzing market microstructure…',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: gap),

            // Input Bar
            Row(
              children: <Widget>[
                Expanded(
                  child: UiInput(
                    controller: _promptCtrl,
                    hintText: 'Ask ${_selectedPersona.shortLabel} anything…',
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
          ],
        ),
      ),
      actions: <Widget>[
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
// Companion Dialog 1b: Community Market Pulse Radar
// ---------------------------------------------------------------------------

class CommunityAiMarketPulseDialog extends StatelessWidget {
  const CommunityAiMarketPulseDialog({
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
      builder: (BuildContext ctx) => CommunityAiMarketPulseDialog(
        repository: repository,
        onPostCreated: onPostCreated,
      ),
    );
  }

  static const List<_PulseTicker> _tickers = <_PulseTicker>[
    _PulseTicker('NIFTY 50', 78, 1420),
    _PulseTicker('BANKNIFTY', 64, 980),
    _PulseTicker('RELIANCE', 82, 540),
    _PulseTicker('HDFCBANK', 46, 410),
    _PulseTicker('TATASTEEL', 74, 360),
    _PulseTicker('INFY', 52, 290),
  ];

  static const List<_PulseSector> _sectors = <_PulseSector>[
    _PulseSector('Nifty Metal', 2.45),
    _PulseSector('Nifty Auto', 1.82),
    _PulseSector('Nifty Bank', 0.94),
    _PulseSector('Nifty Realty', 0.68),
    _PulseSector('Nifty FMCG', 0.12),
    _PulseSector('Nifty IT', -0.54),
    _PulseSector('Nifty Energy', -0.88),
  ];

  void _sharePulse(BuildContext context) {
    final CommunityRepository repo = repository ?? CommunityRepository();
    repo.createPost(
      body:
          '📊 **Market Pulse & Community Sentiment Radar**\n\n'
          '• Overall Sentiment: 74% Bullish | 26% Bearish (Contango Breadth)\n'
          '• Leading Sectors: Nifty Metal (+2.45%), Nifty Auto (+1.82%)\n'
          '• Most Discussed: NIFTY 50 (78% Bullish), RELIANCE (82% Bullish)\n'
          '• Smart Money Delta: FII Net Long +₹1,420 Cr absorbing retail supply.\n\n'
          '#MarketPulse #Sentiment #alphajournal #InstitutionalEdge',
      author: _resolveCurrentAuthor(repo),
      tags: const <String>['MarketPulse', 'Sentiment', 'InstitutionalEdge'],
    );
    if (onPostCreated != null && repo.feedPosts.isNotEmpty) {
      onPostCreated!(repo.feedPosts.first);
    }
    UiToast.show(
      context,
      title: 'Pulse Shared to Feed!',
      message: 'Market Pulse radar posted to the community feed.',
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
      title: 'Market Pulse & Community Sentiment Radar',
      content: SizedBox(
        width: context.sz(560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Overall Sentiment Card
              UiCard(
                variant: UiCardVariant.surface,
                padding: EdgeInsets.all(gap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.radar_rounded,
                          size: context.sz(18),
                          color: theme.colors.primary,
                        ),
                        SizedBox(width: gapXs),
                        Expanded(
                          child: Text(
                            'Aggressive Bullish Contango',
                            style: context.uiText.label.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        UiBadge(
                          label: '74% Bullish',
                          variant: UiBadgeVariant.solid,
                          intent: UiIntent.success,
                        ),
                      ],
                    ),
                    SizedBox(height: gapXs),
                    UiProgressBar(value: 0.74, intent: UiIntent.success),
                    SizedBox(height: gapXs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '3,840 trader opinions tracked across 12 sectors',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                        Text(
                          'Advance/Decline: 2.8x',
                          style: context.uiText.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: gap),

              // Trending Tickers Sentiment List
              Text(
                'Top Discussed Tickers & Sentiment Bias:',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foregroundMuted,
                ),
              ),
              SizedBox(height: gapXs),
              UiCard(
                variant: UiCardVariant.surface,
                padding: EdgeInsets.all(gap),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < _tickers.length; i++) ...<Widget>[
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: context.sz(85),
                            child: Text(
                              _tickers[i].symbol,
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: UiProgressBar(
                              value: _tickers[i].bullishPct / 100,
                              intent: _tickers[i].bullishPct >= 60
                                  ? UiIntent.success
                                  : (_tickers[i].bullishPct <= 45
                                        ? UiIntent.danger
                                        : UiIntent.warning),
                            ),
                          ),
                          SizedBox(width: gapXs),
                          SizedBox(
                            width: context.sz(60),
                            child: Text(
                              '${_tickers[i].bullishPct}% Bull',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _tickers[i].bullishPct >= 60
                                    ? theme.colors.success
                                    : theme.colors.foregroundMuted,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(width: gapXs),
                          UiBadge(
                            label: '${_tickers[i].mentions}',
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                      if (i < _tickers.length - 1) SizedBox(height: gapXs),
                    ],
                  ],
                ),
              ),

              SizedBox(height: gap),

              // Sector Performance Heatmap
              Text(
                'Sector Relative Strength Heatmap:',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foregroundMuted,
                ),
              ),
              SizedBox(height: gapXs),
              Wrap(
                spacing: gapXs,
                runSpacing: gapXs,
                children: <Widget>[
                  for (final _PulseSector s in _sectors)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.sm),
                        vertical: context.sp(theme.spacing.xs),
                      ),
                      decoration: BoxDecoration(
                        color: s.changePct >= 0
                            ? theme.colors.success.withValues(alpha: 0.12)
                            : theme.colors.danger.withValues(alpha: 0.12),
                        borderRadius: context.radius(theme.radii.sm),
                        border: Border.all(
                          color: s.changePct >= 0
                              ? theme.colors.success.withValues(alpha: 0.3)
                              : theme.colors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            s.name,
                            style: context.uiText.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: gapXs),
                          Text(
                            '${s.changePct >= 0 ? '+' : ''}${s.changePct.toStringAsFixed(2)}%',
                            style: context.uiText.caption.copyWith(
                              fontWeight: FontWeight.w800,
                              color: s.changePct >= 0
                                  ? theme.colors.success
                                  : theme.colors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              SizedBox(height: gap),

              // Institutional Flow Summary
              Container(
                padding: EdgeInsets.all(gap),
                decoration: BoxDecoration(
                  color: theme.colors.primary.withValues(alpha: 0.08),
                  borderRadius: context.radius(theme.radii.sm),
                  border: Border.all(
                    color: theme.colors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.account_balance_rounded,
                          size: context.sz(14),
                          color: theme.colors.primary,
                        ),
                        SizedBox(width: gapXs),
                        Text(
                          'Institutional Flow & Smart Money Delta',
                          style: context.uiText.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gapXs),
                    Text(
                      'FIIs added +₹1,420 Cr in index futures with massive call open interest buildup at the 25,000 strike. Retail puts unwound 34% at the 24,800 demand block, creating gamma support into expiry.',
                      style: context.uiText.caption.copyWith(
                        height: 1.45,
                        color: theme.colors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        UiButton(
          label: 'Close',
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        UiButton(
          label: 'Share Pulse to Feed',
          leadingIcon: Icons.share_rounded,
          variant: UiVariant.primary,
          onPressed: () => _sharePulse(context),
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
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
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
                        Text(
                          'Entry: ₹${preset.entry}',
                          style: context.uiText.caption,
                        ),
                        Text(
                          'SL: ₹${preset.stopLoss}',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.danger,
                          ),
                        ),
                        Text(
                          'Target: ₹${preset.target1}',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.success,
                          ),
                        ),
                        Text(
                          'R:R 1:${preset.rrRatio.toStringAsFixed(1)}',
                          style: context.uiText.caption.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
  State<CommunityAiRiskCalcDialog> createState() =>
      _CommunityAiRiskCalcDialogState();
}

class _CommunityAiRiskCalcDialogState extends State<CommunityAiRiskCalcDialog> {
  final TextEditingController _capitalCtrl = TextEditingController(
    text: '500000',
  );
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
    final recommendedLots = riskPerLot > 0
        ? (maxLossAllowed / riskPerLot).floor()
        : 0;
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
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
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
                          color: _riskPercent == r
                              ? theme.colors.primary
                              : theme.colors.border,
                        ),
                      ),
                      child: Text(
                        '$r%',
                        style: context.uiText.caption.copyWith(
                          fontSize: context.fs(11),
                          fontWeight: _riskPercent == r
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _riskPercent == r
                              ? theme.colors.primary
                              : theme.colors.foreground,
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
                      Text(
                        '₹${maxLossAllowed.toStringAsFixed(0)} ($_riskPercent%)',
                        style: context.uiText.bodyStrong.copyWith(
                          color: theme.colors.danger,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: gapXs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stop Loss Distance:',
                        style: context.uiText.caption,
                      ),
                      Text(
                        '${pointsAtRisk.toStringAsFixed(1)} points',
                        style: context.uiText.bodyStrong,
                      ),
                    ],
                  ),
                  SizedBox(height: gapXs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recommended Lots:',
                        style: context.uiText.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$recommendedLots Lots ($totalQty Qty)',
                        style: context.uiText.subheading.copyWith(
                          color: theme.colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: gapXs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Actual Risk Exposure:',
                        style: context.uiText.caption,
                      ),
                      Text(
                        '₹${totalActualRisk.toStringAsFixed(0)}',
                        style: context.uiText.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
  State<CommunityAiAudioBriefDialog> createState() =>
      _CommunityAiAudioBriefDialogState();
}

class _CommunityAiAudioBriefDialogState
    extends State<CommunityAiAudioBriefDialog> {
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
                UiBadge(
                  label: 'TODAY 08:30 AM',
                  intent: UiIntent.primary,
                  size: UiSize.xs,
                ),
                SizedBox(width: gapXs),
                Text(
                  'Institutional Pre-Market Synthesis',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
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
                      color: index < 6
                          ? theme.colors.primary
                          : theme.colors.foregroundMuted.withValues(alpha: 0.4),
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
                  onPressed: () => setState(
                    () => _progress = (_progress - 0.05).clamp(0.0, 1.0),
                  ),
                ),
                SizedBox(width: gap),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: UiIconButton(
                    icon: _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
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
                  onPressed: () => setState(
                    () => _progress = (_progress + 0.05).clamp(0.0, 1.0),
                  ),
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
