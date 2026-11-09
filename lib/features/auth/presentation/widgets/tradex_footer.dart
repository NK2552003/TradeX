import 'package:tradex/features/settings/presentation/widgets/help/publication_reader.dart';
import 'package:tradex/features/settings/presentation/widgets/help/cookie_preferences_dialog.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Reusable comprehensive footer for alphajournal landing and pricing pages.
///
/// Features:
/// 1. Brand column with live NSE/BSE operational status badge & social links.
/// 2. Categorized link columns with live navigation and informational dialogs.
/// 3. Bottom bar with copyright and policy quick actions.
/// 4. SEBI regulatory financial risk disclosure card.
class TradeXFooter extends StatelessWidget {
  const TradeXFooter({
    super.key,
    this.onNavigateToSection,
    this.onGetStartedTrader,
    this.onGetStartedAffiliate,
  });

  final void Function(String section)? onNavigateToSection;
  final VoidCallback? onGetStartedTrader;
  final VoidCallback? onGetStartedAffiliate;

  void _showInfoModal(
    BuildContext context, {
    required String title,
    required String category,
    required String content,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    showSettingsSideSheet<void>(
      context,
      title: title,
      subtitle: category,
      desktopWidthRatio: 0.52,
      maxWidth: 780,
      minDesktopWidth: 540,
      scrollable: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.lg),
          vertical: context.sp(theme.spacing.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            UiBadge(
              label: category,
              intent: UiIntent.primary,
              size: UiSize.xs,
              variant: UiBadgeVariant.soft,
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
            SelectableText(
              content,
              style: context.uiText.body.copyWith(
                color: colors.foreground,
                fontSize: 14.0,
                height: 1.6,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xl)),
            UiButton(
              label: 'View Complete Security Policy',
              variant: UiVariant.outline,
              onPressed: () {
                Navigator.of(context).pop();
                PublicationReader.open(context, 'security');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiDivider(),
        SizedBox(height: context.sp(theme.spacing.lg)),

        // Bottom Bar: Copyright & Quick Links
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.xl),
          ),
          child: LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints constraints) {
            final bool isMobile = constraints.maxWidth < 640;
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'AlphaJournal © ${DateTime.now().year}. All rights reserved.',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundSubtle,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Wrap(
                    spacing: context.sp(theme.spacing.md),
                    runSpacing: context.sp(theme.spacing.xs),
                    children: <Widget>[
                      _buildSmallFooterAction(
                        context,
                        'Privacy Policy',
                        () => _showPrivacyPolicy(context),
                      ),
                      _buildSmallFooterAction(
                        context,
                        'Terms of Service',
                        () => _showTerms(context),
                      ),
                      _buildSmallFooterAction(
                        context,
                        'Security & Compliance',
                        () => _showSecurity(context),
                      ),
                      _buildSmallFooterAction(
                        context,
                        'Cookie preferences',
                        () => CookiePreferencesDialog.show(context),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: context.sp(theme.spacing.md),
              runSpacing: context.sp(theme.spacing.sm),
              children: <Widget>[
                Text(
                  'AlphaJournal © ${DateTime.now().year}. All rights reserved.',
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundSubtle,
                    fontSize: 12,
                  ),
                ),
                Wrap(
                  spacing: context.sp(theme.spacing.md),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: <Widget>[
                    _buildSmallFooterAction(
                      context,
                      'Privacy Policy',
                      () => _showPrivacyPolicy(context),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    _buildSmallFooterAction(
                      context,
                      'Terms of Service',
                      () => _showTerms(context),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    _buildSmallFooterAction(
                      context,
                      'Security & Compliance',
                      () => _showSecurity(context),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    _buildSmallFooterAction(
                      context,
                      'Cookie preferences',
                      () => CookiePreferencesDialog.show(context),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      SizedBox(height: context.sp(theme.spacing.xl)),
    ],
  );
  }

  Widget _buildSmallFooterAction(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    final UiColors colors = context.uiColors;
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: context.uiText.caption.copyWith(
          color: colors.foregroundMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) =>
      PublicationReader.open(context, 'privacy');

  void _showTerms(BuildContext context) =>
      PublicationReader.open(context, 'terms');

  void _showSecurity(BuildContext context) {
    _showInfoModal(
      context,
      title: 'Security & Compliance Architecture',
      category: 'ENTERPRISE SECURITY',
      content:
          '• Data Protection: All data in transit is protected using modern TLS encryption protocols.\n\n'
          '• Tenant Isolation: Strict database Row Level Security (RLS) ensures users can only access their authorized records.\n\n'
          '• Account Privacy: Manage the visibility of your notes, strategies, and journal entries.\n\n'
          '• Zero Custody: alphajournal operates in read-only / execution-audit mode without withdrawal permissions or custody of funds.\n\n'
          '• Infrastructure: Cloud-hosted database and authentication with automated backups and continuous monitoring.',
    );
  }
}
