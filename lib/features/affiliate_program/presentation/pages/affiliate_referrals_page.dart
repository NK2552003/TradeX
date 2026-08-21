import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/affiliate_program/data/repositories/affiliate_portal_repository.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_overview_page.dart';

/// Referral ledger. Desktop gets a sortable, paginated table; phones get the
/// same column definitions collapsed into cards, so the two never disagree
/// about what a row means.
class AffiliateReferralsPage extends StatefulWidget {
  const AffiliateReferralsPage({
    super.key,
    this.repository,
    this.onOpenPayouts,
    this.onOpenMarketing,
  });

  final AffiliatePortalRepository? repository;
  final VoidCallback? onOpenPayouts;
  final VoidCallback? onOpenMarketing;

  @override
  State<AffiliateReferralsPage> createState() => _AffiliateReferralsPageState();
}

class _AffiliateReferralsPageState extends State<AffiliateReferralsPage> {
  late final AffiliatePortalRepository _repo =
      widget.repository ?? AffiliatePortalRepositoryImpl();

  List<Referral> _rows = const <Referral>[];
  List<String> _channels = const <String>[];
  String _query = '';
  ReferralStatus? _status;
  String? _channel;
  bool _loading = true;
  bool _filtering = false;
  Referral? _open;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getReferrals(),
      _repo.getChannels(),
    ]);
    if (!mounted) return;
    setState(() {
      _rows = results[0]! as List<Referral>;
      _channels = results[1]! as List<String>;
      _loading = false;
    });
  }

  /// Every filter change is a repository query rather than a local `where`, so
  /// the same page works unchanged once this is a paginated API call.
  Future<void> _reload() async {
    setState(() => _filtering = true);
    final String query = _query;
    final ReferralStatus? status = _status;
    final String? channel = _channel;
    final List<Referral> rows = await _repo.getReferrals(
      query: query,
      status: status,
      channel: channel,
    );
    if (!mounted ||
        _query != query ||
        _status != status ||
        _channel != channel) {
      return;
    }
    setState(() {
      _rows = rows;
      _filtering = false;
      if (_open != null && !rows.any((Referral r) => r.id == _open!.id)) {
        _open = null;
      }
    });
  }

  void _setQuery(String value) {
    setState(() => _query = value);
    _reload();
  }

  void _setStatus(ReferralStatus? status) {
    setState(() => _status = status);
    _reload();
  }

  void _setChannel(String? channel) {
    setState(() => _channel = channel);
    _reload();
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _status = null;
      _channel = null;
    });
    _reload();
  }

  bool get _filtered =>
      _query.isNotEmpty || _status != null || _channel != null;

  double get _commission =>
      _rows.fold<double>(0, (double sum, Referral r) => sum + r.commission);

  int get _activeCount =>
      _rows.where((Referral r) => r.status == ReferralStatus.active).length;

  /// A hand-off-ready export: the backend replaces this with a signed download
  /// URL, the page keeps the same call site.
  Future<void> _export() async {
    final StringBuffer csv = StringBuffer(
      'name,email,channel,joined,plan,status,commission\n',
    );
    for (final Referral row in _rows) {
      csv.writeln(
        '${row.name},${row.email},${row.channel},'
        '${row.joinedAt.toIso8601String()},${AppTokens.tierLabel(row.tier)},'
        '${referralStatusLabel(row.status)},${row.commission}',
      );
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Copied ${_rows.length} rows',
      message: 'CSV is on your clipboard, ready to paste into a sheet.',
      intent: UiIntent.success,
    );
  }

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'Referrals',
    subtitle: _loading
        ? 'Loading your referred accounts…'
        : '${_rows.length} account${_rows.length == 1 ? '' : 's'} · '
              '$_activeCount active · ${AppTokens.money(_commission)} commission',
    actions: <Widget>[
      UiButton(
        label: 'Export CSV',
        leadingIcon: Icons.download_rounded,
        variant: UiVariant.outline,
        size: UiSize.sm,
        hideLabelOnMobile: true,
        onPressed: _rows.isEmpty ? null : _export,
      ),
      UiButton(
        label: 'Media kit',
        leadingIcon: Icons.collections_bookmark_outlined,
        size: UiSize.sm,
        hideLabelOnMobile: true,
        onPressed: widget.onOpenMarketing,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppFadeIn(child: _filters()),
        UiGap.v(context.ui.spacing.lg),
        AppFadeIn(delay: AppMotion.step, child: _summary()),
        UiGap.v(context.ui.spacing.lg),
        AppFadeIn(delay: AppMotion.step * 2, child: _table()),
      ],
    ),
  );

  Widget _filters() {
    final Widget search = UiInput.search(
      value: _query,
      hintText: 'Search name, email or channel',
      onChanged: _setQuery,
    );
    final Widget status = UiToggleGroup<ReferralStatus?>(
      value: _status,
      onChanged: _setStatus,
      expand: context.uiRes.isMobile,
      options: <UiToggleOption<ReferralStatus?>>[
        const UiToggleOption<ReferralStatus?>(value: null, label: 'All'),
        for (final ReferralStatus value in ReferralStatus.values)
          UiToggleOption<ReferralStatus?>(
            value: value,
            label: referralStatusLabel(value),
            intent: referralStatusIntent(value),
          ),
      ],
    );
    final Widget channel = UiSelect<String?>(
      value: _channel,
      hintText: 'Any channel',
      leadingIcon: Icons.campaign_outlined,
      onChanged: _setChannel,
      options: <UiOption<String?>>[
        const UiOption<String?>(value: null, label: 'Any channel'),
        for (final String option in _channels)
          UiOption<String?>(value: option, label: option),
      ],
    );

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (context.uiRes.isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                search,
                UiGap.v(context.ui.spacing.sm),
                channel,
                UiGap.v(context.ui.spacing.sm),
                status,
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(flex: 2, child: search),
                UiGap.h(context.ui.spacing.md),
                Expanded(child: channel),
                UiGap.h(context.ui.spacing.md),
                Flexible(child: status),
              ],
            ),
          if (_filtered) ...<Widget>[
            UiGap.v(context.ui.spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: UiButton(
                label: 'Clear filters',
                leadingIcon: Icons.filter_alt_off_outlined,
                variant: UiVariant.ghost,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: _clearFilters,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Totals are computed from the rows on screen, so they always describe the
  /// current filter rather than the whole account.
  Widget _summary() {
    final double average = _rows.isEmpty ? 0 : _commission / _rows.length;
    final int trialing = _rows
        .where((Referral r) => r.status == ReferralStatus.trialing)
        .length;
    final int churned = _rows
        .where((Referral r) => r.status == ReferralStatus.churned)
        .length;
    final List<Widget> cards = <Widget>[
      UiMetricCard(
        label: 'Commission in view',
        value: AppTokens.money(_commission),
        icon: Icons.payments_rounded,
      ),
      UiMetricCard(
        label: 'Average per account',
        value: AppTokens.money(average),
        icon: Icons.calculate_outlined,
      ),
      UiMetricCard(
        label: 'Active',
        value: '$_activeCount of ${_rows.length}',
        icon: Icons.verified_outlined,
      ),
      UiMetricCard(
        label: 'Trialing / churned',
        value: '$trialing / $churned',
        icon: Icons.timelapse_outlined,
      ),
    ];
    return UiCardGrid(
      mobileColumns: 2,
      tabletColumns: 2,
      desktopColumns: 4,
      largeColumns: 4,
      childAspectRatio: context.uiRes.pick<double>(
        mobile: 1.5,
        tablet: 1.9,
        desktop: 1.8,
      ),
      children: cards,
    );
  }

  Widget _table() => UiCard(
    title: 'Attributed accounts',
    subtitle: _filtered
        ? 'Filtered view — clear the filters to see every account'
        : 'Sorted by signup date, newest first',
    child: UiTable<Referral>(
      rows: _rows,
      loading: _loading || _filtering,
      stackOnMobile: true,
      pageSize: 10,
      stickyHeader: true,
      onRowTap: _openDetail,
      emptyLabel: _filtered
          ? 'No referral matches these filters'
          : 'No referrals yet — share your link to get started',
      columns: <UiTableColumn<Referral>>[
        UiTableColumn<Referral>(
          header: 'Account',
          flex: 2,
          compare: (Referral a, Referral b) => a.name.compareTo(b.name),
          cell: (BuildContext context, Referral row) => Row(
            children: <Widget>[
              UiAvatar(name: row.name, size: UiSize.sm),
              UiGap.h(context.ui.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      row.name,
                      style: context.uiText.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      row.email,
                      style: context.uiText.caption.copyWith(
                        color: context.uiColors.foregroundMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        UiTableColumn<Referral>(
          header: 'Channel',
          hideBelow: UiTableVisibility.tabletUp,
          compare: (Referral a, Referral b) => a.channel.compareTo(b.channel),
          cell: (BuildContext context, Referral row) => Text(
            row.channel,
            style: context.uiText.body,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        UiTableColumn<Referral>(
          header: 'Plan',
          compare: (Referral a, Referral b) =>
              a.tier.index.compareTo(b.tier.index),
          cell: (BuildContext context, Referral row) => UiBadge(
            label: AppTokens.tierLabel(row.tier),
            icon: AppTokens.tierIcon(row.tier),
            intent: AppTokens.tierIntent(row.tier),
          ),
        ),
        UiTableColumn<Referral>(
          header: 'Joined',
          hideBelow: UiTableVisibility.desktopUp,
          compare: (Referral a, Referral b) => a.joinedAt.compareTo(b.joinedAt),
          cell: (BuildContext context, Referral row) => Text(
            AppTokens.shortDate(row.joinedAt),
            style: context.uiText.body,
          ),
        ),
        UiTableColumn<Referral>(
          header: 'Status',
          compare: (Referral a, Referral b) =>
              a.status.index.compareTo(b.status.index),
          cell: (BuildContext context, Referral row) => UiBadge(
            label: referralStatusLabel(row.status),
            intent: referralStatusIntent(row.status),
            filled: true,
          ),
        ),
        UiTableColumn<Referral>(
          header: 'Commission',
          numeric: true,
          compare: (Referral a, Referral b) =>
              a.commission.compareTo(b.commission),
          cell: (BuildContext context, Referral row) => Text(
            AppTokens.money(row.commission),
            style: context.uiText.bodyStrong.copyWith(
              color: context.uiColors.bullish,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _openDetail(Referral referral) async {
    setState(() => _open = referral);
    await UiDialog.show<void>(
      context,
      child: _ReferralSheet(
        referral: referral,
        onPayouts: widget.onOpenPayouts,
      ),
    );
    if (!mounted) return;
    setState(() => _open = null);
  }
}

/// Detail sheet for one referral. Read-only: a partner can see attribution and
/// commission but never the referred trader's activity.
class _ReferralSheet extends StatelessWidget {
  const _ReferralSheet({required this.referral, this.onPayouts});

  final Referral referral;
  final VoidCallback? onPayouts;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          UiAvatar(name: referral.name, size: UiSize.md),
          UiGap.h(context.ui.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  referral.name,
                  style: context.uiText.heading,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  referral.email,
                  style: context.uiText.caption.copyWith(
                    color: context.uiColors.foregroundMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          UiIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      UiGap.v(context.ui.spacing.lg),
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ReferralRow(referral: referral),
              UiGap.v(context.ui.spacing.md),
              UiCard(
                title: 'Attribution',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _row(context, 'Channel', referral.channel),
                    _row(
                      context,
                      'Signed up',
                      '${AppTokens.shortDate(referral.joinedAt)} · '
                          '${AppTokens.relativeTime(referral.joinedAt)}',
                    ),
                    _row(context, 'Plan', AppTokens.tierLabel(referral.tier)),
                    _row(
                      context,
                      'Status',
                      referralStatusLabel(referral.status),
                    ),
                    _row(
                      context,
                      'Commission to date',
                      AppTokens.money(referral.commission),
                    ),
                  ],
                ),
              ),
              UiGap.v(context.ui.spacing.md),
              const UiCallout(
                title: 'Privacy',
                message:
                    'You see attribution and commission only. A referred '
                    'trader\'s journal, positions and messages are never '
                    'shared with partners.',
                intent: UiIntent.info,
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
        ),
      ),
      UiGap.v(context.ui.spacing.lg),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          UiButton(
            label: 'Close',
            variant: UiVariant.ghost,
            expandOnMobile: false,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          UiGap.h(context.ui.spacing.sm),
          UiButton(
            label: 'Payout ledger',
            leadingIcon: Icons.account_balance_wallet_outlined,
            expandOnMobile: false,
            onPressed: onPayouts == null
                ? null
                : () {
                    Navigator.of(context).maybePop();
                    onPayouts!.call();
                  },
          ),
        ],
      ),
    ],
  );

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.sm)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: context.uiText.caption.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: context.uiText.body,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}
