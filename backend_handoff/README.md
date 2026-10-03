# Backend Handoff

This is the implementation entry point for the backend developer. The Flutter
application is deliberately written against repository seams; do not put
Supabase calls in widgets. Replace a repository implementation at its scope
instead.

Start with [Backend readiness](00-Backend_Readiness.md), then apply the
[database README](../database/README.md) in its stated order. The frontend is
currently backed by demo repositories for several features, so the app must
not be described as live until the relevant repository has been swapped.

## Feature contracts

| Area | Handoff | Backend boundary |
| --- | --- | --- |
| Writing desk: notes, journal and strategies | [01 Trade Journal](01-Trade_Journal/HOW_IT_WORKS.md), [02 Trader Notes](02-Trader_Notes/HOW_IT_WORKS.md), [03 Strategy Notes](03-Strategy_Notes/HOW_IT_WORKS.md) | Implement the repository interfaces and storage uploads; retain the existing UI contracts. |
| AI assistant | [08 AI Assistant](08-AI_Assistant/HOW_IT_WORKS.md) | Invoke models from an authenticated Edge Function; thread persistence, setups, quotas. |
| Realtime Messages | [09 Messages](09-Messages/HOW_IT_WORKS.md) | Supabase Realtime channel on `chat_messages`, attachments, reactions, presence. |
| Social Trading Community | [10 Community](10-Community/HOW_IT_WORKS.md) | Feeds, setups, threaded comments, reactions, follow graph, and polls. |
| Universal Link Graph | [11 Universal Link Graph](11-Universal_Link_Graph/HOW_IT_WORKS.md) | Symmetric bidirectional link edges connecting all 8 core domains. |
| Unified Comments & Visibility | [12 Unified Comments & Visibility](12-Unified_Comments_And_Visibility/HOW_IT_WORKS.md) | Unified polymorphic comment thread system, reactions, and public/private visibility across Notes, Strategies, Journals, and Posts. |
| Markets, news and watchlists | [07 Markets](07-Markets/HOW_IT_WORKS.md), [04 News](04-News/HOW_IT_WORKS.md), [05 Watchlist](05-Watchlist/HOW_IT_WORKS.md) | Treat market data as sourced data with timestamps and provenance. |

| Landing and pricing | [13 Public Site](13-Public_Site/HOW_IT_WORKS.md) | Published JSON catalogues, bundled preview fallback and trusted administration writes. |
| Calculator history | [06 Calculator History](06-Calculator_History/HOW_IT_WORKS.md) | Persist owner-only history with retention limits. |
| Entity Ticker Links | [15 Entity Ticker Links](15-Entity_Ticker_Links/HOW_IT_WORKS.md) | Dedicated relational link table (`entity_ticker_links`) maintaining durable ticker associations across Notes, Journals, Strategies, Community, and Messages under daily market data updates. |


The schema and RLS policies are authoritative for database access. Feature
documents specify the client-facing payloads and operational behavior.
