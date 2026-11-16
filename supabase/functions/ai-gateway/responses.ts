import { freshnessInstructions, needsFreshResearch } from './research-policy.ts';
import { openTraderSkill, uploadTraderToolkit } from './trader-toolkit.ts';

type Message = { role: 'user' | 'assistant' | 'system'; content: string };
type ToolSource = { url: string; title: string; domain: string };
export type ProviderResult = {
  text: string;
  provider: string;
  model: string;
  input?: number;
  output?: number;
  steps?: string[];
  webSearchUsed?: boolean;
  toolSources?: ToolSource[];
};
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

type OutputItem = {
  type?: string;
  name?: string;
  call_id?: string;
  query?: string;
  action?: { type?: string; query?: string; url?: string; pattern?: string };
  content?: OutputText[];
};

function collectOutputSteps(items: OutputItem[] | undefined, sink: string[]) {
  if (!Array.isArray(items)) return;
  for (const item of items) {
    if (!item || typeof item !== 'object') continue;
    if (item.type === 'web_search_call') {
      const q = (item.action?.query ?? item.query ?? '').trim();
      const actionUrl = (item.action?.url ?? '').trim();
      let stepLabel = 'Searching live web sources';
      if (q) {
        stepLabel = `Searching "${q}"`;
      } else if (actionUrl) {
        try {
          const host = new URL(actionUrl).hostname.replace(/^www\./i, '');
          stepLabel = `Reading ${host}`;
        } catch {
          stepLabel = 'Reading web source';
        }
      }
      if (!sink.includes(stepLabel)) sink.push(stepLabel);
    } else if (item.type === 'code_interpreter_call') {
      const stepLabel = 'Running quantitative Python analysis';
      if (!sink.includes(stepLabel)) sink.push(stepLabel);
    } else if (item.type === 'function_call' && item.name) {
      const stepLabel = `Loading ${item.name} toolkit`;
      if (!sink.includes(stepLabel)) sink.push(stepLabel);
    }
  }
}

function collectToolSources(items: OutputItem[] | undefined): ToolSource[] {
  if (!Array.isArray(items)) return [];
  const seen = new Map<string, ToolSource>();
  for (const item of items) {
    for (const content of item.content ?? []) {
      for (const ann of content.annotations ?? []) {
        if (ann.type !== 'url_citation' || !ann.url) continue;
        const cleanUrl = ann.url.trim();
        if (!/^https?:\/\//.test(cleanUrl)) continue;
        try {
          const parsed = new URL(cleanUrl);
          const key = parsed.toString();
          if (seen.has(key)) continue;
          const domain = parsed.hostname.replace(/^www\./i, '');
          const title = (ann.title ?? '').trim() || domain;
          seen.set(key, { url: key, title, domain });
        } catch {
          // Ignore invalid URL.
        }
      }
    }
  }
  return Array.from(seen.values());
}

export async function generateResponses(
  messages: Message[],
  attachments: unknown[],
  mode: string,
  model: string,
  key: string,
  send: typeof fetch,
  allowWebSearch = false,
  toolkit?: 'auto' | 'selected',
): Promise<ProviderResult> {
  const system = messages.filter((m) => m.role === 'system').map((m) => m.content).join('\n') + '\n' + freshnessInstructions();
  const requireFreshSearch = needsFreshResearch(messages.filter((m) => m.role === 'user').at(-1)?.content ?? '');
  const input: unknown[] = messages.filter((m) => m.role !== 'system').map((message) => ({
    role: message.role,
    content: message.role === 'assistant' ? message.content : [
      { type: 'input_text', text: message.content },
      ...(message.role === 'user' && message === messages.at(-1) ? attachments : []),
    ],
  }));
  const tools = mode === 'auto' && !allowWebSearch ? [] : [{ type: 'web_search', external_web_access: true, ...(mode === 'research' ? { search_context_size: 'high' } : {}) }];
  let fileId = toolkit === 'selected' ? await uploadTraderToolkit(key, send) : undefined;
  let inputTokens = 0, outputTokens = 0;
  const recordedSteps: string[] = [];
  for (let step = 0; step < 2; step++) {
    const response = await send('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify({
        model,
        store: false,
        instructions: system + (fileId ? '\nThe bundled trader-skills.zip is in /mnt/data. Extract it with Python and read the selected SKILL.md. Run the supplied scripts, passing their trader/ files between steps. Retrieve external data via permitted web search or ask for dated inputs. Report the actual results in the reply. Preview tickets only.' : ''),
        input,
        tools: [...tools, ...(fileId
          ? [{ type: 'code_interpreter', container: { type: 'auto', file_ids: [fileId] } }]
          : toolkit ? [openTraderSkill] : [])],
        ...(step === 0 && (mode !== 'auto' || requireFreshSearch) && tools.length > 0 ? { tool_choice: { type: 'web_search' } } : {}),
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
    inputTokens += tokenCount(data.usage?.input_tokens) ?? 0;
    outputTokens += tokenCount(data.usage?.output_tokens) ?? 0;
    collectOutputSteps(data.output, recordedSteps);
    const calls = data.output?.filter((item: {type: string; name?: string}) =>
      item.type === 'function_call' && item.name === openTraderSkill.name) ?? [];
    if (calls.length && toolkit === 'auto' && !fileId) {
      fileId = await uploadTraderToolkit(key, send);
      input.push(...data.output, ...calls.map((call: {call_id: string}) => ({
        type: 'function_call_output', call_id: call.call_id, output: 'Trader toolkit loaded into the Python container.',
      })));
      continue;
    }
    const text = data.output?.flatMap((item: { content?: { type: string; text?: string }[] }) => item.content ?? [])
      .filter((content: { type: string }) => content.type === 'output_text')
      .map((content: OutputText) => withCitations(content))
      .join('');
    if (typeof text !== 'string' || !text.trim()) throw new Error('The AI service returned an empty response.');
    const toolSources = collectToolSources(data.output);
    return {
      text: text.trim(),
      provider: 'openai',
      webSearchUsed: recordedSteps.some((step) => step.startsWith('Searching') || step.startsWith('Reading')),
      model: typeof data.model === 'string' ? data.model : model,
      input: inputTokens || undefined,
      output: outputTokens || undefined,
      ...(recordedSteps.length > 0 ? { steps: recordedSteps } : {}),
      ...(toolSources.length > 0 ? { toolSources } : {}),
    };
  }
  throw new Error('The trader workflow did not finish. Retry this request.');
}
