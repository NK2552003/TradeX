import test from 'node:test';
import assert from 'node:assert/strict';
import {
  canonicalSubdomainHost,
  isAlphajournalHost,
  resolveRedirectUrl,
} from '../worker/index.js';

test('recognizes apex and subdomains', () => {
  assert.equal(isAlphajournalHost('alphajournal.in'), true);
  assert.equal(isAlphajournalHost('app.alphajournal.in'), true);
  assert.equal(isAlphajournalHost('community.alphajournal.in'), true);
  assert.equal(isAlphajournalHost('affiliate.alphajournal.in'), true);
  assert.equal(isAlphajournalHost('admin.alphajournal.in'), true);
  assert.equal(isAlphajournalHost('localhost'), false);
  assert.equal(isAlphajournalHost('alphajournal.pages.dev'), false);
});

test('upgrades http and canonicalizes www to apex', () => {
  assert.equal(
    resolveRedirectUrl('http://alphajournal.in/auth/login'),
    'https://alphajournal.in/auth/login',
  );
  assert.equal(
    resolveRedirectUrl('https://www.alphajournal.in/r/CODE123?utm_campaign=fall'),
    'https://alphajournal.in/r/CODE123?utm_campaign=fall',
  );
});

test('canonicalizes community, affiliate, admin, and app routes', () => {
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/community_feed'),
    'https://community.alphajournal.in/community_feed',
  );
  assert.equal(
    resolveRedirectUrl(
      'https://app.alphajournal.in/community/post/12345678-1234-1234-1234-1234567890ab?public=true',
    ),
    'https://community.alphajournal.in/community/post/12345678-1234-1234-1234-1234567890ab?public=true',
  );
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/@nitish'),
    'https://community.alphajournal.in/@nitish',
  );
  assert.equal(
    resolveRedirectUrl('https://community.alphajournal.in/community_explore'),
    null,
  );
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/affiliate_application'),
    'https://affiliate.alphajournal.in/affiliate_application',
  );
  assert.equal(
    resolveRedirectUrl('https://app.alphajournal.in/referrals'),
    'https://affiliate.alphajournal.in/referrals',
  );
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/admin_console'),
    'https://admin.alphajournal.in/admin_console',
  );
  assert.equal(
    resolveRedirectUrl('https://affiliate.alphajournal.in/affiliate_reviews'),
    'https://admin.alphajournal.in/affiliate_reviews',
  );
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/workspace'),
    'https://app.alphajournal.in/workspace',
  );
  assert.equal(
    resolveRedirectUrl('https://community.alphajournal.in/messages'),
    'https://app.alphajournal.in/messages',
  );
});

test('preserves static assets, auth callbacks, referral links, root, and preview', () => {
  for (const url of [
    'https://alphajournal.in/',
    'https://alphajournal.in/auth/login?next=/workspace',
    'https://alphajournal.in/r/TRADER50',
    'https://alphajournal.in/join/TRADER50',
    'https://alphajournal.in/help/privacy',
    'https://app.alphajournal.in/flutter_bootstrap.js',
    'https://community.alphajournal.in/assets/AssetManifest.json',
    'https://community.alphajournal.in/icons/Icon-512.png',
    'https://alphajournal.in/community_feed?preview=customer',
    'http://localhost:8080/workspace',
  ]) {
    assert.equal(resolveRedirectUrl(url), null, url);
  }
  assert.equal(canonicalSubdomainHost(new URL('https://alphajournal.in/journal')), 'app.alphajournal.in');
});
