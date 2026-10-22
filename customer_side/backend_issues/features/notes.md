# Backend Feature Audit: Notes & AI Refactor

**Component:** `lib/features/notes/`  
**Database Tables:** `public.trader_notes`, `public.trader_note_attachments`  
**Storage Bucket:** `note-attachments`  
**Files Evaluated:**  
- `lib/features/notes/data/notes_repository.dart`  
- `lib/features/notes/data/note_ai_refactor.dart`  

---

## 1. Supabase Storage 100% Upload Rejection

- **Folder Path Mismatch (`notes_repository.dart:746-752`):**
  - Uploads to `$noteId/$fileName`.
  - SQL policy requires `(storage.foldername(name))[1] = auth.uid()`.
  - Storage rejects upload with 403 Forbidden.
  - **Action:** Update path to `${auth.uid()}/$noteId/$fileName`.
- **Private Bucket URLs:**
  - `resolveAttachmentUrl` calls `.getPublicUrl()` on private bucket `note-attachments`.
  - **Action:** Replace with `createSignedUrl()`.

---

## 2. Disconnected AI Copilot Edge Function

- **Simulated Local Regex (`note_ai_refactor.dart:27-55`):**
  - Uses `NoteAiRefactorDemo` with `Future.delayed(650ms)` and local string splitting.
  - Planned Supabase Edge Function `functions/v1/note-ai-refactor` is not wired.
  - **Action:** Deploy Edge Function calling Anthropic/Gemini and wire client to invoke it with authenticated JWT.
