import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/affiliate_program/data/repositories/affiliate_portal_repository.dart';

/// Partner hub: the affiliate's home surface. Everything a partner checks daily
/// — what the link earned, where the traffic came from, who signed up and when
/// the money lands — reachable without leaving the page.
class AffiliateOverviewPage extends StatefulWidget {
  const AffiliateOverviewPage({
    super.key,
    this.repository,
    this.onOpenReferrals,
    this.onOpenPayouts,
    this.onOpenMarketing,
  });

  final AffiliatePortalRepository? repository;
  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenPayouts;
  final VoidCallback? onOpenMarketing;

  @override
  State<AffiliateOverviewPage> createState() => _AffiliateOverviewPageState();
}

class _AffiliateOverviewPageState extends State<AffiliateOverviewPage> {
  late final AffiliatePortalRepository _repo =
      widget.repository ?? AffiliatePortalRepositoryImpl();

  AffiliatePortalSnapshot? _snapshot;
  List<String> _ranges = const <String>[];
  String _range = '30D';
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getRanges(),
      _repo.getSnapshot(range: _range),
    ]);
    if (!mounted) return;
    setState(() {
      _ranges = results[0]! as List<String>;
      _snapshot = results[1]! as AffiliatePortalSnapshot;
      _loading = false;
    });
  }

  Future<void> _setRange(String range) async {
    if (range == _range) return;
    setState(() {
      _range = range;
      _refreshing = true;
    });
    final AffiliatePortalSnapshot snapshot = await _repo.getSnapshot(
      range: range,
    );
    if (!mounted || _range != range) return;
    setState(() {
      _snapshot = snapshot;
      _refreshing = false;
    });
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Link copied',
      message: 'Paste it anywhere — attribution is tracked on the click.',
      intent: UiIntent.success,
    );
  }

  /// The slug is the partner's brand, so it is editable rather than assigned.
  Future<void> _editSlug(String current) async {
    final String? slug = await UiDialog.show<String>(
      context,
      child: _SlugSheet(current: current),
    );
    if (slug == null || slug.trim().isEmpty) return;
    final String link = await _repo.updateSlug(slug);
    final AffiliatePortalSnapshot snapshot = await _repo.getSnapshot(
      range: _range,
    );
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    UiToast.show(
      context,
      title: 'Link updated',
      message: link,
      intent: UiIntent.success,
    );
  }

  String get _subtitle {
    final AffiliatePortalSnapshot? snapshot = _snapshot;
    if (snapshot == null) return 'Loading your partner numbers…';
    return '${AppTokens.percent(snapshot.commissionPercent)} commission · '
        '${AppTokens.money(snapshot.pendingBalance)} pending · '
        '${AppTokens.money(snapshot.lifetimeEarned)} lifetime';
  }

  @override
  Widget build(BuildContext context) {
    final AffiliatePortalSnapshot? snapshot = _snapshot;
    return AppPageBlock(
      title: 'Partner hub',
      subtitle: _subtitle,
      actions: <Widget>[
        if (_ranges.isNotEmpty && !context.uiRes.isMobile)
          UiToggleGroup<String>(
            value: _range,
            onChanged: _setRange,
            options: <UiToggleOption<String>>[
              for (final String range in _ranges)
                UiToggleOption<String>(value: range, label: range),
            ],
          ),
        UiButton(
          label: 'Media kit',
          leadingIcon: Icons.collections_bookmark_outlined,
          variant: UiVariant.secondary,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: widget.onOpenMarketing,
        ),
        UiButton(
          label: 'Payouts',
          leadingIcon: Icons.account_balance_wallet_outlined,
          size: UiSize.sm,
          onPressed: widget.onOpenPayouts,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_ranges.isNotEmpty && context.uiRes.isMobile) ...<Widget>[
            UiToggleGroup<String>(
              value: _range,
              onChanged: _setRange,
              expand: true,
              options: <UiToggleOption<String>>[
                for (final String range in _ranges)
                  UiToggleOption<String>(value: range, label: range),
              ],
            ),
            UiGap.v(context.ui.spacing.lg),
          ],
          AppFadeIn(child: _linkCard(snapshot)),
          UiGap.v(context.ui.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step,
            child: AppStatGridBlock(
              stats: snapshot?.stats ?? const <AppStat>[],
              loading: _loading || _refreshing,
            ),
          ),
          UiGap.v(context.ui.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 3,
            child: AppDashboardLayoutBlock(
              main: <Widget>[
                _clicksCard(snapshot),
                _channelsCard(snapshot),
                _recentCard(snapshot),
              ],
              side: <Widget>[
                _earningsCard(snapshot),
                _payoutStatusCard(snapshot),
                _playbookCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The link is the product. It sits above the numbers because copying it is
  /// the action a partner comes here to perform.
  Widget _linkCard(AffiliatePortalSnapshot? snapshot) {
    if (snapshot == null) {
      return UiCard(child: UiSkeleton(height: context.sz(120)));
    }
    final Widget link = UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.link_rounded,
            size: context.sz(context.ui.sizes.iconSm),
            color: context.uiColors.primary,
          ),
          UiGap.h(context.ui.spacing.sm),
          Expanded(
            child: SelectableText(
              snapshot.referralLink,
              maxLines: 1,
              style: context.uiText.bodyStrong,
            ),
          ),
        ],
      ),
    );
    return UiCard(
      title: 'Your referral link',
      subtitle:
          'Every signup through this link earns '
          '${AppTokens.percent(snapshot.commissionPercent)} of the plan, for as '
          'long as the account stays subscribed.',
      trailing: UiBadge(
        label: '${AppTokens.percent(snapshot.commissionPercent)} rate',
        icon: Icons.percent_rounded,
        intent: UiIntent.success,
        filled: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          link,
          UiGap.v(context.ui.spacing.md),
          Wrap(
            spacing: context.sp(context.ui.spacing.sm),
            runSpacing: context.sp(context.ui.spacing.sm),
            children: <Widget>[
              UiButton(
                label: 'Copy link',
                leadingIcon: Icons.copy_all_rounded,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: () => _copyLink(snapshot.referralLink),
              ),
              UiButton(
                label: 'Edit slug',
                leadingIcon: Icons.edit_outlined,
                variant: UiVariant.outline,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: () => _editSlug(snapshot.referralLink),
              ),
              UiButton(
                label: 'Get creatives',
                leadingIcon: Icons.image_outlined,
                variant: UiVariant.ghost,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: widget.onOpenMarketing,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clicksCard(AffiliatePortalSnapshot? snapshot) {
    final List<AppSeriesPoint> series =
        snapshot?.clicks ?? const <AppSeriesPoint>[];
    final double total = series.fold<double>(
      0,
      (double sum, AppSeriesPoint p) => sum + p.value,
    );
    return UiCard(
      title: 'Link clicks',
      subtitle: '${total.toStringAsFixed(0)} clicks over $_range',
      loading: _loading,
      loadingHeight: 220,
      child: UiChart(
        height: context.uiRes.pick<double>(
          mobile: 180,
          tablet: 240,
          desktop: 280,
        ),
        data: <UiChartPoint>[
          for (final AppSeriesPoint point in series)
            UiChartPoint(label: point.label, values: <double>[point.value]),
        ],
        series: <UiChartSeries>[
          UiChartSeries(
            name: 'Clicks',
            type: UiChartSeriesType.area,
            color: context.uiColors.primary,
          ),
        ],
        showLegend: false,
        valueFormatter: (num v) => v.toStringAsFixed(0),
      ),
    );
  }

  /// Channels are ranked by revenue rather than clicks: the question a partner
  /// is answering is where to spend the next hour, not where the noise is.
  Widget _channelsCard(AffiliatePortalSnapshot? snapshot) {
    final List<ChannelPerformance> rows =
        snapshot?.channels ?? const <ChannelPerformance>[];
    return UiCard(
      title: 'Channel performance',
      subtitle: 'Clicks, signups and revenue by source',
      loading: _loading,
      loadingHeight: 220,
      child: UiTable<ChannelPerformance>(
        rows: rows,
        stackOnMobile: true,
        emptyLabel: 'No traffic attributed yet',
        columns: <UiTableColumn<ChannelPerformance>>[
          UiTableColumn<ChannelPerformance>(
            header: 'Channel',
            flex: 2,
            compare: (ChannelPerformance a, ChannelPerformance b) =>
                a.channel.compareTo(b.channel),
            cell: (BuildContext context, ChannelPerformance row) => Text(
              row.channel,
              style: context.uiText.bodyStrong,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          UiTableColumn<ChannelPerformance>(
            header: 'Clicks',
            numeric: true,
            compare: (ChannelPerformance a, ChannelPerformance b) =>
                a.clicks.compareTo(b.clicks),
            cell: (BuildContext context, ChannelPerformance row) =>
                Text('${row.clicks}', style: context.uiText.body),
          ),
          UiTableColumn<ChannelPerformance>(
            header: 'Signups',
            numeric: true,
            compare: (ChannelPerformance a, ChannelPerformance b) =>
                a.signups.compareTo(b.signups),
            cell: (BuildContext context, ChannelPerformance row) =>
                Text('${row.signups}', style: context.uiText.body),
          ),
          UiTableColumn<ChannelPerformance>(
            header: 'Conv.',
            numeric: true,
            hideBelow: UiTableVisibility.tabletUp,
            compare: (ChannelPerformance a, ChannelPerformance b) =>
                a.conversionPercent.compareTo(b.conversionPercent),
            cell: (BuildContext context, ChannelPerformance row) => UiBadge(
              label: AppTokens.percent(row.conversionPercent),
              intent: row.conversionPercent >= 5
                  ? UiIntent.success
                  : (row.conversionPercent >= 2
                        ? UiIntent.warning
                        : UiIntent.neutral),
            ),
          ),
          UiTableColumn<ChannelPerformance>(
            header: 'Revenue',
            numeric: true,
            compare: (ChannelPerformance a, ChannelPerformance b) =>
                a.revenue.compareTo(b.revenue),
            cell: (BuildContext context, ChannelPerformance row) => Text(
              AppTokens.money(row.revenue),
              style: context.uiText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentCard(AffiliatePortalSnapshot? snapshot) {
    final List<Referral> rows = snapshot?.recentReferrals ?? const <Referral>[];
    return UiCard(
      title: 'Latest signups',
      subtitle: rows.isEmpty
          ? 'Nobody has joined through your link yet'
          : 'The ${rows.length} most recent accounts attributed to you',
      loading: _loading,
      loadingHeight: 200,
      actions: <Widget>[
        UiButton(
          label: 'All referrals',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: widget.onOpenReferrals,
        ),
      ],
      child: rows.isEmpty
          ? UiEmptyState(
              title: 'No referrals yet',
              message: 'Share your link and the first signup shows up here.',
              icon: Icons.person_add_alt_1_outlined,
              action: UiButton(
                label: 'Open the media kit',
                leadingIcon: Icons.collections_bookmark_outlined,
                expandOnMobile: false,
                onPressed: widget.onOpenMarketing,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < rows.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: context.sp(context.ui.spacing.sm),
                    ),
                    child: AppFadeIn(
                      delay: AppMotion.step * i,
                      child: ReferralRow(referral: rows[i]),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _earningsCard(AffiliatePortalSnapshot? snapshot) {
    if (snapshot == null) {
      return UiCard(child: UiSkeleton(height: context.sz(160)));
    }
    final double lifetime = snapshot.lifetimeEarned;
    final double pending = snapshot.pendingBalance;
    final double paid = (lifetime - pending).clamp(0, double.infinity);
    return UiCard(
      title: 'Earnings',
      subtitle: 'Lifetime ${AppTokens.money(lifetime)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _Figure(
                  label: 'Ready to withdraw',
                  value: AppTokens.money(pending),
                  intent: UiIntent.success,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Already paid',
                  value: AppTokens.money(paid),
                  intent: UiIntent.neutral,
                ),
              ),
            ],
          ),
          UiGap.v(context.ui.spacing.md),
          UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: paid,
                label: 'Paid',
                color: context.uiColors.foregroundSubtle,
              ),
              UiCategorySegment(
                value: pending,
                label: 'Pending',
                color: context.uiColors.bullish,
              ),
            ],
          ),
          UiGap.v(context.ui.spacing.md),
          UiButton(
            label: 'Request a payout',
            leadingIcon: Icons.account_balance_wallet_outlined,
            expand: true,
            onPressed: pending <= 0 ? null : widget.onOpenPayouts,
          ),
          if (pending <= 0) ...<Widget>[
            UiGap.v(context.ui.spacing.sm),
            Text(
              'Nothing to withdraw — the balance builds as referred accounts '
              'are billed.',
              style: context.uiText.caption.copyWith(
                color: context.uiColors.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _payoutStatusCard(AffiliatePortalSnapshot? snapshot) {
    final Payout? next = snapshot?.nextPayout;
    if (snapshot == null) {
      return UiCard(child: UiSkeleton(height: context.sz(120)));
    }
    if (next == null) {
      return UiCard(
        title: 'Next payout',
        subtitle: 'No request in flight',
        child: UiEmptyState(
          title: 'Nothing scheduled',
          message: 'Request a withdrawal and its progress shows up here.',
          icon: Icons.schedule_rounded,
        ),
      );
    }
    return UiCard(
      title: 'Next payout',
      subtitle:
          '${next.method} · requested ${AppTokens.relativeTime(next.requestedAt)}',
      trailing: UiBadge(
        label: payoutStatusLabel(next.status),
        intent: payoutStatusIntent(next.status),
        filled: true,
      ),
      actions: <Widget>[
        UiButton(
          label: 'Payout ledger',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: widget.onOpenPayouts,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(AppTokens.money(next.amount), style: context.uiText.display),
          UiGap.v(context.ui.spacing.md),
          UiStepper(
            steps: const <UiStepperStep>[
              UiStepperStep(title: 'Requested'),
              UiStepperStep(title: 'Processing'),
              UiStepperStep(title: 'Paid'),
            ],
            currentIndex: switch (next.status) {
              PayoutStatus.pending => 0,
              PayoutStatus.processing => 1,
              PayoutStatus.paid => 2,
            },
          ),
        ],
      ),
    );
  }

  Widget _playbookCard() => const UiCallout(
    title: 'What converts',
    message:
        'Partners earn most from a walkthrough of their own journal — show the '
        'workflow, not the pricing page. Deep-link straight to a feature and '
        'the signup rate roughly doubles.',
    intent: UiIntent.info,
    icon: Icons.lightbulb_outline_rounded,
  );
}

/// One referred account. Shared with the referrals page so a row reads the same
/// way in both places.
class ReferralRow extends StatelessWidget {
  const ReferralRow({super.key, required this.referral, this.onTap});

  final Referral referral;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => UiCard(
    variant: UiCardVariant.surface,
    padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
    onTap: onTap,
    child: Row(
      children: <Widget>[
        UiAvatar(name: referral.name, size: UiSize.sm),
        UiGap.h(context.ui.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                referral.name,
                style: context.uiText.bodyStrong,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${referral.channel} · joined '
                '${AppTokens.relativeTime(referral.joinedAt)}',
                style: context.uiText.caption.copyWith(
                  color: context.uiColors.foregroundMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        UiGap.h(context.ui.spacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              AppTokens.money(referral.commission),
              style: context.uiText.bodyStrong.copyWith(
                color: context.uiColors.bullish,
              ),
            ),
            UiGap.v(context.ui.spacing.xs),
            UiBadge(
              label: referralStatusLabel(referral.status),
              intent: referralStatusIntent(referral.status),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Small label/value pair used inside the earnings card.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.intent,
  });

  final String label;
  final String value;
  final UiIntent intent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: context.uiText.caption.copyWith(
          color: context.uiColors.foregroundMuted,
        ),
      ),
      UiGap.v(context.ui.spacing.xs),
      Text(
        value,
        style: context.uiText.heading.copyWith(color: intent.color(context)),
      ),
    ],
  );
}

/// Slug editor. Kept as its own sheet so the link card stays a read surface.
class _SlugSheet extends StatefulWidget {
  const _SlugSheet({required this.current});

  final String current;

  @override
  State<_SlugSheet> createState() => _SlugSheetState();
}

class _SlugSheetState extends State<_SlugSheet> {
  late String _slug = widget.current.split('/').last;

  String? get _error {
    final String value = _slug.trim();
    if (value.length < 3) return 'At least three characters.';
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(value)) {
      return 'Lower-case letters, numbers, dashes and underscores only.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Edit your slug', style: context.uiText.heading),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.xs),
        Text(
          'This is the tail of your link. Changing it does not break past '
          'attribution — old links keep resolving.',
          style: context.uiText.caption.copyWith(
            color: context.uiColors.foregroundMuted,
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        Flexible(
          child: SingleChildScrollView(
            child: UiField(
              label: 'Slug',
              error: _slug.isEmpty ? null : error,
              child: UiInput(
                value: _slug,
                prefixText: 'tradex.ai/r/',
                error: _slug.isNotEmpty && error != null,
                onChanged: (String value) => setState(() => _slug = value),
              ),
            ),
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.ghost,
              expandOnMobile: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            UiGap.h(context.ui.spacing.sm),
            UiButton(
              label: 'Save',
              expandOnMobile: false,
              onPressed: error != null
                  ? null
                  : () => Navigator.of(context).pop(_slug.trim()),
            ),
          ],
        ),
      ],
    );
  }
}
