import { freshnessInstructions, needsFreshResearch, RESEARCH_PANEL_PROTOCOL } from './research-policy.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';
import { generateResponses, type ProviderResult } from './responses.ts';

const cors = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: cors });
type Message = { role: 'user' | 'assistant' | 'system'; content: string };
type Dependencies = { fetch?: typeof fetch; env?: (name: string) => string | undefined };

const bearer = (value: string) => String.fromCharCode(66, 101, 97, 114, 101, 114) + ' ' + value;
const validAttachment = (item: unknown): boolean => {
  if (!item || typeof item !== 'object') return false;
  const value = item as Record<string, unknown>;
  if (value.type === 'input_text') {
    return typeof value.text === 'string' && value.text.length <= 80000;
  }
  if (value.type === 'input_image') {
    return typeof value.image_url === 'string' &&
      /^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(value.image_url);
  }
  return value.type === 'input_file' &&
    typeof value.filename === 'string' &&
    value.filename.toLowerCase().endsWith('.pdf') &&
    typeof value.file_data === 'string' &&
    /^data:application\/pdf;base64,[A-Za-z0-9+/=]+$/.test(value.file_data);
};
function tokenCount(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? value : undefined;
}

async function generate(
  messages: Message[], maxTokens: number, temperature: number,
  env: (name: string) => string | undefined, send: typeof fetch,
): Promise<ProviderResult> {
  const candidates = [
    { provider: 'openrouter', key: env('OPENROUTER_API_KEY'), model: env('OPENROUTER_MODEL') || 'openrouter/free', url: 'https://openrouter.ai/api/v1/chat/completions' },
    { provider: 'gemini', key: env('GEMINI_API_KEY'), model: env('GEMINI_MODEL') || 'gemini-2.5-flash', url: '' },
    { provider: 'openai', key: env('OPENAI_API_KEY') ?? env('OPEN_AI_KEY'), model: env('OPENAI_MODEL') || 'gpt-4.1-mini', url: 'https://api.openai.com/v1/chat/completions' },
    { provider: 'openai', key: env('OPENAI_API_KEY') ?? env('OPEN_AI_KEY'), model: 'gpt-4o-mini', url: 'https://api.openai.com/v1/chat/completions' },
    { provider: 'anthropic', key: env('CLAUDE_API_KEY'), model: env('CLAUDE_MODEL') || 'claude-sonnet-4-5', url: 'https://api.anthropic.com/v1/messages' },
  ];
  for (const candidate of candidates) {
    if (!candidate.key) continue;
    try {
      let url = candidate.url;
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      let body: Record<string, unknown>;
      const system = messages.filter((m) => m.role === 'system').map((m) => m.content).join('\n');
      if (candidate.provider === 'gemini') {
        url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(candidate.model)}:generateContent`;
        headers['x-goog-api-key'] = candidate.key;
        body = {
          contents: messages.filter((m) => m.role !== 'system').map((m) => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }] })),
          systemInstruction: { parts: [{ text: system }] },
          generationConfig: { maxOutputTokens: maxTokens, temperature },
        };
      } else if (candidate.provider === 'anthropic') {
        headers['x-api-key'] = candidate.key;
        headers['anthropic-version'] = '2023-06-01';
        body = { model: candidate.model, system, messages: messages.filter((m) => m.role !== 'system'), max_tokens: maxTokens, temperature };
      } else {
        headers.Authorization = bearer(candidate.key);
        body = { model: candidate.model, messages, max_tokens: maxTokens, temperature };
      }

      const response = await send(url, { method: 'POST', headers, body: JSON.stringify(body), signal: AbortSignal.timeout(30000) });
      if (!response.ok) continue;
      const data = await response.json();
      const text = candidate.provider === 'gemini'
        ? data.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? '').join('')
        : candidate.provider === 'anthropic'
          ? data.content?.filter((p: { type: string }) => p.type === 'text').map((p: { text: string }) => p.text).join('')
          : data.choices?.[0]?.message?.content;
      if (typeof text !== 'string' || !text.trim() || text.length > 200000) continue;
      return {
        text: text.trim(), provider: candidate.provider, model: typeof data.model === 'string' ? data.model : candidate.model,
        input: tokenCount(data.usage?.prompt_tokens ?? data.usage?.input_tokens ?? data.usageMetadata?.promptTokenCount),
        output: tokenCount(data.usage?.completion_tokens ?? data.usage?.output_tokens ?? data.usageMetadata?.candidatesTokenCount),
      };
    } catch {
      // A provider outage may use another configured provider. Authorization and
      // quota errors occur before this loop and are never bypassed by fallback.
    }
  }
  throw new Error('AI providers are unavailable. Please try again later.');
}

const PERPLEXITY_FORMAT_PROTOCOL = `
Perplexity Card & Citation Response Protocol:
- Open with a concise, factual Direct Answer grounded ONLY in supplied context and verified search/tool results. Cite claims inline as [Title](https://exact-url) — NEVER fabricate URLs or live market prices.
- Enrich complex entities and research with fenced JSON blocks (\`\`\`tag ... \`\`\`) choosing only the card types that fit the user's question:
  • company (equities/crypto/ETFs): {"name","ticker","exchange","sector","price","changePercent","marketCap","pe","eps","revenue","margin","high52w","low52w","analystConsensus":{"buy":...,"hold":...,"sell":...},"highlights":[...],"risks":[...],"summary","sparkline":[...]}
  • person (executives/founders/investors): {"name","role","organization","netWorth","location","bio","highlights":[...],"tickers":["$TICKER"],"timeline":[{"date":"...","title":"...","description":"..."}],"links":[{"title":"...","url":"https://..."}]}
  • news (events/headlines): {"title","items":[{"title","publisher","publishedAt","sentiment":"bullish|bearish|neutral","summary","tickers":["$TICKER"],"url":"https://..."}]}
  • compare / bull_bear / swot / versus: {"mode":"bull_bear|swot|versus|pros_cons","title","leftTitle","rightTitle","leftItems":[...],"rightItems":[...],"strengths":[...],"weaknesses":[...],"opportunities":[...],"threats":[...],"columns":["Entity A","Entity B"],"rows":[{"criterion":"...","values":["...","..."],"winnerIndex":0}]}
  • timeline: {"title","items":[{"date","title","description","status":"done|active|upcoming","impact":"bullish|bearish|neutral"}]}
  • setup / trade_setup: {"ticker","bias":"long|short","timeframe","entry","stop","targets":[...],"riskReward","confidence","invalidation","confluences":[...]}
  • verdict / factbox / faq / checklist / quote: concise structured JSON objects ({"title","verdict","confidence","bullets"} | {"title","facts":[{"label","value"}],"description"} | {"title","items":[{"q","a"}]} | {"title","items":[...]} | {"quote","author","source","url"})
  • earnings: {"ticker","quarter","epsActual","epsEstimate","epsSurprise","revenueActual","revenueEstimate","revenueSurprise","guidance","summary","history":[{"quarter","epsActual","epsEstimate","revenueActual","revenueEstimate","beat":true}]}
  • financials: {"ticker","period":"FY24|TTM","metrics":[{"label","value","change"}],"margins":[{"label","percent"}],"rows":[{"item","value","yoy"}]}
  • macro: {"title","region","regime","indicators":[{"name","value","previous","consensus","impact":"bullish|bearish|neutral"}],"events":[{"date","event","forecast","previous","impact"}]}
  • ratings: {"ticker","consensus":"Strong Buy|Buy|Hold|Sell","targetLow","targetMedian","targetHigh","currentPrice","buyCount","holdCount","sellCount","actions":[{"firm","rating","target","date","action"}]}
  • screener: {"title","universe","columns":[...],"rows":[{"ticker","values":[...],"signal":"bullish|bearish|neutral"}]}
  • sentiment: {"ticker","score":0..100,"label","putCallRatio","shortInterest","retailFlow","institutionalFlow","drivers":[...]}
  • product / place: {"name","category","rating","price","location","summary","specs":[{"label","value"}],"pros":[...],"cons":[...],"url"}
  • media: {"title","items":[{"url","caption","source","type":"chart|image|video"}]}
  • formula / research_steps: {"title","expression","variables":[{"symbol","meaning","value"}],"example","result"} and {"steps":[{"title","detail","source"}]}
  • chart / candle / kpi / bar / line / donut / mermaid for quantitative series or workflows.
- When helpful on exploratory queries, finish with a fenced \`\`\`followups JSON array of 3-4 sharp next questions: ["Question 1?", "Question 2?", "Question 3?"].`;

const FOCUS_DIRECTIVES: Record<string, string> = {
  finance: 'Search Focus [Finance]: Prioritize equities, SEC/exchange filings, earnings, balance sheets, valuation multiples, and structured earnings/financials/ratings/company cards.',
  news: 'Search Focus [News]: Prioritize breaking market-moving headlines, official press releases, catalyst timelines, sentiment impact, and cited news/timeline cards.',
  filings: 'Search Focus [Filings]: Prioritize primary regulatory filings (10-K, 10-Q, 8-K, S-1, red-herring prospectuses, exchange disclosures), footnotes, and risk factors.',
  macro: 'Search Focus [Macro]: Prioritize central bank policy (Fed/ECB/RBI/BoJ), CPI/PCE/payrolls, yield curves, FX, commodities, and macro/timeline cards.',
  academic: 'Search Focus [Academic]: Prioritize quantitative finance studies, statistical factor models, mathematical derivations, and formula/factbox/checklist cards.',
  workspace: 'Search Focus [Workspace]: Ground the analysis first in the supplied user notes, journal records, and strategy context before adding broader synthesis.',
};

interface ExtractedCitation {
  url: string;
  title: string;
  domain: string;
}

function extractCitationsFromText(markdown: string): ExtractedCitation[] {
  const seen = new Map<string, ExtractedCitation>();
  const addUrl = (rawUrl: string, rawTitle = '') => {
    const cleanUrl = rawUrl.trim().replace(/[),.;]+$/, '');
    if (!cleanUrl) return;
    try {
      const parsed = new URL(cleanUrl);
      if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return;
      const key = parsed.toString();
      if (seen.has(key)) return;
      const domain = parsed.hostname.replace(/^www\./i, '');
      const title = rawTitle.trim() || domain;
      seen.set(key, { url: key, title, domain });
    } catch {
      // Ignore invalid URLs.
    }
  };
  for (const match of markdown.matchAll(/\[([^\]\n]{1,160})\]\((https?:\/\/[^\s)]+)\)/g)) {
    addUrl(match[2], match[1]);
  }
  for (const match of markdown.matchAll(/"url"\s*:\s*"(https?:\/\/[^"\s]+)"/g)) {
    addUrl(match[1]);
  }
  return Array.from(seen.values());
}

export async function handleRequest(request: Request, dependencies: Dependencies = {}): Promise<Response> {
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  const logger = createEdgeRequestLogger('ai-gateway', request);
  try {
    const response = await executeAiGatewayRequest(request, dependencies, logger);
    return logger.finish(response);
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(reply(500, { error: 'Unexpected gateway failure.' }));
  }
}

async function executeAiGatewayRequest(
  request: Request,
  dependencies: Dependencies,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
  if (request.method !== 'POST') return reply(405, { error: 'Method not allowed.' });
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return reply(401, { error: 'Sign in required.' });
  const env = dependencies.env ?? Deno.env.get;
  const send = dependencies.fetch ?? fetch;
  const url = env('SUPABASE_URL');
  const anonKey = env('SUPABASE_ANON_KEY');
  const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY') ?? env('SUPABASE_SECRET_KEY');
  if (!url || !anonKey || !serviceKey || !['OPENROUTER_API_KEY', 'GEMINI_API_KEY', 'OPENAI_API_KEY', 'OPEN_AI_KEY', 'CLAUDE_API_KEY'].some((key) => env(key))) {
    return reply(503, { error: 'AI service is not configured.' });
  }
  let body: Record<string, unknown>;
  try {
    const text = await request.text();
    if (text.length > 12000000) return reply(400, { error: 'Request is too large.' });
    body = JSON.parse(text);
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error();
  } catch { return reply(400, { error: 'Invalid AI request.' }); }
  const prompt = body.prompt;
  const kind = body.kind ?? 'completion';
  const persona = body.persona ?? 'swing';
  const mode = body.mode ?? 'auto';
  const focus = typeof body.focus === 'string' &&
    ['all', 'finance', 'news', 'filings', 'macro', 'academic', 'workspace'].includes(body.focus)
    ? body.focus
    : 'all';
  const attachments = Array.isArray(body.attachments) ? body.attachments : [];
  if (mode !== 'auto' && body.allow_web_search === false) {
    return reply(403, { error: 'Enable research for this workspace and specialist to use web search.' });
  }
  if (typeof prompt !== 'string' || !prompt.trim() || prompt.length > 40000 ||
    typeof kind !== 'string' || !['chat', 'regenerate', 'completion'].includes(kind) ||
    typeof persona !== 'string' || persona.length > 80 ||
    typeof mode !== 'string' || !['auto', 'search', 'research'].includes(mode) ||
    attachments.length > 4 ||
    attachments.some((item) => !validAttachment(item)) ||
    (body.thread_id != null && (typeof body.thread_id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.thread_id)))) {
    return reply(400, { error: 'Invalid prompt or conversation.' });
  }
  const messages: Message[] = [];
  if (typeof body.system_prompt === 'string' && body.system_prompt.length <= 12000) {
    messages.push({ role: 'system', content: body.system_prompt });
  } else {
    messages.push({ role: 'system', content: 'Help the user analyze their trading records. Clearly distinguish supplied facts from assumptions and do not invent market prices or performance.' });
  }
  if (typeof body.trader_skill_context === 'string' && body.trader_skill_context.length <= 8000) {
    messages[0].content += '\n' + body.trader_skill_context;
  }
  messages[0].content += '\n' + PERPLEXITY_FORMAT_PROTOCOL + '\n' + RESEARCH_PANEL_PROTOCOL + '\n' + freshnessInstructions();
  if (focus !== 'all' && FOCUS_DIRECTIVES[focus]) {
    messages[0].content += '\n' + FOCUS_DIRECTIVES[focus];
  }
  const responseStyle = body.response_style === 'concise' || body.response_style === 'detailed'
    ? body.response_style
    : 'balanced';
  if (responseStyle === 'concise') {
    messages[0].content += '\nRESPONSE DEPTH: Keep the reply concise and executive — high signal density, short bullets, and compact visual cards.';
  } else if (responseStyle === 'detailed') {
    messages[0].content += '\nRESPONSE DEPTH: Provide thorough institutional-depth analysis with comprehensive comparisons, scenarios, risks, and rich visual cards.';
  }
  if (body.citations_style === 'footnotes') {
    messages[0].content += '\nCITATIONS FORMAT: Prefer numbered footnote markers [1], [2] in prose with a markdown Sources footnote section at the end.';
  } else if (body.citations_style === 'inline') {
    messages[0].content += '\nCITATIONS FORMAT: Prefer inline clickable [Source Title](https://...) links directly alongside supported claims.';
  }
  const toolkit = body.trader_toolkit === 'selected' || body.trader_toolkit === 'auto'
    ? body.trader_toolkit : undefined;
  if (Array.isArray(body.messages)) {
    for (const message of body.messages.slice(-40)) {
      if (!message || !['user', 'assistant'].includes(message.role) || typeof message.content !== 'string' || message.content.length > 40000) {
        return reply(400, { error: 'Invalid conversation history.' });
      }
      messages.push({ role: message.role, content: message.content });
    }
  }
  if (messages.at(-1)?.role !== 'user' || messages.at(-1)?.content !== prompt) messages.push({ role: 'user', content: prompt });
  const account = createClient(url, anonKey, { global: { fetch: send, headers: { Authorization: authorization } }, auth: { autoRefreshToken: false, persistSession: false } });
  const service = createClient(url, serviceKey, { global: { fetch: send }, auth: { autoRefreshToken: false, persistSession: false } });
  const { data: user, error: authError } = await account.auth.getUser(authorization.slice(7));
  if (authError || !user.user) return reply(401, { error: 'Sign in required.' });
  const { data: reservation, error: reserveError } = await account.rpc('reserve_ai_request', {
    p_kind: kind, p_prompt: prompt.trim(), p_thread: body.thread_id ?? null, p_persona: persona,
  });
  if (reserveError) return reply(reserveError.code === '42501' ? 403 : reserveError.code === 'P0001' ? 429 : 503, { error: reserveError.message });
  if (typeof reservation?.request_id !== 'string' || reservation.user_id !== user.user.id) return reply(500, { error: 'Unable to reserve AI request.' });
  try {
    const researchedAt = new Date().toISOString();
    const openAiKey = env('OPENAI_API_KEY') ?? env('OPEN_AI_KEY');
    const result = mode !== 'auto' || attachments.length > 0 || ((body.allow_web_search === true || toolkit) && !!openAiKey)
      ? openAiKey
        ? await generateResponses(messages, attachments, mode, env('OPENAI_MODEL') || 'gpt-4o', openAiKey, send, body.allow_web_search === true, toolkit)
        : (() => { throw new Error('OpenAI is required for web search and file attachments.'); })()
      : await generate(messages,
        typeof body.max_tokens === 'number' ? Math.max(128, Math.min(4096, Math.floor(body.max_tokens))) : 3584,
        typeof body.temperature === 'number' ? Math.max(0, Math.min(1, body.temperature)) : 0.3, env, send);
    const { data: access, error: accessError } = await account.rpc('get_my_admin_access');
    if (accessError || access?.status !== 'active' || access?.features?.ai !== true) throw new Error('AI access is no longer available for this account.');
    const { error: finishError } = await service.rpc('finish_ai_request', {
      p_request: reservation.request_id, p_body: result.text, p_provider: result.provider,
      p_model: result.model, p_input_tokens: result.input ?? null, p_output_tokens: result.output ?? null,
    });
    if (finishError) throw new Error('The AI response could not be saved. Please retry.');
    logger.log('info', 'ai_generation_succeeded', {
      provider: result.provider,
      model: result.model,
      kind,
      mode,
      input_tokens: result.input,
      output_tokens: result.output,
    });
    const textSources = extractCitationsFromText(result.text);
    const mergedSources = new Map<string, ExtractedCitation>();
    for (const src of [...textSources, ...(result.toolSources ?? [])]) {
      if (src.url && !mergedSources.has(src.url)) {
        mergedSources.set(src.url, src);
      }
    }
    const sources = Array.from(mergedSources.values());
    const steps = Array.isArray(result.steps)
      ? result.steps.filter((s) => typeof s === 'string' && s.trim().length > 0)
      : [];
    return reply(200, {
      text: result.text,
      request_id: reservation.request_id,
      provider: result.provider,
      model: result.model,
      usage: reservation.usage,
      research: { requestedAt: researchedAt, timeSensitive: needsFreshResearch(prompt), webSearchUsed: result.webSearchUsed === true },
      ...(sources.length > 0 ? { sources } : {}),
      ...(steps.length > 0 ? { steps } : {}),
      ...(mode !== 'auto' ? { mode } : {}),
      ...(focus !== 'all' ? { focus } : {}),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'AI request failed.';
    logger.log('error', 'ai_generation_failed', { kind, mode, ...describeError(error) });
    await service.rpc('finish_ai_request', { p_request: reservation.request_id, p_error: message });
    return reply(503, { error: message });
  }
}

if (import.meta.main) Deno.serve((request) => handleRequest(request));
