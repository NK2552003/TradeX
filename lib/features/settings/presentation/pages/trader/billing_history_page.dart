import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/models/billing_models.dart';
import 'package:tradex/features/settings/presentation/pages/trader/invoice_detail_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

/// Past charges: a summary of what this account has been billed, a status
/// filter, and a row per invoice that opens the full receipt.
///
/// The totals are added up from the invoices themselves rather than quoted, so
/// the figure at the top of the page is the sum of the rows underneath it.
class BillingHistoryPage extends StatefulWidget {
  const BillingHistoryPage({
    super.key,
    this.repository,
    this.profileRepository,
  });

  final BillingSettingsRepository? repository;

  /// Supplies the "billed to" identity on an opened invoice.
  final ProfileSettingsRepository? profileRepository;

  @override
  State<BillingHistoryPage> createState() => _BillingHistoryPageState();
}

class _BillingHistoryPageState extends State<BillingHistoryPage> {
  late final BillingSettingsRepository _repo;
  late final ProfileSettingsRepository _profiles;
  List<Invoice> _invoices = const <Invoice>[];
  UserProfileModel? _profile;
  SubscriptionSummary? _subscription;
  bool _loading = true;

  /// Set when the load itself failed, which is a different state from an account
  /// that has genuinely never been charged.
  bool _failed = false;

  /// Status being shown, or 'all'. Options come from the invoices on file.
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BillingSettingsRepositoryImpl();
    _profiles = widget.profileRepository ?? ProfileSettingsRepositoryImpl();
    _profile = _profiles.cachedProfile;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final List<Object?> loaded = await Future.wait<Object?>(<Future<Object?>>[
        _repo.getBillingHistory(),
        _profiles.getProfile(),
        _repo.getSubscription(),
      ]);
      if (!mounted) return;
      setState(() {
        _invoices = loaded[0]! as List<Invoice>;
        _profile = loaded[1]! as UserProfileModel;
        _subscription = loaded[2]! as SubscriptionSummary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Statuses actually present, so the filter never offers one that would come
  /// back empty.
  List<String> get _statusOptions {
    final Set<String> seen = <String>{
      for (final Invoice invoice in _invoices) invoice.status,
    };
    return <String>['all', ...seen.toList()..sort()];
  }

  List<Invoice> get _rows => _filter == 'all'
      ? _invoices
      : _invoices
            .where((Invoice invoice) => invoice.status == _filter)
            .toList(growable: false);

  double _sum(double Function(Invoice invoice) value) =>
      _invoices.fold<double>(0, (double sum, Invoice i) => sum + value(i));

  /// Totals for the account, added up from the invoices on screen.
  List<AppStat> get _stats => <AppStat>[
    AppStat(
      label: 'Invoices',
      value: _invoices.length,
      icon: Icons.receipt_long_outlined,
    ),
    AppStat(
      label: 'Total billed',
      value: _sum((Invoice i) => i.amount),
      icon: Icons.payments_outlined,
      formatter: AppTokens.money,
    ),
    AppStat(
      label: 'Tax included',
      value: _sum((Invoice i) => i.taxAmount),
      icon: Icons.receipt_outlined,
      formatter: AppTokens.money,
    ),
  ];

  void _openInvoice(Invoice invoice) {
    showSettingsSideSheet(
      context,
      title: 'Invoice ${invoice.id}',
      subtitle: 'Tax receipt and itemised charge breakdown',
      child: InvoiceDetailPage(
        invoice: invoice,
        billedToName: _profile?.displayName,
        billedToEmail: _profile?.email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool isMobile = context.uiRes.isMobile;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : 108.0)
        : context.sp(theme.spacing.lg);
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      context.sp(theme.spacing.lg),
      context.sp(theme.spacing.lg),
      context.sp(theme.spacing.lg),
      bottomInset,
    );

    if (_loading) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const <Widget>[
            UiSkeleton(height: 96),
            SizedBox(height: 16),
            UiSkeleton(height: 70),
            SizedBox(height: 12),
            UiSkeleton(height: 70),
          ],
        ),
      );
    }

    if (_failed) {
      return Center(
        child: UiEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load your invoices',
          message: 'The billing service did not respond. Nothing was charged.',
          action: UiButton(
            label: 'Retry',
            intent: UiIntent.primary,
            onPressed: _load,
          ),
        ),
      );
    }

    if (_invoices.isEmpty) return Center(child: _emptyState());

    final List<Invoice> rows = _rows;
    final List<String> options = _statusOptions;

    return ListView(
      padding: padding,
      children: <Widget>[
        AppStatGridBlock(stats: _stats),
        if (options.length > 2) ...<Widget>[
          UiGap.v(theme.spacing.md),
          UiToggleGroup<String>(
            value: _filter,
            size: UiSize.sm,
            options: <UiToggleOption<String>>[
              for (final String status in options)
                UiToggleOption<String>(
                  value: status,
                  label: status == 'all'
                      ? 'All'
                      : '${status[0].toUpperCase()}${status.substring(1)}',
                ),
            ],
            onChanged: (String value) => setState(() => _filter = value),
          ),
        ],
        UiGap.v(theme.spacing.lg),
        for (int i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: AppFadeIn(
              delay: AppMotion.step * i,
              child: _invoiceRow(rows[i]),
            ),
          ),
      ],
    );
  }

  /// What an account with no invoices sees. A free plan has never been charged,
  /// which is a different message from a paid plan waiting on its first renewal.
  Widget _emptyState() {
    final bool free = _subscription?.tier == AppTier.free;
    return UiEmptyState(
      icon: Icons.receipt_long_outlined,
      title: free ? 'Nothing billed yet' : 'No invoices yet',
      message: free
          ? 'The Free plan does not charge, so there is nothing to receipt. '
                'Invoices appear here from your first paid period.'
          : 'Your first receipt appears here once the current period renews.',
    );
  }

  Widget _invoiceRow(Invoice invoice) {
    final UiTheme theme = context.ui;
    final bool paid = invoice.status == 'paid';
    return UiCard(
      onTap: () => _openInvoice(invoice),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.primary.withValues(alpha: 0.1),
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              Icons.receipt_rounded,
              color: theme.colors.primary,
              size: context.sz(theme.sizes.iconSm),
            ),
          ),
          UiGap.h(theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        invoice.id,
                        style: context.uiText.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    UiGap.h(theme.spacing.xs),
                    UiBadge(
                      label: invoice.status.toUpperCase(),
                      intent: paid ? UiIntent.bullish : UiIntent.warning,
                      size: UiSize.xs,
                    ),
                  ],
                ),
                Text(
                  '${AppTokens.fullDate(invoice.issuedAt)} · '
                  '${AppTokens.money(invoice.amount)} ${invoice.currency}',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colors.foregroundSubtle,
          ),
        ],
      ),
    );
  }
}
