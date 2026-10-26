import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/affiliate_program/presentation/widgets/affiliate_workspace_view.dart';

class AffiliateMarketingPage extends StatefulWidget {
  const AffiliateMarketingPage({
    super.key,
    this.onNavigate,
    this.onSwitchToTraderView,
    this.onOpenReferrals,
    this.onOpenPayouts,
    this.repository,
  });

  final ValueChanged<String>? onNavigate;
  final VoidCallback? onSwitchToTraderView;
  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenPayouts;
  final AffiliateWorkspaceRepository? repository;

  @override
  State<AffiliateMarketingPage> createState() => _AffiliateMarketingPageState();
}

class _AffiliateMarketingPageState extends State<AffiliateMarketingPage> {
  late final AffiliateWorkspaceRepository _repo =
      widget.repository ?? AffiliateWorkspaceRepository();
  String _name = '', _slug = '', _channel = 'youtube';
  String? _error;
  bool _saving = false;
  bool _slugEdited = false;

  Future<void> _create(VoidCallback reload) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.createCampaign(_name, _channel, _slug);
      if (!mounted) return;
      setState(() {
        _name = '';
        _slug = '';
        _slugEdited = false;
        _saving = false;
      });
      reload();
      UiToast.show(
        context,
        title: 'Campaign created',
        message: 'Your new UTM tracking link is ready to share.',
        intent: UiIntent.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst(RegExp(r'^.*?: '), '');
      });
    }
  }

  Future<void> _toggle(AffiliateRecord campaign, VoidCallback reload) async {
    final active = campaign.text('status') != 'active';
    try {
      await _repo.setCampaignStatus(campaign.id, active);
      if (!mounted) return;
      reload();
      UiToast.show(
        context,
        title: active ? 'Campaign resumed' : 'Campaign paused',
        message: campaign.text('name'),
        intent: UiIntent.info,
      );
    } catch (e) {
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Could not update campaign',
        message: '$e',
        intent: UiIntent.danger,
      );
    }
  }

  Future<void> _deleteCampaign(
    AffiliateRecord campaign,
    VoidCallback reload,
  ) async {
    try {
      await _repo.deleteCampaign(campaign.id);
      if (!mounted) return;
      reload();
      UiToast.show(
        context,
        title: 'Campaign deleted',
        message: '${campaign.text('name')} has been removed.',
        intent: UiIntent.warning,
      );
    } catch (e) {
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Could not delete campaign',
        message: '$e',
        intent: UiIntent.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AffiliateWorkspaceView(
      title: 'Campaign Studio & Media Kit',
      subtitle:
          'Create channel-specific UTM referral links, track INR revenue attribution, and copy SEBI/ASCI-compliant creative assets.',
      repository: _repo,
      onNavigate: widget.onNavigate,
      actions: (ctx, w, _) => [
        if (widget.onSwitchToTraderView != null)
          UiButton(
            label: 'Trader View',
            leadingIcon: Icons.candlestick_chart_rounded,
            size: UiSize.sm,
            variant: UiVariant.secondary,
            onPressed: widget.onSwitchToTraderView,
          ),
        if (w.referralUrl.isNotEmpty)
          UiButton(
            label: 'Copy Base Link',
            leadingIcon: Icons.copy_rounded,
            size: UiSize.sm,
            variant: UiVariant.outline,
            onPressed: () =>
                copyAffiliateText(ctx, 'Referral link', w.referralUrl),
          ),
      ],
      builder: (context, w, reload) {
        final double totalCampaignRevenue = w.campaigns.fold<double>(
          0,
          (sum, c) => sum + c.number('revenue_generated_inr'),
        );
        final builderCard = UiCard(
          title: 'Create Campaign Link',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null) ...[
                UiCallout(
                  title: 'Check campaign details',
                  message: _error,
                  intent: UiIntent.warning,
                ),
                UiGap.v(context.ui.spacing.sm),
              ],
              UiField(
                label: 'Campaign Name',
                child: UiInput(
                  value: _name,
                  hintText: 'NIFTY Weekly Journal Walkthrough',
                  onChanged: (v) => setState(() {
                    _name = v;
                    if (!_slugEdited) {
                      _slug = v
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                          .replaceAll(RegExp(r'^-|-$'), '');
                    }
                  }),
                ),
              ),
              UiGap.v(context.ui.spacing.sm),
              UiField(
                label: 'Channel',
                child: UiSelect<String>(
                  value: _channel,
                  onChanged: (v) => setState(() => _channel = v),
                  options: const [
                    UiOption(value: 'youtube', label: 'YouTube'),
                    UiOption(value: 'newsletter', label: 'Newsletter'),
                    UiOption(value: 'instagram', label: 'Instagram'),
                    UiOption(value: 'website', label: 'Website'),
                    UiOption(value: 'other', label: 'Other'),
                  ],
                ),
              ),
              UiGap.v(context.ui.spacing.sm),
              UiField(
                label: 'UTM Campaign Slug',
                helper: '3–40 lowercase letters, numbers or hyphens.',
                child: UiInput(
                  value: _slug,
                  hintText: 'weekly-journal',
                  onChanged: (v) => setState(() {
                    _slug = v;
                    _slugEdited = true;
                  }),
                ),
              ),
              UiGap.v(context.ui.spacing.md),
              UiButton(
                label: 'Create tracking link',
                leadingIcon: Icons.add_link_rounded,
                intent: UiIntent.primary,
                loading: _saving,
                onPressed: () => _create(reload.call),
              ),
            ],
          ),
        );

        final campaignsCard = UiCard(
          padding: EdgeInsets.zero,
          headerPadding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
          title: 'Campaign Links',
          trailing: UiBadge(
            label: 'Attributed: ${w.money(totalCampaignRevenue)}',
            intent: UiIntent.bullish,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiTable<AffiliateRecord>(
                rows: w.campaigns,
                rowKey: (c) => c.id,
                stackOnMobile: true,
                emptyLabel: 'No campaigns created yet.',
                columns: [
                  UiTableColumn<AffiliateRecord>(
                    id: 'name',
                    flex: 2,
                    label: 'Campaign',
                    cellBuilder: (ctx, c) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.text('name'), style: ctx.uiText.bodyStrong),
                        Text(
                          w.campaignUrl(c),
                          style: ctx.uiText.caption.copyWith(
                            color: ctx.ui.colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiTableColumn<AffiliateRecord>(
                    id: 'channel',
                    label: 'Channel',
                    cellBuilder: (_, c) =>
                        Text(c.text('channel').toUpperCase()),
                  ),
                  UiTableColumn<AffiliateRecord>(
                    id: 'clicks',
                    label: 'Clicks & Rev (₹)',
                    numeric: true,
                    cellBuilder: (ctx, c) => Text(
                      '${c.count('clicks')} · ${w.money(c.number('revenue_generated_inr'))}',
                      style: ctx.uiText.mono,
                    ),
                  ),
                  UiTableColumn<AffiliateRecord>(
                    id: 'actions',
                    label: 'Actions',
                    cellBuilder: (ctx, c) => Wrap(
                      spacing: ctx.sp(ctx.ui.spacing.xs),
                      runSpacing: ctx.sp(ctx.ui.spacing.xxs),
                      children: [
                        UiButton(
                          label: 'Copy',
                          size: UiSize.xs,
                          variant: UiVariant.outline,
                          onPressed: () => copyAffiliateText(
                            ctx,
                            'Campaign link',
                            w.campaignUrl(c),
                          ),
                        ),
                        UiButton(
                          label: c.text('status') == 'active'
                              ? 'Pause'
                              : 'Resume',
                          size: UiSize.xs,
                          variant: UiVariant.ghost,
                          onPressed: () => _toggle(c, reload.call),
                        ),
                        UiIconButton(
                          icon: Icons.delete_outline_rounded,
                          size: UiSize.xs,
                          variant: UiVariant.ghost,
                          tooltip: 'Delete campaign',
                          onPressed: () => _deleteCampaign(c, reload.call),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 900
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: builderCard),
                        UiGap.h(context.ui.spacing.md),
                        Expanded(flex: 7, child: campaignsCard),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        builderCard,
                        UiGap.v(context.ui.spacing.md),
                        campaignsCard,
                      ],
                    ),
            ),
            UiGap.v(context.ui.spacing.lg),
            Text(
              'Approved Copy & SEBI/ASCI Disclosure Templates',
              style: context.uiText.heading,
            ),
            UiGap.v(context.ui.spacing.sm),
            UiCardGrid(
              equalHeight: true,
              minTileWidth: 270,
              children: [
                for (final asset in w.assets)
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: context.sp(context.ui.spacing.xs),
                          runSpacing: context.sp(context.ui.spacing.xxs),
                          children: [
                            Text(
                              asset.text('title'),
                              style: context.uiText.bodyStrong,
                            ),
                            UiBadge(
                              label: asset.text('format'),
                              intent: UiIntent.info,
                            ),
                          ],
                        ),
                        UiGap.v(context.ui.spacing.sm),
                        Text(
                          asset
                              .text('body')
                              .replaceAll('{{referral_url}}', w.referralUrl)
                              .replaceAll('{link}', w.referralUrl),
                          style: context.uiText.caption,
                        ),
                        UiGap.v(context.ui.spacing.md),
                        UiButton(
                          label: 'Copy text with link',
                          leadingIcon: Icons.copy_rounded,
                          size: UiSize.xs,
                          variant: UiVariant.outline,
                          onPressed: () => copyAffiliateText(
                            context,
                            asset.text('title'),
                            asset
                                .text('body')
                                .replaceAll('{{referral_url}}', w.referralUrl)
                                .replaceAll('{link}', w.referralUrl),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
