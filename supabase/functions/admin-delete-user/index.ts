import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers });
type Dependencies = { fetch?: typeof fetch; env?: (name: string) => string | undefined };

/** Permanent deletion is performed only on this trusted server. PostgreSQL
 * claims the reviewed request and prevents concurrent or cross-user jobs. */
export async function handleRequest(request: Request, dependencies: Dependencies = {}): Promise<Response> {
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  const logger = createEdgeRequestLogger('admin-delete-user', request);
  try {
    const response = await executeDeletionRequest(request, dependencies, logger);
    return logger.finish(response);
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(reply(500, { error: 'Account deletion could not be completed.' }));
  }
}

async function executeDeletionRequest(
  request: Request,
  dependencies: Dependencies,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
  if (request.method !== 'POST') return reply(405, { error: 'Method not allowed.' });
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return reply(401, { error: 'Sign in required.' });

  const env = dependencies.env ?? Deno.env.get;
  const send = dependencies.fetch ?? fetch;
  const url = env('SUPABASE_URL');
  const anonKey = env('SUPABASE_ANON_KEY');
  const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY') ?? env('SUPABASE_SECRET_KEY');
  if (!url || !anonKey || !serviceKey) return reply(503, { error: 'Account deletion is not configured.' });

  let requestId: string, confirmation: string, reason: string;
  try {
    const text = await request.text();
    if (text.length > 10000) return reply(400, { error: 'Request is too large.' });
    const body = JSON.parse(text);
    if (typeof body.request_id !== 'string' || typeof body.confirmation !== 'string' || typeof body.reason !== 'string') {
      return reply(400, { error: 'Deletion request, confirmation and reason are required.' });
    }
    requestId = body.request_id;
    confirmation = body.confirmation.trim();
    reason = body.reason.trim();
    if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(requestId) || reason.length < 3 || reason.length > 2000) {
      return reply(400, { error: 'Invalid deletion request or reason.' });
    }
  } catch { return reply(400, { error: 'Invalid request.' }); }

  const account = createClient(url, anonKey, {
    global: { fetch: send, headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: auth, error: authError } = await account.auth.getUser(authorization.slice(7));
  if (authError || !auth.user) return reply(401, { error: 'Sign in required.' });
  const { data: caller, error: callerError } = await account.from('profiles')
    .select('id,role,status').eq('id', auth.user.id).single();
  if (callerError || caller?.role !== 'user_admin' || caller?.status !== 'active') {
    return reply(403, { error: 'An active administrator account is required.' });
  }

  const service = createClient(url, serviceKey, {
    global: { fetch: send },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: claim, error: claimError } = await service.rpc('admin_claim_deletion', {
    p_request: requestId, p_actor: auth.user.id, p_confirmation: confirmation, p_reason: reason,
  });
  if (claimError) return reply(409, { error: claimError.message });
  if (claim?.completed) return reply(200, { deleted: true });
  if (typeof claim?.user_id !== 'string') return reply(500, { error: 'Unable to claim deletion request.' });

  let filesRemoved = 0;
  try {
    // Block future logins before removing files. Existing sessions have already
    // been revoked and the database checks the suspended profile on access.
    if (!claim.auth_deleted) {
      const { error: banError } = await service.auth.admin.updateUserById(claim.user_id, { ban_duration: '876000h' });
      if (banError) throw banError;
    }
    const started = Date.now();
    while (true) {
      if (Date.now() - started > 90000) throw new Error('File cleanup is incomplete. Retry this deletion to continue.');
      const { data: objects, error: listError } = await service.rpc('admin_deletion_storage_batch', { p_request: requestId });
      if (listError) throw listError;
      if (!Array.isArray(objects)) throw new Error('Unable to verify account files.');
      if (objects.length === 0) break;
      const buckets = new Map<string, string[]>();
      for (const object of objects) {
        const names = buckets.get(object.bucket_id) ?? [];
        names.push(object.name);
        buckets.set(object.bucket_id, names);
      }
      for (const [bucket, names] of buckets) {
        const { error } = await service.storage.from(bucket).remove(names);
        if (error) throw error;
        filesRemoved += names.length;
      }
    }
    if (!claim.auth_deleted) {
      const { error: deleteError } = await service.auth.admin.deleteUser(claim.user_id);
      if (deleteError) throw deleteError;
    }
    const { error: finishError } = await service.rpc('admin_finish_deletion', {
      p_request: requestId, p_actor: auth.user.id, p_files: filesRemoved,
    });
    if (finishError) throw finishError;
    logger.log('info', 'deletion_completed', {
      deletion_request_id: requestId,
      files_removed: filesRemoved,
    });
    return reply(200, { deleted: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Account deletion could not be completed.';
    logger.log('error', 'deletion_failed', {
      deletion_request_id: requestId,
      files_removed: filesRemoved,
      ...describeError(error),
    });
    const { error: receiptError } = await service.rpc('admin_finish_deletion', {
      p_request: requestId, p_actor: auth.user.id, p_error: message, p_files: filesRemoved,
    });
    return reply(500, { error: receiptError
      ? 'Deletion needs reconciliation. Refresh the request and retry; the account remains suspended.'
      : message });
  }
}

if (import.meta.main) Deno.serve((request) => handleRequest(request));
