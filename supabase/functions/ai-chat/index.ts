import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const MAX_BODY_BYTES = 128_000;
const MAX_MESSAGE_CHARS = 10_000;

class PayloadTooLargeError extends Error {
  constructor(message = 'Request payload exceeds limit.') {
    super(message);
    this.name = 'PayloadTooLargeError';
  }
}

async function readBodyWithLimit(request: Request, maxBytes: number): Promise<string> {
  const contentLength = request.headers.get('content-length');
  if (contentLength && parseInt(contentLength, 10) > maxBytes) {
    throw new PayloadTooLargeError(`Request body exceeds ${maxBytes} bytes limit.`);
  }

  if (!request.body) return '';

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value) {
        totalBytes += value.byteLength;
        if (totalBytes > maxBytes) {
          throw new PayloadTooLargeError(`Request body exceeds ${maxBytes} bytes limit.`);
        }
        chunks.push(value);
      }
    }
  } finally {
    reader.releaseLock();
  }

  const concatenated = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    concatenated.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(concatenated);
}

function jsonReply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonReply(405, { error: 'Method not allowed' });
  }

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');

  if (!url || !anonKey || !serviceKey) {
    return jsonReply(503, { error: 'Database service is not configured.' });
  }

  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return jsonReply(401, { error: 'Sign in required.' });
  }

  const token = authorization.slice(7);
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: { user }, error: authError } = await userClient.auth.getUser(token);
  if (authError || !user) {
    return jsonReply(401, { error: 'Signed-in account required.' });
  }

  const adminClient = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1. Read and validate request body
  let rawBody: string;
  try {
    rawBody = await readBodyWithLimit(request, MAX_BODY_BYTES);
  } catch (err) {
    if (err instanceof PayloadTooLargeError) {
      return jsonReply(413, { error: err.message });
    }
    return jsonReply(400, { error: 'Failed to read request body.' });
  }

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(rawBody || '{}');
  } catch {
    return jsonReply(400, { error: 'Invalid JSON payload.' });
  }

  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (!message) {
    return jsonReply(400, { error: 'message is required.' });
  }
  if (message.length > MAX_MESSAGE_CHARS) {
    return jsonReply(413, { error: `message exceeds limit of ${MAX_MESSAGE_CHARS} characters.` });
  }

  const persona = typeof body.persona === 'string' ? body.persona.trim() : 'swing';
  let threadId = typeof body.threadId === 'string' && body.threadId.trim().length > 0 ? body.threadId.trim() : null;

  // 2. Authorize and load referenced context server-side
  const authorizedContexts: string[] = [];
  const sources: Array<{ kind: string; id: string; title: string }> = [];

  if (body.context && typeof body.context === 'object') {
    const ctx = body.context as Record<string, unknown>;
    const recordRefs = Array.isArray(ctx.recordRefs) ? ctx.recordRefs : [];

    for (const ref of recordRefs) {
      if (!ref || typeof ref !== 'object') continue;
      const kind = String(ref.kind ?? '').toLowerCase();
      const id = String(ref.id ?? '');
      if (!id) continue;

      if (kind === 'note') {
        const { data: note } = await adminClient
          .from('trader_notes')
          .select('id, user_id, title, content, is_public')
          .eq('id', id)
          .maybeSingle();

        if (note && (note.user_id === user.id || note.is_public)) {
          authorizedContexts.push(`[Note: ${note.title}]\n${note.content}`);
          sources.push({ kind: 'note', id: note.id, title: note.title });
        }
      } else if (kind === 'journal' || kind === 'trade') {
        const { data: trade } = await adminClient
          .from('journal_entries')
          .select('id, user_id, ticker, side, entry_price, exit_price, pnl, notes')
          .eq('id', id)
          .maybeSingle();

        if (trade && trade.user_id === user.id) {
          authorizedContexts.push(
            `[Trade: ${trade.ticker} ${trade.side}] Entry: ${trade.entry_price}, Exit: ${trade.exit_price ?? 'Open'}, PnL: ${trade.pnl ?? 0}\nNotes: ${trade.notes ?? ''}`
          );
          sources.push({ kind: 'journal', id: trade.id, title: `${trade.ticker} trade` });
        }
      } else if (kind === 'strategy') {
        const { data: strat } = await adminClient
          .from('strategies')
          .select('id, user_id, name, content, is_public')
          .eq('id', id)
          .maybeSingle();

        if (strat && (strat.user_id === user.id || strat.is_public)) {
          authorizedContexts.push(`[Strategy Playbook: ${strat.name}]\n${strat.content}`);
          sources.push({ kind: 'strategy', id: strat.id, title: strat.name });
        }
      }
    }
  }

  // 3. Atomically check and record quota
  try {
    await adminClient.from('ai_insight_requests').insert({
      user_id: user.id,
      kind: 'copilot_chat',
    });
  } catch (err) {
    console.error('Quota recording error:', err);
    return jsonReply(429, { error: 'Monthly AI quota reached or request rate limit exceeded.' });
  }

  // 4. Ensure thread exists or create it
  if (!threadId) {
    threadId = crypto.randomUUID();
    await adminClient.from('ai_threads').insert({
      id: threadId,
      user_id: user.id,
      title: message.slice(0, 50),
      persona,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
  }

  // Persist user turn
  const userMessageId = crypto.randomUUID();
  await adminClient.from('ai_messages').insert({
    id: userMessageId,
    thread_id: threadId,
    role: 'user',
    body: message,
    created_at: new Date().toISOString(),
  });

  // 5. Select provider and model (OpenAI preferred: gpt-4.1-mini)
  const openAiApiKey = Deno.env.get('OPEN_AI_KEY') ?? Deno.env.get('OPENAI_API_KEY');
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
  const openRouterApiKey = Deno.env.get('OPENROUTER_API_KEY');

  const systemPrompt = `You are alphajournal Institutional AI Copilot, an elite market intelligence engine for serious traders.
Persona mode: ${persona}
Directives:
1. Provide actionable, high-signal quantitative insights with exact price structures, risk/reward boundaries, and logical invalidations.
2. Structure answers with clean Markdown headings, bulleted technical confluences, and structured summary tables where appropriate.
3. Maintain all numbers and calculations with rigorous precision.`;

  const contextBlock = authorizedContexts.length > 0
    ? `\n\nAuthorized User Context:\n${authorizedContexts.join('\n\n---\n\n')}`
    : '';

  const fullPrompt = `${message}${contextBlock}`;

  const assistantMessageId = crypto.randomUUID();

  // Create streaming SSE response
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      function sendEvent(event: string, data: Record<string, unknown>) {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      }

      sendEvent('thread', { threadId });
      for (const src of sources) {
        sendEvent('source', src);
      }

      let completeText = '';

      // Try OpenAI first
      if (openAiApiKey) {
        for (const model of ['gpt-4.1-mini', 'gpt-4o-mini']) {
          try {
            const openAiRes = await fetch('https://api.openai.com/v1/chat/completions', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${openAiApiKey}`,
              },
              body: JSON.stringify({
                model,
                messages: [
                  { role: 'system', content: systemPrompt },
                  { role: 'user', content: fullPrompt },
                ],
                stream: true,
                temperature: 0.3,
                max_tokens: 2048,
              }),
            });

            if (openAiRes.ok && openAiRes.body) {
              const reader = openAiRes.body.getReader();
              const decoder = new TextDecoder();
              let buffer = '';

              while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');
                buffer = lines.pop() ?? '';

                for (const line of lines) {
                  const trimmed = line.trim();
                  if (!trimmed.startsWith('data:')) continue;
                  const dataStr = trimmed.slice(5).trim();
                  if (dataStr === '[DONE]') break;
                  try {
                    const parsed = JSON.parse(dataStr);
                    const delta = parsed.choices?.[0]?.delta?.content;
                    if (delta) {
                      completeText += delta;
                      sendEvent('delta', { messageId: assistantMessageId, text: delta });
                    }
                  } catch (_) {}
                }
              }

              if (completeText.trim().length > 0) {
                break;
              }
            }
          } catch (e) {
            console.error(`OpenAI ${model} streaming error:`, e);
          }
        }
      }

      // Fallback to Gemini if OpenAI did not yield
      if (!completeText.trim() && geminiApiKey) {
        try {
          const geminiRes = await fetch(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': geminiApiKey,
              },
              body: JSON.stringify({
                contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\n${fullPrompt}` }] }],
                generationConfig: { temperature: 0.3, maxOutputTokens: 2048 },
              }),
            }
          );
          if (geminiRes.ok) {
            const data = await geminiRes.json();
            const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
            if (text) {
              completeText = text;
              sendEvent('delta', { messageId: assistantMessageId, text });
            }
          }
        } catch (e) {
          console.error('Gemini fallback error:', e);
        }
      }

      // Fallback to OpenRouter if still empty
      if (!completeText.trim() && openRouterApiKey) {
        try {
          const openRouterRes = await fetch('https://openrouter.ai/api/v1/chat/completions', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${openRouterApiKey}`,
            },
            body: JSON.stringify({
              model: 'meta-llama/llama-3.3-70b-instruct',
              messages: [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: fullPrompt },
              ],
              temperature: 0.3,
              max_tokens: 2048,
            }),
          });
          if (openRouterRes.ok) {
            const data = await openRouterRes.json();
            const text = data.choices?.[0]?.message?.content ?? '';
            if (text) {
              completeText = text;
              sendEvent('delta', { messageId: assistantMessageId, text });
            }
          }
        } catch (e) {
          console.error('OpenRouter fallback error:', e);
        }
      }

      if (completeText.trim().length > 0) {
        // Atomically save assistant turn
        await adminClient.from('ai_messages').insert({
          id: assistantMessageId,
          thread_id: threadId,
          role: 'assistant',
          body: completeText.trim(),
          sources: sources.map((s) => `${s.kind}:${s.id}:${s.title}`),
          created_at: new Date().toISOString(),
        });

        await adminClient
          .from('ai_threads')
          .update({ updated_at: new Date().toISOString() })
          .eq('id', threadId);

        sendEvent('complete', {
          messageId: assistantMessageId,
          usage: { inputTokens: fullPrompt.length, outputTokens: completeText.length },
        });
      } else {
        sendEvent('error', {
          code: 'service_unavailable',
          message: 'AI assistant is currently unavailable. Please try again.',
        });
      }

      controller.close();
    },
  });

  return new Response(stream, {
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
});
