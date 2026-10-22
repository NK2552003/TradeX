# Frontend Feature Audit: AI Assistant & Copilot

**Component:** `lib/features/ai_assistant/`  
**Target Files:**  
- `lib/features/ai_assistant/presentation/views/ai_chat_view.dart`  
- `lib/features/ai_assistant/presentation/views/ai_insights_view.dart`  

---

## 1. Dead Buttons & No-Op Handlers

| UI Control | File & Line | Failure Mechanism | Priority |
|---|---|---|:---:|
| Header "More Options" Menu | `ai_chat_view.dart:242` | Child `UiIconButton` has `onPressed: null`; inactive. | Low |
| Insight Card Action Dropdown | `ai_insights_view.dart:367` | Child `UiIconButton` has `onPressed: null`; inactive. | Low |

---

## 2. Simulated Typing & LLM Latency

- **Simulated Chat Stream:**
  - AI chat responses run through an artificial timer loop (`Future.delayed(Duration(milliseconds: 30))`) outputting canned regex responses.
  - Zero streaming WebSockets or SSE (Server-Sent Events) integrated.
  - **Action:** Replace simulated loop with a real SSE client consuming Supabase Edge Function `/functions/v1/ai-copilot`.
