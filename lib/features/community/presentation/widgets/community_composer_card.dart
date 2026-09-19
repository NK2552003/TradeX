import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_picker.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_quote_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_schedule_dialog.dart';

// ---------------------------------------------------------------------------
// CommunityComposerCard
// ---------------------------------------------------------------------------

/// A rich tweet-composer card for the TradeX community platform.
///
/// Allows the author to compose a freeform post body, attach `$TICKER` tags,
/// embed a structured trade-setup snippet, or attach a workspace record (Note, Trade, Strategy).
/// Calls [CommunityRepository.createPost] on submit and fires
/// [onPostCreated] for parent widgets to react (e.g. scroll-to-top).
class CommunityComposerCard extends StatefulWidget {
  const CommunityComposerCard({
    super.key,
    required this.author,
    required this.repository,
    this.hintText = "What's happening? Share a setup, thesis or lesson…",
    this.onPostCreated,
    this.quotedPost,
    this.compact = false,
  });

  final CommunityAuthor author;
  final CommunityRepository repository;
  final String hintText;
  final VoidCallback? onPostCreated;
  final CommunityPost? quotedPost;

  /// When true the textarea starts at 1 row (condensed feed header style).
  final bool compact;

  @override
  State<CommunityComposerCard> createState() => _CommunityComposerCardState();
}

class _CommunityComposerCardState extends State<CommunityComposerCard> {
  // ---- Core body -----------------------------------------------------------
  String _body = '';

  // ---- Attached tickers / tags ---------------------------------------------
  final List<String> _tickers = <String>[];
  final List<String> _tags = <String>[];

  // ---- Attached record (note, journal, strategy) ---------------------------
  AppWritingPostAttachment? _attachment;

  // ---- Advanced Composer Additions -----------------------------------------
  CommunitySentiment? _sentiment;
  DateTime? _scheduledFor;
  CommunityReplyAudience _replyAudience = CommunityReplyAudience.everyone;
  bool _showPollForm = false;
  final TextEditingController _pollQuestionCtrl = TextEditingController();
  final TextEditingController _pollOpt1Ctrl = TextEditingController();
  final TextEditingController _pollOpt2Ctrl = TextEditingController();

  // ---- Submission ----------------------------------------------------------
  bool _submitting = false;

  // ---- Trade setup form ----------------------------------------------------
  bool _showSetupForm = false;
  final TextEditingController _setupTickerCtrl = TextEditingController();
  String _tradeSetupSide = 'LONG';
  final TextEditingController _setupEntryCtrl = TextEditingController();
  final TextEditingController _setupExitCtrl = TextEditingController();
  final TextEditingController _setupSlCtrl = TextEditingController();
  final TextEditingController _setupTargetCtrl = TextEditingController();

  // ---- Ticker dialog input -------------------------------------------------
  final TextEditingController _tickerInputCtrl = TextEditingController();

  @override
  void dispose() {
    _setupTickerCtrl.dispose();
    _setupEntryCtrl.dispose();
    _setupExitCtrl.dispose();
    _setupSlCtrl.dispose();
    _setupTargetCtrl.dispose();
    _tickerInputCtrl.dispose();
    _pollQuestionCtrl.dispose();
    _pollOpt1Ctrl.dispose();
    _pollOpt2Ctrl.dispose();
    super.dispose();
  }


  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _setupFormFilled =>
      _setupTickerCtrl.text.trim().isNotEmpty &&
      _setupEntryCtrl.text.trim().isNotEmpty;

  CommunityTradeSetup? get _buildTradeSetup {
    if (!_showSetupForm || !_setupFormFilled) return null;
    return CommunityTradeSetup(
      ticker: _setupTickerCtrl.text.trim().toUpperCase(),
      side: _tradeSetupSide,
      entry: _setupEntryCtrl.text.trim(),
      exit: _setupExitCtrl.text.trim().isEmpty
          ? null
          : _setupExitCtrl.text.trim(),
      stopLoss: _setupSlCtrl.text.trim().isEmpty
          ? null
          : _setupSlCtrl.text.trim(),
      target: _setupTargetCtrl.text.trim().isEmpty
          ? null
          : _setupTargetCtrl.text.trim(),
    );
  }

  void _removeTicker(String ticker) {
    setState(() => _tickers.remove(ticker));
  }

  void _addTicker(String raw) {
    final String t = raw.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9&]'),
      '',
    );
    if (t.isEmpty || _tickers.contains(t)) return;
    setState(() => _tickers.add(t));
  }

  void _toggleSetupForm() {
    setState(() {
      _showSetupForm = !_showSetupForm;
      if (!_showSetupForm) {
        _setupTickerCtrl.clear();
        _setupEntryCtrl.clear();
        _setupExitCtrl.clear();
        _setupSlCtrl.clear();
        _setupTargetCtrl.clear();
        _tradeSetupSide = 'LONG';
      }
    });
  }

  CommunityPoll? get _buildPoll {
    if (!_showPollForm || _pollQuestionCtrl.text.trim().isEmpty) return null;
    final opt1 = _pollOpt1Ctrl.text.trim().isEmpty ? 'Bullish' : _pollOpt1Ctrl.text.trim();
    final opt2 = _pollOpt2Ctrl.text.trim().isEmpty ? 'Bearish' : _pollOpt2Ctrl.text.trim();
    return CommunityPoll(
      id: 'poll_${DateTime.now().millisecondsSinceEpoch}',
      question: _pollQuestionCtrl.text.trim(),
      options: [
        CommunityPollOption(id: 'opt_1', text: opt1, votes: 0),
        CommunityPollOption(id: 'opt_2', text: opt2, votes: 0),
      ],
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
  }

  Future<void> _submit() async {
    final String body = _body.trim();
    if (body.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    try {
      widget.repository.createPost(
        body: body,
        tickers: List<String>.unmodifiable(_tickers),
        tags: List<String>.unmodifiable(_tags),
        tradeSetup: _buildTradeSetup,
        attachment: _attachment,
        poll: _buildPoll,
        quoted: widget.quotedPost,
        sentiment: _sentiment,
        replyAudience: _replyAudience,
        scheduledFor: _scheduledFor,
        author: widget.author,
      );

      if (!mounted) return;
      UiToast.show(
        context,
        title: _scheduledFor != null ? 'Scheduled!' : 'Posted!',
        message: _scheduledFor != null
            ? 'Post scheduled for ${_scheduledFor!.hour}:${_scheduledFor!.minute}'
            : 'Your setup is now live.',
        intent: UiIntent.success,
      );

      // Reset form state
      setState(() {
        _body = '';
        _tickers.clear();
        _tags.clear();
        _attachment = null;
        _showSetupForm = false;
        _sentiment = null;
        _scheduledFor = null;
        _showPollForm = false;
        _pollQuestionCtrl.clear();
        _pollOpt1Ctrl.clear();
        _pollOpt2Ctrl.clear();
        _setupTickerCtrl.clear();
        _setupEntryCtrl.clear();
        _setupExitCtrl.clear();
        _setupSlCtrl.clear();
        _setupTargetCtrl.clear();
        _tradeSetupSide = 'LONG';
        _replyAudience = CommunityReplyAudience.everyone;
      });

      widget.onPostCreated?.call();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handlePickAttachment() async {
    final AppWritingPostAttachment? picked =
        await CommunityAttachmentPicker.show(
          context,
          repository: widget.repository,
        );
    if (picked != null) {
      setState(() => _attachment = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // Ticker dialog
  // ---------------------------------------------------------------------------

  Future<void> _showTickerDialog() async {
    _tickerInputCtrl.clear();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Add Ticker'),
          content: TextField(
            controller: _tickerInputCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'e.g. RELIANCE, NIFTY, TSLA',
              prefixText: '\$',
            ),
            onSubmitted: (String val) => Navigator.of(ctx).pop(val),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_tickerInputCtrl.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      _addTicker(result);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final double spacingSm = context.sp(theme.spacing.sm);
    final double spacingXs = context.sp(theme.spacing.xs);
    final double spacingMd = context.sp(theme.spacing.md);

    return UiCard(
      padding: EdgeInsets.all(spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ---- Author avatar -----------------------------------------------
          UiAvatar(
            imageUrl: widget.author.avatarUrl,
            name: widget.author.displayName,
            size: isMobile ? UiSize.sm : UiSize.md,
            verified: widget.author.verified,
            verifiedColor: widget.author.verifiedColor(theme),
          ),

          SizedBox(width: spacingSm),

          // ---- Main content column -----------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Body textarea
                UiTextarea(
                  value: _body,
                  hintText: widget.hintText,
                  rows: widget.compact ? 1 : 2,
                  maxRows: 6,
                  showCounter: false,
                  onChanged: (String v) => setState(() => _body = v),
                ),

                // Sentiment & Scheduled badges
                if (_sentiment != null || _scheduledFor != null) ...<Widget>[
                  SizedBox(height: spacingXs),
                  Row(
                    children: [
                      if (_sentiment != null)
                        UiBadge(
                          label: _sentiment == CommunitySentiment.bullish ? 'BULLISH' : 'BEARISH',
                          intent: _sentiment == CommunitySentiment.bullish ? UiIntent.success : UiIntent.danger,
                          variant: UiBadgeVariant.solid,
                          size: UiSize.xs,
                          onRemove: () => setState(() => _sentiment = null),
                        ),
                      if (_scheduledFor != null) ...[
                        SizedBox(width: spacingXs),
                        UiBadge(
                          label: 'Scheduled: ${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}',
                          intent: UiIntent.primary,
                          variant: UiBadgeVariant.soft,
                          size: UiSize.xs,
                          onRemove: () => setState(() => _scheduledFor = null),
                        ),
                      ],
                    ],
                  ),
                ],

                // Ticker badges
                if (_tickers.isNotEmpty) ...<Widget>[
                  SizedBox(height: spacingXs),
                  _TickerBadgeWrap(tickers: _tickers, onRemove: _removeTicker),
                ],

                // Quoted post preview if quoting
                if (widget.quotedPost != null) ...<Widget>[
                  SizedBox(height: spacingSm),
                  CommunityQuoteCard(
                    post: widget.quotedPost!,
                  ),
                ],

                // Poll creation box
                if (_showPollForm) ...<Widget>[
                  SizedBox(height: spacingSm),
                  UiCard(
                    variant: UiCardVariant.surface,
                    padding: EdgeInsets.all(spacingSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Create Poll',
                              style: context.uiText.label.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            UiIconButton(
                              icon: Icons.close,
                              size: UiSize.xs,
                              variant: UiVariant.ghost,
                              onPressed: () => setState(() => _showPollForm = false),
                            ),
                          ],
                        ),
                        SizedBox(height: spacingXs),
                        UiInput(
                          controller: _pollQuestionCtrl,
                          hintText: 'Ask a trading question...',
                          size: UiSize.sm,
                        ),
                        SizedBox(height: spacingXs),
                        UiInput(
                          controller: _pollOpt1Ctrl,
                          hintText: 'Option 1 (e.g. Bullish Breakout)',
                          size: UiSize.sm,
                        ),
                        SizedBox(height: spacingXs),
                        UiInput(
                          controller: _pollOpt2Ctrl,
                          hintText: 'Option 2 (e.g. Bear Trap)',
                          size: UiSize.sm,
                        ),
                      ],
                    ),
                  ),
                ],

                // Trade setup form
                if (_showSetupForm) ...<Widget>[
                  SizedBox(height: spacingSm),
                  _TradeSetupForm(
                    tickerController: _setupTickerCtrl,
                    entryController: _setupEntryCtrl,
                    exitController: _setupExitCtrl,
                    slController: _setupSlCtrl,
                    targetController: _setupTargetCtrl,
                    side: _tradeSetupSide,
                    onSideChanged: (String s) =>
                        setState(() => _tradeSetupSide = s),
                  ),
                ],

                // Selected attachment tile
                if (_attachment != null) ...<Widget>[
                  SizedBox(height: spacingSm),
                  CommunityAttachmentTile(
                    attachment: _attachment!,
                    onRemove: () => setState(() => _attachment = null),
                  ),
                ],

                SizedBox(height: spacingXs),

                // Action row
                _ActionRow(
                  body: _body,
                  submitting: _submitting,
                  showSetupActive: _showSetupForm,
                  showPollActive: _showPollForm,
                  hasAttachment: _attachment != null,
                  hasSentiment: _sentiment != null,
                  replyAudience: _replyAudience,
                  onToggleAudience: () {
                    setState(() {
                      if (_replyAudience == CommunityReplyAudience.everyone) {
                        _replyAudience = CommunityReplyAudience.following;
                      } else if (_replyAudience == CommunityReplyAudience.following) {
                        _replyAudience = CommunityReplyAudience.mentioned;
                      } else {
                        _replyAudience = CommunityReplyAudience.everyone;
                      }
                    });
                    UiToast.show(
                      context,
                      title: 'Reply Audience',
                      message: _replyAudience == CommunityReplyAudience.everyone
                          ? 'Everyone can reply'
                          : (_replyAudience == CommunityReplyAudience.following
                              ? 'Only followed traders can reply'
                              : 'Only mentioned accounts can reply'),
                    );
                  },
                  onToggleSetup: _toggleSetupForm,
                  onTogglePoll: () => setState(() => _showPollForm = !_showPollForm),
                  onToggleSentiment: () {
                    setState(() {
                      if (_sentiment == null) {
                        _sentiment = CommunitySentiment.bullish;
                      } else if (_sentiment == CommunitySentiment.bullish) {
                        _sentiment = CommunitySentiment.bearish;
                      } else {
                        _sentiment = null;
                      }
                    });
                  },
                  onSchedule: () async {
                    final dt = await CommunityScheduleDialog.show(context);
                    if (dt != null) {
                      setState(() => _scheduledFor = dt);
                    }
                  },
                  onPickAttachment: _handlePickAttachment,
                  onAddTicker: _showTickerDialog,
                  onSubmit: (_body.trim().isEmpty && _attachment == null && !_showPollForm)
                      ? null
                      : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TickerBadgeWrap — private
// ---------------------------------------------------------------------------

class _TickerBadgeWrap extends StatelessWidget {
  const _TickerBadgeWrap({required this.tickers, required this.onRemove});

  final List<String> tickers;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.xs);
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: <Widget>[
        for (final String t in tickers)
          UiBadge(
            label: '\$$t',
            intent: UiIntent.primary,
            variant: UiBadgeVariant.soft,
            onRemove: () => onRemove(t),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _TradeSetupForm — private
// ---------------------------------------------------------------------------

class _TradeSetupForm extends StatelessWidget {
  const _TradeSetupForm({
    required this.tickerController,
    required this.entryController,
    required this.exitController,
    required this.slController,
    required this.targetController,
    required this.side,
    required this.onSideChanged,
  });

  final TextEditingController tickerController;
  final TextEditingController entryController;
  final TextEditingController exitController;
  final TextEditingController slController;
  final TextEditingController targetController;
  final String side;
  final ValueChanged<String> onSideChanged;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);
    final bool isMobile = context.uiRes.isMobile;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Form header
          Row(
            children: <Widget>[
              Icon(
                Icons.candlestick_chart_rounded,
                size: context.sz(14),
                color: theme.colors.foregroundMuted,
              ),
              SizedBox(width: gapXs),
              Text(
                'Trade Setup',
                style: context.uiText.label.copyWith(
                  color: theme.colors.foregroundMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          SizedBox(height: gap),

          // Row 1: Ticker + Side toggle
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiInput(
                  controller: tickerController,
                  hintText: 'Ticker (e.g. NIFTY)',
                  leadingIcon: Icons.attach_money_rounded,
                  size: UiSize.sm,
                ),
                SizedBox(height: gapXs),
                _SideToggle(side: side, onChanged: onSideChanged),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: UiInput(
                    controller: tickerController,
                    hintText: 'Ticker (e.g. NIFTY)',
                    leadingIcon: Icons.attach_money_rounded,
                    size: UiSize.sm,
                  ),
                ),
                SizedBox(width: gapXs),
                _SideToggle(side: side, onChanged: onSideChanged),
              ],
            ),

          SizedBox(height: gapXs),

          // Row 2: Entry + Exit
          Row(
            children: <Widget>[
              Expanded(
                child: UiInput(
                  controller: entryController,
                  hintText: 'Entry',
                  prefixText: '₹',
                  size: UiSize.sm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              SizedBox(width: gapXs),
              Expanded(
                child: UiInput(
                  controller: exitController,
                  hintText: 'Exit (opt.)',
                  prefixText: '₹',
                  size: UiSize.sm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: gapXs),

          // Row 3: SL + Target
          Row(
            children: <Widget>[
              Expanded(
                child: UiInput(
                  controller: slController,
                  hintText: 'Stop Loss (opt.)',
                  prefixText: '₹',
                  size: UiSize.sm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  intent: UiIntent.bearish,
                ),
              ),
              SizedBox(width: gapXs),
              Expanded(
                child: UiInput(
                  controller: targetController,
                  hintText: 'Target (opt.)',
                  prefixText: '₹',
                  size: UiSize.sm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  intent: UiIntent.bullish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SideToggle — private
// ---------------------------------------------------------------------------

class _SideToggle extends StatelessWidget {
  const _SideToggle({required this.side, required this.onChanged});

  final String side;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return UiToggleGroup<String>(
      size: UiSize.sm,
      variant: UiToggleGroupVariant.segmented,
      value: side,
      onChanged: onChanged,
      options: const <UiToggleOption<String>>[
        UiToggleOption<String>(
          value: 'LONG',
          label: 'Long',
          intent: UiIntent.bullish,
        ),
        UiToggleOption<String>(
          value: 'SHORT',
          label: 'Short',
          intent: UiIntent.bearish,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ActionRow — private
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.body,
    required this.submitting,
    required this.showSetupActive,
    required this.showPollActive,
    required this.hasAttachment,
    required this.hasSentiment,
    required this.replyAudience,
    required this.onToggleAudience,
    required this.onToggleSetup,
    required this.onTogglePoll,
    required this.onToggleSentiment,
    required this.onSchedule,
    required this.onPickAttachment,
    required this.onAddTicker,
    required this.onSubmit,
  });

  final String body;
  final bool submitting;
  final bool showSetupActive;
  final bool showPollActive;
  final bool hasAttachment;
  final bool hasSentiment;
  final CommunityReplyAudience replyAudience;
  final VoidCallback onToggleAudience;
  final VoidCallback onToggleSetup;
  final VoidCallback onTogglePoll;
  final VoidCallback onToggleSentiment;
  final VoidCallback onSchedule;
  final VoidCallback onPickAttachment;
  final VoidCallback onAddTicker;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int charCount = body.characters.length;
    final bool hasBody = body.trim().isNotEmpty;

    return Row(
      children: <Widget>[
        // Chart setup toggle
        UiIconButton(
          icon: Icons.candlestick_chart_rounded,
          tooltip: showSetupActive ? 'Remove chart setup' : 'Add chart setup',
          size: UiSize.sm,
          variant: showSetupActive ? UiVariant.soft : UiVariant.ghost,
          intent: showSetupActive ? UiIntent.primary : null,
          onPressed: onToggleSetup,
        ),

        SizedBox(width: context.sp(theme.spacing.xxs)),

        // Poll toggle
        UiIconButton(
          icon: Icons.poll_outlined,
          tooltip: showPollActive ? 'Remove poll' : 'Add poll',
          size: UiSize.sm,
          variant: showPollActive ? UiVariant.soft : UiVariant.ghost,
          intent: showPollActive ? UiIntent.primary : null,
          onPressed: onTogglePoll,
        ),

        SizedBox(width: context.sp(theme.spacing.xxs)),

        // Sentiment toggle (Bullish/Bearish)
        UiIconButton(
          icon: Icons.trending_up_rounded,
          tooltip: 'Sentiment (Bullish/Bearish)',
          size: UiSize.sm,
          variant: hasSentiment ? UiVariant.soft : UiVariant.ghost,
          intent: hasSentiment ? UiIntent.success : null,
          onPressed: onToggleSentiment,
        ),

        SizedBox(width: context.sp(theme.spacing.xxs)),

        // Attach record (Notes, Trades, Strategies) - Headline feature
        UiIconButton(
          icon: Icons.link_rounded,
          tooltip: hasAttachment
              ? 'Change attached record'
              : 'Attach record (Note, Trade, Strategy)',
          size: UiSize.sm,
          variant: hasAttachment ? UiVariant.soft : UiVariant.ghost,
          intent: hasAttachment ? UiIntent.primary : null,
          onPressed: onPickAttachment,
        ),

        SizedBox(width: context.sp(theme.spacing.xxs)),

        // Add ticker
        UiIconButton(
          icon: Icons.tag_rounded,
          tooltip: 'Add ticker',
          size: UiSize.sm,
          variant: UiVariant.ghost,
          onPressed: onAddTicker,
        ),

        SizedBox(width: context.sp(theme.spacing.xxs)),

        // Schedule Post
        UiIconButton(
          icon: Icons.schedule_rounded,
          tooltip: 'Schedule Post',
          size: UiSize.sm,
          variant: UiVariant.ghost,
          onPressed: onSchedule,
        ),

        SizedBox(width: context.sp(theme.spacing.xxs)),

        // Reply audience toggle
        UiIconButton(
          icon: replyAudience == CommunityReplyAudience.everyone
              ? Icons.public_rounded
              : (replyAudience == CommunityReplyAudience.following
                  ? Icons.people_outline_rounded
                  : Icons.alternate_email_rounded),
          tooltip: 'Reply audience: ${replyAudience.name}',
          size: UiSize.sm,
          variant: replyAudience != CommunityReplyAudience.everyone ? UiVariant.soft : UiVariant.ghost,
          onPressed: onToggleAudience,
        ),

        const Spacer(),

        // Live character count
        if (hasBody) ...<Widget>[
          Text(
            '$charCount',
            style: context.uiText.caption.copyWith(
              color: charCount > 260
                  ? theme.colors.destructive
                  : theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
        ],

        // Post button
        UiButton(
          label: 'Post',
          size: UiSize.sm,
          loading: submitting,
          expandOnMobile: false,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

