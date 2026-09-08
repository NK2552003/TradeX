# Markets (Quotes & History)

## Overview

The Markets feature drives the frontend's display of instrument pricing, daily changes, and historical OHLC (Open, High, Low, Close) charts. Currently, the frontend loads bundled JSON mock data. The backend needs to replace this by exposing live or scheduled price updates from upstream APIs (e.g. Polygon, Yahoo Finance, Alpha Vantage).

## Schema

1. **`instruments`**: The master list of all tradable symbols (e.g., `AAPL`, `NVDA`, `RELIANCE.NS`).
2. **`quotes`**: The latest available snapshot for an instrument (`price`, `change_pct`, `volume`). It maps directly to `MarketQuote` on the frontend.
3. **`market_history`**: Time-series OHLC bars mapping to `MarketBar` on the frontend.

## Cron Jobs

- **Live/Frequent Quote Fetcher**: A cron job running every 1-5 minutes during market hours to fetch the latest `quotes` for active `instruments`.
- **EOD History Sync**: A daily cron job to append End-of-Day (EOD) OHLC bars into `market_history` after market close. (Alternatively, for intraday charting, a more frequent cron job or a TimescaleDB continuous aggregate strategy is required).
