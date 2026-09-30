-- tables.sql (AI Assistant)
-- Schema definitions for AI Copilot threads, messages, chart setups, insights, and quotas.

CREATE TABLE IF NOT EXISTS ai_chart_setups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL DEFAULT '15m',
    pattern TEXT NOT NULL DEFAULT '',
    direction TEXT NOT NULL CHECK (direction IN ('long', 'short')),
    entry NUMERIC(16, 4) NOT NULL,
    stop_loss NUMERIC(16, 4) NOT NULL,
    target1 NUMERIC(16, 4) NOT NULL,
    target2 NUMERIC(16, 4) NOT NULL,
    confidence INTEGER NOT NULL DEFAULT 80 CHECK (confidence >= 0 AND confidence <= 100),
    rationale TEXT NOT NULL DEFAULT '',
    preview_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL DEFAULT 'New Conversation',
    persona TEXT NOT NULL DEFAULT 'swing'
        CHECK (persona IN ('swing', 'scalp', 'options', 'macro', 'risk')),
    pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES ai_threads(id) ON DELETE CASCADE ON UPDATE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    body TEXT NOT NULL DEFAULT '',
    pending BOOLEAN NOT NULL DEFAULT false,
    error TEXT,
    sources TEXT[] NOT NULL DEFAULT '{}',
    attachments TEXT[] NOT NULL DEFAULT '{}',
    chart_setup_id UUID REFERENCES ai_chart_setups(id) ON DELETE SET NULL ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    confidence NUMERIC(5, 4) DEFAULT 0.8500,
    sentiment_score NUMERIC(5, 4) DEFAULT 0.0000,
    tickers TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_quotas (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    daily_limit INTEGER NOT NULL DEFAULT 50,
    daily_used INTEGER NOT NULL DEFAULT 0 CHECK (daily_used >= 0),
    reset_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '1 day'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
