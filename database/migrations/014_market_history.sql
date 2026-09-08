BEGIN;

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

-- Timeseries hypertable if using TimescaleDB, otherwise regular B-tree index
CREATE INDEX IF NOT EXISTS idx_market_history_time ON market_history(time DESC);

COMMIT;
