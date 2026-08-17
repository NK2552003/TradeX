import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/models/billing_models.dart';
import 'package:tradex/features/settings/presentation/pages/trader/invoice_detail_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

class BillingHistoryPage extends StatefulWidget {
  const BillingHistoryPage({
    super.key,
    this.repository,
  });

  final BillingSettingsRepository? repository;

  @override
  State<BillingHistoryPage> createState() => _BillingHistoryPageState();
}

class _BillingHistoryPageState extends State<BillingHistoryPage> {
  late final BillingSettingsRepository _repo;
  List<Invoice> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BillingSettingsRepositoryImpl();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getBillingHistory();
      if (mounted) {
        setState(() {
          _invoices = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          children: const [
            UiSkeleton(height: 70),
            SizedBox(height: 12),
            UiSkeleton(height: 70),
          ],
        ),
      );
    }

    if (_invoices.isEmpty) {
      return Center(
        child: UiEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No Invoices Yet',
          message: 'Past receipts and invoices will be listed here after renewal.',
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      itemCount: _invoices.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: context.sp(theme.spacing.sm)),
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        return UiCard(
          onTap: () {
            showSettingsSideSheet(
              context,
              title: 'Invoice ${inv.id}',
              subtitle: 'Tax receipt & itemized charge breakdown',
              child: InvoiceDetailPage(invoice: inv),
            );
          },
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: context.radius(theme.radii.md),
                ),
                child: Icon(
                  Icons.receipt_rounded,
                  color: colors.primary,
                  size: context.sz(20),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(inv.id, style: context.uiText.bodyStrong),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        UiBadge(
                          label: inv.status.toUpperCase(),
                          intent: inv.status == 'paid'
                              ? UiIntent.bullish
                              : UiIntent.warning,
                          size: UiSize.xs,
                        ),
                      ],
                    ),
                    Text(
                      '${inv.issuedAt.year}-${inv.issuedAt.month.toString().padLeft(2, '0')}-${inv.issuedAt.day.toString().padLeft(2, '0')} · ₹${inv.amount.toStringAsFixed(2)} ${inv.currency}',
                      style: context.uiText.caption
                          .copyWith(color: colors.foregroundMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: colors.foregroundSubtle),
            ],
          ),
        );
      },
    );
  }
}
