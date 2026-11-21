import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/update/app_update.dart';
import '../../widgets/help/cookie_preferences_dialog.dart';
import '../../widgets/help/help_document_library.dart';
import '../../widgets/help/help_issue_report_card.dart';
import '../../widgets/help/help_support_card.dart';
import '../../widgets/help/install_app_card.dart';
import '../../widgets/help/publication_reader.dart';

class HelpAboutPage extends StatelessWidget {
  const HelpAboutPage({super.key, this.submitTicket, this.onLaunchIssueUrl});
  final HelpTicketSubmit? submitTicket;
  final HelpIssueUrlLauncher? onLaunchIssueUrl;

  @override
  Widget build(BuildContext context) {
    final UiSpacing spacing = context.ui.spacing;
    return UiPage(
      title: 'Help and policies',
      subtitle:
          'Understand your workspace. Manage your choices. Find the details you need.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiButton(
            label: 'Cookie preferences',
            leadingIcon: Icons.cookie_outlined,
            variant: UiVariant.outline,
            expand: true,
            onPressed: () => CookiePreferencesDialog.show(context),
          ),
          UiGap.v(spacing.lg),
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Start here', style: context.uiText.bodyStrong),
                UiGap.v(spacing.sm),
                Text(
                  'Get practical help with your account, trading journal, privacy, subscriptions and device.',
                  style: context.uiText.body,
                ),
                UiGap.v(spacing.md),
                UiButton(
                  label: 'Workspace guide',
                  expand: true,
                  onPressed: () =>
                      PublicationReader.open(context, 'user-guide'),
                ),
                UiGap.v(spacing.sm),
                UiButton(
                  label: 'Privacy and data',
                  variant: UiVariant.outline,
                  expand: true,
                  onPressed: () => PublicationReader.open(context, 'privacy'),
                ),
                UiGap.v(spacing.sm),
                UiButton(
                  label: 'Free plan and ads',
                  variant: UiVariant.outline,
                  expand: true,
                  onPressed: () =>
                      PublicationReader.open(context, 'advertising'),
                ),
                UiGap.v(spacing.sm),
                UiButton(
                  label: 'Release notes',
                  variant: UiVariant.ghost,
                  expand: true,
                  onPressed: () =>
                      PublicationReader.open(context, 'release-notes'),
                ),
              ],
            ),
          ),
          UiGap.v(spacing.lg),
          const InstallAppCard(),
          UiGap.v(spacing.lg),
          const AppReleaseVersionCard(),
          UiGap.v(spacing.lg),
          const HelpDocumentLibrary(),
          UiGap.v(spacing.lg),
          HelpIssueReportCard(onLaunchUrl: onLaunchIssueUrl),
          UiGap.v(spacing.lg),
          HelpSupportCard(submitTicket: submitTicket),
          UiGap.v(spacing.lg),
          Text(
            'AlphaJournal · Trading journals and research\nInformational tools do not replace independent investment advice.',
            style: context.uiText.caption,
          ),
          UiGap.v(context.uiDockInset),
        ],
      ),
    );
  }
}
