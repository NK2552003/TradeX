# TradeX full stack folder structure

This document outlines the project layout for the TradeX application, organizing the Flutter client and Supabase backend into a single repository structure.

## Recommended layout

```text
TradeX/
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

## Frontend structure

The Flutter application lives in `lib/` and `test/`:

- `lib/core/`: shared application code including configuration, networking, routing, theme tokens, and reusable widgets.
- `lib/features/<feature>/`: self-contained domain features separated into `data/`, `domain/`, and `presentation/` layers.
- `test/`: mirrors the production directory structure to keep test suites paired with source features.
- Platform folders (`android/`, `ios/`, `web/`, and desktop): standard Flutter platform targets at the workspace root.

## Backend structure

Supabase backend assets live under `supabase/`:

- `supabase/migrations/`: SQL migration files managing database schema definitions, row-level security policies, and performance indexes.
- `supabase/functions/`: Supabase Edge Functions, with one directory per function.
- Each function runs server-side TypeScript on Deno and handles a single API boundary or scheduled task.

## Backend functions

```text
supabase/functions/
  ai-insight/                # AI market and trading insights
  analyze-screenshot/        # Vision parsing for trade journal screenshots
  ai-strategy-review/        # Premium strategy review
  ai-journal-analysis/       # Premium journal analysis and trade review
  strategy-ai-summary/       # Premium strategy summary generation
  ai-chat/                   # Premium conversational Q&A
  price-alerts/              # Scheduled market alert checks
  revenuecat-webhook/        # Subscription synchronization webhook
```

## Architecture guidelines

- Keep UI components, state providers, and repositories inside the feature slice that owns them.
- Place utility functions in `lib/core/` only when multiple feature modules depend on them.
- Track all database schema changes through `supabase/migrations/` to guarantee reproducible environments.
- Keep third-party secrets and private keys inside Supabase Edge Function environment variables.
- Implement new capabilities as self-contained feature slices in Flutter, paired with corresponding migrations or Edge Functions when backend support is required.

## Related documentation

- [04-frontend/FLUTTER_FOLDER_STRUCTURE.md](./04-frontend/FLUTTER_FOLDER_STRUCTURE.md) details the client-only folder layout.
- [02-architecture/ARCHITECTURE.md](./02-architecture/ARCHITECTURE.md) defines the backend stack and overall system design.