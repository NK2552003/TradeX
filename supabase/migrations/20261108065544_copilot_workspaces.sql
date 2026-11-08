-- Hosted copilot documents/preferences. Provider and connector secrets never
-- belong in this client-accessible state. AI generation still goes through the
-- authenticated ai-gateway and its existing account/quota checks.
CREATE TABLE IF NOT EXISTS public.copilot_workspaces (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  state jsonb NOT NULL CHECK (jsonb_typeof(state) = 'object'),
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT copilot_workspace_size CHECK (octet_length(state::text) <= 5000000)
);
ALTER TABLE public.copilot_workspaces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.copilot_workspaces FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.copilot_workspaces TO authenticated;
DROP POLICY IF EXISTS copilot_workspace_owner ON public.copilot_workspaces;
CREATE POLICY copilot_workspace_owner ON public.copilot_workspaces
  FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
