import assert from 'node:assert/strict';
import test from 'node:test';
import { handleVoiceRequest } from '../../../supabase/functions/ai-voice/voice.ts';

const authOk = async () => ({ ok: true, userId: 'user-1' });
const baseEnv = (name) => {
  if (name === 'OPENAI_API_KEY') return 'sk-test-secret';
  return undefined;
};

test('ai-voice rejects unauthenticated requests cleanly', async () => {
  const res = await handleVoiceRequest(
    new Request('https://example.com/functions/v1/ai-voice', { method: 'POST', body: '{}' }),
    { env: baseEnv, authenticate: authOk },
  );
  assert.equal(res.status, 401);
});

test('ai-voice rejects callers without AI access entitlement', async () => {
  const res = await handleVoiceRequest(
    new Request('https://example.com/functions/v1/ai-voice', {
      method: 'POST',
      headers: { Authorization: 'Bearer jwt' },
      body: JSON.stringify({ action: 'speech', text: 'Hello' }),
    }),
    {
      env: baseEnv,
      authenticate: async () => ({ ok: false, status: 403, error: 'AI voice access is not available for this account.' }),
    },
  );
  assert.equal(res.status, 403);
});

test('ai-voice speech proxies OpenAI TTS with allowlisted voice and returns audio/mpeg', async () => {
  let upstreamBody;
  const fakeMp3 = new Uint8Array([0x49, 0x44, 0x33, 0x04]);
  const res = await handleVoiceRequest(
    new Request('https://example.com/functions/v1/ai-voice', {
      method: 'POST',
      headers: { Authorization: 'Bearer jwt' },
      body: JSON.stringify({ action: 'speech', text: 'NVDA broke resistance.', voice: 'onyx' }),
    }),
    {
      env: baseEnv,
      authenticate: authOk,
      fetch: async (url, init) => {
        assert.equal(url, 'https://api.openai.com/v1/audio/speech');
        assert.equal(init.headers.Authorization, 'Bearer sk-test-secret');
        upstreamBody = JSON.parse(init.body);
        return new Response(fakeMp3, { status: 200, headers: { 'Content-Type': 'audio/mpeg' } });
      },
    },
  );
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('Content-Type'), 'audio/mpeg');
  assert.equal(upstreamBody.model, 'tts-1');
  assert.equal(upstreamBody.voice, 'onyx');
  assert.equal(upstreamBody.response_format, 'mp3');
  assert.deepEqual(new Uint8Array(await res.arrayBuffer()), fakeMp3);
});

test('ai-voice transcribe reconstructs multipart audio and falls back to whisper-1 on model_not_found', async () => {
  const modelsTried = [];
  const audioSample = Buffer.from('fake-webm-audio').toString('base64');
  const res = await handleVoiceRequest(
    new Request('https://example.com/functions/v1/ai-voice', {
      method: 'POST',
      headers: { Authorization: 'Bearer jwt' },
      body: JSON.stringify({
        action: 'transcribe',
        audio_base64: `data:audio/webm;codecs=opus;base64,${audioSample}`,
        mime_type: 'audio/webm;codecs=opus',
        filename: 'turn.webm',
      }),
    }),
    {
      env: baseEnv,
      authenticate: authOk,
      fetch: async (url, init) => {
        assert.equal(url, 'https://api.openai.com/v1/audio/transcriptions');
        const form = init.body;
        const model = form.get('model');
        modelsTried.push(model);
        const file = form.get('file');
        assert.equal(file.name, 'turn.webm');
        assert.equal(file.type, 'audio/webm');
        if (model === 'gpt-4o-mini-transcribe') {
          return Response.json({ error: { code: 'model_not_found' } }, { status: 404 });
        }
        return Response.json({ text: 'Check live price for NVDA' });
      },
    },
  );
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.deepEqual(modelsTried, ['gpt-4o-mini-transcribe', 'whisper-1']);
  assert.equal(body.text, 'Check live price for NVDA');
  assert.equal(body.model, 'whisper-1');
});

test('ai-voice sanitizes invalid API key errors without leaking secrets', async () => {
  const res = await handleVoiceRequest(
    new Request('https://example.com/functions/v1/ai-voice', {
      method: 'POST',
      headers: { Authorization: 'Bearer jwt' },
      body: JSON.stringify({ action: 'speech', text: 'Test' }),
    }),
    {
      env: baseEnv,
      authenticate: authOk,
      fetch: async () => Response.json({ error: { message: 'Incorrect key sk-test-secret' } }, { status: 401 }),
    },
  );
  assert.equal(res.status, 502);
  const body = await res.json();
  assert.match(body.error, /secrets is invalid/);
  assert.ok(!body.error.includes('sk-test-secret'));
});
