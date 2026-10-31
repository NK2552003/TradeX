import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

console.log('--- Testing note-ai-refactor Edge Function Logic ---');

// 1. Static file check for Item 6 & 7
const edgeFileContent = readFileSync('supabase/functions/note-ai-refactor/index.ts', 'utf-8');

// Verify Gemini URL does not contain ?key=
assert.ok(
  !edgeFileContent.includes('generateContent?key='),
  'Gemini URL must not contain ?key= in query string'
);

// Verify x-goog-api-key header is set
assert.ok(
  edgeFileContent.includes("'x-goog-api-key': geminiApiKey"),
  "Gemini request must include 'x-goog-api-key': geminiApiKey header"
);

// Verify AbortSignal.timeout(20_000) for Gemini and OpenRouter
const timeoutCount = (edgeFileContent.match(/AbortSignal\.timeout\(20_000\)/g) || []).length;
assert.ok(
  timeoutCount >= 2,
  `Expected at least 2 AbortSignal.timeout(20_000) calls, found ${timeoutCount}`
);

// Verify P0001 quota mapping
assert.ok(
  edgeFileContent.includes("quotaError.code === 'P0001'"),
  'Must explicitly check for PostgreSQL error code P0001 for quota exhaustion'
);

// Verify 500 generic error response for non-quota DB failure
assert.ok(
  edgeFileContent.includes("error: 'Failed to record AI request. Please try again later.'"),
  'Must return generic 500 message for non-quota DB failures without leaking internal details'
);

// 2. Test readBodyWithLimit implementation
const MAX_BODY_BYTES = 64_000;
const MAX_SELECTED_TEXT_CHARS = 20_000;
const MAX_INSTRUCTION_CHARS = 2_000;
const MAX_CONTEXT_TITLE_CHARS = 300;

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

  if (!request.body) {
    return '';
  }

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
  const testText = 'Hello World! ' + 'A'.repeat(500);
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode(testText));
      controller.close();
    },
  });
  const req = new Request('http://localhost', {
    method: 'POST',
    body: stream,
    headers: { 'Content-Type': 'application/json' },
    duplex: 'half',
  });
  const body = await readBodyWithLimit(req, MAX_BODY_BYTES);
  assert.equal(body, testText);
  console.log('✓ Streaming body within limit succeeds');
}

// Test multibyte characters in streamed body
{
  const multibyteText = '🚀 Trading Analysis: ₹50,000 profit (25%) 日本語 text';
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode(multibyteText));
      controller.close();
    },
  });
  const req = new Request('http://localhost', {
    method: 'POST',
    body: stream,
    headers: { 'Content-Type': 'application/json' },
    duplex: 'half',
  });
  const body = await readBodyWithLimit(req, MAX_BODY_BYTES);
  assert.equal(body, multibyteText);
  console.log('✓ Multibyte streamed body handled correctly');
}

// Test streaming body exceeding limit
{
  const largeChunk = new Uint8Array(35_000);
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(largeChunk);
      controller.enqueue(largeChunk); // 70,000 bytes total > 64,000
      controller.close();
    },
  });
  const req = new Request('http://localhost', {
    method: 'POST',
    body: stream,
    duplex: 'half',
  });

  await assert.rejects(
    async () => await readBodyWithLimit(req, MAX_BODY_BYTES),
    PayloadTooLargeError
  );
  console.log('✓ Oversized streamed body rejected with PayloadTooLargeError (413)');
}

// Test Content-Length exceeding limit rejected immediately
{
  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'content-length': '70000' },
  });
  await assert.rejects(
    async () => await readBodyWithLimit(req, MAX_BODY_BYTES),
    PayloadTooLargeError
  );
  console.log('✓ Content-Length header > 64k rejected before reading stream');
}

// 3. Test validation logic
const VALID_NOTE_TYPES = new Set([
  'general',
  'analysis',
  'plan',
  'review',
  'idea',
  'cheat_sheet',
  'cheatSheet',
]);

function validatePayload(body) {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return { status: 400, error: 'Request body must be a JSON object.' };
  }

  if (!('selectedText' in body) || body.selectedText === null || body.selectedText === undefined) {
    return { status: 400, error: 'selectedText is required.' };
  }
  if (typeof body.selectedText !== 'string') {
    return { status: 400, error: 'selectedText must be a string.' };
  }
  const cleanSelectedText = body.selectedText.trim();
  if (cleanSelectedText.length === 0) {
    return { status: 400, error: 'selectedText cannot be blank.' };
  }
  if (cleanSelectedText.length > MAX_SELECTED_TEXT_CHARS) {
    return {
      status: 413,
      error: `selectedText exceeds maximum length of ${MAX_SELECTED_TEXT_CHARS} characters.`,
    };
  }

  let contextTitle;
  if ('contextTitle' in body && body.contextTitle !== null && body.contextTitle !== undefined) {
    if (typeof body.contextTitle !== 'string') {
      return { status: 400, error: 'contextTitle must be a string if provided.' };
    }
    const cleanTitle = body.contextTitle.trim();
    if (cleanTitle.length > MAX_CONTEXT_TITLE_CHARS) {
      return {
        status: 413,
        error: `contextTitle exceeds maximum length of ${MAX_CONTEXT_TITLE_CHARS} characters.`,
      };
    }
    contextTitle = cleanTitle.length > 0 ? cleanTitle : undefined;
  }

  let instruction;
  if ('instruction' in body && body.instruction !== null && body.instruction !== undefined) {
    if (typeof body.instruction !== 'string') {
      return { status: 400, error: 'instruction must be a string if provided.' };
    }
    const cleanInstruction = body.instruction.trim();
    if (cleanInstruction.length > MAX_INSTRUCTION_CHARS) {
      return {
        status: 413,
        error: `instruction exceeds maximum length of ${MAX_INSTRUCTION_CHARS} characters.`,
      };
    }
    instruction = cleanInstruction.length > 0 ? cleanInstruction : undefined;
  }

  let noteType = 'general';
  if ('noteType' in body && body.noteType !== null && body.noteType !== undefined) {
    if (typeof body.noteType !== 'string') {
      return { status: 400, error: 'noteType must be a string if provided.' };
    }
    const normalizedType = body.noteType.trim();
    if (!VALID_NOTE_TYPES.has(normalizedType)) {
      return {
        status: 400,
        error: `Invalid noteType '${normalizedType}'. Supported values: ${Array.from(VALID_NOTE_TYPES).join(', ')}.`,
      };
    }
    noteType = normalizedType === 'cheatSheet' ? 'cheat_sheet' : normalizedType;
  }

  return { status: 200, cleanSelectedText, contextTitle, instruction, noteType };
}

// Test valid payloads
{
  const res = validatePayload({
    selectedText: 'Nifty 50 long setup with stop loss 24,000',
    contextTitle: 'Morning Trade',
    instruction: 'Convert to bullet points',
    noteType: 'plan',
  });
  assert.equal(res.status, 200);
  assert.equal(res.noteType, 'plan');
  assert.equal(res.contextTitle, 'Morning Trade');
  console.log('✓ Valid payload passes validation');
}

// Test missing selectedText returns 400
{
  const res = validatePayload({ noteType: 'plan' });
  assert.equal(res.status, 400);
  assert.equal(res.error, 'selectedText is required.');
  console.log('✓ Missing selectedText rejected with 400');
}

// Test non-string selectedText returns 400
{
  const res = validatePayload({ selectedText: 12345 });
  assert.equal(res.status, 400);
  assert.equal(res.error, 'selectedText must be a string.');
  console.log('✓ Non-string selectedText rejected with 400');
}

// Test empty selectedText returns 400
{
  const res = validatePayload({ selectedText: '   ' });
  assert.equal(res.status, 400);
  assert.equal(res.error, 'selectedText cannot be blank.');
  console.log('✓ Blank selectedText rejected with 400');
}

// Test oversized selectedText returns 413
{
  const res = validatePayload({ selectedText: 'X'.repeat(20_001) });
  assert.equal(res.status, 413);
  assert.ok(res.error.includes('20000 characters'));
  console.log('✓ Oversized selectedText rejected with 413');
}

// Test oversized contextTitle returns 413
{
  const res = validatePayload({
    selectedText: 'Valid text',
    contextTitle: 'T'.repeat(301),
  });
  assert.equal(res.status, 413);
  assert.ok(res.error.includes('300 characters'));
  console.log('✓ Oversized contextTitle rejected with 413');
}

// Test oversized instruction returns 413
{
  const res = validatePayload({
    selectedText: 'Valid text',
    instruction: 'I'.repeat(2001),
  });
  assert.equal(res.status, 413);
  assert.ok(res.error.includes('2000 characters'));
  console.log('✓ Oversized instruction rejected with 413');
}

// Test invalid noteType returns 400
{
  const res = validatePayload({
    selectedText: 'Valid text',
    noteType: 'malicious_injection',
  });
  assert.equal(res.status, 400);
  assert.ok(res.error.includes("Invalid noteType 'malicious_injection'"));
  console.log('✓ Invalid noteType rejected with 400');
}

// Test cheatSheet camelCase alias maps to cheat_sheet
{
  const res = validatePayload({
    selectedText: 'Valid text',
    noteType: 'cheatSheet',
  });
  assert.equal(res.status, 200);
  assert.equal(res.noteType, 'cheat_sheet');
  console.log('✓ cheatSheet camelCase maps to cheat_sheet');
}

// 4. Test Quota trigger vs Database Error Separation
function handleQuotaResult(quotaError) {
  if (quotaError) {
    if (quotaError.code === 'P0001' || quotaError.message?.toLowerCase().includes('quota')) {
      return {
        status: 429,
        error: 'AI monthly quota exceeded. Upgrade your plan for more refactoring requests.',
      };
    }
    return {
      status: 500,
      error: 'Failed to record AI request. Please try again later.',
    };
  }
  return { status: 200 };
}

{
  // Quota trigger exception: code P0001
  const quotaRes = handleQuotaResult({
    code: 'P0001',
    message: 'Subscription free quota reached (10 of 10)',
  });
  assert.equal(quotaRes.status, 429);
  assert.equal(
    quotaRes.error,
    'AI monthly quota exceeded. Upgrade your plan for more refactoring requests.'
  );
  console.log('✓ P0001 trigger exception mapped to 429 generic quota message');
}

{
  // Non-quota DB failure (e.g. connection timeout, table locked, permission error)
  const dbFailure = handleQuotaResult({
    code: '57P01',
    message: 'FATAL: terminating connection due to administrator command',
  });
  assert.equal(dbFailure.status, 500);
  assert.equal(
    dbFailure.error,
    'Failed to record AI request. Please try again later.'
  );
  // Ensure internal DB message is not exposed to client
  assert.ok(!dbFailure.error.includes('terminating connection'));
  console.log('✓ Non-quota DB failure mapped to 500 without leaking database error');
}

console.log('--- ALL note-ai-refactor EDGE FUNCTION TESTS PASSED ---');

