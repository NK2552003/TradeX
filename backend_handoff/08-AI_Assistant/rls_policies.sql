-- rls_policies.sql (AI Assistant)

ALTER TABLE ai_chart_setups ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_quotas ENABLE ROW LEVEL SECURITY;

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
