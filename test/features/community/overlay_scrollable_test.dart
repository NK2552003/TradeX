import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

void main() {
  late CommunityRepository repo;

  setUp(() {
    repo = CommunityRepository();
  });

  tearDown(() {
    repo.dispose();
  });

  testWidgets('overlay side sheet is scrollable and does not overflow in Trade Setup mode',
      (WidgetTester tester) async {
    // Set a constrained desktop viewport height (e.g. 700px height like on a laptop screen)
    tester.view.physicalSize = const Size(1280, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final author = CommunityAuthor(
      id: 'nk2552003',
      displayName: 'nk2552003',
      handle: '@nk2552003', // Already has leading @
      userRole: UserRole.customer,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showSettingsSideSheet<void>(
                  context,
                  title: 'Create Post',
                  subtitle: 'Share your thesis, trade setup, or questions with traders',
                  desktopWidthRatio: 0.52,
                  maxWidth: 720,
                  minDesktopWidth: 540,
                  scrollable: true,
                  child: CommunityComposerCard(
                    author: author,
                    repository: repo,
                    initialMode: ComposerMode.tradeSetup,
                  ),
                );
              },
              child: const Text('Open Overlay'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open overlay
    await tester.tap(find.text('Open Overlay'));
    await tester.pumpAndSettle();

    // Verify overlay header is rendered
    expect(find.text('Create Post'), findsOneWidget);

    // Verify handle strips duplicate @ so it shows @nk2552003 and not @@nk2552003
    expect(find.text('@nk2552003'), findsOneWidget);
    expect(find.text('@@nk2552003'), findsNothing);

    // Verify that Trade Setup controls are present inside the overlay
    expect(find.text('Professional Financial Setup'), findsOneWidget);
    expect(find.text('Candlestick data (optional)'), findsOneWidget);

    // Verify no RenderFlex overflow was thrown
    expect(tester.takeException(), isNull);

    // Verify Scrollbar and SingleChildScrollView exist inside the overlay
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.byType(Scrollbar), findsWidgets);

    // Scroll down to the bottom
    await tester.drag(find.text('Professional Financial Setup'), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Verify bottom action button is reachable
    expect(find.text('Publish Setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
