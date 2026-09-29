import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';

/// Comprehensive creation sheet that allows customizing every detail required for
/// a professional Note, Journal Trade, Strategy Playbook, or Community Post before
/// committing it to storage and linking it to the rest of the application.
class AiCreateSheet extends StatefulWidget {
  final AiAssistantRepository repository;
  final AiCreateTarget target;
  final AiChartSetup? setup;
  final void Function(AppLinkRef ref)? onOpenRef;

  const AiCreateSheet({
    super.key,
    required this.repository,
    required this.target,
    this.setup,
    this.onOpenRef,
  });

  static Future<void> show(
    BuildContext context, {
    required AiAssistantRepository repository,
    required AiCreateTarget target,
    AiChartSetup? setup,
    void Function(AppLinkRef ref)? onOpenRef,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiCreateSheet(
        repository: repository,
        target: target,
        setup: setup,
        onOpenRef: onOpenRef,
      ),
    );
  }

  @override
  State<AiCreateSheet> createState() => _AiCreateSheetState();
}

class _AiCreateSheetState extends State<AiCreateSheet> {
  late AiCreateDraft _draft;

  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late TextEditingController _summaryController;

  // Journal specific controllers
  late TextEditingController _tickerController;
  late TextEditingController _entryController;
  late TextEditingController _stopLossController;
  late TextEditingController _target1Controller;
  late TextEditingController _target2Controller;
  late TextEditingController _quantityController;
  late TextEditingController _strategyNameController;

  // State values
  late List<String> _tickers;
  late List<String> _tags;
  late AppNoteType _noteType;
  late bool _isFavorite;
  late bool _isPublic;
  late AppSide _side;
  late bool _isClosed;
  late int _disciplineScore;
  late String _category;
  late AppStrategyStatus _strategyStatus;
  late String _channel;

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    if (widget.setup != null) {
      _draft = widget.repository.draftFromSetup(widget.setup!, widget.target);
    } else {
      _draft = widget.repository.draftFromChat(widget.target);
    }

    _titleController = TextEditingController(text: _draft.title);
    _bodyController = TextEditingController(text: _draft.body);
    _summaryController = TextEditingController(text: _draft.summary ?? '');

    final s = _draft.setup;
    final defaultTicker = _draft.tickers.isNotEmpty
        ? _draft.tickers.first
        : (s?.symbol ?? 'NIFTY50');
    _tickerController = TextEditingController(text: defaultTicker);
    _entryController = TextEditingController(
      text: (_draft.entryPrice ?? s?.entry ?? 100.0).toStringAsFixed(2),
    );
    _stopLossController = TextEditingController(
      text: (_draft.stopLoss ?? s?.stopLoss ?? 95.0).toStringAsFixed(2),
    );
    _target1Controller = TextEditingController(
      text: (_draft.target1 ?? s?.target1 ?? 110.0).toStringAsFixed(2),
    );
    _target2Controller = TextEditingController(
      text: (_draft.target2 ?? s?.target2 ?? 115.0).toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: _draft.quantity.toInt().toString(),
    );
    _strategyNameController = TextEditingController(
      text: _draft.strategyName ?? s?.pattern ?? 'Breakout Momentum',
    );

    _tickers = List<String>.from(_draft.tickers);
    _tags = List<String>.from(_draft.tags);
    _noteType = _draft.noteType;
    _isFavorite = _draft.isFavorite;
    _isPublic = _draft.isPublic;
    _side = _draft.side;
    _isClosed = _draft.isClosed;
    _disciplineScore = _draft.psychologyScore;
    _category = _draft.category ?? 'Breakout Momentum';
    _strategyStatus = _draft.strategyStatus;
    _channel = _draft.channel;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _summaryController.dispose();
    _tickerController.dispose();
    _entryController.dispose();
    _stopLossController.dispose();
    _target1Controller.dispose();
    _target2Controller.dispose();
    _quantityController.dispose();
    _strategyNameController.dispose();
    super.dispose();
  }

  double get _currentEntry => double.tryParse(_entryController.text) ?? 100.0;
  double get _currentStop => double.tryParse(_stopLossController.text) ?? 95.0;
  double get _currentTarget1 => double.tryParse(_target1Controller.text) ?? 110.0;
  double get _currentQuantity => double.tryParse(_quantityController.text) ?? 50.0;

  double get _calcRiskPerShare => (_currentEntry - _currentStop).abs();
  double get _calcRewardPerShare => (_currentTarget1 - _currentEntry).abs();
  double get _calcRRRatio =>
      _calcRiskPerShare > 0 ? _calcRewardPerShare / _calcRiskPerShare : 1.0;
  double get _calcTotalRisk => _calcRiskPerShare * _currentQuantity;
  double get _calcTotalReward => _calcRewardPerShare * _currentQuantity;

  Future<void> _handleCreate() async {
    setState(() => _isCreating = true);

    final updatedDraft = _draft.copyWith(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      summary: _summaryController.text.trim(),
      tickers: _tickers,
      tags: _tags,
      noteType: _noteType,
      isFavorite: _isFavorite,
      isPublic: _isPublic,
      side: _side,
      entryPrice: _currentEntry,
      stopLoss: _currentStop,
      target1: _currentTarget1,
      target2: double.tryParse(_target2Controller.text),
      quantity: _currentQuantity,
      rMultiple: _calcRRRatio,
      strategyName: _strategyNameController.text.trim(),
      psychologyScore: _disciplineScore,
      isClosed: _isClosed,
      category: _category,
      strategyStatus: _strategyStatus,
      channel: _channel,
    );

    try {
      final ref = await widget.repository.create(updatedDraft);
      if (mounted) {
        Navigator.of(context).pop();
        UiToastScope.maybeOf(context)?.show(
          UiToastData(
            title: '${widget.target.label} Created',
            message: updatedDraft.title,
            intent: UiIntent.success,
          ),
        );
        if (ref != null && widget.onOpenRef != null) {
          widget.onOpenRef!(ref);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return AiDensityScope(
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        minChildSize: 0.55,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(context.sz(theme.radii.lg)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                const AiSheetGrabber(),
                _buildHeader(context),
                const UiDivider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.lg),
                      vertical: context.sp(theme.spacing.md),
                    ),
                    children: [
                      switch (widget.target) {
                        AiCreateTarget.note ||
                        AiCreateTarget.chartAnalysis =>
                          _buildNoteForm(context),
                        AiCreateTarget.journal => _buildJournalForm(context),
                        AiCreateTarget.strategy => _buildStrategyForm(context),
                        AiCreateTarget.post => _buildPostForm(context),
                      },
                    ],
                  ),
                ),
                const UiDivider(),
                _buildFooter(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = context.ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.xs),
        context.sp(theme.spacing.sm),
        context.sp(theme.spacing.sm),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
            decoration: BoxDecoration(
              color: widget.target.intent.color(context).withValues(alpha: 0.12),
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              widget.target.icon,
              color: widget.target.intent.color(context),
              size: context.sz(20),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.target.label,
                  style: context.uiText.title.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.target.description,
                  style: context.uiText.caption.copyWith(
                    color: context.uiColors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          UiBadge(
            label: 'AI Draft',
            intent: UiIntent.primary,
            variant: UiBadgeVariant.soft,
            size: UiSize.xs,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          UiIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Note Form
  // ---------------------------------------------------------------------------
  Widget _buildNoteForm(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiInput(
          label: 'Note Title',
          controller: _titleController,
          hintText: 'Enter title...',
          autofocus: true,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Row(
          children: [
            Expanded(
              child: UiSelect<AppNoteType>(
                label: 'Note Type',
                value: _noteType,
                onChanged: (val) => setState(() => _noteType = val),
                options: AppNoteType.values
                    .map((t) => UiOption<AppNoteType>(value: t, label: t.label))
                    .toList(),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: context.sp(theme.spacing.lg)),
                child: Row(
                  children: [
                    UiSwitch(
                      value: _isFavorite,
                      label: 'Favorite',
                      onChanged: (v) => setState(() => _isFavorite = v),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    UiSwitch(
                      value: _isPublic,
                      label: 'Public',
                      onChanged: (v) => setState(() => _isPublic = v),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTagInput(
          label: 'Linked Tickers',
          prefix: '\$',
          hintText: 'Add ticker (e.g. AAPL, NVDA, NIFTY)',
          tags: _tickers,
          onChanged: (tags) => setState(() => _tickers = tags),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTagInput(
          label: 'Tags',
          prefix: '#',
          hintText: 'Add tag (e.g. Breakout, Support, Macro)',
          tags: _tags,
          onChanged: (tags) => setState(() => _tags = tags),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTextarea(
          label: 'Markdown Body',
          controller: _bodyController,
          rows: 10,
          maxRows: 20,
          hintText: 'Write or refine your technical note...',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Journal Trade Form
  // ---------------------------------------------------------------------------
  Widget _buildJournalForm(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: UiInput(
                label: 'Symbol / Instrument',
                controller: _tickerController,
                hintText: 'e.g. NIFTY, AAPL, BTC',
                onChanged: (val) {
                  setState(() {
                    if (_tickers.isEmpty) {
                      _tickers.add(val.toUpperCase());
                    } else {
                      _tickers[0] = val.toUpperCase();
                    }
                  });
                },
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Side', style: context.uiText.label),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  UiToggleGroup<AppSide>(
                    variant: UiToggleGroupVariant.pill,
                    value: _side,
                    onChanged: (s) => setState(() => _side = s),
                    options: const [
                      UiToggleOption<AppSide>(
                        value: AppSide.long,
                        label: 'LONG',
                        icon: Icons.trending_up_rounded,
                      ),
                      UiToggleOption<AppSide>(
                        value: AppSide.short,
                        label: 'SHORT',
                        icon: Icons.trending_down_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiInput(
          label: 'Trade Title',
          controller: _titleController,
          hintText: 'Headline for this setup...',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiInput(
          label: 'Strategy / Setup Pattern',
          controller: _strategyNameController,
          hintText: 'e.g. Bull Flag, FVG Liquidity Sweep, VWAP Cross',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Pricing & Metrics Card
        UiCard(
          variant: UiCardVariant.surface,
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate_outlined, size: context.sz(16), color: colors.primary),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Text('Trade Execution Matrix', style: context.uiText.bodyStrong),
                  const Spacer(),
                  UiBadge(
                    label: '${_calcRRRatio.toStringAsFixed(1)}R Ratio',
                    intent: _calcRRRatio >= 2.0 ? UiIntent.success : UiIntent.warning,
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Row(
                children: [
                  Expanded(
                    child: UiInput(
                      label: 'Entry Price',
                      controller: _entryController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: UiInput(
                      label: 'Stop Loss',
                      controller: _stopLossController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Row(
                children: [
                  Expanded(
                    child: UiInput(
                      label: 'Target 1',
                      controller: _target1Controller,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: UiInput(
                      label: 'Target 2 (Runner)',
                      controller: _target2Controller,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: UiInput(
                      label: 'Quantity / Size',
                      controller: _quantityController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Container(
                padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.sm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricSnippet(context, 'Risk / Share', '\$${_calcRiskPerShare.toStringAsFixed(2)}', colors.destructive),
                    _metricSnippet(context, 'Reward / Share', '\$${_calcRewardPerShare.toStringAsFixed(2)}', colors.success),
                    _metricSnippet(context, 'Total Risk', '\$${_calcTotalRisk.toStringAsFixed(0)}', colors.destructive),
                    _metricSnippet(context, 'Potential Profit', '\$${_calcTotalReward.toStringAsFixed(0)}', colors.success),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Conviction and Status
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discipline Score: $_disciplineScore / 5', style: context.uiText.label),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    children: [1, 2, 3, 4, 5].map((score) {
                      final selected = _disciplineScore == score;
                      return GestureDetector(
                        onTap: () => setState(() => _disciplineScore = score),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.sp(theme.spacing.sm),
                            vertical: context.sp(theme.spacing.xxs),
                          ),
                          decoration: BoxDecoration(
                            color: selected ? colors.primary : colors.surfaceMuted,
                            borderRadius: context.radius(theme.radii.sm),
                          ),
                          child: Text(
                            '$score ★',
                            style: context.uiText.caption.copyWith(
                              color: selected ? Colors.white : colors.foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: context.sp(theme.spacing.lg)),
                child: Row(
                  children: [
                    UiSwitch(
                      value: _isClosed,
                      label: 'Already Closed',
                      onChanged: (v) => setState(() => _isClosed = v),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    UiSwitch(
                      value: _isPublic,
                      label: 'Public',
                      onChanged: (v) => setState(() => _isPublic = v),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTagInput(
          label: 'Tags',
          prefix: '#',
          tags: _tags,
          onChanged: (tags) => setState(() => _tags = tags),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTextarea(
          label: 'Execution Notes & Trade Thesis',
          controller: _bodyController,
          rows: 6,
          maxRows: 14,
        ),
      ],
    );
  }

  Widget _metricSnippet(BuildContext context, String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: context.uiText.caption.copyWith(fontSize: 10)),
        Text(val, style: context.uiText.numeric.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Strategy Playbook Form
  // ---------------------------------------------------------------------------
  Widget _buildStrategyForm(BuildContext context) {
    final theme = context.ui;

    final categories = <String>[
      'Breakout Momentum',
      'Price Action & Market Structure',
      'Mean Reversion & Scalping',
      'Trend Following',
      'Order Flow & Volume Profile',
      'Options Directional & Flow',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiInput(
          label: 'Playbook Name',
          controller: _titleController,
          hintText: 'e.g. S&P 500 Liquidity Sweep System',
          autofocus: true,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiInput(
          label: 'Core Premise / One-Line Summary',
          controller: _summaryController,
          hintText: 'Define the edge in one sentence...',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Row(
          children: [
            Expanded(
              child: UiSelect<String>(
                label: 'Strategy Category',
                value: _category,
                onChanged: (cat) => setState(() => _category = cat),
                options: categories
                    .map((c) => UiOption<String>(value: c, label: c))
                    .toList(),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            Expanded(
              child: UiSelect<AppStrategyStatus>(
                label: 'Playbook Status',
                value: _strategyStatus,
                onChanged: (s) => setState(() => _strategyStatus = s),
                options: AppStrategyStatus.values
                    .map((s) => UiOption<AppStrategyStatus>(value: s, label: s.name.toUpperCase()))
                    .toList(),
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTagInput(
          label: 'Applicable Tickers & Markets',
          prefix: '\$',
          hintText: 'e.g. SPY, QQQ, NIFTY, BTC',
          tags: _tickers,
          onChanged: (tags) => setState(() => _tickers = tags),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTagInput(
          label: 'Tags',
          prefix: '#',
          tags: _tags,
          onChanged: (tags) => setState(() => _tags = tags),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            UiSwitch(
              value: _isPublic,
              label: 'Publish to Community Playbooks',
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            UiSwitch(
              value: _isFavorite,
              label: 'Pin as Favorite Playbook',
              onChanged: (v) => setState(() => _isFavorite = v),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTextarea(
          label: 'Playbook Execution Rules (Markdown)',
          controller: _bodyController,
          rows: 10,
          maxRows: 22,
          hintText: 'Document conditions, entry trigger, stop loss, and targets...',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Post Form
  // ---------------------------------------------------------------------------
  Widget _buildPostForm(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final channels = <String>['Feed', 'Signals', 'Breakouts', 'Macro', 'Crypto'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiInput(
          label: 'Post Headline',
          controller: _titleController,
          hintText: 'Optional summary title...',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiSelect<String>(
          label: 'Community Channel',
          value: _channel,
          onChanged: (c) => setState(() => _channel = c),
          options: channels.map((c) => UiOption<String>(value: c, label: '#$c')).toList(),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Attached Setup Preview
        if (_draft.setup != null) ...[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.md),
              border: Border.all(color: colors.border, width: theme.borders.hairline),
            ),
            child: Row(
              children: [
                Icon(_draft.setup!.direction.icon, color: _draft.setup!.direction.intent.color(context)),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attached Setup: ${_draft.setup!.symbol} ${_draft.setup!.pattern}',
                        style: context.uiText.bodyStrong,
                      ),
                      Text(
                        'Entry: ${_draft.setup!.entry} | SL: ${_draft.setup!.stopLoss} | TP: ${_draft.setup!.target1} (${_draft.setup!.rrRatio.toStringAsFixed(1)}R)',
                        style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                UiBadge(label: _draft.setup!.direction.label, intent: _draft.setup!.direction.intent),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
        ],

        UiTagInput(
          label: 'Cashtags',
          prefix: '\$',
          tags: _tickers,
          onChanged: (tags) => setState(() => _tickers = tags),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTagInput(
          label: 'Hashtags',
          prefix: '#',
          tags: _tags,
          onChanged: (tags) => setState(() => _tags = tags),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTextarea(
          label: 'Post Content',
          controller: _bodyController,
          rows: 6,
          maxRows: 12,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------
  Widget _buildFooter(BuildContext context) {
    final theme = context.ui;

    return Padding(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: context.sp(theme.spacing.md)),
          UiButton(
            label: widget.target.actionLabel,
            intent: UiIntent.primary,
            loading: _isCreating,
            onPressed: _handleCreate,
          ),
        ],
      ),
    );
  }
}
