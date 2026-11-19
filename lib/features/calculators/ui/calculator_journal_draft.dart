import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
// ignore: unused_import, unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/journal/ui/journal_editor_screen.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';

/// Opens a reviewable trade entry pre-populated from a calculator and persists
/// it to the backend journal repository and calculator trade history on save.
Future<AppTrade?> openCalculatorJournalDraft(
  BuildContext context, {
  required String symbol,
  required double entry,
  double? stopLoss,
  double? exit,
  required double quantity,
  double? target,
  AppSide? side,
  String? calculatorId,
  String? calculatorName,
  String? notes,
}) async {
  int existingTradeCount = 0;
  try {
    final existing = await JournalRepositoryScope.repository.fetchAll();
    existingTradeCount = existing.length;
  } catch (_) {}
  if (!context.mounted) return null;
  final allowed = await CustomerLimitations.checkCanCreateTrade(
    context,
    currentTradeCount: existingTradeCount,
  );
  if (!allowed || !context.mounted) return null;

  final AppSide resolvedSide =
      side ??
      (stopLoss != null
          ? (entry >= stopLoss ? AppSide.long : AppSide.short)
          : (exit != null && exit < entry ? AppSide.short : AppSide.long));
  final double pnl = exit == null
      ? 0
      : (exit - entry) * quantity * (resolvedSide == AppSide.long ? 1 : -1);
  final double pnlPct = exit == null || entry == 0
      ? 0
      : ((exit - entry) / entry) *
            100 *
            (resolvedSide == AppSide.long ? 1 : -1);
  final String cleanSymbol = symbol.trim().toUpperCase();
  final String tagSource = calculatorId ?? 'calculator';

  final AppTrade draft = AppTrade(
    id: '',
    ticker: cleanSymbol,
    side: resolvedSide,
    entry: entry,
    exit: exit,
    openedAt: DateTime.now(),
    closedAt: exit != null ? DateTime.now() : null,
    stopLoss: stopLoss,
    target: target,
    size: quantity <= 0 ? 1 : quantity,
    pnl: pnl,
    pnlPercent: pnlPct,
    outcome: exit == null
        ? AppOutcome.open
        : (pnl > 0
              ? AppOutcome.win
              : (pnl < 0 ? AppOutcome.loss : AppOutcome.breakeven)),
    tags: <String>['calculator', if (tagSource != 'calculator') tagSource],
    title: '${calculatorName ?? 'Calculator'} · $cleanSymbol',
    notes: notes,
    content: notes ?? '',
  );

  final AppTrade? saved = await Navigator.of(context).push<AppTrade?>(
    MaterialPageRoute<AppTrade?>(
      builder: (routeContext) => Scaffold(
        body: JournalEditorScreen(
          detailsOnly: true,
          entry: draft,
          onClose: (AppTrade? result) => Navigator.of(routeContext).pop(result),
        ),
      ),
    ),
  );

  if (saved != null) {
    await CalculatorHistoryStore.instance.recordLoggedTrade(
      saved,
      calculatorId: calculatorId ?? 'calculator',
      calculatorName: calculatorName ?? 'Calculator',
    );
  }
  return saved;
}

/// Lightweight record of a calculator trade or calculation snapshot synced
/// with [JournalRepository] (`journal_entries` in Supabase) + local cache.
class CalculatorHistoryRecord {
  const CalculatorHistoryRecord({
    required this.id,
    required this.calculatorId,
    required this.calculatorName,
    required this.symbol,
    required this.side,
    required this.entry,
    required this.size,
    required this.createdAt,
    this.exit,
    this.stopLoss,
    this.target,
    this.pnl = 0,
    this.outcome = AppOutcome.open,
    this.journalEntryId,
    this.summary,
  });

  final String id;
  final String calculatorId;
  final String calculatorName;
  final String symbol;
  final AppSide side;
  final double entry;
  final double? exit;
  final double? stopLoss;
  final double? target;
  final double size;
  final double pnl;
  final AppOutcome outcome;
  final DateTime createdAt;
  final String? journalEntryId;
  final String? summary;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'calculator_id': calculatorId,
    'calculator_name': calculatorName,
    'symbol': symbol,
    'side': side.name,
    'entry': entry,
    'exit': exit,
    'stop_loss': stopLoss,
    'target': target,
    'size': size,
    'pnl': pnl,
    'outcome': outcome.name,
    'created_at': createdAt.toIso8601String(),
    'journal_entry_id': journalEntryId,
    'summary': summary,
  };

  factory CalculatorHistoryRecord.fromJson(Map<String, dynamic> json) {
    return CalculatorHistoryRecord(
      id: json['id']?.toString() ?? '',
      calculatorId: json['calculator_id']?.toString() ?? 'calculator',
      calculatorName: json['calculator_name']?.toString() ?? 'Calculator',
      symbol: (json['symbol']?.toString() ?? '').toUpperCase(),
      side: json['side'] == 'short' ? AppSide.short : AppSide.long,
      entry: (json['entry'] as num?)?.toDouble() ?? 0,
      exit: (json['exit'] as num?)?.toDouble(),
      stopLoss: (json['stop_loss'] as num?)?.toDouble(),
      target: (json['target'] as num?)?.toDouble(),
      size: (json['size'] as num?)?.toDouble() ?? 1,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0,
      outcome: switch (json['outcome']?.toString()) {
        'win' => AppOutcome.win,
        'loss' => AppOutcome.loss,
        'breakeven' => AppOutcome.breakeven,
        _ => AppOutcome.open,
      },
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      journalEntryId: json['journal_entry_id']?.toString(),
      summary: json['summary']?.toString(),
    );
  }

  factory CalculatorHistoryRecord.fromTrade(
    AppTrade trade, {
    String calculatorId = 'calculator',
    String calculatorName = 'Calculator',
  }) {
    final String resolvedCalcName = trade.title.contains('·')
        ? trade.title.split('·').first.trim()
        : calculatorName;
    return CalculatorHistoryRecord(
      id: trade.id,
      calculatorId: calculatorId,
      calculatorName: resolvedCalcName.isEmpty
          ? 'Calculator'
          : resolvedCalcName,
      symbol: trade.ticker,
      side: trade.side,
      entry: trade.entry,
      exit: trade.exit,
      stopLoss: trade.stopLoss,
      target: trade.target,
      size: trade.size,
      pnl: trade.pnl,
      outcome: trade.outcome,
      createdAt: trade.openedAt,
      journalEntryId: trade.id,
      summary: trade.notes,
    );
  }
}

/// Persistent store that merges backend `journal_entries` with local calculator
/// history so logged trades are always available across sessions.
class CalculatorHistoryStore extends ChangeNotifier {
  CalculatorHistoryStore._();
  static final CalculatorHistoryStore instance = CalculatorHistoryStore._();

  static const String _prefsKey = 'alphajournal_calculator_logged_trades_v1';
  final List<CalculatorHistoryRecord> _localRecords =
      <CalculatorHistoryRecord>[];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
      for (final item in raw) {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        _localRecords.add(CalculatorHistoryRecord.fromJson(decoded));
      }
    } catch (_) {}
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _localRecords
          .take(100)
          .map((r) => jsonEncode(r.toJson()))
          .toList();
      await prefs.setStringList(_prefsKey, encoded);
    } catch (_) {}
  }

  Future<void> recordLoggedTrade(
    AppTrade trade, {
    String calculatorId = 'calculator',
    String calculatorName = 'Calculator',
  }) async {
    await _ensureLoaded();
    final record = CalculatorHistoryRecord.fromTrade(
      trade,
      calculatorId: calculatorId,
      calculatorName: calculatorName,
    );
    _localRecords.removeWhere(
      (r) => r.id == record.id || r.journalEntryId == trade.id,
    );
    _localRecords.insert(0, record);
    await _persistLocal();
    notifyListeners();
  }

  /// Loads merged history from live `JournalRepository` (`journal_entries`
  /// table in Supabase) and local calculator log records.
  Future<List<CalculatorHistoryRecord>> fetchHistory() async {
    await _ensureLoaded();
    final List<AppTrade> journalTrades = await JournalRepositoryScope.repository
        .fetchAll();

    final Map<String, CalculatorHistoryRecord> merged =
        <String, CalculatorHistoryRecord>{};

    for (final r in _localRecords) {
      merged[r.journalEntryId ?? r.id] = r;
    }

    for (final t in journalTrades) {
      final bool isFromCalc =
          t.tags.contains('calculator') ||
          t.title.toLowerCase().contains('calculator') ||
          merged.containsKey(t.id);
      if (isFromCalc || journalTrades.length <= 50) {
        final existing = merged[t.id];
        merged[t.id] = CalculatorHistoryRecord.fromTrade(
          t,
          calculatorId: existing?.calculatorId ?? 'calculator',
          calculatorName:
              existing?.calculatorName ??
              (t.title.contains('·')
                  ? t.title.split('·').first.trim()
                  : 'Trade Journal'),
        );
      }
    }

    final List<CalculatorHistoryRecord> sorted = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<void> deleteRecord(CalculatorHistoryRecord record) async {
    await _ensureLoaded();
    _localRecords.removeWhere(
      (r) => r.id == record.id || r.journalEntryId == record.journalEntryId,
    );
    await _persistLocal();
    final String? jId = record.journalEntryId;
    if (jId != null && jId.isNotEmpty) {
      try {
        await JournalRepositoryScope.repository.delete(jId);
      } catch (_) {}
    }
    notifyListeners();
  }
}

/// Opens the Calculator Trade & Execution History side sheet linked directly
/// with the backend `journal_entries` repository.
Future<void> showCalculatorHistorySheet(BuildContext context) {
  return showSettingsSideSheet<void>(
    context,
    title: 'Logged Trades & History',
    subtitle: 'Synced with Trade Journal backend',
    desktopWidthRatio: 0.36,
    minDesktopWidth: 400,
    maxWidth: 520,
    child: const _CalculatorHistorySheetContent(),
  );
}

class _CalculatorHistorySheetContent extends StatefulWidget {
  const _CalculatorHistorySheetContent();

  @override
  State<_CalculatorHistorySheetContent> createState() =>
      _CalculatorHistorySheetContentState();
}

class _CalculatorHistorySheetContentState
    extends State<_CalculatorHistorySheetContent> {
  List<CalculatorHistoryRecord> _records = const <CalculatorHistoryRecord>[];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    CalculatorHistoryStore.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    CalculatorHistoryStore.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final items = await CalculatorHistoryStore.instance.fetchHistory();
    if (!mounted) return;
    setState(() {
      _records = items;
      _loading = false;
    });
  }

  Future<void> _openInEditor(CalculatorHistoryRecord record) async {
    final String? id = record.journalEntryId;
    AppTrade? trade;
    if (id != null && id.isNotEmpty) {
      trade = await JournalRepositoryScope.repository.getById(id);
    }
    final AppTrade resolvedTrade =
        trade ??
        AppTrade(
          id: record.journalEntryId ?? '',
          ticker: record.symbol,
          side: record.side,
          entry: record.entry,
          exit: record.exit,
          stopLoss: record.stopLoss,
          target: record.target,
          size: record.size,
          pnl: record.pnl,
          outcome: record.outcome,
          openedAt: record.createdAt,
          title: '${record.calculatorName} · ${record.symbol}',
          notes: record.summary,
        );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          body: JournalEditorScreen(
            detailsOnly: true,
            entry: resolvedTrade,
            onClose: (_) => Navigator.of(routeContext).pop(),
          ),
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final q = _search.trim().toLowerCase();
    final filtered = _records.where((r) {
      if (q.isEmpty) return true;
      return r.symbol.toLowerCase().contains(q) ||
          r.calculatorName.toLowerCase().contains(q) ||
          (r.summary?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
          child: Row(
            children: <Widget>[
              Expanded(
                child: UiInput.search(
                  value: _search,
                  hintText: 'Filter by symbol or calculator…',
                  onChanged: (v) => setState(() => _search = v),
                  onClear: () => setState(() => _search = ''),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiIconButton(
                icon: Icons.refresh_rounded,
                size: UiSize.sm,
                tooltip: 'Sync with backend',
                onPressed: _reload,
              ),
            ],
          ),
        ),
        SizedBox(
          height: theme.borders.hairline,
          child: ColoredBox(color: colors.border),
        ),
        Expanded(
          child: _loading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                    child: const UiSkeleton(width: 240, height: 80),
                  ),
                )
              : filtered.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                  child: UiEmptyState(
                    icon: Icons.history_rounded,
                    title: 'No logged calculator trades yet',
                    message:
                        'Use "Log Trade" inside any trading calculator (Position Size, Risk/Reward, P&L, Options P&L, Brokerage, or Margin) to save trades directly to your Journal.',
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: context.sp(theme.spacing.xs)),
                  itemBuilder: (ctx, index) {
                    final item = filtered[index];
                    final isLong = item.side == AppSide.long;
                    return UiCard(
                      variant: UiCardVariant.surface,
                      onTap: () => _openInEditor(item),
                      child: Padding(
                        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                UiBadge(
                                  label: item.symbol,
                                  intent: UiIntent.primary,
                                  variant: UiBadgeVariant.soft,
                                  size: UiSize.xs,
                                ),
                                SizedBox(width: context.sp(theme.spacing.xs)),
                                UiBadge(
                                  label: isLong ? 'LONG' : 'SHORT',
                                  intent: isLong
                                      ? UiIntent.bullish
                                      : UiIntent.bearish,
                                  variant: UiBadgeVariant.outline,
                                  size: UiSize.xs,
                                ),
                                SizedBox(width: context.sp(theme.spacing.xs)),
                                Expanded(
                                  child: Text(
                                    item.calculatorName,
                                    style: context.uiText.caption.copyWith(
                                      color: colors.foregroundMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                UiIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  size: UiSize.xs,
                                  variant: UiVariant.ghost,
                                  tooltip: 'Delete trade log',
                                  onPressed: () async {
                                    await CalculatorHistoryStore.instance
                                        .deleteRecord(item);
                                    if (context.mounted) {
                                      UiToast.success(
                                        context,
                                        title: 'Removed from trade history',
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: context.sp(theme.spacing.xs)),
                            Wrap(
                              spacing: context.sp(theme.spacing.md),
                              runSpacing: context.sp(theme.spacing.xxs),
                              children: <Widget>[
                                Text(
                                  'Entry: ₹${AppTokens.price(item.entry)}',
                                  style: context.uiText.bodyStrong,
                                ),
                                Text(
                                  'Qty: ${AppTokens.count(item.size)}',
                                  style: context.uiText.caption,
                                ),
                                if (item.stopLoss != null)
                                  Text(
                                    'SL: ₹${AppTokens.price(item.stopLoss!)}',
                                    style: context.uiText.caption.copyWith(
                                      color: colors.danger,
                                    ),
                                  ),
                                if (item.target != null)
                                  Text(
                                    'Target: ₹${AppTokens.price(item.target!)}',
                                    style: context.uiText.caption.copyWith(
                                      color: colors.success,
                                    ),
                                  ),
                                if (item.exit != null)
                                  Text(
                                    'Exit: ₹${AppTokens.price(item.exit!)} (${AppTokens.signedMoney(item.pnl, decimals: 0)})',
                                    style: context.uiText.caption.copyWith(
                                      color: item.pnl >= 0
                                          ? colors.success
                                          : colors.danger,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
