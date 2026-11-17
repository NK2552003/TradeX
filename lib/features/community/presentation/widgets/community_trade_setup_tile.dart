import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Reusable snippet widget rendering structured trade setup details and candlestick chart.
class CommunityTradeSetupTile extends StatelessWidget {
  const CommunityTradeSetupTile({
    super.key,
    required this.setup,
    this.onTap,
    this.onCloneSetup,
    this.onLogToJournal,
  });

  final CommunityTradeSetup setup;
  final VoidCallback? onTap;
  final VoidCallback? onCloneSetup;
  final VoidCallback? onLogToJournal;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;

    return CommunityTile(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(setup.ticker, style: context.uiText.bodyStrong),
              UiBadge(
                label: setup.side,
                intent: setup.isBullish ? UiIntent.success : UiIntent.danger,
                size: UiSize.xs,
              ),
              if (setup.pnl != null)
                Text(setup.pnl!, style: context.uiText.numeric),
              if (setup.rMultiple != null || _computeRiskReward() != null)
                UiBadge(
                  label: setup.rMultiple ?? _computeRiskReward()!,
                  intent: (setup.isWin ?? true)
                      ? UiIntent.success
                      : UiIntent.danger,
                  size: UiSize.xs,
                ),
            ],
          ),
          UiGap.v(theme.spacing.xs),

          // Keep the execution levels readable in the narrow desktop sidebar.
          LayoutBuilder(
            builder: (context, box) {
              final metrics = <String, String>{
                'Entry': setup.entry,
                if (setup.exit != null) 'Exit': setup.exit!,
                if (setup.stopLoss != null) 'Stop Loss': setup.stopLoss!,
                if (setup.target != null) 'Target': setup.target!,
              };
              final columns = box.maxWidth >= 600 ? metrics.length : 2;
              final gap = context.sp(theme.spacing.xs);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final metric in metrics.entries)
                    SizedBox(
                      width: (box.maxWidth - gap * (columns - 1)) / columns,
                      child: _metricBox(context, metric.key, metric.value),
                    ),
                ],
              );
            },
          ),

          if (setup.candlesFromImage && setup.candles.isNotEmpty)
            const UiBadge(
              label: 'Image-derived · approximate',
              intent: UiIntent.warning,
              size: UiSize.xs,
            ),

          // Embedded Candlestick Chart
          if (setup.candles.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            UiCard(
              padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
              child: UiCandleChart(
                candles: setup.candles,
                height: isMobile ? 110 : 140,
                showVolume: false,
                showGrid: false,
                interactive: false,
              ),
            ),
          ],

          SizedBox(height: context.sp(theme.spacing.xs)),

          // Execution Bridge & Journal Action Row
          Wrap(
            alignment: WrapAlignment.end,
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              UiButton(
                label: 'Copy Setup to Journal',
                leadingIcon: Icons.bookmark_add_outlined,
                variant: UiVariant.ghost,
                size: UiSize.xs,
                onPressed:
                    onLogToJournal ??
                    () {
                      UiToast.show(
                        context,
                        title: 'Copied to Journal',
                        message:
                            'Trade setup for ${setup.ticker} saved to your Trading Journal',
                        intent: UiIntent.success,
                      );
                    },
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiButton(
                label: 'Clone Setup',
                leadingIcon: Icons.copy_rounded,
                variant: UiVariant.outline,
                size: UiSize.xs,
                onPressed:
                    onCloneSetup ??
                    () {
                      UiToast.show(
                        context,
                        title: 'Setup Cloned',
                        message:
                            'Loaded ${setup.ticker} setup into Order Ticket (Paper Desk)',
                        intent: UiIntent.primary,
                      );
                    },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBox(BuildContext context, String label, String value) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundSubtle,
            fontSize: context.fs(10),
          ),
        ),
        Text(
          value,
          style: context.uiText.caption.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: context.fs(12),
            color: theme.colors.foreground,
          ),
        ),
      ],
    );
  }

  String? _computeRiskReward() {
    if (setup.rMultiple != null) return setup.rMultiple;
    final entry = double.tryParse(
      setup.entry.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    final sl = setup.stopLoss != null
        ? double.tryParse(setup.stopLoss!.replaceAll(RegExp(r'[^0-9.]'), ''))
        : null;
    final target = setup.target != null
        ? double.tryParse(setup.target!.replaceAll(RegExp(r'[^0-9.]'), ''))
        : null;
    if (entry == null || sl == null || target == null) return null;
    double risk = 0;
    double reward = 0;
    if (setup.isBullish) {
      risk = entry - sl;
      reward = target - entry;
    } else {
      risk = sl - entry;
      reward = entry - target;
    }
    if (risk <= 0 || reward <= 0) return null;
    return '1 : ${(reward / risk).toStringAsFixed(1)} R:R';
  }
}
