import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/core/navigation/customer_routes.dart';
import 'package:alphajournal/core/navigation/share_links.dart';

void main() {
  test('every public share URL opens the exact record in both URL codecs', () {
    for (final kind in [
      AppLinkKind.note,
      AppLinkKind.journal,
      AppLinkKind.strategy,
      AppLinkKind.communityPost,
      AppLinkKind.ticker,
    ]) {
      final ref = AppLinkRef(
        kind: kind,
        id: 'id / with & symbols',
        title: 'Record',
        isPublicContext: true,
      );
      final uri = Uri.parse(AppShareLinks.record(ref));
      for (final path in [uri, Uri.parse('${uri.path}?public=true')]) {
        final route = CustomerRoute.parse(path);
        expect(route.valid, isTrue);
        expect(route.request!.id, ref.id);
        expect(route.request!.kind, kind);
        expect(route.request!.publicContext, isTrue);
      }
      final parsed = AppDeepLink.tryParseUrl(uri.toString())!;
      expect(parsed.id, ref.id);
      expect(parsed.kind, kind);
      expect(parsed.isPublicContext, isTrue);
    }
  });

  test(
    'previously copied links remain public and preserve record identifiers',
    () {
      final paths = {
        '/p/notes/note-1': AppLinkKind.note,
        '/p/journal/trade-1': AppLinkKind.journal,
        '/p/strategies/strategy-1': AppLinkKind.strategy,
        '/community/note/note-1': AppLinkKind.note,
        '/community/journal/trade-1': AppLinkKind.journal,
        '/community/strategy/strategy-1': AppLinkKind.strategy,
        '/p/post-1': AppLinkKind.communityPost,
        '/p/post/post-1': AppLinkKind.communityPost,
        '/community/post/post-1': AppLinkKind.communityPost,
      };
      for (final entry in paths.entries) {
        for (final prefix in [
          '',
          'https://alphajournal.in',
          'http://alphajournal.in',
        ]) {
          final route = CustomerRoute.parse(Uri.parse('$prefix${entry.key}'));
          expect(route.valid, isTrue, reason: '$prefix${entry.key}');
          expect(route.request!.kind, entry.value);
          expect(route.request!.id, entry.key.split('/').last);
          expect(route.request!.publicContext, isTrue);
        }
      }
    },
  );

  test('profile handle survives URL encoding and sign-in return', () {
    for (final path in [
      '/@dev_admin',
      '/%40dev_admin',
      AppShareLinks.profile('@dev_admin'),
    ]) {
      final route = CustomerRoute.parse(Uri.parse(path));
      expect(route.destination, 'public_profile');
      expect(route.profileHandle, 'dev_admin');
    }
    final login = Uri(
      path: '/auth/login',
      queryParameters: {'next': '/@dev_admin'},
    );
    expect(CustomerRoute.parse(login).profileHandle, 'dev_admin');
    expect(CustomerRoute.afterAuthentication(login)!.$1.path, '/@dev_admin');
    expect(
      AppShareLinks.referral('ref code'),
      'https://alphajournal.in/r/ref%20code',
    );
    expect(
      AppShareLinks.profile('@dev_admin'),
      'https://community.alphajournal.in/@dev_admin',
    );
    expect(
      AppShareLinks.record(
        const AppLinkRef(
          kind: AppLinkKind.communityPost,
          id: 'abc',
          title: 'Post',
        ),
      ),
      'https://community.alphajournal.in/community/post/abc?public=true',
    );
    expect(
      AppShareLinks.record(
        const AppLinkRef(kind: AppLinkKind.journal, id: 'j-1', title: 'Trade'),
      ),
      'https://app.alphajournal.in/journal/j-1',
    );
  });

  test(
    'destinationUrl and displayHostAndPath resolve canonical subdomains',
    () {
      expect(
        AppShareLinks.destinationUrl('calculators'),
        'https://app.alphajournal.in/calculators',
      );
      expect(
        AppShareLinks.destinationUrl('community_feed'),
        'https://community.alphajournal.in/community_feed',
      );
      expect(
        AppShareLinks.destinationUrl('affiliate_application'),
        'https://affiliate.alphajournal.in/affiliate_application',
      );
      expect(
        AppShareLinks.displayHostAndPath(
          'https://community.alphajournal.in/community/post/p-1?public=true',
        ),
        'community.alphajournal.in/community/post/p-1',
      );
    },
  );

  test('malformed profile and extra record segments are rejected', () {
    for (final path in [
      '/@',
      '/@bad%2Fhandle',
      '/@bad,handle',
      '/community/post/id/extra',
      '/p/notes/id/extra',
    ]) {
      expect(CustomerRoute.parse(Uri.parse(path)).valid, isFalse, reason: path);
    }
  });
}
