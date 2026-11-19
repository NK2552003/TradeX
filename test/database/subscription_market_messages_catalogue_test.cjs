const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {resolve} = require('node:path');

const sql = readFileSync(
  resolve(
    __dirname,
    '../../supabase/migrations/20261119020000_subscription_market_messages_catalogue.sql',
  ),
  'utf8',
);

test('published catalogue describes enforced access on every plan', () => {
  assert.match(sql, /WHEN 'free'[\s\S]+Limited Community ticker, news and instrument previews/);
  assert.match(sql, /WHEN 'premium'[\s\S]+Full Market Intelligence[\s\S]+Private Messages[\s\S]+All advanced calculators/);
  assert.match(sql, /WHEN 'enterprise'[\s\S]+Everything in Basic[\s\S]+Advanced backtesting and analytics/);
  assert.match(sql, /'id', 'subscription_access'/);
});
