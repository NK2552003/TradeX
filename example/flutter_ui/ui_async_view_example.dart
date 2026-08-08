import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Professional Level Async View Showcase featuring interactive state toggles,
/// live simulated data fetching, error retry handling, and empty states.
class UiAsyncViewExampleView extends StatefulWidget {
  const UiAsyncViewExampleView({super.key});

  @override
  State<UiAsyncViewExampleView> createState() => _UiAsyncViewExampleViewState();
}

class _UiAsyncViewExampleViewState extends State<UiAsyncViewExampleView> {
  bool _isLoading = false;
  String? _error;
  bool _isEmpty = false;

  void _triggerFetchSuccess() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isEmpty = false;
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _triggerFetchError() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isEmpty = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = '503 Service Unavailable: Exchange WebSocket Connection Dropped';
      });
    }
  }

  void _triggerFetchEmpty() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isEmpty = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isEmpty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiAsyncView Showcase & Controller', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Unified state controller handling the 4 primary UI async states: Loading -> Error -> Empty -> Content.',
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundMuted),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // 1. Interactive State Switcher Card
          UiAsyncViewStateCard(
            title: '1. Live Market Orderbook Controller',
            subtitle: 'Toggle states or click Simulate Load to see smooth cross-fade transitions',
            contentBuilder: (ctx) => Column(
              children: <Widget>[
                _buildOrderRow(ctx, 'BTC/USD', 'Buy Limit @ \$64,250.00', '1.5 BTC', 'Executing', UiIntent.bullish),
                const SizedBox(height: 8),
                _buildOrderRow(ctx, 'ETH/USD', 'Sell Limit @ \$3,450.00', '10 ETH', 'Pending', UiIntent.warning),
                const SizedBox(height: 8),
                _buildOrderRow(ctx, 'SOL/USD', 'Stop Market @ \$142.00', '50 SOL', 'Filled', UiIntent.primary),
              ],
            ),
          ),

          SizedBox(height: context.sp(theme.spacing.xl)),

          // 2. Interactive Action Trigger Controls
          UiCard(
            title: '2. Simulate Real API Data Fetching',
            subtitle: 'Trigger mock async network calls and observe state transitions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: context.sp(theme.spacing.sm),
                  runSpacing: context.sp(theme.spacing.sm),
                  children: <Widget>[
                    UiButton(
                      label: 'Fetch Data (Success)',
                      leadingIcon: Icons.check_circle_outline,
                      variant: UiVariant.primary,
                      onPressed: _isLoading ? null : _triggerFetchSuccess,
                    ),
                    UiButton(
                      label: 'Fetch Data (Error)',
                      leadingIcon: Icons.error_outline,
                      variant: UiVariant.destructive,
                      onPressed: _isLoading ? null : _triggerFetchError,
                    ),
                    UiButton(
                      label: 'Fetch Data (Empty)',
                      leadingIcon: Icons.inbox_outlined,
                      variant: UiVariant.outline,
                      onPressed: _isLoading ? null : _triggerFetchEmpty,
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                UiAsyncView(
                  loading: _isLoading,
                  loadingMessage: 'Connecting to TradeX Matching Engine...',
                  error: _error,
                  errorTitle: 'Exchange API Error',
                  onRetry: _triggerFetchSuccess,
                  isEmpty: _isEmpty,
                  emptyTitle: 'No Watchlists Found',
                  emptyMessage: 'You have not created any market watchlists yet.',
                  emptyIcon: Icons.auto_graph_outlined,
                  emptyAction: UiButton(
                    label: 'Create Watchlist',
                    leadingIcon: Icons.add,
                    expandOnMobile: false,
                    onPressed: _triggerFetchSuccess,
                  ),
                  builder: (ctx) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colors.surfaceMuted,
                      borderRadius: context.radius(theme.radii.lg),
                      border: Border.all(
                        color: theme.colors.border,
                        width: theme.borders.hairline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('Live Portfolio Asset Stream', style: context.uiText.heading.copyWith(fontSize: 16)),
                            const UiBadge(label: 'Connected', intent: UiIntent.bullish),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Value: \$128,450.20 • 24h PnL: +\$4,210.00 (+3.39%)',
                          style: context.uiText.body.copyWith(color: theme.colors.foregroundMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(
    BuildContext ctx,
    String pair,
    String detail,
    String amount,
    String status,
    UiIntent intent,
  ) {
    final theme = ctx.ui;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted,
        borderRadius: ctx.radius(theme.radii.md),
        border: Border.all(
          color: theme.colors.border,
          width: theme.borders.hairline,
        ),
      ),
      child: Row(
        children: <Widget>[
          UiAvatar(name: pair, size: UiSize.sm),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(pair, style: ctx.uiText.heading.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(detail, style: ctx.uiText.caption.copyWith(color: theme.colors.foregroundMuted)),
              ],
            ),
          ),
          Text(amount, style: ctx.uiText.numeric.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          UiBadge(label: status, intent: intent),
        ],
      ),
    );
  }
}
