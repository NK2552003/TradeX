# 11-Universal_Link_Graph — Backend Architecture & Integration Guide

## 1. Overview
The Universal Link Graph is the relational backbone that binds TradeX into a unified quantitative trading workspace. It connects records across all 8 core domains:
1. `note`: Trader Note (markdown thesis, checklist, research)
2. `journal`: Trade Journal Entry (executed trade with fills and PnL)
3. `strategy`: Strategy Playbook (rules, parameters, backtests)
4. `aiCopilot`: AI Copilot Conversation or Generated Trade Setup
5. `communityPost`: Community Post or Analysis Thread
6. `messageThread`: Direct Message or Desk Chat Conversation
7. `ticker`: Market Symbol (e.g. `AAPL`, `NVDA`, `BTC`)
8. `trader`: Peer Trader Profile

---

## 2. Core Concepts
- **Symmetric Bidirectionality**: When record A links to record B, record B automatically has a reciprocal backlink to record A under the same user's account.
- **Idempotency**: Linking twice produces a single canonical edge with no errors.
- **Cascade & Cleanup**: Deletion of a source record cascades and removes dangling edges.
- **Fast Traversal**: Indexed on `(user_id, source_kind, source_id)` and `(user_id, target_kind, target_id)`.

---

## 3. Database Functions
- `create_universal_link(src_kind, src_id, tgt_kind, tgt_id, label, metadata)`: Creates reciprocal edges.
- `delete_universal_link(src_kind, src_id, tgt_kind, tgt_id)`: Removes reciprocal edges.
- `get_universal_links(kind, id)`: Fetches all connected links for any record.

---

## 4. Frontend Integration
In Flutter, the link graph is encapsulated in `lib/core/linking/link_graph.dart` and `lib/features/linking/link_graph_service.dart`.
When any record tile (`AppLinkRefTile`) is tapped, the shell's `onOpenRef` automatically handles navigation, switching workspaces or pushing overlays dynamically.
