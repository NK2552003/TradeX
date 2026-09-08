ALTER TABLE watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE watchlist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY watchlists_select ON watchlists FOR SELECT USING (user_id = auth.uid());
CREATE POLICY watchlists_insert ON watchlists FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY watchlists_update ON watchlists FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY watchlists_delete ON watchlists FOR DELETE USING (user_id = auth.uid());

CREATE POLICY watchlist_items_select ON watchlist_items FOR SELECT USING (
    EXISTS (SELECT 1 FROM watchlists WHERE id = watchlist_items.watchlist_id AND user_id = auth.uid())
);
CREATE POLICY watchlist_items_insert ON watchlist_items FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM watchlists WHERE id = watchlist_items.watchlist_id AND user_id = auth.uid())
);
CREATE POLICY watchlist_items_delete ON watchlist_items FOR DELETE USING (
    EXISTS (SELECT 1 FROM watchlists WHERE id = watchlist_items.watchlist_id AND user_id = auth.uid())
);
