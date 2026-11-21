import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/settings/data/publication_library.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';

class PublicationReader extends StatefulWidget {
  const PublicationReader({
    super.key,
    required this.documentId,
    this.embedded = false,
  });

  final String documentId;
  final bool embedded;

  static void open(BuildContext context, String id) {
    final meta = _metadataForId(id);
    showSettingsSideSheet<void>(
      context,
      title: meta.title,
      subtitle: meta.subtitle,
      desktopWidthRatio: 0.52,
      maxWidth: 780,
      minDesktopWidth: 540,
      child: PublicationReader(documentId: id, embedded: true),
    );
  }

  static ({String title, String subtitle}) _metadataForId(String id) {
    const meta = <String, ({String title, String subtitle})>{
      'privacy': (
        title: 'Privacy Policy',
        subtitle: 'Data governance, telemetry, and privacy commitments',
      ),
      'terms': (
        title: 'Terms of Service',
        subtitle: 'Platform agreement, software usage terms, and governance',
      ),
      'security': (
        title: 'Security & Compliance Architecture',
        subtitle: 'Data protection, tenant isolation, and audit controls',
      ),
      'cookies': (
        title: 'Cookie Policy',
        subtitle: 'Storage tokens, telemetry consent, and preferences',
      ),
      'consent-specification': (
        title: 'Consent Specification',
        subtitle:
            'Technical specification for user privacy and analytics consent',
      ),
      'refunds': (
        title: 'Refund & Cancellation Policy',
        subtitle: 'Billing periods, subscriptions, and refund eligibility',
      ),
      'trading-risk': (
        title: 'Trading & AI Risk Disclaimer',
        subtitle: 'Capital risk disclosure, algorithm boundaries, and notices',
      ),
      'eula': (
        title: 'End User License Agreement',
        subtitle: 'Software licensing, rights, restrictions, and updates',
      ),
      'acceptable-use': (
        title: 'Acceptable Use Policy',
        subtitle: 'Platform behavior, automated scrapers, and conduct rules',
      ),
      'community': (
        title: 'Community Guidelines',
        subtitle: 'Trader social interactions, content moderation, and ethics',
      ),
      'affiliate-agreement': (
        title: 'Affiliate Agreement',
        subtitle: 'Partnership terms, commission eligibility, and obligations',
      ),
      'affiliate-marketing': (
        title: 'Affiliate Marketing Rules',
        subtitle: 'Brand guidelines, approved promotional materials, and ads',
      ),
      'affiliate-payouts': (
        title: 'Affiliate Payout Terms',
        subtitle: 'Payment schedule, threshold, currency, and reporting',
      ),
      'account-deletion': (
        title: 'Account Deletion & Data Retention',
        subtitle: 'Data destruction lifecycle, retention windows, and backups',
      ),
      'publication-guide': (
        title: 'Publication Guide',
        subtitle: 'Document structure, versioning, and policy review cycle',
      ),
      'advertising': (
        title: 'Advertising Policy',
        subtitle:
            'Commercial sponsorships, attribution, and partner guidelines',
      ),
      'install': (
        title: 'Installation & Access Guide',
        subtitle: 'Platform setup, PWA, mobile browser, and desktop sync',
      ),
      'user-guide': (
        title: 'Platform User Guide',
        subtitle: 'Getting started, journaling, calculators, and shortcuts',
      ),
      'support': (
        title: 'Support & Escalation',
        subtitle: 'Customer help channels, response SLAs, and incident triage',
      ),
      'accessibility': (
        title: 'Accessibility Statement',
        subtitle: 'WCAG compliance, screen readers, contrast, and scaling',
      ),
      'storage-register': (
        title: 'Storage & Data Register',
        subtitle:
            'Classification of local storage, cookies, and database state',
      ),
      'implementation': (
        title: 'Technical Implementation',
        subtitle: 'Architecture overview, integrations, and runtime stack',
      ),
      'release-notes': (
        title: 'Release Notes & Changelog',
        subtitle: 'Version history, feature additions, and security updates',
      ),
    };

    final found = meta[id];
    if (found != null) return found;

    final formatted = id
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
    return (title: formatted, subtitle: 'Help & Documentation');
  }

  @override
  State<PublicationReader> createState() => _PublicationReaderState();
}

class _PublicationReaderState extends State<PublicationReader> {
  late Future<List<PublicationDocument>> _documents = PublicationLibrary.load();
  Set<int> _expanded = {0};

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go('/help');
    }
  }

  Widget _buildDocumentContent(
    BuildContext context,
    PublicationDocument document,
  ) {
    final theme = context.ui;
    final colors = context.uiColors;

    final double hPad = context.sp(theme.spacing.lg);
    final double vPad = context.sp(theme.spacing.md);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        hPad,
        (widget.embedded ? MediaQuery.paddingOf(context).top : 0.0) + vPad,
        hPad,
        vPad,
      ),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded) ...[
              UiHeader(title: document.title, subtitle: document.intro),
              UiGap.v(context.ui.spacing.md),
            ] else if (document.intro.isNotEmpty) ...[
              Text(
                document.intro,
                style: context.uiText.body.copyWith(
                  color: colors.foregroundMuted,
                  height: 1.5,
                  fontSize: 14.0,
                ),
              ),
              UiGap.v(context.ui.spacing.md),
            ],
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: context.sp(theme.spacing.sm),
              runSpacing: context.sp(theme.spacing.xs),
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: colors.foregroundMuted,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      'Updated ${document.updated}',
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
                UiBadge(
                  label: document.status.isNotEmpty
                      ? document.status
                      : 'Official',
                  intent: UiIntent.primary,
                  size: UiSize.xs,
                  variant: UiBadgeVariant.soft,
                ),
              ],
            ),
            UiGap.v(context.ui.spacing.md),
            Wrap(
              spacing: context.sp(context.ui.spacing.sm),
              runSpacing: context.sp(context.ui.spacing.xs),
              children: [
                UiButton(
                  label: 'Expand all sections',
                  variant: UiVariant.outline,
                  size: UiSize.sm,
                  onPressed: () => setState(
                    () => _expanded = Set.from(
                      List.generate(document.sections.length, (i) => i),
                    ),
                  ),
                ),
                UiButton(
                  label: 'Collapse sections',
                  variant: UiVariant.ghost,
                  size: UiSize.sm,
                  onPressed: () => setState(() => _expanded = {}),
                ),
              ],
            ),
            UiGap.v(context.ui.spacing.md),
            UiAccordion(
              allowMultiple: true,
              openIndices: _expanded,
              onChanged: (value) => setState(() => _expanded = value),
              items: [
                for (final section in document.sections)
                  UiAccordionItem(
                    title: section.title,
                    content: Text(
                      section.body,
                      style: context.uiText.body.copyWith(height: 1.6),
                    ),
                  ),
              ],
            ),
            UiGap.v(context.ui.spacing.xl),
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.md),
                border: Border.all(
                  color: colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questions or Compliance Requests',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'For compliance inquiries, data privacy requests, or formal notices, contact us at support@alphajournal.com.',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            UiGap.v(context.uiDockInset + 16.0),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<List<PublicationDocument>>(
      future: _documents,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: UiEmptyState(
              title: 'Document could not be loaded',
              actionLabel: 'Retry',
              onActionPressed: () => setState(() {
                _documents = PublicationLibrary.load();
              }),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: UiSkeleton(height: 200),
            ),
          );
        }
        final matches = snapshot.data!.where((d) => d.id == widget.documentId);
        if (matches.isEmpty) {
          return const Center(
            child: UiEmptyState(
              title: 'Document not found',
              message: 'Return to help to browse the available documents.',
            ),
          );
        }
        return _buildDocumentContent(context, matches.first);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody(context);
    }

    return UiPage(
      title: 'Help and policies',
      actions: [
        UiButton(
          label: 'Back to help',
          variant: UiVariant.outline,
          onPressed: _back,
        ),
      ],
      child: _buildBody(context),
    );
  }
}
