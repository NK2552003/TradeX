const PRODUCTION_ORIGINS = new Set([
  'https://alphajournal.in',
  'https://www.alphajournal.in',
  'https://app.alphajournal.in',
  'https://community.alphajournal.in',
  'https://admin.alphajournal.in',
  'https://affiliate.alphajournal.in',
]);

const LOCAL_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i;

export function allowedCorsOrigin(request: Request): string | null {
  const origin = request.headers.get('origin')?.trim() ?? '';
  if (!origin) return null;
  if (PRODUCTION_ORIGINS.has(origin) || LOCAL_ORIGIN.test(origin)) {
    return origin;
  }
  return null;
}

export function withCorsHeaders(
  request: Request,
  response: Response,
): Response {
  response.headers.delete('Access-Control-Allow-Origin');
  response.headers.set(
    'Access-Control-Allow-Headers',
    'authorization, apikey, content-type, x-client-info',
  );
  response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.headers.set('Access-Control-Max-Age', '86400');
  response.headers.append('Vary', 'Origin');
  const origin = allowedCorsOrigin(request);
  if (origin != null) {
    response.headers.set('Access-Control-Allow-Origin', origin);
  }
  return response;
}

export function corsPreflightResponse(request: Request): Response {
  return withCorsHeaders(request, new Response(null, { status: 200 }));
}
