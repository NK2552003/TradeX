# 10-Community — Backend Architecture & Integration Guide

## 1. Overview
The Community feature powers TradeX's social trading feed, technical strategy discussions, sentiment polls, and peer trader follow graphs.

Key capabilities:
- **Rich Posts**: Markdown body with ticker tagging (`#NVDA`), topic channels (`#general`, `#crypto`, `#scalping`), and post kinds (`standard`, `analysis`, `playbook`, `signal`, `poll`).
- **Structured Trade Setups**: Native side (long/short), entry, stop loss, targets (TP1/TP2), timeframe, and chart images.
- **Threaded Comments**: LinkedIn/Twitter-style comment trees with nested replies.
- **Social Graph**: Likes, reposts with quotes, bookmarks, follower/following relationships.
- **Interactive Polls**: Community sentiment voting with live percentage distribution.

---

## 2. Realtime & Trigger Sync
- Triggers on `community_likes` and `community_comments` automatically increment/decrement `likes_count` and `comments_count` on `community_posts` with row-level locks, avoiding race conditions.
- Realtime channels can listen for live comments and like count deltas.

---

## 3. Data Model Hierarchy
```text
community_posts
├── community_post_trade_setups (1:1 optional structured trade levels)
├── community_post_attachments (1:many attachments / references)
├── community_comments (1:many threaded comments)
├── community_likes (M:N profiles)
├── community_reposts (M:N profiles with optional quote)
├── community_bookmarks (M:N profiles)
└── community_polls (1:1 optional poll with options & user votes)
```

---

## 4. Universal Linking Contract
When a trader publishes a post containing a strategy playbook or trade journal execution, an edge is created in `universal_link_edges`:
```sql
SELECT create_universal_link('communityPost', post.id, 'strategy', strategy.id, 'Playbook Reference');
```
This enables users reading the post to click straight through to the interactive strategy viewer in TradeX.
