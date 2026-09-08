import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import '../data/repositories/strategy_repository.dart';
import '../models/strategy_model.dart';
import 'widgets/strategy_card.dart';
import 'widgets/strategy_guide_overlay.dart';

/// Main landing page for Linked Strategies feature.
/// Where users define their playbooks and rules first.
class StrategiesRootPage extends StatefulWidget {
  const StrategiesRootPage({
    super.key,
    this.onCreateStrategy,
    this.onStrategyTap,
  });

  final VoidCallback? onCreateStrategy;
  final ValueChanged<Strategy>? onStrategyTap;

  @override
  State<StrategiesRootPage> createState() => _StrategiesRootPageState();
}

class _StrategiesRootPageState extends State<StrategiesRootPage> {
  final StrategyRepository _repository = StrategyRepositoryImpl.instance;
  List<Strategy> _strategies = [];
  bool _loading = true;
  String _filterCategory = 'All';
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadStrategies();
  }

  Future<void> _loadStrategies() async {
    setState(() => _loading = true);
    try {
      List<Strategy> strategies;
      if (_showFavoritesOnly) {
        strategies = await _repository.getFavoriteStrategies();
      } else {
        strategies = await _repository.getAllStrategies();
      }
      
      if (_filterCategory != 'All') {
        strategies = strategies.where((s) => s.category == _filterCategory).toList();
      }
      
      setState(() {
        _strategies = strategies;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Set<String> get _categories {
    final cats = _strategies.map((s) => s.category).whereType<String>().toSet();
    return {'All', ...cats};
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isDesktop = context.uiRes.isDesktop;

    return AppPageBlock(
      title: 'Linked Strategies',
      subtitle: 'Define your playbooks and rules first',
      actions: [
        UiIconButton(
          icon: _showFavoritesOnly ? Icons.star : Icons.star_border,
          tooltip: _showFavoritesOnly ? 'Show all' : 'Show favorites',
          onPressed: () {
            setState(() => _showFavoritesOnly = !_showFavoritesOnly);
            _loadStrategies();
          },
        ),
        SizedBox(width: context.sp(theme.spacing.sm)),
        UiButton(
          label: 'New Strategy',
          leadingIcon: Icons.add,
          variant: UiVariant.filled,
          expandOnMobile: false,
          onPressed: widget.onCreateStrategy,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter bar
          _buildFilterBar(context),
          SizedBox(height: context.sp(theme.spacing.lg)),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _strategies.isEmpty
                    ? StrategiesEmptyState(
                        onCreateStrategy: widget.onCreateStrategy,
                      )
                    : StrategyGrid(
                        strategies: _strategies,
                        onStrategyTap: widget.onStrategyTap,
                        compact: !isDesktop,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final UiTheme theme = context.ui;
    final categories = _categories.toList();

    if (context.uiRes.isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final isSelected = cat == _filterCategory;
            return Padding(
              padding: EdgeInsets.only(right: context.sp(theme.spacing.sm)),
              child: UiChip(
                label: cat,
                selected: isSelected,
                onTap: () {
                  setState(() => _filterCategory = cat);
                  _loadStrategies();
                },
              ),
            );
          }).toList(),
        ),
      );
    }

    return Row(
      children: [
        Text(
          'Filter by category:',
          style: context.uiText.label.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.md)),
        ...categories.map((cat) {
          final isSelected = cat == _filterCategory;
          return Padding(
            padding: EdgeInsets.only(right: context.sp(theme.spacing.sm)),
            child: UiChip(
              label: cat,
              selected: isSelected,
              onTap: () {
                setState(() => _filterCategory = cat);
                _loadStrategies();
              },
            ),
          );
        }),
      ],
    );
  }
}
