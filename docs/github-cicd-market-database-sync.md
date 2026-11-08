# Market and news CI

The workflow is `.github/workflows/supabase-market-sync.yml` (there is no `ci.yml`). It runs every six hours at minute 17, on relevant main-branch pushes, and on manual dispatch. Pull requests run offline validation only.

## Bounded universe

At most **5,000** symbols are selected before any Yahoo fetch. Curated major stocks, indices, ETFs and crypto pairs come first; remaining stored quotes are ranked by descending positive reported trading volume, with symbol as the deterministic tie-breaker. This is a popularity proxy, not a market-cap ranking. Retired symbols, unsupported `.U`/`.W`/`.WS` notation, and unranked zero/missing-volume additions are excluded. Stored history is retained.

One frozen manifest feeds ten non-overlapping partitions of at most 500 symbols. Five jobs run at once, each with two fetch workers. Each job allows up to 330 minutes for fetching and verified publication, within a 360-minute job limit. GitHub-hosted runners enforce a six-hour maximum; this is not an unlimited wait. Setup and report upload have 30 minutes of headroom. Completed results are published after every ten valid symbols, without waiting for the whole 50-symbol fetch window. Database writes are batched, details are read only for the current batch, and existing history receives a one-month overlap refresh. New symbols and explicit history runs fetch two years.

Known missing listings and stale quotes/history are discarded from this publication and recorded in `discarded_symbols`. Network failures, rate limiting, invalid OHLC coverage and unconfirmed writes remain failures. Screeners publish only after every partition succeeds and its report accounts for every selected symbol. Discarded symbols cannot re-enter via stale database quotes. News runs independently of quote coverage.

Every upsert checks the returned row identities and values, then reads the records back from Supabase and checks them again. `confirmed_writes` counts confirmed write responses; `verified_writes` counts successful read-back checks. A symbol receives `persisted: true` only after all its applicable tables pass verification. Verification failures fail CI; they are never reported as successful publication.

Reports are checkpointed after every publication batch. A killed job uploads its last checkpoint with `running`/interrupted status, never a false success. Summaries are bounded to 100 issues; artifacts retain all details.

## Required GitHub secrets

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (server-side writes; public anonymous keys cannot substitute)

Use **Actions → Supabase Market & News Database Sync → Run workflow**. Select `all`, `quotes`, `history`, `news` or `screeners`. Set `fetch_live=false` for offline tests only.

## Local checks

```sh
python3 -m pip install -r scripts/requirements.txt
python3 -m unittest discover -s test/scripts -p 'test_*.py' -v
python3 scripts/sync_market_pipeline.py --dry-run --symbols AAPL,MSFT,RELIANCE.NS,BTC-USD --market-only
```

An explicit symbol subset is still capped at 5,000. Provider failures return a nonzero exit code and write `market-sync-report.json`. A dry run never writes to Supabase.
