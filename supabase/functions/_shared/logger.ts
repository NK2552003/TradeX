const REDACTED_KEYS = new Set([
  'authorization',
  'apikey',
  'api_key',
  'token',
  'access_token',
  'refresh_token',
  'secret',
  'password',
  'email',
  'prompt',
  'system_prompt',
  'message',
  'messages',
  'selectedtext',
  'selected_text',
  'cookie',
  'signature',
  'x-razorpay-signature',
  'x-push-secret',
]);

export type EdgeLogLevel = 'info' | 'warn' | 'error';

function sanitizeValue(key: string, value: unknown): unknown {
  if (REDACTED_KEYS.has(key.toLowerCase())) {
    return '[redacted]';
  }
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value === 'string') {
    return value.length > 240 ? `${value.slice(0, 237)}...` : value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }
  if (Array.isArray(value)) {
    return value.slice(0, 12).map((item) => sanitizeValue(key, item));
  }
  if (typeof value === 'object') {
    const cleaned: Record<string, unknown> = {};
    for (const [nestedKey, nestedValue] of Object.entries(value as Record<string, unknown>)) {
      const sanitized = sanitizeValue(nestedKey, nestedValue);
      if (sanitized !== undefined) {
        cleaned[nestedKey] = sanitized;
      }
    }
    return cleaned;
  }
  return String(value);
}

export function sanitizeLogDetails(
  details?: Record<string, unknown>,
): Record<string, unknown> | undefined {
  if (!details) return undefined;
  const cleaned: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(details)) {
    const sanitized = sanitizeValue(key, value);
    if (sanitized !== undefined) {
      cleaned[key] = sanitized;
    }
  }
  return Object.keys(cleaned).length > 0 ? cleaned : undefined;
}

export function describeError(error: unknown): {
  error_type: string;
  error_code?: string;
  error_message: string;
} {
  if (error instanceof Error) {
    const maybeCode = (error as { code?: unknown }).code;
    return {
      error_type: error.name || 'Error',
      error_code: typeof maybeCode === 'string' || typeof maybeCode === 'number'
        ? String(maybeCode)
        : undefined,
      error_message: error.message.slice(0, 240),
    };
  }
  if (error && typeof error === 'object') {
    const record = error as { code?: unknown; name?: unknown; message?: unknown };
    return {
      error_type: typeof record.name === 'string' ? record.name : 'ObjectError',
      error_code: typeof record.code === 'string' || typeof record.code === 'number'
        ? String(record.code)
        : undefined,
      error_message: String(record.message ?? 'Unexpected error').slice(0, 240),
    };
  }
  return {
    error_type: typeof error,
    error_message: String(error ?? 'Unexpected error').slice(0, 240),
  };
}

export function logEdgeEvent(
  level: EdgeLogLevel,
  fn: string,
  event: string,
  details?: Record<string, unknown>,
): void {
  const payload = {
    ts: new Date().toISOString(),
    source: 'supabase_edge_function',
    level,
    fn,
    event,
    ...(sanitizeLogDetails(details) ?? {}),
  };
  const line = JSON.stringify(payload);
  if (level === 'error') {
    console.error(line);
  } else {
    console.log(line);
  }
}

export function createEdgeRequestLogger(fn: string, request: Request) {
  const startedAt = Date.now();
  const requestId = request.headers.get('x-request-id')?.trim() || crypto.randomUUID();
  let pathname = '/';
  try {
    pathname = new URL(request.url).pathname;
  } catch {
    // Keep default root path when test uses a relative or mock URL.
  }

  const base = {
    request_id: requestId,
    method: request.method,
    path: pathname,
  };

  return {
    requestId,
    log(level: EdgeLogLevel, event: string, details?: Record<string, unknown>) {
      logEdgeEvent(level, fn, event, {
        ...base,
        elapsed_ms: Date.now() - startedAt,
        ...(details ?? {}),
      });
    },
    finish(response: Response, details?: Record<string, unknown>): Response {
      const level: EdgeLogLevel = response.status >= 500
        ? 'error'
        : response.status >= 400
        ? 'warn'
        : 'info';
      logEdgeEvent(level, fn, 'request_completed', {
        ...base,
        status: response.status,
        duration_ms: Date.now() - startedAt,
        ...(details ?? {}),
      });
      return response;
    },
  };
}
