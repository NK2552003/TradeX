# Public site and asset data

Apply migrations `023_public_site_and_market_assets.sql` and
`024_market_screener_snapshots.sql`, then the generated seeds
`database/seeds/03_public_site.sql` and `04_market_assets.sql` to your local database.
The existing schema must be installed first. Both seeds are repeatable and retain
canonical integer article IDs by upserting on `news_articles.link`.

`pricing_catalogues.catalogue` matches `PricingCatalogueResponse.fromJson`:
plans, feature categories/rows, FAQs, billing metadata, disclaimer, and editorial
copy. `public_site_pages.content` contains brand, hero, ordered feature cards,
role cards, FAQs, and footer. Edit the published rows to update both pages.
JSONB preserves ordered editorial lists and the current Free/Pro/Enterprise
comparison contract without requiring UI changes for content edits.

`MockPublicSiteRepository` loads `assets/data/pricing_catalogue.json` and
`landing_page.json` with the same JSON structures. Configured Supabase uses
`DatabasePublicSiteRepository`. Missing/unpublished rows, missing tables and
requests exceeding eight seconds resolve through the same bundled catalogue
contract. This allows local previews before migrations/seeds are applied. Both
landing and pricing remain usable when that configured backend is unavailable.
A failed bundled read still exposes an error/retry state. No catalogue public write
policies exist. Public reads expose only published rows.

Plan selection validates plan ID and cycle, then updates the existing local
onboarding session. This is a frontend mock, not a payment processor. Real paid
entitlements must be issued by a trusted checkout/webhook integration, separately
from public content tables.

Run `python3 scripts/refresh_loop.py --once` to refresh ticker lists, quotes,
fundamentals, history, full details, categorized news, screeners and SQL exports.
This command writes local assets/SQL only, even if DATABASE_URL is configured.
Run `python3 scripts/export_asset_sql.py` after changing marketing fixtures.
Run `python3 scripts/validate_asset_sql.py` to execute seeds twice in an isolated,
temporary PostgreSQL cluster and check counts and access rules.

The market_data feature is the asset adapter for all finance-kit JSON:
quotes, fundamentals, stock detail, history, topic news and screeners. Its
community rail shows only top gainers and top losers, with actual closing-price
sparklines, company names, prices and absolute/percentage changes. The independent
Market Intelligence menu offers News, Movers, Instruments and Screeners to every
role. Image-led news uses source thumbnails, topic columns and full-width article
readers; instrument details include charts, fundamentals, company news, options,
history, dividends, recommendations and holders. Navigation preserves the preceding
detail when opening related articles. Prices are
bundled snapshots with timestamps, not a live tick stream. Screener rankings are
computed from exported quotes; categories absent from the universe stay empty.
Unavailable providers may use the scripts' existing mock fallback, labelled in
full stock details. The refresh manifest records exported counts and file paths.

## Landing layout restoration

The landing layout is restored from commit `7749e2cb` (before `6ff24195`
replaced it). Preserve its sticky navigation, centered hero, app showcase,
workspace/persona cards, feature cards, pricing, FAQ and detailed footer. Mobile
retains the earlier carousel and Trader/Affiliate/sign-in actions. The repository
continues to supply pricing with its bounded database request and bundled fallback;
restoration does not replace the pricing data contract. Desktop off-screen sections
use `UiDeferred`, and section navigation re-aligns after deferred content mounts.
Pricing comparison categories also mount near the viewport. Avoid replacing the
landing layout when adjusting backend content or the independent markets feature.
