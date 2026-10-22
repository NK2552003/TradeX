# Backend Feature Audit: AI Assistant & Copilot

**Component:** `lib/features/ai_assistant/`  
**Database Tables:** `public.ai_conversations`, `public.ai_messages`, `public.trader_notes`  
**Files Evaluated:**  
- `lib/features/ai_assistant/data/ai_assistant_repository.dart`  

---

## 1. Non-UUID Type Syntax Error (Error `22P02`)

- **Synthetic ID String Rejection (`ai_assistant_repository.dart:398`):**
  - Generates note ID string `'note_ai_${uid}'` and attempts to insert it into `trader_notes.id` (`UUID PRIMARY KEY`).
  - PostgreSQL throws `ERROR: 22P02: invalid input syntax for type uuid: "note_ai_..."`.
  - **Action:** Generate standard `Uuid().v4()` strings.

---

## 2. 0% Real LLM Call Backend

- **Canned Regex Responses:**
  - `AiAssistantRepository` matches regex keywords on-device and returns hardcoded string responses.
  - Zero connection to OpenAI, Gemini, or Claude APIs.
  - **Action:** Deploy Supabase Edge Function `functions/v1/ai-copilot` that securely proxies user prompts to Gemini 1.5 Pro / Claude 3.5 Sonnet with user portfolio context and streaming SSE output.
