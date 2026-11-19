import 'package:flutter/material.dart';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/presentation/market_instrument_view.dart';
import 'watchlist_symbol_dialog.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/watchlists/data/watchlist_repository.dart';

class WatchlistsPage extends StatefulWidget {
  const WatchlistsPage({
    super.key,
    this.repository,
    this.marketRepository,
    this.onTickerTap,
  });

  final WatchlistRepository? repository;
  final AssetMarketRepository? marketRepository;
  final ValueChanged<AppTicker>? onTickerTap;

  @override
  State<WatchlistsPage> createState() => _WatchlistsPageState();
}

class _WatchlistsPageState extends State<WatchlistsPage> {
  late final WatchlistRepository _repo;
  bool _loading = true;
  List<AppTicker> _tickers = [];
  List<String> _watchlists = [];
  String? _error;
  AssetMarketRepository get _market =>
      widget.marketRepository ?? AssetMarketRepository.shared;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? WatchlistRepositoryImpl();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getWatchlistTickers();
      final watchlists = await _repo.getWatchlists();
      if (mounted) {
        setState(() {
          _tickers = list;
          _watchlists = watchlists;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('WatchlistsPage error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your watchlist. Please retry.';
        });
      }
    }
  }

  Future<void> _addSymbol() async {
    final bool? added = await UiDialog.show<bool>(
      context,
      child: WatchlistSymbolDialog(
        repository: _repo,
        marketRepository: _market,
      ),
    );
    if (added == true && mounted) await _loadWatchlist();
  }

  final Set<String> _removing = {};

  Future<void> _removeTicker(AppTicker ticker) async {
    if (_removing.contains(ticker.symbol)) return;
    final accepted = await UiDialog.confirm(
      context,
      title: 'Remove ${ticker.symbol}?',
      description:
          'Remove this symbol from all your watchlists. You can add it again at any time.',
      confirmLabel: 'Remove',
    );
    if (!accepted || !mounted) return;
    _removing.add(ticker.symbol);
    try {
      final lists = await _repo.getWatchlists();
      for (final name in lists) {
        await _repo.removeTickerFromWatchlist(name, ticker.symbol);
      }
    } catch (_) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Could not remove from every watchlist',
          message:
              'The list will refresh. Retry to remove any remaining entries.',
        );
      }
    } finally {
      _removing.remove(ticker.symbol);
      if (mounted) await _loadWatchlist();
    }
  }

  Future<void> _openTicker(AppTicker ticker) async {
    if (widget.onTickerTap != null) {
      widget.onTickerTap!(ticker);
      return;
    }
    try {
      final market = await _market.snapshot();
      final instrument = market.instruments
          .where((q) => q.symbol == ticker.symbol)
          .firstOrNull;
      if (!mounted) return;
      if (instrument == null) {
        throw StateError(
          'Instrument details are unavailable for ${ticker.symbol}.',
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            appBar: AppBar(title: Text(ticker.symbol)),
            body: MarketInstrumentView(
              instrument: instrument,
              repository: _market,
              snapshot: market,
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        UiToast.show(
          context,
          title: 'Instrument unavailable',
          message: 'Could not open ${ticker.symbol}. Please retry.',
          intent: UiIntent.warning,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.watchlists();
    }

    final quota = CustomerLimitations.currentQuota;
    return AppPageBlock(
      title: 'Market Watchlists',
      subtitle: 'Saved symbols and available market snapshots',
      actions: [
        UiBadge(
          label:
              'Lists ${_watchlists.length}/${quota.maxWatchlists} · Alerts max ${quota.maxAlerts}',
          intent: UiIntent.neutral,
          variant: UiBadgeVariant.soft,
          size: UiSize.xs,
        ),
        UiButton(
          label: 'Add Symbol',
          leadingIcon: Icons.add,
          intent: UiIntent.primary,
          size: UiSize.sm,
          onPressed: _addSymbol,
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              UiEmptyState(
                title: 'Watchlist unavailable',
                message: _error,
                action: UiButton(label: 'Retry', onPressed: _loadWatchlist),
              )
            else
              AppWatchlistBlock(
                tickers: _tickers,
                onTickerTap: _openTicker,
                onRemove: _removeTicker,
                onAdd: _addSymbol,
              ),
            UiGap.v(context.sp(theme.spacing.xl)),
            AppHeatmapBlock(
              entries: _tickers.where((t) => t.price.isFinite).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
