#!/usr/bin/env node
/**
 * AlphaJournal (TradeX) — Automated Supabase Market Intelligence & News Sync
 *
 * Syncs tickers, live quotes, fundamentals, OHLCV price history, screeners, and
 * financial news articles directly into Supabase Postgres tables via PostgREST.
 *
 * Usage:
 *   SUPABASE_URL="https://<project-ref>.supabase.co" \
 *   SUPABASE_SERVICE_ROLE_KEY="<service-role-or-anon-key>" \
 *   node scripts/sync_market_data_to_supabase.mjs [--scope=all|quotes|history|news|screeners] [--live=true]
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');
const DATA_DIR = path.join(ROOT_DIR, 'assets', 'data');

const SUPABASE_URL = (process.env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
const SUPABASE_SERVICE_ROLE_KEY = (
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_ANON_KEY ||
  ''
).trim();
const SUPABASE_ADMIN_EMAIL = (process.env.SUPABASE_ADMIN_EMAIL || '').trim();
const SUPABASE_ADMIN_PASSWORD = (process.env.SUPABASE_ADMIN_PASSWORD || '').trim();

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    '[sync] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variable.'
  );
  process.exit(1);
}

const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const clean = arg.replace(/^--/, '');
    const [k, v = 'true'] = clean.split('=');
    return [k, v];
  })
);
const SYNC_SCOPE = (args.scope || process.env.SYNC_SCOPE || 'all').toLowerCase();
const FETCH_LIVE = (args.live || process.env.FETCH_LIVE || 'true').toLowerCase() !== 'false';

let bearerToken = SUPABASE_SERVICE_ROLE_KEY;

async function authenticateIfNeeded() {
  if (!SUPABASE_ADMIN_EMAIL || !SUPABASE_ADMIN_PASSWORD) {
    return;
  }
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: SUPABASE_ADMIN_EMAIL,
        password: SUPABASE_ADMIN_PASSWORD,
      }),
    });
    if (res.ok) {
      const json = await res.json();
      if (json.access_token) {
        bearerToken = json.access_token;
        console.log(`[sync] Authenticated as ${SUPABASE_ADMIN_EMAIL}`);
      }
    }
  } catch (err) {
    console.warn(`[sync] Admin password auth skipped: ${err.message}`);
  }
}

function readJsonFile(relPath) {
  const fullPath = path.join(DATA_DIR, relPath);
  if (!fs.existsSync(fullPath)) return null;
  return JSON.parse(fs.readFileSync(fullPath, 'utf8'));
}

async function upsertBatch(table, rows, onConflict, chunkSize = 250) {
  if (!Array.isArray(rows) || rows.length === 0) return 0;
  let total = 0;
  const query = onConflict ? `?on_conflict=${encodeURIComponent(onConflict)}` : '';
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}${query}`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${bearerToken}`,
        'Content-Type': 'application/json',
        Prefer: 'resolution=merge-duplicates,return=minimal',
      },
      body: JSON.stringify(chunk),
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Upsert into ${table} failed (${res.status}): ${text}`);
    }
    total += chunk.length;
  }
  return total;
}

async function fetchYahooChart(symbol, range = '1mo', interval = '1d') {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(
    symbol
  )}?range=${range}&interval=${interval}`;
  const res = await fetch(url, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      Accept: 'application/json',
    },
  });
  if (!res.ok) return null;
  const payload = await res.json();
  return payload?.chart?.result?.[0] ?? null;
}

async function fetchLiveRssNews() {
  const feeds = [
    {
      publisher: 'Economic Times Markets',
      url: 'https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms',
    },
    {
      publisher: 'Moneycontrol Markets',
      url: 'https://www.moneycontrol.com/rss/MCtopnews.xml',
    },
    {
      publisher: 'Yahoo Finance',
      url: 'https://finance.yahoo.com/news/rssindex',
    },
  ];
  const articles = [];
  for (const feed of feeds) {
    try {
      const res = await fetch(feed.url, {
        headers: { 'User-Agent': 'AlphaJournalMarketSync/1.0' },
      });
      if (!res.ok) continue;
      const xml = await res.text();
      const itemRegex = /<item>([\s\S]*?)<\/item>/gi;
      let match;
      let count = 0;
      while ((match = itemRegex.exec(xml)) !== null && count < 15) {
        const block = match[1];
        const title = (
          block.match(/<title><!\[CDATA\[([\s\S]*?)\]\]><\/title>/i)?.[1] ||
          block.match(/<title>([\s\S]*?)<\/title>/i)?.[1] ||
          ''
        )
          .replace(/<[^>]+>/g, '')
          .trim();
        const link = (
          block.match(/<link>([\s\S]*?)<\/link>/i)?.[1] || ''
        ).trim();
        const summary = (
          block.match(
            /<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>/i
          )?.[1] ||
          block.match(/<description>([\s\S]*?)<\/description>/i)?.[1] ||
          ''
        )
          .replace(/<[^>]+>/g, '')
          .trim();
        const pubDateRaw = block.match(/<pubDate>([\s\S]*?)<\/pubDate>/i)?.[1];
        if (!title || !link) continue;
        const idHash = Buffer.from(link)
          .toString('base64url')
          .slice(0, 32);
        const publishedAt = pubDateRaw
          ? new Date(pubDateRaw).toISOString()
          : new Date().toISOString();
        articles.push({
          id: `rss_${idHash}`,
          title,
          summary: summary || title,
          link,
          publisher: feed.publisher,
          thumbnail_url: null,
          content_type: 'STORY',
          published_at: Number.isNaN(Date.parse(publishedAt))
            ? new Date().toISOString()
            : publishedAt,
        });
        count++;
      }
    } catch (err) {
      console.warn(`[sync] RSS fetch warning (${feed.publisher}): ${err.message}`);
    }
  }
  return articles;
}

async function syncTickersAndQuotes() {
  const universe = readJsonFile('tickers/universe.json') || [];
  const quotesSeed = readJsonFile('quotes.json') || {};
  const fundamentalsSeed = readJsonFile('fundamentals.json') || {};

  const tickerMap = new Map();
  for (const item of universe) {
    if (!item?.ticker) continue;
    tickerMap.set(item.ticker, {
      ticker: item.ticker,
      name: item.name || item.ticker,
      market:
        item.market ||
        (item.ticker.endsWith('.NS')
          ? 'IN'
          : item.ticker.endsWith('-USD')
          ? 'CRYPTO'
          : 'US'),
      exchange: item.exchange || (item.ticker.endsWith('.NS') ? 'NSE' : 'NASDAQ'),
      currency: item.currency || (item.ticker.endsWith('.NS') ? 'INR' : 'USD'),
      asset_type: item.asset_type || 'EQUITY',
    });
  }
  for (const [symbol, q] of Object.entries(quotesSeed)) {
    if (!tickerMap.has(symbol)) {
      tickerMap.set(symbol, {
        ticker: symbol,
        name: q.name || symbol,
        market:
          q.market ||
          (symbol.endsWith('.NS')
            ? 'IN'
            : symbol.endsWith('-USD')
            ? 'CRYPTO'
            : 'US'),
        exchange: q.exchange || (symbol.endsWith('.NS') ? 'NSE' : 'NASDAQ'),
        currency: q.currency || (symbol.endsWith('.NS') ? 'INR' : 'USD'),
        asset_type: 'EQUITY',
      });
    }
  }

  const tickersRows = Array.from(tickerMap.values());
  const upsertedTickers = await upsertBatch('tickers', tickersRows, 'ticker');
  console.log(`[sync] Upserted ${upsertedTickers} tickers`);

  const quoteRows = [];
  const symbols = tickersRows.map((t) => t.ticker);

  for (const symbol of symbols) {
    const seed = quotesSeed[symbol] || {};
    let price = Number(seed.price ?? seed.regularMarketPrice ?? 0);
    let prevClose = Number(seed.previous_close ?? seed.regularMarketPreviousClose ?? price);
    let dayHigh = Number(seed.day_high ?? seed.regularMarketDayHigh ?? price);
    let dayLow = Number(seed.day_low ?? seed.regularMarketDayLow ?? price);
    let volume = Number(seed.volume ?? seed.regularMarketVolume ?? 0);
    let changePct = Number(seed.change_pct ?? seed.regularMarketChangePercent ?? 0);

    if (FETCH_LIVE) {
      try {
        const live = await fetchYahooChart(symbol, '5d', '1d');
        const meta = live?.meta;
        if (meta?.regularMarketPrice) {
          price = Number(meta.regularMarketPrice);
          prevClose = Number(meta.chartPreviousClose ?? meta.previousClose ?? price);
          dayHigh = Number(meta.regularMarketDayHigh ?? price);
          dayLow = Number(meta.regularMarketDayLow ?? price);
          volume = Number(meta.regularMarketVolume ?? volume);
          changePct =
            prevClose > 0 ? Number((((price - prevClose) / prevClose) * 100).toFixed(2)) : 0;
        }
      } catch (_) {
        // Keep seed fallback if rate-limited
      }
    }

    if (price > 0) {
      quoteRows.push({
        ticker: symbol,
        price,
        previous_close: prevClose,
        day_high: dayHigh,
        day_low: dayLow,
        volume: Math.round(volume),
        change_pct: changePct,
        updated_at: new Date().toISOString(),
      });
    }
  }

  const upsertedQuotes = await upsertBatch('stock_quotes', quoteRows, 'ticker');
  console.log(`[sync] Upserted ${upsertedQuotes} stock_quotes`);

  const fundamentalRows = [];
  for (const [symbol, f] of Object.entries(fundamentalsSeed)) {
    if (!tickerMap.has(symbol)) continue;
    fundamentalRows.push({
      ticker: symbol,
      sector: f.sector || null,
      industry: f.industry || null,
      market_cap: f.market_cap != null ? Math.round(Number(f.market_cap)) : null,
      pe_ratio: f.pe_ratio != null ? Number(f.pe_ratio) : null,
      forward_pe: f.forward_pe != null ? Number(f.forward_pe) : null,
      pb_ratio: f.pb_ratio != null ? Number(f.pb_ratio) : null,
      dividend_yield: f.dividend_yield != null ? Number(f.dividend_yield) : null,
      roe: f.roe != null ? Number(f.roe) : null,
      profit_margins: f.profit_margins != null ? Number(f.profit_margins) : null,
      beta: f.beta != null ? Number(f.beta) : null,
      fifty_two_week_high:
        f.fifty_two_week_high != null ? Number(f.fifty_two_week_high) : null,
      fifty_two_week_low:
        f.fifty_two_week_low != null ? Number(f.fifty_two_week_low) : null,
      summary: f.summary || null,
      updated_at: new Date().toISOString(),
    });
  }
  const upsertedFundamentals = await upsertBatch(
    'stock_fundamentals',
    fundamentalRows,
    'ticker'
  );
  console.log(`[sync] Upserted ${upsertedFundamentals} stock_fundamentals`);
  return tickerMap;
}

async function syncPriceHistory(tickerMap) {
  const historyDir = path.join(DATA_DIR, 'history');
  const historyRows = [];

  if (fs.existsSync(historyDir)) {
    const files = fs.readdirSync(historyDir).filter((f) => f.endsWith('.json'));
    for (const file of files) {
      const symbol = file.replace(/\.json$/, '');
      if (tickerMap && !tickerMap.has(symbol)) continue;
      const parsed = readJsonFile(`history/${file}`);
      const bars = Array.isArray(parsed?.data) ? parsed.data : [];
      for (const bar of bars.slice(-120)) {
        const dateStr = String(bar.date || '').slice(0, 10);
        if (!dateStr) continue;
        historyRows.push({
          ticker: symbol,
          date: dateStr,
          open: bar.open != null ? Number(bar.open) : null,
          high: bar.high != null ? Number(bar.high) : null,
          low: bar.low != null ? Number(bar.low) : null,
          close: bar.close != null ? Number(bar.close) : null,
          volume: bar.volume != null ? Math.round(Number(bar.volume)) : 0,
        });
      }
    }
  }

  const upserted = await upsertBatch(
    'stock_price_history',
    historyRows,
    'ticker,date',
    500
  );
  console.log(`[sync] Upserted ${upserted} stock_price_history OHLCV rows`);
}

async function syncNews(tickerMap) {
  const seedNews = readJsonFile('all_news.json') || [];
  const liveNews = FETCH_LIVE ? await fetchLiveRssNews() : [];

  const articlesById = new Map();
  const articleTickerLinks = [];

  for (const item of [...liveNews, ...seedNews]) {
    const id = String(item.id || '').trim();
    const title = String(item.title || '').trim();
    const link = String(item.link || '').trim();
    if (!id || !title || !link) continue;

    articlesById.set(id, {
      id,
      title,
      summary: item.summary || title,
      link,
      publisher: item.publisher || 'Market Wire',
      thumbnail_url: item.thumbnail_url || null,
      content_type: item.content_type || 'STORY',
      published_at: item.published_at || new Date().toISOString(),
    });

    const related = Array.isArray(item.related_tickers)
      ? item.related_tickers
      : [];
    for (const sym of related) {
      if (!tickerMap || tickerMap.has(sym)) {
        articleTickerLinks.push({
          article_id: id,
          ticker: sym,
        });
      }
    }
  }

  const newsRows = Array.from(articlesById.values());
  const upsertedNews = await upsertBatch('news_articles', newsRows, 'id');
  console.log(`[sync] Upserted ${upsertedNews} news_articles`);

  if (articleTickerLinks.length > 0) {
    const upsertedLinks = await upsertBatch(
      'news_article_tickers',
      articleTickerLinks,
      'article_id,ticker'
    );
    console.log(`[sync] Upserted ${upsertedLinks} news_article_tickers`);
  }
}

async function syncScreeners(tickerMap) {
  const screenersSeed = readJsonFile('screeners.json') || {};
  const categoryNames = Object.keys(screenersSeed);
  if (categoryNames.length === 0) return;

  const categoryRows = categoryNames.map((name) => ({
    name,
    category_type: name.startsWith('india_') ? 'IN' : 'GLOBAL',
  }));
  await upsertBatch('screener_categories', categoryRows, 'name');

  const catsRes = await fetch(
    `${SUPABASE_URL}/rest/v1/screener_categories?select=id,name`,
    {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${bearerToken}`,
      },
    }
  );
  if (!catsRes.ok) return;
  const cats = await catsRes.json();
  const idByName = new Map(cats.map((c) => [c.name, c.id]));

  const resultRows = [];
  for (const [name, payload] of Object.entries(screenersSeed)) {
    const categoryId = idByName.get(name);
    if (!categoryId) continue;
    const quotes = Array.isArray(payload?.quotes) ? payload.quotes : [];
    quotes.forEach((q, idx) => {
      const symbol = q.ticker || q.symbol;
      if (!symbol || (tickerMap && !tickerMap.has(symbol))) return;
      resultRows.push({
        category_id: categoryId,
        ticker: symbol,
        rank: idx + 1,
        price: Number(q.price ?? q.regularMarketPrice ?? 0),
        change_pct: Number(q.change_pct ?? q.regularMarketChangePercent ?? 0),
        extra_data: q,
        updated_at: new Date().toISOString(),
      });
    });
  }

  if (resultRows.length > 0) {
    const upserted = await upsertBatch(
      'screener_results',
      resultRows,
      'category_id,ticker'
    );
    console.log(`[sync] Upserted ${upserted} screener_results`);
  }
}

async function main() {
  console.log(
    `[sync] Starting Supabase Market Sync (scope=${SYNC_SCOPE}, live=${FETCH_LIVE})`
  );
  await authenticateIfNeeded();

  let tickerMap = null;
  if (
    SYNC_SCOPE === 'all' ||
    SYNC_SCOPE === 'quotes' ||
    SYNC_SCOPE === 'history' ||
    SYNC_SCOPE === 'news' ||
    SYNC_SCOPE === 'screeners'
  ) {
    tickerMap = await syncTickersAndQuotes();
  }
  if (SYNC_SCOPE === 'all' || SYNC_SCOPE === 'history') {
    await syncPriceHistory(tickerMap);
  }
  if (SYNC_SCOPE === 'all' || SYNC_SCOPE === 'news') {
    await syncNews(tickerMap);
  }
  if (SYNC_SCOPE === 'all' || SYNC_SCOPE === 'screeners') {
    await syncScreeners(tickerMap);
  }
  console.log('[sync] Market database synchronization complete.');
}

main().catch((err) => {
  console.error('[sync] Fatal error:', err);
  process.exit(1);
});
