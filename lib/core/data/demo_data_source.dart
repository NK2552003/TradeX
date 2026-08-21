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

  /// Closed and open positions backing the journal, portfolio and dashboard.
  List<AppTrade> trades({int count = 42}) {
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
      result.add(
        AppTrade(
          id: 'trd_${instrument.symbol.toLowerCase()}_$i',
          ticker: instrument.symbol,
          side: side,
          entry: entry,
          exit: open ? null : exit,
          openedAt: openedAt,
          closedAt: open ? null : openedAt.add(Duration(hours: 1 + i % 6)),
          stopLoss: _round(
            side == AppSide.long ? entry * 0.988 : entry * 1.012,
          ),
          target: _round(side == AppSide.long ? entry * 1.026 : entry * 0.974),
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
          strategy: _setups[rng.nextInt(_setups.length)],
          tags: <String>[
            _setups[rng.nextInt(_setups.length)],
            _emotions[rng.nextInt(_emotions.length)],
            instrument.sector,
          ],
          notes:
              'Executed the ${_setups[rng.nextInt(_setups.length)].toLowerCase()} '
              'plan on ${instrument.symbol}. Managed the position against the '
              'stop without widening it.',
          psychologyScore: 2 + rng.nextInt(4),
        ),
      );
    }
    return result;
  }

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

  /// Strategy notes library entries with rolled-up performance.
  List<AppStrategy> strategies() {
    final Random rng = _rng(51);
    return <AppStrategy>[
      for (int i = 0; i < _setups.length; i++)
        AppStrategy(
          id: 'stg_${i + 1}',
          name: _setups[i],
          summary:
              'Rules-based ${_setups[i].toLowerCase()} playbook with defined '
              'invalidation, scaling plan and session filter.',
          category: i.isEven ? 'bullish' : 'bearish',
          isPublic: i % 3 != 0,
          isFavorite: i < 2,
          trades: 24 + rng.nextInt(140),
          winRate: _round(38 + rng.nextDouble() * 34, 1),
          avgR: _round(-0.4 + rng.nextDouble() * 2.6),
          netPnl: _round((rng.nextDouble() - 0.3) * 24000),
          updatedAt: _now.subtract(Duration(days: i * 3 + 1)),
          versionCount: 2 + rng.nextInt(6),
          equityCurve: _spark(60 + i, points: 18, drift: i.isEven ? 0.8 : -0.4),
        ),
    ];
  }

  /// Saved revisions for a single strategy note.
  List<AppStrategyVersion> strategyVersions(String strategyId) {
    final Random rng = _rng(strategyId.hashCode.abs() % 9999);
    final int count = 4 + rng.nextInt(3);
    return List<AppStrategyVersion>.generate(count, (int i) {
      final int version = count - i;
      return AppStrategyVersion(
        id: '${strategyId}_v$version',
        version: version,
        savedAt: _now.subtract(Duration(days: i * 6 + 1)),
        author: _people[i % _people.length].name,
        note: i == 0
            ? 'Tightened the stop to the prior swing and added a session filter.'
            : 'Adjusted position sizing rules and documented invalidation.',
        isCurrent: i == 0,
      );
    });
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
