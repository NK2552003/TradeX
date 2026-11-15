import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import test from 'node:test';
const source = await readFile(new URL('../../worker/index.js', import.meta.url), 'utf8');
const {default: worker} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
test('HTTP share links upgrade to HTTPS canonical subdomain before serving the app', async () => {
  const response = await worker.fetch(new Request('http://alphajournal.in/@dev_admin?public=true'), {
    ASSETS: {fetch() {throw Error('must redirect before assets');}},
  });
  assert.equal(response.status, 308);
  assert.equal(response.headers.get('location'), 'https://community.alphajournal.in/@dev_admin?public=true');
});
test('HTTPS shared links serve the application on canonical subdomains when metadata is unavailable', async () => {
  const canonicalUrls = [
    'https://community.alphajournal.in/@dev_admin',
    'https://community.alphajournal.in/p/notes/note-1',
    'https://app.alphajournal.in/notes/note-1?public=true',
    'https://community.alphajournal.in/community/post/12345678-1234-1234-1234-123456789abc',
  ];
  for (const url of canonicalUrls) {
    const response = await worker.fetch(new Request(url), {
      ASSETS: {fetch: async () => new Response('app shell')},
    });
    assert.equal(response.status, 200, url);
    assert.equal(await response.text(), 'app shell');
  }
});
