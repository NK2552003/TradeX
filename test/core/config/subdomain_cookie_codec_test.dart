import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/config/subdomain_cookie_codec.dart';

void main() {
  test('isProductionDomain recognizes apex and subdomains only', () {
    expect(SubdomainCookieCodec.isProductionDomain('alphajournal.in'), isTrue);
    expect(
      SubdomainCookieCodec.isProductionDomain('app.alphajournal.in'),
      isTrue,
    );
    expect(
      SubdomainCookieCodec.isProductionDomain('community.alphajournal.in'),
      isTrue,
    );
    expect(
      SubdomainCookieCodec.isProductionDomain('affiliate.alphajournal.in'),
      isTrue,
    );
    expect(
      SubdomainCookieCodec.isProductionDomain('admin.alphajournal.in'),
      isTrue,
    );
    expect(SubdomainCookieCodec.isProductionDomain('localhost'), isFalse);
    expect(SubdomainCookieCodec.isProductionDomain('evil-alphajournal.in'), isFalse);
    expect(SubdomainCookieCodec.isProductionDomain('alphajournal.in.evil.com'), isFalse);
  });

  test('splits and reassembles large Supabase session JSON across cookie chunks', () {
    final fakeSession = jsonEncode({
      'access_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.${'a' * 2200}',
      'refresh_token': 'rt_${'b' * 400}',
      'expires_at': 1893456000,
      'user': {
        'id': '00000000-0000-0000-0000-000000000001',
        'email': 'trader@alphajournal.in',
        'app_metadata': {'provider': 'google'},
      },
    });

    final chunks = SubdomainCookieCodec.splitForCookies(
      fakeSession,
      maxEncodedLength: 1000,
    );
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(Uri.encodeComponent(chunk).length, lessThanOrEqualTo(1000));
    }

    final cookieHeader = [
      'ax_sb_auth.n=${chunks.length}',
      for (var i = 0; i < chunks.length; i++)
        'ax_sb_auth.$i=${Uri.encodeComponent(chunks[i])}',
      'unrelated=123',
    ].join('; ');

    final parsed = SubdomainCookieCodec.parseCookieString(cookieHeader);
    expect(SubdomainCookieCodec.readChunked(parsed, 'ax_sb_auth'), fakeSession);
  });

  test('readChunked returns null when any chunk or count is missing/invalid', () {
    expect(
      SubdomainCookieCodec.readChunked({'ax_sb_auth.n': '2', 'ax_sb_auth.0': 'a'}, 'ax_sb_auth'),
      isNull,
    );
    expect(
      SubdomainCookieCodec.readChunked({'ax_sb_auth.n': '0'}, 'ax_sb_auth'),
      isNull,
    );
    expect(
      SubdomainCookieCodec.readChunked({'ax_sb_auth.n': '999'}, 'ax_sb_auth'),
      isNull,
    );
  });

  test('formats parent-domain SameSite=Lax Secure cookies and deletes cleanly', () {
    final setDirective = SubdomainCookieCodec.formatSetCookie(
      'ax_role',
      'user1:affiliate',
      domain: '.alphajournal.in',
      maxAgeSeconds: 3600,
      secure: true,
    );
    expect(setDirective, contains('Domain=.alphajournal.in'));
    expect(setDirective, contains('Path=/'));
    expect(setDirective, contains('SameSite=Lax'));
    expect(setDirective, contains('Max-Age=3600'));
    expect(setDirective, contains('Secure'));

    final delDirective = SubdomainCookieCodec.formatDeleteCookie(
      'ax_role',
      domain: '.alphajournal.in',
      secure: true,
    );
    expect(delDirective, contains('Max-Age=0'));
    expect(delDirective, contains('Domain=.alphajournal.in'));
  });
}
