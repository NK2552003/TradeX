import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers });
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

  let selectedText: string;
  let contextTitle: string | undefined;
  let instruction: string | undefined;
  let noteType: string;

  try {
    const body = await request.json() as Record<string, unknown>;
    selectedText = String(body.selectedText ?? '').trim();
    contextTitle = body.contextTitle ? String(body.contextTitle).trim() : undefined;
    instruction = body.instruction ? String(body.instruction).trim() : undefined;
    noteType = String(body.noteType ?? 'general');
  } catch {
    return reply(400, { error: 'Invalid JSON payload.' });
  }

  if (!selectedText) {
    return reply(400, { error: 'selectedText is required.' });
  }

  // Enforce per-user quota & record invocation in ai_insight_requests
  const service = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { error: quotaError } = await service.from('ai_insight_requests').insert({
    user_id: user.id,
    kind: 'note_refactor',
    requested_at: new Date().toISOString(),
  });

  if (quotaError) {
    return reply(429, { error: quotaError.message || 'AI monthly quota exceeded.' });
  }

  // LLM invocation via Gemini or OpenRouter
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
${selectedText}
"""`;

  let enhancedText: string | null = null;

  if (geminiApiKey) {
    try {
      const geminiRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
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
        }
      );
      if (geminiRes.ok) {
        const json = await geminiRes.json();
        const candidate = json.candidates?.[0]?.content?.parts?.[0]?.text;
        if (candidate) enhancedText = candidate.trim();
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
      });
      if (openRouterRes.ok) {
        const json = await openRouterRes.json();
        const choice = json.choices?.[0]?.message?.content;
        if (choice) enhancedText = choice.trim();
      }
    } catch (e) {
      console.error('OpenRouter call error:', e);
    }
  }

  if (!enhancedText) {
    return reply(503, { error: 'AI refactoring service is currently unavailable.' });
  }

  // Strip wrapping code fences if returned by LLM
  if (enhancedText.startsWith('```markdown') && enhancedText.endsWith('```')) {
    enhancedText = enhancedText.slice(11, -3).trim();
  } else if (enhancedText.startsWith('```') && enhancedText.endsWith('```')) {
    enhancedText = enhancedText.slice(3, -3).trim();
  }

  return reply(200, { enhanced: enhancedText });
});

