import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import '../data/watchlist_repository.dart';

class WatchlistSymbolDialog extends StatefulWidget {
  const WatchlistSymbolDialog({
    super.key,
    required this.repository,
    required this.marketRepository,
  });
  final WatchlistRepository repository;
  final AssetMarketRepository marketRepository;
  @override
  State<WatchlistSymbolDialog> createState() => _WatchlistSymbolDialogState();
}

class _WatchlistSymbolDialogState extends State<WatchlistSymbolDialog> {
  late final Future<(List<String>, MarketSnapshot)> _data = _load();
  String _query = '';
  String? _watchlist;
  MarketInstrument? _selected;
  String? _error;
  bool _saving = false;
  bool _createList = false;

  Future<(List<String>, MarketSnapshot)> _load() async {
    final lists = await widget.repository.getWatchlists();
    final market = await widget.marketRepository.snapshot();
    _createList = lists.isEmpty;
    _watchlist = lists.firstOrNull ?? 'Default Watchlist';
    return (lists, market);
  }

  Future<void> _save() async {
    if (_saving || _selected == null || _watchlist == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_createList) await widget.repository.createWatchlist(_watchlist!);
      await widget.repository.addTickerToWatchlist(
        _watchlist!,
        _selected!.symbol,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this symbol. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => UiDialog(
    title: 'Add Symbol',
    description: 'Find a symbol in the available market catalogue.',
    content: FutureBuilder<(List<String>, MarketSnapshot)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const UiCallout(
            title: 'Catalogue unavailable',
            message: 'Close this picker and retry.',
            intent: UiIntent.warning,
          );
        }
        if (!snapshot.hasData) return const UiSkeleton(height: 160);
        final (lists, market) = snapshot.data!;
        final query = _query.trim().toLowerCase();
        final results = market.instruments
            .where(
              (q) =>
                  query.isEmpty ||
                  q.symbol.toLowerCase().contains(query) ||
                  q.name.toLowerCase().contains(query),
            )
            .take(20)
            .toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lists.isEmpty)
              UiInput(
                label: 'Watchlist',
                value: _watchlist,
                hintText: 'Name your first watchlist',
                onChanged: (value) => setState(
                  () => _watchlist = value.trim().isEmpty ? null : value.trim(),
                ),
              )
            else
              UiSelect<String>(
                label: 'Watchlist',
                value: _watchlist,
                options: [
                  for (final list in lists) UiOption(value: list, label: list),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _watchlist = value),
              ),
            const UiGap.v(12),
            UiInput.search(
              value: _query,
              hintText: 'Search symbol or company',
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _query = value),
            ),
            const UiGap.v(12),
            SizedBox(
              height: context.sz(200),
              child: results.isEmpty
                  ? const UiEmptyState(title: 'No matching symbols')
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return UiButton(
                          label: '${item.symbol} · ${item.name}',
                          variant: _selected?.symbol == item.symbol
                              ? UiVariant.soft
                              : UiVariant.ghost,
                          expand: true,
                          onPressed: _saving
                              ? null
                              : () => setState(() => _selected = item),
                        );
                      },
                    ),
            ),
            if (_error != null)
              UiCallout(
                title: 'Save failed',
                message: _error!,
                intent: UiIntent.danger,
              ),
          ],
        );
      },
    ),
    actions: [
      UiButton(
        label: 'Cancel',
        variant: UiVariant.ghost,
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      UiButton(
        label: 'Add to watchlist',
        loading: _saving,
        onPressed: _selected == null || _watchlist == null || _saving
            ? null
            : _save,
      ),
    ],
  );
}
