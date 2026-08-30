# TraderHub — Full-Stack Folder Structure

This document shows the recommended project layout for the full TraderHub app: Flutter on the client side and Supabase on the backend side. It is meant to be the single place to understand where app code, tests, migrations, and Edge Functions live.

## Recommended layout

```text
traderhub/
  android/
  ios/
  macos/
  linux/
  windows/
  web/
  assets/
  lib/
    core/
      config/
      network/
      router/
      theme/
      utils/
      widgets/
    features/
      auth/
        data/
        domain/
        presentation/
      journal/
        data/
        domain/
        presentation/
      strategies/
        data/
        domain/
        presentation/
      watchlists/
        data/
        domain/
        presentation/
      portfolio/
        data/
        domain/
        presentation/
      community/
        data/
        domain/
        presentation/
      messages/
        data/
        domain/
        presentation/
      insights/
        data/
        domain/
        presentation/
      notifications/
        data/
        domain/
        presentation/
      subscriptions/
        data/
        domain/
        presentation/
      enterprise/
        data/
        domain/
        presentation/
    main.dart
  test/
    core/
    features/
      auth/
      journal/
      strategies/
      watchlists/
      portfolio/
      community/
      messages/
      insights/
      notifications/
      subscriptions/
  supabase/
    migrations/
    functions/
      ai-insight/
      analyze-screenshot/
      ai-strategy-review/
      ai-journal-analysis/
      strategy-ai-summary/
      ai-chat/
      price-alerts/
      revenuecat-webhook/
  pubspec.yaml
  analysis_options.yaml
  README.md
```

## Frontend side

The Flutter app stays under `lib/` and `test/`.

- `lib/core/` holds shared app-wide code: config, networking, routing, theme, utilities, and reusable widgets.
- `lib/features/<feature>/` keeps each feature isolated into `data/`, `domain/`, and `presentation/` layers.
- `test/` mirrors the production structure so tests are easy to place and find.
- Platform folders like `android/`, `ios/`, `web/`, and desktop targets stay at the root because they are standard Flutter platform entry points.

## Backend side

The Supabase backend stays under `supabase/`.

- `supabase/migrations/` contains SQL migration files for schema, RLS, indexes, and database changes.
- `supabase/functions/` contains Edge Functions, one folder per function.
- Each Edge Function folder is server-side TypeScript/Deno code and should stay focused on a single API boundary or scheduled job.

## Backend function map

```text
supabase/functions/
  ai-insight/                # AI market/trading insight generation
  analyze-screenshot/        # Screenshot parsing for trade journal prefill
  ai-strategy-review/        # Premium strategy review
  ai-journal-analysis/       # Premium journal analysis / trade review
  strategy-ai-summary/       # Premium strategy summary generation
  ai-chat/                   # Premium AI chat / Q&A
  price-alerts/              # Scheduled market alert checks
  revenuecat-webhook/        # Subscription sync webhook
```

## Practical rules

- Keep Flutter UI, state, and data access in the feature slice that owns them.
- Keep shared logic in `lib/core/` only when more than one feature needs it.
- Keep all schema changes in `supabase/migrations/` so the database is reproducible.
- Keep all server-side API logic in `supabase/functions/` so secret keys never enter the client.
- Add new product features as new feature slices in Flutter and, when needed, matching migrations or Edge Functions in Supabase.

## Relationship to the other docs

- [04-frontend/FLUTTER_FOLDER_STRUCTURE.md](04-frontend/FLUTTER_FOLDER_STRUCTURE.md) is the frontend-only version of the app layout.
- [02-architecture/ARCHITECTURE.md](02-architecture/ARCHITECTURE.md) remains the source of truth for the backend stack and the canonical folder structure used here.