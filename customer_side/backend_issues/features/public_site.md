# Backend Feature Audit: Public Site & Pricing Catalogues

**Component:** `lib/features/public_site/`  
**Database Tables:** `public.pricing_catalogues`  
**Files Evaluated:**  
- `lib/features/public_site/data/public_site_repository.dart`  

---

## 1. Silent Pricing Desync

- **Silent Asset Fallback (`public_site_repository.dart:40-60`):**
  - Any PostgREST timeout or schema error silently falls back to `assets/data/pricing_catalogue.json`.
  - Hides updated subscription prices and seasonal discounts configured by marketing/finance.
  - **Action:** Add proper error monitoring (Sentry) and a lightweight Redis edge cache for pricing data.
