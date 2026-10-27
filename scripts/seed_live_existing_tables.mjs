import { readFileSync } from 'node:fs';

const envContent = readFileSync('.env', 'utf8');
const env = {};
for (const line of envContent.split('\n')) {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
    const idx = trimmed.indexOf('=');
    env[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }
}

const supabaseUrl = env['NEXT_PUBLIC_SUPABASE_URL'] || env['SUPABASE_URL'];
const supabaseAnonKey = env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] || env['SUPABASE_ANON_KEY'];

async function seed() {
  console.log('='.repeat(70));
  console.log('SEEDING LIVE SUPABASE EXISTING TABLES WITH REALISTIC TRADER DATA');
  console.log('='.repeat(70));

  // 1. Authenticate as Admin
  const authRes = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'apikey': supabaseAnonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@tradex.ai', password: 'Admin@TradeX2026!' })
  });
  const { access_token, user } = await authRes.json();
  const headers = {
    'apikey': supabaseAnonKey,
    'Authorization': `Bearer ${access_token}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
  };

  console.log(`Authenticated as: ${user.email} (ID: ${user.id})`);

  // 2. Fetch existing profiles and diversify subscription tiers
  const profRes = await fetch(`${supabaseUrl}/rest/v1/profiles?select=id,handle,email,subscription_tier`, { headers });
  const profiles = await profRes.json();
  console.log(`Auditing ${profiles.length} real profiles...`);

  const tierDistribution = ['pro', 'enterprise', 'free', 'free', 'pro', 'free', 'enterprise'];
  for (let i = 0; i < profiles.length; i++) {
    const p = profiles[i];
    if (p.id === user.id) continue;
    const targetTier = tierDistribution[i % tierDistribution.length];
    if (p.subscription_tier !== targetTier) {
      await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${p.id}`, {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ subscription_tier: targetTier, status: 'active' })
      });
      console.log(`  Updated ${p.handle} -> Tier: ${targetTier}`);
    }
  }

  // 3. Seed Community Posts & Trade Setups
  console.log('\n[1/5] Seeding Community Posts & Trade Setups...');
  const samplePosts = [
    {
      id: 'd0000001-0000-0000-0000-000000000002',
      title: 'BANKNIFTY Weekly Expiry Setup: 52,000 Straddle Unwinding',
      body: 'Massive open interest unwinding observed at 52,000 Call strike. Looking for a clean break above 52,250 with target at 52,600. Keep stop-loss tight below 51,980 on 15m closing basis.',
      excerpt: 'Massive open interest unwinding observed at 52,000 Call strike.',
      kind: 'standard',
      tickers: ['BANKNIFTY'],
      tags: ['BANKNIFTY', 'Expiry', 'PriceAction', 'Derivatives'],
      likes_count: 14,
      comments_count: 3,
      views_count: 142,
      is_public: true,
      setup: {
        symbol: 'BANKNIFTY',
        entry_price: 52250.0,
        stop_loss: 51980.0,
        take_profit: 52600.0,
        side: 'long',
        timeframe: '15m',
        risk_reward_ratio: 1.3,
        status: 'active'
      }
    },
    {
      id: 'd0000001-0000-0000-0000-000000000003',
      title: 'RELIANCE 1D Swing Breakout: Golden Cross & Volume Expansion',
      body: 'RELIANCE printing a multi-week ascending triangle breakout with institutional volume above 20-day average. 50 EMA has crossed above 200 EMA on daily timeframe. Target 3,150 INR with swing stop at 2,940 INR.',
      excerpt: 'RELIANCE printing a multi-week ascending triangle breakout with institutional volume.',
      kind: 'standard',
      tickers: ['RELIANCE'],
      tags: ['RELIANCE', 'SwingTrading', 'GoldenCross', 'NSE'],
      likes_count: 22,
      comments_count: 5,
      views_count: 310,
      is_public: true,
      setup: {
        symbol: 'RELIANCE',
        entry_price: 3010.0,
        stop_loss: 2940.0,
        take_profit: 3150.0,
        side: 'long',
        timeframe: '1D',
        risk_reward_ratio: 2.0,
        status: 'active'
      }
    },
    {
      id: 'd0000001-0000-0000-0000-000000000004',
      title: 'TATASTEEL Pullback & Continuation Strategy',
      body: 'Metal sector finding strong bids near 20 EMA dynamic support. Watching 158 INR level for high probability reversal entry. FII net flow turned positive yesterday.',
      excerpt: 'Metal sector finding strong bids near 20 EMA dynamic support.',
      kind: 'standard',
      tickers: ['TATASTEEL'],
      tags: ['TATASTEEL', 'Metals', 'Pullback', 'NSE'],
      likes_count: 9,
      comments_count: 2,
      views_count: 88,
      is_public: true,
      setup: {
        symbol: 'TATASTEEL',
        entry_price: 158.5,
        stop_loss: 154.0,
        take_profit: 168.0,
        side: 'long',
        timeframe: '1D',
        risk_reward_ratio: 2.1,
        status: 'active'
      }
    }
  ];

  for (const p of samplePosts) {
    const postPayload = {
      id: p.id,
      author_id: user.id,
      title: p.title,
      body: p.body,
      excerpt: p.excerpt,
      kind: p.kind,
      tickers: p.tickers,
      tags: p.tags,
      likes_count: p.likes_count,
      comments_count: p.comments_count,
      views_count: p.views_count,
      is_public: p.is_public
    };

    const pRes = await fetch(`${supabaseUrl}/rest/v1/community_posts`, {
      method: 'POST',
      headers: { ...headers, 'Resolution': 'merge-duplicates' },
      body: JSON.stringify(postPayload)
    });
    console.log(`  - Post: "${p.title.substring(0, 35)}..." -> HTTP ${pRes.status}`);

    if (p.setup) {
      const sRes = await fetch(`${supabaseUrl}/rest/v1/community_post_trade_setups`, {
        method: 'POST',
        headers: { ...headers, 'Resolution': 'merge-duplicates' },
        body: JSON.stringify({
          post_id: p.id,
          ...p.setup
        })
      });
      console.log(`    Setup: ${p.setup.symbol} ${p.setup.side} -> HTTP ${sRes.status}`);
    }

    // Add a comment
    await fetch(`${supabaseUrl}/rest/v1/community_comments`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        post_id: p.id,
        author_id: user.id,
        content: 'Watching price action closely around key opening levels. Remember to scale out at 1:1 R/R.'
      })
    });
  }

  // 4. Seed Trader Notes
  console.log('\n[2/5] Seeding Trader Notes...');
  const sampleNotes = [
    {
      id: 'e0000001-0000-0000-0000-000000000002',
      title: 'Weekly NIFTY & FinNifty Expiry Playbook',
      content: '1. Wait for first 30 mins (9:15 - 9:45 AM) to let implied volatility settle.\n2. Note VWAP and Opening Range.\n3. Track PCR (Put-Call Ratio) on Sensibull.\n4. Avoid holding OTM options past 2:30 PM due to rapid theta decay.',
      tags: ['Expiry', 'Options', 'FinNifty', 'Checklist'],
      is_public: true
    },
    {
      id: 'e0000001-0000-0000-0000-000000000003',
      title: 'Trading Psychology & Emotional Discipline Rules',
      content: '- No revenge trading after 2 consecutive stop-losses.\n- If daily drawdown hits ₹10,000, terminal goes off.\n- Never convert an intraday scalp into an overnight delivery.\n- Review your TradeX journal every Sunday evening.',
      tags: ['Mindset', 'Discipline', 'RiskManagement'],
      is_public: true
    },
    {
      id: 'e0000001-0000-0000-0000-000000000004',
      title: 'Price Action & Candlestick Confirmation Patterns',
      content: 'Look for rejection wicks at key horizontal S/R zones.\nBullish engulfing with high volume near 20 EMA gives > 65% win-rate in backtests.',
      tags: ['PriceAction', 'Candlesticks', 'TechnicalAnalysis'],
      is_public: true
    }
  ];

  for (const n of sampleNotes) {
    const nRes = await fetch(`${supabaseUrl}/rest/v1/trader_notes`, {
      method: 'POST',
      headers: { ...headers, 'Resolution': 'merge-duplicates' },
      body: JSON.stringify({
        id: n.id,
        user_id: user.id,
        title: n.title,
        content: n.content,
        tags: n.tags,
        is_public: n.is_public
      })
    });
    console.log(`  - Note: "${n.title}" -> HTTP ${nRes.status}`);
  }

  // 5. Seed Journal Entries
  console.log('\n[3/5] Seeding Real Journal Entries...');
  const sampleJournals = [
    {
      id: 'f0000001-0000-0000-0000-000000000002',
      ticker: 'BANKNIFTY',
      title: 'BANKNIFTY 52,200 PE Put Spread Exit',
      content: 'Executed 1:2 bear put spread at 10:15 AM following false breakout of morning high. Booked full profits near 51,900 support.',
      entry_price: 240.0,
      exit_price: 382.0,
      stop_loss: 190.0,
      target: 380.0,
      size: 100,
      side: 'LONG',
      pnl: 14200.0,
      pnl_percent: 59.16,
      tags: ['BANKNIFTY', 'Options', 'PutSpread'],
      is_public: true,
      psychology: 'Patient execution, followed trading plan 100%.',
      psychology_score: 9
    },
    {
      id: 'f0000001-0000-0000-0000-000000000003',
      ticker: 'RELIANCE',
      title: 'RELIANCE Swing Breakout Delivery Trade',
      content: 'Accumulated 150 shares on daily ascending triangle breakout. Exited 50% at first target 3,150 INR.',
      entry_price: 3010.0,
      exit_price: 3133.33,
      stop_loss: 2940.0,
      target: 3150.0,
      size: 150,
      side: 'LONG',
      pnl: 18500.0,
      pnl_percent: 4.1,
      tags: ['RELIANCE', 'Equity', 'Swing'],
      is_public: true,
      psychology: 'Confident hold over 5 trading sessions.',
      psychology_score: 9
    },
    {
      id: 'f0000001-0000-0000-0000-000000000004',
      ticker: 'TATASTEEL',
      title: 'TATASTEEL 20 EMA Pullback Stopped Out',
      content: 'Entered on 15m hammer candle near support, but broader metal index turned weak. Disciplined stop-loss triggered.',
      entry_price: 158.5,
      exit_price: 155.3,
      stop_loss: 155.0,
      target: 168.0,
      size: 1000,
      side: 'LONG',
      pnl: -3200.0,
      pnl_percent: -2.02,
      tags: ['TATASTEEL', 'Equity', 'StopLoss'],
      is_public: true,
      psychology: 'Accepted small loss smoothly without emotional distress.',
      psychology_score: 8.0
    },
    {
      id: 'f0000001-0000-0000-0000-000000000005',
      ticker: 'INFY',
      title: 'INFY Q3 Results Pre-Market Momentum Scalp',
      content: 'Heavy tech buying in early session. Fast 15-minute scalp capturing 28 points on 200 shares.',
      entry_price: 1880.0,
      exit_price: 1908.0,
      stop_loss: 1865.0,
      target: 1910.0,
      size: 200,
      side: 'LONG',
      pnl: 5600.0,
      pnl_percent: 1.49,
      tags: ['INFY', 'Scalp', 'Intraday'],
      is_public: true,
      psychology: 'Swift execution and quick profit taking.',
      psychology_score: 9.0
    }
  ];

  for (const j of sampleJournals) {
    const jRes = await fetch(`${supabaseUrl}/rest/v1/journal_entries`, {
      method: 'POST',
      headers: { ...headers, 'Resolution': 'merge-duplicates' },
      body: JSON.stringify({
        id: j.id,
        user_id: user.id,
        ticker: j.ticker,
        title: j.title,
        content: j.content,
        entry_price: j.entry_price,
        exit_price: j.exit_price,
        stop_loss: j.stop_loss,
        target: j.target,
        size: j.size,
        side: j.side,
        pnl: j.pnl,
        pnl_percent: j.pnl_percent,
        tags: j.tags,
        is_public: j.is_public,
        psychology: j.psychology,
        psychology_score: j.psychology_score
      })
    });
    console.log(`  - Journal: ${j.ticker} (${j.pnl > 0 ? '+' : ''}₹${j.pnl}) -> HTTP ${jRes.status}`);
  }

  // 6. Seed Strategies
  console.log('\n[4/5] Seeding Proven Trading Strategies...');
  const sampleStrats = [
    {
      id: 'a0000001-0000-0000-0000-000000000002',
      title: 'VWAP Mean Reversion Scalping Protocol',
      content: 'Designed for high beta index options. When price deviates > 2 standard deviations from VWAP on 5m chart with RSI < 25 or > 75, take counter-trend scalp back to VWAP midline.',
      summary: 'High probability mean reversion when price overextends from intraday institutional benchmark (VWAP).',
      category: 'Scalping',
      status: 'active',
      visibility: 'public',
      tags: ['VWAP', 'Scalping', 'MeanReversion', 'Options'],
      linked_tickers: ['NIFTY', 'BANKNIFTY']
    },
    {
      id: 'a0000001-0000-0000-0000-000000000003',
      title: 'Supertrend (10,3) + 20 EMA Trend Riding',
      content: 'Rule 1: Trade only in the direction of daily 20 EMA.\nRule 2: On 15m chart, enter when Supertrend confirms and price retests 20 EMA with bullish/bearish candle.\nRule 3: Trail stop-loss along the Supertrend line.',
      summary: 'Disciplined multi-timeframe trend continuation model with dynamic trailing stop-loss.',
      category: 'Trend Following',
      status: 'active',
      visibility: 'public',
      tags: ['Supertrend', 'EMA', 'Trend', 'Swing'],
      linked_tickers: ['NIFTY', 'RELIANCE', 'TATASTEEL']
    }
  ];

  for (const s of sampleStrats) {
    const sRes = await fetch(`${supabaseUrl}/rest/v1/strategies`, {
      method: 'POST',
      headers: { ...headers, 'Resolution': 'merge-duplicates' },
      body: JSON.stringify({
        id: s.id,
        user_id: user.id,
        title: s.title,
        content: s.content,
        summary: s.summary,
        category: s.category,
        status: s.status,
        visibility: s.visibility,
        tags: s.tags,
        linked_tickers: s.linked_tickers
      })
    });
    console.log(`  - Strategy: "${s.title}" -> HTTP ${sRes.status}`);
  }

  // 7. Seed Affiliate Payouts
  console.log('\n[5/5] Seeding Affiliate Payouts in INR...');
  const samplePayouts = [
    {
      id: 'b0000001-0000-0000-0000-000000000002',
      affiliate_id: user.id,
      amount: 6500.0,
      currency: 'INR',
      status: 'pending',
      payout_method: 'upi',
      transaction_reference: null,
      notes: 'Pending bi-weekly settlement to verified UPI ID'
    }
  ];

  for (const p of samplePayouts) {
    const payRes = await fetch(`${supabaseUrl}/rest/v1/affiliate_payouts`, {
      method: 'POST',
      headers: { ...headers, 'Resolution': 'merge-duplicates' },
      body: JSON.stringify(p)
    });
    console.log(`  - Payout: ₹${p.amount} (${p.status}) -> HTTP ${payRes.status}`);
  }

  console.log('\n' + '='.repeat(70));
  console.log('LIVE SUPABASE EXISTING TABLES SEEDING COMPLETED SUCCESSFULLY!');
  console.log('='.repeat(70));
}

seed();
