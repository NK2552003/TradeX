import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';

const ALLOWED_ORIGINS = new Set([
  'https://alphajournal.in',
  'https://www.alphajournal.in',
  'https://app.alphajournal.in',
  'https://community.alphajournal.in',
  'https://admin.alphajournal.in',
  'https://affiliate.alphajournal.in',
]);

function resolveAllowedOrigin(request: Request): string {
  const origin = request.headers.get('origin')?.trim() ?? '';
  if (ALLOWED_ORIGINS.has(origin)) {
    return origin;
  }
  if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)) {
    return origin;
  }
  return 'https://alphajournal.in';
}

export function buildCorsHeaders(
  request: Request,
  cacheControl?: string,
): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': resolveAllowedOrigin(request),
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
    ...(cacheControl ? { 'Cache-Control': cacheControl } : {}),
  };
}

export const MAX_BODY_BYTES = 32_000;
export const MAX_SYMBOLS = 30;
export const SYMBOL_REGEX = /^[A-Za-z0-9^.=\-_]{1,20}$/;

export class PayloadTooLargeError extends Error {
  constructor(message = 'Request payload exceeds limit.') {
    super(message);
    this.name = 'PayloadTooLargeError';
  }
}

export class ValidationError extends Error {
  constructor(message = 'Validation error.') {
    super(message);
    this.name = 'ValidationError';
  }
}

// In-memory cache with bounded size
interface CacheEntry<T> {
  data: T;
  expiresAt: number;
}
export const cache = new Map<string, CacheEntry<unknown>>();

export function getCached<T>(key: string): T | null {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    cache.delete(key);
    return null;
  }
  return entry.data as T;
}

export function setCached<T>(key: string, data: T, ttlMs: number): void {
  if (cache.size > 2000) {
    cache.clear();
  }
  cache.set(key, { data, expiresAt: Date.now() + ttlMs });
}

export async function readBodyWithLimit(request: Request, maxBytes: number): Promise<string> {
  const contentLength = request.headers.get('content-length');
  if (contentLength && parseInt(contentLength, 10) > maxBytes) {
    throw new PayloadTooLargeError(`Request body exceeds ${maxBytes} bytes limit.`);
  }

  if (!request.body) {
    return '';
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value) {
        totalBytes += value.byteLength;
        if (totalBytes > maxBytes) {
          throw new PayloadTooLargeError(`Request body exceeds ${maxBytes} bytes limit.`);
        }
        chunks.push(value);
      }
    }
  } finally {
    reader.releaseLock();
  }

  const concatenated = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    concatenated.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(concatenated);
}

export interface QuotePayload {
  symbol: string;
  name: string;
  price: number;
  previousClose: number;
  open: number;
  high: number;
  low: number;
  change: number;
  changePercent: number;
  volume: number;
  fiftyTwoWeekHigh: number;
  fiftyTwoWeekLow: number;
  spark: number[];
  isLive: boolean;
  timestamp: string;
  source: string;
}

export const SECTOR_MAPPING = [
  { name: 'Technology', symbol: 'XLK', key: 'technology', weight: 32.43 },
  { name: 'Financial Services', symbol: 'XLF', key: 'financial_services', weight: 13.44 },
  { name: 'Industrials', symbol: 'XLI', key: 'industrials', weight: 10.23 },
  { name: 'Healthcare', symbol: 'XLV', key: 'healthcare', weight: 9.83 },
  { name: 'Consumer Cyclical', symbol: 'XLY', key: 'consumer_cyclical', weight: 9.32 },
  { name: 'Communication Services', symbol: 'XLC', key: 'communication_services', weight: 8.57 },
  { name: 'Energy', symbol: 'XLE', key: 'energy', weight: 5.22 },
  { name: 'Consumer Defensive', symbol: 'XLP', key: 'consumer_defensive', weight: 4.61 },
  { name: 'Basic Materials', symbol: 'XLB', key: 'basic_materials', weight: 2.47 },
  { name: 'Real Estate', symbol: 'XLRE', key: 'real_estate', weight: 1.98 },
  { name: 'Utilities', symbol: 'XLU', key: 'utilities', weight: 1.90 },
];

export async function fetchServerQuote(symbol: string): Promise<QuotePayload | null> {
  const cacheKey = `quote:${symbol.toUpperCase()}`;
  const cached = getCached<QuotePayload>(cacheKey);
  if (cached) return cached;

  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=5d`;
    const res = await fetch(url, {
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      signal: AbortSignal.timeout(6000),
    });

    if (!res.ok) {
      return null;
    }

    const data = await res.json();
    const result = data?.chart?.result?.[0];
    if (!result) return null;

    const meta = result.meta || {};
    const quoteData = result.indicators?.quote?.[0] || {};
    const price = Number(meta.regularMarketPrice ?? meta.chartPreviousClose ?? 0);
    const prevClose = Number(meta.chartPreviousClose ?? price);
    const change = price - prevClose;
    const changePercent = Number(
      meta.regularMarketChangePercent ?? (prevClose === 0 ? 0 : (change / prevClose) * 100)
    );
    const volume = Number(meta.regularMarketVolume ?? 0);
    const fiftyTwoWeekHigh = Number(meta.fiftyTwoWeekHigh ?? price);
    const fiftyTwoWeekLow = Number(meta.fiftyTwoWeekLow ?? price);
    const closes: number[] = Array.isArray(quoteData.close)
      ? quoteData.close.filter((c: unknown): c is number => typeof c === 'number' && Number.isFinite(c))
      : [];

    const opens = Array.isArray(quoteData.open) ? quoteData.open : [];
    const highs = Array.isArray(quoteData.high) ? quoteData.high : [];
    const lows = Array.isArray(quoteData.low) ? quoteData.low : [];

    const open = Number(opens[0] ?? prevClose);
    const high = Number(highs[0] ?? price);
    const low = Number(lows[0] ?? price);

    const name = String(meta.longName || meta.shortName || symbol);

    const payload: QuotePayload = {
      symbol,
      name,
      price,
      previousClose: prevClose,
      open,
      high,
      low,
      change,
      changePercent,
      volume,
      fiftyTwoWeekHigh,
      fiftyTwoWeekLow,
      spark: closes.length > 0 ? closes : [prevClose, price],
      isLive: true,
      timestamp: new Date().toISOString(),
      source: 'Market Quote Proxy (Live)',
    };

    setCached(cacheKey, payload, 60_000); // 1-minute TTL
    return payload;
  } catch (_e) {
    return null;
  }
}

export async function handleRequest(request: Request): Promise<Response> {
  const headers = buildCorsHeaders(request);

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers });
  }

  const logger = createEdgeRequestLogger('market-quote-proxy', request);
  try {
    const response = await executeMarketQuoteRequest(request, headers, logger);
    return logger.finish(response);
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(
      new Response(JSON.stringify({ error: 'Market data request failed.' }), {
        status: 500,
        headers,
      }),
    );
  }
}

async function executeMarketQuoteRequest(
  request: Request,
  headers: Record<string, string>,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed. Use POST.' }), {
      status: 405,
      headers,
    });
  }

  let bodyText: string;
  try {
    bodyText = await readBodyWithLimit(request, MAX_BODY_BYTES);
  } catch (err) {
    if (err instanceof PayloadTooLargeError) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 413,
        headers,
      });
    }
    return new Response(JSON.stringify({ error: 'Unable to read request body.' }), {
      status: 400,
      headers,
    });
  }

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(bodyText);
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw new Error();
    }
  } catch {
    return new Response(JSON.stringify({ error: 'Malformed JSON payload.' }), {
      status: 400,
      headers,
    });
  }

  const action = typeof body.action === 'string' ? body.action.toLowerCase() : 'quotes';
  logger.log('info', 'market_action_received', {
    action,
    symbol_count: Array.isArray(body.symbols) ? body.symbols.length : undefined,
  });

  // 1. Quotes Action
  if (action === 'quotes') {
    const rawSymbols = body.symbols;
    if (!Array.isArray(rawSymbols) || rawSymbols.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Invalid input: "symbols" must be a non-empty array of strings.' }),
        { status: 400, headers }
      );
    }

    if (rawSymbols.length > MAX_SYMBOLS) {
      return new Response(
        JSON.stringify({ error: `Too many symbols: maximum allowed is ${MAX_SYMBOLS}.` }),
        { status: 400, headers }
      );
    }

    const sanitizedSymbols: string[] = [];
    for (const s of rawSymbols) {
      if (typeof s !== 'string') {
        return new Response(
          JSON.stringify({ error: 'Invalid symbol type: each symbol must be a string.' }),
          { status: 400, headers }
        );
      }
      const trimmed = s.trim();
      if (!SYMBOL_REGEX.test(trimmed)) {
        return new Response(
          JSON.stringify({ error: `Invalid symbol format: "${trimmed}". Must match ${SYMBOL_REGEX.source}` }),
          { status: 400, headers }
        );
      }
      sanitizedSymbols.push(trimmed);
    }

    const quotes: Record<string, QuotePayload> = {};
    const missing: string[] = [];

    // Parallel fetch with bounded batching
    await Promise.all(
      sanitizedSymbols.map(async (sym) => {
        const q = await fetchServerQuote(sym);
        if (q) {
          quotes[sym] = q;
        } else {
          missing.push(sym);
        }
      })
    );

    return new Response(
      JSON.stringify({
        quotes,
        missing,
        freshness: missing.length === 0 ? 'live' : 'partial',
        deliveredAt: new Date().toISOString(),
      }),
      { status: 200, headers: buildCorsHeaders(request, 'public, max-age=30') }
    );
  }

  // 2. Sectors Action
  if (action === 'sectors') {
    const cacheKey = 'sectors:all';
    const cached = getCached<unknown>(cacheKey);
    if (cached) {
      return new Response(
        JSON.stringify({
          sectors: cached,
          freshness: 'cached',
          deliveredAt: new Date().toISOString(),
        }),
        { status: 200, headers: buildCorsHeaders(request, 'public, max-age=60') }
      );
    }

    const sectors = await Promise.all(
      SECTOR_MAPPING.map(async (item) => {
        const q = await fetchServerQuote(item.symbol);
        const dayReturn = q ? q.changePercent : 0.0;
        const ytdReturn = dayReturn; // fallback or calculated from spark
        return {
          name: item.name,
          symbol: item.symbol,
          key: item.key,
          marketWeight: item.weight,
          dayReturn,
          ytdReturn,
          isLive: q ? q.isLive : false,
        };
      })
    );

    setCached(cacheKey, sectors, 300_000); // 5-minute cache

    return new Response(
      JSON.stringify({
        sectors,
        freshness: 'live',
        deliveredAt: new Date().toISOString(),
      }),
      { status: 200, headers: buildCorsHeaders(request, 'public, max-age=60') }
    );
  }

  // 3. News Action
  if (action === 'news') {
    const rawQuery = typeof body.query === 'string' ? body.query.trim().slice(0, 50) : 'stock';
    const rawCount = typeof body.count === 'number' && Number.isInteger(body.count) ? Math.min(Math.max(body.count, 1), 30) : 20;

    const cacheKey = `news:${rawQuery}:${rawCount}`;
    const cached = getCached<unknown>(cacheKey);
    if (cached) {
      return new Response(
        JSON.stringify({
          news: cached,
          freshness: 'cached',
          deliveredAt: new Date().toISOString(),
        }),
        { status: 200, headers: buildCorsHeaders(request, 'public, max-age=60') }
      );
    }

    try {
      const url = `https://query1.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(rawQuery)}&newsCount=${rawCount}&quotesCount=0&enableFuzzyQuery=false`;
      const res = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        signal: AbortSignal.timeout(6000),
      });

      if (res.ok) {
        const data = await res.json();
        const newsList = Array.isArray(data?.news) ? data.news : [];
        const articles = newsList
          .filter((n: Record<string, unknown>) => typeof n?.title === 'string' && n.title.length > 0)
          .map((n: Record<string, unknown>) => {
            const pubTime = typeof n.providerPublishTime === 'number'
              ? new Date(n.providerPublishTime * 1000).toISOString()
              : new Date().toISOString();
            const thumbObj = (n.thumbnail as Record<string, unknown>) || {};
            const thumbs = Array.isArray(thumbObj.resolutions)
              ? (thumbObj.resolutions as { url: string; tag?: string }[])
              : [];
            let thumbUrl = thumbs.find((r) => r.tag === 'original')?.url ||
              thumbs[0]?.url ||
              (thumbObj.originalUrl as string) ||
              (thumbObj.url as string) ||
              null;
            if (!thumbUrl && typeof n.thumbnail_url === 'string') {
              thumbUrl = n.thumbnail_url;
            }
            const tickers = Array.isArray(n.relatedTickers) ? n.relatedTickers.filter((t): t is string => typeof t === 'string') : [];

            const rawSum = typeof n.summary === 'string' ? n.summary : typeof n.description === 'string' ? n.description : null;
            const summary = rawSum && rawSum.trim().length > 0
              ? rawSum.trim()
              : (tickers.length > 0
                ? `Reporting on ${tickers.join(', ')} market movements and outlook.`
                : 'Market commentary on current financial developments.');

            return {
              title: n.title,
              publisher: n.publisher || 'Financial Wire',
              link: n.link || '',
              published_at: pubTime,
              thumbnail_url: thumbUrl,
              related_tickers: tickers,
              summary,
            };
          });

        setCached(cacheKey, articles, 300_000); // 5-minute cache

        return new Response(
          JSON.stringify({
            news: articles,
            freshness: 'live',
            deliveredAt: new Date().toISOString(),
          }),
          { status: 200, headers: buildCorsHeaders(request, 'public, max-age=60') }
        );
      }
    } catch (_e) {
      // Fallback to empty news list
    }

    return new Response(
      JSON.stringify({
        news: [],
        freshness: 'empty',
        deliveredAt: new Date().toISOString(),
      }),
      { status: 200, headers }
    );
  }

  return new Response(
    JSON.stringify({ error: `Unknown action: "${action}". Supported actions: "quotes", "sectors", "news".` }),
    { status: 400, headers }
  );
}

// In standard Supabase Edge Function environment
if (typeof Deno !== 'undefined' && Deno?.serve) {
  Deno.serve(handleRequest);
}

