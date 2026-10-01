import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/watchlists/data/watchlist_repository.dart';

class WatchlistsPage extends StatefulWidget {
  const WatchlistsPage({super.key, this.repository});

  final WatchlistRepository? repository;

  @override
  State<WatchlistsPage> createState() => _WatchlistsPageState();
}

class _WatchlistsPageState extends State<WatchlistsPage> {
  late final WatchlistRepository _repo;
  bool _loading = true;
  List<AppTicker> _tickers = [];
  AppTicker? _selectedTicker;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? WatchlistRepositoryImpl();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getWatchlistTickers();
      if (mounted) {
        setState(() {
          _tickers = list;
          if (list.isNotEmpty && _selectedTicker == null) {
            _selectedTicker = list.first;
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('WatchlistsPage error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.watchlists();
    }

    return AppPageBlock(
      title: 'Market Watchlists',
      subtitle:
          'Real-time quotes, technical scanners, and price alert thresholds',
      actions: [
        UiButton(
          label: 'Add Symbol',
          leadingIcon: Icons.add,
          intent: UiIntent.primary,
          size: UiSize.sm,
          onPressed: () {
            UiToast.show(
              context,
              title: 'Add Symbol',
              message: 'Symbol search and watchlist picker opened.',
              intent: UiIntent.info,
            );
          },
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppWatchlistBlock(
              tickers: _tickers,
              onTickerTap: (ticker) {
                setState(() => _selectedTicker = ticker);
              },
            ),
            UiGap.v(context.sp(theme.spacing.xl)),
            AppHeatmapBlock(entries: _tickers),
          ],
        ),
      ),
    );
  }
}
