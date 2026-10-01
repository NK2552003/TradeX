# Canonical market news

`news_articles` is the single main-branch article table: integer `id`, unique
`link`, title, summary, publisher, thumbnail_url, content_type and published_at.
Never change the ID type or create another article table for imported assets.
`news_article_tickers` and `news_article_topics` link the finance kits to the
shared `tickers` and `news_topics` registries. Legacy `news_tickers` references
older `instruments` consumers; it is not the current finance importer join.

The topic feed merges by canonical link and unions ticker associations from all
source fetches. `all_news.json` is the aggregate; `by_topic/*.json` retains topic
membership. Seed 04 upserts articles by link and retains integer IDs on repeats.

Frontend news uses source images, publisher/time, source-linked ticker badges,
a featured story, topic columns and latest headlines. Article details display
the exported summary and open the original source for the complete article.
The dataset does not contain licensed full article bodies or popularity scores;
do not manufacture either. Public pricing content is a separate feature.

See ../07-Markets/HOW_IT_WORKS.md for the full pipeline and installation order.
