import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/models/app_models.dart';
import 'package:tradex/features/workspace/data/workspace_post_service.dart';

void main() {
  group('WorkspacePostService', () {
    late WorkspacePostService service;

    setUp(() {
      service = WorkspacePostService.instance;
    });

    test('seeds default mock post links', () {
      expect(service.allLinks, isNotEmpty);
      expect(service.totalLinkedPosts(), greaterThanOrEqualTo(5));
      expect(service.totalLikes(), greaterThan(0));
      expect(service.totalComments(), greaterThan(0));
    });

    test('correctly identifies linked records', () {
      expect(service.isLinked(AppLinkKind.strategy, 'strat-1'), isTrue);
      expect(service.isLinked(AppLinkKind.note, 'note-1'), isTrue);
      expect(service.isLinked(AppLinkKind.journal, 'trade-1'), isTrue);
      expect(service.isLinked(AppLinkKind.note, 'non-existent-note'), isFalse);
    });

    test('can retrieve primary and all links for a record', () {
      final AppPostLinkInfo? primary =
          service.getPrimaryLink(AppLinkKind.strategy, 'strat-1');
      expect(primary, isNotNull);
      expect(primary!.postId, equals('post-101'));
      expect(primary.postTitle, contains('NVDA'));

      final List<AppPostLinkInfo> all =
          service.getLinksForRecord(AppLinkKind.strategy, 'strat-1');
      expect(all, isNotEmpty);
      expect(all.first.postId, equals('post-101'));
    });

    test('can dynamically link and unlink records', () {
      const String testRecordId = 'custom-test-note-99';
      expect(service.isLinked(AppLinkKind.note, testRecordId), isFalse);

      service.linkRecord(
        kind: AppLinkKind.note,
        recordId: testRecordId,
        postTitle: 'Dynamic Test Post',
      );

      expect(service.isLinked(AppLinkKind.note, testRecordId), isTrue);
      final AppPostLinkInfo? linked =
          service.getPrimaryLink(AppLinkKind.note, testRecordId);
      expect(linked, isNotNull);
      expect(linked!.postTitle, equals('Dynamic Test Post'));

      service.unlinkRecord(linked.postId);
      expect(service.isLinked(AppLinkKind.note, testRecordId), isFalse);
    });
  });
}
