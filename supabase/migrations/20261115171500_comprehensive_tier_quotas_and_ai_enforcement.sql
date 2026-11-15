-- Comprehensive Tier Quotas & Server-Side Enforcement across Free / Basic / Pro
-- 1. Updates public.pricing_catalogues with complete limits (notes, trades, live_playbooks,
--    watchlists, alerts, community_posts_per_day, community_comments_per_day,
--    ai_queries_per_month, allow_pdf_export, allow_advanced_backtest) and comparison rows.
-- 2. Updates public.get_customer_quota_usage to report live counts for watchlists, alerts,
--    community posts today, community comments today, and ai_queries_today alongside notes,
--    trades, live playbooks, and monthly AI queries.
-- 3. Updates public.enforce_published_customer_quota and ensures BEFORE INSERT/UPDATE
--    triggers enforce limits on notes, journal entries, live playbooks, AI requests,
--    watchlists, price alerts, community posts, and comments.

INSERT INTO public.pricing_catalogues (id, catalogue, published, updated_at)
VALUES (
  'default',
  '{
    "plans": [
      {
        "id": "tier_free",
        "tier": "free",
        "name": "Free",
        "subtitle": "Starter workspace with 3 notes, 15 trades, 1 playbook, 2 posts/day & 5 AI prompts/mo",
        "monthly_amount": 0.0,
        "annual_monthly_amount": 0.0,
        "currency_symbol": "₹",
        "features_summary": [
          "Up to 3 research notes",
          "Up to 15 logged trades (total)",
          "1 active playbook · 1 watchlist · 3 price alerts",
          "Up to 2 community posts/day & 10 comments/day",
          "Up to 5 AI prompts per month",
          "Core calculators & market view"
        ],
        "badge_label": "AVAILABLE NOW",
        "highlighted": false,
        "is_current": false,
        "cta_label": "Continue with Free",
        "limits": {
          "notes": 3,
          "trades": 15,
          "live_playbooks": 1,
          "watchlists": 1,
          "alerts": 3,
          "community_posts_per_day": 2,
          "community_comments_per_day": 10,
          "ai_queries_per_month": 5,
          "allow_pdf_export": false,
          "allow_advanced_backtest": false
        },
        "is_purchasable": true
      },
      {
        "id": "tier_pro",
        "tier": "premium",
        "name": "Basic",
        "subtitle": "Expanded trading workspace; monthly subscriptions are disabled for now",
        "monthly_amount": 299.0,
        "annual_monthly_amount": 239.0,
        "currency_symbol": "₹",
        "features_summary": [
          "Up to 25 research notes",
          "Up to 100 logged trades (total)",
          "3 active playbooks · 5 watchlists · 25 price alerts",
          "Up to 15 community posts/day & 50 comments/day",
          "Up to 20 AI prompts per month",
          "Monthly subscriptions disabled for now"
        ],
        "badge_label": "MONTHLY SUBSCRIPTIONS DISABLED",
        "highlighted": true,
        "is_current": false,
        "cta_label": "Monthly subscriptions disabled",
        "limits": {
          "notes": 25,
          "trades": 100,
          "live_playbooks": 3,
          "watchlists": 5,
          "alerts": 25,
          "community_posts_per_day": 15,
          "community_comments_per_day": 50,
          "ai_queries_per_month": 20,
          "allow_pdf_export": false,
          "allow_advanced_backtest": false
        },
        "is_purchasable": false
      },
      {
        "id": "tier_enterprise",
        "tier": "enterprise",
        "name": "Pro",
        "subtitle": "High-capacity professional workspace; monthly subscriptions are disabled for now",
        "monthly_amount": 499.0,
        "annual_monthly_amount": 399.0,
        "currency_symbol": "₹",
        "features_summary": [
          "Up to 10,000 research notes",
          "Up to 50,000 logged trades (total)",
          "250 active playbooks · 100 watchlists · 500 alerts",
          "Up to 100 community posts/day & 500 comments/day",
          "Up to 5,000 AI prompts per month",
          "PDF & CSV exports + advanced analytics"
        ],
        "badge_label": "MONTHLY SUBSCRIPTIONS DISABLED",
        "highlighted": false,
        "is_current": false,
        "cta_label": "Monthly subscriptions disabled",
        "limits": {
          "notes": 10000,
          "trades": 50000,
          "live_playbooks": 250,
          "watchlists": 100,
          "alerts": 500,
          "community_posts_per_day": 100,
          "community_comments_per_day": 500,
          "ai_queries_per_month": 5000,
          "allow_pdf_export": true,
          "allow_advanced_backtest": true
        },
        "is_purchasable": false
      }
    ],
    "categories": [
      {
        "id": "cat_limits",
        "name": "Enforced workspace & AI quotas",
        "rows": [
          {"id": "feat_notes", "title": "Research notes", "tooltip": "Maximum saved research notes. Checked on creation.", "free_value": "3 total", "pro_value": "25 total", "enterprise_value": "10,000 total", "is_boolean": false},
          {"id": "feat_trades", "title": "Logged trades", "tooltip": "Maximum saved journal trades. Checked on creation.", "free_value": "15 total", "pro_value": "100 total", "enterprise_value": "50,000 total", "is_boolean": false},
          {"id": "feat_playbooks", "title": "Active playbooks", "tooltip": "Maximum active strategy playbooks. Checked on creation/activation.", "free_value": "1 active", "pro_value": "3 active", "enterprise_value": "250 active", "is_boolean": false},
          {"id": "feat_ai", "title": "AI Copilot & refactor prompts", "tooltip": "Hard monthly server-side quota across AI chat, voice assistant, and note refactor.", "free_value": "5 / month", "pro_value": "20 / month", "enterprise_value": "5,000 / month", "is_boolean": false},
          {"id": "feat_watchlists", "title": "Custom watchlists", "tooltip": "Maximum watchlists per account.", "free_value": "1 watchlist", "pro_value": "5 watchlists", "enterprise_value": "100 watchlists", "is_boolean": false},
          {"id": "feat_alerts", "title": "Armed price alerts", "tooltip": "Maximum active ticker price alerts.", "free_value": "3 alerts", "pro_value": "25 alerts", "enterprise_value": "500 alerts", "is_boolean": false}
        ]
      },
      {
        "id": "cat_community_exports",
        "name": "Community & exports",
        "rows": [
          {"id": "feat_community_posts", "title": "Community posts", "tooltip": "Daily community post publishing cap enforced on client & database.", "free_value": "2 / day", "pro_value": "15 / day", "enterprise_value": "100 / day", "is_boolean": false},
          {"id": "feat_community_comments", "title": "Community comments & replies", "tooltip": "Daily comment & reply limit across feed and linked records.", "free_value": "10 / day", "pro_value": "50 / day", "enterprise_value": "500 / day", "is_boolean": false},
          {"id": "feat_pdf_export", "title": "PDF & CSV report exports", "tooltip": "Export trade entries, research notes, and strategy playbooks as PDFs or reports.", "free_value": false, "pro_value": false, "enterprise_value": true, "is_boolean": true},
          {"id": "feat_backtest", "title": "Advanced analytics & backtest", "tooltip": "Institutional playbook backtesting & multi-factor analytics.", "free_value": false, "pro_value": false, "enterprise_value": true, "is_boolean": true}
        ]
      },
      {
        "id": "cat_access",
        "name": "Current availability",
        "rows": [
          {"id": "feat_charts", "title": "Charts and market browsing", "tooltip": "Available data depends on the configured provider and its coverage; real-time depth is not guaranteed.", "free_value": "View access", "pro_value": "Full access", "enterprise_value": "Full access", "is_boolean": false},
          {"id": "feat_checkout", "title": "Monthly subscriptions", "tooltip": "Monthly subscriptions for Basic and Pro are temporarily disabled.", "free_value": "Not needed", "pro_value": "Disabled for now", "enterprise_value": "Disabled for now", "is_boolean": false}
        ]
      }
    ],
    "faqs": [
      {"id": "faq_billing", "category": "billing", "question": "Can I subscribe to Basic or Pro monthly right now?", "answer": "Monthly subscriptions for Basic and Pro are disabled for now. You can use the Free plan (up to 3 notes, 15 trades, 1 playbook, 1 watchlist, 2 daily posts, and 5 monthly AI prompts) immediately."},
      {"id": "faq_limits", "category": "features", "question": "Which limits are checked today?", "answer": "All plans enforce saved notes (3/25/10,000), logged trades (15/100/50,000), live playbooks (1/3/250), watchlists (1/5/100), price alerts (3/25/500), daily community posts (2/15/100) and comments (10/50/500), PDF/CSV exports (Pro), and hard monthly AI quotas (5/20/5,000) across text, voice, and note refactor."},
      {"id": "faq_data", "category": "features", "question": "Is market data real-time?", "answer": "Coverage and delay depend on the connected data provider. alphajournal does not currently promise tick-by-tick depth or exchange-grade low latency."},
      {"id": "faq_tax", "category": "billing", "question": "Are paid prices final, including taxes?", "answer": "Basic (₹299/mo) and Pro (₹499/mo) prices are preview rates while monthly subscriptions remain disabled."}
    ],
    "annual_discount_percent": 20,
    "annual_months_billed": 12,
    "footer_disclaimer": "Free includes up to 3 notes, 15 trades, 1 watchlist, 2 daily posts, and 5 AI prompts/month. Monthly subscriptions for Basic and Pro are disabled for now.",
    "copy": {
      "badge": "Plans for every workspace",
      "title": "Choose Your Trading Plan",
      "description": "Compare Free, Basic, and Pro workspace quotas. Monthly subscriptions for Basic and Pro are disabled for now.",
      "monthly": "Monthly",
      "annual": "Billed annually",
      "current": "Current Plan",
      "processing": "Processing…",
      "matrix": "Compare Features Across Plans",
      "faq": "Frequently Asked Questions",
      "all": "All Questions",
      "retry": "Try again",
      "back": "Back",
      "error": "Unable to load pricing",
      "billing_suffix": "/month",
      "annual_savings": "Monthly subscriptions are currently disabled for Basic and Pro",
      "feature": "Feature"
    }
  }'::jsonb,
  true,
  now()
)
ON CONFLICT (id) DO UPDATE
SET catalogue = EXCLUDED.catalogue,
    published = true,
    updated_at = now();

CREATE OR REPLACE FUNCTION public.get_customer_quota_usage(target_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := auth.uid();
  effective_user_id uuid := COALESCE(target_user_id, auth.uid());
  effective_tier text := 'free';
  published_limits jsonb;
  admin_overrides jsonb := '{}'::jsonb;
  note_count integer := 0;
  trade_count integer := 0;
  playbook_count integer := 0;
  ai_month_count integer := 0;
  ai_day_count integer := 0;
  watchlist_count integer := 0;
  alert_count integer := 0;
  posts_today_count integer := 0;
  comments_today_count integer := 0;
  unified_comments_today integer := 0;
BEGIN
  IF actor_id IS NULL OR effective_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF effective_user_id <> actor_id AND NOT public.is_user_admin() THEN
    RAISE EXCEPTION 'Quota access denied' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = effective_user_id) THEN
    RAISE EXCEPTION 'Account not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT s.tier INTO effective_tier
  FROM public.subscriptions s
  WHERE s.user_id = effective_user_id
    AND s.status IN ('active', 'trialing', 'canceled')
    AND (s.expires_at IS NULL OR s.expires_at > now())
  LIMIT 1;

  IF effective_tier IS NULL THEN
    SELECT p.subscription_tier, COALESCE(p.admin_controls->'limits', '{}'::jsonb)
    INTO effective_tier, admin_overrides
    FROM public.profiles p
    WHERE p.id = effective_user_id;
  ELSE
    SELECT COALESCE(p.admin_controls->'limits', '{}'::jsonb)
    INTO admin_overrides
    FROM public.profiles p
    WHERE p.id = effective_user_id;
  END IF;

  effective_tier := COALESCE(effective_tier, 'free');
  IF effective_tier = 'basic' THEN
    effective_tier := 'premium';
  ELSIF effective_tier = 'pro' THEN
    effective_tier := 'enterprise';
  END IF;

  SELECT plan->'limits' INTO published_limits
  FROM public.pricing_catalogues c,
       jsonb_array_elements(c.catalogue->'plans') plan
  WHERE c.id = 'default'
    AND c.published
    AND plan->>'tier' = effective_tier
  LIMIT 1;

  IF published_limits IS NULL THEN
    SELECT plan->'limits' INTO published_limits
    FROM public.pricing_catalogues c,
         jsonb_array_elements(c.catalogue->'plans') plan
    WHERE c.id = 'default'
      AND c.published
      AND plan->>'tier' = 'free'
    LIMIT 1;
  END IF;

  published_limits := COALESCE(published_limits, '{}'::jsonb);
  IF admin_overrides ? 'posts_per_day' AND NOT (admin_overrides ? 'community_posts_per_day') THEN
    admin_overrides := admin_overrides || jsonb_build_object('community_posts_per_day', admin_overrides->'posts_per_day');
  END IF;
  published_limits := published_limits || (COALESCE(admin_overrides, '{}'::jsonb) - 'ai_queries_per_day');

  SELECT count(*) INTO note_count
  FROM public.trader_notes
  WHERE user_id = effective_user_id;

  SELECT count(*) INTO trade_count
  FROM public.journal_entries
  WHERE user_id = effective_user_id;

  SELECT count(*) INTO playbook_count
  FROM public.strategies
  WHERE user_id = effective_user_id
    AND status = 'live';

  SELECT count(*) INTO ai_month_count
  FROM public.ai_insight_requests
  WHERE user_id = effective_user_id
    AND requested_at >= date_trunc('month', now())
    AND requested_at < date_trunc('month', now()) + interval '1 month';

  SELECT count(*) INTO ai_day_count
  FROM public.ai_insight_requests
  WHERE user_id = effective_user_id
    AND requested_at >= date_trunc('day', now())
    AND requested_at < date_trunc('day', now()) + interval '1 day';

  IF to_regclass('public.watchlists') IS NOT NULL THEN
    SELECT count(*) INTO watchlist_count
    FROM public.watchlists
    WHERE user_id = effective_user_id;
  END IF;

  IF to_regclass('public.watchlist_items') IS NOT NULL AND to_regclass('public.watchlists') IS NOT NULL THEN
    SELECT count(*) INTO alert_count
    FROM public.watchlist_items wi
    JOIN public.watchlists w ON w.id = wi.watchlist_id
    WHERE w.user_id = effective_user_id
      AND COALESCE(wi.alert_armed, false) = true;
  END IF;

  IF to_regclass('public.community_posts') IS NOT NULL THEN
    SELECT count(*) INTO posts_today_count
    FROM public.community_posts
    WHERE author_id = effective_user_id
      AND created_at >= date_trunc('day', now())
      AND created_at < date_trunc('day', now()) + interval '1 day';
  END IF;

  IF to_regclass('public.community_comments') IS NOT NULL THEN
    SELECT count(*) INTO comments_today_count
    FROM public.community_comments
    WHERE author_id = effective_user_id
      AND created_at >= date_trunc('day', now())
      AND created_at < date_trunc('day', now()) + interval '1 day';
  END IF;

  IF to_regclass('public.unified_comments') IS NOT NULL THEN
    SELECT count(*) INTO unified_comments_today
    FROM public.unified_comments
    WHERE author_id = effective_user_id
      AND created_at >= date_trunc('day', now())
      AND created_at < date_trunc('day', now()) + interval '1 day';
    comments_today_count := comments_today_count + unified_comments_today;
  END IF;

  RETURN jsonb_build_object(
    'user_id', effective_user_id,
    'tier', effective_tier,
    'limits', published_limits,
    'notes_used', note_count,
    'trades_used', trade_count,
    'live_playbooks_used', playbook_count,
    'ai_queries_used', ai_month_count,
    'ai_queries_today', ai_day_count,
    'watchlists_used', watchlist_count,
    'alerts_used', alert_count,
    'community_posts_today', posts_today_count,
    'community_comments_today', comments_today_count,
    'window_started_at', date_trunc('month', now()),
    'day_started_at', date_trunc('day', now())
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_quota_usage(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_quota_usage(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.enforce_published_customer_quota()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  owner_id uuid;
  usage jsonb;
  k text;
  used_key text;
  maximum integer;
  used integer;
  daily_max integer;
BEGIN
  IF auth.uid() IS NULL OR tradex_private.is_admin() THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'strategies' THEN
    IF NEW.status <> 'live' OR (TG_OP = 'UPDATE' AND OLD.status = 'live') THEN
      RETURN NEW;
    END IF;
    owner_id := NEW.user_id;
    k := 'live_playbooks';
    used_key := 'live_playbooks_used';
  ELSIF TG_TABLE_NAME = 'trader_notes' THEN
    owner_id := NEW.user_id;
    k := 'notes';
    used_key := 'notes_used';
  ELSIF TG_TABLE_NAME = 'journal_entries' THEN
    owner_id := NEW.user_id;
    k := 'trades';
    used_key := 'trades_used';
  ELSIF TG_TABLE_NAME = 'watchlists' THEN
    owner_id := NEW.user_id;
    k := 'watchlists';
    used_key := 'watchlists_used';
  ELSIF TG_TABLE_NAME = 'watchlist_items' THEN
    IF COALESCE(NEW.alert_armed, false) = false
       OR (TG_OP = 'UPDATE' AND COALESCE(OLD.alert_armed, false) = true) THEN
      RETURN NEW;
    END IF;
    SELECT w.user_id INTO owner_id
    FROM public.watchlists w
    WHERE w.id = NEW.watchlist_id;
    IF owner_id IS NULL THEN
      RETURN NEW;
    END IF;
    k := 'alerts';
    used_key := 'alerts_used';
  ELSIF TG_TABLE_NAME = 'community_posts' THEN
    owner_id := NEW.author_id;
    k := 'community_posts_per_day';
    used_key := 'community_posts_today';
  ELSIF TG_TABLE_NAME IN ('community_comments', 'unified_comments') THEN
    owner_id := NEW.author_id;
    k := 'community_comments_per_day';
    used_key := 'community_comments_today';
  ELSE
    owner_id := NEW.user_id;
    k := 'ai_queries_per_month';
    used_key := 'ai_queries_used';
  END IF;

  IF owner_id IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(owner_id::text), hashtext(k));
  usage := public.get_customer_quota_usage(owner_id);
  maximum := (usage->'limits'->>k)::integer;
  used := COALESCE((usage->>used_key)::integer, 0);

  IF maximum IS NULL OR used >= maximum THEN
    RAISE EXCEPTION 'Account % limit reached (% of %)', k, used, maximum
      USING ERRCODE = 'P0001';
  END IF;

  IF TG_TABLE_NAME = 'ai_insight_requests' THEN
    SELECT q.daily_limit INTO daily_max
    FROM public.ai_quotas q
    WHERE q.user_id = owner_id;
    IF daily_max IS NOT NULL AND COALESCE((usage->>'ai_queries_today')::integer, 0) >= daily_max THEN
      RAISE EXCEPTION 'Daily AI request limit reached' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.trader_notes') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.trader_notes;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT ON public.trader_notes
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;

  IF to_regclass('public.journal_entries') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.journal_entries;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT ON public.journal_entries
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;

  IF to_regclass('public.strategies') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.strategies;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT OR UPDATE OF status ON public.strategies
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;

  IF to_regclass('public.ai_insight_requests') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.ai_insight_requests;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT ON public.ai_insight_requests
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;

  IF to_regclass('public.watchlists') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.watchlists;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT ON public.watchlists
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;

  IF to_regclass('public.watchlist_items') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.watchlist_items;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT OR UPDATE OF alert_armed ON public.watchlist_items
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;

  IF to_regclass('public.community_posts') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.community_posts;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT ON public.community_posts
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;

  IF to_regclass('public.community_comments') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.community_comments;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT ON public.community_comments
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;

  IF to_regclass('public.unified_comments') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_published_customer_quota ON public.unified_comments;
    CREATE TRIGGER trg_enforce_published_customer_quota
      BEFORE INSERT ON public.unified_comments
      FOR EACH ROW EXECUTE FUNCTION public.enforce_published_customer_quota();
  END IF;
END $$;
