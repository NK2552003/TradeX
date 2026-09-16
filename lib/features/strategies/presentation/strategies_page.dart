import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/strategies/data/strategy_repository.dart';

class StrategiesPage extends StatefulWidget {
  const StrategiesPage({super.key, this.repository});

  final StrategyRepository? repository;

  @override
  State<StrategiesPage> createState() => _StrategiesPageState();
}

class _StrategiesPageState extends State<StrategiesPage> {
  late final StrategyRepository _repo;
  bool _loading = true;
  List<AppStrategy> _strategies = [];
  AppStrategy? _selectedStrategy;
  List<AppStrategyVersion> _versions = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? StrategyRepositoryImpl();
    _loadStrategies();
  }

  Future<void> _loadStrategies() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getStrategies();
      if (mounted) {
        setState(() {
          _strategies = list;
          if (list.isNotEmpty && _selectedStrategy == null) {
            _selectStrategy(list.first);
          } else {
            _loading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('StrategiesPage error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectStrategy(AppStrategy strategy) async {
    setState(() {
      _selectedStrategy = strategy;
    });

    final versions = await _repo.getVersionHistory(strategy.id);
    if (mounted) {
      setState(() {
        _versions = versions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.strategies();
    }

    return AppPageBlock(
      title: 'Quant Strategies',
      subtitle: 'Build, backtest, and refine systematic trading models',
      actions: [
        UiButton(
          label: 'New Strategy',
          leadingIcon: Icons.add,
          intent: UiIntent.primary,
          size: UiSize.sm,
          onPressed: () {
            UiToast.show(
              context,
              title: 'New Quant Strategy',
              message: 'Strategy builder wizard initialized.',
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
            AppStrategyLibraryBlock(
              strategies: _strategies,
              onOpen: (strategy) => _selectStrategy(strategy),
            ),
            if (_selectedStrategy != null && _versions.isNotEmpty) ...[
              UiGap.v(context.sp(theme.spacing.xl)),
              AppVersionHistoryBlock(
                versions: _versions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
