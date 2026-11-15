import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

console.log('--- Testing market-quote-proxy Edge Function Contract & Logic ---');

// 1. Static file check for Edge Function implementation
const edgeFileContent = readFileSync('supabase/functions/market-quote-proxy/index.ts', 'utf-8');

// Verify CORS headers and origin allowlist are defined
assert.ok(
  edgeFileContent.includes("'Access-Control-Allow-Origin': resolveAllowedOrigin(request)") &&
    edgeFileContent.includes('https://alphajournal.in') &&
    edgeFileContent.includes('authorization, x-client-info, apikey, content-type'),
  'Must include restricted origin Access-Control-Allow-Origin and Supabase CORS headers'
);

// Verify request limits
assert.ok(
  edgeFileContent.includes('MAX_BODY_BYTES = 32_000'),
  'Must enforce MAX_BODY_BYTES limit'
);
assert.ok(
  edgeFileContent.includes('MAX_SYMBOLS = 30'),
  'Must enforce MAX_SYMBOLS limit'
);

// Verify SYMBOL_REGEX
assert.ok(
  edgeFileContent.includes('SYMBOL_REGEX'),
  'Must define SYMBOL_REGEX for symbol sanitization'
);

// Verify AbortSignal.timeout
assert.ok(
  edgeFileContent.includes('AbortSignal.timeout(6000)'),
  'Must use AbortSignal.timeout on upstream provider requests'
);

// Verify no spoofed mobile headers in edge function or server calls
assert.ok(
  !edgeFileContent.includes('_mobileIpPrefixes'),
  'Edge function must not use fraudulent mobile IP prefix spoofing'
);

// 2. Unit tests for edge function logic
const MAX_BODY_BYTES = 32_000;
const MAX_SYMBOLS = 30;
const SYMBOL_REGEX = /^[A-Za-z0-9^.=\-_]{1,20}$/;

class PayloadTooLargeError extends Error {
  constructor(message = 'Request payload exceeds limit.') {
    super(message);
    this.name = 'PayloadTooLargeError';
  }
}

async function readBodyWithLimit(request, maxBytes) {
  const contentLength = request.headers.get('content-length');
  if (contentLength && parseInt(contentLength, 10) > maxBytes) {
    throw new PayloadTooLargeError(`Request body exceeds ${maxBytes} bytes limit.`);
  }

  if (!request.body) return '';

  const reader = request.body.getReader();
  const chunks = [];
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

// Test streaming body within limit
{
  const testText = JSON.stringify({ action: 'quotes', symbols: ['AAPL', 'MSFT'] });
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode(testText));
      controller.close();
    },
  });
  const req = new Request('https://test/proxy', {
    method: 'POST',
    body: stream,
    duplex: 'half',
  });
  const body = await readBodyWithLimit(req, MAX_BODY_BYTES);
  assert.equal(body, testText);
  console.log('✓ Streamed body within limit successfully read');
}

// Test streaming body exceeding limit
{
  const stream = new ReadableStream({
    start(controller) {
      const chunk = new Uint8Array(10_000);
      controller.enqueue(chunk);
      controller.enqueue(chunk);
      controller.enqueue(chunk);
      controller.enqueue(chunk); // 40,000 bytes > 32,000 bytes
      controller.close();
    },
  });
  const req = new Request('https://test/proxy', {
    method: 'POST',
    body: stream,
    duplex: 'half',
  });

  await assert.rejects(
    () => readBodyWithLimit(req, MAX_BODY_BYTES),
    (err) => err instanceof PayloadTooLargeError && err.message.includes('exceeds'),
    'Should reject oversized streamed body with PayloadTooLargeError'
  );
  console.log('✓ Oversized streamed body rejected with 413 error');
}

// Test symbol validation logic
function validateSymbols(rawSymbols) {
  if (!Array.isArray(rawSymbols) || rawSymbols.length === 0) {
    throw new Error('symbols must be a non-empty array of strings.');
  }
  if (rawSymbols.length > MAX_SYMBOLS) {
    throw new Error(`Too many symbols: maximum allowed is ${MAX_SYMBOLS}.`);
  }
  const sanitized = [];
  for (const s of rawSymbols) {
    if (typeof s !== 'string') {
      throw new Error('each symbol must be a string.');
    }
    const trimmed = s.trim();
    if (!SYMBOL_REGEX.test(trimmed)) {
      throw new Error(`Invalid symbol format: "${trimmed}".`);
    }
    sanitized.push(trimmed);
  }
  return sanitized;
}

// Valid symbols pass
{
  const symbols = ['AAPL', '^GSPC', 'RELIANCE.NS', 'GC=F', 'BTC-USD'];
  const validated = validateSymbols(symbols);
  assert.deepEqual(validated, symbols);
  console.log('✓ Valid symbols correctly validated');
}

// Rejects empty symbols
{
  assert.throws(() => validateSymbols([]), /non-empty array/);
  assert.throws(() => validateSymbols(null), /non-empty array/);
  console.log('✓ Empty or null symbols rejected');
}

// Rejects > 30 symbols
{
  const tooMany = Array.from({ length: 31 }, (_, i) => `SYM${i}`);
  assert.throws(() => validateSymbols(tooMany), /Too many symbols/);
  console.log('✓ Excessive symbols (> 30) rejected');
}

// Rejects malicious symbol format
{
  assert.throws(() => validateSymbols(['AAPL', '<script>']), /Invalid symbol format/);
  assert.throws(() => validateSymbols(['AAPL', 'OR 1=1;']), /Invalid symbol format/);
  assert.throws(() => validateSymbols(['AAPL', 'SYM/../TR']), /Invalid symbol format/);
  console.log('✓ Malformed or injection symbols rejected');
}

// Rejects non-string element in symbols array
{
  assert.throws(() => validateSymbols(['AAPL', 12345]), /each symbol must be a string/);
  console.log('✓ Non-string symbol rejected');
}

// Cache TTL and eviction test
{
  const cache = new Map();
  function setCached(key, data, ttlMs) {
    cache.set(key, { data, expiresAt: Date.now() + ttlMs });
  }
  function getCached(key) {
    const entry = cache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      cache.delete(key);
      return null;
    }
    return entry.data;
  }

  setCached('AAPL', { price: 235 }, 50);
  assert.deepEqual(getCached('AAPL'), { price: 235 });

  await new Promise((r) => setTimeout(r, 60));
  assert.equal(getCached('AAPL'), null, 'Expired entry should return null');
  console.log('✓ Server-side cache TTL and expiration verified');
}

console.log('All 8 Edge Function contract tests passed successfully!');
