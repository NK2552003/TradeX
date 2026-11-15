import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const MAX_BODY_BYTES = 64_000;
const MAX_SELECTED_TEXT_CHARS = 20_000;
const MAX_INSTRUCTION_CHARS = 2_000;
const MAX_CONTEXT_TITLE_CHARS = 300;

const VALID_NOTE_TYPES = new Set([
  'general',
  'analysis',
  'plan',
  'review',
  'idea',
  'cheat_sheet',
  'cheatSheet',
]);

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

  if (!request.body) {
    return '';
  }

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

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  const logger = createEdgeRequestLogger('note-ai-refactor', request);
  try {
    return logger.finish(await handleNoteRefactorRequest(request, logger));
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(reply(500, { error: 'Note refactoring request failed.' }));
  }
});

async function handleNoteRefactorRequest(
  request: Request,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
  if (request.method !== 'POST') return reply(405, { error: 'Method not allowed' });

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');

  if (!url || !anonKey || !serviceKey) {
    return reply(503, { error: 'Database service is not configured.' });
  }

  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return reply(401, { error: 'Sign in required.' });
  }

  const token = authorization.slice(7);
  const account = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: { user }, error: authError } = await account.auth.getUser(token);
  if (authError || !user) {
    return reply(401, { error: 'Signed-in account required.' });
  }

  // 1. Bound and stream request body before parsing
  let rawBody: string;
  try {
    rawBody = await readBodyWithLimit(request, MAX_BODY_BYTES);
  } catch (err) {
    if (err instanceof PayloadTooLargeError) {
      return reply(413, { error: err.message });
    }
    return reply(400, { error: 'Failed to read request body.' });
  }

  // 2. Validate JSON structure
  let body: Record<string, unknown>;
  try {
    body = JSON.parse(rawBody || '{}');
  } catch {
    return reply(400, { error: 'Invalid JSON payload.' });
  }

  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return reply(400, { error: 'Request body must be a JSON object.' });
  }

  // 3. Validate selectedText field and bound character length
  if (!('selectedText' in body) || body.selectedText === null || body.selectedText === undefined) {
    return reply(400, { error: 'selectedText is required.' });
  }
  if (typeof body.selectedText !== 'string') {
    return reply(400, { error: 'selectedText must be a string.' });
  }
  const cleanSelectedText = body.selectedText.trim();
  if (cleanSelectedText.length === 0) {
    return reply(400, { error: 'selectedText cannot be blank.' });
  }
  if (cleanSelectedText.length > MAX_SELECTED_TEXT_CHARS) {
    return reply(413, {
      error: `selectedText exceeds maximum length of ${MAX_SELECTED_TEXT_CHARS} characters.`,
    });
  }

  // 4. Validate optional contextTitle field
  let contextTitle: string | undefined;
  if ('contextTitle' in body && body.contextTitle !== null && body.contextTitle !== undefined) {
    if (typeof body.contextTitle !== 'string') {
      return reply(400, { error: 'contextTitle must be a string if provided.' });
    }
    const cleanTitle = body.contextTitle.trim();
    if (cleanTitle.length > MAX_CONTEXT_TITLE_CHARS) {
      return reply(413, {
        error: `contextTitle exceeds maximum length of ${MAX_CONTEXT_TITLE_CHARS} characters.`,
      });
    }
    contextTitle = cleanTitle.length > 0 ? cleanTitle : undefined;
  }

  // 5. Validate optional instruction field
  let instruction: string | undefined;
  if ('instruction' in body && body.instruction !== null && body.instruction !== undefined) {
    if (typeof body.instruction !== 'string') {
      return reply(400, { error: 'instruction must be a string if provided.' });
    }
    const cleanInstruction = body.instruction.trim();
    if (cleanInstruction.length > MAX_INSTRUCTION_CHARS) {
      return reply(413, {
        error: `instruction exceeds maximum length of ${MAX_INSTRUCTION_CHARS} characters.`,
      });
    }
    instruction = cleanInstruction.length > 0 ? cleanInstruction : undefined;
  }

  // 6. Validate optional noteType field against domain enum contract
  let noteType = 'general';
  if ('noteType' in body && body.noteType !== null && body.noteType !== undefined) {
    if (typeof body.noteType !== 'string') {
      return reply(400, { error: 'noteType must be a string if provided.' });
    }
    const normalizedType = body.noteType.trim();
    if (!VALID_NOTE_TYPES.has(normalizedType)) {
      return reply(400, {
        error: `Invalid noteType '${normalizedType}'. Supported values: ${Array.from(VALID_NOTE_TYPES).join(', ')}.`,
      });
    }
    noteType = normalizedType === 'cheatSheet' ? 'cheat_sheet' : normalizedType;
  }

  // 7. Enforce per-user quota & record invocation atomically via reserve_ai_request
  //    using the authenticated user client so auth.uid() quota triggers run under lock.
  const { data: reservation, error: quotaError } = await account.rpc('reserve_ai_request', {
    p_kind: 'completion',
    p_prompt: cleanSelectedText.slice(0, 500),
    p_thread: null,
    p_persona: noteType,
  });

  if (quotaError) {
    // Return 429 when SQLSTATE P0001 indicates quota or limit exhaustion
    const lowerMsg = quotaError.message?.toLowerCase() ?? '';
    const isQuotaExceeded =
      quotaError.code === 'P0001' &&
      (Boolean(quotaError.message?.toLowerCase().includes('quota')) ||
        lowerMsg.includes('limit reached'));

    if (isQuotaExceeded) {
      return reply(429, {
        error: 'AI monthly quota exceeded. Upgrade your plan for more refactoring requests.',
      });
    }
    if (quotaError.code === '42501') {
      return reply(403, {
        error: quotaError.message || 'AI access is not available for this account.',
      });
    }
    console.error('[note-ai-refactor] Database insertion failure:', {
      code: quotaError.code,
      hint: quotaError.hint,
      message: quotaError.message,
    });
    return reply(500, {
      error: 'Failed to record AI request. Please try again later.',
    });
  }
  const _noteRefactorRequestId = typeof reservation?.request_id === 'string' ? reservation.request_id : null;
  const service = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 8. LLM invocation via OpenAI, Gemini or OpenRouter with headers and timeout signals
  const openAiApiKey = Deno.env.get('OPEN_AI_KEY') ?? Deno.env.get('OPENAI_API_KEY');
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
  const openRouterApiKey = Deno.env.get('OPENROUTER_API_KEY');

  const systemPrompt = `You are alphajournal Copilot, an elite quantitative financial analyst and disciplined trading performance coach.
Your task is to refine, enhance, or restructure the trader's note content according to their instructions.
Guidelines:
- Return ONLY the raw Markdown output replacing the selected text, without conversational filler or markdown fences (\`\`\`) around the entire response.
- Maintain all price levels, ratios, numbers, tickers, and percentages exactly.
- Apply high-signal trading formatting (tables, checklists, bulleted frameworks).
- Adhere strictly to the requested instruction.`;

  const prompt = `Context:
- Note Title: ${contextTitle ?? 'Trading Note'}
- Note Type: ${noteType}
- Instruction: ${instruction ?? 'Refine, polish, and structure into clear actionable trading notes'}

Selected Note Passage:
"""
${cleanSelectedText}
"""`;

  let enhancedText: string | null = null;

  if (!enhancedText && openAiApiKey) {
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
              { role: 'user', content: prompt },
            ],
            temperature: 0.3,
            max_tokens: 2048,
          }),
          signal: AbortSignal.timeout(20_000),
        });
        if (openAiRes.ok) {
          const json = await openAiRes.json();
          const choice = json.choices?.[0]?.message?.content;
          if (choice) {
            enhancedText = choice.trim();
            break;
          }
        } else {
          console.error(`OpenAI ${model} error response status:`, openAiRes.status);
        }
      } catch (e) {
        console.error(`OpenAI ${model} call error:`, e);
      }
    }
  }

  if (!enhancedText && geminiApiKey) {
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
            contents: [
              {
                role: 'user',
                parts: [{ text: `${systemPrompt}\n\n${prompt}` }],
              },
            ],
            generationConfig: {
              temperature: 0.3,
              maxOutputTokens: 2048,
            },
          }),
          signal: AbortSignal.timeout(20_000),
        }
      );
      if (geminiRes.ok) {
        const json = await geminiRes.json();
        const candidate = json.candidates?.[0]?.content?.parts?.[0]?.text;
        if (candidate) enhancedText = candidate.trim();
      } else {
        console.error('Gemini error response status:', geminiRes.status);
      }
    } catch (e) {
      console.error('Gemini call error:', e);
    }
  }

  if (!enhancedText && openRouterApiKey) {
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
            { role: 'user', content: prompt },
          ],
          temperature: 0.3,
          max_tokens: 2048,
        }),
        signal: AbortSignal.timeout(20_000),
      });
      if (openRouterRes.ok) {
        const json = await openRouterRes.json();
        const choice = json.choices?.[0]?.message?.content;
        if (choice) enhancedText = choice.trim();
      } else {
        console.error('OpenRouter error response status:', openRouterRes.status);
      }
    } catch (e) {
      console.error('OpenRouter call error:', e);
    }
  }

  if (!enhancedText) {
    if (_noteRefactorRequestId) {
      await service.rpc('finish_ai_request', {
        p_request: _noteRefactorRequestId,
        p_error: 'AI refactoring service is currently unavailable.',
      });
    }
    logger.log('error', 'note_refactor_providers_unavailable', { note_type: noteType });
    return reply(503, { error: 'AI refactoring service is currently unavailable.' });
  }

  // Strip wrapping code fences if returned by LLM
  if (enhancedText.startsWith('```markdown') && enhancedText.endsWith('```')) {
    enhancedText = enhancedText.slice(11, -3).trim();
  } else if (enhancedText.startsWith('```') && enhancedText.endsWith('```')) {
    enhancedText = enhancedText.slice(3, -3).trim();
  }

  if (_noteRefactorRequestId) {
    await service.rpc('finish_ai_request', {
      p_request: _noteRefactorRequestId,
      p_body: enhancedText,
      p_provider: 'note-refactor',
      p_model: 'refactor',
      p_input_tokens: cleanSelectedText.length,
      p_output_tokens: enhancedText.length,
    });
  }

  logger.log('info', 'note_refactor_succeeded', {
    note_type: noteType,
    input_chars: cleanSelectedText.length,
    output_chars: enhancedText.length,
  });
  return reply(200, { enhanced: enhancedText, usage: reservation?.usage });
}
