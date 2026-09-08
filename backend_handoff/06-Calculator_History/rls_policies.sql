ALTER TABLE calculator_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY calculator_history_select ON calculator_history FOR SELECT USING (user_id = auth.uid());
CREATE POLICY calculator_history_insert ON calculator_history FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY calculator_history_delete ON calculator_history FOR DELETE USING (user_id = auth.uid());
