# Backend Feature Audit: Direct Messages & Realtime

**Component:** `lib/features/messages/`  
**Database Tables:** `public.chat_threads`, `public.chat_messages`, `public.chat_participants`  
**Files Evaluated:**  
- `database/migrations/018_messages_realtime.sql`  
- `lib/features/messages/data/messages_repository.dart`  

---

## 1. Global Real-Time Direct Message Leakage (IDOR)

- **Unfiltered Channel Subscription (`messages_repository.dart:298-317`):**
  - Subscribes to Realtime channel `'public:messages_channel'` on `chat_messages` without any thread or recipient filter.
  - Because table is published to realtime replication, **all direct messages sent between any users are broadcast to all connected clients**.
  - **Action:** Enforce Supabase Realtime Private Channels scoped to authorized participant IDs:
    ```sql
    ALTER TABLE chat_messages REPLICA IDENTITY FULL;
    ```
    And subscribe client strictly to `channel('thread:$threadId')` with explicit filter.

---

## 2. Unencrypted Database Storage

- **Cleartext Message Bodies (`018_messages_realtime.sql`):**
  - `chat_messages.body` stores raw plaintext strings while UI markets "End-to-end encrypted".
  - **Action:** If true E2EE is required, store encrypted ciphertext blobs with client-side key exchange, or remove deceptive E2EE claims.
