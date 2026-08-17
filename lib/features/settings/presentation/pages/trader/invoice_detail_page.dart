import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/models/billing_models.dart';

class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({
    super.key,
    required this.invoice,
  });

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  UiButton(
                    label: 'Download PDF',
                    leadingIcon: Icons.picture_as_pdf_outlined,
                    size: UiSize.xs,
                    onPressed: () {
                      UiToast.show(
                        context,
                        title: 'Downloading Invoice',
                        message: 'Invoice ${invoice.id}.pdf download initiated.',
                        intent: UiIntent.success,
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              UiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Invoice Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TradeX Inc.', style: context.uiText.heading),
                          Text('548 Market St, Suite 300', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                          Text('San Francisco, CA 94104', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                          Text('support@tradex.ai', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('INVOICE', style: context.uiText.display.copyWith(fontSize: 20)),
                          Text(invoice.id, style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                          SizedBox(height: context.sp(theme.spacing.xs)),
                          UiBadge(
                            label: invoice.status.toUpperCase(),
                            intent: invoice.status == 'paid' ? UiIntent.bullish : UiIntent.warning,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  UiDivider(),
                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Billed to and Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Billed To:', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                          Text('Nitish Kumar', style: context.uiText.bodyStrong),
                          Text('nitish@tradex.ai', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Date Issued:', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                          Text(
                            '${invoice.issuedAt.year}-${invoice.issuedAt.month.toString().padLeft(2, '0')}-${invoice.issuedAt.day.toString().padLeft(2, '0')}',
                            style: context.uiText.bodyStrong,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),

                  // Line Items Table
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: context.radius(theme.radii.md),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.surfaceHover,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.md)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 4, child: Text('Description', style: context.uiText.caption.copyWith(fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: context.uiText.caption.copyWith(fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: context.uiText.caption.copyWith(fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        ...invoice.lineItems.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(flex: 4, child: Text(item.description, style: context.uiText.body)),
                                  Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: context.uiText.body)),
                                  Expanded(flex: 2, child: Text('₹${item.amount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: context.uiText.bodyStrong)),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),

                  // Total calculation
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 260,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                              Text('₹${invoice.amount.toStringAsFixed(2)}', style: context.uiText.body),
                            ],
                          ),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('GST (18% included)', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                              Text('₹${(invoice.amount * 0.18 / 1.18).toStringAsFixed(2)}', style: context.uiText.body),
                            ],
                          ),
                          SizedBox(height: context.sp(theme.spacing.xs)),
                          UiDivider(),
                          SizedBox(height: context.sp(theme.spacing.xs)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Paid', style: context.uiText.heading),
                              Text('₹${invoice.amount.toStringAsFixed(2)} ${invoice.currency}', style: context.uiText.heading.copyWith(color: colors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xl)),

                  UiCallout(
                    title: 'Paid with Visa ending in 4242',
                    message: 'Thank you for your business. For billing inquiries contact billing@tradex.ai.',
                    intent: UiIntent.info,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
