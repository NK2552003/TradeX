-- Retained compatibility definitions; apply database/schema.sql for the complete schema.
-- Instruments
CREATE TABLE IF NOT EXISTS instruments (
    symbol TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    exchange TEXT,
    asset_class TEXT,
    currency TEXT,
    market TEXT,
    sector TEXT,
    industry TEXT,
    market_cap BIGINT,
    pe_ratio NUMERIC,
    fifty_two_week_high NUMERIC,
    fifty_two_week_low NUMERIC,
    dividend_yield NUMERIC,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Quotes
CREATE TABLE IF NOT EXISTS quotes (
    symbol TEXT PRIMARY KEY REFERENCES instruments(symbol) ON DELETE CASCADE,
    price NUMERIC NOT NULL,
    previous_close NUMERIC,
    day_high NUMERIC,
    day_low NUMERIC,
    volume BIGINT,
    change_pct NUMERIC,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Market History (OHLC Bars)
CREATE TABLE IF NOT EXISTS market_history (
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    time TIMESTAMPTZ NOT NULL,
    open NUMERIC NOT NULL,
    high NUMERIC NOT NULL,
    low NUMERIC NOT NULL,
    close NUMERIC NOT NULL,
    volume BIGINT NOT NULL,
    PRIMARY KEY (symbol, time)
);
CREATE INDEX IF NOT EXISTS idx_market_history_time ON market_history(time DESC);
