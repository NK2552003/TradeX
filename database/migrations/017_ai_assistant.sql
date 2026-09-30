-- 017_ai_assistant.sql
--
-- AI Copilot: threads, message logs, institutional chart setups, generated insights,
-- and rate-limiting quotas.
--
-- Mirrors models in lib/features/ai_assistant/models/ai_assistant_models.dart and
-- repository contract in lib/features/ai_assistant/data/ai_assistant_repository.dart.

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
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  ticker TEXT,
  summary TEXT,
  indicators JSONB,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  title TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  confidence NUMERIC(5, 4) DEFAULT 0.8500,
  sentiment_score NUMERIC(5, 4) DEFAULT 0.0000,
  tickers TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Upgrade either pre-existing insight shape without deleting cached signals.
ALTER TABLE ai_insights
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD COLUMN IF NOT EXISTS ticker TEXT,
    ADD COLUMN IF NOT EXISTS summary TEXT,
    ADD COLUMN IF NOT EXISTS indicators JSONB,
    ADD COLUMN IF NOT EXISTS generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS body TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS confidence NUMERIC(5, 4) DEFAULT 0.8500,
    ADD COLUMN IF NOT EXISTS sentiment_score NUMERIC(5, 4) DEFAULT 0.0000,
    ADD COLUMN IF NOT EXISTS tickers TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE ai_insights
    ALTER COLUMN ticker DROP NOT NULL,
    ALTER COLUMN summary DROP NOT NULL,
    ALTER COLUMN user_id DROP NOT NULL,
    ALTER COLUMN title SET DEFAULT '',
    ALTER COLUMN body SET DEFAULT '';

CREATE TABLE IF NOT EXISTS ai_quotas (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    daily_limit INTEGER NOT NULL DEFAULT 50,
    daily_used INTEGER NOT NULL DEFAULT 0 CHECK (daily_used >= 0),
    reset_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '1 day'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ai_threads_user_updated ON ai_threads(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_messages_thread_created ON ai_messages(thread_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_ai_chart_setups_user_symbol ON ai_chart_setups(user_id, symbol);
CREATE INDEX IF NOT EXISTS idx_ai_insights_user_created ON ai_insights(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_insights_tickers ON ai_insights USING GIN(tickers);

-- Enable Row Level Security (RLS)
ALTER TABLE ai_chart_setups ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_quotas ENABLE ROW LEVEL SECURITY;

-- Standard user RLS Policies
CREATE POLICY "Users can manage own AI chart setups"
    ON ai_chart_setups FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own AI threads"
    ON ai_threads FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage messages in own threads"
    ON ai_messages FOR ALL
    USING (EXISTS (
        SELECT 1 FROM ai_threads
        WHERE ai_threads.id = ai_messages.thread_id
        AND ai_threads.user_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM ai_threads
        WHERE ai_threads.id = ai_messages.thread_id
        AND ai_threads.user_id = auth.uid()
    ));

CREATE POLICY "Users can manage own AI insights"
    ON ai_insights FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own AI quota"
    ON ai_quotas FOR SELECT
    USING (auth.uid() = user_id);
