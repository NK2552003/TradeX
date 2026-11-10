import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/views/shared_profile_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

void main() {
  testWidgets(
    'shared handle loads that author rather than the viewer profile',
    (tester) async {
      final repo = CommunityRepository();
      addTearDown(repo.dispose);
      final author = repo.suggestedTraders.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharedProfilePage(
              handle: author.cleanHandle,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final profile = tester.widget<TraderProfilePreviewPage>(
        find.byType(TraderProfilePreviewPage),
      );
      expect(profile.author!.id, author.id);
      expect(profile.forceTraderView, isTrue);
      expect(profile.isCurrentUser, isFalse);
    },
  );
  testWidgets(
    'missing shared handle shows not found rather than another profile',
    (tester) async {
      final repo = CommunityRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharedProfilePage(
              handle: 'missing_shared_profile',
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profile not found'), findsOneWidget);
      expect(find.byType(TraderProfilePreviewPage), findsNothing);
    },
  );
}
