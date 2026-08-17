# TraderHub — Flutter Folder Structure

This document defines the recommended Flutter project layout for TraderHub. The goal is to keep feature code isolated, make Riverpod usage predictable, and leave room for testing, shared UI, and future platform-specific work without turning `lib/` into a dumping ground.

## Recommended layout

```text
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
```

## What belongs where

### `lib/core/`
Shared code that does not belong to a single feature.

- `config/` for environment access, app constants, and app-wide configuration objects.
- `network/` for the Dio client, interceptors, request helpers, and API plumbing.
- `router/` for the `go_router` setup and route guards.
- `theme/` for Material theme setup, tokens, and design-system mapping.
- `utils/` for small reusable helpers that are not UI-specific.
- `widgets/` for shared widgets used across multiple features.

### `lib/features/<feature>/`
Each feature stays isolated inside its own slice.

- `data/` for data sources, DTOs, repository implementations, and remote/local adapters.
- `domain/` for entities, repository contracts, and business rules.
- `presentation/` for screens, widgets, controllers, and Riverpod providers tied to the UI.

### `test/`
Mirror the production feature structure so tests are easy to find.

- Keep unit tests near the corresponding feature slice.
- Place widget and golden tests next to the presentation layer they cover.
- Put shared test helpers in `test/core/`.

## Feature slice example

```text
lib/features/journal/
  data/
    datasources/
    dtos/
    repositories/
  domain/
    entities/
    repositories/
    usecases/
  presentation/
    pages/
    widgets/
    providers/
```

## Conventions

- Prefer feature-first organization over generic app-wide folders.
- Keep UI, state, and data access separated by layer inside a feature.
- Put cross-feature helpers in `core/` only when they are truly shared.
- Keep generated files out of the structure description; codegen output should live beside the source that generates it.
- Add new features as new slices under `lib/features/` instead of expanding `core/`.

## Practical rule

If a file answers a question for one feature, keep it inside that feature slice. If it answers a question for the whole app, move it to `core/`.