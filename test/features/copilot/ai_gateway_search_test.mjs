import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildProviderMessages,
  parseDataUrl,
  validAttachment,
} from '../../../supabase/functions/ai-gateway/attachments.ts';
import { freshnessInstructions, needsFreshResearch } from '../../../supabase/functions/ai-gateway/research-policy.ts';
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
    assert.equal(sent.tool_choice?.type, 'web_search');
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


test('freshness clock uses the supplied request time across year boundaries', () => {
  const policy = freshnessInstructions(new Date('2027-01-01T00:01:00Z'));
  assert.match(policy, /2027-01-01T00:01:00.000Z/);
  assert.match(policy, /publication date, event date, and underlying data period/);
  assert.match(policy, /current information could not be verified/);
});

test('time-sensitive prompts force live search in Auto but conceptual questions do not', async () => {
  for (const [prompt, required] of [
    ["What is the latest RBI decision today?", true],
    ["Check current AAPL price", true],
    ["Explain compound interest", false],
  ]) {
    assert.equal(needsFreshResearch(prompt), required);
    await generateResponses([{role: 'user', content: prompt}], [], 'auto', 'model', 'test-key', async (_, options) => {
      const request = JSON.parse(options.body);
      assert.equal(request.tool_choice?.type, required ? 'web_search' : undefined);
      assert.equal(request.tools[0].external_web_access, true);
      assert.match(request.instructions, /CURRENT RESEARCH CLOCK:/);
      return Response.json(answer);
    }, true);
  }
});

test('latest requests cannot override disabled search', async () => {
  await generateResponses([{role: 'user', content: 'latest news today'}], [], 'auto', 'model', 'test-key', async (_, options) => {
    const request = JSON.parse(options.body);
    assert.deepEqual(request.tools, []);
    assert.equal(request.tool_choice, undefined);
    assert.match(request.instructions, /If live tools are unavailable/);
    return Response.json(answer);
  }, false);
});

test('validAttachment accepts data images (png/jpeg/webp/gif), https image URLs, PDFs, and bounded text', () => {
  assert.equal(validAttachment({ type: 'input_image', image_url: 'data:image/gif;base64,R0lGODlhAQABAAAAACw=' }), true);
  assert.equal(validAttachment({ type: 'input_image', image_url: 'data:image/webp;base64,AAAA' }), true);
  assert.equal(validAttachment({ type: 'input_image', image_url: 'https://charts.example.com/nvda.png' }), true);
  assert.equal(validAttachment({ type: 'input_image', image_url: 'http://insecure.example.com/a.png' }), false);
  assert.equal(
    validAttachment({ type: 'input_file', filename: '10k.pdf', file_data: 'data:application/pdf;base64,JVBERi0x' }),
    true,
  );
  assert.equal(validAttachment({ type: 'input_text', text: 'AAPL,185.2' }), true);
  assert.deepEqual(parseDataUrl('data:image/png;base64,QUJD'), { mimeType: 'image/png', data: 'QUJD' });
});

test('buildProviderMessages formats multimodal attachments for Gemini, Anthropic, and OpenAI/OpenRouter', () => {
  const history = [
    { role: 'system', content: 'You are TradeX Copilot.' },
    { role: 'user', content: 'Analyze this chart and PDF' },
  ];
  const atts = [
    { type: 'input_image', image_url: 'data:image/png;base64,QUJD' },
    { type: 'input_image', image_url: 'https://cdn.example.com/setup.png' },
    { type: 'input_file', filename: 'report.pdf', file_data: 'data:application/pdf;base64,UERGFQ==' },
    { type: 'input_text', text: 'Ticker: NVDA' },
  ];

  const gemini = buildProviderMessages('gemini', history, atts);
  assert.equal(gemini.length, 1);
  assert.equal(gemini[0].role, 'user');
  assert.deepEqual(gemini[0].parts[1], { inlineData: { mimeType: 'image/png', data: 'QUJD' } });
  assert.equal(gemini[0].parts[2].text, 'Image URL: https://cdn.example.com/setup.png');
  assert.deepEqual(gemini[0].parts[3], { inlineData: { mimeType: 'application/pdf', data: 'UERGFQ==' } });
  assert.equal(gemini[0].parts[4].text, 'Ticker: NVDA');

  const claude = buildProviderMessages('anthropic', history, atts);
  assert.equal(claude.length, 1);
  assert.equal(claude[0].content[1].type, 'image');
  assert.equal(claude[0].content[1].source.type, 'base64');
  assert.equal(claude[0].content[2].source.type, 'url');
  assert.equal(claude[0].content[3].type, 'document');
  assert.equal(claude[0].content[4].text, 'Ticker: NVDA');

  const openai = buildProviderMessages('openrouter', history, atts);
  assert.equal(openai.length, 2);
  assert.equal(openai[1].content[1].type, 'image_url');
  assert.equal(openai[1].content[2].image_url.url, 'https://cdn.example.com/setup.png');
  assert.match(openai[1].content[3].text, /report\.pdf/);
});
