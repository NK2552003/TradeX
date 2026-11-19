-- Keep the published subscription catalogue aligned with enforced frontend and
-- RLS entitlements for Market Intelligence, Messages, and calculators.

BEGIN;

UPDATE public.pricing_catalogues catalogue_row
SET catalogue = catalogue_row.catalogue || jsonb_build_object(
  'plans', (
    SELECT jsonb_agg(
      CASE plan->>'tier'
        WHEN 'free' THEN plan || jsonb_build_object(
          'subtitle', 'Community access, core calculators, and limited ticker, news, and instrument previews',
          'tagline', 'Community access, core calculators, and limited ticker, news, and instrument previews',
          'features_summary', jsonb_build_array(
            'Up to 3 research notes and 15 logged trades',
            'Community feed and public post view access',
            'Core calculators',
            'Limited Community ticker, news and instrument previews',
            'No private Messages or full Market Intelligence'
          ),
          'features', jsonb_build_array(
            'Up to 3 research notes and 15 logged trades',
            'Community feed and public post view access',
            'Core calculators',
            'Limited Community ticker, news and instrument previews',
            'No private Messages or full Market Intelligence'
          )
        )
        WHEN 'premium' THEN plan || jsonb_build_object(
          'subtitle', 'Full Market Intelligence, private Messages, advanced calculators, and expanded workspace limits',
          'tagline', 'Full Market Intelligence, private Messages, advanced calculators, and expanded workspace limits',
          'features_summary', jsonb_build_array(
            'Up to 25 research notes and 100 logged trades',
            'Full Market Intelligence and instrument research',
            'Private Messages',
            'All advanced calculators',
            'Up to 20 AI prompts per month'
          ),
          'features', jsonb_build_array(
            'Up to 25 research notes and 100 logged trades',
            'Full Market Intelligence and instrument research',
            'Private Messages',
            'All advanced calculators',
            'Up to 20 AI prompts per month'
          )
        )
        WHEN 'enterprise' THEN plan || jsonb_build_object(
          'subtitle', 'Everything in Basic plus exports, advanced analytics, backtesting, and higher quotas',
          'tagline', 'Everything in Basic plus exports, advanced analytics, backtesting, and higher quotas',
          'features_summary', jsonb_build_array(
            'Everything in Basic, including Markets, Messages and calculators',
            'Up to 10,000 notes and 50,000 logged trades',
            'PDF and CSV exports',
            'Advanced backtesting and analytics',
            'Higher AI, watchlist, alert, and Community quotas'
          ),
          'features', jsonb_build_array(
            'Everything in Basic, including Markets, Messages and calculators',
            'Up to 10,000 notes and 50,000 logged trades',
            'PDF and CSV exports',
            'Advanced backtesting and analytics',
            'Higher AI, watchlist, alert, and Community quotas'
          )
        )
        ELSE plan
      END
      ORDER BY plan_ordinality
    )
    FROM jsonb_array_elements(catalogue_row.catalogue->'plans')
      WITH ORDINALITY AS plans(plan, plan_ordinality)
  ),
  'categories', (
    SELECT COALESCE(jsonb_agg(category ORDER BY category_ordinality), '[]'::jsonb)
      || jsonb_build_array(jsonb_build_object(
        'id', 'subscription_access',
        'name', 'Market, Messages & Calculators',
        'rows', jsonb_build_array(
          jsonb_build_object(
            'id', 'market_intelligence',
            'title', 'Market Intelligence',
            'tooltip', 'Free receives only bounded Community previews; the complete workspace requires Basic or Pro.',
            'free_value', 'Limited Community previews',
            'pro_value', 'Full access',
            'enterprise_value', 'Full access',
            'is_boolean', false
          ),
          jsonb_build_object(
            'id', 'private_messages',
            'title', 'Private Messages',
            'tooltip', 'Messages and realtime subscriptions are not initialized for Free accounts.',
            'free_value', 'Not included',
            'pro_value', 'Included',
            'enterprise_value', 'Included',
            'is_boolean', false
          ),
          jsonb_build_object(
            'id', 'calculators',
            'title', 'Calculators',
            'tooltip', 'Free includes core calculators; Basic and Pro include advanced trading, options, forex, and tax tools.',
            'free_value', 'Core tools',
            'pro_value', 'All tools',
            'enterprise_value', 'All tools',
            'is_boolean', false
          )
        )
      ))
    FROM jsonb_array_elements(COALESCE(catalogue_row.catalogue->'categories', '[]'::jsonb))
      WITH ORDINALITY AS categories(category, category_ordinality)
    WHERE category->>'id' <> 'subscription_access'
  ),
  'footer_disclaimer',
    'Free includes Community access, core calculators, and bounded market previews. Full Market Intelligence and Messages require Basic or Pro.',
  'copy', COALESCE(catalogue_row.catalogue->'copy', '{}'::jsonb) || jsonb_build_object(
    'description', 'Free includes limited Community market previews. Basic unlocks Market Intelligence, Messages, and advanced calculators; Pro adds exports, analytics, and higher quotas.'
  )
),
updated_at = now()
WHERE id = 'default';

COMMIT;
