import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  createEdgeRequestLogger,
  describeError,
  sanitizeLogDetails,
} from '../supabase/functions/_shared/logger.ts';

test('sanitizeLogDetails redacts credentials and PII while preserving safe telemetry', () => {
  const cleaned = sanitizeLogDetails({
    authorization: 'Bearer secret-jwt',
    email: 'trader@example.com',
    prompt: 'Analyze NVDA entry',
    nested: {
      apikey: 'anon-key',
      provider: 'openai',
    },
    model: 'gpt-4.1-mini',
    duration_ms: 142,
  });

  assert.equal(cleaned.authorization, '[redacted]');
  assert.equal(cleaned.email, '[redacted]');
  assert.equal(cleaned.prompt, '[redacted]');
  assert.equal(cleaned.nested.apikey, '[redacted]');
  assert.equal(cleaned.nested.provider, 'openai');
  assert.equal(cleaned.model, 'gpt-4.1-mini');
  assert.equal(cleaned.duration_ms, 142);
});

test('createEdgeRequestLogger emits structured JSON across info, warn, and error statuses', () => {
  const logs = [];
  const errors = [];
  const origLog = console.log;
  const origError = console.error;
  console.log = (msg) => logs.push(msg);
  console.error = (msg) => errors.push(msg);

  try {
    const req = new Request('https://example.supabase.co/functions/v1/ai-gateway', {
      method: 'POST',
      headers: { 'x-request-id': 'req-123' },
    });
    const logger = createEdgeRequestLogger('ai-gateway', req);
    logger.finish(new Response('{}', { status: 200 }), { model: 'gpt-4.1-mini' });
    logger.finish(new Response('{}', { status: 401 }));
    logger.finish(new Response('{}', { status: 503 }), describeError(new Error('Upstream timeout')));
  } finally {
    console.log = origLog;
    console.error = origError;
  }

  assert.equal(logs.length, 2);
  assert.equal(errors.length, 1);

  const okEvent = JSON.parse(logs[0]);
  assert.equal(okEvent.source, 'supabase_edge_function');
  assert.equal(okEvent.fn, 'ai-gateway');
  assert.equal(okEvent.request_id, 'req-123');
  assert.equal(okEvent.level, 'info');
  assert.equal(okEvent.status, 200);
  assert.equal(okEvent.model, 'gpt-4.1-mini');

  const warnEvent = JSON.parse(logs[1]);
  assert.equal(warnEvent.level, 'warn');
  assert.equal(warnEvent.status, 401);

  const errEvent = JSON.parse(errors[0]);
  assert.equal(errEvent.level, 'error');
  assert.equal(errEvent.status, 503);
  assert.equal(errEvent.error_message, 'Upstream timeout');
});

test('supabase config, wrangler observability, Edge Functions, and migration stay aligned', () => {
  const configToml = readFileSync('supabase/config.toml', 'utf8');
  assert.match(configToml, /\[analytics\]\s+enabled\s*=\s*true/);
  for (const fn of [
    'admin-delete-user',
    'ai-gateway',
    'ai-voice',
    'ai-chat',
    'note-ai-refactor',
    'create-business-checkout',
    'market-quote-proxy',
    'push-dispatch',
    'razorpay-webhook',
    'revenuecat-webhook',
  ]) {
    assert.ok(configToml.includes(`[functions.${fn}]`), `Missing config.toml entry for ${fn}`);
    const edgeSource = readFileSync(`supabase/functions/${fn}/index.ts`, 'utf8');
    assert.ok(
      edgeSource.includes("../_shared/logger.ts"),
      `Expected ${fn}/index.ts to use _shared/logger.ts`,
    );
  }

  const wranglerRaw = readFileSync('wrangler.jsonc', 'utf8');
  const wrangler = JSON.parse(wranglerRaw);
  assert.equal(wrangler.observability?.enabled, true);
  assert.equal(wrangler.observability?.logs?.enabled, true);
  assert.equal(wrangler.observability?.traces?.enabled, true);

  const migration = readFileSync(
    'supabase/migrations/20261115133500_system_runtime_logs.sql',
    'utf8',
  );
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.system_runtime_logs/);
  assert.match(migration, /ENABLE ROW LEVEL SECURITY/);
  assert.match(migration, /\(SELECT tradex_private\.is_admin\(\)\)/);
  assert.match(migration, /tradex_private\.prune_system_runtime_logs/);
});
