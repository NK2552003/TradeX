# 12-Unified_Comments_And_Visibility — Backend Architecture & Integration Guide

## 1. Overview
This module unifies public and private visibility controls and discussions across all 4 key AlphaJournal content entities:
1. **Trader Notes** (`note` / `trader_notes`)
2. **Strategy Playbooks** (`strategy` / `strategies`)
3. **Trade Journals** (`journal` / `journal_entries`)
4. **Community Posts** (`post` / `community_posts`)

---

## 2. Core Principles

### Visibility Matrix
| Entity | Storage Column | Values | Default | Meaning When Private |
|---|---|---|---|---|
| **Notes** | `is_public` | `BOOLEAN` | `false` | Only readable by author; hidden from community feed & search |
| **Strategies** | `visibility` | `TEXT` (`'private'`, `'public'`) | `'private'` | Playbook rules hidden from explore tab; journal links confidential |
| **Journals** | `is_public` | `BOOLEAN` | `false` | Execution review hidden from peer critique; broker fills confidential |
| **Posts** | `is_public`, `visibility` | `BOOLEAN`, `TEXT` | `true`, `'public'` | Post is visible only to author when private |

### Unified Polymorphic Comments
- Table: `unified_comments`
- Key Columns: `entity_type` ('note', 'strategy', 'journal', 'post'), `entity_id` (UUID as string), `author_id`, `parent_id` (nested replies), `body`, `sentiment` ('BULLISH', 'BEARISH', 'NEUTRAL'), `likes_count`, `reply_count`.
- Reactions: `unified_comment_likes` with LinkedIn-grade reactions (`👍`, `🚀`, `💡`, `🔥`, `❤️`).

---

## 3. Database Procedures
- `set_entity_visibility(p_entity_type, p_entity_id, p_is_public)`:
  Validates ownership and atomically switches visibility in the corresponding entity table.
- `add_entity_comment(p_entity_type, p_entity_id, p_body, p_parent_id, p_sentiment)`:
  Inserts a threaded comment, verifies private entity access permissions, and returns the new comment UUID.
- `toggle_entity_comment_like(p_comment_id, p_reaction)`:
  Toggles reaction, updating comment like counts atomically.

---

## 4. Frontend Integration
- Widget: `UniversalCommentsSection` (`lib/features/community/presentation/widgets/universal_comments_section.dart`).
- Displays public/private indicators, one-tap "Make Public" buttons when private, sentiment badges, and threaded replies.
- Integrated into `NotePreviewScreen`, `StrategyDetailScreen`, `JournalEntryScreen`, and `CommunityPostDetailView`.
