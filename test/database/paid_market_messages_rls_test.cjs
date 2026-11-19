const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {resolve} = require('node:path');

const sql = readFileSync(
  resolve(
    __dirname,
    '../../supabase/migrations/20261119010000_paid_market_messages_and_community_preview.sql',
  ),
  'utf8',
);

test('full market and messages require a paid effective tier', () => {
  assert.match(sql, /effective_tier\(p_user\) IN \('premium', 'enterprise'\)/);
  assert.match(sql, /CREATE POLICY paid_market_read/);
  assert.match(sql, /REVOKE SELECT ON[\s\S]+FROM anon;/);
  assert.match(sql, /tradex_private\.has_paid_tier\(\(SELECT auth\.uid\(\)\)\)/);
  assert.match(sql, /CREATE POLICY messages_read[\s\S]+chat_member/);
});

test('community preview is authenticated, bounded, and does not expose fundamentals', () => {
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.community_market_preview\(\)/);
  assert.match(sql, /caller IS NULL OR NOT tradex_private\.account_active\(caller\)/);
  assert.match(sql, /LIMIT 8/);
  assert.match(sql, /LIMIT 6/);
  const preview = sql.slice(
    sql.indexOf('CREATE OR REPLACE FUNCTION public.community_market_preview()'),
    sql.indexOf('CREATE OR REPLACE FUNCTION public.market_overview_payload()'),
  );
  assert.doesNotMatch(preview, /stock_fundamentals|stock_details|options_contracts/);
  assert.match(sql, /REVOKE ALL ON FUNCTION public\.community_market_preview\(\) FROM PUBLIC, anon/);
});

test('paid overview uses one aggregated RPC payload', () => {
  assert.match(sql, /CREATE OR REPLACE FUNCTION public\.market_overview_payload\(\)/);
  assert.match(sql, /'quotes'[\s\S]+'screeners'[\s\S]+'news'[\s\S]+'manifest'/);
  assert.match(sql, /AlphaJournal Basic or Pro is required/);
});
