import { allowedEndpoint, shouldSend } from './policy.ts';
function assert(value: boolean) { if (!value) throw new Error('Assertion failed'); }
Deno.test('push endpoints reject SSRF, credentials and non-provider hosts', () => {
  assert(allowedEndpoint('https://fcm.googleapis.com/fcm/send/abc'));
  for (const endpoint of ['http://fcm.googleapis.com/a', 'https://localhost/a', 'https://127.0.0.1/',
    'https://fcm.googleapis.com.evil.test/', 'https://user:pass@fcm.googleapis.com/', 'https://fcm.googleapis.com:8443/']) {
    assert(!allowedEndpoint(endpoint));
  }
});
Deno.test('category preferences and cross-midnight quiet hours are honored', () => {
  assert(!shouldSend({push_by_category: {community: false}}, 'comment', 'system', 0));
  assert(!shouldSend({push_by_category: {message: false}}, 'message', 'system', 0));
  const prefs = {quiet_hours_enabled: true, quiet_hours_start: '22:00', quiet_hours_end: '07:00'};
  assert(!shouldSend(prefs, 'message', 'message', 330, new Date('2026-11-15T18:00:00Z')));
  assert(shouldSend(prefs, 'message', 'message', 330, new Date('2026-11-15T02:00:00Z')));
  assert(shouldSend(prefs, 'message', 'message', 0, new Date('2026-11-15T07:00:00Z')));
});
