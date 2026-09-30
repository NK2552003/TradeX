# 09-Messages — Backend Architecture & Integration Guide

## 1. Overview
The Messages feature provides high-performance, real-time communication across TradeX:
- **1-on-1 Direct Messaging**: Private conversations between verified traders.
- **Desk & Group Chats**: Collaborative group channels for trading desks and strategy clubs.
- **Rich Media & Domain Attachments**: Native attachments for images, charts, PDFs, audio voice notes, and live record links (Trade Journal entries, Notes, Strategies, AI Setups).
- **Interactive Reactions & Delivery Status**: Emoji reactions, message edits, deletions, read receipts, and real-time presence indicators.

---

## 2. Realtime Architecture (Supabase Realtime)
Postgres tables published to `supabase_realtime`:
- `chat_messages` (new messages, status updates)
- `chat_reactions` (instant emoji reactions)
- `chat_user_presence` (online / away / busy / offline status)

Clients subscribe to channel `room:thread_id`:
```typescript
const channel = supabase.channel(`chat:${threadId}`)
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'chat_messages',
    filter: `thread_id=eq.${threadId}`,
  }, (payload) => {
    // Handle incoming message
  })
  .subscribe();
```

---

## 3. Data Model Hierarchy
```text
chat_threads
├── chat_participants (many-to-many with profiles)
└── chat_messages
    ├── chat_attachments (images, voice notes, documents)
    ├── chat_shared_refs (links to Notes, Journal, Strategy, AI Copilot)
    └── chat_reactions (emoji reactions per trader)
```

---

## 4. Endpoints & RPC Functions
- `GET /threads`: List active user threads with last message preview and unread counts.
- `GET /threads/:id/messages`: Paginated message list with attachments and shared refs.
- `POST /threads/:id/messages`: Send message with optional attachments or shared records.
- `POST /threads/:id/reactions`: Toggle emoji reaction on message.
- `POST /threads/direct`: Get or create direct conversation with a peer trader.
- `POST /presence`: Heartbeat update for presence state.
