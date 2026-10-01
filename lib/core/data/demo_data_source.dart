import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Deterministic in-memory data source used by every feature repository while
/// the product runs as a frontend prototype.
///
/// Backend hand-off contract: each `DemoDataSource` getter maps 1:1 to a
/// repository method in `lib/features/<feature>/data/repositories/`. Replace the
/// repository implementation with a real API/Supabase call and delete nothing
/// else — no widget reads this class directly.
class DemoDataSource {
  DemoDataSource._();

  /// Single shared instance so every repository observes the same session data.
  static final DemoDataSource instance = DemoDataSource._();

  /// Fixed seed keeps every rebuild, hot reload and widget test identical.
  static const int _seed = 20260821;

  static final DateTime _now = DateTime.now();

  Random _rng([int salt = 0]) => Random(_seed + salt);

  /// Memoized cross-link table, built once per session.
  ///
  /// Every linked surface reads its edges from here, so the note that points at
  /// a journal entry and the entry that points back are two views of one fact
  /// rather than two independent guesses.
  _LinkSeed? _linkCache;

  _LinkSeed get _linkSeed => _linkCache ??= _LinkSeed(
    noteIds: List<String>.generate(_noteTitles.length, _noteId),
    journal: _rawTrades(),
    strategyIds: List<String>.generate(
      _setups.length,
      (int i) => 'stg_${i + 1}',
    ),
  );

  double _round(double value, [int decimals = 2]) {
    final num factor = pow(10, decimals);
    return (value * factor).round() / factor;
  }

  // ---------------------------------------------------------------------------
  // Instrument universe
  // ---------------------------------------------------------------------------

  static const List<_Instrument> _instruments = <_Instrument>[
    _Instrument('RELIANCE', 'Reliance Industries', 2912.40, 'Energy'),
    _Instrument('HDFCBANK', 'HDFC Bank', 1684.75, 'Financials'),
    _Instrument('INFY', 'Infosys', 1543.20, 'IT'),
    _Instrument('TCS', 'Tata Consultancy Services', 3902.10, 'IT'),
    _Instrument('NIFTY50', 'Nifty 50 Index', 24380.55, 'Index'),
    _Instrument('BANKNIFTY', 'Bank Nifty Index', 52140.90, 'Index'),
    _Instrument('TATAMOTORS', 'Tata Motors', 984.35, 'Auto'),
    _Instrument('SBIN', 'State Bank of India', 812.60, 'Financials'),
    _Instrument('ADANIENT', 'Adani Enterprises', 3120.15, 'Infra'),
    _Instrument('SUNPHARMA', 'Sun Pharmaceutical', 1748.90, 'Pharma'),
    _Instrument('ITC', 'ITC Limited', 468.25, 'FMCG'),
    _Instrument('LT', 'Larsen & Toubro', 3640.80, 'Infra'),
  ];

  /// Symbols available to scanners, watchlists and the journal composer.
  List<String> get symbols =>
      _instruments.map((_Instrument i) => i.symbol).toList(growable: false);

  List<double> _spark(int salt, {int points = 16, double drift = 0}) {
    final Random rng = _rng(salt);
    double value = 100;
    return List<double>.generate(points, (int i) {
      value += (rng.nextDouble() - 0.5) * 6 + drift;
      return _round(value);
    });
  }

  /// Live-quote rows for watchlists, heatmaps and movers rails.
  List<AppTicker> tickers({int? limit, String? category}) {
    final Random rng = _rng(11);
    final List<AppTicker> all = <AppTicker>[
      for (int i = 0; i < _instruments.length; i++)
        AppTicker(
          symbol: _instruments[i].symbol,
          name: _instruments[i].name,
          price: _instruments[i].price,
          changePercent: _round((rng.nextDouble() - 0.42) * 5.4),
          spark: _spark(30 + i),
          category: _instruments[i].sector,
          isFavorite: i < 5,
        ),
    ];
    final List<AppTicker> filtered = category == null
        ? all
        : all
              .where((AppTicker t) => t.category == category)
              .toList(growable: false);
    return limit == null ? filtered : filtered.take(limit).toList();
  }

  /// Sector labels used by watchlist tabs and allocation breakdowns.
  List<String> get sectors =>
      _instruments.map((_Instrument i) => i.sector).toSet().toList();

  AppTicker tickerFor(String symbol) => tickers().firstWhere(
    (AppTicker t) => t.symbol == symbol,
    orElse: () => tickers().first,
  );

  /// The round number just under a price — the sort of level an alert would have
  /// been set at and has since been crossed.
  double levelBelow(double price, {double step = 50}) =>
      (price / step).floor() * step;

  /// The round number just over a price — a level still to be taken out, which is
  /// how a breakout or continuation trigger is quoted.
  double levelAbove(double price, {double step = 50}) =>
      (price / step).ceil() * step;

  /// OHLCV history for the price chart of [symbol].
  List<AppCandle> candles(String symbol, {int count = 90}) {
    final AppTicker ticker = tickerFor(symbol);
    final Random rng = _rng(symbol.hashCode.abs() % 9999);
    double close = ticker.price * 0.88;
    return List<AppCandle>.generate(count, (int i) {
      final double open = close;
      final double move = (rng.nextDouble() - 0.46) * open * 0.018;
      close = _round(open + move);
      final double wick = open * 0.006 * (0.4 + rng.nextDouble());
      return AppCandle(
        time: _now.subtract(Duration(days: count - i)),
        open: _round(open),
        high: _round(max(open, close) + wick),
        low: _round(min(open, close) - wick),
        close: close,
        volume: (120000 + rng.nextInt(480000)).toDouble(),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // People
  // ---------------------------------------------------------------------------

  static const List<_Person> _people = <_Person>[
    _Person('quantqueen', 'Ava Chen', 'Swing trading semis and index futures.'),
    _Person('deltadev', 'Rohan Mehta', 'Options seller. Theta is my edge.'),
    _Person('chartsage', 'Neha Kapoor', 'Price action purist, no indicators.'),
    _Person('riskfirst', 'Daniel Osei', 'Position sizing over prediction.'),
    _Person('gapfader', 'Priya Nair', 'Opening range and gap statistics.'),
    _Person('macrolens', 'Ibrahim Khan', 'Rates, INR and cross-asset flows.'),
  ];

  /// Community members surfaced in feeds, leaderboards and follow suggestions.
  List<AppTrader> traders({int? limit}) {
    final Random rng = _rng(21);
    final List<AppTrader> all = <AppTrader>[
      for (int i = 0; i < _people.length; i++)
        AppTrader(
          id: 'trd_${i + 1}',
          handle: _people[i].handle,
          displayName: _people[i].name,
          avatarUrl: 'https://i.pravatar.cc/150?img=${12 + i * 7}',
          bio: _people[i].bio,
          tier: AppTier.values[i % AppTier.values.length],
          followers: 800 + rng.nextInt(24000),
          following: 40 + rng.nextInt(400),
          winRate: _round(46 + rng.nextDouble() * 22, 1),
          verified: i.isEven,
          isFollowing: i % 3 == 0,
          tradingStyle: const <String>[
            'Swing',
            'Options',
            'Intraday',
            'Positional',
          ][i % 4],
        ),
    ];
    return limit == null ? all : all.take(limit).toList();
  }

  /// The signed-in trader, derived from the auth session rather than a literal.
  AppTrader me({
    required String id,
    required String handle,
    required String displayName,
    AppTier tier = AppTier.free,
    String? bio,
  }) => AppTrader(
    id: id,
    handle: handle,
    displayName: displayName,
    bio: bio,
    tier: tier,
    followers: 1284,
    following: 212,
    winRate: 58.4,
    verified: tier != AppTier.free,
    tradingStyle: 'Swing',
  );

  // ---------------------------------------------------------------------------
  // Journal
  // ---------------------------------------------------------------------------

  static const List<String> _setups = <String>[
    'Opening range breakout',
    'Gap fade',
    'Trend continuation',
    'VWAP reclaim',
    'Failed breakdown',
    'Earnings drift',
  ];

  static const List<String> _emotions = <String>[
    'Followed plan',
    'Chased entry',
    'Cut early',
    'Sized correctly',
    'Revenge trade',
  ];

  /// Journal entries before any cross-link is attached.
  ///
  /// Every field here is derived from the trade's own numbers, so it can be
  /// built without consulting notes or strategies — which is what lets
  /// [_linkSeed] index journal ids without calling back into [trades].
  List<AppTrade> _rawTrades({int count = 42}) {
    final Random rng = _rng(41);
    final List<AppTrade> result = <AppTrade>[];
    for (int i = 0; i < count; i++) {
      final _Instrument instrument =
          _instruments[rng.nextInt(_instruments.length)];
      final AppSide side = rng.nextBool() ? AppSide.long : AppSide.short;
      final double entry = _round(
        instrument.price * (0.94 + rng.nextDouble() * 0.12),
      );
      final bool open = i < 3;
      final double moveFactor = (rng.nextDouble() - 0.38) * 0.05;
      final double exit = _round(
        entry * (1 + (side == AppSide.long ? moveFactor : -moveFactor)),
      );
      final double size = (10 + rng.nextInt(90)).toDouble();
      final double gross = side == AppSide.long
          ? (exit - entry) * size
          : (entry - exit) * size;
      final double pnl = _round(gross);
      final double risk = entry * 0.01 * size;
      final DateTime openedAt = _now.subtract(
        Duration(days: i ~/ 2, hours: rng.nextInt(7)),
      );
      final DateTime? closedAt = open
          ? null
          : openedAt.add(Duration(hours: 1 + i % 6));
      final String setup = _setups[rng.nextInt(_setups.length)];
      final String emotion = _emotions[rng.nextInt(_emotions.length)];
      // Roughly one trade in seven was logged without a playbook attached.
      // That is the state `AppLinkGraph.orphans()` exists to surface, and the
      // "unfiled" prompt cannot be designed against a workspace where every
      // entry is already filed.
      final bool unfiled = i % 7 == 5;
      final double stop = _round(
        side == AppSide.long ? entry * 0.988 : entry * 1.012,
      );
      final double target = _round(
        side == AppSide.long ? entry * 1.026 : entry * 0.974,
      );
      final DateTime edited = (closedAt ?? openedAt).add(
        Duration(minutes: 25 + i * 3),
      );
      result.add(
        AppTrade(
          id: 'trd_${instrument.symbol.toLowerCase()}_$i',
          userId: 'demo_user',
          ticker: instrument.symbol,
          side: side,
          entry: entry,
          exit: open ? null : exit,
          openedAt: openedAt,
          closedAt: closedAt,
          stopLoss: stop,
          target: target,
          size: size,
          pnl: open ? 0 : pnl,
          pnlPercent: open ? 0 : _round((pnl / (entry * size)) * 100),
          rMultiple: open ? null : _round(pnl / (risk == 0 ? 1 : risk)),
          outcome: open
              ? AppOutcome.open
              : pnl > 0
              ? AppOutcome.win
              : pnl < 0
              ? AppOutcome.loss
              : AppOutcome.breakeven,
          strategy: unfiled ? null : setup,
          strategyId: unfiled ? null : 'stg_${_setups.indexOf(setup) + 1}',
          isPublic: i % 5 == 0,
          isFavorite: i < 3,
          tags: unfiled
              ? <String>[emotion, instrument.sector]
              : <String>[setup, emotion, instrument.sector],
          notes: unfiled
              ? 'Logged the fill on ${instrument.symbol} straight from the '
                    'terminal. No playbook attached yet.'
              : 'Executed the ${setup.toLowerCase()} plan on ${instrument.symbol}. '
                    'Managed the position against the stop without widening it.',
          psychologyScore: 2 + rng.nextInt(4),
          // A trader who names an entry has already decided what it was about;
          // the rest fall back to `displayTitle`. Both cases have to appear in
          // the seed or the fallback ships untested.
          title: i % 3 == 0 ? '$setup — ${instrument.symbol}' : '',
          // Not every logged trade gets written up, and the gap is the point:
          // `journalCoverage` and the "needs a write-up" prompt have nothing to
          // report if the seed is uniformly complete.
          content: i % 5 == 3
              ? ''
              : _journalStory(
                  index: i,
                  instrument: instrument,
                  side: side,
                  setup: setup,
                  emotion: emotion,
                  entry: entry,
                  exit: exit,
                  stop: stop,
                  target: target,
                  size: size,
                  pnl: pnl,
                  risk: risk,
                  open: open,
                  openedAt: openedAt,
                ),
          updatedAt: edited.isAfter(_now) ? _now : edited,
        ).withDerivedCounts(),
      );
    }
    return result;
  }

  /// Closed and open positions backing the journal, portfolio and dashboard,
  /// with the note links attached.
  List<AppTrade> trades({int count = 42}) => <AppTrade>[
    for (final AppTrade t in _rawTrades(count: count))
      t.copyWith(linkedNoteIds: _linkSeed.notesForJournal(t.id)),
  ];

  /// Pre-trade discipline gates shown before logging an entry.
  List<AppChecklistItem> checklist() => const <AppChecklistItem>[
    AppChecklistItem(
      id: 'chk_bias',
      label: 'Higher timeframe bias confirmed',
      description: 'Daily and 4H structure agree with the intended direction.',
      icon: Icons.timeline_rounded,
      done: true,
    ),
    AppChecklistItem(
      id: 'chk_risk',
      label: 'Risk is within 1% of equity',
      description: 'Position size derived from stop distance, not conviction.',
      icon: Icons.shield_outlined,
      done: true,
    ),
    AppChecklistItem(
      id: 'chk_news',
      label: 'No event risk in the next hour',
      description: 'Checked economic calendar and earnings dates.',
      icon: Icons.event_note_outlined,
    ),
    AppChecklistItem(
      id: 'chk_journal',
      label: 'Thesis written before entry',
      description: 'Invalidation level and target recorded in the journal.',
      icon: Icons.edit_note_rounded,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Strategies
  // ---------------------------------------------------------------------------

  /// Playbook lifecycle states, cycled so every badge appears in the library.
  static const List<AppStrategyStatus> _strategyStatusCycle =
      <AppStrategyStatus>[
        AppStrategyStatus.live,
        AppStrategyStatus.live,
        AppStrategyStatus.testing,
        AppStrategyStatus.live,
        AppStrategyStatus.draft,
        AppStrategyStatus.retired,
      ];

  static const List<List<String>> _strategyTagSets = <List<String>>[
    <String>['intraday', 'index', 'momentum'],
    <String>['intraday', 'mean-reversion'],
    <String>['swing', 'trend'],
    <String>['intraday', 'vwap'],
    <String>['intraday', 'reversal'],
    <String>['swing', 'events'],
  ];

  static const List<String> _strategySummaries = <String>[
    'Buy the break of the first 15-minute range on index futures when the '
        'pre-open gap is narrow enough for the range to mean something.',
    'Short the open of a gap that has no news behind it and let it fill back '
        'into the prior close.',
    'Add to an established daily trend on the first pullback that holds the '
        '20-EMA, sized so a failed retest costs less than the last leg paid.',
    'Take the reclaim of VWAP after a failed morning push, using the session '
        'volume-weighted price as both trigger and invalidation.',
    'Buy the failure of an obvious breakdown level once the sellers who forced '
        'it are trapped below the reclaim.',
    'Hold the post-earnings drift for two to five sessions when the reaction '
        'candle closes in the top quartile of its range.',
  ];

  /// Strategy playbooks before any cross-link is attached. Link-free for the
  /// same reason [_rawTrades] is.
  List<AppStrategy> _rawStrategies() {
    final Random rng = _rng(51);
    return <AppStrategy>[
      for (int i = 0; i < _setups.length; i++)
        AppStrategy(
          id: 'stg_${i + 1}',
          userId: 'demo_user',
          name: _setups[i],
          summary: _strategySummaries[i],
          content: _strategyPlaybook(i),
          status: _strategyStatusCycle[i],
          tags: _strategyTagSets[i],
          linkedTickers: <String>[
            _instruments[(i * 2) % _instruments.length].symbol,
            _instruments[(i * 2 + 5) % _instruments.length].symbol,
          ],
          category: i.isEven ? 'bullish' : 'bearish',
          isPublic: i % 3 != 0,
          isFavorite: i < 2,
          trades: 24 + rng.nextInt(140),
          winRate: _round(38 + rng.nextDouble() * 34, 1),
          avgR: _round(-0.4 + rng.nextDouble() * 2.6),
          netPnl: _round((rng.nextDouble() - 0.3) * 24000),
          createdAt: _now.subtract(Duration(days: 120 + i * 11)),
          updatedAt: _now.subtract(Duration(days: i * 3 + 1)),
          versionCount: 2 + rng.nextInt(6),
          equityCurve: _spark(60 + i, points: 18, drift: i.isEven ? 0.8 : -0.4),
        ).withDerivedCounts(),
    ];
  }

  /// The strategy library with its note and journal links attached.
  List<AppStrategy> strategies() => <AppStrategy>[
    for (final AppStrategy s in _rawStrategies())
      s.copyWith(
        linkedNoteIds: _linkSeed.notesForStrategy(s.id),
        linkedJournalIds: _linkSeed.journalForStrategy(s.id),
      ),
  ];

  static const List<String> _versionNotes = <String>[
    'Tightened the stop to the prior swing and added a session filter.',
    'Documented the invalidation level instead of leaving it to judgement.',
    'Replaced the fixed target with a partial at 1R and a trail on the rest.',
    'Added the pre-open gap filter after three losses on wide-gap days.',
    'Cut the afternoon window — the sample after 14:00 had no edge.',
    'Rewrote the sizing rules against stop distance rather than conviction.',
    'First draft. Rules only, no sizing and no review cadence yet.',
  ];

  /// Saved revisions for a single strategy note.
  ///
  /// Older revisions are the current playbook with its later sections removed.
  /// A playbook grows section by section, so a version list where every entry
  /// carries the same body cannot show a trader what they actually changed —
  /// and the restore button has nothing to restore.
  List<AppStrategyVersion> strategyVersions(String strategyId) {
    final Random rng = _rng(strategyId.hashCode.abs() % 9999);
    final int count = 4 + rng.nextInt(3);
    final int index = _strategyIndexOf(strategyId);
    final String body = _strategyPlaybook(index);
    final List<String> sections = _markdownSections(body);
    return List<AppStrategyVersion>.generate(count, (int i) {
      final int version = count - i;
      final int kept = (sections.length - i).clamp(1, sections.length);
      final String content = i == 0 ? body : sections.take(kept).join('\n\n');
      return AppStrategyVersion(
        id: '${strategyId}_v$version',
        strategyId: strategyId,
        version: version,
        savedAt: _now.subtract(Duration(days: i * 6 + 1)),
        author: _people[i % _people.length].name,
        note: i == count - 1
            ? _versionNotes.last
            : _versionNotes[(index + i) % (_versionNotes.length - 1)],
        // The one-line summary is what the playbook was always *about*; the body
        // is what got revised. Carrying it on every revision is what lets the
        // version list stay readable when the body is collapsed.
        summary: _strategySummaries[index],
        content: content,
        wordCount: AppMarkdownStats.of(content).wordCount,
        isCurrent: i == 0,
      );
    });
  }

  /// `stg_3` → `2`. Falls back to a stable bucket so an unknown id still gets a
  /// consistent playbook rather than an empty one.
  int _strategyIndexOf(String strategyId) {
    final int? parsed = int.tryParse(strategyId.split('_').last);
    if (parsed != null && parsed >= 1 && parsed <= _setups.length) {
      return parsed - 1;
    }
    return strategyId.hashCode.abs() % _setups.length;
  }

  /// Splits markdown on `##` headings, keeping each heading with its body.
  static List<String> _markdownSections(String markdown) {
    final List<String> out = <String>[];
    final StringBuffer current = StringBuffer();
    for (final String line in markdown.split('\n')) {
      if (line.startsWith('## ') && current.toString().trim().isNotEmpty) {
        out.add(current.toString().trim());
        current.clear();
      }
      current.writeln(line);
    }
    if (current.toString().trim().isNotEmpty) {
      out.add(current.toString().trim());
    }
    return out;
  }

  /// Nodes and links for the strategy relationship graph.
  ({List<AppGraphNode> nodes, List<AppGraphLink> links}) strategyGraph() {
    final List<AppStrategy> library = strategies();
    final List<AppGraphNode> nodes = <AppGraphNode>[
      for (final AppStrategy s in library)
        AppGraphNode(
          id: s.id,
          label: s.name,
          group: 'Strategy',
          weight: 1.6,
          intent: s.netPnl >= 0 ? UiIntent.success : UiIntent.danger,
        ),
      for (final AppTicker t in tickers(limit: 6))
        AppGraphNode(
          id: t.symbol,
          label: t.symbol,
          group: t.category ?? 'Instrument',
          intent: UiIntent.primary,
        ),
    ];
    final Random rng = _rng(71);
    final List<AppGraphLink> links = <AppGraphLink>[
      for (final AppStrategy s in library)
        for (final AppTicker t in tickers(limit: 6))
          if (rng.nextDouble() > 0.55)
            AppGraphLink(
              source: s.id,
              target: t.symbol,
              strength: _round(0.4 + rng.nextDouble(), 1),
              label: '${8 + rng.nextInt(40)} trades',
            ),
    ];
    return (nodes: nodes, links: links);
  }

  /// Simulation output for the strategy analyzer.
  AppBacktestResult backtest(AppStrategy strategy) => AppBacktestResult(
    id: 'bt_${strategy.id}',
    name: strategy.name,
    netPnl: strategy.netPnl,
    winRate: strategy.winRate,
    trades: strategy.trades,
    equityCurve: strategy.equityCurve,
    maxDrawdown: _round(6 + (strategy.id.hashCode.abs() % 14).toDouble()),
    profitFactor: _round(0.8 + (strategy.winRate / 100) * 2.2),
    sharpe: _round(0.4 + (strategy.avgR.abs() * 0.7)),
    runAt: _now.subtract(const Duration(hours: 3)),
  );

  // ---------------------------------------------------------------------------
  // Community
  // ---------------------------------------------------------------------------

  static const List<String> _postBodies = <String>[
    'Rotated out of TATAMOTORS into RELIANCE today. Structure is clean on the 4H and the daily trend is intact.',
    'Bank Nifty gave a textbook opening range breakout. Took partials at 1R and trailed the rest under the 15m swing.',
    'Reminder: your edge is worthless without position sizing. Two oversized losers erase ten disciplined winners.',
    'Journal review for the week: 14 trades, 8 winners, avg 1.6R. Every loss came from entries taken outside the plan.',
    'INFY earnings drift setup is still working. Entry on the first pullback after the gap, stop under the gap low.',
    'Sharing my updated pre-trade checklist. The news-window gate alone removed my three worst trades last month.',
  ];

  /// Twitter-style community feed posts.
  List<AppPost> posts({int? limit}) {
    final Random rng = _rng(81);
    final List<AppTrader> authors = traders();
    final List<AppPost> all = <AppPost>[
      for (int i = 0; i < _postBodies.length; i++)
        AppPost(
          id: 'post_${i + 1}',
          author: authors[i % authors.length],
          body: _postBodies[i],
          createdAt: _now.subtract(Duration(minutes: 7 + i * 83)),
          type: i % 3 == 0 ? 'analysis' : 'note',
          tickers: <String>[
            _instruments[i % _instruments.length].symbol,
            _instruments[(i + 3) % _instruments.length].symbol,
          ],
          attachments: <AppPostAttachment>[
            if (i % 3 == 0)
              AppPostChartAttachment(<UiCandle>[
                for (final AppCandle c in candles(
                  _instruments[i % _instruments.length].symbol,
                  count: 32,
                ))
                  UiCandle(
                    time: c.time,
                    open: c.open,
                    high: c.high,
                    low: c.low,
                    close: c.close,
                    volume: c.volume,
                  ),
              ]),
            if (i % 4 == 1)
              AppPostStrategyAttachment(
                _setups[i % _setups.length],
                locked: i.isOdd,
              ),
          ],
          likes: 24 + rng.nextInt(420),
          comments: rng.nextInt(48),
          views: 140 + rng.nextInt(2800),
          liked: i % 3 == 0,
          saved: i % 4 == 0,
        ),
    ];
    return limit == null ? all : all.take(limit).toList();
  }

  /// Replies on a post detail surface.
  List<AppComment> comments(String postId) {
    final Random rng = _rng(postId.hashCode.abs() % 9999);
    final List<AppTrader> authors = traders();
    return List<AppComment>.generate(4, (int i) {
      return AppComment(
        id: '${postId}_c$i',
        author: authors[(i + 1) % authors.length],
        body: const <String>[
          'Clean read. What invalidates the idea for you?',
          'Same setup on SBIN this morning, worked well with a tighter stop.',
          'Appreciate you posting the losers too. That is the useful half.',
          'How are you sizing this relative to your daily loss cap?',
        ][i],
        createdAt: _now.subtract(Duration(minutes: 12 + i * 37)),
        likes: rng.nextInt(38),
        liked: i == 1,
      );
    });
  }

  /// Leaderboard rows keyed by trader with the period return.
  List<MapEntry<AppTrader, double>> leaderboard(String period) {
    final Random rng = _rng(period.hashCode.abs() % 9999);
    final List<MapEntry<AppTrader, double>> rows =
        <MapEntry<AppTrader, double>>[
          for (final AppTrader t in traders())
            MapEntry<AppTrader, double>(
              t,
              _round(rng.nextDouble() * 48000 - 6000),
            ),
        ];
    rows.sort(
      (MapEntry<AppTrader, double> a, MapEntry<AppTrader, double> b) =>
          b.value.compareTo(a.value),
    );
    return rows;
  }

  // ---------------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------------

  /// Direct-message threads for the inbox.
  List<AppConversation> conversations() {
    final Random rng = _rng(91);
    final List<AppTrader> peers = traders();
    return <AppConversation>[
      for (int i = 0; i < peers.length; i++)
        AppConversation(
          id: 'conv_${i + 1}',
          peer: peers[i],
          lastMessage: const <String>[
            'Sent you the updated risk sheet.',
            'Did you take the BANKNIFTY breakout?',
            'Review notes are in the shared strategy note.',
            'Payout landed, thanks for the heads up.',
            'Let us pair on the journal audit tomorrow.',
            'That gap fade stat holds on 3 years of data.',
          ][i % 6],
          lastMessageAt: _now.subtract(Duration(minutes: 4 + i * 121)),
          unread: i < 2 ? 1 + rng.nextInt(3) : 0,
        ),
    ];
  }

  /// Messages inside a single thread.
  List<AppChatMessage> chatMessages(String conversationId) {
    final Random rng = _rng(conversationId.hashCode.abs() % 9999);
    const List<String> bodies = <String>[
      'Morning — did you get the risk sheet?',
      'Yes, reviewing it now. The drawdown cap looks tight.',
      'It is intentional. Two red days should pause new entries.',
      'Agreed. I will mirror it in my personal rules.',
      'Ping me after the close and we can compare journals.',
    ];
    return List<AppChatMessage>.generate(bodies.length, (int i) {
      return AppChatMessage(
        id: '${conversationId}_m$i',
        body: bodies[i],
        fromMe: i.isOdd,
        sentAt: _now.subtract(Duration(minutes: (bodies.length - i) * 9)),
        pending: false,
      );
    })..shuffle(Random(rng.nextInt(3)));
  }

  // ---------------------------------------------------------------------------
  // Notifications, news and AI
  // ---------------------------------------------------------------------------

  /// Notification-centre entries across every category.
  List<AppNotification> notifications() {
    // The risk and billing entries quote figures that exist elsewhere in the
    // app — the configured loss cap and the plan catalogue's price. They are
    // read from those rather than written out, so a notification cannot tell the
    // reader about a limit or a charge the rest of the app disagrees with.
    final double dayNet = dayPnl(
      days: 1,
    ).fold<double>(0, (double sum, AppDayPnl d) => sum + d.pnl);
    final double lossSoFar = dayNet < 0 ? -dayNet : 0;
    final double premiumPrice = planPrice(AppTier.premium);
    final AppTicker alertTicker = tickerFor('RELIANCE');
    final List<_NotificationSeed> seeds = <_NotificationSeed>[
      _NotificationSeed(
        'Price alert triggered',
        '${alertTicker.symbol} crossed above '
            '${AppTokens.price(levelBelow(alertTicker.price))} — your alert '
            'fired at ${AppTokens.money(alertTicker.price)}.',
        'Alerts',
        Icons.notifications_active_outlined,
        false,
      ),
      const _NotificationSeed(
        'Weekly journal review ready',
        '14 trades analysed. Discipline score improved to 4.1 / 5.',
        'AI',
        Icons.auto_awesome_outlined,
        false,
      ),
      const _NotificationSeed(
        'Ava Chen replied to your post',
        '"Clean read. What invalidates the idea for you?"',
        'Community',
        Icons.forum_outlined,
        false,
      ),
      _NotificationSeed(
        lossSoFar > 0 ? 'Risk limit warning' : 'Risk limits are clear',
        lossSoFar > 0
            ? 'Daily loss is ${AppTokens.money(lossSoFar, decimals: 0)} — '
                  '${AppTokens.percent(lossSoFar / dailyLossCap * 100, decimals: 0)} '
                  'of your ${AppTokens.money(dailyLossCap, decimals: 0)} cap.'
            : 'Your full ${AppTokens.money(dailyLossCap, decimals: 0)} daily loss cap is still available.',
        'Risk',
        Icons.shield_outlined,
        false,
      ),
      _NotificationSeed(
        'Invoice paid',
        'TradeX ${AppTokens.tierLabel(AppTier.premium)} renewed for ${AppTokens.price(premiumPrice)}.',
        'Billing',
        Icons.credit_card_outlined,
        true,
      ),
      const _NotificationSeed(
        'New follower',
        'Rohan Mehta started following you.',
        'Community',
        Icons.person_add_alt_outlined,
        true,
      ),
      const _NotificationSeed(
        'Strategy note shared',
        'Neha Kapoor shared "Failed breakdown" with you.',
        'Strategies',
        Icons.account_tree_outlined,
        true,
      ),
    ];
    return <AppNotification>[
      for (int i = 0; i < seeds.length; i++)
        AppNotification(
          id: 'ntf_${i + 1}',
          title: seeds[i].title,
          body: seeds[i].body,
          createdAt: _now.subtract(Duration(minutes: 6 + i * 94)),
          icon: seeds[i].icon,
          category: seeds[i].category,
          read: seeds[i].read,
        ),
    ];
  }

  /// Categories offered in notification preferences and centre filters.
  List<String> get notificationCategories => notifications()
      .map((AppNotification n) => n.category ?? 'Other')
      .toSet()
      .toList();

  /// Market headlines with sentiment scoring.
  List<AppNewsItem> news({int? limit}) {
    const List<List<String>> seeds = <List<String>>[
      <String>[
        'RBI holds repo rate at 6.50%, flags resilient domestic demand',
        'Economic Times',
        'The Monetary Policy Committee kept rates unchanged while projecting 7.2% growth for the year.',
      ],
      <String>[
        'IT majors guide for stronger H2 as deal pipeline widens',
        'Mint',
        'Infosys and TCS both pointed to improving discretionary spend in BFSI clients.',
      ],
      <String>[
        'Crude slips 2% on demand concerns, energy names under pressure',
        'Reuters',
        'Brent fell below the prior week range, pressuring refining margins.',
      ],
      <String>[
        'FII flows turn positive for the third straight session',
        'Business Standard',
        'Net institutional buying was concentrated in financials and autos.',
      ],
      <String>[
        'Bank Nifty reclaims 52,000 as credit growth stays above 14%',
        'Moneycontrol',
        'Private lenders led the advance with broad participation.',
      ],
    ];
    final Random rng = _rng(101);
    final List<AppNewsItem> all = <AppNewsItem>[
      for (int i = 0; i < seeds.length; i++)
        AppNewsItem(
          id: 'news_${i + 1}',
          headline: seeds[i][0],
          source: seeds[i][1],
          publishedAt: _now.subtract(Duration(minutes: 18 + i * 67)),
          sentimentScore: _round(rng.nextDouble() * 1.6 - 0.6),
          tickers: <String>[
            _instruments[i % _instruments.length].symbol,
            _instruments[(i + 4) % _instruments.length].symbol,
          ],
          summary: seeds[i][2],
        ),
    ];
    return limit == null ? all : all.take(limit).toList();
  }

  /// AI-generated market and journal insights.
  List<AppAiInsight> insights({int? limit}) {
    // The continuation trigger is read off the instrument's own quote, so an
    // insight can never point at a level the symbol is nowhere near.
    final AppTicker flagTicker = tickerFor('RELIANCE');
    final List<List<String>> seeds = <List<String>>[
      <String>[
        'Pattern detected: bull flag on ${flagTicker.symbol}',
        '${flagTicker.symbol} is compressing on the 1H with falling volume. '
            'A close above ${AppTokens.price(levelAbove(flagTicker.price))} '
            'with expansion would confirm continuation.',
        flagTicker.symbol,
      ],
      const <String>[
        'Your win rate drops 19% after 2pm',
        'Across 42 logged trades, afternoon entries underperform. Consider a hard cut-off after the midday session.',
        'NIFTY50',
      ],
      const <String>[
        'Oversized losers are capping your expectancy',
        'Your three largest losses each exceeded 2R. Normalising risk would lift net P/L by an estimated 31%.',
        'BANKNIFTY',
      ],
      const <String>[
        'Gap fade edge is decaying',
        'Win rate on gap fades fell from 61% to 44% over the last 20 trades. Re-test the filter before sizing up.',
        'TATAMOTORS',
      ],
    ];
    final Random rng = _rng(111);
    final List<AppAiInsight> all = <AppAiInsight>[
      for (int i = 0; i < seeds.length; i++)
        AppAiInsight(
          id: 'ai_${i + 1}',
          title: seeds[i][0],
          body: seeds[i][1],
          confidence: _round(0.62 + rng.nextDouble() * 0.34),
          sentimentScore: _round(rng.nextDouble() * 1.6 - 0.7),
          tickers: <String>[seeds[i][2]],
          createdAt: _now.subtract(Duration(minutes: 9 + i * 41)),
        ),
    ];
    return limit == null ? all : all.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Aggregates
  // ---------------------------------------------------------------------------

  /// Blocks of the trading session the desk reports against, in local market
  /// hours. Analytics buckets trades with these instead of inventing its own
  /// boundaries, so a venue change only has to be made here.
  List<({int fromHour, int toHour, String label})> sessionBlocks() =>
      const <({int fromHour, int toHour, String label})>[
        (fromHour: 0, toHour: 11, label: 'Open · to 11:00'),
        (fromHour: 11, toHour: 13, label: 'Midday · 11-13'),
        (fromHour: 13, toHour: 15, label: 'Afternoon · 13-15'),
        (fromHour: 15, toHour: 24, label: 'Close · after 15:00'),
      ];

  /// Daily P/L cells for the calendar heatmap.
  List<AppDayPnl> dayPnl({int days = 35}) {
    final Random rng = _rng(121);
    return List<AppDayPnl>.generate(days, (int i) {
      final bool flat = rng.nextDouble() < 0.18;
      return AppDayPnl(
        date: _now.subtract(Duration(days: days - 1 - i)),
        pnl: flat ? 0 : _round((rng.nextDouble() - 0.42) * 9000),
        trades: flat ? 0 : 1 + rng.nextInt(5),
      );
    });
  }

  /// Cumulative equity series for curve blocks.
  List<AppSeriesPoint> equitySeries({int points = 30}) {
    final Random rng = _rng(131);
    double equity = 480000;
    return List<AppSeriesPoint>.generate(points, (int i) {
      equity += (rng.nextDouble() - 0.4) * 9000;
      final DateTime date = _now.subtract(Duration(days: points - 1 - i));
      return AppSeriesPoint(
        label: AppTokens.shortDate(date),
        value: _round(equity),
      );
    });
  }

  /// Drawdown series expressed as negative percentages.
  List<double> drawdownSeries({int points = 30}) {
    final Random rng = _rng(141);
    return List<double>.generate(
      points,
      (int i) => _round(-rng.nextDouble() * 12, 1),
    );
  }

  /// Desk-wide daily loss cap in account currency. The risk meter, the desk
  /// risk limits and the copilot all read this one number.
  double get dailyLossCap => 25000;

  /// Default account-percentage risk budget for a single entry.
  double get riskPerTradePercent => 1;

  /// Seats the desk's plan is licensed for. Seat usage, the invite flow and the
  /// plan-usage meters all divide by this one number.
  int get deskSeatLicences => 10;

  /// How long a seat can sit unused before the console suggests reclaiming it.
  int get deskIdleSeatDays => 14;

  /// Retention window the plan gives audit entries.
  int get deskAuditRetentionDays => 365;

  // ---------------------------------------------------------------------------
  // Affiliate programme
  // ---------------------------------------------------------------------------
  static const List<_ReferralSeed> _referralSeeds = <_ReferralSeed>[
    _ReferralSeed('Aarav Mehta', 'aarav.mehta@example.com', 'Organic search'),
    _ReferralSeed('Diya Kapoor', 'diya.kapoor@example.com', 'YouTube review'),
    _ReferralSeed('Rohit Verma', 'rohit.verma@example.com', 'Newsletter'),
    _ReferralSeed('Sneha Iyer', 'sneha.iyer@example.com', 'X thread'),
    _ReferralSeed('Kabir Nair', 'kabir.nair@example.com', 'Discord'),
    _ReferralSeed('Meera Joshi', 'meera.joshi@example.com', 'YouTube review'),
    _ReferralSeed('Vivaan Rao', 'vivaan.rao@example.com', 'Organic search'),
    _ReferralSeed('Ishita Bose', 'ishita.bose@example.com', 'Newsletter'),
    _ReferralSeed('Arjun Pillai', 'arjun.pillai@example.com', 'Webinar'),
    _ReferralSeed('Nisha Gupta', 'nisha.gupta@example.com', 'X thread'),
  ];

  /// Referred accounts owned by the signed-in affiliate.
  List<
    ({
      String id,
      String name,
      String email,
      String channel,
      DateTime joinedAt,
      AppTier tier,
      String status,
      double commission,
    })
  >
  referrals() {
    final Random rng = _rng(151);
    const List<String> statuses = <String>['active', 'trialing', 'churned'];
    return <
      ({
        String id,
        String name,
        String email,
        String channel,
        DateTime joinedAt,
        AppTier tier,
        String status,
        double commission,
      })
    >[
      for (int i = 0; i < _referralSeeds.length; i++)
        (
          id: 'ref_${i + 1}',
          name: _referralSeeds[i].name,
          email: _referralSeeds[i].email,
          channel: _referralSeeds[i].channel,
          joinedAt: _now.subtract(Duration(days: 3 + i * 9 + rng.nextInt(6))),
          tier: i % 4 == 0
              ? AppTier.enterprise
              : (i.isEven ? AppTier.premium : AppTier.free),
          status: statuses[i % 3 == 2 && i > 6 ? 2 : (i % 5 == 1 ? 1 : 0)],
          commission: _round(
            i % 4 == 0
                ? 4200 + rng.nextDouble() * 2600
                : rng.nextDouble() * 1800,
          ),
        ),
    ];
  }

  /// Distinct acquisition channels, derived from the referral seeds.
  List<String> get referralChannels =>
      _referralSeeds.map((_ReferralSeed s) => s.channel).toSet().toList()
        ..sort();

  /// Click / signup funnel per channel.
  List<({String channel, int clicks, int signups, double revenue})>
  referralFunnel() {
    final Random rng = _rng(161);
    return <({String channel, int clicks, int signups, double revenue})>[
      for (final String channel in referralChannels)
        (
          channel: channel,
          clicks: 240 + rng.nextInt(1800),
          signups: 4 + rng.nextInt(26),
          revenue: _round(1200 + rng.nextDouble() * 9400),
        ),
    ];
  }

  /// Daily click volume for the affiliate traffic chart.
  List<AppSeriesPoint> referralClicks({int days = 30}) {
    final Random rng = _rng(171);
    return List<AppSeriesPoint>.generate(days, (int i) {
      final DateTime date = _now.subtract(Duration(days: days - 1 - i));
      return AppSeriesPoint(
        label: AppTokens.shortDate(date),
        value: (30 + rng.nextInt(190)).toDouble(),
      );
    });
  }

  /// Payout ledger rows for the affiliate payouts surface.
  List<
    ({
      String id,
      double amount,
      DateTime requestedAt,
      DateTime? paidAt,
      String method,
      String status,
      String? reference,
    })
  >
  payouts() {
    final Random rng = _rng(181);
    return <
      ({
        String id,
        double amount,
        DateTime requestedAt,
        DateTime? paidAt,
        String method,
        String status,
        String? reference,
      })
    >[
      for (int i = 0; i < 6; i++)
        (
          id: 'pay_${1000 + i}',
          amount: _round(8000 + rng.nextDouble() * 42000),
          requestedAt: _now.subtract(Duration(days: 8 + i * 30)),
          paidAt: i == 0 ? null : _now.subtract(Duration(days: 4 + i * 30)),
          method: i.isEven ? 'Bank transfer (NEFT)' : 'UPI',
          status: i == 0 ? 'pending' : (i == 1 ? 'processing' : 'paid'),
          reference: i == 0 ? null : 'TXN${728400 + i * 137}',
        ),
    ];
  }

  /// Withdrawal methods offered to affiliates, with the limits and lead times
  /// the finance team publishes for each one.
  List<
    ({
      String id,
      String label,
      String detail,
      IconData icon,
      double minimum,
      double feePercent,
      String eta,
    })
  >
  payoutMethods() =>
      const <
        ({
          String id,
          String label,
          String detail,
          IconData icon,
          double minimum,
          double feePercent,
          String eta,
        })
      >[
        (
          id: 'neft',
          label: 'Bank transfer (NEFT)',
          detail: 'To the account on your KYC record',
          icon: Icons.account_balance_outlined,
          minimum: 5000,
          feePercent: 0,
          eta: '2–3 working days',
        ),
        (
          id: 'upi',
          label: 'UPI',
          detail: 'Instant to a verified UPI ID',
          icon: Icons.qr_code_2_rounded,
          minimum: 1000,
          feePercent: 0,
          eta: 'Same day',
        ),
        (
          id: 'paypal',
          label: 'PayPal',
          detail: 'For partners billing from outside India',
          icon: Icons.public_rounded,
          minimum: 8000,
          feePercent: 2.9,
          eta: '3–5 working days',
        ),
        (
          id: 'credit',
          label: 'Platform credit',
          detail: 'Applied to your own subscription, no fee',
          icon: Icons.card_giftcard_outlined,
          minimum: 500,
          feePercent: 0,
          eta: 'Immediate',
        ),
      ];

  /// Downloadable creatives for the marketing kit.
  List<
    ({
      String id,
      String title,
      String format,
      String dimensions,
      String sizeLabel,
      IconData icon,
    })
  >
  creatives() =>
      const <
        ({
          String id,
          String title,
          String format,
          String dimensions,
          String sizeLabel,
          IconData icon,
        })
      >[
        (
          id: 'cr_banner_lg',
          title: 'Leaderboard banner',
          format: 'PNG',
          dimensions: '728 × 90',
          sizeLabel: '148 KB',
          icon: Icons.image_outlined,
        ),
        (
          id: 'cr_banner_sq',
          title: 'Square social tile',
          format: 'PNG',
          dimensions: '1080 × 1080',
          sizeLabel: '412 KB',
          icon: Icons.crop_square_rounded,
        ),
        (
          id: 'cr_story',
          title: 'Story / Reels frame',
          format: 'MP4',
          dimensions: '1080 × 1920',
          sizeLabel: '3.2 MB',
          icon: Icons.smart_display_outlined,
        ),
        (
          id: 'cr_deck',
          title: 'Partner pitch deck',
          format: 'PDF',
          dimensions: '16 : 9',
          sizeLabel: '1.8 MB',
          icon: Icons.slideshow_rounded,
        ),
        (
          id: 'cr_copy',
          title: 'Email + caption copy pack',
          format: 'DOCX',
          dimensions: '6 templates',
          sizeLabel: '64 KB',
          icon: Icons.subject_rounded,
        ),
        (
          id: 'cr_logo',
          title: 'Brand & logo kit',
          format: 'ZIP',
          dimensions: 'SVG + PNG',
          sizeLabel: '2.4 MB',
          icon: Icons.workspaces_outline,
        ),
      ];

  // ---------------------------------------------------------------------------
  // Desk / organisation
  // ---------------------------------------------------------------------------

  static const List<_MemberSeed> _memberSeeds = <_MemberSeed>[
    _MemberSeed('Nitish Kumar', 'nitish@tradex.ai', AppTeamRole.owner),
    _MemberSeed('Ananya Sharma', 'ananya@tradex.ai', AppTeamRole.admin),
    _MemberSeed('Rahul Menon', 'rahul@tradex.ai', AppTeamRole.analyst),
    _MemberSeed('Priya Desai', 'priya@tradex.ai', AppTeamRole.analyst),
    _MemberSeed('Karan Bhatia', 'karan@tradex.ai', AppTeamRole.member),
    _MemberSeed('Tanvi Rao', 'tanvi@tradex.ai', AppTeamRole.member),
    _MemberSeed('Farhan Qureshi', 'farhan@tradex.ai', AppTeamRole.viewer),
  ];

  /// Desk roster for the organisation team surface.
  List<AppTeamMember> teamMembers() {
    final Random rng = _rng(191);
    return <AppTeamMember>[
      for (int i = 0; i < _memberSeeds.length; i++)
        AppTeamMember(
          id: 'mem_${i + 1}',
          name: _memberSeeds[i].name,
          email: _memberSeeds[i].email,
          role: _memberSeeds[i].role,
          status: i == 5
              ? AppMemberStatus.invited
              : (i == 6 ? AppMemberStatus.suspended : AppMemberStatus.active),
          lastActiveAt: i == 5
              ? null
              : _now.subtract(Duration(minutes: 6 + rng.nextInt(4000))),
        ),
    ];
  }

  /// Desk seats a licence actually occupies. A suspended member keeps their
  /// record but releases the seat, which is what the billing meter is counting.
  int get occupiedDeskSeats => teamMembers()
      .where((AppTeamMember m) => m.status != AppMemberStatus.suspended)
      .length;

  static const List<String> _auditActions = <String>[
    'Signed in',
    'Updated risk limits',
    'Exported journal CSV',
    'Rotated API key',
    'Invited a team member',
    'Approved an affiliate application',
    'Changed subscription tier',
    'Deleted a strategy version',
    'Enabled two-factor authentication',
    'Downloaded audit log',
  ];

  /// Immutable audit trail rows.
  List<AppAuditEntry> auditLog({int count = 24}) {
    final Random rng = _rng(201);
    final List<AppTeamMember> members = teamMembers();
    return List<AppAuditEntry>.generate(count, (int i) {
      final AppTeamMember actor = members[rng.nextInt(members.length)];
      return AppAuditEntry(
        id: 'aud_${count - i}',
        actor: actor.email,
        action: _auditActions[(i + rng.nextInt(3)) % _auditActions.length],
        at: _now.subtract(Duration(minutes: 24 + i * 97 + rng.nextInt(40))),
        target: i.isEven
            ? 'desk/${actor.name.split(' ').first.toLowerCase()}'
            : null,
        ip: '10.${rng.nextInt(60)}.${rng.nextInt(255)}.${1 + rng.nextInt(240)}',
      );
    });
  }

  /// Issued API keys for the integrations surface.
  List<AppApiKey> apiKeys() {
    final Random rng = _rng(211);
    const List<String> labels = <String>[
      'Production backend',
      'Broker sync worker',
      'Analytics warehouse',
      'Legacy webhook',
    ];
    return <AppApiKey>[
      for (int i = 0; i < labels.length; i++)
        AppApiKey(
          id: 'key_${i + 1}',
          label: labels[i],
          maskedKey: 'tdx_live_••••••••${2100 + i * 373}',
          createdAt: _now.subtract(Duration(days: 20 + i * 45)),
          lastUsedAt: i == 3
              ? null
              : _now.subtract(Duration(minutes: 3 + rng.nextInt(900))),
          revoked: i == 3,
          scopes: i == 0
              ? const <String>['trades:read', 'trades:write', 'journal:read']
              : const <String>['trades:read'],
        ),
    ];
  }

  /// Scopes a desk key can be granted, with what each one unlocks. The key
  /// editor reads these instead of shipping its own copy of the list.
  List<({String scope, String description})> apiScopes() =>
      const <({String scope, String description})>[
        (scope: 'trades:read', description: 'Read closed and open positions.'),
        (scope: 'trades:write', description: 'Log and amend trades.'),
        (scope: 'journal:read', description: 'Read journal entries and notes.'),
        (
          scope: 'analytics:read',
          description: 'Pull desk analytics and equity.',
        ),
        (scope: 'team:read', description: 'List seats, roles and statuses.'),
        (scope: 'audit:read', description: 'Stream the audit trail.'),
      ];

  /// Plan consumption metrics for usage/billing surfaces.
  List<AppUsageMetric> usageMetrics() {
    final Random rng = _rng(221);
    return <AppUsageMetric>[
      AppUsageMetric(
        label: 'Seats',
        used: occupiedDeskSeats.toDouble(),
        limit: deskSeatLicences.toDouble(),
        unit: 'seats',
      ),
      AppUsageMetric(
        label: 'AI copilot requests',
        used: (620 + rng.nextInt(300)).toDouble(),
        limit: 5000,
        unit: 'req',
      ),
      AppUsageMetric(
        label: 'Journal entries',
        used: trades().length.toDouble(),
        limit: 5000,
      ),
      AppUsageMetric(
        label: 'API calls',
        used: (48000 + rng.nextInt(24000)).toDouble(),
        limit: 250000,
        unit: 'calls',
      ),
      AppUsageMetric(
        label: 'Storage',
        used: _round(6.4 + rng.nextDouble() * 3, 1),
        limit: 50,
        unit: 'GB',
      ),
    ];
  }

  /// Subscription plans for pricing / paywall surfaces.
  /// The single plan catalogue. Both the subscription repository and the billing
  /// settings repository read it, so a price or a feature line only ever exists
  /// once — the backend swaps this for the products it sells.
  ///
  /// Pass [annual] to price the same catalogue per year. Nothing is re-typed:
  /// the yearly amount is [annualMonthsBilled] times the monthly one, which is
  /// the same arithmetic the invoice total uses.
  List<AppPlan> plans({AppTier current = AppTier.free, bool annual = false}) {
    final List<AppPlan> monthly = _monthlyPlans(current);
    if (!annual) return monthly;
    return <AppPlan>[
      for (final AppPlan plan in monthly)
        AppPlan(
          tier: plan.tier,
          amount: plan.amount * annualMonthsBilled,
          priceLabel: AppTokens.price(plan.amount * annualMonthsBilled),
          period: '/yr',
          description: plan.description,
          features: <String>[
            ...plan.features,
            if (plan.amount > 0) '$annualMonthsFree months free, billed yearly',
          ],
          highlighted: plan.highlighted,
          current: plan.current,
        ),
    ];
  }

  /// Months charged when a plan is billed yearly. The rest of the year is the
  /// discount, so the saving on the toggle and the invoice total agree.
  int get annualMonthsBilled => 10;

  /// Months of the year an annual plan does not pay for. The saving the plan
  /// chooser advertises is derived from this, so the toggle cannot promise a
  /// discount the invoice does not take off.
  int get annualMonthsFree => 12 - annualMonthsBilled;

  /// Monthly list price per tier — the one place a plan's number is written
  /// down. Labels, annual totals, invoices and coupon arithmetic are all
  /// derived from it, so a price change here moves every surface at once.
  static const Map<AppTier, double> _monthlyAmounts = <AppTier, double>{
    AppTier.free: 0,
    AppTier.premium: 2499,
    AppTier.enterprise: 7999,
  };

  List<AppPlan> _monthlyPlans(AppTier current) => <AppPlan>[
    _plan(
      tier: AppTier.free,
      current: current,
      description: 'Core journal logging and basic charts for individuals.',
      features: const <String>[
        'Up to 100 journal entries',
        'One watchlist',
        'Basic NSE / BSE scanner',
        'Standard charts and technical indicators',
        '20 AI copilot requests / month',
        'Community read access',
      ],
    ),
    _plan(
      tier: AppTier.premium,
      current: current,
      description: 'Advanced analytics, AI copilot and unlimited journaling.',
      features: const <String>[
        'Unlimited journal entries',
        'Unlimited watchlists and alerts',
        'Real-time Level 2 market scanner',
        '500 AI copilot requests / month',
        'Strategy backtests and version history',
        'Direct messages, community posting and mentor reviews',
        'Export journal to CSV / PDF',
      ],
      highlighted: true,
    ),
    _plan(
      tier: AppTier.enterprise,
      current: current,
      description:
          'Multi-seat desks that need controls, audit and priority support.',
      features: const <String>[
        'Everything in Premium',
        '10 desk seats with role controls',
        'Institutional risk limits, audit trail and SSO',
        'Unlimited AI copilot requests',
        'API keys and warehouse export',
        'Dedicated account manager and priority support',
      ],
    ),
  ];

  /// Assembles one catalogue row, pricing it from [_monthlyAmounts] so the
  /// amount a checkout charges and the label a plan card shows are the same
  /// number formatted once.
  AppPlan _plan({
    required AppTier tier,
    required AppTier current,
    required String description,
    required List<String> features,
    bool highlighted = false,
  }) {
    final double amount = planPrice(tier);
    return AppPlan(
      tier: tier,
      amount: amount,
      priceLabel: AppTokens.price(amount),
      description: description,
      features: features,
      highlighted: highlighted,
      current: tier == current,
    );
  }

  /// Monthly list price for [tier].
  double planPrice(AppTier tier) => _monthlyAmounts[tier] ?? 0;

  /// Allowances for [tier]. Keyed so the billing meters, the copilot gate and
  /// the journal limit all read the same ceiling for the same plan.
  Map<String, int> planLimits(AppTier tier) => switch (tier) {
    AppTier.free => const <String, int>{
      'ai_queries': 20,
      'journal_trades': 100,
      'watchlists': 1,
      'alerts': 3,
    },
    AppTier.premium => const <String, int>{
      'ai_queries': 500,
      'journal_trades': 5000,
      'watchlists': 20,
      'alerts': 100,
    },
    AppTier.enterprise => const <String, int>{
      'ai_queries': 5000,
      'journal_trades': 50000,
      'watchlists': 100,
      'alerts': 500,
    },
  };

  /// Per-account usage behind the billing meters. Counts come from the same
  /// seeded records the pages render and are capped by the plan, so a meter can
  /// never show more consumed than the plan allows.
  Map<String, int> accountUsage(AppTier tier) {
    final Map<String, int> limits = planLimits(tier);
    final Random rng = _rng(447);
    int within(String key, int used) =>
        used.clamp(0, limits[key] ?? used).toInt();
    return <String, int>{
      'ai_queries_used': within(
        'ai_queries',
        (limits['ai_queries']! * 0.28).round() + rng.nextInt(24),
      ),
      'ai_queries_limit': limits['ai_queries']!,
      'journal_trades_used': within('journal_trades', trades().length),
      'journal_trades_limit': limits['journal_trades']!,
      'watchlists_used': within('watchlists', 7),
      'watchlists_limit': limits['watchlists']!,
      'alerts_used': within('alerts', 5),
      'alerts_limit': limits['alerts']!,
      // Seats are a desk capability: a single-trader plan is one seat, and an
      // enterprise licence carries the same number the plan advertises.
      'seats_used': tier == AppTier.enterprise ? occupiedDeskSeats : 1,
      'seats_limit': tier == AppTier.enterprise ? deskSeatLicences : 1,
    };
  }

  /// Achievements / streak badges for the profile surface.
  List<AppAchievement> achievements() => const <AppAchievement>[
    AppAchievement(
      id: 'ach_streak',
      title: 'Ten-session streak',
      description: 'Logged every trade for ten sessions running.',
      icon: Icons.local_fire_department_rounded,
      unlocked: true,
    ),
    AppAchievement(
      id: 'ach_discipline',
      title: 'Checklist disciplinarian',
      description: 'Cleared the pre-trade checklist 50 times.',
      icon: Icons.verified_rounded,
      unlocked: true,
    ),
    AppAchievement(
      id: 'ach_backtest',
      title: 'Lab technician',
      description: 'Run 25 backtests to unlock.',
      icon: Icons.science_rounded,
      progress: 0.68,
    ),
    AppAchievement(
      id: 'ach_mentor',
      title: 'Desk mentor',
      description: 'Reach 1,000 community followers.',
      icon: Icons.groups_rounded,
      progress: 0.42,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Global search
  // ---------------------------------------------------------------------------

  /// Flattened index behind the ⌘K palette and the search surface.
  ///
  /// Every row carries the id of the record it points at, so the surface that
  /// opens a hit can load the real trade, strategy or trader rather than
  /// unpicking the display title.
  List<AppSearchResult> searchIndex() => <AppSearchResult>[
    for (final AppTicker ticker in tickers())
      AppSearchResult(
        id: 'sr_tk_${ticker.symbol}',
        entityId: ticker.symbol,
        title: ticker.symbol,
        kind: AppSearchKind.ticker,
        subtitle: ticker.name,
        meta: AppTokens.signedPercent(ticker.changePercent),
      ),
    for (final AppTrade trade in trades().take(18))
      AppSearchResult(
        id: 'sr_tr_${trade.id}',
        entityId: trade.id,
        title: '${trade.ticker} · ${AppTokens.sideLabel(trade.side)}',
        kind: AppSearchKind.trade,
        subtitle:
            '${AppTokens.shortDate(trade.openedAt)} · ${trade.strategy ?? 'Unclassified'}',
        meta: AppTokens.signedMoney(trade.pnl),
      ),
    for (final AppStrategy strategy in strategies())
      AppSearchResult(
        id: 'sr_st_${strategy.id}',
        entityId: strategy.id,
        title: strategy.name,
        kind: AppSearchKind.strategy,
        subtitle: strategy.summary,
        meta: AppTokens.percent(strategy.winRate),
      ),
    for (final AppTrader trader in traders())
      AppSearchResult(
        id: 'sr_us_${trader.id}',
        entityId: trader.id,
        title: trader.displayName ?? trader.handle,
        kind: AppSearchKind.trader,
        subtitle: '@${trader.handle}',
        avatarUrl: trader.avatarUrl,
      ),
    for (final AppPost post in posts().take(10))
      AppSearchResult(
        id: 'sr_po_${post.id}',
        entityId: post.id,
        title: post.body.length > 60
            ? '${post.body.substring(0, 60)}…'
            : post.body,
        kind: AppSearchKind.post,
        subtitle: '@${post.author.handle}',
      ),
    for (final AppTrade trade
        in trades().where((AppTrade t) => (t.notes ?? '').isNotEmpty).take(8))
      AppSearchResult(
        id: 'sr_nt_${trade.id}',
        entityId: trade.id,
        title: trade.notes!,
        kind: AppSearchKind.note,
        subtitle: '${trade.ticker} · ${AppTokens.shortDate(trade.openedAt)}',
      ),
  ];

  // ---------------------------------------------------------------------------
  // Trader notes
  // ---------------------------------------------------------------------------

  static const List<String> _noteTitles = <String>[
    'Opening range breakout playbook',
    'Bank Nifty expiry — what actually worked',
    'Weekly review: week 34',
    'Pre-market plan — Monday',
    'Why I keep cutting winners early',
    'Position sizing cheat sheet',
    'RELIANCE swing thesis',
    'Gap-and-go checklist',
    'Rules I broke this month',
    'IT sector rotation notes',
    'Options greeks refresher',
    'Journal audit — Q3 lessons',
  ];

  static const List<AppNoteType> _noteTypeCycle = <AppNoteType>[
    AppNoteType.plan,
    AppNoteType.analysis,
    AppNoteType.review,
    AppNoteType.plan,
    AppNoteType.idea,
    AppNoteType.cheatSheet,
    AppNoteType.analysis,
    AppNoteType.cheatSheet,
    AppNoteType.review,
    AppNoteType.analysis,
    AppNoteType.cheatSheet,
    AppNoteType.review,
  ];

  static const List<List<String>> _noteTagSets = <List<String>>[
    <String>['playbook', 'breakout'],
    <String>['expiry', 'options'],
    <String>['review', 'weekly'],
    <String>['premarket'],
    <String>['psychology', 'discipline'],
    <String>['risk', 'reference'],
    <String>['swing', 'thesis'],
    <String>['checklist', 'momentum'],
    <String>['psychology', 'rules'],
    <String>['sector', 'rotation'],
    <String>['options', 'reference'],
    <String>['review', 'quarterly'],
  ];

  /// The seeded id for note [i]. Derivable from the index alone, so [_LinkSeed]
  /// can wire note edges without building the notes first.
  static String _noteId(int i) => 'note_${(i + 1).toString().padLeft(3, '0')}';

  /// Long-form markdown notes behind the Notes workspace.
  ///
  /// Bodies are deliberately varied — tables, checklists, fenced code, math and
  /// a flowchart — so the preview, the outline and the PDF export are all
  /// exercised by the seeded content rather than only by a hand-typed note.
  ///
  /// Every cross-link comes from [_linkSeed] rather than from `strategies()` or
  /// `trades()`, which is what keeps the three seeded surfaces from calling one
  /// another in a cycle while still agreeing on every edge.
  List<AppNote> notes({int? limit}) {
    final Random rng = _rng(77);
    final List<AppNote> all = <AppNote>[
      for (int i = 0; i < _noteTitles.length; i++)
        () {
          final DateTime created = _now.subtract(
            Duration(days: i * 3 + rng.nextInt(3), hours: rng.nextInt(20)),
          );
          // The edit lands after creation but never in the future. Unclamped,
          // the newest sample could be stamped up to 30 hours ahead, which
          // reads as "edited in 12 hours" on the card and outranks a note the
          // writer genuinely just saved.
          final DateTime edited = created.add(
            Duration(hours: rng.nextInt(30) + 1),
          );
          final String noteId = _noteId(i);
          final String? strategyId = _linkSeed.strategyForNote(noteId);
          return AppNote(
            id: noteId,
            userId: 'demo_user',
            title: _noteTitles[i],
            content: _noteSample(i),
            createdAt: created,
            updatedAt: edited.isAfter(_now) ? _now : edited,
            noteType: _noteTypeCycle[i],
            tags: _noteTagSets[i],
            linkedTickers: <String>[
              _instruments[i % _instruments.length].symbol,
              if (i.isEven) _instruments[(i + 4) % _instruments.length].symbol,
            ],
            strategyId: strategyId,
            strategyName: strategyId == null
                ? null
                : _setups[_strategyIndexOf(strategyId)],
            linkedJournalIds: _linkSeed.journalForNote(noteId),
            isPublic: i % 5 == 0,
          ).withDerivedCounts();
        }(),
    ];
    all.sort((AppNote a, AppNote b) => b.updatedAt.compareTo(a.updatedAt));
    return limit == null ? all : all.take(limit).toList(growable: false);
  }

  /// Six markdown bodies cycled across the seeded notes.
  String _noteSample(int i) => switch (i % 6) {
    0 =>
      '''
## Setup

Trade the **first 15-minute range** on index futures. Only take the break when
the pre-open gap is under 0.4% — anything wider and the range is noise.

| Field | Value |
| --- | --- |
| Ticker | NIFTY50 |
| Entry | Range high + 0.1% |
| Stop | Range low |
| Target | 2R |
| R:R | 1:2 |

### Pre-flight

- [x] Marked the 15m range
- [x] Checked the India VIX
- [ ] Sized the position off the stop distance
- [ ] Alert set on the range high

> If the first candle after the break closes back inside the range, the trade is
> void. No second entry.
''',
    1 =>
      '''
## What happened

Expiry ran the way the weekly OI suggested: max pain pinned near 52,000 and
every attempt above it faded inside twenty minutes.

```chart
{
  "type": "bar",
  "title": "P&L by hour",
  "labels": ["9:15", "10:15", "11:15", "12:15", "13:15", "14:15"],
  "series": [{"name": "Net", "data": [1200, -400, 900, 150, -700, 2400]}]
}
```

The edge was in *not* trading the middle of the day. Two of the three losses
came from the 12:15–13:15 chop.

### Position sizing

Risk per trade stays at \$R = 0.01 \\times equity\$, so a 40-point stop on Bank
Nifty is one lot and nothing more.
''',
    2 =>
      '''
## Scorecard

- Trades taken: **14**
- Win rate: **57%**
- Average win: 1.8R · average loss: 0.9R

## What worked

Waiting for the retest. Every trade I took on the first touch either stopped out
or gave back most of the move.

## What did not

Adding to a losing position twice on Wednesday. That single decision cost more
than the whole week's gains.

## Next week

- [ ] No adds below entry, ever
- [ ] Flat by 14:45 on expiry day
- [ ] One screenshot per trade, no exceptions
''',
    3 =>
      '''
## Bias

Neutral-to-long while 24,180 holds on the hourly.

## Key levels

| Level | Type | Note |
| --- | --- | --- |
| 24,540 | Resistance | Weekly high, heavy call OI |
| 24,380 | Pivot | Yesterday's VWAP |
| 24,180 | Support | Breakout base, invalidates the long |

## Watchlist

`RELIANCE` `HDFCBANK` `TATAMOTORS`

## Rules for the session

- [ ] Maximum three trades
- [ ] Stop trading after two losses
- [ ] No new positions after 14:30
''',
    4 =>
      '''
I keep exiting at 1R because the *unrealised* number feels like it belongs to me
already. It does not. It is a position, not a payout.

```mermaid
flowchart TD
    A[Position at +1R] --> B{Thesis intact?}
    B -->|Yes| C[Trail the stop, hold]
    B -->|No| D[Close it now]
    C --> E[Reassess at +2R]
```

### The fix

Set the target as a resting order **before** entry, then close the app. The
decision has to be made while I am neutral, not while I am watching the tape.
''',
    _ =>
      '''
## Fixed-fractional sizing

```dart
double quantity({
  required double equity,
  required double riskPercent,
  required double entry,
  required double stop,
}) {
  final double riskPerUnit = (entry - stop).abs();
  if (riskPerUnit == 0) return 0;
  return (equity * riskPercent / 100) / riskPerUnit;
}
```

## Reference table

| Risk % | Equity | Stop distance | Size |
| --- | --- | --- | --- |
| 0.5% | 500,000 | 12 | 208 |
| 1.0% | 500,000 | 12 | 416 |
| 1.0% | 500,000 | 25 | 200 |

==Never size off conviction.== Size off the stop, then decide whether the
resulting position is one you can hold.
''',
  };

  // ---------------------------------------------------------------------------
  // Journal write-ups
  // ---------------------------------------------------------------------------

  /// The markdown body for one journal entry, written against that entry's own
  /// numbers.
  ///
  /// Six shapes are cycled so the reader, the outline and the PDF exporter meet
  /// the range a real journal contains: a plan-versus-execution review, a
  /// decision timeline, a chart, a post-mortem, a levels table and a three-line
  /// log. Every number in the prose is the number stored on the entry, so a
  /// mismatch between the card and the body would be a real bug rather than a
  /// seeding artefact.
  String _journalStory({
    required int index,
    required _Instrument instrument,
    required AppSide side,
    required String setup,
    required String emotion,
    required double entry,
    required double exit,
    required double stop,
    required double target,
    required double size,
    required double pnl,
    required double risk,
    required bool open,
    required DateTime openedAt,
  }) {
    final String symbol = instrument.symbol;
    final String dir = AppTokens.sideLabel(side).toLowerCase();
    final String result = open ? 'still open' : AppTokens.signedMoney(pnl);
    final String rMultiple = open || risk == 0 ? '—' : AppTokens.rr(pnl / risk);
    final String exited = open ? 'still working' : AppTokens.price(exit);
    final String lots = size.toStringAsFixed(0);
    final String opened = AppTokens.clockTime(openedAt);
    final bool won = !open && pnl > 0;
    return switch (index % 6) {
      0 => _journalPlanVsActual(
        symbol: symbol,
        setup: setup,
        dir: dir,
        entry: entry,
        stop: stop,
        target: target,
        exited: exited,
        lots: lots,
        rMultiple: rMultiple,
        emotion: emotion,
        open: open,
        won: won,
      ),
      1 => _journalTimeline(
        symbol: symbol,
        setup: setup,
        dir: dir,
        opened: opened,
        entry: entry,
        stop: stop,
        exited: exited,
        emotion: emotion,
        open: open,
        won: won,
      ),
      2 => _journalChart(
        symbol: symbol,
        setup: setup,
        pnl: pnl,
        risk: risk,
        result: result,
        rMultiple: rMultiple,
        sector: instrument.sector,
        open: open,
      ),
      3 => _journalPostMortem(
        symbol: symbol,
        setup: setup,
        dir: dir,
        entry: entry,
        stop: stop,
        exited: exited,
        result: result,
        emotion: emotion,
        open: open,
        won: won,
      ),
      4 => _journalLevels(
        symbol: symbol,
        name: instrument.name,
        setup: setup,
        dir: dir,
        entry: entry,
        stop: stop,
        target: target,
        lots: lots,
        risk: risk,
        rMultiple: rMultiple,
        open: open,
      ),
      _ => _journalLog(
        symbol: symbol,
        setup: setup,
        dir: dir,
        entry: entry,
        exited: exited,
        result: result,
        emotion: emotion,
        open: open,
      ),
    };
  }

  /// Shape 0 — what was written down against what happened.
  String _journalPlanVsActual({
    required String symbol,
    required String setup,
    required String dir,
    required double entry,
    required double stop,
    required double target,
    required String exited,
    required String lots,
    required String rMultiple,
    required String emotion,
    required bool open,
    required bool won,
  }) =>
      '''
## Plan

$setup on `$symbol`. Took it $dir at ${AppTokens.price(entry)} with the stop at
${AppTokens.price(stop)} and the first scale at ${AppTokens.price(target)}.

| Field | Planned | Actual |
| --- | --- | --- |
| Entry | ${AppTokens.price(entry)} | ${AppTokens.price(entry)} |
| Stop | ${AppTokens.price(stop)} | held |
| Target | ${AppTokens.price(target)} | $exited |
| Size | $lots | $lots |
| Result | 2.00R | $rMultiple |

## Execution

$emotion. ${open
          ? 'Position is still on — stop is at breakeven and the plan is to hold into the close.'
          : won
          ? 'Scaled half at the target and trailed the rest under the last swing.'
          : 'Stopped out where the plan said to. No widening, no second entry.'}

## Review

- [x] Entry matched the written trigger
- [${open ? ' ' : 'x'}] Exit matched the written plan
- [${won ? 'x' : ' '}] Held the full plan without cutting early
- [ ] Screenshot attached

> ${won ? 'Repeatable. The only reason this worked is that the level was marked before the open.' : 'Nothing to fix. A losing trade taken by the rules is a cost of doing business, not a mistake.'}
''';

  /// Shape 1 — the decision path, as a flowchart plus the timestamps.
  String _journalTimeline({
    required String symbol,
    required String setup,
    required String dir,
    required String opened,
    required double entry,
    required double stop,
    required String exited,
    required String emotion,
    required bool open,
    required bool won,
  }) =>
      '''
## How it went on

Marked the level pre-open, waited for the $setup trigger on `$symbol`, and got
filled $dir at ${AppTokens.price(entry)} at $opened.

```mermaid
flowchart TD
    A[Level marked pre-open] --> B{Trigger printed?}
    B -->|Yes| C[Enter $dir @ ${AppTokens.price(entry)}]
    B -->|No| Z[Stand down]
    C --> D{Holding above ${AppTokens.price(stop)}?}
    D -->|Yes| E[${open
          ? 'Trail and hold'
          : won
          ? 'Scale at target'
          : 'Give it room to the stop'}]
    D -->|No| F[Close: $exited]
```

## Decision log

| Time | Action | Why |
| --- | --- | --- |
| $opened | Entry $dir | Trigger matched the plan |
| +20m | Stop to breakeven | ${won ? 'First push held' : 'Structure was thinning out'} |
| +1h | ${open ? 'Still on' : 'Exit at $exited'} | ${open
          ? 'Thesis intact'
          : won
          ? 'Target reached'
          : 'Invalidation hit'} |

## Honest note

$emotion. ${open
          ? 'The only open question is whether I hold this overnight; the plan says flat by the close.'
          : won
          ? 'The process was clean. Sizing was the reason this mattered at all.'
          : 'I would take it again. The setup was right; the market was not.'}
''';

  /// Shape 2 — the open-P&L path through the hold.
  ///
  /// The excursion is drawn against the amount risked rather than the realised
  /// P&L, so an entry that is still open plots a real path instead of a flat
  /// line at zero.
  String _journalChart({
    required String symbol,
    required String setup,
    required double pnl,
    required double risk,
    required String result,
    required String rMultiple,
    required String sector,
    required bool open,
  }) {
    final double unit = risk == 0 ? 100 : risk;
    String at(double multiple) => (unit * multiple).round().toString();
    final String close = open ? at(0.9) : pnl.round().toString();
    return '''
## Result

$setup on `$symbol` · $sector. ${open ? 'Still open' : 'Closed'} at $result
($rMultiple on risk).

```chart
{
  "type": "line",
  "title": "Open P&L through the hold",
  "labels": ["Entry", "+15m", "+30m", "+45m", "+1h", "${open ? 'Now' : 'Exit'}"],
  "series": [{"name": "P&L", "data": [0, ${at(0.4)}, ${at(-0.3)}, ${at(0.8)}, ${at(1.2)}, $close]}]
}
```

## Read of the tape

The excursion peaked well above where it settled. That gap is the whole lesson:
the trade was worth more mid-hold than it was at the exit, and the plan had no
rule for taking that.

## Takeaway

- [ ] Write a partial-scale rule for entries that reach 1.2R inside the hour
- [ ] Log maximum favourable excursion on every entry, not just the result
- [${open ? ' ' : 'x'}] Result reconciled against the broker statement
''';
  }

  /// Shape 3 — a post-mortem. The entry that gets read again a month later.
  String _journalPostMortem({
    required String symbol,
    required String setup,
    required String dir,
    required double entry,
    required double stop,
    required String exited,
    required String result,
    required String emotion,
    required bool open,
    required bool won,
  }) =>
      '''
## What I did

Went $dir on `$symbol` at ${AppTokens.price(entry)} calling it a $setup. Closed
at $exited for $result.

## What actually happened

The setup was not there. I wanted it to be there, which is a different thing.
The level I entered against had already been tested twice that session, and by
the third touch there was nobody left to trap.

## The rule I broke

> $emotion.

${won ? 'It worked anyway, which is the dangerous outcome — a rule broken and rewarded is a rule that will be broken again.' : 'It did not work, which at least makes the accounting honest.'}

## Cost

| Item | Value |
| --- | --- |
| Result | $result |
| Stop distance | ${AppTokens.price((entry - stop).abs())} |
| Rule broken | Third-touch entry |
| Repeat offence | Yes — fourth this month |

## Fix

- [ ] Hard rule: no entries on the third test of a level in one session
- [ ] Mark tested levels on the chart as they happen, not afterwards
- [${open ? ' ' : 'x'}] Re-read this entry before trading `$symbol` again
''';

  /// Shape 4 — the levels table and the sizing arithmetic behind them.
  String _journalLevels({
    required String symbol,
    required String name,
    required String setup,
    required String dir,
    required double entry,
    required double stop,
    required double target,
    required String lots,
    required double risk,
    required String rMultiple,
    required bool open,
  }) =>
      '''
## Instrument

`$symbol` — $name. Traded $dir off the $setup.

## Levels that mattered

| Level | Type | Note |
| --- | --- | --- |
| ${AppTokens.price(target)} | Target | First scale, 2R from entry |
| ${AppTokens.price(entry)} | Entry | Trigger printed and held |
| ${AppTokens.price(stop)} | Stop | Invalidation — below this the idea is wrong |

## Risk arithmetic

Risk per unit is \$|entry - stop|\$, so the size came off the stop distance and
nothing else:

\$\$ size = \\frac{R}{|entry - stop|} = \\frac{${AppTokens.money(risk, decimals: 0)}}{${AppTokens.price((entry - stop).abs())}} \\approx $lots \$\$

Total risked: **${AppTokens.money(risk, decimals: 0)}**. Returned $rMultiple on
it.

## Notes

${open ? 'Still holding. The stop has not moved and will not until the first target trades.' : 'Closed inside the session. Nothing about the size was a decision made in the moment — it was arithmetic done before the entry, which is the only reason the stop was survivable.'}
''';

  /// Shape 5 — the three-line log. Most entries in a real journal look like
  /// this, and a seed made only of essays would make the list look wrong.
  String _journalLog({
    required String symbol,
    required String setup,
    required String dir,
    required double entry,
    required String exited,
    required String result,
    required String emotion,
    required bool open,
  }) =>
      '''
- $setup on `$symbol`, $dir from ${AppTokens.price(entry)} → $exited ($result).
- $emotion.
- ${open ? 'Holding. Stop unchanged.' : 'Flat. Nothing to add.'}
''';

  // ---------------------------------------------------------------------------
  // Strategy playbooks
  // ---------------------------------------------------------------------------

  /// The full playbook body for strategy [i], matching `_setups[i]`.
  ///
  /// Written as documents rather than blurbs. A playbook a trader will not read
  /// under pressure is a playbook that does not exist — and every surface that
  /// renders one (the detail tab, the version list, the PDF export, the outline)
  /// needs real structure to be worth testing against. Each body carries at
  /// least six `##` sections so [_markdownSections] can peel revisions off the
  /// end and the version list shows genuine growth.
  String _strategyPlaybook(int i) => switch (i) {
    0 => _playbookOpeningRange,
    1 => _playbookGapFade,
    2 => _playbookTrendContinuation,
    3 => _playbookVwapReclaim,
    4 => _playbookFailedBreakdown,
    _ => _playbookEarningsDrift,
  };

  static const String _playbookOpeningRange = r'''
## Thesis

The first fifteen minutes of the session price in overnight information. Once
that range is set, a decisive break of it with the day's first real volume tends
to run, because the participants who were waiting for confirmation all get it at
the same moment.

The edge is not the break. The edge is refusing the break on days when the range
is meaningless.

## Universe and session

| Filter | Rule |
| --- | --- |
| Instruments | NIFTY50, BANKNIFTY futures only |
| Window | 09:30 – 11:00 IST |
| Range definition | 09:15 – 09:30 high and low |
| Gap filter | Pre-open gap must be under 0.4% |
| Volatility filter | India VIX between 11 and 22 |

## Entry

- Mark the 15-minute range before 09:31. If it was not marked in advance, the
  day is a no-trade day.
- Enter on a five-minute close beyond the range extreme plus 0.1%.
- One entry per side per session. A failed break does not get a second attempt.

## Invalidation

The idea is wrong the moment price closes back inside the range on the
five-minute chart. That is the exit, not the stop — the stop is the far side of
the range and exists only for gaps.

> If the first candle after the break closes back inside the range, the trade is
> void. Flat, then stand down until 11:00.

## Management

- Scale half at 1R, move the stop to entry on the balance.
- Trail the remainder under each completed five-minute swing.
- Flat by 11:00 regardless of open P&L. The premise expires with the window.

## Sizing

Risk 0.75% of equity per attempt, sized off the distance to the opposite side of
the range:

```dart
double lots({
  required double equity,
  required double rangeHigh,
  required double rangeLow,
  required double pointValue,
}) {
  final double stopPoints = (rangeHigh - rangeLow).abs();
  if (stopPoints == 0) return 0;
  return (equity * 0.0075) / (stopPoints * pointValue);
}
```

## Pre-flight checklist

- [ ] Range marked before 09:31
- [ ] Gap measured and under 0.4%
- [ ] VIX inside the band
- [ ] Size computed from range width, not conviction
- [ ] Alert set on both extremes

## Review cadence

Weekly. Bucket every attempt by gap size and by range width, and drop any bucket
that has produced a negative expectancy over thirty attempts.
''';

  static const String _playbookGapFade = r'''
## Thesis

A gap with no information behind it is an inventory problem, not a repricing.
Market makers who absorbed the imbalance at the open want out, and the path of
least resistance is back toward the prior close.

The whole strategy rests on one judgement: is there news, or is there not?

## News screen

```mermaid
flowchart TD
    A[Gap over 0.8%] --> B{Company or macro news?}
    B -->|Yes| Z[No trade. This is a repricing.]
    B -->|No| C{Gap inside 20-day ATR?}
    C -->|No| Z
    C -->|Yes| D{Volume in first 5m above average?}
    D -->|No| Z
    D -->|Yes| E[Fade toward prior close]
```

Anything that reaches E is a candidate. Everything else is a chart to watch, not
a trade to take.

## Universe and session

| Filter | Rule |
| --- | --- |
| Instruments | Liquid single stocks, top 100 by turnover |
| Window | 09:20 – 10:30 IST |
| Gap size | 0.8% to 2.5% |
| Excluded | Earnings day, board-meeting day, index rebalance |

## Entry

- Wait for the first five-minute candle to complete. Never fade the open tick.
- Enter against the gap when the second candle fails to extend the first by more
  than 0.15%.
- Limit orders only. If it does not fill on the retest, the trade never existed.

## Invalidation

A new session extreme after entry. That is the whole rule — no ATR multiples, no
time stops. If the gap is still extending, the premise was wrong.

## Management

- Target is the prior close, taken as a resting limit at entry time.
- Take 60% at the halfway mark to the close, hold the rest to the level.
- No trailing. Fades either work quickly or they do not work.

## Sizing

Half the standard unit. This setup has the highest hit rate in the book and the
worst tail — a gap that keeps going does not stop where the stop is.

| Gap size | Unit |
| --- | --- |
| 0.8 – 1.2% | 0.5R |
| 1.2 – 1.8% | 0.4R |
| 1.8 – 2.5% | 0.3R |

## Review cadence

Monthly, and separately for gap-up versus gap-down. The two behave differently
enough that pooling them hides which side is actually paying.
''';

  static const String _playbookTrendContinuation = r'''
## Thesis

Trends persist longer than they should because institutions cannot fill a
position in one session. The tradable consequence is that the first orderly
pullback inside an established daily trend is usually bought before it reaches
anything a retail chart would call support.

## Trend definition

A trend exists when all three hold on the daily:

- Price above the 20-EMA, and the 20-EMA above the 50-EMA.
- Two consecutive higher swing lows (inverted for shorts).
- The last leg travelled at least 1.5x the 20-day ATR.

If any one is missing there is no trend, and this playbook does not apply.

## Entry

- Wait for a pullback that holds the 20-EMA on a **closing** basis.
- Enter on the first daily close back above the prior day's high.
- Never enter inside the pullback. The entry is the resumption, not the dip.

| Field | Rule |
| --- | --- |
| Trigger | Close above prior day high |
| Stop | Below the pullback low |
| First target | Measured move of the previous leg |
| Time stop | 8 sessions with no new high |

## Invalidation

A daily close below the pullback low. Intraday violations are noise; this is a
swing playbook and the close is the only price that counts.

## Management

- Nothing at 1R. Scaling early is what turns a trend trade into a scalp.
- Trail under each new higher swing low once 2R is reached.
- Exit fully on the first daily close below the 20-EMA.

## Sizing

Full unit, 1% of equity, sized so a failed retest costs less than the previous
leg paid:

$$ risk = 0.01 \times equity, \qquad size = \frac{risk}{|entry - pullbackLow|} $$

If the resulting position is larger than 15% of average daily volume, take the
volume constraint instead and accept the smaller risk.

## Session and portfolio limits

- Maximum three concurrent positions from this playbook.
- No two in the same sector.
- Correlation check against open index positions before adding a fourth idea.

## Review cadence

Quarterly. Trend playbooks need a sample measured in seasons, and a monthly
review on a strategy that takes eight trades a quarter is noise dressed as
diligence.
''';

  static const String _playbookVwapReclaim = r'''
## Thesis

Session VWAP is where the average participant is flat. A morning push that fails
and then reclaims VWAP traps everyone who sold the failure, and their covering is
the fuel for the second attempt.

This is the highest-frequency setup in the book and the one most easily ruined by
taking it twice.

## Universe and session

| Filter | Rule |
| --- | --- |
| Instruments | Index futures and top-50 single stocks |
| Window | 10:00 – 14:30 IST |
| Minimum morning range | 0.6% |
| Required | At least one failed push before the reclaim |

## Entry

- Identify the failed push: a session high followed by a close below VWAP.
- Enter on the first five-minute close back above VWAP.
- Confirmation required: the reclaim candle's volume must exceed the failure
  candle's volume.

## Invalidation

A five-minute close back below VWAP after entry. One reclaim attempt per
session — the second is where this setup gives back everything the first made.

> The rule that matters is not the entry. It is that there is exactly one
> attempt. Everything about this playbook's expectancy comes from that.

## Management

- Stop below the reclaim candle's low.
- First scale at the session high, remainder trailed on the VWAP itself.
- Flat at 15:15. Never hold a VWAP trade into the close.

## Sizing

Standard unit, 1% of equity, off the reclaim candle's range:

```dart
double size({
  required double equity,
  required double reclaimHigh,
  required double reclaimLow,
}) {
  final double stopDistance = (reclaimHigh - reclaimLow).abs();
  if (stopDistance == 0) return 0;
  return (equity * 0.01) / stopDistance;
}
```

## Pre-flight checklist

- [ ] Failed push identified and timestamped
- [ ] VWAP reclaimed on a closing basis
- [ ] Reclaim volume exceeds failure volume
- [ ] This is the first attempt of the session
- [ ] Exit alarm set for 15:15

## Review cadence

Weekly, split by time of day. The 10:00 – 11:30 sample and the 13:00 – 14:30
sample have behaved differently every quarter this has been tracked.
''';

  static const String _playbookFailedBreakdown = r'''
## Thesis

Obvious support draws stops. When price breaks it and immediately reclaims, the
sellers who were filled below are trapped and the buyers who were stopped out
have to re-enter higher. Both flows point the same way.

Status note: this playbook is still in **draft**. The sample is under forty
trades and the sizing rules have not been stress-tested through a high-VIX
regime.

## What counts as obvious

| Signal | Requirement |
| --- | --- |
| Touches | Level tested at least twice in the last 10 sessions |
| Visibility | Round number, prior swing low, or prior day low |
| Break depth | 0.2% to 0.6% below the level |
| Reclaim speed | Back above within 3 five-minute candles |

A level nobody is watching produces no trapped participants, and this setup has
nothing to work with.

## Entry

- Enter on the close of the candle that reclaims the level.
- If the reclaim takes more than three candles, the flush was real. Stand down.

## Invalidation

A new low below the flush low. The trapped-seller premise dies there, and
holding past it is a bet on something this playbook has no view on.

## Management

- Stop below the flush low, never at the level itself.
- Scale half into the first push back to the pre-break range midpoint.
- Trail the remainder under the reclaim low.

## Sizing

Half unit while this remains a draft. The stop sits below a wick, which means the
real risk is wider than the measured risk more often than the model admits.

## Open questions

- [ ] Does the setup survive when the index is also breaking down?
- [ ] Is the three-candle reclaim window right, or is it curve-fitted?
- [ ] Should the flush depth filter be an ATR fraction rather than a percentage?

## Review cadence

Every twenty trades until the sample reaches one hundred, then monthly. Promote
to **testing** only once the open questions above have answers written into this
document.
''';

  static const String _playbookEarningsDrift = r'''
## Thesis

Post-earnings announcement drift is one of the few anomalies that has survived
publication. Prices underreact to genuine surprise, and the adjustment plays out
over days rather than in the reaction candle.

Status note: **retired**. The edge in this universe compressed to nothing once
the reaction candle started absorbing the whole move, and two consecutive
quarters of negative expectancy is enough. Kept for reference, not for trading.

## Signal

| Requirement | Rule |
| --- | --- |
| Reaction close | Top quartile of the reaction-day range |
| Gap | At least 3% in the direction of the surprise |
| Volume | Three times the 20-day average |
| Guidance | Raised, not merely reaffirmed |

## Entry

- Enter on the close of the session **after** the reaction day.
- Never on the reaction day itself. The spread and the slippage take the whole
  edge before the drift starts.

## Invalidation

A close below the reaction-day midpoint. That level is where the surprise stops
being priced as good news.

## Management

- Hold two to five sessions. No discretionary extensions.
- Exit on the fifth close regardless of P&L.
- No scaling. The drift is small and splitting it makes the commissions matter.

## Sizing

$$ size = \frac{0.005 \times equity}{|entry - reactionMidpoint|} $$

Half unit, because the position is held overnight through a period when the
company is still releasing information.

## Why it was retired

```chart
{
  "type": "bar",
  "title": "Expectancy by quarter (R per trade)",
  "labels": ["Q1", "Q2", "Q3", "Q4"],
  "series": [{"name": "Avg R", "data": [0.34, 0.21, -0.05, -0.18]}]
}
```

The decline is monotonic and the last two quarters are negative. There is no
version of this document that fixes that, so it is archived rather than revised.

## Review cadence

None. If the reaction-candle absorption reverses, re-open as a fresh draft rather
than reviving this one.
''';
}

@immutable
class _ReferralSeed {
  const _ReferralSeed(this.name, this.email, this.channel);

  final String name;
  final String email;
  final String channel;
}

@immutable
class _MemberSeed {
  const _MemberSeed(this.name, this.email, this.role);

  final String name;
  final String email;
  final AppTeamRole role;
}

@immutable
class _Instrument {
  const _Instrument(this.symbol, this.name, this.price, this.sector);

  final String symbol;
  final String name;
  final double price;
  final String sector;
}

@immutable
class _Person {
  const _Person(this.handle, this.name, this.bio);

  final String handle;
  final String name;
  final String bio;
}

@immutable
class _NotificationSeed {
  const _NotificationSeed(
    this.title,
    this.body,
    this.category,
    this.icon,
    this.read,
  );

  final String title;
  final String body;
  final String category;
  final IconData icon;
  final bool read;
}

/// The single table every seeded cross-link is read from.
///
/// Both ends of every edge are derived here, so the note that lists a journal
/// entry and the entry that lists the note back are two views of one fact. Built
/// from ids and link-free records only — never from a fully linked one — which is
/// what keeps `notes()`, `trades()` and `strategies()` out of a cycle while still
/// agreeing on every edge.
///
/// Backend hand-off: this class is the shape of the join tables. `noteToJournal`
/// is `note_journal_links`, `noteToStrategy` is the `strategy_id` column on
/// `trader_notes`, and the inverses are indexes, not stored rows.
class _LinkSeed {
  _LinkSeed({
    required List<String> noteIds,
    required List<AppTrade> journal,
    required List<String> strategyIds,
  }) {
    for (int i = 0; i < noteIds.length; i++) {
      final String noteId = noteIds[i];

      // Half the notes discuss trades, and the ones that do usually discuss
      // more than one — a weekly review pointing at a single entry is not what a
      // review looks like.
      if (journal.isNotEmpty && i.isEven) {
        _noteToJournal[noteId] = <String>{
          journal[(i * 3) % journal.length].id,
          journal[(i * 3 + 7) % journal.length].id,
          if (i % 4 == 0) journal[(i * 5 + 2) % journal.length].id,
        }.toList(growable: false);
      }

      // Two notes in three sit under a playbook. The third is the loose idea or
      // the cheat sheet that belongs to no single strategy — the case the
      // "unfiled" filter and the orphan prompt exist for.
      if (strategyIds.isNotEmpty && i % 3 != 2) {
        _noteToStrategy[noteId] = strategyIds[i % strategyIds.length];
      }
    }

    // Inverses, materialised rather than searched at read time so a lookup from
    // either end of an edge is one map hit.
    _noteToJournal.forEach((String noteId, List<String> entries) {
      for (final String entryId in entries) {
        (_journalToNotes[entryId] ??= <String>[]).add(noteId);
      }
    });
    _noteToStrategy.forEach((String noteId, String strategyId) {
      (_strategyToNotes[strategyId] ??= <String>[]).add(noteId);
    });
    for (final AppTrade t in journal) {
      final String? id = t.strategyId;
      if (id == null || id.isEmpty) continue;
      (_strategyToJournal[id] ??= <String>[]).add(t.id);
    }
  }

  final Map<String, List<String>> _noteToJournal = <String, List<String>>{};
  final Map<String, String> _noteToStrategy = <String, String>{};
  final Map<String, List<String>> _journalToNotes = <String, List<String>>{};
  final Map<String, List<String>> _strategyToNotes = <String, List<String>>{};
  final Map<String, List<String>> _strategyToJournal = <String, List<String>>{};

  List<String> journalForNote(String noteId) =>
      _noteToJournal[noteId] ?? const <String>[];

  String? strategyForNote(String noteId) => _noteToStrategy[noteId];

  List<String> notesForJournal(String entryId) =>
      _journalToNotes[entryId] ?? const <String>[];

  List<String> notesForStrategy(String strategyId) =>
      _strategyToNotes[strategyId] ?? const <String>[];

  List<String> journalForStrategy(String strategyId) =>
      _strategyToJournal[strategyId] ?? const <String>[];
}
