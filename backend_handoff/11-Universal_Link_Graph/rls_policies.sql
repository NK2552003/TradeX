-- rls_policies.sql (Universal Link Graph)

ALTER TABLE universal_link_edges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own universal links"
    ON universal_link_edges FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
