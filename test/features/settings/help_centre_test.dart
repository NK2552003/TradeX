import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/privacy/consent_preferences.dart';
import 'package:alphajournal/features/settings/data/publication_library.dart';
import 'package:alphajournal/features/settings/data/cookie_notice_content.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/help_about_page.dart';
import 'package:alphajournal/features/settings/presentation/widgets/help/cookie_preferences_dialog.dart';
import 'package:alphajournal/features/settings/presentation/widgets/help/help_issue_report_card.dart';
import 'package:alphajournal/features/settings/presentation/widgets/help/publication_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(CookieNoticeContent.load);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'all documents are bundled, searchable and contain complete sections',
    () async {
      final docs = await PublicationLibrary.load();
      expect(docs.length, 23);
      expect(docs.map((d) => d.id).toSet().length, 23);
      expect(docs.every((d) => d.sections.length >= 5), true);
      expect(
        docs.singleWhere((d) => d.id == 'cookies').matches('Google AdSense'),
        true,
      );
      expect(docs.singleWhere((d) => d.id == 'privacy').status, 'Policy');
    },
  );

  testWidgets('mobile help searches full text and opens a complete document', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => PublicationLibrary.load());
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HelpAboutPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Help and policies'), findsOneWidget);

    final search = find.byType(TextField).first;
    await tester.ensureVisible(search);
    await tester.enterText(search, 'seven-day cooldown');
    await tester.pumpAndSettle();
    expect(find.textContaining('Consent Advertising'), findsOneWidget);
    final read = find.textContaining('Consent Advertising');
    await tester.ensureVisible(read);
    await tester.tap(read);
    await tester.pumpAndSettle();
    expect(find.byType(PublicationReader), findsOneWidget);
    expect(find.text('Architecture'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'granular consent saves and rejecting advertising clears personalisation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ConsentController();
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => UiButton(
                label: 'Preferences',
                onPressed: () => CookiePreferencesDialog.show(
                  context,
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Preferences'));
      await tester.pumpAndSettle();
      Future<void> toggle(String label) async {
        final control = find.byWidgetPredicate(
          (w) => w is UiSwitch && w.label == label,
        );
        await tester.ensureVisible(control);
        await tester.tap(
          find
              .descendant(of: control, matching: find.byType(UiInteractive))
              .first,
        );
        await tester.pumpAndSettle();
      }

      await toggle('Advertising');
      await toggle('Personalised ads');
      await toggle('Advertising');
      await toggle('Analytics');
      final save = find.text('Save choices');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(controller.value.analytics, true);
      expect(controller.value.advertising, false);
      expect(controller.value.personalizedAds, false);
      expect(find.byType(CookiePreferencesDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final action in ['Accept optional', 'Reject optional']) {
    testWidgets('$action persists through the real notice buttons', (
      tester,
    ) async {
      final controller = ConsentController();
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => UiButton(
                label: 'Open notice',
                onPressed: () => CookiePreferencesDialog.show(
                  context,
                  controller: controller,
                  manage: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open notice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      final restored = ConsentController();
      await restored.initialize();
      final accepted = action == 'Accept optional';
      expect(restored.needsChoice, false);
      expect(restored.value.analytics, accepted);
      expect(restored.value.advertising, accepted);
      expect(restored.value.personalizedAds, accepted);
      expect(restored.value.affiliate, accepted);
    });
  }

  testWidgets('closing the notice does not accept optional tracking', (
    tester,
  ) async {
    final controller = ConsentController();
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => UiButton(
              label: 'Open notice',
              onPressed: () => CookiePreferencesDialog.show(
                context,
                controller: controller,
                manage: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open notice'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is UiIconButton && w.tooltip == 'Close'),
    );
    await tester.pumpAndSettle();
    expect(controller.needsChoice, true);
    expect(controller.value.advertising, false);
  });

  testWidgets(
    'cookie sheet adapts on resize and Back restores saved category states',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 850);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ConsentController();
      await controller.save(const ConsentPreferences(analytics: true));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => UiButton(
              label: 'Preferences',
              onPressed: () => CookiePreferencesDialog.show(
                context,
                controller: controller,
                manage: false,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Preferences'));
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('ui-dialog-surface'));
      expect(tester.getCenter(panel).dx, closeTo(640, .01));
      expect(find.text('On'), findsOneWidget);
      for (final size in [
        const Size(320, 600),
        const Size(844, 390),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width == 320) {
          expect(tester.getBottomLeft(panel).dy, closeTo(size.height, .01));
        }
        await tester.ensureVisible(find.text('Manage choices'));
        await tester.tap(find.text('Manage choices'));
        await tester.pumpAndSettle();
        final analytics = find.byWidgetPredicate(
          (w) => w is UiSwitch && w.label == 'Analytics',
        );
        expect(tester.widget<UiSwitch>(analytics).value, isTrue);
        final switchTarget = find
            .descendant(of: analytics, matching: find.byType(UiInteractive))
            .first;
        await Scrollable.ensureVisible(
          tester.element(switchTarget),
          alignment: .5,
        );
        await tester.tap(switchTarget);
        await tester.pumpAndSettle();
        expect(tester.widget<UiSwitch>(analytics).value, isFalse);
        final back = find.byWidgetPredicate(
          (w) => w is UiIconButton && w.tooltip == 'Back to overview',
        );
        await tester.ensureVisible(back);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.text('On'), findsOneWidget);
        expect(controller.value.analytics, isTrue);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('full-width title rows remain readable with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => PublicationLibrary.load());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(body: HelpAboutPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Policy draft'), findsNothing);
    expect(find.text('Read Privacy Policy'), findsNothing);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Help & Support buttons and Cookie dialog action buttons are full width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => PublicationLibrary.load());

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HelpAboutPage())),
      );
      await tester.pumpAndSettle();

      // Every action button on HelpAboutPage (including Cookie preferences) is full width.
      for (final String label in <String>[
        'Cookie preferences',
        'Workspace guide',
        'Privacy and data',
        'Free plan and ads',
        'Release notes',
        'Installation guide',
        'Report a bug or issue',
        'Request a feature',
        'Report a security vulnerability',
        'Browse all issue templates',
        'Email support',
        'Copy email address',
      ]) {
        final Finder buttonFinder = find.byWidgetPredicate(
          (Widget w) => w is UiButton && w.label == label,
        );
        expect(buttonFinder, findsOneWidget, reason: 'Missing button: $label');
        expect(
          tester.widget<UiButton>(buttonFinder).expand,
          isTrue,
          reason: '$label must expand to full width',
        );
      }

      // Cookie preferences button spans the full content width of the Help page.
      final Finder cookieBtn = find.byWidgetPredicate(
        (Widget w) => w is UiButton && w.label == 'Cookie preferences',
      );
      final double cookieWidth = tester.getSize(cookieBtn).width;
      expect(cookieWidth, greaterThan(340));

      // Open CookiePreferencesDialog and verify all three action buttons are full width.
      await tester.tap(cookieBtn);
      await tester.pumpAndSettle();

      final List<double> dialogButtonWidths = <double>[];
      for (final String label in <String>[
        'Reject optional',
        'Accept optional',
        'Save choices',
      ]) {
        final Finder btn = find.byWidgetPredicate(
          (Widget w) => w is UiButton && w.label == label,
        );
        expect(btn, findsOneWidget, reason: 'Missing cookie button: $label');
        expect(tester.widget<UiButton>(btn).expand, isTrue);
        dialogButtonWidths.add(tester.getSize(btn).width);
      }
      expect(
        (dialogButtonWidths[0] - dialogButtonWidths[1]).abs(),
        lessThan(0.5),
      );
      expect(
        (dialogButtonWidths[1] - dialogButtonWidths[2]).abs(),
        lessThan(0.5),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Report a bug or issue validates input, blocks secrets, routes public issues and private security advisories',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => PublicationLibrary.load());

      final List<Uri> launched = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HelpAboutPage(
              onLaunchIssueUrl: (Uri uri) async {
                launched.add(uri);
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder reportBtn = find.byWidgetPredicate(
        (Widget w) => w is UiButton && w.label == 'Report a bug or issue',
      );
      await tester.ensureVisible(reportBtn);
      await tester.tap(reportBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ReportIssueDialog), findsOneWidget);

      // Submitting empty fields shows validation warning without launching a URL.
      final Finder githubSubmit = find.byKey(
        const ValueKey<String>('report-issue-github-submit'),
      );
      await tester.ensureVisible(githubSubmit);
      await tester.tap(githubSubmit);
      await tester.pumpAndSettle();
      expect(launched, isEmpty);
      expect(
        find.textContaining('Please enter a concise summary'),
        findsOneWidget,
      );

      // Entering a secret token blocks public GitHub submission.
      await tester.enterText(
        find.byKey(const ValueKey<String>('report-issue-summary')),
        'Login fails with token',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('report-issue-details')),
        'Header was Bearer superSecretToken1234567890',
      );
      await tester.ensureVisible(githubSubmit);
      await tester.tap(githubSubmit);
      await tester.pumpAndSettle();
      expect(launched, isEmpty);
      expect(
        find.textContaining('Possible secret, token, or password detected'),
        findsOneWidget,
      );

      // Sanitized bug report opens GitHub issue with bug.yml template and sanitized environment.
      await tester.enterText(
        find.byKey(const ValueKey<String>('report-issue-summary')),
        'Workspace calendar overlaps on small screens',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('report-issue-details')),
        '1. Open Workspace\n2. Tap Month view',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('report-issue-expected')),
        'Calendar fits cleanly without clipping',
      );
      await tester.ensureVisible(githubSubmit);
      await tester.tap(githubSubmit);
      await tester.pumpAndSettle();

      expect(launched, hasLength(1));
      final Uri bugUri = launched.single;
      expect(bugUri.host, 'github.com');
      expect(bugUri.path, '/NK2552003/TradeX/issues/new');
      expect(bugUri.queryParameters['template'], 'bug.yml');
      expect(
        bugUri.queryParameters['title'],
        '[Bug]: Workspace calendar overlaps on small screens',
      );
      expect(
        bugUri.queryParameters['steps'],
        contains('1. Open Workspace'),
      );
      expect(bugUri.queryParameters['environment'], contains('Mobile'));

      // Close dialog and test private security vulnerability routing.
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is UiIconButton && w.tooltip == 'Close'),
      );
      await tester.pumpAndSettle();

      final Finder securityBtn = find.byWidgetPredicate(
        (Widget w) => w is UiButton && w.label == 'Report a security vulnerability',
      );
      await tester.ensureVisible(securityBtn);
      await tester.tap(securityBtn);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('report-issue-github-submit')),
        findsNothing,
      );
      final Finder advisoryBtn = find.byKey(
        const ValueKey<String>('report-issue-security-submit'),
      );
      expect(advisoryBtn, findsOneWidget);
      await tester.ensureVisible(advisoryBtn);
      await tester.tap(advisoryBtn);
      await tester.pumpAndSettle();

      expect(launched, hasLength(2));
      expect(
        launched.last.toString(),
        'https://github.com/NK2552003/TradeX/security/advisories/new',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
