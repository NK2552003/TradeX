import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';

/// Predefined trader feed preset.
class TraderFeedPreset {
  const TraderFeedPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tags,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<String> tags;
}

const List<TraderFeedPreset> kTraderFeedPresets = <TraderFeedPreset>[
  TraderFeedPreset(
    id: 'fno',
    title: 'Nifty & BankNifty F&O',
    description: 'Weekly expiry setups, Greeks, IV skew, max pain and PCR analysis.',
    icon: Icons.flash_on_rounded,
    tags: <String>['#Nifty', '#BankNifty', '#OptionsBuying', '#ExpirySpecial'],
  ),
  TraderFeedPreset(
    id: 'crypto',
    title: 'Crypto Momentum',
    description: 'BTC dominance, high-beta altcoin breakouts, liquidation heatmaps & funding.',
    icon: Icons.currency_bitcoin_rounded,
    tags: <String>['#BTC', '#ETH', '#Solana', '#PerpTrading'],
  ),
  TraderFeedPreset(
    id: 'swing',
    title: 'Swing Equity Breakouts',
    description: 'Stage-2 base breakouts, 52-week highs, VCP contractions & institutional volume.',
    icon: Icons.trending_up_rounded,
    tags: <String>['#BreakoutStocks', '#VCP', '#StageAnalysis', '#CANSLIM'],
  ),
  TraderFeedPreset(
    id: 'scalping',
    title: 'Intraday Scalping & Order Flow',
    description: '1-min to 5-min VWAP retests, volume delta, order blocks & liquidity sweeps.',
    icon: Icons.timer_outlined,
    tags: <String>['#Scalping', '#OrderFlow', '#VWAP', '#FVG'],
  ),
  TraderFeedPreset(
    id: 'macro',
    title: 'Global Macro & Commodities',
    description: 'Gold (XAUUSD), Crude Oil, US 10Y Yields, DXY, and central bank catalysts.',
    icon: Icons.public_rounded,
    tags: <String>['#Gold', '#CrudeOil', '#Macro', '#Forex'],
  ),
];

/// Executive dialog allowing traders to customize, reorder, and add curated feeds.
class CommunityFeedCustomizerDialog extends StatefulWidget {
  const CommunityFeedCustomizerDialog({
    super.key,
    required this.repository,
  });

  final CommunityRepository repository;

  static Future<void> show(
    BuildContext context, {
    required CommunityRepository repository,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ctx.sz(560)),
          child: Container(
            padding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
            decoration: BoxDecoration(
              color: ctx.ui.colors.surface,
              borderRadius: ctx.radius(ctx.ui.radii.lg),
              border: Border.all(
                color: ctx.ui.colors.border,
                width: ctx.ui.borders.hairline,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CommunityFeedCustomizerDialog(repository: repository),
          ),
        ),
      ),
    );
  }

  @override
  State<CommunityFeedCustomizerDialog> createState() =>
      _CommunityFeedCustomizerDialogState();
}

class _CommunityFeedCustomizerDialogState
    extends State<CommunityFeedCustomizerDialog> {
  String _newTabInput = '';

  void _addTab(String tabName) {
    final String clean = tabName.trim();
    if (clean.isEmpty) return;

    if (widget.repository.customFeedTabs.contains(clean)) {
      UiToast.info(
        context,
        title: 'Already Added',
        message: '"$clean" is already active on your feed tabs.',
      );
      return;
    }

    widget.repository.addCustomFeedTab(clean);
    setState(() => _newTabInput = '');

    UiToast.success(
      context,
      title: 'Feed Tab Added',
      message: 'Added "$clean" to your community navigation bar.',
    );
  }

  void _removeTab(String tabName) {
    widget.repository.removeCustomFeedTab(tabName);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<String> activeTabs = widget.repository.customFeedTabs;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                decoration: BoxDecoration(
                  color: theme.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(theme.radii.sm),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: theme.colors.primary,
                  size: context.sz(20),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Customize Feed Sub-Tabs',
                      style: context.uiText.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Add custom watchlist categories or choose institutional trader presets',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiIconButton(
                icon: Icons.close_rounded,
                size: UiSize.xs,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Add custom tab input
                  Text(
                    'Create Custom Tab',
                    style: context.uiText.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: UiInput(
                          value: _newTabInput,
                          hintText: 'e.g. BankNifty Options, Breakouts, \$TSLA...',
                          onChanged: (String val) =>
                              setState(() => _newTabInput = val),
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      UiButton(
                        label: 'Add Tab',
                        leadingIcon: Icons.add_rounded,
                        variant: UiVariant.primary,
                        size: UiSize.sm,
                        onPressed: _newTabInput.trim().isEmpty
                            ? null
                            : () => _addTab(_newTabInput),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Active custom tabs section
                  Row(
                    children: <Widget>[
                      Text(
                        'Active Tabs (${activeTabs.length})',
                        style: context.uiText.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap X to remove',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),

                  if (activeTabs.isEmpty)
                    Container(
                      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                      decoration: BoxDecoration(
                        color: theme.colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(theme.radii.md),
                        border: Border.all(color: theme.colors.border),
                      ),
                      child: Center(
                        child: Text(
                          'No custom tabs added yet. Select a curated preset below!',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: context.sp(theme.spacing.xs),
                      runSpacing: context.sp(theme.spacing.xs),
                      children: <Widget>[
                        for (final String tab in activeTabs)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.sp(theme.spacing.sm),
                              vertical: context.sp(theme.spacing.xxs),
                            ),
                            decoration: BoxDecoration(
                              color: theme.colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(theme.radii.pill),
                              border: Border.all(
                                color: theme.colors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.tag_rounded,
                                  size: context.sz(14),
                                  color: theme.colors.primary,
                                ),
                                SizedBox(width: context.sp(theme.spacing.xxs)),
                                Text(
                                  tab,
                                  style: context.uiText.label.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colors.primary,
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.xxs)),
                                InkWell(
                                  onTap: () => _removeTab(tab),
                                  borderRadius: BorderRadius.circular(theme.radii.pill),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: context.sz(14),
                                    color: theme.colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                  SizedBox(height: context.sp(theme.spacing.lg)),
                  const UiDivider(),
                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Curated trader presets
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome,
                        size: context.sz(16),
                        color: theme.colors.primary,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xxs)),
                      Text(
                        'Curated Trader Presets (1-Click Add)',
                        style: context.uiText.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),

                  for (final TraderFeedPreset preset in kTraderFeedPresets) ...<Widget>[
                    Padding(
                      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
                      child: UiCard(
                        variant: UiCardVariant.surface,
                        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                              decoration: BoxDecoration(
                                color: theme.colors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                preset.icon,
                                size: context.sz(18),
                                color: theme.colors.primary,
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.sm)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    preset.title,
                                    style: context.uiText.bodyStrong.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: context.sp(theme.spacing.xxs)),
                                  Text(
                                    preset.description,
                                    style: context.uiText.caption.copyWith(
                                      color: theme.colors.foregroundMuted,
                                    ),
                                  ),
                                  SizedBox(height: context.sp(theme.spacing.xxs)),
                                  Wrap(
                                    spacing: context.sp(theme.spacing.xxs),
                                    children: preset.tags.map((String t) {
                                      return UiBadge(
                                        label: t,
                                        variant: UiBadgeVariant.outline,
                                        size: UiSize.xs,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            UiButton(
                              label: activeTabs.contains(preset.title)
                                  ? 'Added'
                                  : '+ Add',
                              leadingIcon: activeTabs.contains(preset.title)
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              variant: activeTabs.contains(preset.title)
                                  ? UiVariant.secondary
                                  : UiVariant.primary,
                              size: UiSize.xs,
                              onPressed: activeTabs.contains(preset.title)
                                  ? null
                                  : () => _addTab(preset.title),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: context.sp(theme.spacing.md)),
          UiButton(
            label: 'Done',
            variant: UiVariant.primary,
            size: UiSize.sm,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
