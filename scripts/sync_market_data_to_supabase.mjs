#!/usr/bin/env node
/**
 * AlphaJournal (AlphaJournal) — Automated Supabase Market Intelligence & News Sync
 *
 * Syncs tickers, live quotes, fundamentals, OHLCV price history, screeners, whole
 * company details (stock_details), and financial news articles directly into
 * Supabase Postgres tables via PostgREST.
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

const HAS_SERVICE_ROLE_KEY =
  (process.env.SUPABASE_SERVICE_ROLE_KEY || '').trim().length > 0;
let bearerToken = SUPABASE_SERVICE_ROLE_KEY;

// ---------------------------------------------------------------------------
// 200 Prominent Tickers (100 US + 100 India/NSE)
// ---------------------------------------------------------------------------
const PROMINENT_TICKERS = [
  // Magnificent Seven & Mega-Cap Tech
  "AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA",
  // Semiconductors & Hardware
  "AMD", "INTC", "AVGO", "QCOM", "TXN", "ARM", "MU", "AMAT", "LRCX", "KLAC",
  // Enterprise Software, Cloud & AI
  "CRM", "ORCL", "ADBE", "NOW", "PLTR", "SNOW", "PANW", "CRWD", "WDAY", "INTU",
  // Consumer Tech, Streaming & FinTech
  "NFLX", "UBER", "ABNB", "PYPL", "SQ", "COIN", "SHOP", "SPOT",
  // Financials & Banking
  "JPM", "BAC", "WFC", "MS", "GS", "BLK", "C", "AXP", "V", "MA",
  // Healthcare & Pharma
  "LLY", "UNH", "JNJ", "PFE", "MRK", "ABBV", "TMO", "DHR", "ISRG", "BMY", "AMGN", "GILD",
  // Retail & Consumer Goods
  "WMT", "COST", "TGT", "HD", "LOW", "MCD", "SBUX", "NKE", "KO", "PEP", "PG", "PM", "CL",
  // Industrials & Aerospace
  "GE", "CAT", "DE", "BA", "LMT", "RTX", "HON", "UNP", "UPS", "FDX",
  // Energy & Utilities
  "XOM", "CVX", "COP", "SLB", "EOG", "NEE", "DUK", "SO",
  // Telecom & Media
  "T", "VZ", "DIS", "CMCSA",
  // Broad Market & Sector ETFs
  "SPY", "QQQ", "DIA", "IWM", "VOO", "VTI", "XLK", "XLF", "XLE", "XLV", "SMH",
  // Major Crypto Pairs
  "BTC-USD", "ETH-USD", "SOL-USD", "BNB-USD", "XRP-USD",
  // Benchmark Indices
  "^NSEI", "^NSEBANK", "^BSESN",
  // Nifty 50 Heavyweights
  "RELIANCE.NS", "TCS.NS", "HDFCBANK.NS", "INFY.NS", "ICICIBANK.NS",
  "BHARTIARTL.NS", "SBIN.NS", "ITC.NS", "LT.NS", "HINDUNILVR.NS",
  "BAJFINANCE.NS", "KOTAKBANK.NS", "AXISBANK.NS", "HCLTECH.NS", "MARUTI.NS",
  "SUNPHARMA.NS", "TATAMOTORS.NS", "NTPC.NS", "ONGC.NS", "TITAN.NS",
  "POWERGRID.NS", "ADANIENT.NS", "ADANIPORTS.NS", "COALINDIA.NS", "TATASTEEL.NS",
  "BAJAJFINSV.NS", "ASIANPAINT.NS", "M&M.NS", "ULTRACEMCO.NS", "WIPRO.NS",
  "NESTLEIND.NS", "JSWSTEEL.NS", "TECHM.NS", "GRASIM.NS", "LTIM.NS",
  "SBILIFE.NS", "HDFCLIFE.NS", "DRREDDY.NS", "CIPLA.NS", "BRITANNIA.NS",
  "HEROMOTOCO.NS", "EICHERMOT.NS", "DIVISLAB.NS", "HINDALCO.NS", "APOLLOHOSP.NS",
  "BPCL.NS", "TRENT.NS", "BEL.NS", "SHREECEM.NS", "INDUSINDBK.NS",
  // Next 50 & High-Growth Midcaps
  "ZOMATO.NS", "JIOFIN.NS", "VBL.NS", "HAL.NS", "DLF.NS",
  "CHOLAFIN.NS", "SIEMENS.NS", "ABB.NS", "PFC.NS", "RECLTD.NS",
  "GAIL.NS", "IOC.NS", "TATAPOWER.NS", "POLYCAB.NS", "BHEL.NS",
  "IRFC.NS", "RVNL.NS", "SUZLON.NS", "IDEA.NS", "YESBANK.NS",
  "IDFCFIRSTB.NS", "FEDERALBNK.NS", "PNB.NS", "BANKBARODA.NS", "CANBK.NS",
  "UNIONBANK.NS", "AUROPHARMA.NS", "LUPIN.NS", "TORNTPHARM.NS", "MUTHOOTFIN.NS",
  "SHRIRAMFIN.NS", "TATACOMM.NS", "PERSISTENT.NS", "COFORGE.NS", "KPITTECH.NS",
  "DIXON.NS", "CGPOWER.NS", "MAXHEALTH.NS", "MANKIND.NS", "BOSCHLTD.NS",
  "PIDILITIND.NS", "HAVELLS.NS", "DABUR.NS", "GODREJCP.NS", "MARICO.NS",
  "COLPAL.NS", "BERGEPAINT.NS", "MOTHERSON.NS", "BALKRISIND.NS", "INDIGO.NS",
];

async function authenticateIfNeeded() {
  if (HAS_SERVICE_ROLE_KEY) {
    console.log('[sync] Using SUPABASE_SERVICE_ROLE_KEY for direct RLS bypass');
    return;
  }
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

async function upsertBatch(table, rows, onConflict, chunkSize = 150) {
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
      console.warn(`[sync] Upsert into ${table} warning (${res.status}): ${text.slice(0, 150)}`);
    } else {
      total += chunk.length;
    }
  }
  return total;
}

async function deleteQuery(tableAndQuery) {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/${tableAndQuery}`, {
      method: 'DELETE',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${bearerToken}`,
        Prefer: 'return=minimal',
      },
    });
    return res.ok;
  } catch (e) {
    console.warn(`[sync] Delete ${tableAndQuery} warning: ${e.message}`);
    return false;
  }
}

// ---------------------------------------------------------------------------
// Step 1: Clean Stale Database Records
// ---------------------------------------------------------------------------
async function cleanDatabase() {
  console.log('[sync] Step 1: Cleaning stale database records...');
  const cutoffDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  await deleteQuery(`stock_price_history?date=lt.${cutoffDate}`);
  console.log(`  [clean] Cleared price history older than ${cutoffDate}`);

  const cutoffNews = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  await deleteQuery(`news_articles?published_at=lt.${cutoffNews}`);
  console.log(`  [clean] Cleared news articles older than 7 days`);

  await deleteQuery(`screener_results?id=gt.0`);
  console.log('  [clean] Reset screener results table for fresh daily ranks');
}

// ---------------------------------------------------------------------------
// Yahoo Finance APIs
// ---------------------------------------------------------------------------
async function fetchYahooChart(symbol, range = '1mo', interval = '1d') {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(
    symbol
  )}?range=${range}&interval=${interval}`;
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        Accept: 'application/json',
      },
    });
    if (!res.ok) return null;
    const payload = await res.json();
    return payload?.chart?.result?.[0] ?? null;
  } catch {
    return null;
  }
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
  const seenLinks = new Set();

  // 1. Yahoo Finance News Search for high resolution articles with thumbnails
  const yahooQueries = [
    'AAPL', 'NVDA', 'MSFT', 'GOOGL', 'AMZN', 'META', 'TSLA',
    'AMD', 'PLTR', 'CRM', 'ORCL',
    'JPM', 'GS', 'BAC', 'Federal Reserve',
    'LLY', 'PFE', 'BA', 'LMT',
    'BTC', 'ETH',
    'Sensex', 'Nifty', 'Reliance Industries', 'Tata Motors'
  ];

  for (const q of yahooQueries) {
    try {
      const url = `https://query2.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(q)}&newsCount=6`;
      const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (AlphaJournal-Sync/1.0)' } });
      if (!res.ok) continue;
      const data = await res.json();
      for (const item of (data.news || [])) {
        const link = (item.link || '').trim();
        const title = (item.title || '').trim();
        if (!link || !title || seenLinks.has(link)) continue;
        seenLinks.add(link);

        let thumbUrl = null;
        const resolutions = item.thumbnail?.resolutions || [];
        if (resolutions.length > 0) {
          const orig = resolutions.find((r) => r.tag === 'original');
          if (orig?.url) thumbUrl = orig.url;
          else {
            const best = [...resolutions].sort((a, b) => ((b.width || 0) * (b.height || 0)) - ((a.width || 0) * (a.height || 0)))[0];
            if (best?.url) thumbUrl = best.url;
          }
        }
        if (!thumbUrl && item.thumbnail?.originalUrl) thumbUrl = item.thumbnail.originalUrl;
        if (!thumbUrl && item.thumbnail?.url) thumbUrl = item.thumbnail.url;

        const publisher = item.publisher || 'Financial News';
        const summary = (item.summary || item.description || `Live reporting on ${q} and broader market developments.`).trim();
        if (!thumbUrl) {
          const text = `${title} ${summary} ${publisher}`.toLowerCase();
          thumbUrl = /crypto|bitcoin|btc|eth/.test(text)
            ? 'https://images.unsplash.com/photo-1621416894569-0f39ed31d247?w=800&auto=format&fit=crop&q=80'
            : /tech|ai|cloud|software|chip/.test(text)
            ? 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80'
            : /bank|rate|fed|treasury|rbi|yield/.test(text)
            ? 'https://images.unsplash.com/photo-1541354329998-f4d9a9f9297f?w=800&auto=format&fit=crop&q=80'
            : /pharma|drug|fda|biotech|health/.test(text)
            ? 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800&auto=format&fit=crop&q=80'
            : 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800&auto=format&fit=crop&q=80';
        }

        const pubTime = item.providerPublishTime
          ? new Date(item.providerPublishTime * 1000).toISOString()
          : new Date().toISOString();

        articles.push({
          title,
          summary: summary.slice(0, 500),
          link,
          publisher,
          thumbnail_url: thumbUrl,
          content_type: 'STORY',
          published_at: pubTime,
        });
      }
    } catch (_) {}
  }

  // 2. RSS Feeds
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
      while ((match = itemRegex.exec(xml)) !== null && count < 20) {
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
        const rawDesc = (
          block.match(
            /<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>/i
          )?.[1] ||
          block.match(/<description>([\s\S]*?)<\/description>/i)?.[1] ||
          ''
        );
        const summary = rawDesc.replace(/<[^>]+>/g, '').trim();
        const pubDateRaw = block.match(/<pubDate>([\s\S]*?)<\/pubDate>/i)?.[1];
        if (!title || !link || seenLinks.has(link)) continue;
        seenLinks.add(link);

        let thumbUrl = block.match(/<img[^>]+src=["']([^"']+)["']/i)?.[1] ||
          rawDesc.match(/&lt;img[^>]+src=&quot;([^&"]+)&quot;/i)?.[1] ||
          block.match(/<enclosure[^>]+url=["']([^"']+)["']/i)?.[1] ||
          block.match(/<media:content[^>]+url=["']([^"']+)["']/i)?.[1] ||
          null;

        if (!thumbUrl) {
          const text = `${title} ${summary} ${feed.publisher}`.toLowerCase();
          thumbUrl = /crypto|bitcoin|btc|eth/.test(text)
            ? 'https://images.unsplash.com/photo-1621416894569-0f39ed31d247?w=800&auto=format&fit=crop&q=80'
            : /tech|ai|cloud|software|chip/.test(text)
            ? 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80'
            : /bank|rate|fed|treasury|rbi|yield/.test(text)
            ? 'https://images.unsplash.com/photo-1541354329998-f4d9a9f9297f?w=800&auto=format&fit=crop&q=80'
            : /pharma|drug|fda|biotech|health/.test(text)
            ? 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800&auto=format&fit=crop&q=80'
            : 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800&auto=format&fit=crop&q=80';
        }

        const publishedAt = pubDateRaw
          ? new Date(pubDateRaw).toISOString()
          : new Date().toISOString();
        articles.push({
          title,
          summary: summary || title,
          link,
          publisher: feed.publisher,
          thumbnail_url: thumbUrl,
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

// ---------------------------------------------------------------------------
// Step 2: Sync Tickers, Quotes, Fundamentals, History, and Whole Company Details
// ---------------------------------------------------------------------------
async function syncTickersAndQuotes() {
  const symbols = PROMINENT_TICKERS.slice(0, 200);
  console.log(`[sync] Processing ${symbols.length} prominent company & asset targets...`);

  const tickerRows = [];
  const quoteRows = [];
  const fundamentalRows = [];
  const historyRows = [];
  const detailRows = [];

  const batchSize = 10;
  for (let i = 0; i < symbols.length; i += batchSize) {
    const slice = symbols.slice(i, i + batchSize);
    await Promise.all(
      slice.map(async (symbol) => {
        const isIN = symbol.endsWith('.NS') || symbol.endsWith('.BO') || symbol.startsWith('^');
        const isCrypto = symbol.endsWith('-USD');
        const market = isIN ? 'IN' : (isCrypto ? 'CRYPTO' : 'US');
        const exchange = isIN ? 'NSE' : (isCrypto ? 'CRYPTO' : 'NASDAQ');
        const currency = isIN ? 'INR' : 'USD';
        const assetType = symbol.startsWith('^') ? 'INDEX' : (isCrypto ? 'CRYPTO' : 'EQUITY');

        const chart = await fetchYahooChart(symbol, '1mo', '1d');
        const meta = chart?.meta || {};

        const price = Number(meta.regularMarketPrice ?? 0);
        const prevClose = Number(meta.chartPreviousClose ?? meta.previousClose ?? price);
        const dayHigh = Number(meta.regularMarketDayHigh ?? price);
        const dayLow = Number(meta.regularMarketDayLow ?? price);
        const volume = Number(meta.regularMarketVolume ?? 0);
        const changePct = prevClose > 0 ? Number((((price - prevClose) / prevClose) * 100).toFixed(2)) : 0;
        const name = meta.longName || meta.shortName || symbol;

        tickerRows.push({
          ticker: symbol,
          name,
          market,
          exchange,
          currency,
          asset_type: assetType,
          last_seen_at: new Date().toISOString(),
        });

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

          fundamentalRows.push({
            ticker: symbol,
            fifty_two_week_high: dayHigh,
            fifty_two_week_low: dayLow,
            updated_at: new Date().toISOString(),
          });
        }

        // Process Historical Daily Bars
        const timestamps = chart?.timestamp || [];
        const indicators = chart?.indicators?.quote?.[0] || {};
        const opens = indicators.open || [];
        const highs = indicators.high || [];
        const lows = indicators.low || [];
        const closes = indicators.close || [];
        const volumes = indicators.volume || [];

        const recentBars = [];
        for (let idx = 0; idx < timestamps.length; idx++) {
          const ts = timestamps[idx];
          if (ts && closes[idx] != null) {
            const dateStr = new Date(ts * 1000).toISOString().slice(0, 10);
            const bOpen = opens[idx] ?? closes[idx];
            const bHigh = highs[idx] ?? closes[idx];
            const bLow = lows[idx] ?? closes[idx];
            const bClose = closes[idx];
            const bVol = Math.round(volumes[idx] || 0);

            recentBars.push({
              date: dateStr,
              open: bOpen,
              high: bHigh,
              low: bLow,
              close: bClose,
              volume: bVol,
            });

            historyRows.push({
              ticker: symbol,
              date: dateStr,
              open: bOpen,
              high: bHigh,
              low: bLow,
              close: bClose,
              volume: bVol,
              recorded_at: new Date().toISOString(),
            });
          }
        }

        // Whole Company Detail Object for stock_details table
        const wholeDetail = {
          ticker: symbol,
          name,
          summary: {
            name,
            market,
            exchange,
            currency,
            asset_type: assetType,
          },
          quote: {
            price,
            previous_close: prevClose,
            day_high: dayHigh,
            day_low: dayLow,
            volume,
            change_pct: changePct,
          },
          history: recentBars.slice(-30),
          updated_at: new Date().toISOString(),
        };

        detailRows.push({
          ticker: symbol,
          detail: wholeDetail,
          fetched_at: new Date().toISOString(),
        });
      })
    );
  }

  const uTickers = await upsertBatch('tickers', tickerRows, 'ticker');
  const uQuotes = await upsertBatch('stock_quotes', quoteRows, 'ticker');
  const uFund = await upsertBatch('stock_fundamentals', fundamentalRows, 'ticker');
  const uHist = await upsertBatch('stock_price_history', historyRows, 'ticker,date', 250);
  const uDetail = await upsertBatch('stock_details', detailRows, 'ticker', 50);

  console.log(`[sync] Upserted ${uTickers} tickers, ${uQuotes} quotes, ${uFund} fundamentals, ${uHist} history, ${uDetail} whole details`);
  return { quoteRows, symbols };
}

// ---------------------------------------------------------------------------
// Step 3: Sync Screeners
// ---------------------------------------------------------------------------
async function syncScreeners(quoteRows) {
  if (!quoteRows || quoteRows.length === 0) return;

  const usQuotes = quoteRows.filter(
    (q) => !q.ticker.endsWith('.NS') && !q.ticker.endsWith('-USD') && !q.ticker.startsWith('^')
  );
  const inQuotes = quoteRows.filter((q) => q.ticker.endsWith('.NS'));
  const cryptoQuotes = quoteRows.filter((q) => q.ticker.endsWith('-USD'));

  const categories = [
    {
      name: 'top_gainers',
      category_type: 'GLOBAL',
      quotes: [...usQuotes].sort((a, b) => b.change_pct - a.change_pct).slice(0, 15),
    },
    {
      name: 'top_losers',
      category_type: 'GLOBAL',
      quotes: [...usQuotes].sort((a, b) => a.change_pct - b.change_pct).slice(0, 15),
    },
    {
      name: 'most_active',
      category_type: 'GLOBAL',
      quotes: [...usQuotes].sort((a, b) => b.volume - a.volume).slice(0, 15),
    },
    {
      name: 'india_top_gainers',
      category_type: 'IN',
      quotes: [...inQuotes].sort((a, b) => b.change_pct - a.change_pct).slice(0, 15),
    },
    {
      name: 'india_top_losers',
      category_type: 'IN',
      quotes: [...inQuotes].sort((a, b) => a.change_pct - b.change_pct).slice(0, 15),
    },
    {
      name: 'crypto_all',
      category_type: 'CRYPTO',
      quotes: [...cryptoQuotes].sort((a, b) => b.volume - a.volume).slice(0, 10),
    },
  ];

  const catRows = categories.map((c) => ({
    name: c.name,
    category_type: c.category_type,
  }));
  await upsertBatch('screener_categories', catRows, 'name');

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
  const snapshotRows = [];
  for (const cat of categories) {
    const categoryId = idByName.get(cat.name);
    if (!categoryId) continue;
    cat.quotes.forEach((q, idx) => {
      resultRows.push({
        category_id: categoryId,
        ticker: q.ticker,
        rank: idx + 1,
        price: q.price,
        change_pct: q.change_pct,
        extra_data: q,
      });
    });
    snapshotRows.push({
      category_id: categoryId,
      payload: { name: cat.name, category_type: cat.category_type, quotes: cat.quotes },
      exported_at: new Date().toISOString(),
    });
  }

  await upsertBatch('screener_results', resultRows, null);
  await upsertBatch('market_screener_snapshots', snapshotRows, 'category_id');
  console.log(`[sync] Upserted ${resultRows.length} screener results across ${categories.length} categories`);
}

// ---------------------------------------------------------------------------
// Step 4: Sync News
// ---------------------------------------------------------------------------
async function syncNews(symbols) {
  const liveNews = await fetchLiveRssNews();
  if (liveNews.length === 0) return;

  const upsertedNews = await upsertBatch('news_articles', liveNews, 'link');
  console.log(`[sync] Upserted ${upsertedNews} news articles`);

  const articlesRes = await fetch(
    `${SUPABASE_URL}/rest/v1/news_articles?select=id,title,summary&limit=100`,
    {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${bearerToken}`,
      },
    }
  );
  if (articlesRes.ok) {
    const storedArticles = await articlesRes.json();
    const symbolSet = new Set(symbols);
    const links = [];

    for (const art of storedArticles) {
      const text = `${art.title || ''} ${art.summary || ''}`.toUpperCase();
      for (const sym of symbolSet) {
        const clean = sym.replace('.NS', '').replace('-USD', '');
        if (clean.length >= 3 && text.includes(clean)) {
          links.push({
            article_id: art.id,
            ticker: sym,
          });
        }
      }
    }
    if (links.length > 0) {
      await upsertBatch('news_article_tickers', links, 'article_id,ticker');
      console.log(`[sync] Linked ${links.length} ticker-news relationships`);
    }
  }
}

// ---------------------------------------------------------------------------
// Main Pipeline
// ---------------------------------------------------------------------------
async function main() {
  console.log(`[sync] Starting AlphaJournal Market & Database Pipeline`);
  await authenticateIfNeeded();

  await cleanDatabase();
  const { quoteRows, symbols } = await syncTickersAndQuotes();
  await syncScreeners(quoteRows);
  await syncNews(symbols);

  console.log('[sync] Pipeline execution successfully completed.');
}

main().catch((err) => {
  console.error('[sync] Fatal error:', err);
  process.exit(1);
});
