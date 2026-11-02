import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/features/community/data/workspace_attachment_service.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_picker.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_mention_autocomplete.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradex/features/community/presentation/widgets/community_quote_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_schedule_dialog.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Composer Creation Mode
// ---------------------------------------------------------------------------

enum ComposerMode { post, tradeSetup, chart, poll, attachment }

// ---------------------------------------------------------------------------
// CommunityComposerCard
// ---------------------------------------------------------------------------

/// A responsive, multi-step Bloomberg/Twitter Pro-grade composer card for alphajournal.
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
    this.initialMode = ComposerMode.post,
    this.hintText =
        "What's happening? Share a setup, thesis, or trading lesson…",
    this.onPostCreated,
    this.quotedPost,
    this.postToEdit,
    this.onClose,
    this.compact = false,
    this.isDrawerTile = false,
  });

  final ComposerMode initialMode;
  final CommunityAuthor author;
  final CommunityRepository repository;
  final String hintText;
  final VoidCallback? onPostCreated;
  final CommunityPost? quotedPost;
  final CommunityPost? postToEdit;
  final VoidCallback? onClose;

  /// When true the textarea starts at 1 row.
  final bool compact;

  /// When true (or on mobile screens), renders as a bottom drawer tile card
  /// with rounded top corners, sharp bottom corners, and a top drag handle.
  final bool isDrawerTile;

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
  final TextEditingController _setupCandlesCtrl = TextEditingController();
  String? _candleError;
  final TextEditingController _setupCatalystCtrl = TextEditingController();

  // ---- Dynamic Poll form (2 to 5 options) -----------------------------------
  final TextEditingController _pollQuestionCtrl = TextEditingController();
  final List<TextEditingController> _pollOptionControllers =
      <TextEditingController>[TextEditingController(), TextEditingController()];
  Duration _pollDuration = const Duration(hours: 24);
  bool _pollAllowMultiple = false;

  // ---- Ticker dialog input -------------------------------------------------
  final TextEditingController _tickerInputCtrl = TextEditingController();

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
      text:
          "📊 **Daily Market Outlook**\n\n• Key Support & Resistance: \n• Macro Trigger / FII Flow: \n• Sector in Focus: \n• Trading Bias for Today: ",
    ),
    (
      title: 'Breakout Trade Thesis',
      icon: Icons.trending_up_rounded,
      text:
          "🚀 **Breakout Setup Thesis**\n\n• Technical Catalyst: \n• Volume Confirmation: \n• Invalidation Level: \n• Primary Target: ",
    ),
    (
      title: 'Trade Journal Post-Mortem',
      icon: Icons.menu_book_rounded,
      text:
          "📝 **Trade Execution Review**\n\n• Setup Executed: \n• What Went Well: \n• Slippage / Mistake: \n• Key Lesson for Next Session: ",
    ),
    (
      title: 'Educational Playbook',
      icon: Icons.school_outlined,
      text:
          "💡 **Trader Education Playbook**\n\n• Concept: \n• Common Retail Trap: \n• High-Probability Entry Trigger: \n• Capital Preservation Rule: ",
    ),
  ];

  static const List<({String name, String url})> _sampleChartPresets = [
    (
      name: 'Bull Flag Breakout',
      url:
          'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800&auto=format&fit=crop&q=80',
    ),
    (
      name: 'Order Block Sweep',
      url:
          'https://images.unsplash.com/photo-1642543492481-44e81e3914a7?w=800&auto=format&fit=crop&q=80',
    ),
    (
      name: 'Volume Weighted Reversal',
      url:
          'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=800&auto=format&fit=crop&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode;
    _initFromPostToEdit();
    _bodyCtrl.addListener(_onBodyChanged);
    _setupEntryCtrl.addListener(_onSetupPricesChanged);
    _setupSlCtrl.addListener(_onSetupPricesChanged);
    _setupTargetCtrl.addListener(_onSetupPricesChanged);
  }

  void _initFromPostToEdit() {
    final p = widget.postToEdit;
    if (p == null) return;

    _bodyCtrl.text = p.body;
    _body = p.body;
    _tickers.addAll(p.tickers);
    _tags.addAll(p.tags);
    _imageUrls.addAll(p.effectiveImageUrls);
    _attachment = p.attachment;
    _sentiment = p.sentiment;
    _replyAudience = p.replyAudience;
    _scheduledFor = p.scheduledFor;

    if (p.tradeSetup != null) {
      _activeMode = ComposerMode.tradeSetup;
      final ts = p.tradeSetup!;
      if (ts.candles.isNotEmpty) {
        _setupCandlesCtrl.text = const JsonEncoder.withIndent('  ').convert([
          for (final c in ts.candles)
            {
              'time': c.time.toIso8601String(),
              'open': c.open,
              'high': c.high,
              'low': c.low,
              'close': c.close,
              'volume': c.volume,
            },
        ]);
      }
      _setupTickerCtrl.text = ts.ticker;
      _tradeSetupSide = ts.side;
      _setupEntryCtrl.text = ts.entry;
      if (ts.exit != null) _setupExitCtrl.text = ts.exit!;
      if (ts.stopLoss != null) _setupSlCtrl.text = ts.stopLoss!;
      if (ts.target != null) _setupTargetCtrl.text = ts.target!;
    } else if (p.poll != null) {
      _activeMode = ComposerMode.poll;
      final poll = p.poll!;
      _pollQuestionCtrl.text = poll.question;
      _pollAllowMultiple = poll.allowMultiple;
      _pollOptionControllers.clear();
      for (final opt in poll.options) {
        _pollOptionControllers.add(TextEditingController(text: opt.text));
      }
    } else if (p.attachment != null) {
      _activeMode = ComposerMode.attachment;
    } else if (_imageUrls.isNotEmpty) {
      _activeMode = ComposerMode.chart;
    } else {
      _activeMode = ComposerMode.post;
    }
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
    _setupCandlesCtrl.dispose();
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
    final token = lastSpace == -1
        ? textToCursor
        : textToCursor.substring(lastSpace + 1);
    if (token.startsWith('@') ||
        token.startsWith('\$') ||
        token.startsWith('#')) {
      return token;
    }
    return '';
  }

  void _replaceActiveToken(String replacement) {
    final selectionEnd = _bodyCtrl.selection.end;
    final textToCursor =
        selectionEnd >= 0 && selectionEnd <= _bodyCtrl.text.length
        ? _bodyCtrl.text.substring(0, selectionEnd)
        : _bodyCtrl.text;
    final lastSpace = textToCursor.lastIndexOf(RegExp(r'[\s\n]'));
    final prefix = lastSpace == -1
        ? ''
        : textToCursor.substring(0, lastSpace + 1);
    final remaining = selectionEnd >= 0 && selectionEnd <= _bodyCtrl.text.length
        ? _bodyCtrl.text.substring(selectionEnd)
        : '';
    final newText = '$prefix$replacement $remaining';
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: prefix.length + replacement.length + 1,
      ),
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

  // ---------------------------------------------------------------------------
  // Inline AI-Assist Actions
  // ---------------------------------------------------------------------------

  void _aiPolishThesis() {
    final String text = _bodyCtrl.text.trim();
    if (text.isEmpty) {
      const String template =
          '📊 **Executive Trade Thesis**\n\n'
          '• **Macro Context:** Index holding above critical daily 20 EMA with positive FII cash accumulation.\n'
          '• **Setup Rationale:** Clean ascending triangle breakout with expanding volume delta.\n'
          '• **Risk Invalidation:** 15m candle close below demand block.\n'
          '• **Execution Plan:** Scale out 50% at Target 1, trail stop to breakeven for runner.';
      _bodyCtrl.text = template;
      setState(() => _body = template);
      UiToast.show(
        context,
        title: 'AI Thesis Generated',
        message: 'Generated professional executive trading thesis.',
        intent: UiIntent.success,
      );
      return;
    }

    final List<String> lines = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final StringBuffer polished = StringBuffer();
    polished.writeln('🎯 **Key Trade Thesis & Plan**');
    polished.writeln();
    for (final String line in lines) {
      if (line.startsWith('•') ||
          line.startsWith('-') ||
          line.startsWith('*')) {
        polished.writeln(line);
      } else {
        polished.writeln('• ${line.trim()}');
      }
    }
    polished.writeln();
    polished.writeln(
      '⚡ **Risk Management:** Strict stop discipline; no overnight carry without hedge.',
    );

    _bodyCtrl.text = polished.toString();
    setState(() => _body = polished.toString());
    UiToast.show(
      context,
      title: 'Thesis Polished',
      message: 'Enhanced structure, readability, and risk framing.',
      intent: UiIntent.success,
    );
  }

  void _aiAutoTagTickers() {
    final String text = _bodyCtrl.text;
    if (text.isEmpty) {
      UiToast.show(
        context,
        title: 'No Text Found',
        message: 'Write your thesis first to auto-detect tickers.',
        intent: UiIntent.warning,
      );
      return;
    }

    const List<String> knownTickers = <String>[
      'NIFTY',
      'BANKNIFTY',
      'FINNIFTY',
      'MIDCPNIFTY',
      'RELIANCE',
      'HDFCBANK',
      'ICICIBANK',
      'INFY',
      'TCS',
      'SBIN',
      'TATAMOTORS',
      'ITC',
      'BHARTIARTL',
      'KOTAKBANK',
      'LT',
      'AXISBANK',
      'BTC',
      'ETH',
      'SOL',
      'TSLA',
      'AAPL',
      'NVDA',
      'SPY',
      'QQQ',
      'GOLD',
      'CRUDE',
    ];

    int addedCount = 0;
    String updatedText = text;

    for (final String sym in knownTickers) {
      final RegExp regex = RegExp('\\b(?<!\\\$)$sym\\b', caseSensitive: false);
      if (regex.hasMatch(updatedText)) {
        updatedText = updatedText.replaceAllMapped(
          regex,
          (Match m) => '\$$sym',
        );
        if (!_tickers.contains(sym)) {
          _tickers.add(sym);
          addedCount++;
        }
      }
    }

    _bodyCtrl.text = updatedText;
    setState(() => _body = updatedText);

    if (addedCount > 0) {
      UiToast.show(
        context,
        title: 'Tickers Auto-Tagged',
        message: 'Detected and tagged $addedCount ticker(s) in your thesis.',
        intent: UiIntent.success,
      );
    } else {
      UiToast.show(
        context,
        title: 'No New Tickers Detected',
        message: 'All mentioned tickers are already tagged.',
        intent: UiIntent.info,
      );
    }
  }

  void _aiFormatSetup() {
    setState(() {
      _activeMode = ComposerMode.tradeSetup;
      if (_setupTickerCtrl.text.isEmpty && _tickers.isNotEmpty) {
        _setupTickerCtrl.text = _tickers.first;
      }
      if (_setupEntryCtrl.text.isEmpty) {
        _setupEntryCtrl.text = '24820';
        _setupSlCtrl.text = '24760';
        _setupTargetCtrl.text = '24970';
        _setupCatalystCtrl.text = '15m close below 24,760 demand block';
      }
    });

    UiToast.show(
      context,
      title: 'Trade Setup Formatted',
      message: 'Structured entry, invalidation SL, and targets prepared.',
      intent: UiIntent.success,
    );
  }

  void _aiAddBullBearCatalysts() {
    final String current = _bodyCtrl.text.trim();
    const String catalystBlock =
        '\n\n⚖️ **Bull / Bear Catalyst Matrix**\n'
        '🟢 **Bull Case:** Sustained volume above VWAP, call OI unwinding, FII index net-long.\n'
        '🔴 **Bear Risk:** Rejection at daily resistance, India VIX expansion, weakness in US futures.';

    _bodyCtrl.text = current.isEmpty
        ? catalystBlock.trimLeft()
        : '$current$catalystBlock';
    setState(() => _body = _bodyCtrl.text);

    UiToast.show(
      context,
      title: 'Catalysts Appended',
      message: 'Added balanced Bull vs. Bear risk parameters.',
      intent: UiIntent.info,
    );
  }

  bool _isUploadingChart = false;

  Future<void> _pickAndUploadChart() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() => _isUploadingChart = true);
      if (mounted) {
        UiToast.show(
          context,
          title: 'Uploading chart...',
          message: 'Uploading ${picked.name} to community storage',
          intent: UiIntent.info,
        );
      }

      final bytes = await picked.readAsBytes();
      final tempId = const Uuid().v4();
      final publicUrl = await widget.repository.uploadAttachment(
        postId: tempId,
        bytes: bytes,
        filename: picked.name,
      );

      if (publicUrl.isNotEmpty) {
        _addImageUrl(publicUrl);
      }
    } catch (e) {
      if (mounted) {
        UiToast.error(context, title: 'Upload failed', message: '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingChart = false);
      }
    }
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
    if (_activeMode != ComposerMode.tradeSetup || !_setupFormFilled) {
      return null;
    }
    final previous = widget.postToEdit?.tradeSetup;
    final sameExecution =
        previous != null &&
        previous.ticker == _setupTickerCtrl.text.trim().toUpperCase() &&
        previous.side == _tradeSetupSide &&
        previous.entry == _setupEntryCtrl.text.trim() &&
        (previous.exit ?? '') == _setupExitCtrl.text.trim() &&
        (previous.stopLoss ?? '') == _setupSlCtrl.text.trim() &&
        (previous.target ?? '') == _setupTargetCtrl.text.trim();
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
      candles: _previewCandles,
      rMultiple: sameExecution ? previous.rMultiple : null,
      pnl: sameExecution ? previous.pnl : null,
      isWin: sameExecution ? previous.isWin : null,
    );
  }

  List<UiCandle> get _previewCandles {
    try {
      return _parseSetupCandles();
    } on FormatException {
      return const <UiCandle>[];
    }
  }

  List<UiCandle> _parseSetupCandles() {
    final text = _setupCandlesCtrl.text.trim();
    if (text.isEmpty) return const <UiCandle>[];
    final decoded = jsonDecode(text);
    if (decoded is! List) {
      throw const FormatException('Enter an array of OHLC candles.');
    }
    final candles = <UiCandle>[];
    for (final row in decoded) {
      if (row is! Map) {
        throw const FormatException('Each candle must be an object.');
      }
      double number(String key, {double? fallback}) {
        final value = row[key];
        final parsed = value is num
            ? value.toDouble()
            : double.tryParse('$value');
        if (value == null && fallback != null) return fallback;
        if (parsed == null || !parsed.isFinite) {
          throw FormatException('Invalid $key value.');
        }
        return parsed;
      }

      final time = DateTime.tryParse('${row['time']}');
      if (time == null) {
        throw const FormatException('Each candle needs a valid time.');
      }
      final open = number('open'),
          high = number('high'),
          low = number('low'),
          close = number('close');
      final volume = number('volume', fallback: 0);
      if (low > high ||
          open < low ||
          open > high ||
          close < low ||
          close > high ||
          volume < 0) {
        throw const FormatException(
          'High and low must contain open and close; volume cannot be negative.',
        );
      }
      candles.add(
        UiCandle(
          time: time,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
        ),
      );
    }
    candles.sort((a, b) => a.time.compareTo(b.time));
    return candles;
  }

  CommunityPoll? get _buildPoll {
    if (_activeMode != ComposerMode.poll ||
        _pollQuestionCtrl.text.trim().isEmpty) {
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
          CommunityPollOption(
            id: 'opt_${i + 1}',
            text: validOptions[i],
            votes: 0,
          ),
      ],
      expiresAt: DateTime.now().add(_pollDuration),
      allowMultiple: _pollAllowMultiple,
      authorId: widget.author.id,
      authorDisplayName: widget.author.displayName,
      authorAvatarUrl: widget.author.avatarUrl,
    );
  }

  CommunityPost _buildPreviewPost() {
    final original = widget.postToEdit;
    final Set<String> previewTickers = <String>{
      ..._tickers.map((t) => t.replaceAll(r'$', '').toUpperCase()),
    };
    if (_setupTickerCtrl.text.trim().isNotEmpty) {
      previewTickers.add(
        _setupTickerCtrl.text.trim().replaceAll(r'$', '').toUpperCase(),
      );
    }
    final tickerMatches = RegExp(
      r'(?<![\$\w])\$([A-Za-z\^][A-Za-z0-9\.\-\_\^\=]{0,9})\b(?!\$)',
    ).allMatches(_body);
    for (final m in tickerMatches) {
      final sym = m.group(1)?.toUpperCase();
      if (sym != null && sym.isNotEmpty) {
        previewTickers.add(sym);
      }
    }
    final Set<String> previewTags = <String>{
      ..._tags.map((t) => t.replaceAll('#', '')),
    };
    final tagMatches = RegExp(
      r'(?<!\w)#([A-Za-z0-9_]{1,30})\b',
    ).allMatches(_body);
    for (final m in tagMatches) {
      final tag = m.group(1);
      if (tag != null && tag.isNotEmpty) {
        previewTags.add(tag);
      }
    }

    return CommunityPost(
      id: original?.id ?? 'preview_draft',
      author: widget.author,
      body: _body.isEmpty
          ? 'Your market thesis and analysis will appear here...'
          : _body,
      createdAt: original?.createdAt ?? (_scheduledFor ?? DateTime.now()),
      tickers: List<String>.unmodifiable(previewTickers),
      tags: List<String>.unmodifiable(previewTags),
      tradeSetup: _buildTradeSetup,
      attachment: _attachment,
      poll: _buildPoll,
      quoted: widget.quotedPost ?? original?.quoted,
      sentiment: _sentiment,
      replyAudience: _replyAudience,
      imageUrls: List<String>.unmodifiable(_imageUrls),
      imageUrl: _imageUrls.isNotEmpty ? _imageUrls.first : null,
      scheduledFor: _scheduledFor,
      likes: original?.likes ?? 0,
      comments: original?.comments ?? 0,
      reposts: original?.reposts ?? 0,
      views: original?.views ?? 0,
      isEdited: widget.postToEdit != null,
      editedAt: widget.postToEdit != null ? DateTime.now() : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Submission
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final String body = _body.trim();
    final bool hasSetup =
        _activeMode == ComposerMode.tradeSetup && _setupFormFilled;
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
    if (hasSetup) {
      try {
        _parseSetupCandles();
      } on FormatException catch (error) {
        setState(() => _candleError = error.message);
        return;
      }
    }

    setState(() => _submitting = true);
    AppLinkRef? publishedHere;
    try {
      final finalBody = body.isEmpty
          ? (hasSetup
                ? 'Shared setup for \$${_setupTickerCtrl.text.trim().toUpperCase()}'
                : 'Shared market analysis')
          : body;

      final Set<String> allTickers = <String>{
        ..._tickers.map((t) => t.replaceAll(r'$', '').toUpperCase()),
      };
      if (hasSetup && _setupTickerCtrl.text.trim().isNotEmpty) {
        allTickers.add(
          _setupTickerCtrl.text.trim().replaceAll(r'$', '').toUpperCase(),
        );
      }
      final tickerMatches = RegExp(
        r'(?<![\$\w])\$([A-Za-z\^][A-Za-z0-9\.\-\_\^\=]{0,9})\b(?!\$)',
      ).allMatches(finalBody);
      for (final m in tickerMatches) {
        final sym = m.group(1)?.toUpperCase();
        if (sym != null && sym.isNotEmpty) {
          allTickers.add(sym);
        }
      }

      final Set<String> allTags = <String>{
        ..._tags.map((t) => t.replaceAll('#', '')),
      };
      final tagMatches = RegExp(
        r'(?<!\w)#([A-Za-z0-9_]{1,30})\b',
      ).allMatches(finalBody);
      for (final m in tagMatches) {
        final tag = m.group(1);
        if (tag != null && tag.isNotEmpty) {
          allTags.add(tag);
        }
      }

      if (widget.quotedPost != null && !widget.quotedPost!.isPublic) {
        throw StateError('Publish the original post before quoting it.');
      }
      if (_attachment != null) {
        final fresh = await WorkspaceAttachmentService().resolve(
          _attachment!.source,
          requireOwner: true,
        );
        if (fresh == null) {
          throw StateError('The attached record no longer exists.');
        }
        _attachment = fresh;
      }
      if (!mounted) return;
      if (_attachment != null && _attachment!.requiresPublication) {
        final bool accepted = await UiDialog.confirm(
          context,
          title: 'Publish the attached record?',
          description:
              'Posting this attachment makes the complete attached record public. Review its content before sharing. Linked private records remain private.',
          confirmLabel: 'Publish and post',
        );
        if (!accepted || !mounted) {
          if (mounted) {
            setState(() => _submitting = false);
            UiToast.info(
              context,
              title: 'Attachment kept private',
              message:
                  'The post was not published and your private record remains protected.',
            );
          }
          return;
        }
        final AppLinkRef src = _attachment!.source;
        try {
          switch (src.kind) {
            case AppLinkKind.note:
              await NotesRepositoryScope.repository.setVisibility(src.id, true);
              publishedHere = src;
              break;
            case AppLinkKind.strategy:
              await StrategiesRepositoryScope.repository.setVisibility(
                src.id,
                true,
              );
              publishedHere = src;
              break;
            case AppLinkKind.journal:
              await JournalRepositoryScope.repository.setVisibility(
                src.id,
                true,
              );
              publishedHere = src;
              break;
            default:
              break;
          }
        } catch (_) {
          if (mounted) {
            UiToast.show(
              context,
              title: 'Attachment was not published',
              message: 'The post was not sent. Retry or remove the attachment.',
              intent: UiIntent.danger,
            );
          }
          return;
        }
      }

      if (_attachment != null) {
        _attachment = await WorkspaceAttachmentService().resolve(
          _attachment!.source,
          requireOwner: true,
        );
      }
      if (widget.postToEdit != null) {
        final p = widget.postToEdit!;
        await widget.repository.editPost(
          p.id,
          finalBody,
          tickers: List<String>.unmodifiable(allTickers),
          tags: List<String>.unmodifiable(allTags),
          tradeSetup: _buildTradeSetup,
          clearTradeSetup:
              _activeMode != ComposerMode.tradeSetup && p.tradeSetup != null,
          attachment: _attachment,
          clearAttachment: _attachment == null && p.attachment != null,
          poll: _buildPoll,
          clearPoll: _activeMode != ComposerMode.poll && p.poll != null,
          sentiment: _sentiment,
          clearSentiment: _sentiment == null && p.sentiment != null,
          replyAudience: _replyAudience,
          imageUrls: List<String>.unmodifiable(_imageUrls),
        );

        if (!mounted) return;
        UiToast.show(
          context,
          title: 'Post Updated',
          message: 'Your post edits have been saved.',
          intent: UiIntent.success,
        );

        widget.onPostCreated?.call();
        return;
      }

      await widget.repository.createPost(
        body: finalBody,
        tickers: List<String>.unmodifiable(allTickers),
        tags: List<String>.unmodifiable(allTags),
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
        title: _scheduledFor != null ? 'Scheduled!' : 'Submitted for Review',
        message: _scheduledFor != null
            ? 'Post scheduled for ${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}'
            : 'Your post has been submitted and is pending approval.',
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
        _setupCandlesCtrl.clear();
        _candleError = null;
        _tradeSetupSide = 'LONG';
        _replyAudience = CommunityReplyAudience.everyone;
      });

      widget.onPostCreated?.call();
    } catch (error) {
      if (publishedHere != null) {
        try {
          await WorkspaceAttachmentService().setVisibility(
            publishedHere,
            false,
          );
        } catch (_) {
          if (mounted) {
            UiToast.error(
              context,
              title: 'Review attachment visibility',
              message:
                  'The post failed and the attachment could not be made private again.',
            );
          }
        }
      }
      if (mounted) {
        UiToast.error(context, title: 'Post was not saved', message: '$error');
      }
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
    final bool isMobile = context.uiRes.isMobile;
    final bool isDesktop = context.uiRes.isDesktop;
    final bool asDrawerTile = widget.isDrawerTile || isMobile;

    final double spacingSm = context.sp(theme.spacing.sm);
    final double spacingXs = context.sp(theme.spacing.xs);
    final double spacingMd = context.sp(theme.spacing.md);
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    final String activeToken = _extractActiveToken();

    final BorderRadius cardBorderRadius = asDrawerTile
        ? BorderRadius.vertical(
            top: Radius.circular(context.sz(20)),
            bottom: Radius.zero,
          )
        : BorderRadius.circular(context.sz(theme.radii.lg));

    return UiCard(
      variant: UiCardVariant.surface,
      borderRadius: cardBorderRadius,
      padding: EdgeInsets.fromLTRB(
        isMobile ? spacingSm : spacingMd,
        isMobile ? spacingSm : spacingMd,
        isMobile ? spacingSm : spacingMd,
        asDrawerTile ? (spacingSm + safeBottom) : spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Drawer Drag Handle on Mobile Bottom Sheet
          if (asDrawerTile) ...<Widget>[
            Center(
              child: Container(
                width: context.sz(36),
                height: context.sz(4),
                margin: EdgeInsets.only(bottom: spacingSm),
                decoration: BoxDecoration(
                  color: theme.colors.border.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(context.sz(2)),
                ),
              ),
            ),
          ],

          // ---- Step 1: Clean Identity & Audience Header ----
          _buildIdentityHeader(theme, isMobile),

          SizedBox(height: spacingSm),

          // ---- Step 2: Segmented Mode Selector with Accent Theming ----
          _buildModeSelector(theme, isMobile),

          SizedBox(height: spacingSm),

          // ---- Step 3: Main Body / Responsive Two-Column Preview ----
          if (isDesktop && _isPreviewMode) ...<Widget>[
            // Desktop 2-column live split view (Interactive Editor on left, Real-time feed preview on right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: _buildEditorContent(theme, isMobile, activeToken),
                ),
                SizedBox(width: spacingMd),
                Container(width: 1, height: 480, color: theme.colors.border),
                SizedBox(width: spacingMd),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: context.sz(14),
                            color: theme.colors.primary,
                          ),
                          SizedBox(width: spacingXs),
                          Text(
                            'LIVE FEED PREVIEW',
                            style: context.uiText.label.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: context.fs(11),
                              letterSpacing: 0.6,
                              color: theme.colors.primary,
                            ),
                          ),
                          const Spacer(),
                          UiBadge(
                            label: 'REAL-TIME',
                            intent: UiIntent.success,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                      SizedBox(height: spacingSm),
                      CommunityPostCard(
                        post: _buildPreviewPost(),
                        variant: CommunityPostCardVariant.boxed,
                        repository: widget.repository,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (_isPreviewMode) ...<Widget>[
            // Mobile full-width preview mode
            _buildLivePreviewCard(theme, isMobile),
          ] else ...<Widget>[
            // Standard single-column editor
            _buildEditorContent(theme, isMobile, activeToken),
          ],

          SizedBox(height: spacingSm),
          UiDivider(spacing: spacingXs),
          SizedBox(height: spacingXs),

          // ---- Bottom Action Toolbar ----
          _buildActionRow(theme, isMobile, isDesktop),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Clean Identity & Audience Header
  // ---------------------------------------------------------------------------

  Widget _buildIdentityHeader(UiTheme theme, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            UiAvatar(
              imageUrl: widget.author.avatarUrl,
              name: widget.author.displayName,
              size: isMobile ? UiSize.xs : UiSize.sm,
              verified: false,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Expanded(
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      widget.author.displayName,
                      style: context.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: context.fs(13.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.author.verified) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified_rounded,
                      size: context.sz(14),
                      color: widget.author.verifiedColor(theme),
                    ),
                  ],
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Builder(
                    builder: (context) {
                      final cleanHandle = widget.author.handle
                          .replaceFirst(RegExp(r'^@+'), '')
                          .trim();
                      return Flexible(
                        child: Text(
                          '@$cleanHandle',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                            fontSize: context.fs(12),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            // Audience dropdown pill
            UiDropdownMenu(
              items: <UiMenuItem>[
                UiMenuItem(
                  label: 'Everyone',
                  icon: Icons.public_rounded,
                  selected: _replyAudience == CommunityReplyAudience.everyone,
                  onTap: () => setState(
                    () => _replyAudience = CommunityReplyAudience.everyone,
                  ),
                ),
                UiMenuItem(
                  label: 'Followed traders only',
                  icon: Icons.people_outline_rounded,
                  selected: _replyAudience == CommunityReplyAudience.following,
                  onTap: () => setState(
                    () => _replyAudience = CommunityReplyAudience.following,
                  ),
                ),
                UiMenuItem(
                  label: 'Mentioned traders only',
                  icon: Icons.alternate_email_rounded,
                  selected: _replyAudience == CommunityReplyAudience.mentioned,
                  onTap: () => setState(
                    () => _replyAudience = CommunityReplyAudience.mentioned,
                  ),
                ),
              ],
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                  vertical: context.sp(theme.spacing.xxs),
                ),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.pill),
                  border: Border.all(color: theme.colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _replyAudience == CommunityReplyAudience.everyone
                          ? Icons.public_rounded
                          : (_replyAudience == CommunityReplyAudience.following
                                ? Icons.people_outline_rounded
                                : Icons.alternate_email_rounded),
                      size: context.sz(12),
                      color: theme.colors.primary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      _replyAudience == CommunityReplyAudience.everyone
                          ? 'Everyone'
                          : (_replyAudience == CommunityReplyAudience.following
                                ? 'Followed'
                                : 'Mentioned'),
                      style: context.uiText.caption.copyWith(
                        fontSize: context.fs(11),
                        fontWeight: FontWeight.w600,
                        color: theme.colors.foreground,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: context.sz(14),
                      color: theme.colors.foregroundMuted,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            // Live Preview Toggle Pill
            InkWell(
              onTap: () => setState(() => _isPreviewMode = !_isPreviewMode),
              borderRadius: context.radius(theme.radii.pill),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                  vertical: context.sp(theme.spacing.xxs),
                ),
                decoration: BoxDecoration(
                  color: _isPreviewMode
                      ? theme.colors.primary.withValues(alpha: 0.15)
                      : theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.pill),
                  border: Border.all(
                    color: _isPreviewMode
                        ? theme.colors.primary
                        : theme.colors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _isPreviewMode
                          ? Icons.edit_rounded
                          : Icons.visibility_outlined,
                      size: context.sz(12),
                      color: _isPreviewMode
                          ? theme.colors.primary
                          : theme.colors.foregroundMuted,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      _isPreviewMode ? 'Editing' : 'Preview',
                      style: context.uiText.caption.copyWith(
                        fontSize: context.fs(11),
                        fontWeight: FontWeight.w600,
                        color: _isPreviewMode
                            ? theme.colors.primary
                            : theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.postToEdit != null) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiBadge(
                label: 'EDITING',
                intent: UiIntent.primary,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
            ],
            if (widget.onClose != null) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiIconButton(
                icon: Icons.close_rounded,
                size: UiSize.xs,
                tooltip: 'Close',
                onPressed: widget.onClose,
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Segmented Mode Selector with Accent Theming
  // ---------------------------------------------------------------------------

  Widget _buildModeSelector(UiTheme theme, bool isMobile) {
    final double gapXs = context.sp(theme.spacing.xs);

    return Row(
      children: <Widget>[
        // Mode Selector Scroll
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _ModePill(
                  icon: Icons.edit_note_rounded,
                  label: 'Thesis',
                  accentColor: theme.colors.primary,
                  selected: _activeMode == ComposerMode.post,
                  onTap: () => setState(() => _activeMode = ComposerMode.post),
                ),
                SizedBox(width: gapXs),
                _ModePill(
                  icon: Icons.candlestick_chart_rounded,
                  label: 'Trade Setup',
                  accentColor: theme.colors.success,
                  selected: _activeMode == ComposerMode.tradeSetup,
                  onTap: () =>
                      setState(() => _activeMode = ComposerMode.tradeSetup),
                ),
                SizedBox(width: gapXs),
                _ModePill(
                  icon: Icons.image_search_rounded,
                  label: _imageUrls.isNotEmpty
                      ? 'Chart (${_imageUrls.length})'
                      : 'Chart & Vision',
                  accentColor: theme.colors.info,
                  selected: _activeMode == ComposerMode.chart,
                  onTap: () => setState(() => _activeMode = ComposerMode.chart),
                ),
                SizedBox(width: gapXs),
                _ModePill(
                  icon: Icons.poll_outlined,
                  label: 'Poll',
                  accentColor: theme.colors.warning,
                  selected: _activeMode == ComposerMode.poll,
                  onTap: () => setState(() => _activeMode = ComposerMode.poll),
                ),
                SizedBox(width: gapXs),
                _ModePill(
                  icon: Icons.attach_file_rounded,
                  label: _attachment != null ? 'Record (1)' : 'Attach Record',
                  accentColor: const Color(0xFF8B5CF6),
                  selected: _activeMode == ComposerMode.attachment,
                  onTap: () =>
                      setState(() => _activeMode = ComposerMode.attachment),
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: gapXs),

        // Quick Starter Templates Menu
        UiDropdownMenu(
          items: <UiMenuItem>[
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
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Inline AI-Assist Toolbar
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Unified Smart Intelligence Bar (AI Copilot + Quick-Add Trending)
  // ---------------------------------------------------------------------------

  Widget _buildUnifiedIntelligenceBar(UiTheme theme, bool isMobile) {
    final double gapXs = context.sp(theme.spacing.xxs);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.xs),
        vertical: context.sp(theme.spacing.xs),
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(color: theme.colors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Row 1: AI Copilot Tools
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.auto_awesome,
                      size: context.sz(12.5),
                      color: theme.colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Copilot',
                      style: context.uiText.label.copyWith(
                        fontSize: context.fs(11),
                        fontWeight: FontWeight.w700,
                        color: theme.colors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                _aiToolButton(
                  context,
                  theme,
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Polish Thesis',
                  onTap: _aiPolishThesis,
                ),
                SizedBox(width: gapXs),
                _aiToolButton(
                  context,
                  theme,
                  icon: Icons.tag_rounded,
                  label: 'Auto-Tag Tickers',
                  onTap: _aiAutoTagTickers,
                ),
                SizedBox(width: gapXs),
                _aiToolButton(
                  context,
                  theme,
                  icon: Icons.candlestick_chart_rounded,
                  label: 'Format Setup',
                  onTap: _aiFormatSetup,
                ),
                SizedBox(width: gapXs),
                _aiToolButton(
                  context,
                  theme,
                  icon: Icons.balance_rounded,
                  label: 'Add Catalysts',
                  onTap: _aiAddBullBearCatalysts,
                ),
              ],
            ),
          ),

          SizedBox(height: gapXs + 2),
          Container(
            height: 1,
            color: theme.colors.border.withValues(alpha: 0.5),
          ),
          SizedBox(height: gapXs + 2),

          // Row 2: Quick-Add Trending Tickers & Tags
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Text(
                  'Quick Add: ',
                  style: context.uiText.caption.copyWith(
                    fontSize: context.fs(11),
                    color: theme.colors.foregroundMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final String t in _trendingCashtags) ...<Widget>[
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
                InkWell(
                  onTap: _showTickerDialog,
                  borderRadius: context.radius(theme.radii.sm),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.xs),
                      vertical: 2,
                    ),
                    margin: EdgeInsets.only(right: gapXs),
                    decoration: BoxDecoration(
                      color: theme.colors.surface,
                      borderRadius: context.radius(theme.radii.sm),
                      border: Border.all(color: theme.colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.add,
                          size: context.sz(11),
                          color: theme.colors.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Symbol',
                          style: context.uiText.caption.copyWith(
                            fontSize: context.fs(11),
                            color: theme.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final String tag in _trendingHashtags) ...<Widget>[
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
                        color: theme.colors.surface,
                        borderRadius: context.radius(theme.radii.sm),
                        border: Border.all(color: theme.colors.border),
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
          ),
        ],
      ),
    );
  }

  Widget _aiToolButton(
    BuildContext context,
    UiTheme theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.pill),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.xs),
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: context.radius(theme.radii.pill),
          border: Border.all(color: theme.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: context.sz(11), color: theme.colors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.uiText.label.copyWith(
                fontSize: context.fs(10.5),
                fontWeight: FontWeight.w600,
                color: theme.colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Editor Content Column
  // ---------------------------------------------------------------------------

  Widget _buildEditorContent(UiTheme theme, bool isMobile, String activeToken) {
    final double spacingSm = context.sp(theme.spacing.sm);
    final double spacingXs = context.sp(theme.spacing.xs);

    return Column(
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
            onSelectTrader: (trader) =>
                _replaceActiveToken(trader.displayHandle),
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

        SizedBox(height: spacingXs),

        // Unified Smart Intelligence Strip (AI Tools & Quick-Add Trending)
        _buildUnifiedIntelligenceBar(theme, isMobile),

        // Active Badges Row: Sentiment, Conviction, Tickers, Tags
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
        if (_activeMode == ComposerMode.chart ||
            _imageUrls.isNotEmpty) ...<Widget>[
          SizedBox(height: spacingSm),
          _buildChartStudioCard(theme, isMobile),
        ],

        // Mode 3: Poll Form with dynamic choices & demographics
        if (_activeMode == ComposerMode.poll) ...<Widget>[
          SizedBox(height: spacingSm),
          _buildPollCard(theme, isMobile),
        ],

        // Mode 4: Attachment Form (Note, Journal, Strategy)
        if (_activeMode == ComposerMode.attachment ||
            _attachment != null) ...<Widget>[
          SizedBox(height: spacingSm),
          _buildAttachmentCard(theme, isMobile),
        ],
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
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: context.sz(15),
                  color: theme.colors.primary,
                ),
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
  // Active Badges Row
  // ---------------------------------------------------------------------------

  Widget _buildActiveBadgesRow(UiTheme theme, double spacingXs) {
    final bool hasBadges =
        _sentiment != null ||
        _conviction != 'Standard' ||
        _scheduledFor != null ||
        _tickers.isNotEmpty ||
        _tags.isNotEmpty ||
        _imageUrls.isNotEmpty;

    if (!hasBadges) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: spacingXs),
      child: Wrap(
        spacing: spacingXs,
        runSpacing: spacingXs,
        children: <Widget>[
          if (_sentiment != null)
            UiBadge(
              label: _sentiment == CommunitySentiment.bullish
                  ? 'BULLISH'
                  : (_sentiment == CommunitySentiment.bearish
                        ? 'BEARISH'
                        : 'NEUTRAL'),
              intent: _sentiment == CommunitySentiment.bullish
                  ? UiIntent.success
                  : (_sentiment == CommunitySentiment.bearish
                        ? UiIntent.danger
                        : UiIntent.info),
              variant: UiBadgeVariant.solid,
              size: UiSize.xs,
              onRemove: () => setState(() => _sentiment = null),
            ),
          if (_conviction != 'Standard')
            UiBadge(
              label: _conviction,
              intent: UiIntent.warning,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
              onRemove: () => setState(() => _conviction = 'Standard'),
            ),
          if (_scheduledFor != null)
            UiBadge(
              label:
                  'Scheduled: ${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}',
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
              label:
                  '${_imageUrls.length} Chart Image${_imageUrls.length > 1 ? "s" : ""}',
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
          Wrap(
            spacing: gapXs,
            runSpacing: gapXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Icon(
                Icons.candlestick_chart_rounded,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              Text(
                'Professional Financial Setup',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foreground,
                ),
              ),
              if (rrMetrics.badge != null) rrMetrics.badge!,
            ],
          ),

          SizedBox(height: gap),

          // Instrument Selector Segmented Control
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final inst in <String>[
                  'Cash Equity',
                  'Index Futures',
                  'Options Buying',
                  'Options Selling',
                  'Crypto Perp',
                ]) ...[
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
                          color: _instrumentType == inst
                              ? theme.colors.primary
                              : theme.colors.border,
                        ),
                      ),
                      child: Text(
                        inst,
                        style: context.uiText.caption.copyWith(
                          fontSize: context.fs(11),
                          fontWeight: _instrumentType == inst
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _instrumentType == inst
                              ? theme.colors.primary
                              : theme.colors.foregroundMuted,
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              SizedBox(width: gapXs),
              Expanded(
                child: UiInput(
                  controller: _setupExitCtrl,
                  hintText: 'Exit / Trailing (Optional)',
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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

          UiTextarea(
            key: const ValueKey<String>('setup-candles-input'),
            controller: _setupCandlesCtrl,
            label: 'Candlestick data (optional)',
            hintText:
                '[{"time":"2026-09-30T09:15:00+05:30","open":100,"high":105,"low":99,"close":103,"volume":1200}]',
            helper:
                'Paste OHLC candle data to display the chart. Price levels alone do not contain market candles.',
            rows: 3,
            maxRows: 6,
            showCounter: false,
            errorText: _candleError,
            onChanged: (_) => setState(() => _candleError = null),
          ),
          SizedBox(height: gapXs),

          // Setup Invalidation Trigger
          UiInput(
            controller: _setupCatalystCtrl,
            hintText:
                'Invalidation trigger (e.g. 15m candle close below support)...',
            leadingIcon: Icons.shield_outlined,
            size: UiSize.xs,
          ),
        ],
      ),
    );
  }

  ({
    bool isValid,
    double riskPoints,
    double rewardPoints,
    double riskPct,
    double rewardPct,
    Widget? badge,
  })
  _computeRiskReward() {
    final entry = double.tryParse(_setupEntryCtrl.text.trim());
    final sl = double.tryParse(_setupSlCtrl.text.trim());
    final target = double.tryParse(_setupTargetCtrl.text.trim());

    if (entry == null || sl == null || target == null || entry <= 0) {
      return (
        isValid: false,
        riskPoints: 0,
        rewardPoints: 0,
        riskPct: 0,
        rewardPct: 0,
        badge: null,
      );
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

    final String label;
    final UiIntent intent;
    final UiBadgeVariant variant;

    if (ratio >= 2.5) {
      label = '🔥 High Edge 1 : ${ratio.toStringAsFixed(2)}';
      intent = UiIntent.success;
      variant = UiBadgeVariant.solid;
    } else if (ratio >= 1.5) {
      label = '✅ Favorable 1 : ${ratio.toStringAsFixed(2)}';
      intent = UiIntent.success;
      variant = UiBadgeVariant.soft;
    } else if (ratio >= 1.0) {
      label = 'R:R 1 : ${ratio.toStringAsFixed(2)}';
      intent = UiIntent.warning;
      variant = UiBadgeVariant.soft;
    } else {
      label = '⚠️ Sub-optimal 1 : ${ratio.toStringAsFixed(2)}';
      intent = UiIntent.danger;
      variant = UiBadgeVariant.soft;
    }

    return (
      isValid: true,
      riskPoints: risk,
      rewardPoints: reward,
      riskPct: riskPct,
      rewardPct: rewardPct,
      badge: UiBadge(
        label: label,
        intent: intent,
        variant: variant,
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
                  Icon(
                    Icons.insert_photo_outlined,
                    size: context.sz(16),
                    color: theme.colors.primary,
                  ),
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
                onPressed: () =>
                    setState(() => _activeMode = ComposerMode.post),
              ),
            ],
          ),

          SizedBox(height: gapXs),
          Text(
            'Upload or attach TradingView / broker chart screenshots to validate your thesis:',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: gap),

          // Dropzone for upload
          UiDropzone(
            title: 'Drop TradingView or Broker Chart',
            message: 'PNG, JPG, or WebP up to 10 MB',
            icon: Icons.add_photo_alternate_outlined,
            uploading: _isUploadingChart,
            onPick: _pickAndUploadChart,
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

          if (CustomerDataPolicy.allowDemo) ...[
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
          ],

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
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: context.sz(20),
                              ),
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
                  Icon(
                    Icons.poll_rounded,
                    size: context.sz(16),
                    color: theme.colors.primary,
                  ),
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
                onPressed: () =>
                    setState(() => _activeMode = ComposerMode.post),
              ),
            ],
          ),
          SizedBox(height: gapXs),
          UiInput(
            controller: _pollQuestionCtrl,
            hintText:
                'Ask your market consensus question (e.g. NIFTY expiry bias?)...',
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
                    hintText:
                        'Choice ${i + 1} (e.g. ${i == 0
                            ? "Bullish Breakout"
                            : i == 1
                            ? "Bear Trap"
                            : "Consolidation"})',
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
                    onChanged: (hours) =>
                        setState(() => _pollDuration = Duration(hours: hours)),
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
                  Icon(
                    Icons.library_books_rounded,
                    size: context.sz(16),
                    color: theme.colors.primary,
                  ),
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
                onPressed: () =>
                    setState(() => _activeMode = ComposerMode.post),
              ),
            ],
          ),
          SizedBox(height: gapXs),
          Text(
            'Attach a research Note, an executed Journal Trade, or an algorithmic Strategy directly to this post:',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
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
      final id =
          '${type.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
      final title = titleCtrl.text.trim();
      final desc = descCtrl.text.trim().isEmpty
          ? 'Created via Community'
          : descCtrl.text.trim();

      final AppLinkKind kind;
      if (type.toLowerCase() == 'trade') {
        kind = AppLinkKind.journal;
      } else if (type.toLowerCase() == 'strategy') {
        kind = AppLinkKind.strategy;
      } else {
        kind = AppLinkKind.note;
      }

      final record = AppWritingPostAttachment.manual(
        source: AppLinkRef(kind: kind, id: id, title: title),
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

    return Wrap(
      spacing: context.sp(theme.spacing.xs),
      runSpacing: context.sp(theme.spacing.xs),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        // 1. Market Bias (Bullish, Bearish, Neutral) Selector
        UiDropdownMenu(
          items: <UiMenuItem>[
            UiMenuItem(
              label: 'Bullish Bias',
              icon: Icons.trending_up_rounded,
              intent: UiIntent.success,
              selected: _sentiment == CommunitySentiment.bullish,
              onTap: () =>
                  setState(() => _sentiment = CommunitySentiment.bullish),
            ),
            UiMenuItem(
              label: 'Bearish Bias',
              icon: Icons.trending_down_rounded,
              intent: UiIntent.danger,
              selected: _sentiment == CommunitySentiment.bearish,
              onTap: () =>
                  setState(() => _sentiment = CommunitySentiment.bearish),
            ),
            UiMenuItem(
              label: 'Neutral / Rangebound',
              icon: Icons.trending_flat_rounded,
              intent: UiIntent.info,
              selected: _sentiment == CommunitySentiment.neutral,
              onTap: () =>
                  setState(() => _sentiment = CommunitySentiment.neutral),
            ),
            if (_sentiment != null)
              UiMenuItem(
                label: 'Clear Bias',
                icon: Icons.close_rounded,
                destructive: true,
                onTap: () => setState(() => _sentiment = null),
              ),
          ],
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xs),
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _sentiment == CommunitySentiment.bullish
                  ? theme.colors.success.withValues(alpha: 0.12)
                  : (_sentiment == CommunitySentiment.bearish
                        ? theme.colors.destructive.withValues(alpha: 0.12)
                        : theme.colors.surfaceMuted),
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: _sentiment == CommunitySentiment.bullish
                    ? theme.colors.success.withValues(alpha: 0.3)
                    : (_sentiment == CommunitySentiment.bearish
                          ? theme.colors.destructive.withValues(alpha: 0.3)
                          : theme.colors.border),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _sentiment?.icon ?? Icons.trending_up_rounded,
                  size: context.sz(13),
                  color: _sentiment == CommunitySentiment.bullish
                      ? theme.colors.success
                      : (_sentiment == CommunitySentiment.bearish
                            ? theme.colors.destructive
                            : theme.colors.foregroundMuted),
                ),
                if (!isMobile) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    _sentiment != null ? _sentiment!.label : 'Bias',
                    style: context.uiText.caption.copyWith(
                      fontSize: context.fs(11),
                      fontWeight: FontWeight.w600,
                      color: _sentiment == CommunitySentiment.bullish
                          ? theme.colors.success
                          : (_sentiment == CommunitySentiment.bearish
                                ? theme.colors.destructive
                                : theme.colors.foreground),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: context.sz(14),
                    color: theme.colors.foregroundMuted,
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(width: context.sp(theme.spacing.xs)),

        // 2. Timeframe Horizon Selector
        UiDropdownMenu(
          items: <UiMenuItem>[
            for (final tf in <String>[
              '15m Scalp',
              'Intraday',
              'Daily Swing',
              'Weekly Macro',
            ])
              UiMenuItem(
                label: tf,
                selected: _timeframe == tf,
                onTap: () => setState(() => _timeframe = tf),
              ),
          ],
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xs),
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(color: theme.colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.schedule_outlined,
                  size: context.sz(13),
                  color: theme.colors.foregroundMuted,
                ),
                if (!isMobile) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    _timeframe,
                    style: context.uiText.caption.copyWith(
                      fontSize: context.fs(11),
                      fontWeight: FontWeight.w600,
                      color: theme.colors.foreground,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: context.sz(14),
                    color: theme.colors.foregroundMuted,
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(width: context.sp(theme.spacing.xs)),

        // 3. Conviction Level Selector
        UiDropdownMenu(
          items: <UiMenuItem>[
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
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xs),
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _conviction.contains('🔥')
                  ? theme.colors.warning.withValues(alpha: 0.12)
                  : theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: _conviction.contains('🔥')
                    ? theme.colors.warning.withValues(alpha: 0.3)
                    : theme.colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.local_fire_department_rounded,
                  size: context.sz(13),
                  color: _conviction.contains('🔥')
                      ? theme.colors.warning
                      : theme.colors.foregroundMuted,
                ),
                if (!isMobile) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    _conviction == 'Standard' ? 'Conviction' : _conviction,
                    style: context.uiText.caption.copyWith(
                      fontSize: context.fs(11),
                      fontWeight: FontWeight.w600,
                      color: _conviction.contains('🔥')
                          ? theme.colors.warning
                          : theme.colors.foreground,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: context.sz(14),
                    color: theme.colors.foregroundMuted,
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(width: context.sp(theme.spacing.xs)),

        // 4. Schedule Post Shortcut
        UiIconButton(
          icon: Icons.event_available_outlined,
          tooltip: _scheduledFor != null
              ? 'Scheduled: ${_scheduledFor!.hour.toString().padLeft(2, '0')}:${_scheduledFor!.minute.toString().padLeft(2, '0')}'
              : 'Schedule Post',
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

        // Circular Character Meter
        if (hasBody) ...<Widget>[
          UiProgressCircle(
            size: 18,
            thickness: 2.2,
            value: charRatio,
            showLabel: false,
            intent: charCount > 500
                ? UiIntent.danger
                : (charCount > 400 ? UiIntent.warning : UiIntent.primary),
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          Text(
            '$charCount/500',
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
        if (hasBody ||
            _tickers.isNotEmpty ||
            _tags.isNotEmpty ||
            _imageUrls.isNotEmpty ||
            _attachment != null) ...<Widget>[
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
                _conviction = 'Standard';
                _scheduledFor = null;
              });
            },
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
        ],

        // Post / Publish Button
        UiButton(
          label: widget.postToEdit != null
              ? 'Save Changes'
              : (_scheduledFor != null
                    ? 'Schedule'
                    : (_activeMode == ComposerMode.tradeSetup
                          ? 'Publish Setup'
                          : 'Post Thesis')),
          leadingIcon: widget.postToEdit != null
              ? Icons.check_circle_outline_rounded
              : (_scheduledFor != null
                    ? Icons.schedule_send_rounded
                    : Icons.send_rounded),
          size: UiSize.sm,
          loading: _submitting,
          expandOnMobile: false,
          onPressed:
              (_body.trim().isEmpty &&
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
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color color = accentColor ?? theme.colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.sm),
          vertical: context.sp(theme.spacing.xxs),
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : theme.colors.surfaceMuted,
          borderRadius: context.radius(theme.radii.pill),
          border: Border.all(
            color: selected ? color : theme.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.sz(14),
              color: selected ? color : theme.colors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xxs)),
            Text(
              label,
              style: context.uiText.caption.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : theme.colors.foregroundMuted,
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
