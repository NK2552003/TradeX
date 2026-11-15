export const voiceCorsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const VALID_VOICES = new Set(['nova', 'alloy', 'echo', 'onyx', 'shimmer']);
const MIME_TO_EXT: Record<string, string> = {
  'audio/webm': 'webm',
  'audio/mp4': 'mp4',
  'audio/m4a': 'm4a',
  'audio/x-m4a': 'm4a',
  'audio/aac': 'm4a',
  'audio/mpeg': 'mp3',
  'audio/mp3': 'mp3',
  'audio/wav': 'wav',
  'audio/wave': 'wav',
  'audio/x-wav': 'wav',
  'audio/ogg': 'ogg',
  'audio/flac': 'flac',
};

const MAX_REQUEST_CHARS = 10_500_000;
const MAX_AUDIO_BYTES = 8_000_000;
const MAX_SPEECH_CHARS = 4_000;

export type AuthCheck = (authorization: string) => Promise<
  | { ok: true; userId: string }
  | { ok: false; status: number; error: string }
>;

export type VoiceDependencies = {
  fetch?: typeof fetch;
  env?: (name: string) => string | undefined;
  authenticate?: AuthCheck;
};

const jsonReply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...voiceCorsHeaders, 'Content-Type': 'application/json' },
  });

const bearer = (value: string) =>
  String.fromCharCode(66, 101, 97, 114, 101, 114) + ' ' + value;

function normalizeMime(raw: unknown): { mime: string; ext: string } | null {
  if (raw == null) return { mime: 'audio/webm', ext: 'webm' };
  if (typeof raw !== 'string') return null;
  const base = raw.split(';')[0].trim().toLowerCase();
  const ext = MIME_TO_EXT[base];
  return ext ? { mime: base === 'audio/x-m4a' || base === 'audio/aac' ? 'audio/m4a' : base, ext } : null;
}

function sanitizeFilename(raw: unknown, ext: string): string {
  if (typeof raw !== 'string' || !raw.trim()) return `speech.${ext}`;
  const cleaned = raw.trim().replace(/[^a-zA-Z0-9._-]/g, '_');
  if (!cleaned) return `speech.${ext}`;
  return cleaned.toLowerCase().endsWith(`.${ext}`) ? cleaned : `${cleaned}.${ext}`;
}

function decodeBase64Audio(raw: unknown): Uint8Array | null {
  if (typeof raw !== 'string' || !raw.trim()) return null;
  const stripped = raw.trim().replace(/^data:[^,]+;base64,/i, '').replace(/\s+/g, '');
  if (!stripped || stripped.length > Math.ceil((MAX_AUDIO_BYTES * 4) / 3) + 16) return null;
  try {
    const binary = atob(stripped);
    if (binary.length === 0 || binary.length > MAX_AUDIO_BYTES) return null;
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  } catch {
    return null;
  }
}

async function mapOpenAiFailure(response: Response): Promise<{ status: number; message: string; code?: string }> {
  const payload = await response.json().catch(() => ({})) as { error?: { code?: string } };
  const code = payload?.error?.code;
  if (response.status === 401) {
    return { status: 502, code, message: 'The OpenAI key configured in Supabase Edge Function secrets is invalid.' };
  }
  if (code === 'insufficient_quota') {
    return { status: 429, code, message: 'The OpenAI API project has no available quota. Check its billing and usage limits.' };
  }
  if (response.status === 429) {
    return { status: 429, code, message: 'OpenAI is rate limiting voice requests. Please retry shortly.' };
  }
  if (response.status === 403 || code === 'model_not_found') {
    return { status: 502, code, message: 'The OpenAI API project cannot access the configured voice model. Check its model permissions.' };
  }
  return { status: 502, code, message: 'OpenAI voice request failed. Check your gateway and model configuration.' };
}

async function handleSpeech(
  body: Record<string, unknown>,
  openAiKey: string,
  env: (name: string) => string | undefined,
  send: typeof fetch,
): Promise<Response> {
  const rawText = body.text;
  if (typeof rawText !== 'string' || !rawText.trim()) {
    return jsonReply(400, { error: 'Speech text is required.' });
  }
  const input = rawText.trim().slice(0, MAX_SPEECH_CHARS);
  const rawVoice = typeof body.voice === 'string' ? body.voice.trim().toLowerCase() : 'nova';
  const voice = VALID_VOICES.has(rawVoice) ? rawVoice : 'nova';
  const model = env('OPENAI_TTS_MODEL') || 'tts-1';

  const response = await send('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      Authorization: bearer(openAiKey),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      input,
      voice,
      response_format: 'mp3',
    }),
    signal: AbortSignal.timeout(25000),
  });

  if (!response.ok) {
    const mapped = await mapOpenAiFailure(response);
    return jsonReply(mapped.status, { error: mapped.message });
  }

  const audioBytes = new Uint8Array(await response.arrayBuffer());
  if (audioBytes.byteLength === 0) {
    return jsonReply(502, { error: 'OpenAI returned empty speech audio.' });
  }
  return new Response(audioBytes, {
    status: 200,
    headers: {
      ...voiceCorsHeaders,
      'Content-Type': 'audio/mpeg',
      'Cache-Control': 'no-store',
    },
  });
}

async function handleTranscribe(
  body: Record<string, unknown>,
  openAiKey: string,
  env: (name: string) => string | undefined,
  send: typeof fetch,
): Promise<Response> {
  const mimeInfo = normalizeMime(body.mime_type);
  if (!mimeInfo) {
    return jsonReply(400, { error: 'Unsupported audio mime_type.' });
  }
  const bytes = decodeBase64Audio(body.audio_base64);
  if (!bytes) {
    return jsonReply(400, { error: 'Valid base64 audio_base64 is required.' });
  }
  const filename = sanitizeFilename(body.filename, mimeInfo.ext);
  const prompt = typeof body.prompt === 'string' && body.prompt.trim()
    ? body.prompt.trim().slice(0, 500)
    : undefined;

  const primaryModel = env('OPENAI_TRANSCRIBE_MODEL') || 'gpt-4o-mini-transcribe';
  const models = primaryModel === 'whisper-1' ? ['whisper-1'] : [primaryModel, 'whisper-1'];

  for (let i = 0; i < models.length; i++) {
    const model = models[i];
    const form = new FormData();
    form.append('file', new Blob([bytes.buffer as ArrayBuffer], { type: mimeInfo.mime }), filename);
    form.append('model', model);
    form.append('response_format', 'json');
    if (prompt) form.append('prompt', prompt);

    const response = await send('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        Authorization: bearer(openAiKey),
      },
      body: form,
      signal: AbortSignal.timeout(30000),
    });

    if (response.ok) {
      const data = await response.json().catch(() => ({})) as { text?: unknown };
      const text = typeof data.text === 'string' ? data.text.trim() : '';
      return jsonReply(200, { text, model });
    }

    const mapped = await mapOpenAiFailure(response);
    const shouldFallback = i < models.length - 1 &&
      (mapped.code === 'model_not_found' || response.status === 404 || response.status === 403);
    if (!shouldFallback) {
      return jsonReply(mapped.status, { error: mapped.message });
    }
  }

  return jsonReply(502, { error: 'OpenAI transcription failed.' });
}

export async function handleVoiceRequest(
  request: Request,
  dependencies: VoiceDependencies = {},
): Promise<Response> {
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: voiceCorsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonReply(405, { error: 'Method not allowed.' });
  }
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return jsonReply(401, { error: 'Sign in required.' });
  }

  const env = dependencies.env ?? ((name: string) => undefined);
  const send = dependencies.fetch ?? fetch;
  const openAiKey = env('OPENAI_API_KEY') ?? env('OPEN_AI_KEY');
  if (!openAiKey) {
    return jsonReply(503, { error: 'Voice AI service is not configured.' });
  }

  if (dependencies.authenticate) {
    const auth = await dependencies.authenticate(authorization);
    if (!auth.ok) {
      return jsonReply(auth.status, { error: auth.error });
    }
  }

  let body: Record<string, unknown>;
  try {
    const raw = await request.text();
    if (!raw || raw.length > MAX_REQUEST_CHARS) {
      return jsonReply(400, { error: 'Voice request payload is empty or too large.' });
    }
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('Invalid object');
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return jsonReply(400, { error: 'Invalid voice request.' });
  }

  try {
    if (body.action === 'speech') {
      return await handleSpeech(body, openAiKey, env, send);
    }
    if (body.action === 'transcribe') {
      return await handleTranscribe(body, openAiKey, env, send);
    }
    return jsonReply(400, { error: 'Unsupported voice action.' });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Voice request failed.';
    return jsonReply(503, { error: message });
  }
}
