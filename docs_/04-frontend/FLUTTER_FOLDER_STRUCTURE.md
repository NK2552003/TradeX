# Flutter folder structure: TradeX

This document defines the recommended Flutter project layout for TradeX. The goal is to keep feature code isolated, make Riverpod state management predictable, and organize testing and shared UI cleanly without cluttering `lib/`.

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

- `config/`: Environment configuration, app constants, and global settings.
- `network/`: Dio client configuration, interceptors, request helpers, and API plumbing.
- `router/`: Navigation setup using `go_router` and authentication guards.
- `theme/`: Material theme definitions, tokens, and design system mappings.
- `utils/`: Reusable utility functions and helper classes.
- `widgets/`: Shared UI components used across multiple features.

### `lib/features/<feature>/`
Each feature lives inside its own isolated slice.

- `data/`: Remote and local data sources, DTOs, and repository implementations.
- `domain/`: Business entities, repository interfaces, and use cases.
- `presentation/`: Screens, widgets, controllers, and Riverpod providers.

### `test/`
Mirrors the production feature structure to keep tests discoverable.

- Keep unit tests near their corresponding feature slice.
- Place widget and golden tests next to the presentation layer they verify.
- Store shared test helpers and mock factories in `test/core/`.

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

- Organize files by feature first rather than by technical layer across the whole application.
- Separate UI, state, and data access layers cleanly within each feature.
- Place helpers in `core/` only when multiple features require them.
- Keep generated code next to its source files.
- Introduce new product capabilities as dedicated directories under `lib/features/`.

## Practical rule

If a file serves a single feature, keep it inside that feature directory. If it serves the entire application, place it in `core/`.