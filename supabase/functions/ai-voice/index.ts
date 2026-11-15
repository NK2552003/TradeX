import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';
import { AuthCheck, handleVoiceRequest, voiceCorsHeaders } from './voice.ts';

const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...voiceCorsHeaders, 'Content-Type': 'application/json' },
  });

export async function handleRequest(request: Request): Promise<Response> {
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: voiceCorsHeaders });
  }
  const logger = createEdgeRequestLogger('ai-voice', request);
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!url || !anonKey) {
    return logger.finish(reply(503, { error: 'Voice AI service is not configured.' }));
  }

  const authenticate: AuthCheck = async (authorization) => {
    const account = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const token = authorization.slice(7);
    const { data: userData, error: authError } = await account.auth.getUser(token);
    if (authError || !userData.user) {
      return { ok: false, status: 401, error: 'Sign in required.' };
    }
    const { data: access, error: accessError } = await account.rpc('get_my_admin_access');
    if (accessError || access?.status !== 'active' || access?.features?.ai !== true) {
      return { ok: false, status: 403, error: 'AI voice access is not available for this account.' };
    }
    return { ok: true, userId: userData.user.id };
  };

  try {
    const response = await handleVoiceRequest(request, {
      env: (name) => Deno.env.get(name),
      fetch,
      authenticate,
    });
    return logger.finish(response);
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(reply(500, { error: 'Voice request failed.' }));
  }
}

if (import.meta.main) {
  Deno.serve((request) => handleRequest(request));
}
