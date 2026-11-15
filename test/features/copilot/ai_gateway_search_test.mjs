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

for (const selection of ['auto', 'selected']) {
  test(`trader toolkit loads the shipped pack for ${selection} selection`, async () => {
    let uploads = 0;
    const requests = [];
    const result = await generateResponses([{role: 'user', content: 'Size my positions'}],
      [], 'auto', 'model', 'key', async (url, options) => {
        if (url.endsWith('/files')) {
          uploads++;
          const file = options.body.get('file');
          assert.equal(file.name, 'trader-skills.zip');
          const bytes = Buffer.from(await file.arrayBuffer());
          assert.equal(bytes.readUInt32LE(0), 0x04034b50);
          for (const name of ['alerts', 'analyst', 'broker', 'budget', 'copycat', 'news',
            'pelosi', 'rebalance', 'risk', 'screener', 'tax']) {
            assert.ok(bytes.includes(Buffer.from(`trader-${name}/SKILL.md`)));
          }
          return Response.json({ id: 'file-test' });
        }
        const body = JSON.parse(options.body);
        requests.push(body);
        if (selection === 'auto' && requests.length === 1) {
          assert.equal(body.tools[0].name, 'open_trader_skill');
          return Response.json({output: [{type: 'function_call', name: 'open_trader_skill',
            call_id: 'call-1', arguments: '{}'}], usage: {input_tokens: 11}});
        }
        assert.deepEqual(body.tools, [{type: 'code_interpreter', container: {type: 'auto', file_ids: ['file-test']}}]);
        if (selection === 'auto') assert.equal(body.input.at(-1).call_id, 'call-1');
        return Response.json({...answer, usage: {input_tokens: 20}});
      }, false, selection);
    assert.equal(uploads, 1);
    assert.equal(requests.length, selection === 'auto' ? 2 : 1);
    assert.equal(result.input, selection === 'auto' ? 31 : 20);
  });
}

test('extracts web search steps, code interpreter steps, and toolSources from Responses output', async () => {
  const result = await generateResponses(
    [{ role: 'user', content: 'Analyze NVDA Q4 earnings' }],
    [],
    'research',
    'gpt-4o',
    'test-key',
    async () => Response.json({
      model: 'gpt-4o',
      output: [
        { type: 'web_search_call', action: { type: 'search', query: 'NVDA Q4 earnings release' } },
        { type: 'web_search_call', action: { type: 'open_page', url: 'https://investor.nvidia.com/q4' } },
        { type: 'code_interpreter_call' },
        {
          content: [
            {
              type: 'output_text',
              text: 'Revenue beat consensus [1].',
              annotations: [
                {
                  type: 'url_citation',
                  start_index: 23,
                  end_index: 26,
                  title: 'NVIDIA IR',
                  url: 'https://investor.nvidia.com/q4',
                },
              ],
            },
          ],
        },
      ],
    }),
    true,
  );
  assert.deepEqual(result.steps, [
    'Searching "NVDA Q4 earnings release"',
    'Reading investor.nvidia.com',
    'Running quantitative Python analysis',
  ]);
  assert.equal(result.toolSources?.length, 1);
  assert.equal(result.toolSources?.[0]?.domain, 'investor.nvidia.com');
});
