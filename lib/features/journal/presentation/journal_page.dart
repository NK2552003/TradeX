import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, this.repository});

  final JournalRepository? repository;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late final JournalRepository _repo;
  bool _loading = true;
  List<AppTrade> _trades = [];
  String _query = '';
  AppOutcome? _outcomeFilter;
  AppTrade? _selectedTrade;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? JournalRepositoryImpl();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getEntries(
        query: _query.isNotEmpty ? _query : null,
        outcome: _outcomeFilter,
      );
      if (mounted) {
        setState(() {
          _trades = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('JournalPage error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQueryChanged(String value) {
    _query = value;
    _loadEntries();
  }

  void _onOutcomeChanged(AppOutcome? outcome) {
    _outcomeFilter = outcome;
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.journal();
    }

    return AppPageBlock(
      title: 'Trade Journal',
      subtitle: 'Log, analyze, and optimize your trading executions',
      actions: [
        UiButton(
          label: 'New Entry',
          leadingIcon: Icons.add,
          intent: UiIntent.primary,
          size: UiSize.sm,
          onPressed: () {
            UiToast.show(
              context,
              title: 'Journal Entry',
              message: 'Journal entry modal opened.',
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
            AppJournalFilterBlock(
              query: _query,
              outcome: _outcomeFilter,
              onQueryChanged: _onQueryChanged,
              onOutcomeChanged: _onOutcomeChanged,
            ),
            UiGap.v(context.sp(theme.spacing.lg)),
            if (_trades.isEmpty)
              UiEmptyState(
                icon: Icons.auto_stories_outlined,
                title: 'No Journal Entries Found',
                message: 'Start by logging your first trade setup or clearing your active filters.',
                action: UiButton(
                  label: 'Refresh',
                  leadingIcon: Icons.refresh,
                  onPressed: _loadEntries,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTradeListBlock(
                      trades: _trades,
                      onTradeTap: (trade) {
                        setState(() => _selectedTrade = trade);
                      },
                    ),
                  ),
                  if (_selectedTrade != null && !context.uiRes.isMobile) ...[
                    UiGap.h(context.sp(theme.spacing.lg)),
                    Expanded(
                      flex: 2,
                      child: AppTradeDetailBlock(
                        trade: _selectedTrade!,
                        onDelete: () => setState(() => _selectedTrade = null),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
