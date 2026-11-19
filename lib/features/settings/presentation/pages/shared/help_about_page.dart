import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/update/app_update.dart';
import '../../widgets/help/cookie_preferences_dialog.dart';
import '../../widgets/help/help_document_library.dart';
import '../../widgets/help/help_support_card.dart';
import '../../widgets/help/install_app_card.dart';
import '../../widgets/help/publication_reader.dart';

class HelpAboutPage extends StatelessWidget {
  const HelpAboutPage({super.key, this.submitTicket});
  final HelpTicketSubmit? submitTicket;

  @override
  Widget build(BuildContext context) => UiPage(
    title: 'Help and policies',
    subtitle:
        'Understand your workspace. Manage your choices. Find the details you need.',
    actions: [
      UiButton(
        label: 'Cookie preferences',
        variant: UiVariant.outline,
        onPressed: () => CookiePreferencesDialog.show(context),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Start here', style: context.uiText.bodyStrong),
              UiGap.v(context.ui.spacing.sm),
              Text(
                'Get practical help with your account, trading journal, privacy, subscriptions and device.',
                style: context.uiText.body,
              ),
              UiGap.v(context.ui.spacing.md),
              Wrap(
                spacing: context.sp(context.ui.spacing.sm),
                runSpacing: context.sp(context.ui.spacing.sm),
                children: [
                  UiButton(
                    label: 'Workspace guide',
                    onPressed: () =>
                        PublicationReader.open(context, 'user-guide'),
                  ),
                  UiButton(
                    label: 'Privacy and data',
                    variant: UiVariant.outline,
                    onPressed: () => PublicationReader.open(context, 'privacy'),
                  ),
                  UiButton(
                    label: 'Free plan and ads',
                    variant: UiVariant.outline,
                    onPressed: () =>
                        PublicationReader.open(context, 'advertising'),
                  ),
                  UiButton(
                    label: 'Release notes',
                    variant: UiVariant.ghost,
                    onPressed: () =>
                        PublicationReader.open(context, 'release-notes'),
                  ),
                ],
              ),
            ],
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        const InstallAppCard(),
        UiGap.v(context.ui.spacing.lg),
        const AppReleaseVersionCard(),
        UiGap.v(context.ui.spacing.lg),
        const HelpDocumentLibrary(),
        UiGap.v(context.ui.spacing.lg),
        HelpSupportCard(submitTicket: submitTicket),
        UiGap.v(context.ui.spacing.lg),
        Text(
          'AlphaJournal · Trading journals and research\nInformational tools do not replace independent investment advice.',
          style: context.uiText.caption,
        ),
        UiGap.v(context.uiDockInset),
      ],
    ),
  );
}
