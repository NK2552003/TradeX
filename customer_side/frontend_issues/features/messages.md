# Frontend Feature Audit: Direct Messages

**Component:** `lib/features/messages/`  
**Target Files:**  
- `lib/features/messages/presentation/messages_page.dart`  
- `lib/features/messages/presentation/views/messages_thread_view.dart`  
- `lib/features/messages/presentation/widgets/message_composer.dart`  

---

## 1. False Security Banners

- **Misleading E2EE Banner (`messages_thread_view.dart:400, 919`):**
  - Displays lock icon and "Direct messages are end-to-end encrypted".
  - Messages are stored as plaintext strings in PostgreSQL.
  - **Action:** Remove lock icon and E2EE text immediately.

---

## 2. Layout & Gesture Inset Overlap

- **Composer Obscuration on Gesture Navigation Devices (`message_composer.dart:20-60`):**
  - Input field and send button lack `SafeArea(bottom: true)`.
  - Obscured by iOS / Android home pill.
  - **Action:** Wrap composer in `SafeArea(top: false, child: ...)`.

---

## 3. Empty State Poisoning

- **Fake Threads Displayed to Real Users:**
  - `fetchFromSupabase` fails to clear seed personas ("Sarah Jenkins") for users with 0 messages.
  - **Action:** Clear in-memory seed list when backend returns an empty thread list.
