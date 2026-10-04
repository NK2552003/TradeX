# 15-Entity_Ticker_Links — Backend Architecture & Handoff Guide

## 1. Overview
`entity_ticker_links` is a dedicated relational junction and tracking table connecting financial market tickers (e.g. `AAPL`, `NVDA`, `BTCUSDT`, `RELIANCE`) directly with content entities across TradeX:
1. **Trader Notes** (`note`): Markdown theses, setups, research docs (`trader_notes`).
2. **Trade Journal** (`journal`): Trade executions, fills, and review logs (`journal_entries`).
3. **Strategy Playbooks** (`strategy`): Quantitative systems, rules, and parameters (`strategies`).
4. **Community Posts** (`community_post`): Social trade signals, setups, and discussions (`community_posts`).
5. **Direct Messages** (`message`): Direct peer chats, desk alerts, and shared record refs (`chat_messages`).

---

## 2. Business Problem & Rationale
Market tickers undergo frequent modifications on a daily basis:
- Daily EOD close quote updates, volume changes, and high/low resets.
- Corporate actions: Stock splits, symbol renaming (e.g., FB -> META), delistings.
- Ingestion of fresh market data feeds from Yahoo Finance, NSE, Binance, or broker APIs.

If ticker relationships were only stored as unindexed markdown text or denormalized text arrays inside individual entity records:
- Daily symbol or pricing updates would cause irregularities, orphan links, or broken references.
- Querying all historical notes, trades, strategies, posts, and messages discussing a specific ticker would require 5 expensive full-table scans.
- Snapshots of prices at link time would be lost.

By storing all ticker links in `entity_ticker_links`, associations are persisted independently of daily market ticker table refreshes.

---

## 3. Core Database Table Schema
```sql
CREATE TABLE IF NOT EXISTS entity_ticker_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    entity_type TEXT NOT NULL
        CHECK (entity_type IN ('note', 'journal', 'strategy', 'community_post', 'message')),
    entity_id TEXT NOT NULL,
    ticker VARCHAR(20) NOT NULL,
    context_source TEXT NOT NULL DEFAULT 'inline', -- 'inline', 'manual', 'tag', 'setup', 'shared_ref', 'attachment'
    price_at_link NUMERIC, -- snapshot of price at the moment of linking
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, entity_type, entity_id, ticker)
);
```

---

## 4. Stored Functions (RPCs)
- `record_entity_ticker_link(p_entity_type, p_entity_id, p_ticker, p_context_source, p_price_at_link, p_metadata)`:
  Idempotently creates or updates the ticker link row.
- `delete_entity_ticker_links(p_entity_type, p_entity_id, p_ticker)`:
  Removes ticker link(s) for a given entity.
- `get_entity_ticker_links_for_ticker(p_ticker)`:
  Fetches all notes, journals, strategies, community posts, and messages referencing a ticker.
- `get_entity_ticker_links_for_entity(p_entity_type, p_entity_id)`:
  Fetches all tickers referenced by a specific entity.

---

## 5. Frontend Repository Integration
The Flutter application integrates with this table via:
- Model & Service: `lib/features/linking/entity_ticker_links_repository.dart`
- Auto-sync on write:
  - `NotesRepository`: on note create/update/delete.
  - `JournalRepository`: on trade create/update/delete.
  - `StrategiesRepository`: on strategy create/update/delete.
  - `CommunityRepository`: on post create/edit/delete.
  - `MessagesRepository`: on message send/edit/delete.
  - `AppLinkGraphService`: on explicit manual link/unlink.
