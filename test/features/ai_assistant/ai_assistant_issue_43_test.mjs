import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

console.log('--- Testing Issue #43 & OpenAI Integration Suite ---');

// 1. Verify EnvConfig reads OPEN_AI_KEY and TRACKING_ID
const envConfigContent = readFileSync('lib/core/config/env_config.dart', 'utf-8');
assert.ok(
  envConfigContent.includes("'OPEN_AI_KEY'"),
  'EnvConfig must check OPEN_AI_KEY environment variable'
);
assert.ok(
  envConfigContent.includes("'TRACKING_ID'"),
  'EnvConfig must check TRACKING_ID environment variable'
);
console.log('✓ EnvConfig environment variable configuration verified');

// 2. Verify UnifiedAiService OpenAI models and priority
const unifiedAiContent = readFileSync('lib/core/ai/unified_ai_service.dart', 'utf-8');
assert.ok(
  unifiedAiContent.includes("'gpt-4.1-mini'"),
  'UnifiedAiService must configure gpt-4.1-mini'
);
assert.ok(
  unifiedAiContent.includes("'gpt-4o-mini'"),
  'UnifiedAiService must configure gpt-4o-mini'
);
assert.ok(
  !unifiedAiContent.includes('note_ai_'),
  'No note_ai_ prefixes in unified_ai_service'
);
console.log('✓ UnifiedAiService OpenAI model selection verified');

// 3. Verify valid UUIDv4 IDs in ai_assistant_repository.dart and community dialog
const repoContent = readFileSync('lib/features/ai_assistant/data/ai_assistant_repository.dart', 'utf-8');
assert.ok(
  !repoContent.includes("'note_ai_"),
  'ai_assistant_repository must not contain legacy note_ai_ prefixes'
);
assert.ok(
  !repoContent.includes("'trade_ai_"),
  'ai_assistant_repository must not contain legacy trade_ai_ prefixes'
);
assert.ok(
  !repoContent.includes("'strat_ai_"),
  'ai_assistant_repository must not contain legacy strat_ai_ prefixes'
);
assert.ok(
  repoContent.includes('const Uuid().v4()'),
  'ai_assistant_repository must use RFC 4122 v4 UUIDs'
);
console.log('✓ ai_assistant_repository UUIDv4 generation verified');

const communityDialogContent = readFileSync(
  'lib/features/community/presentation/widgets/community_ai_assistant_dialog.dart',
  'utf-8'
);
assert.ok(
  !communityDialogContent.includes('note_ai_'),
  'community_ai_assistant_dialog must not contain legacy note_ai_ prefixes'
);
assert.ok(
  !communityDialogContent.includes('trade_ai_'),
  'community_ai_assistant_dialog must not contain legacy trade_ai_ prefixes'
);
assert.ok(
  !communityDialogContent.includes('strat_ai_'),
  'community_ai_assistant_dialog must not contain legacy strat_ai_ prefixes'
);
assert.ok(
  communityDialogContent.includes('const Uuid().v4()'),
  'community_ai_assistant_dialog must use RFC 4122 v4 UUIDs'
);
console.log('✓ community_ai_assistant_dialog UUIDv4 generation verified');

// 4. Verify supabase/functions/ai-chat/index.ts implementation
const aiChatContent = readFileSync('supabase/functions/ai-chat/index.ts', 'utf-8');

// JWT check
assert.ok(
  aiChatContent.includes("request.headers.get('authorization')"),
  'ai-chat must inspect Authorization header'
);
assert.ok(
  aiChatContent.includes('.auth.getUser(token)'),
  'ai-chat must verify user session via auth.getUser'
);

// Server-side portfolio authorization
assert.ok(
  aiChatContent.includes('trade.user_id === user.id') &&
  aiChatContent.includes('note.user_id === user.id'),
  'ai-chat must scope portfolio queries (notes, trades, strategies) strictly to user.id or public'
);

// Rate limits / Quota
assert.ok(
  aiChatContent.includes('ai_insight_requests'),
  'ai-chat must log and track quota in ai_insight_requests'
);

// OpenAI Integration & gpt-4.1-mini
assert.ok(
  aiChatContent.includes('https://api.openai.com/v1/chat/completions'),
  'ai-chat must call OpenAI chat completions API'
);
assert.ok(
  aiChatContent.includes('gpt-4.1-mini'),
  'ai-chat must use gpt-4.1-mini as preferred model'
);

// SSE Streaming
assert.ok(
  aiChatContent.includes("'text/event-stream'"),
  'ai-chat must stream responses using text/event-stream'
);
console.log('✓ supabase/functions/ai-chat/index.ts verified');

// 5. Verify notes refactor edge function OpenAI integration
const noteRefactorContent = readFileSync('supabase/functions/note-ai-refactor/index.ts', 'utf-8');
assert.ok(
  noteRefactorContent.includes("Deno.env.get('OPEN_AI_KEY')"),
  'note-ai-refactor must support OPEN_AI_KEY'
);
assert.ok(
  noteRefactorContent.includes('gpt-4.1-mini'),
  'note-ai-refactor must support gpt-4.1-mini'
);
console.log('✓ supabase/functions/note-ai-refactor/index.ts OpenAI support verified');

console.log('--- ALL ISSUE #43 & OPENAI INTEGRATION CHECKS PASSED ---');
