ALTER TABLE instruments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY instruments_read ON instruments FOR SELECT USING (true);
CREATE POLICY quotes_read ON quotes FOR SELECT USING (true);
CREATE POLICY market_history_read ON market_history FOR SELECT USING (true);
