import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/models/billing_models.dart';

/// A single receipt: letterhead, who it was billed to, the itemised charge and
/// the tax breakdown.
///
/// Every figure is read off the [Invoice] or derived from its total, so the
/// breakdown always adds up to what was charged. The issuing entity, the tax
/// rate and the card that settled the charge travel on the invoice too — this
/// layout does not know any of them on its own.
class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({
    super.key,
    required this.invoice,
    this.billedToName,
    this.billedToEmail,
  });

  final Invoice invoice;

  /// Account the charge was raised against. Supplied by the caller from the
  /// profile rather than assumed here — an invoice naming the wrong person is
  /// worse than one that omits the line.
  final String? billedToName;
  final String? billedToEmail;

  bool get _paid => invoice.status == 'paid';

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool stacked = context.uiRes.isMobile;

    return SingleChildScrollView(
      // Bottom padding clears the phone dock, which floats over the page.
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg) + (stacked ? context.uiDockInset : 0),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: UiButton(
                  label: 'Download PDF',
                  leadingIcon: Icons.picture_as_pdf_outlined,
                  size: UiSize.xs,
                  onPressed: () => UiToast.show(
                    context,
                    title: 'Preparing ${invoice.id}.pdf',
                    message: 'Your receipt will download in a moment.',
                    intent: UiIntent.info,
                  ),
                ),
              ),
              UiGap.v(theme.spacing.sm),
              UiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _header(context, stacked: stacked),
                    UiGap.v(theme.spacing.lg),
                    UiDivider(),
                    UiGap.v(theme.spacing.md),
                    _parties(context, stacked: stacked),
                    UiGap.v(theme.spacing.lg),
                    _lineItems(context),
                    UiGap.v(theme.spacing.lg),
                    _totals(context),
                    UiGap.v(theme.spacing.xl),
                    UiCallout(
                      title: _settlementTitle,
                      message: _settlementMessage,
                      intent: _paid ? UiIntent.info : UiIntent.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _settlementTitle {
    final String? card = invoice.paymentMethodLabel;
    if (!_paid) return 'This invoice is ${invoice.status}';
    return card == null ? 'Paid in full' : 'Paid with $card';
  }

  String get _settlementMessage {
    final InvoiceIssuer? issuer = invoice.issuer;
    final String contact = issuer == null
        ? ''
        : ' For billing questions contact ${issuer.supportEmail}.';
    return _paid
        ? 'Thank you for your business.$contact'
        : 'Settle it from the billing page to keep your plan active.$contact';
  }

  /// Letterhead: the issuing entity on one side, the document reference and its
  /// status on the other.
  Widget _header(BuildContext context, {required bool stacked}) {
    final InvoiceIssuer? issuer = invoice.issuer;
    final Widget from = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(issuer?.name ?? 'TradeX', style: context.uiText.subheading),
        if (issuer != null)
          for (final String line in <String>[
            ...issuer.addressLines,
            issuer.supportEmail,
            if (issuer.taxId != null) '${issuer.taxLabel} ${issuer.taxId}',
          ])
            Text(
              line,
              style: context.uiText.caption.copyWith(
                color: context.ui.colors.foregroundMuted,
              ),
            ),
      ],
    );
    final Widget reference = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          'INVOICE',
          style: context.uiText.heading.copyWith(letterSpacing: 1.5),
        ),
        Text(
          invoice.id,
          style: context.uiText.caption.copyWith(
            color: context.ui.colors.foregroundMuted,
          ),
        ),
        UiGap.v(context.ui.spacing.xs),
        UiBadge(
          label: invoice.status.toUpperCase(),
          intent: _paid ? UiIntent.bullish : UiIntent.warning,
          size: UiSize.xs,
        ),
      ],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[reference, UiGap.v(context.ui.spacing.md), from],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: from),
        reference,
      ],
    );
  }

  /// Who was billed, and when the charge was raised.
  Widget _parties(BuildContext context, {required bool stacked}) {
    final Widget billedTo = _labelled(
      context,
      label: 'Billed to',
      value: (billedToName ?? '').trim().isEmpty
          ? 'This account'
          : billedToName!.trim(),
      detail: (billedToEmail ?? '').trim().isEmpty
          ? null
          : billedToEmail!.trim(),
    );
    final Widget issued = _labelled(
      context,
      label: 'Date issued',
      value: AppTokens.fullDate(invoice.issuedAt),
      align: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[billedTo, UiGap.v(context.ui.spacing.md), issued],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: billedTo),
        issued,
      ],
    );
  }

  Widget _labelled(
    BuildContext context, {
    required String label,
    required String value,
    String? detail,
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) => Column(
    crossAxisAlignment: align,
    children: <Widget>[
      Text(
        label,
        style: context.uiText.caption.copyWith(
          color: context.ui.colors.foregroundMuted,
        ),
      ),
      Text(value, style: context.uiText.bodyStrong),
      if (detail != null)
        Text(
          detail,
          style: context.uiText.caption.copyWith(
            color: context.ui.colors.foregroundMuted,
          ),
        ),
    ],
  );

  /// The itemisation. A credit (a coupon) carries a negative amount, so it is
  /// tinted as one rather than reading like another charge.
  Widget _lineItems(BuildContext context) {
    final UiTheme theme = context.ui;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.border),
        borderRadius: context.radius(theme.radii.md),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.sm),
            ),
            decoration: BoxDecoration(
              color: theme.colors.surfaceHover,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(theme.radii.md),
              ),
            ),
            child: _itemRow(
              context,
              description: 'Description',
              quantity: 'Qty',
              amount: 'Amount',
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (invoice.lineItems.isEmpty)
            Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Text(
                'No itemisation was supplied for this charge.',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ),
          for (final InvoiceLineItem item in invoice.lineItems)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.sm),
              ),
              child: _itemRow(
                context,
                description: item.description,
                quantity: '${item.quantity}',
                amount: AppTokens.money(item.amount * item.quantity),
                style: context.uiText.body,
                amountColor: item.amount < 0 ? theme.colors.bullish : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _itemRow(
    BuildContext context, {
    required String description,
    required String quantity,
    required String amount,
    required TextStyle style,
    Color? amountColor,
  }) => Row(
    children: <Widget>[
      Expanded(flex: 5, child: Text(description, style: style)),
      Expanded(
        child: Text(quantity, textAlign: TextAlign.center, style: style),
      ),
      Expanded(
        flex: 2,
        child: Text(
          amount,
          textAlign: TextAlign.right,
          style: amountColor == null
              ? style
              : style.copyWith(color: amountColor),
        ),
      ),
    ],
  );

  /// Subtotal, tax and total. The taxable value is the total with tax stripped
  /// out rather than a separate figure, so the two lines always sum to the
  /// amount charged.
  Widget _totals(BuildContext context) {
    final UiTheme theme = context.ui;
    final String taxLabel = invoice.issuer?.taxLabel ?? 'Tax';
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: context.sz(280),
        child: Column(
          children: <Widget>[
            _totalRow(
              context,
              label: 'Subtotal',
              value: AppTokens.money(invoice.subtotal),
            ),
            if (invoice.taxPercent > 0) ...<Widget>[
              UiGap.v(theme.spacing.xxs),
              _totalRow(
                context,
                label: 'Taxable value',
                value: AppTokens.money(invoice.netAmount),
              ),
              UiGap.v(theme.spacing.xxs),
              _totalRow(
                context,
                label:
                    '$taxLabel (${AppTokens.percent(invoice.taxPercent, decimals: 0)} included)',
                value: AppTokens.money(invoice.taxAmount),
              ),
            ],
            UiGap.v(theme.spacing.xs),
            UiDivider(),
            UiGap.v(theme.spacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _paid ? 'Total paid' : 'Amount due',
                  style: context.uiText.subheading,
                ),
                Text(
                  '${AppTokens.money(invoice.amount)} ${invoice.currency}',
                  style: context.uiText.subheading.copyWith(
                    color: theme.colors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(
    BuildContext context, {
    required String label,
    required String value,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Expanded(
        child: Text(
          label,
          style: context.uiText.caption.copyWith(
            color: context.ui.colors.foregroundMuted,
          ),
        ),
      ),
      Text(value, style: context.uiText.body),
    ],
  );
}
