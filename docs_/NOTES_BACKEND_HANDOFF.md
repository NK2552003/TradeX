# TradeX trader notes backend integration

The notes feature currently runs against an in-memory demo repository. The UI and presentation layers interact exclusively through an abstract interface. Connecting the live backend requires implementing the repository interface, configuring a storage bucket, deploying one Edge Function, and updating the initialization scope.

- Interface: [lib/features/notes/data/notes_repository.dart](../lib/features/notes/data/notes_repository.dart)
- Model: `AppNote` / `AppNoteType` in [lib/core/app-ui/models/app_models.dart](../lib/core/app-ui/models/app_models.dart)
- Schema: [database/migrations/007_trader_notes.sql](../database/migrations/007_trader_notes.sql), policies in [database/rls_policies.sql](../database/rls_policies.sql)

## 1. Tables

The feature uses `trader_notes`, `trader_note_attachments`, `trader_note_likes`, `trader_note_comments`, and `trader_note_views`. Apply `migrations/007_trader_notes.sql` and `008_trader_note_engagement.sql`, then execute `rls_policies.sql`. The initial migrations enable row-level security without granting permissions, so the policy script must be executed before access is permitted.

### Database column and model field mapping

| Column | `AppNote` field | Notes |
| --- | --- | --- |
| `id` | `id` | An empty string represents an unsaved draft; execute an insert rather than an update. |
| `user_id` | `userId` | Assigned on the server via `auth.uid()`; do not accept client-provided user IDs. |
| `title` | `title` | May be left empty; the user interface displays "Untitled note". |
| `content` | `content` | Raw Markdown, representing the single source of truth for the note body. |
| `note_type` | `noteType` | Handled via `AppNoteType.wireId` and `AppNoteType.fromId`. Converts `cheatSheet` to `cheat_sheet`; unrecognized strings default to `general`. |
| `tags` | `tags` | Stored without a leading `#` symbol. |
| `linked_tickers` | `linkedTickers` | Stored without a leading `$` symbol. |
| `strategy_id` | `strategyId` | References `strategies.id`. Set to null if the associated strategy is deleted. |
| (joined) | `strategyName` | Computed field. Join `strategies.name` or leave null to display the identifier. |
| `linked_journal_ids` | `linkedJournalIds` | Array of `journal_entries.id` values. Relational foreign keys cannot attach to an array; resolve matching rows and omit missing entries. |
| `is_public` | `isPublic` | Governs the `trader_notes_public_read` policy. |
| `view_count`, `like_count` | `viewCount`, `likeCount` | Counters managed automatically by triggers. Do not write to these columns from the client. |
| `word_count`, `checklist_done`, `checklist_total`, `has_images`, `has_code` | Same | Derived from `content` using `AppNote.withDerivedCounts()` before each write. |
| `created_at`, `updated_at` | `createdAt`, `updatedAt` | `updated_at` is updated automatically by `trg_trader_notes_updated_at`. |

## 2. API contract

The `NotesRepository` interface defines all required backend calls:

| Method | Supabase call |
| --- | --- |
| `watchAll()` | `from('trader_notes').stream(primaryKey: ['id']).eq('user_id', uid).order('updated_at', ascending: false)` or a `select()` query paired with a Realtime channel. Emits an initial snapshot. Queries for public viewing select `is_public = true` and hydrate counters separately. |
| `watchPublic()` | Streams rows from `trader_notes` where `is_public = true` ordered newest first, joining the active user's like state and comment profile data. Edit and delete controls are disabled for public streams. |
| `recordView(id)` | Inserts `(note_id, user_id)` into `trader_note_views` ignoring conflicts. The associated trigger increments `view_count`. |
| `toggleLike(id)` | Inserts or deletes rows in `trader_note_likes`. The database trigger updates `like_count`. |
| `addComment(id, body)` | Inserts a row into `trader_note_comments` and returns the note with author profile metadata joined. |
| `fetchAll()` | `select().eq('user_id', uid).order('updated_at', ascending: false)` |
| `getById(id)` | `select().eq('id', id).maybeSingle()` |
| `create(draft)` | `insert(payload).select().single()`, ignoring `draft.id` |
| `update(note)` | `update(payload).eq('id', note.id).select().single()` |
| `delete(id)` | `delete().eq('id', id)`, with attachments cascading on delete |
| `uploadAttachment(noteId, file)` | Uploads files to `note-attachments`, inserts a row into `trader_note_attachments`, and returns the `storage_path`. This returned path is written directly into the markdown body. |
| `resolveAttachmentUrl(ref)` | Generates a signed URL: `createSignedUrl(ref, 3600)` |

Failures should throw exceptions rather than returning empty payloads, allowing callers to display errors through `UiToast.error`.

## 3. Storage bucket configuration

Configure a private bucket named `note-attachments`:

- Maximum file size: 10 MB per object (matching the database `byte_size` CHECK constraint).
- Allowed MIME types: `image/*`, `application/pdf`, and `text/*`.
- Object key format: `<user_id>/<note_id>/<uuid><ext>`, enabling path prefix matching in storage policies.
- Access: generate signed URLs with a 1-hour expiration. The client caches resolved URLs during the active session.

Storage access policies match table permissions: note authors have full access to objects under their `user_id` prefix, while readers of public notes receive `SELECT` access for objects linked to that note.

## 4. Edge Function: note-ai-refactor

This function powers the selection toolbar (`AiRefactorBar`) in the rich text editor for quick rewrites and custom prompts. The client interface is `NoteAiRefactor.enhance()` in [lib/features/notes/data/note_ai_refactor.dart](../lib/features/notes/data/note_ai_refactor.dart).

Request payload (`noteType` matches `AppNoteType.wireId`):

```json
{
  "selectedText": "string, required",
  "contextTitle": "string, optional, the note title",
  "instruction": "string, optional, user custom prompt",
  "noteType": "general | analysis | plan | review | idea | cheat_sheet"
}
```

Response payload:

```json
{ "enhanced": "string, markdown replacing the selection" }
```

Requirements:

- Validate caller JWT credentials via `Authorization: Bearer <access_token>` and return 401 for unauthenticated requests.
- Return raw Markdown only without enclosing backtick fences or conversational filler. The client substitutes the response text directly into the selected range.
- Maintain formatting structures: list items must return as lists, and tables must return as tables.
- Enforce per-user rate limits and record invocations in `ai_insight_requests` with `kind = 'note_refactor'`.
- On non-200 responses, leave the editor content unchanged and return an error message: `{ "error": "..." }`.

## 5. Integration checklist

1. Apply `migrations/007_trader_notes.sql`, `008_trader_note_engagement.sql`, and `rls_policies.sql`.
2. Create the `note-attachments` storage bucket with the specified size and MIME rules.
3. Create `SupabaseNotesRepository implements NotesRepository`, adhering strictly to the interface methods.
4. Update the initialization entrypoint to call `NotesRepositoryScope.override(SupabaseNotesRepository())`.
5. Connect `uploadAttachment` and `resolveAttachmentUrl` to Supabase Storage.
6. Deploy `note-ai-refactor`, implement `EdgeNoteAiRefactor implements NoteAiRefactor`, and inject it via `NoteAiScope.override(EdgeNoteAiRefactor())`.
7. Verify the complete flow: create a note, upload an attachment, publish it publicly, view it from another account to verify view and like counters, add a comment, export as PDF, and toggle the note back to private.
