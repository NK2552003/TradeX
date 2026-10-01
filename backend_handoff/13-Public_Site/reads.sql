-- Anonymous visitors see only published content; RLS is the enforcement layer.
SELECT content FROM public_site_pages WHERE id = 'landing' AND published;
SELECT catalogue FROM pricing_catalogues WHERE id = 'default' AND published;
-- Complete instrument snapshots retain all finance-kit fields.
SELECT detail FROM stock_details WHERE ticker = :ticker;
