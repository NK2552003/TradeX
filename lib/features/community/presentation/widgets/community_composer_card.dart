import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_picker.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_mention_autocomplete.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_quote_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_schedule_dialog.dart';

// ---------------------------------------------------------------------------
// Composer Creation Mode
// ---------------------------------------------------------------------------

enum ComposerMode {
  post,
  tradeSetup,
  chart,
  poll,
  attachment,
}

// ---------------------------------------------------------------------------
// CommunityComposerCard
// ---------------------------------------------------------------------------

/// A responsive, multi-step Bloomberg/Twitter Pro-grade composer card for TraderHub.
///
/// Features:
/// - Multiple creation modes: Quick Post, Structured Trade Setup, Chart & Vision, Poll, Workspace Attachment.
/// - Live "Preview Mode" toggle: Preview how the post card renders in the feed before publishing.
/// - Live Risk:Reward computation badge and visual proportional category bar.
/// - Instrument selector: Cash Equity, Index Futures, Options Buying, Options Selling, Crypto Perp.
/// - Market Bias, Horizon / Timeframe, and Conviction level selectors.
/// - Integrated `@mentions`, `#hashtags`, and `$cashtags` autocomplete overlay.
/// - Trending tickers and hashtags intelligence bar with instant click-to-append.
/// - Screenshot & chart upload dropzone with technical pattern presets.
/// - Ready-made trader templates (Morning Outlook, Breakout Thesis, Trade Review, Educational).
/// - Interactive poll setup with 2-5 choices, duration, and multi-select toggle.
/// - Character progress ring meter and reply audience management.
class CommunityComposerCard extends StatefulWidget {
  const CommunityComposerCard({
    super.key,
    required this.author,
    required this.repository,
    this.hintText = "What's happening? Share a setup, thesis, or trading lesson…",
    this.onPostCreated,
    this.quotedPost,
    this.compact = false,
  });

  final CommunityAuthor author;
  final CommunityRepository repository;
  final String hintText;
  final VoidCallback? onPostCreated;
  final CommunityPost? quotedPost;

  /// When true the textarea starts at 1 row.
  final bool compact;

  @override
  State<CommunityComposerCard> createState() => _CommunityComposerCardState();
}

class _CommunityComposerCardState extends State<CommunityComposerCard> {
  // ---- Active Mode & Live Preview -------------------------------------------
  ComposerMode _activeMode = ComposerMode.post;
  bool _isPreviewMode = false;

  // ---- Core body -----------------------------------------------------------
  final TextEditingController _bodyCtrl = TextEditingController();
  String _body = '';

  // ---- Attached tickers & tags ---------------------------------------------
  final List<String> _tickers = <String>[];
  final List<String> _tags = <String>[];

  // ---- Attached images & screenshots ---------------------------------------
  final List<String> _imageUrls = <String>[];
  final TextEditingController _chartUrlCtrl = TextEditingController();

  // ---- Attached record (note, journal, strategy) ---------------------------
  AppWritingPostAttachment? _attachment;

  // ---- Advanced Composer Additions -----------------------------------------
  CommunitySentiment? _sentiment;
  String _timeframe = 'Intraday';
  String _conviction = 'Standard';
  DateTime? _scheduledFor;
  CommunityReplyAudience _replyAudience = CommunityReplyAudience.everyone;

  // ---- Trade setup form ----------------------------------------------------
  String _instrumentType = 'Cash Equity';
  final TextEditingController _setupTickerCtrl = TextEditingController();
  String _tradeSetupSide = 'LONG';
  final TextEditingController _setupEntryCtrl = TextEditingController();
  final TextEditingController _setupExitCtrl = TextEditingController();
  final TextEditingController _setupSlCtrl = TextEditingController();
  final TextEditingController _setupTargetCtrl = TextEditingController();
  final TextEditingController _setupCatalystCtrl = TextEditingController();

  // ---- Dynamic Poll form (2 to 5 options) -----------------------------------
  final TextEditingController _pollQuestionCtrl = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  Duration _pollDuration = const Duration(hours: 24);
  bool _pollAllowMultiple = false;

  // ---- Ticker dialog input -------------------------------------------------
  final TextEditingController _tickerInputCtrl = TextEditingController();

  // ---- Trending intelligence quick strip -----------------------------------
  bool _showTrendingStrip = true;

  // ---- Submission state ----------------------------------------------------
  bool _submitting = false;

  // ---- Static Presets & Templates ------------------------------------------
  static const List<String> _trendingCashtags = <String>[
    'NIFTY',
    'BANKNIFTY',
    'RELIANCE',
    'HDFCBANK',
    'BTC',
    'TSLA',
    'GOLD',
  ];

  static const List<String> _trendingHashtags = <String>[
    'Breakout',
    'PriceAction',
    'OptionsSelling',
    'EarningsPlay',
    'RiskManagement',
    'Scalping',
  ];

  static const List<({String title, IconData icon, String text})> _templates = [
    (
      title: 'Daily Market Outlook',
      icon: Icons.wb_sunny_outlined,
      text: "📊 **Daily Market Outlook**\n\n• Key Support & Resistance: \n• Macro Trigger / FII Flow: \n• Sector in Focus: \n• Trading Bias for Today: ",
    ),
    (
      title: 'Breakout Trade Thesis',
      icon: Icons.trending_up_rounded,
      text: "🚀 **Breakout Setup Thesis**\n\n• Technical Catalyst: \n• Volume Confirmation: \n• Invalidation Level: \n• Primary Target: ",
    ),
    (
      title: 'Trade Journal Post-Mortem',
      icon: Icons.menu_book_rounded,
      text: "📝 **Trade Execution Review**\n\n• Setup Executed: \n• What Went Well: \n• Slippage / Mistake: \n• Key Lesson for Next Session: ",
    ),
    (
      title: 'Educational Playbook',
      icon: Icons.school_outlined,
      text: "💡 **Trader Education Playbook**\n\n• Concept: \n• Common Retail Trap: \n• High-Probability Entry Trigger: \n• Capital Preservation Rule: ",
    ),
  ];

  static const List<({String name, String url})> _sampleChartPresets = [
    (
      name: 'Bull Flag Breakout',
      url: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800&auto=format&fit=crop&q=80',
    ),
    (
      name: 'Order Block Sweep',
      url: 'https://images.unsplash.com/photo-1642543492481-44e81e3914a7?w=800&auto=format&fit=crop&q=80',
    ),
    (
      name: 'Volume Weighted Reversal',
      url: 'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=800&auto=format&fit=crop&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bodyCtrl.addListener(_onBodyChanged);
    _setupEntryCtrl.addListener(_onSetupPricesChanged);
    _setupSlCtrl.addListener(_onSetupPricesChanged);
    _setupTargetCtrl.addListener(_onSetupPricesChanged);
  }

  void _onBodyChanged() {
    if (_body != _bodyCtrl.text) {
      setState(() => _body = _bodyCtrl.text);
    }
  }

  void _onSetupPricesChanged() {
    if (_activeMode == ComposerMode.tradeSetup) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _bodyCtrl.removeListener(_onBodyChanged);
    _setupEntryCtrl.removeListener(_onSetupPricesChanged);
    _setupSlCtrl.removeListener(_onSetupPricesChanged);
    _setupTargetCtrl.removeListener(_onSetupPricesChanged);

    _bodyCtrl.dispose();
    _chartUrlCtrl.dispose();
    _setupTickerCtrl.dispose();
    _setupEntryCtrl.dispose();
    _setupExitCtrl.dispose();
    _setupSlCtrl.dispose();
    _setupTargetCtrl.dispose();
    _setupCatalystCtrl.dispose();
    _tickerInputCtrl.dispose();
    _pollQuestionCtrl.dispose();
    for (final ctrl in _pollOptionControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Mentions / Cashtags Autocomplete
  // ---------------------------------------------------------------------------

  String _extractActiveToken() {
    if (_body.isEmpty) return '';
    final selectionEnd = _bodyCtrl.selection.end;
    final textToCursor = selectionEnd >= 0 && selectionEnd <= _body.length
        ? _body.substring(0, selectionEnd)
        : _body;
    final lastSpace = textToCursor.lastIndexOf(RegExp(r'[\s\n]'));
    final token = lastSpace == -1 ? textToCursor : textToCursor.substring(lastSpace + 1);
    if (token.startsWith('@') || token.startsWith('\$') || token.startsWith('#')) {
      return token;
    }
    return '';
  }

  void _replaceActiveToken(String replacement) {
    final selectionEnd = _bodyCtrl.selection.end;
    final textToCursor = selectionEnd >= 0 && selectionEnd <= _bodyCtrl.text.length
        ? _bodyCtrl.text.substring(0, selectionEnd)
        : _bodyCtrl.text;
    final lastSpace = textToCursor.lastIndexOf(RegExp(r'[\s\n]'));
    final prefix = lastSpace == -1 ? '' : textToCursor.substring(0, lastSpace + 1);
    final remaining = selectionEnd >= 0 && selectionEnd <= _bodyCtrl.text.length
        ? _bodyCtrl.text.substring(selectionEnd)
        : '';
    final newText = '$prefix$replacement $remaining';
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: prefix.length + replacement.length + 1),
    );
    setState(() => _body = newText);
  }

  // ---------------------------------------------------------------------------
  // Tickers & Tags Quick Add Helpers
  // ---------------------------------------------------------------------------

  void _removeTicker(String ticker) {
    setState(() => _tickers.remove(ticker));
  }

  void _addTicker(String raw) {
    final String t = raw.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9&]'),
      '',
    );
    if (t.isEmpty || _tickers.contains(t)) return;
    setState(() {
      _tickers.add(t);
      if (!_body.contains('\$$t')) {
        _bodyCtrl.text = _body.isEmpty ? '\$$t ' : '$_body \$$t ';
      }
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _addTag(String raw) {
    final String t = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() {
      _tags.add(t);
      if (!_body.contains('#$t')) {
        _bodyCtrl.text = _body.isEmpty ? '#$t ' : '$_body #$t ';
      }
    });
  }

  void _applyTemplate(String templateText) {
    _bodyCtrl.text = templateText;
    _bodyCtrl.selection = TextSelection.collapsed(offset: templateText.length);
    setState(() => _body = templateText);
    UiToast.show(
      context,
      title: 'Template Applied',
      message: 'Fill in your trading thesis.',
      intent: UiIntent.info,
    );
  }

  void _addImageUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty || _imageUrls.contains(clean)) return;
    setState(() {
      _imageUrls.add(clean);
      _chartUrlCtrl.clear();
    });
    UiToast.show(
      context,
      title: 'Chart Attached',
      message: 'Screenshot added to post.',
      intent: UiIntent.success,
    );
  }

  void _removeImageUrl(String url) {
    setState(() => _imageUrls.remove(url));
  }

  // ---------------------------------------------------------------------------
  // Trade Setup & Poll Builders
  // ---------------------------------------------------------------------------

  bool get _setupFormFilled =>
      _setupTickerCtrl.text.trim().isNotEmpty &&
      _setupEntryCtrl.text.trim().isNotEmpty;

  CommunityTradeSetup? get _buildTradeSetup {
    if (_activeMode != ComposerMode.tradeSetup || !_setupFormFilled) return null;
    return CommunityTradeSetup(
      ticker: _setupTickerCtrl.text.trim().toUpperCase(),
      side: _tradeSetupSide,
      entry: _setupEntryCtrl.text.trim(),
      exit: _setupExitCtrl.text.trim().isEmpty ? null : _setupExitCtrl.text.trim(),
      stopLoss: _setupSlCtrl.text.trim().isEmpty ? null : _setupSlCtrl.text.trim(),
      target: _setupTargetCtrl.text.trim().isEmpty ? null : _setupTargetCtrl.text.trim(),
    );
  }

  CommunityPoll? get _buildPoll {
    if (_activeMode != ComposerMode.poll || _pollQuestionCtrl.text.trim().isEmpty) {
      return null;
    }
    final validOptions = _pollOptionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (validOptions.length < 2) return null;

    return CommunityPoll(
      id: 'poll_${DateTime.now().millisecondsSinceEpoch}',
      question: _pollQuestionCtrl.text.trim(),
      options: [
        for (int i = 0; i < validOptions.length; i++)
          CommunityPollOption(id: 'opt_${i + 1}', text: validOptions[i], votes: 0),
      ],
      expiresAt: DateTime.now().add(_pollDuration),
      allowMultiple: _pollAllowMultiple,
      authorId: widget.author.id,
      authorDisplayName: widget.author.displayName,
      authorAvatarUrl: widget.author.avatarUrl,
    );
  }

  CommunityPost _buildPreviewPost() {
    return CommunityPost(
      id: 'preview_draft',
      author: widget.author,
      body: _body.isEmpty ? 'Your market thesis and analysis will appear here...' : _body,
      createdAt: _scheduledFor ?? DateTime.now(),
      tickers: List<String>.unmodifiable(_tickers),
      tags: List<String>.unmodifiable(_tags),
      tradeSetup: _buildTradeSetup,
      attachment: _attachment,
      poll: _buildPoll,
      quoted: widget.quotedPost,
      sentiment: _sentiment,
      replyAudience: _replyAudience,
      imageUrls: List<String>.unmodifiable(_imageUrls),
      imageUrl: _imageUrls.isNotEmpty ? _imageUrls.first : null,
      scheduledFor: _scheduledFor,
    );
  }

  // ---------------------------------------------------------------------------
  // Submission
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final String body = _body.trim();
    final bool hasSetup = _activeMode == ComposerMode.tradeSetup && _setupFormFilled;
    final bool hasPoll = _activeMode == ComposerMode.poll && _buildPoll != null;
    final bool hasImages = _imageUrls.isNotEmpty;
    final bool hasAttachment = _attachment != null;

    if (body.isEmpty && !hasSetup && !hasPoll && !hasImages && !hasAttachment) {
      UiToast.show(
        context,
        title: 'Empty Post',
        message: 'Please write your thesis or fill out a trade setup.',
        intent: UiIntent.warning,
      );
      return;
    }

    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final finalBody = body.isEmpty ? (hasSetup ? 'Shared setup for \$${_setupTickerCtrl.text.trim().toUpperCase()}' : 'Shared market analysis') : body;

      widget.repository.createPost(
        body: finalBody,
        tickers: List<String>.unmodifiable(_tickers),
        tags: List<String>.unmodifiable(_tags),
        tradeSetup: _buildTradeSetup,
        attachment: _attachment,
        poll: _buildPoll,
        quoted: widget.quotedPost,
        sentiment: _sentiment,
        replyAudience: _replyAudience,
        scheduledFor: _scheduledFor,
        imageUrl: _imageUrls.isNotEmpty ? _imageUrls.first : null,
        imageUrls: List<String>.unmodifiable(_imageUrls),
        author: widget.author,
      );

      if (!mounted) return;
      UiToast.show(
        context,
        title: _scheduledFor != null ? 'Scheduled!' : 'Published!',
        message: _scheduledFor != null
            ? 'Post scheduled for ${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}'
            : 'Your setup is now live in the community feed.',
        intent: UiIntent.success,
      );

      // Reset form state
      setState(() {
        _bodyCtrl.clear();
        _body = '';
        _tickers.clear();
        _tags.clear();
        _imageUrls.clear();
        _chartUrlCtrl.clear();
        _attachment = null;
        _sentiment = null;
        _scheduledFor = null;
        _activeMode = ComposerMode.post;
        _isPreviewMode = false;
        _pollQuestionCtrl.clear();
        for (final c in _pollOptionControllers) {
          c.clear();
        }
        _setupTickerCtrl.clear();
        _setupEntryCtrl.clear();
        _setupExitCtrl.clear();
        _setupSlCtrl.clear();
        _setupTargetCtrl.clear();
        _setupCatalystCtrl.clear();
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
      setState(() {
        _attachment = picked;
        _activeMode = ComposerMode.attachment;
      });
    }
  }

  Future<void> _showTickerDialog() async {
    _tickerInputCtrl.clear();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return UiDialog(
          title: 'Add Cashtag',
          content: UiInput(
            controller: _tickerInputCtrl,
            autofocus: true,
            leadingIcon: Icons.attach_money_rounded,
            hintText: 'e.g. RELIANCE, NIFTY, TSLA',
            onSubmitted: (String val) => Navigator.of(ctx).pop(val),
          ),
          actions: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.ghost,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Add Cashtag',
              onPressed: () => Navigator.of(ctx).pop(_tickerInputCtrl.text),
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
    final isMobile = context.uiRes.isMobile;
    final isDesktop = context.uiRes.isDesktop;
    final double spacingSm = context.sp(theme.spacing.sm);
    final double spacingXs = context.sp(theme.spacing.xs);
    final double spacingMd = context.sp(theme.spacing.md);

    final activeToken = _extractActiveToken();

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(isMobile ? spacingSm : spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ---- Step 1: Mode Switcher & Top Utility Bar ----------------------
          _buildTopHeaderBar(theme, isMobile),

          SizedBox(height: spacingSm),

          // ---- Step 2: Main Body or Live Preview ----------------------------
          if (_isPreviewMode) ...[
            _buildLivePreviewCard(theme, isMobile),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Author avatar
                UiAvatar(
                  imageUrl: widget.author.avatarUrl,
                  name: widget.author.displayName,
                  size: isMobile ? UiSize.sm : UiSize.md,
                  verified: widget.author.verified,
                  verifiedColor: widget.author.verifiedColor(theme),
                ),

                SizedBox(width: spacingSm),

                // Content & Inputs
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Textarea
                      UiTextarea(
                        controller: _bodyCtrl,
                        hintText: _getHintForMode(),
                        rows: widget.compact ? 2 : (isMobile ? 2 : 3),
                        maxRows: 7,
                        showCounter: false,
                      ),

                      // Mention / Cashtag / Hashtag Autocomplete Dropdown
                      if (activeToken.isNotEmpty) ...<Widget>[
                        SizedBox(height: spacingXs),
                        CommunityMentionAutocomplete(
                          query: activeToken,
                          traders: widget.repository.topTraders,
                          onSelectTrader: (trader) => _replaceActiveToken('@${trader.handle}'),
                          onSelectTicker: (ticker) {
                            _replaceActiveToken('\$$ticker');
                            _addTicker(ticker);
                          },
                          onSelectTag: (tag) {
                            _replaceActiveToken('#$tag');
                            _addTag(tag);
                          },
                        ),
                      ],

                      // Trending Tickers & Hashtags Intelligence Strip
                      if (_showTrendingStrip) ...<Widget>[
                        SizedBox(height: spacingXs),
                        _buildTrendingStrip(theme),
                      ],

                      // Active Badges Row: Sentiment, Timeframe, Conviction, Tickers, Tags
                      _buildActiveBadgesRow(theme, spacingXs),

                      // Quoted post preview if quoting
                      if (widget.quotedPost != null) ...<Widget>[
                        SizedBox(height: spacingSm),
                        CommunityQuoteCard(post: widget.quotedPost!),
                      ],

                      // Mode 1: Structured Trade Setup Form
                      if (_activeMode == ComposerMode.tradeSetup) ...<Widget>[
                        SizedBox(height: spacingSm),
                        _buildTradeSetupCard(theme, isMobile),
                      ],

                      // Mode 2: Chart & Vision Screenshot Studio
                      if (_activeMode == ComposerMode.chart || _imageUrls.isNotEmpty) ...<Widget>[
                        SizedBox(height: spacingSm),
                        _buildChartStudioCard(theme, isMobile),
                      ],

                      // Mode 3: Poll Form with dynamic choices & demographics
                      if (_activeMode == ComposerMode.poll) ...<Widget>[
                        SizedBox(height: spacingSm),
                        _buildPollCard(theme, isMobile),
                      ],

                      // Mode 4: Attachment Form (Note, Journal, Strategy)
                      if (_activeMode == ComposerMode.attachment || _attachment != null) ...<Widget>[
                        SizedBox(height: spacingSm),
                        _buildAttachmentCard(theme, isMobile),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: spacingSm),
          UiDivider(spacing: spacingXs),
          SizedBox(height: spacingXs),

          // ---- Bottom Action Toolbar ----------------------------------------
          _buildActionRow(theme, isMobile, isDesktop),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header: Mode Selector, Templates & Live Preview Switcher
  // ---------------------------------------------------------------------------

  Widget _buildTopHeaderBar(UiTheme theme, bool isMobile) {
    final double gapXs = context.sp(theme.spacing.xs);

    return Row(
      children: [
        // Mode Selector Scroll
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ModePill(
                  icon: Icons.edit_note_rounded,
                  label: 'Thesis',
                  selected: _activeMode == ComposerMode.post,
                  onTap: () => setState(() {
                    _activeMode = ComposerMode.post;
                    _isPreviewMode = false;
                  }),
                ),
                SizedBox(width: gapXs),
                _ModePill(
                  icon: Icons.candlestick_chart_rounded,
                  label: 'Trade Setup',
                  selected: _activeMode == ComposerMode.tradeSetup,
                  onTap: () => setState(() {
                    _activeMode = ComposerMode.tradeSetup;
                    _isPreviewMode = false;
                  }),
                ),
                SizedBox(width: gapXs),
                _ModePill(
                  icon: Icons.image_search_rounded,
                  label: _imageUrls.isNotEmpty ? 'Chart (${_imageUrls.length})' : 'Chart & Vision',
                  selected: _activeMode == ComposerMode.chart,
                  onTap: () => setState(() {
                    _activeMode = ComposerMode.chart;
                    _isPreviewMode = false;
                  }),
                ),
                SizedBox(width: gapXs),
                _ModePill(
                  icon: Icons.poll_outlined,
                  label: 'Poll',
                  selected: _activeMode == ComposerMode.poll,
                  onTap: () => setState(() {
                    _activeMode = ComposerMode.poll;
                    _isPreviewMode = false;
                  }),
                ),
                SizedBox(width: gapXs),
                _ModePill(
                  icon: Icons.attach_file_rounded,
                  label: _attachment != null ? 'Record' : 'Attach Record',
                  selected: _activeMode == ComposerMode.attachment,
                  onTap: () => setState(() {
                    _activeMode = ComposerMode.attachment;
                    _isPreviewMode = false;
                  }),
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: gapXs),

        // Quick Starter Templates Menu
        UiDropdownMenu(
          items: [
            for (final t in _templates)
              UiMenuItem(
                label: t.title,
                icon: t.icon,
                onTap: () => _applyTemplate(t.text),
              ),
          ],
          child: UiButton(
            label: isMobile ? '' : 'Templates',
            leadingIcon: Icons.auto_awesome_rounded,
            size: UiSize.xs,
            variant: UiVariant.ghost,
          ),
        ),

        SizedBox(width: gapXs),

        // Live Preview Toggle Pill
        InkWell(
          onTap: () => setState(() => _isPreviewMode = !_isPreviewMode),
          borderRadius: context.radius(theme.radii.pill),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.xxs),
            ),
            decoration: BoxDecoration(
              color: _isPreviewMode
                  ? theme.colors.primary.withValues(alpha: 0.15)
                  : theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: _isPreviewMode ? theme.colors.primary : theme.colors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPreviewMode ? Icons.edit_rounded : Icons.visibility_outlined,
                  size: context.sz(13),
                  color: _isPreviewMode ? theme.colors.primary : theme.colors.foregroundMuted,
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
                Text(
                  _isPreviewMode ? 'Edit' : 'Preview',
                  style: context.uiText.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isPreviewMode ? theme.colors.primary : theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Live Feed Preview View
  // ---------------------------------------------------------------------------

  Widget _buildLivePreviewCard(UiTheme theme, bool isMobile) {
    final previewPost = _buildPreviewPost();
    final double gapXs = context.sp(theme.spacing.xs);
    final double gapSm = context.sp(theme.spacing.sm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.remove_red_eye_outlined, size: context.sz(15), color: theme.colors.primary),
                SizedBox(width: gapXs),
                Text(
                  'Live Feed Preview (How other traders will see this)',
                  style: context.uiText.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
            UiButton(
              label: 'Back to Edit',
              size: UiSize.xs,
              variant: UiVariant.ghost,
              onPressed: () => setState(() => _isPreviewMode = false),
            ),
          ],
        ),
        SizedBox(height: gapSm),
        CommunityPostCard(
          post: previewPost,
          variant: CommunityPostCardVariant.boxed,
          repository: widget.repository,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Trending Intelligence Strip
  // ---------------------------------------------------------------------------

  Widget _buildTrendingStrip(UiTheme theme) {
    final double gapXs = context.sp(theme.spacing.xs);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Quick Add: ',
            style: context.uiText.caption.copyWith(
              fontSize: context.fs(11),
              color: theme.colors.foregroundMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final t in _trendingCashtags) ...[
            InkWell(
              onTap: () => _addTicker(t),
              borderRadius: context.radius(theme.radii.sm),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                  vertical: 2,
                ),
                margin: EdgeInsets.only(right: gapXs),
                decoration: BoxDecoration(
                  color: theme.colors.primary.withValues(alpha: 0.08),
                  borderRadius: context.radius(theme.radii.sm),
                  border: Border.all(
                    color: theme.colors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '+\$$t',
                  style: context.uiText.caption.copyWith(
                    fontSize: context.fs(11),
                    color: theme.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          for (final tag in _trendingHashtags) ...[
            InkWell(
              onTap: () => _addTag(tag),
              borderRadius: context.radius(theme.radii.sm),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                  vertical: 2,
                ),
                margin: EdgeInsets.only(right: gapXs),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.sm),
                  border: Border.all(
                    color: theme.colors.border,
                  ),
                ),
                child: Text(
                  '+#$tag',
                  style: context.uiText.caption.copyWith(
                    fontSize: context.fs(11),
                    color: theme.colors.foregroundMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Badges Row
  // ---------------------------------------------------------------------------

  Widget _buildActiveBadgesRow(UiTheme theme, double spacingXs) {
    final hasBadges = _sentiment != null ||
        _scheduledFor != null ||
        _tickers.isNotEmpty ||
        _tags.isNotEmpty ||
        _imageUrls.isNotEmpty ||
        _activeMode == ComposerMode.tradeSetup;

    if (!hasBadges) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: spacingXs),
      child: Wrap(
        spacing: spacingXs,
        runSpacing: spacingXs,
        children: [
          if (_sentiment != null)
            UiBadge(
              label: _sentiment == CommunitySentiment.bullish
                  ? 'BULLISH'
                  : (_sentiment == CommunitySentiment.bearish ? 'BEARISH' : 'NEUTRAL'),
              intent: _sentiment == CommunitySentiment.bullish
                  ? UiIntent.success
                  : (_sentiment == CommunitySentiment.bearish ? UiIntent.danger : UiIntent.info),
              variant: UiBadgeVariant.solid,
              size: UiSize.xs,
              onRemove: () => setState(() => _sentiment = null),
            ),
          UiBadge(
            label: _timeframe,
            intent: UiIntent.primary,
            variant: UiBadgeVariant.soft,
            size: UiSize.xs,
          ),
          if (_conviction != 'Standard')
            UiBadge(
              label: _conviction,
              intent: UiIntent.warning,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
            ),
          if (_scheduledFor != null)
            UiBadge(
              label: 'Scheduled: ${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}',
              intent: UiIntent.primary,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
              onRemove: () => setState(() => _scheduledFor = null),
            ),
          for (final String t in _tickers)
            UiBadge(
              label: '\$$t',
              intent: UiIntent.primary,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
              onRemove: () => _removeTicker(t),
            ),
          for (final String tag in _tags)
            UiBadge(
              label: '#$tag',
              intent: UiIntent.warning,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
              onRemove: () => _removeTag(tag),
            ),
          if (_imageUrls.isNotEmpty)
            UiBadge(
              label: '${_imageUrls.length} Chart Image${_imageUrls.length > 1 ? "s" : ""}',
              intent: UiIntent.info,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
            ),
        ],
      ),
    );
  }

  String _getHintForMode() {
    switch (_activeMode) {
      case ComposerMode.tradeSetup:
        return 'Outline your setup thesis, execution trigger, and risk plan...';
      case ComposerMode.chart:
        return 'Describe the key chart patterns, support/resistance, or volume indicators shown...';
      case ComposerMode.poll:
        return 'Provide context and key questions to accompany your community poll...';
      case ComposerMode.attachment:
        return 'Summarize the attached workspace record and key insights for other traders...';
      case ComposerMode.post:
        return widget.hintText;
    }
  }

  // ---------------------------------------------------------------------------
  // Mode: Structured Trade Setup Card
  // ---------------------------------------------------------------------------

  Widget _buildTradeSetupCard(UiTheme theme, bool isMobile) {
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);

    final rrMetrics = _computeRiskReward();

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header with Side and R:R Badge
          Row(
            children: <Widget>[
              Icon(
                Icons.candlestick_chart_rounded,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              SizedBox(width: gapXs),
              Text(
                'Professional Financial Setup',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foreground,
                ),
              ),
              const Spacer(),
              if (rrMetrics.badge != null) rrMetrics.badge!,
            ],
          ),

          SizedBox(height: gap),

          // Instrument Selector Segmented Control
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final inst in <String>['Cash Equity', 'Index Futures', 'Options Buying', 'Options Selling', 'Crypto Perp']) ...[
                  InkWell(
                    onTap: () => setState(() => _instrumentType = inst),
                    borderRadius: context.radius(theme.radii.pill),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.sm),
                        vertical: context.sp(theme.spacing.xxs),
                      ),
                      margin: EdgeInsets.only(right: gapXs),
                      decoration: BoxDecoration(
                        color: _instrumentType == inst
                            ? theme.colors.primary.withValues(alpha: 0.15)
                            : theme.colors.surfaceMuted,
                        borderRadius: context.radius(theme.radii.pill),
                        border: Border.all(
                          color: _instrumentType == inst ? theme.colors.primary : theme.colors.border,
                        ),
                      ),
                      child: Text(
                        inst,
                        style: context.uiText.caption.copyWith(
                          fontSize: context.fs(11),
                          fontWeight: _instrumentType == inst ? FontWeight.w600 : FontWeight.w500,
                          color: _instrumentType == inst ? theme.colors.primary : theme.colors.foregroundMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: gap),

          // Row 1: Ticker + Long/Short Toggle
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiInput(
                  controller: _setupTickerCtrl,
                  hintText: 'Ticker (e.g. NIFTY, RELIANCE, TSLA)',
                  leadingIcon: Icons.attach_money_rounded,
                  size: UiSize.sm,
                ),
                SizedBox(height: gapXs),
                _SideToggle(
                  side: _tradeSetupSide,
                  onChanged: (s) => setState(() => _tradeSetupSide = s),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: UiInput(
                    controller: _setupTickerCtrl,
                    hintText: 'Ticker (e.g. NIFTY, RELIANCE, TSLA)',
                    leadingIcon: Icons.attach_money_rounded,
                    size: UiSize.sm,
                  ),
                ),
                SizedBox(width: gapXs),
                _SideToggle(
                  side: _tradeSetupSide,
                  onChanged: (s) => setState(() => _tradeSetupSide = s),
                ),
              ],
            ),

          SizedBox(height: gapXs),

          // Row 2: Entry + Exit
          Row(
            children: <Widget>[
              Expanded(
                child: UiInput(
                  controller: _setupEntryCtrl,
                  hintText: 'Entry Price',
                  prefixText: '₹',
                  size: UiSize.sm,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              SizedBox(width: gapXs),
              Expanded(
                child: UiInput(
                  controller: _setupExitCtrl,
                  hintText: 'Exit / Trailing (Optional)',
                  prefixText: '₹',
                  size: UiSize.sm,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),

          SizedBox(height: gapXs),

          // Row 3: Stop Loss + Target
          Row(
            children: <Widget>[
              Expanded(
                child: UiInput(
                  controller: _setupSlCtrl,
                  hintText: 'Stop Loss (SL)',
                  prefixText: '₹',
                  size: UiSize.sm,
                  intent: UiIntent.bearish,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              SizedBox(width: gapXs),
              Expanded(
                child: UiInput(
                  controller: _setupTargetCtrl,
                  hintText: 'Target / Take Profit',
                  prefixText: '₹',
                  size: UiSize.sm,
                  intent: UiIntent.bullish,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),

          // Live Risk:Reward Visual Proportion Bar
          if (rrMetrics.isValid) ...[
            SizedBox(height: gap),
            Container(
              padding: EdgeInsets.all(gapXs),
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.sm),
                border: Border.all(color: theme.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Risk: ${rrMetrics.riskPct.toStringAsFixed(2)}% (₹${rrMetrics.riskPoints.toStringAsFixed(2)})',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: context.fs(11),
                        ),
                      ),
                      Text(
                        'Reward: +${rrMetrics.rewardPct.toStringAsFixed(2)}% (₹${rrMetrics.rewardPoints.toStringAsFixed(2)})',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: context.fs(11),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  UiCategoryBar(
                    showLegend: false,
                    thickness: 6,
                    segments: [
                      UiCategorySegment(
                        value: rrMetrics.riskPoints,
                        label: 'Risk',
                        color: theme.colors.danger,
                      ),
                      UiCategorySegment(
                        value: rrMetrics.rewardPoints,
                        label: 'Reward',
                        color: theme.colors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: gapXs),

          // Setup Invalidation Trigger
          UiInput(
            controller: _setupCatalystCtrl,
            hintText: 'Invalidation trigger (e.g. 15m candle close below support)...',
            leadingIcon: Icons.shield_outlined,
            size: UiSize.xs,
          ),
        ],
      ),
    );
  }

  ({bool isValid, double riskPoints, double rewardPoints, double riskPct, double rewardPct, Widget? badge}) _computeRiskReward() {
    final entry = double.tryParse(_setupEntryCtrl.text.trim());
    final sl = double.tryParse(_setupSlCtrl.text.trim());
    final target = double.tryParse(_setupTargetCtrl.text.trim());

    if (entry == null || sl == null || target == null || entry <= 0) {
      return (isValid: false, riskPoints: 0, rewardPoints: 0, riskPct: 0, rewardPct: 0, badge: null);
    }

    double risk = 0;
    double reward = 0;
    if (_tradeSetupSide == 'LONG') {
      risk = entry - sl;
      reward = target - entry;
    } else {
      risk = sl - entry;
      reward = entry - target;
    }

    if (risk <= 0 || reward <= 0) {
      return (
        isValid: false,
        riskPoints: 0,
        rewardPoints: 0,
        riskPct: 0,
        rewardPct: 0,
        badge: const UiBadge(
          label: 'Invalid Setup R:R',
          intent: UiIntent.danger,
          variant: UiBadgeVariant.soft,
          size: UiSize.xs,
        ),
      );
    }

    final ratio = reward / risk;
    final riskPct = (risk / entry) * 100;
    final rewardPct = (reward / entry) * 100;

    final intent = ratio >= 2.0 ? UiIntent.success : (ratio >= 1.0 ? UiIntent.warning : UiIntent.danger);
    return (
      isValid: true,
      riskPoints: risk,
      rewardPoints: reward,
      riskPct: riskPct,
      rewardPct: rewardPct,
      badge: UiBadge(
        label: 'R:R 1 : ${ratio.toStringAsFixed(2)}',
        intent: intent,
        variant: UiBadgeVariant.solid,
        size: UiSize.xs,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mode: Chart & Vision Screenshot Studio
  // ---------------------------------------------------------------------------

  Widget _buildChartStudioCard(UiTheme theme, bool isMobile) {
    final double gap = context.sp(theme.spacing.sm);
    final double gapSm = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.insert_photo_outlined, size: context.sz(16), color: theme.colors.primary),
                  SizedBox(width: gapXs),
                  Text(
                    'Chart Screenshot & Technical Vision',
                    style: context.uiText.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colors.foreground,
                    ),
                  ),
                ],
              ),
              UiIconButton(
                icon: Icons.close,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: () => setState(() => _activeMode = ComposerMode.post),
              ),
            ],
          ),

          SizedBox(height: gapXs),
          Text(
            'Upload or attach TradingView / broker chart screenshots to validate your thesis:',
            style: context.uiText.caption.copyWith(color: theme.colors.foregroundMuted),
          ),
          SizedBox(height: gap),

          // Dropzone for upload
          UiDropzone(
            title: 'Drop TradingView or Broker Chart',
            message: 'PNG, JPG, or WebP up to 10 MB',
            icon: Icons.add_photo_alternate_outlined,
            onPick: () {
              // Simulated pick: Attach top chart preset or prompt URL
              _addImageUrl(_sampleChartPresets.first.url);
            },
          ),

          SizedBox(height: gapSm),

          // Direct URL input
          Row(
            children: [
              Expanded(
                child: UiInput(
                  controller: _chartUrlCtrl,
                  hintText: 'Paste Image URL (TradingView snapshot link)...',
                  leadingIcon: Icons.link_rounded,
                  size: UiSize.sm,
                  onSubmitted: _addImageUrl,
                ),
              ),
              SizedBox(width: gapXs),
              UiButton(
                label: 'Attach',
                size: UiSize.sm,
                variant: UiVariant.soft,
                onPressed: () => _addImageUrl(_chartUrlCtrl.text),
              ),
            ],
          ),

          SizedBox(height: gapSm),

          // Sample Technical Chart Presets
          Text(
            'Or select sample technical setup:',
            style: context.uiText.caption.copyWith(
              fontSize: context.fs(11),
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: gapXs),
          Wrap(
            spacing: gapXs,
            runSpacing: gapXs,
            children: [
              for (final preset in _sampleChartPresets)
                UiButton(
                  label: preset.name,
                  size: UiSize.xs,
                  variant: UiVariant.outline,
                  onPressed: () => _addImageUrl(preset.url),
                ),
            ],
          ),

          // Attached Images Gallery
          if (_imageUrls.isNotEmpty) ...[
            SizedBox(height: gap),
            UiDivider(spacing: gapXs),
            SizedBox(height: gapXs),
            Text(
              'Attached Images (${_imageUrls.length}):',
              style: context.uiText.label.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colors.foreground,
              ),
            ),
            SizedBox(height: gapXs),
            Wrap(
              spacing: gapXs,
              runSpacing: gapXs,
              children: [
                for (final url in _imageUrls)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: context.radius(theme.radii.sm),
                        child: Container(
                          width: context.sz(90),
                          height: context.sz(60),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colors.border),
                          ),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(Icons.broken_image_outlined, size: context.sz(20)),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () => _removeImageUrl(url),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: context.sz(12),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mode: Poll Card (2-5 options, duration, multi-select)
  // ---------------------------------------------------------------------------

  Widget _buildPollCard(UiTheme theme, bool isMobile) {
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.poll_rounded, size: context.sz(16), color: theme.colors.primary),
                  SizedBox(width: gapXs),
                  Text(
                    'Democratic Community Poll',
                    style: context.uiText.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colors.foreground,
                    ),
                  ),
                ],
              ),
              UiIconButton(
                icon: Icons.close,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: () => setState(() => _activeMode = ComposerMode.post),
              ),
            ],
          ),
          SizedBox(height: gapXs),
          UiInput(
            controller: _pollQuestionCtrl,
            hintText: 'Ask your market consensus question (e.g. NIFTY expiry bias?)...',
            size: UiSize.sm,
          ),
          SizedBox(height: gapXs),

          // Options List
          for (int i = 0; i < _pollOptionControllers.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: UiInput(
                    controller: _pollOptionControllers[i],
                    hintText: 'Choice ${i + 1} (e.g. ${i == 0 ? "Bullish Breakout" : i == 1 ? "Bear Trap" : "Consolidation"})',
                    size: UiSize.sm,
                  ),
                ),
                if (_pollOptionControllers.length > 2) ...[
                  SizedBox(width: gapXs),
                  UiIconButton(
                    icon: Icons.remove_circle_outline,
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                    intent: UiIntent.danger,
                    onPressed: () {
                      setState(() {
                        _pollOptionControllers.removeAt(i).dispose();
                      });
                    },
                  ),
                ],
              ],
            ),
            SizedBox(height: gapXs),
          ],

          // Add Option button (up to 5 options)
          if (_pollOptionControllers.length < 5) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: UiButton(
                label: '+ Add Choice',
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: () {
                  setState(() {
                    _pollOptionControllers.add(TextEditingController());
                  });
                },
              ),
            ),
            SizedBox(height: gapXs),
          ],

          UiDivider(spacing: gapXs),

          // Settings: Duration & Multiple Choice
          Wrap(
            spacing: gap,
            runSpacing: gapXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Duration: ', style: context.uiText.caption),
                  UiToggleGroup<int>(
                    size: UiSize.xs,
                    value: _pollDuration.inHours,
                    onChanged: (hours) => setState(() => _pollDuration = Duration(hours: hours)),
                    options: const [
                      UiToggleOption(value: 6, label: '6h'),
                      UiToggleOption(value: 24, label: '24h'),
                      UiToggleOption(value: 72, label: '3d'),
                      UiToggleOption(value: 168, label: '7d'),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UiToggle(
                    value: _pollAllowMultiple,
                    onChanged: (v) => setState(() => _pollAllowMultiple = v),
                  ),
                  SizedBox(width: gapXs),
                  Text('Multiple answers', style: context.uiText.caption),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mode: Attachment Card (Note, Journal, Strategy)
  // ---------------------------------------------------------------------------

  Widget _buildAttachmentCard(UiTheme theme, bool isMobile) {
    final double gap = context.sp(theme.spacing.sm);
    final double gapXs = context.sp(theme.spacing.xs);

    if (_attachment != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommunityAttachmentTile(
            attachment: _attachment!,
            onRemove: () => setState(() => _attachment = null),
          ),
        ],
      );
    }

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.library_books_rounded, size: context.sz(16), color: theme.colors.primary),
                  SizedBox(width: gapXs),
                  Text(
                    'Attach or Create Workspace Record',
                    style: context.uiText.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colors.foreground,
                    ),
                  ),
                ],
              ),
              UiIconButton(
                icon: Icons.close,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: () => setState(() => _activeMode = ComposerMode.post),
              ),
            ],
          ),
          SizedBox(height: gapXs),
          Text(
            'Attach a research Note, an executed Journal Trade, or an algorithmic Strategy directly to this post:',
            style: context.uiText.caption.copyWith(color: theme.colors.foregroundMuted),
          ),
          SizedBox(height: gap),

          // Shortcut buttons
          Wrap(
            spacing: gapXs,
            runSpacing: gapXs,
            children: [
              UiButton(
                label: 'Browse Workspace Records',
                leadingIcon: Icons.folder_open_rounded,
                size: UiSize.sm,
                variant: UiVariant.outline,
                onPressed: _handlePickAttachment,
              ),
              UiButton(
                label: '+ New Note',
                leadingIcon: Icons.note_add_outlined,
                size: UiSize.sm,
                variant: UiVariant.ghost,
                onPressed: () => _quickCreateInline(theme, 'Note'),
              ),
              UiButton(
                label: '+ New Trade',
                leadingIcon: Icons.show_chart_rounded,
                size: UiSize.sm,
                variant: UiVariant.ghost,
                onPressed: () => _quickCreateInline(theme, 'Trade'),
              ),
              UiButton(
                label: '+ New Strategy',
                leadingIcon: Icons.psychology_outlined,
                size: UiSize.sm,
                variant: UiVariant.ghost,
                onPressed: () => _quickCreateInline(theme, 'Strategy'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickCreateInline(UiTheme theme, String type) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return UiDialog(
          title: 'Create & Attach $type',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiInput(
                controller: titleCtrl,
                hintText: '$type Title or Symbol...',
                autofocus: true,
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              UiInput(
                controller: descCtrl,
                hintText: 'Key summary or rationale...',
              ),
            ],
          ),
          actions: [
            UiButton(
              label: 'Cancel',
              variant: UiVariant.ghost,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            UiButton(
              label: 'Create & Attach',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && titleCtrl.text.trim().isNotEmpty) {
      final id = '${type.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
      final title = titleCtrl.text.trim();
      final desc = descCtrl.text.trim().isEmpty ? 'Created via Community' : descCtrl.text.trim();

      final AppLinkKind kind;
      if (type.toLowerCase() == 'trade') {
        kind = AppLinkKind.journal;
      } else if (type.toLowerCase() == 'strategy') {
        kind = AppLinkKind.strategy;
      } else {
        kind = AppLinkKind.note;
      }

      final record = AppWritingPostAttachment.manual(
        source: AppLinkRef(
          kind: kind,
          id: id,
          title: title,
        ),
        excerpt: desc,
        updatedAt: DateTime.now(),
      );

      widget.repository.addAttachableRecord(record);
      setState(() {
        _attachment = record;
        _activeMode = ComposerMode.attachment;
      });

      if (mounted) {
        UiToast.show(
          context,
          title: '$type Created',
          message: 'Attached to your post.',
          intent: UiIntent.success,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Action Row
  // ---------------------------------------------------------------------------

  Widget _buildActionRow(UiTheme theme, bool isMobile, bool isDesktop) {
    final int charCount = _body.characters.length;
    final bool hasBody = _body.trim().isNotEmpty;
    final double charRatio = (charCount / 500).clamp(0.0, 1.0);

    return Row(
      children: <Widget>[
        // Quick Cashtag ($)
        UiIconButton(
          icon: Icons.attach_money_rounded,
          tooltip: 'Add Cashtag (\$TICKER)',
          size: UiSize.sm,
          variant: UiVariant.ghost,
          onPressed: _showTickerDialog,
        ),

        // Quick Tag (#)
        UiIconButton(
          icon: Icons.tag_rounded,
          tooltip: 'Toggle Trending Strip',
          size: UiSize.sm,
          variant: _showTrendingStrip ? UiVariant.soft : UiVariant.ghost,
          onPressed: () => setState(() => _showTrendingStrip = !_showTrendingStrip),
        ),

        // Sentiment Menu (Bullish, Bearish, Neutral)
        UiDropdownMenu(
          items: [
            UiMenuItem(
              label: 'Bullish Bias',
              icon: Icons.trending_up_rounded,
              intent: UiIntent.success,
              onTap: () => setState(() => _sentiment = CommunitySentiment.bullish),
            ),
            UiMenuItem(
              label: 'Bearish Bias',
              icon: Icons.trending_down_rounded,
              intent: UiIntent.danger,
              onTap: () => setState(() => _sentiment = CommunitySentiment.bearish),
            ),
            UiMenuItem(
              label: 'Neutral / Rangebound',
              icon: Icons.trending_flat_rounded,
              intent: UiIntent.info,
              onTap: () => setState(() => _sentiment = CommunitySentiment.neutral),
            ),
            if (_sentiment != null)
              UiMenuItem(
                label: 'Clear Sentiment',
                icon: Icons.close_rounded,
                destructive: true,
                onTap: () => setState(() => _sentiment = null),
              ),
          ],
          child: UiIconButton(
            icon: _sentiment?.icon ?? Icons.trending_up_rounded,
            tooltip: 'Market Bias (${_sentiment?.label ?? "Select"})',
            size: UiSize.sm,
            variant: _sentiment != null ? UiVariant.soft : UiVariant.ghost,
            intent: _sentiment == CommunitySentiment.bullish
                ? UiIntent.success
                : (_sentiment == CommunitySentiment.bearish ? UiIntent.danger : null),
          ),
        ),

        // Timeframe Horizon Menu
        UiDropdownMenu(
          items: [
            for (final tf in ['15m Scalp', 'Intraday', 'Daily Swing', 'Weekly Macro'])
              UiMenuItem(
                label: tf,
                selected: _timeframe == tf,
                onTap: () => setState(() => _timeframe = tf),
              ),
          ],
          child: UiIconButton(
            icon: Icons.schedule_outlined,
            tooltip: 'Timeframe Horizon: $_timeframe',
            size: UiSize.sm,
            variant: UiVariant.ghost,
          ),
        ),

        // Conviction Level Menu
        UiDropdownMenu(
          items: [
            UiMenuItem(
              label: '1★ Speculative',
              selected: _conviction == 'Speculative',
              onTap: () => setState(() => _conviction = 'Speculative'),
            ),
            UiMenuItem(
              label: '2★ Standard Setup',
              selected: _conviction == 'Standard',
              onTap: () => setState(() => _conviction = 'Standard'),
            ),
            UiMenuItem(
              label: '3★ High Conviction 🔥',
              selected: _conviction == 'High Conviction 🔥',
              onTap: () => setState(() => _conviction = 'High Conviction 🔥'),
            ),
          ],
          child: UiIconButton(
            icon: Icons.local_fire_department_outlined,
            tooltip: 'Conviction: $_conviction',
            size: UiSize.sm,
            variant: _conviction != 'Standard' ? UiVariant.soft : UiVariant.ghost,
            intent: _conviction.contains('🔥') ? UiIntent.warning : null,
          ),
        ),

        // Image / Chart Screenshot Shortcut
        UiIconButton(
          icon: Icons.image_outlined,
          tooltip: 'Attach Chart Screenshot',
          size: UiSize.sm,
          variant: _imageUrls.isNotEmpty ? UiVariant.soft : UiVariant.ghost,
          onPressed: () => setState(() => _activeMode = ComposerMode.chart),
        ),

        // Schedule Post
        UiIconButton(
          icon: Icons.event_available_outlined,
          tooltip: 'Schedule Post',
          size: UiSize.sm,
          variant: _scheduledFor != null ? UiVariant.soft : UiVariant.ghost,
          intent: _scheduledFor != null ? UiIntent.primary : null,
          onPressed: () async {
            final dt = await CommunityScheduleDialog.show(context);
            if (dt != null) {
              setState(() => _scheduledFor = dt);
            }
          },
        ),

        // Reply Audience Selector
        UiDropdownMenu(
          items: [
            UiMenuItem(
              label: 'Everyone can reply',
              icon: Icons.public_rounded,
              selected: _replyAudience == CommunityReplyAudience.everyone,
              onTap: () => setState(() => _replyAudience = CommunityReplyAudience.everyone),
            ),
            UiMenuItem(
              label: 'Followed traders only',
              icon: Icons.people_outline_rounded,
              selected: _replyAudience == CommunityReplyAudience.following,
              onTap: () => setState(() => _replyAudience = CommunityReplyAudience.following),
            ),
            UiMenuItem(
              label: 'Mentioned traders only',
              icon: Icons.alternate_email_rounded,
              selected: _replyAudience == CommunityReplyAudience.mentioned,
              onTap: () => setState(() => _replyAudience = CommunityReplyAudience.mentioned),
            ),
          ],
          child: UiIconButton(
            icon: _replyAudience == CommunityReplyAudience.everyone
                ? Icons.public_rounded
                : (_replyAudience == CommunityReplyAudience.following
                    ? Icons.people_outline_rounded
                    : Icons.alternate_email_rounded),
            tooltip: 'Audience: ${_replyAudience.name}',
            size: UiSize.sm,
            variant: _replyAudience != CommunityReplyAudience.everyone ? UiVariant.soft : UiVariant.ghost,
          ),
        ),

        const Spacer(),

        // Circular Character Meter
        if (hasBody) ...<Widget>[
          UiProgressCircle(
            size: 18,
            thickness: 2.2,
            value: charRatio,
            intent: charCount > 500 ? UiIntent.danger : (charCount > 400 ? UiIntent.warning : UiIntent.primary),
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          Text(
            '$charCount',
            style: context.uiText.caption.copyWith(
              fontSize: context.fs(11),
              color: charCount > 500
                  ? theme.colors.destructive
                  : theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
        ],

        // Clear Draft Button if dirty
        if (hasBody || _tickers.isNotEmpty || _tags.isNotEmpty || _imageUrls.isNotEmpty || _attachment != null) ...[
          UiIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Clear Draft',
            size: UiSize.sm,
            variant: UiVariant.ghost,
            intent: UiIntent.danger,
            onPressed: () {
              setState(() {
                _bodyCtrl.clear();
                _body = '';
                _tickers.clear();
                _tags.clear();
                _imageUrls.clear();
                _attachment = null;
                _sentiment = null;
                _scheduledFor = null;
              });
            },
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
        ],

        // Post / Publish Button
        UiButton(
          label: _scheduledFor != null
              ? 'Schedule'
              : (_activeMode == ComposerMode.tradeSetup ? 'Publish Setup' : 'Post Thesis'),
          leadingIcon: _scheduledFor != null ? Icons.schedule_send_rounded : Icons.send_rounded,
          size: UiSize.sm,
          loading: _submitting,
          expandOnMobile: false,
          onPressed: (_body.trim().isEmpty &&
                  _attachment == null &&
                  _imageUrls.isEmpty &&
                  _activeMode != ComposerMode.poll &&
                  _activeMode != ComposerMode.tradeSetup)
              ? null
              : _submit,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mode Pill Header
// ---------------------------------------------------------------------------

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.pill),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.sm),
          vertical: context.sp(theme.spacing.xxs),
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colors.primary.withValues(alpha: 0.14) : theme.colors.surfaceMuted,
          borderRadius: context.radius(theme.radii.pill),
          border: Border.all(
            color: selected ? theme.colors.primary : theme.colors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.sz(14),
              color: selected ? theme.colors.primary : theme.colors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xxs)),
            Text(
              label,
              style: context.uiText.caption.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? theme.colors.primary : theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SideToggle
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
