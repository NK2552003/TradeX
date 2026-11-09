import assert from 'node:assert/strict';
import test from 'node:test';
import { generateResponses } from '../../../supabase/functions/ai-gateway/responses.ts';

const messages = [{ role: 'user', content: 'Find current market news.' }];
const answer = { output: [{ content: [{ type: 'output_text', text: 'Market news.' }] }], model: 'gpt-4o' };
for (const mode of ['auto', 'search', 'research']) {
  test(`${mode} enables the real search tool with gpt-4o`, async () => {
    let sent;
    const result = await generateResponses(messages, [], mode, 'gpt-4o', 'test-key', async (url, options) => {
      assert.equal(url, 'https://api.openai.com/v1/responses');
      sent = JSON.parse(options.body);
      return Response.json(answer);
    }, true);
    assert.equal(sent.model, 'gpt-4o');
    assert.equal(sent.tools[0].type, 'web_search');
    assert.equal(sent.tool_choice?.type, mode === 'auto' ? undefined : 'web_search');
    assert.equal(sent.tools[0].search_context_size, mode === 'research' ? 'high' : undefined);
    assert.equal(result.text, 'Market news.');
  });
}
test('Auto without research permission exposes no search tool', async () => {
  await generateResponses(messages, [], 'auto', 'gpt-4o', 'test-key', async (_, options) => {
    assert.deepEqual(JSON.parse(options.body).tools, []);
    return Response.json(answer);
  }, false);
});
test('search citations become clickable source links', async () => {
  const result = await generateResponses(messages, [], 'search', 'gpt-4o', 'test-key', async () => Response.json({
    output: [{ content: [{ type: 'output_text', text: 'News [1].', annotations: [
      { type: 'url_citation', start_index: 5, end_index: 8, title: 'Source', url: 'https://example.com/news' },
    ] }] }],
  }));
  assert.equal(result.text, 'News [Source](https://example.com/news).');
});
for (const [status, code, message] of [
  [401, 'invalid_api_key', /key.*invalid/],
  [429, 'insufficient_quota', /quota/],
  [429, 'rate_limit_exceeded', /rate limiting/],
  [404, 'model_not_found', /model permissions/],
]) {
  test(`provider ${code} gives actionable feedback without leaking provider payload`, async () => {
    await assert.rejects(generateResponses(messages, [], 'search', 'gpt-4o', 'test-key', async () =>
      Response.json({ error: { code, message: 'sensitive provider details' } }, { status })), message);
  });
}
