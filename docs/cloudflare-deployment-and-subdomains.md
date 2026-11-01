# Cloudflare Deployment, Domain Registrar & Subdomain Setup Guide

This guide walks through deploying **alphajournal** to **Cloudflare Pages** from the `feature/admin` (or `main`) branch and configuring the root domain (`alphajournal.in` / `alphagournal.in`) and all dedicated subdomains:

- `https://alphajournal.in` (Public Marketing & Landing Site)
- `https://app.alphajournal.in` (Trader Workspace Entrypoint)
- `https://community.alphajournal.in` (Public & Verified Trader Community Feed)
- `https://admin.alphajournal.in` (Admin Console Entrypoint)
- `https://affiliate.alphajournal.in` (Partner & Affiliate Portal)

> **Built-in Subdomain Routing**: [`CustomerRoute.parse`](../lib/core/navigation/customer_routes.dart) automatically inspects `uri.host` when visiting `/` on any subdomain (`app.*`, `community.*`, `admin.*`, `affiliate.*`) for both `alphajournal.in` and `alphagournal.in`, routing directly to the matching module from a single unified web build.

---

## Step 1: Connect Domain Registrar to Cloudflare

1. Log in to your **Cloudflare Dashboard** (`https://dash.cloudflare.com`) and click **Add a Domain**.
2. Enter your domain (`alphajournal.in` — and optionally `alphagournal.in` if registered as a typo-redirect alias) and select the **Free** (or Pro) plan.
3. Cloudflare will assign two nameservers (for example: `lara.ns.cloudflare.com` and `rick.ns.cloudflare.com`).
4. Log in to your **Domain Registrar** (GoDaddy, Namecheap, Hostinger, BigRock, Porkbun, or Nixi `.in` registry):
   - Open **DNS Management / Nameservers** for `alphajournal.in`.
   - Change Nameservers from **Default** to **Custom Nameservers**.
   - Replace existing nameservers with the 2 Cloudflare nameservers and save.
   - Disable DNSSEC at the registrar temporarily while switching nameservers, then enable DNSSEC inside Cloudflare (`DNS -> Settings -> Enable DNSSEC`) once the zone is **Active**.

---

## Step 2: Deploy to Cloudflare Pages

### Option A: Direct CLI Upload (Fastest & Most Reliable for Flutter Web)

Because Cloudflare Pages' default build image does not pre-install the Flutter SDK, building locally (or in GitHub Actions) and deploying via `wrangler` is the fastest production workflow:

```bash
# 1. Sync client environment variables into assets/config/client.env
python3 scripts/prepare_client_config.py

# 2. Build the production Flutter Web bundle
flutter build web --release

# 3. Deploy build/web to Cloudflare Pages (creates project if first run)
npx wrangler pages deploy build/web --project-name=alphajournal --branch=feature/admin
```

### Option B: Automatic Git Deployment on Cloudflare Pages

If you connect your GitHub repository directly in **Cloudflare Dashboard -> Compute (Workers & Pages) -> Create -> Pages -> Connect to Git**:

- **Repository**: `nk2552003/TradeX`
- **Production branch**: `feature/admin` (or `main`)
- **Build command**:
  ```bash
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter && export PATH="$PATH:$HOME/flutter/bin" && python3 scripts/prepare_client_config.py && flutter pub get && flutter build web --release
  ```
- **Build output directory**: `build/web`
- **Environment variables** (under *Settings -> Environment Variables*):
  - `SUPABASE_URL`: `https://ylxwgkhtwrizdmuhlhxs.supabase.co`
  - `SUPABASE_ANON_KEY`: *(your anon key from `.env`)*
  - `SUPABASE_PUBLISHABLE_KEY`: *(your publishable key from `.env`)*
  - `APP_ENV`: `production`

---

## Step 3: Attach Custom Domains & Subdomains in Cloudflare Pages

A single Cloudflare Pages project (`alphajournal.pages.dev`) serves the root domain and all subdomains seamlessly.

1. In Cloudflare Dashboard, open **Workers & Pages -> alphajournal -> Custom domains**.
2. Click **Set up a custom domain** and add each of the following one by one:
   - `alphajournal.in`
   - `www.alphajournal.in`
   - `app.alphajournal.in`
   - `community.alphajournal.in`
   - `admin.alphajournal.in`
   - `affiliate.alphajournal.in`
3. Cloudflare will automatically create the corresponding proxied DNS records in your zone. Verify under **DNS -> Records** that the following records exist with **Proxy status = Proxied (Orange Cloud)**:

| Type | Name | Target / Content | Proxy Status | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `CNAME` | `@` (`alphajournal.in`) | `alphajournal.pages.dev` | Proxied | Public Marketing & Landing Site |
| `CNAME` | `www` | `alphajournal.pages.dev` | Proxied | Redirects or serves root site |
| `CNAME` | `app` | `alphajournal.pages.dev` | Proxied | Trader Workspace (`destination: workspace`) |
| `CNAME` | `community` | `alphajournal.pages.dev` | Proxied | Community Feed (`destination: community_feed`) |
| `CNAME` | `admin` | `alphajournal.pages.dev` | Proxied | Admin Console (`destination: admin_console`) |
| `CNAME` | `affiliate` | `alphajournal.pages.dev` | Proxied | Affiliate Portal (`destination: affiliate_application`) |

*(If you also own `alphagournal.in`, add it as a Custom Domain or create a Cloudflare Bulk Redirect Rule forwarding `https://*.alphagournal.in/*` -> `https://$1.alphajournal.in/$2` with status `301`).*

---

## Step 4: Configure Cloudflare SSL/TLS, Security & Redirect Rules

1. **SSL/TLS Mode**:
   - Go to **SSL/TLS -> Overview** and set encryption mode to **Full (strict)**.
   - Go to **SSL/TLS -> Edge Certificates** and enable:
     - **Always Use HTTPS**: `On`
     - **Automatic HTTPS Rewrites**: `On`
     - **Minimum TLS Version**: `TLS 1.2`
2. **Canonical `www` to Root Redirect**:
   - Go to **Rules -> Redirect Rules -> Create Rule**:
   - **Rule name**: `Redirect www to apex`
   - **When incoming requests match**: `Hostname equals www.alphajournal.in`
   - **Then**: Dynamic Redirect -> `concat("https://alphajournal.in", http.request.uri.path)` with Status `301`.
3. **SPA Routing & Headers**:
   - `web/_redirects` and `web/_headers` are bundled into `build/web/` automatically during `flutter build web --release`, so Cloudflare Pages serves `/sitemap.xml`, `/robots.txt`, `/favicon.svg`, and deep links (`/community_feed`, `/auth/login`, `/notes/:id`) with zero 404 errors.

---

## Step 5: Post-Deployment Checklist (What to Do After Deploying)

### 1. Update Supabase Auth URL Configuration
Open your **Supabase Dashboard** (`https://supabase.com/dashboard/project/ylxwgkhtwrizdmuhlhxs/auth/url-configuration`) and configure:

- **Site URL**:
  ```text
  https://alphajournal.in
  ```
- **Redirect URLs** (add all of these so OTP links, password recovery, and OAuth callbacks work across every subdomain):
  ```text
  https://alphajournal.in/**
  https://app.alphajournal.in/**
  https://community.alphajournal.in/**
  https://admin.alphajournal.in/**
  https://affiliate.alphajournal.in/**
  https://*.alphajournal.pages.dev/**
  tradex://auth/callback
  ```

### 2. Where to Put AI API Keys (Supabase Edge Function Secrets vs. Cloudflare Variables)

Your current `.env` keys (`OPEN_AI_KEY` and `OPENROUTER_API_KEY`) have been verified against live OpenAI (`gpt-4o-mini`) and OpenRouter (`openrouter/free`) endpoints and are **100% active and working**.

Here is **where each key belongs** in production:

#### A. Supabase Edge Function Secrets (Primary & Recommended for Security)
All server-side AI keys (`OPENAI_API_KEY` / `OPEN_AI_KEY`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY`) **should be stored in Supabase Edge Function Secrets**, never exposed in public static files.

1. **Via Supabase Dashboard**:
   - Open `https://supabase.com/dashboard/project/ylxwgkhtwrizdmuhlhxs/functions/secrets` (**Project Settings -> Edge Functions -> Secrets**).
   - Add the following secrets:
     - `OPENAI_API_KEY` = *(your `OPEN_AI_KEY` value from `.env`)*
     - `OPEN_AI_KEY` = *(your `OPEN_AI_KEY` value from `.env`)*
     - `OPENROUTER_API_KEY` = *(your `OPENROUTER_API_KEY` value from `.env`)*
2. **Or via Supabase CLI**:
   ```bash
   npx supabase login
   npx supabase secrets set \
     OPENAI_API_KEY="sk-proj-..." \
     OPEN_AI_KEY="sk-proj-..." \
     OPENROUTER_API_KEY="sk-or-v1-..." \
     --project-ref ylxwgkhtwrizdmuhlhxs

   # Deploy the Edge Functions so they pick up the latest code & secrets:
   npx supabase functions deploy ai-gateway --project-ref ylxwgkhtwrizdmuhlhxs
   npx supabase functions deploy note-ai-refactor --project-ref ylxwgkhtwrizdmuhlhxs
   npx supabase functions deploy market-quote-proxy --project-ref ylxwgkhtwrizdmuhlhxs
   ```

#### B. Cloudflare Pages Environment Variables
In **Cloudflare Dashboard -> Workers & Pages -> alphajournal -> Settings -> Environment variables**, put **public client configuration**:
- `SUPABASE_URL` = `https://ylxwgkhtwrizdmuhlhxs.supabase.co`
- `SUPABASE_ANON_KEY` = *(your anon key from `.env`)*
- `SUPABASE_PUBLISHABLE_KEY` = *(your publishable key from `.env`)*
- `ENVIRONMENT` = `production`

> **Optional Client-Side Fallback**: [`UnifiedAiService`](../lib/core/ai/unified_ai_service.dart) and [`RealNoteAiRefactor`](../lib/features/notes/data/real_note_ai_refactor.dart) automatically try the Supabase Edge Functions (`note-ai-refactor` and `ai-gateway`) first. If the Edge Functions are not yet deployed or configured in Supabase, they gracefully fall back to client-side AI providers when compiled with `--dart-define=OPEN_AI_KEY=...` or `--dart-define=OPENROUTER_API_KEY=...`. Once your Supabase Edge Function secrets are set, you do **not** need AI keys in Cloudflare Pages.

### 3. Verify Live Database Pricing & Quotas
The live Supabase database (`public.pricing_catalogues`, `public.profiles`, `public.subscriptions`, and `public.get_customer_quota_usage`) is already updated with:
- **Free (`AppTier.free`)**: ₹0/mo — 3 notes, 15 trades, 1 active playbook, 5 AI queries/mo, Community view access.
- **Basic (`AppTier.premium`)**: ₹299/mo — 25 notes, 100 trades, 3 active playbooks, 20 AI queries/mo (`is_purchasable: false` / Monthly Subscriptions Disabled).
- **Pro (`AppTier.enterprise`)**: ₹499/mo — 10,000 notes, 50,000 trades, 250 active playbooks, 5,000 AI queries/mo (`is_purchasable: false` / Monthly Subscriptions Disabled).

When you are ready to re-enable monthly checkout for Basic and Pro in the future, either:
- Toggle **Purchasable** in **Admin Console -> Pricing & Plans** (`https://admin.alphajournal.in`), or
- Update `is_purchasable` to `true` in `public.pricing_catalogues`.

### 4. Submit `sitemap.xml` to Google Search Console
1. Open [Google Search Console](https://search.google.com/search-console) and add a **Domain Property** for `alphajournal.in`.
2. Verify ownership via Cloudflare DNS (Google Search Console provides a 1-click Cloudflare verification flow).
3. Go to **Sitemaps** in the left sidebar and submit:
   ```text
   https://alphajournal.in/sitemap.xml
   ```
4. Verify that `https://alphajournal.in/robots.txt` is reachable and returns `200 OK`.
