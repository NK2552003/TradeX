# 08 AI Assistant

## Scope

The AI assistant currently owns local thread state and uses seeded replies so
the UI can be exercised without a provider. Creation drafts already pass
through the Notes, Journal, Strategies, and Community repository boundaries.
The backend replaces response generation and persistence; it does not change
the assistant widgets.

The create-sheet layout is covered by
`test/features/ai_assistant/ai_create_sheet_test.dart`: every supported target
must open a usable, populated form without a layout exception.

## Security model

- Flutter sends the authenticated Supabase JWT to an Edge Function, never an
  OpenAI/Anthropic/Gemini key.
- The Edge Function verifies the JWT, derives the user id, enforces tier and
  rate limits, and records auditable request metadata.
- Resolve all referenced notes, trades, strategies, and portfolio facts
  server-side. Do not trust client-supplied ownership, public visibility, or
  record text.
- Context is private to the requesting account. Community or public record
  context can be used only if it is currently public; private records of other
  users are never prompt material.
- Log request ids, model id, token counts, latency, outcome, and a content
  digest/redacted summary. Do not log unredacted private prompts or provider
  credentials.

## Suggested tables

`ai_insights` and `ai_insight_requests` already exist in the schema. Add these
through a new ordered migration before enabling persistent conversations:

| Table | Required fields | Access |
| --- | --- | --- |
| `ai_threads` | `id`, `user_id`, `title`, `persona`, `created_at`, `updated_at`, `archived_at` | owner only |
| `ai_messages` | `id`, `thread_id`, `role`, `body`, `sources jsonb`, `model`, `prompt_tokens`, `completion_tokens`, `created_at` | owner only |
| `ai_request_audit` | `id`, `user_id`, `thread_id`, `request_id`, `kind`, `model`, `status`, `token_count`, `latency_ms`, `created_at` | service role writes; owner may read a safe summary if needed |

Foreign-key `ai_threads.user_id` to `profiles(id)` and cascade messages when a
thread is deleted. Enable RLS on all three tables. The client must never insert
assistant-role messages directly; the Edge Function does that after a provider
response succeeds.

## Edge Function contract

Implement `ai-chat` as an authenticated Edge Function. It should return a
streaming response using Server-Sent Events (or a Supabase Realtime relay when
SSE is not available on a target platform).

### Request

```json
{
  "threadId": "uuid or null for a new thread",
  "persona": "swing",
  "message": "Review my position sizing",
  "context": {
    "recordRefs": [{"kind": "note", "id": "uuid"}],
    "screen": "journal"
  }
}
```

`recordRefs` are identifiers, not client-provided record bodies. The server
loads and authorizes them. Reject unknown kinds, records owned by another user,
and context that exceeds the model’s configured budget.

### Events

```text
event: thread
data: {"threadId":"..."}

event: delta
data: {"messageId":"...","text":"Risk per trade should..."}

event: source
data: {"kind":"note","id":"...","title":"Sizing rules"}

event: complete
data: {"messageId":"...","usage":{"inputTokens":420,"outputTokens":180}}

event: error
data: {"code":"rate_limited","message":"Try again in 30 seconds."}
```

Persist the user message before calling the provider. Persist assistant content
atomically on `complete`; mark interrupted output as incomplete rather than
presenting it as a final recommendation. Idempotency is required: accept a
client-generated request id and return the already-created result on retry.

## Create-from-AI contract

The client offers these targets:

| Target | Backend mutation | Visibility rule |
| --- | --- | --- |
| Research note | Create `trader_notes` | Starts private unless the owner explicitly selects public. |
| Journal trade | Create `journal_entries` | Owner-only by default; never auto-publish trade execution data. |
| Strategy playbook | Create `strategies` and its initial version | Private unless explicitly published. |
| Community post | Create `posts` | A referenced Writing Desk source must be public and owned by the caller. |
| Chart analysis | Generate/persist an AI message or draft only | It creates no record until the user selects an export target. |

Validate generation output against the same server-side schemas used for normal
creation. The assistant cannot bypass validation, RLS, size limits, moderation,
or source visibility rules.

## Client integration plan

1. Add a transport abstraction beneath `AiAssistantRepository`; keep its
   `ChangeNotifier` read API stable for the views.
2. On send, append an optimistic pending message, call `ai-chat`, and update it
   from `delta` events. Remove the seeded `Timer` reply implementation once the
   stream is live.
3. Load thread history and persisted messages by owner-only queries.
4. For creation, submit the reviewed draft to the normal feature service—not
   directly to an AI table—then return the resulting typed record id for
   navigation.
5. Surface authorization, provider, validation, and rate-limit failures as
   actionable UI errors without discarding the compose text.

## Acceptance checks

- A thread survives app restart and cannot be fetched by another account.
- A response receives more than one streaming `delta` event before `complete`.
- Retrying the same request id does not duplicate a user or assistant message.
- The provider key is absent from the Flutter build, `.env` assets, logs, and
  API responses.
- AI-created notes/strategies honor the selected private/public state; AI-created
  posts cannot expose a private attachment.
- Every create target continues to pass the creation-sheet widget test.
