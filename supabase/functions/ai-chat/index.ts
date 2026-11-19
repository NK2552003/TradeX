import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, withCorsHeaders } from '../_shared/cors.ts';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';

const corsHeaders = {
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
    return corsPreflightResponse(request);
  }
  const logger = createEdgeRequestLogger('ai-chat', request);
  try {
    return logger.finish(withCorsHeaders(
      request,
      await handleAiChatRequest(request, logger),
    ));
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(withCorsHeaders(
      request,
      jsonReply(500, { error: 'AI assistant request failed.' }),
    ));
  }
});

async function handleAiChatRequest(
  request: Request,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
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

  // 3. Atomically reserve quota and validate AI entitlement as the authenticated user.
  //    Unlike unchecked admin inserts, reserve_ai_request acquires an advisory lock,
  //    enforces published tier limits & daily caps, and returns SQLSTATE P0001/42501 on denial.
  const { data: reservation, error: reserveError } = await userClient.rpc('reserve_ai_request', {
    p_kind: 'chat',
    p_prompt: message,
    p_thread: threadId,
    p_persona: persona,
  });
  if (reserveError) {
    console.error('Quota recording failed:', reserveError.code, reserveError.message);
    if (reserveError.code === '42501') {
      return jsonReply(403, { error: reserveError.message || 'AI access is not available for this account.' });
    }
    if (reserveError.code === 'P0001') {
      return jsonReply(429, { error: reserveError.message || 'Monthly AI quota reached or request rate limit exceeded.' });
    }
    return jsonReply(503, { error: reserveError.message || 'Unable to verify AI quota.' });
  }
  const requestId = typeof reservation?.request_id === 'string' ? reservation.request_id : null;

  // 4. Ensure thread exists or create it
  if (!threadId) {
    threadId = crypto.randomUUID();
    await adminClient.from('ai_threads').insert({
      id: threadId,
      user_id: user.id,
      title: 'Private AI conversation',
      persona,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
  }

  // Conversation content is retained only by the encrypted client workspace.

  // 5. Select provider and model (OpenAI preferred: gpt-4.1-mini)
  const openAiApiKey = Deno.env.get('OPEN_AI_KEY') ?? Deno.env.get('OPENAI_API_KEY');
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
  const openRouterApiKey = Deno.env.get('OPENROUTER_API_KEY');

  const systemPrompt = `You are AlphaJournal Institutional AI Copilot, an elite Perplexity-style market & research intelligence engine for serious traders.
Persona mode: ${persona}
Directives:
1. Lead with a crisp Direct Answer grounded strictly in supplied context or verified facts; cite external URLs as [Title](https://...) without ever inventing URLs or live market quotes.
2. Enrich entities and research with fenced JSON visual cards using clean Markdown + structured blocks (\`\`\`company, \`\`\`person, \`\`\`news, \`\`\`compare, \`\`\`timeline, \`\`\`setup, \`\`\`verdict, \`\`\`factbox, \`\`\`faq, \`\`\`checklist, \`\`\`quote, \`\`\`earnings, \`\`\`financials, \`\`\`macro, \`\`\`ratings, \`\`\`screener, \`\`\`sentiment, \`\`\`product, \`\`\`media, \`\`\`formula, \`\`\`research_steps, \`\`\`kpi, \`\`\`candle, \`\`\`chart) whenever helpful, keeping numbers rigorous.
3. End exploratory answers with a fenced \`\`\`followups JSON array of 3-4 smart follow-up questions.`;

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
                max_tokens: 3584,
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
            console.error('OpenAI streaming failed');
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
                generationConfig: { temperature: 0.3, maxOutputTokens: 3584 },
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
          console.error('Gemini fallback failed');
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
              max_tokens: 3584,
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
          console.error('OpenRouter fallback failed');
        }
      }

      if (completeText.trim().length > 0) {
        if (requestId) {
          await adminClient.rpc('finish_ai_request', {
            p_request: requestId,
            p_body: completeText,
            p_provider: openAiApiKey ? 'openai' : (geminiApiKey ? 'gemini' : 'openrouter'),
            p_model: 'copilot-chat',
            p_input_tokens: fullPrompt.length,
            p_output_tokens: completeText.length,
          });
        }
        await adminClient
          .from('ai_threads')
          .update({ updated_at: new Date().toISOString() })
          .eq('id', threadId);

        logger.log('info', 'ai_chat_stream_completed', {
          persona,
          thread_id: threadId,
          input_chars: fullPrompt.length,
          output_chars: completeText.length,
        });
        sendEvent('complete', {
          messageId: assistantMessageId,
          usage: {
            inputTokens: fullPrompt.length,
            outputTokens: completeText.length,
            ...(reservation?.usage ?? {}),
          },
        });
      } else {
        if (requestId) {
          await adminClient.rpc('finish_ai_request', {
            p_request: requestId,
            p_error: 'AI assistant is currently unavailable. Please try again.',
          });
        }
        logger.log('error', 'ai_chat_providers_unavailable', { persona, thread_id: threadId });
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
}

