type Message = { role: 'user' | 'assistant' | 'system'; content: string };
type ProviderResult = { text: string; provider: string; model: string; input?: number; output?: number };
type Citation = { type: string; url?: string; title?: string; start_index?: number; end_index?: number };
type OutputText = { text?: string; annotations?: Citation[] };
function tokenCount(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? value : undefined;
}

function withCitations(content: OutputText): string {
  let text = content.text ?? '';
  const citations = (content.annotations ?? []).filter((item) =>
    item.type === 'url_citation' && /^https?:\/\//.test(item.url ?? '') &&
    Number.isInteger(item.start_index) && Number.isInteger(item.end_index) &&
    item.start_index! >= 0 && item.end_index! > item.start_index! && item.end_index! <= text.length
  ).sort((a, b) => b.start_index! - a.start_index!);
  let boundary = text.length;
  for (const citation of citations) {
    if (citation.end_index! > boundary) continue;
    const label = (citation.title || 'Source').replace(/[\[\]\n\r]/g, ' ');
    const url = citation.url!.replace(/\(/g, '%28').replace(/\)/g, '%29');
    text = text.slice(0, citation.start_index) + `[${label}](${url})` + text.slice(citation.end_index);
    boundary = citation.start_index!;
  }
  return text;
}

export async function generateResponses(
  messages: Message[],
  attachments: unknown[],
  mode: string,
  model: string,
  key: string,
  send: typeof fetch,
  allowWebSearch = false,
): Promise<ProviderResult> {
  const system = messages.filter((m) => m.role === 'system').map((m) => m.content).join('\n');
  const input = messages.filter((m) => m.role !== 'system').map((message) => ({
    role: message.role,
    content: [
      { type: 'input_text', text: message.content },
      ...(message.role === 'user' && message === messages.at(-1) ? attachments : []),
    ],
  }));
  const tools = mode === 'auto' && !allowWebSearch ? [] : [{ type: 'web_search', ...(mode === 'research' ? { search_context_size: 'high' } : {}) }];
  const response = await send('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model,
      instructions: system,
      input,
      tools,
      ...(mode !== 'auto' && tools.length > 0 ? { tool_choice: { type: 'web_search' } } : {}),
      max_output_tokens: 4096,
    }),
    signal: AbortSignal.timeout(60000),
  });
  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    const code = error.error?.code;
    if (response.status === 401) throw new Error('The OpenAI key configured in Supabase Edge Function secrets is invalid.');
    if (code === 'insufficient_quota') throw new Error('The OpenAI API project has no available quota. Check its billing and usage limits.');
    if (response.status === 429) throw new Error('OpenAI is rate limiting requests. Please retry shortly.');
    if (response.status === 403 || code === 'model_not_found') throw new Error('The OpenAI API project cannot access the configured model. Check its model permissions.');
    throw new Error('OpenAI could not complete this request. Check the gateway model and provider configuration.');
  }
  const data = await response.json();
  const text = data.output?.flatMap((item: { content?: { type: string; text?: string }[] }) => item.content ?? [])
    .filter((content: { type: string }) => content.type === 'output_text')
    .map((content: OutputText) => withCitations(content))
    .join('');
  if (typeof text !== 'string' || !text.trim()) throw new Error('The AI service returned an empty response.');
  return {
    text: text.trim(),
    provider: 'openai',
    model: typeof data.model === 'string' ? data.model : model,
    input: tokenCount(data.usage?.input_tokens),
    output: tokenCount(data.usage?.output_tokens),
  };
}

