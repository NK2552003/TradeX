import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { generateResponses } from './responses.ts';

const cors = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: cors });
type Message = { role: 'user' | 'assistant' | 'system'; content: string };
type ProviderResult = { text: string; provider: string; model: string; input?: number; output?: number };
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

export async function handleRequest(request: Request, dependencies: Dependencies = {}): Promise<Response> {
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
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
    const openAiKey = env('OPENAI_API_KEY') ?? env('OPEN_AI_KEY');
    const result = mode !== 'auto' || attachments.length > 0 || (body.allow_web_search === true && !!openAiKey)
      ? openAiKey
        ? await generateResponses(messages, attachments, mode, env('OPENAI_MODEL') || 'gpt-5.4', openAiKey, send, body.allow_web_search === true)
        : (() => { throw new Error('OpenAI is required for web search and file attachments.'); })()
      : await generate(messages,
        typeof body.max_tokens === 'number' ? Math.max(128, Math.min(4096, Math.floor(body.max_tokens))) : 2048,
        typeof body.temperature === 'number' ? Math.max(0, Math.min(1, body.temperature)) : 0.3, env, send);
    const { data: access, error: accessError } = await account.rpc('get_my_admin_access');
    if (accessError || access?.status !== 'active' || access?.features?.ai !== true) throw new Error('AI access is no longer available for this account.');
    const { error: finishError } = await service.rpc('finish_ai_request', {
      p_request: reservation.request_id, p_body: result.text, p_provider: result.provider,
      p_model: result.model, p_input_tokens: result.input ?? null, p_output_tokens: result.output ?? null,
    });
    if (finishError) throw new Error('The AI response could not be saved. Please retry.');
    return reply(200, { text: result.text, request_id: reservation.request_id, provider: result.provider, model: result.model, usage: reservation.usage });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'AI request failed.';
    await service.rpc('finish_ai_request', { p_request: reservation.request_id, p_error: message });
    return reply(503, { error: message });
  }
}

if (import.meta.main) Deno.serve((request) => handleRequest(request));
