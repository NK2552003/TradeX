import assert from 'node:assert/strict';
import {
  allowedCorsOrigin,
  corsPreflightResponse,
  withCorsHeaders,
} from './cors.ts';

Deno.test('CORS reflects only approved AlphaJournal origins', () => {
  for (const origin of [
    'https://alphajournal.in',
    'https://app.alphajournal.in',
    'https://community.alphajournal.in',
    'http://localhost:7357',
  ]) {
    const request = new Request('https://project.supabase.co/functions/v1/test', {
      method: 'OPTIONS',
      headers: { origin },
    });
    assert.equal(allowedCorsOrigin(request), origin);
    assert.equal(
      corsPreflightResponse(request).headers.get('access-control-allow-origin'),
      origin,
    );
  }
});

Deno.test('CORS removes wildcard access for unapproved origins', () => {
  const request = new Request('https://project.supabase.co/functions/v1/test', {
    headers: { origin: 'https://attacker.invalid' },
  });
  const response = withCorsHeaders(
    request,
    new Response('{}', {
      headers: { 'Access-Control-Allow-Origin': '*' },
    }),
  );
  assert.equal(allowedCorsOrigin(request), null);
  assert.equal(response.headers.get('access-control-allow-origin'), null);
  assert.match(response.headers.get('vary') ?? '', /Origin/i);
});

Deno.test('non-browser clients remain supported without an Origin header', () => {
  const request = new Request('https://project.supabase.co/functions/v1/test');
  const response = withCorsHeaders(request, new Response('{}'));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('access-control-allow-origin'), null);
});
