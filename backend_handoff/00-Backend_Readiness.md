# TradeX backend readiness

## Purpose and current boundary

TradeX is a Flutter client with repository interfaces already separating UI
from data access. Several implementations intentionally use in-memory demo
data. Backend work therefore has two parts: apply the Supabase schema/RLS
contract and provide live implementations behind the existing repository
interfaces. Do not add provider keys, service-role keys, or direct database
queries to widgets.

Read [database/README.md](../database/README.md) before making changes. Its
schema, ordered migrations, RLS policies, storage policies, and public-read
function are the source of truth.

## Frontend fixes already landed

- AI creation sheets now lay out safely for note, journal, strategy, post, and
  chart-analysis targets. Targeted AI capability cards open their matching
  creation flow instead of merely sending a seed prompt.
- Cross-feature destination history is retained in the application shell, so a
  system back action returns to the source destination after a linked jump.
- Community setup actions now create a journal draft, direct-message actions
  open a recipient-preselected compose dialog, and article/share actions call
  the platform URL/share integrations.
- Public/private enforcement remains a backend release gate: current demo
  repositories are not authorization boundaries and must not be used in a
  production deployment.

## Release gates

| Gate | Required evidence |
| --- | --- |
| Auth | A signed-in caller can read and mutate only their own private records. The server derives `user_id` from the JWT. |
| Public source safety | An anonymous read of a private note, journal entry, or strategy returns no data. A public post cannot attach a private record. |
| Storage | Object keys are `<user_id>/<parent_id>/<uuid><extension>` and signed URL generation obeys the same ownership/public policy as its parent row. |
| Realtime | A message event is visible only to its participants; read receipts and presence never leak to unrelated users. |
| AI | The provider credential exists only in an Edge Function/server environment. Requests are authenticated, rate-limited, audited, and have a bounded context window. |
| Client swap | Startup calls the appropriate `*RepositoryScope.override(...)` methods with live implementations. Demo repositories are not registered in production. |

## Public and private sources

The product vocabulary in [CONTEXT.md](../CONTEXT.md) is intentional:

- A **private record** belongs to its owner’s workspace. Its body, linked
  records, execution data, and attachments are never valid public-source data.
- A **public record** was explicitly published by its owner. Publication is
  reversible; revoking it must immediately make it unavailable through public
  read paths.
- A community post may reference **one** Writing Desk source: one note, one
  journal entry, or one strategy. It is a post attachment, not an implicit
  grant to every linked record.
- Internal `tradex://` links are authenticated-app navigation only. They are
  not web sharing URLs and must still pass authorization at the destination.

Use `public_document(kind, id)` for anonymous document reads. It projects only
safe public fields and prevents graph mirror arrays from exposing private
workspace relationships. Do not replace it with a broad table `SELECT`.

### Community and public sources

The `posts` table has `note_id`, `journal_entry_id`, and `strategy_id`, with a
database check that allows at most one of them. Before insert or update, the
backend must verify all of the following in one transaction:

1. The caller owns the attached record.
2. That record is publicly readable at commit time.
3. The post contains no second source id.
4. The serialized post payload includes only the attachment preview returned
   by the public-source projection—not the record body, link arrays, or private
   attachment paths.

If a source becomes private or is deleted, retain the post but clear or hide
its attachment in the response. Never cache a formerly valid public preview
without re-checking visibility.

## Messages and Realtime

The current `MessagesRepository` documents the required mutations and still
contains demo simulation. Replace it with a live implementation that:

1. Creates a canonical direct conversation (participant ids ordered) or a
   group conversation via a participants table if group chat is enabled.
2. Inserts messages with `sender_id = auth.uid()` and broadcasts through a
   private Supabase Realtime channel authorized by conversation membership.
3. Marks read receipts server-side and returns the resulting state to both
   sender and recipient.
4. Cancels every stream/channel when a user leaves, blocks, deletes, or
   navigates away from a conversation.
5. Validates any record-sharing payload against the source’s current visibility
   before rendering a preview.

Do not implement the client’s current timer-based auto replies in production.

## Navigation and internal links

The current shell receives an `AppLinkRef` and performs an authorized
destination transition. Backend APIs should return record ids and a stable type
(`note`, `journal`, `strategy`, `ticker`, `post`, `message`, or `ai_thread`),
not pre-authorized screen URLs. The client builds internal links with
`AppDeepLink`; every fetched record still requires an ownership/public check.

For external mobile deep links, register the app/universal-link domains only
after the API can resolve the target safely. A link must open the sign-in flow
first when no session exists, then retry the original target after auth.

## Client integration seams

| Feature | Interface or repository to replace |
| --- | --- |
| Notes | `lib/features/notes/data/notes_repository.dart` |
| Journal | `lib/features/journal/data/journal_repository.dart` |
| Strategies | `lib/features/strategies/data/strategies_repository.dart` |
| Community | `lib/features/community/data/community_repository.dart` |
| Messages | `lib/features/messages/data/messages_repository.dart` |
| AI | `lib/features/ai_assistant/data/ai_assistant_repository.dart` or a transport injected beneath it |

Use the UI-facing model types as the mapping contract. Preserve errors rather
than returning an empty list or null for failed writes: the UI can then show a
toast and preserve the user’s draft.

## Verification matrix

Run this with two normal accounts plus an anonymous client before release:

| Scenario | Expected result |
| --- | --- |
| Account A creates a private note | Only A can read, update, attach, or link it. |
| A makes a note public, then B opens it | B receives the public projection only; public attachment URLs work. |
| A makes that note private again | B’s next fetch and signed URL request fail; existing UI removes the preview. |
| A tries to attach a private journal record to a post | The mutation is rejected. |
| A sends B a DM | Only A and B receive the Realtime event and receipt update. |
| A asks the AI assistant to create a note/journal/strategy/post | The server validates the draft, persists through the matching service, and returns the new id. |
| A follows an internal link that they cannot access | The destination shows an access/not-found state; no metadata leaks. |
