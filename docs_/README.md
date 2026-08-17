# TraderHub — Complete Documentation

Master index for every doc produced for this project, organized as one folder tree instead of separate zips. If you were handed a specific role's zip before (product/UI-UX/backend/frontend/freelance), this is the same content consolidated and deduplicated — every file now lives in exactly one folder.

## Folder structure

```
traderhub-project/
├── 01-product/        Product scope, roadmap, feature specs
├── 02-architecture/    System design, database, APIs, integrations, backend ops
├── 03-design/          Visual design system, screens, UI flows, navigation
├── 04-frontend/        Flutter implementation: state, components, forms, routing
├── 05-ops/              Setup, deployment, security, testing (shared across roles)
└── 06-business/          Client briefs, freelancer briefs, contractor agreement
```

## 01-product/ — What we're building and why
| File | Covers |
|---|---|
| `PRD.md` | Full product scope: 5 pillars, target users, all features by module, subscription tiers, revenue model, release plan |
| `FEATURES_LIST.md` | Plain, non-technical feature list — what the app does, by module, with tier tags. The quick read for the owner; PRD.md is the full detail |
| `TIME_ESTIMATION.md` | Solo vs. parallel-freelance build timelines, critical path, and how the open Phase 1 scope conflict changes the estimate |

## 02-architecture/ — How the backend is built
| File | Covers |
|---|---|
| `ARCHITECTURE.md` | Stack, high-level diagram, folder structure, environments |
| `API_DATA_MODEL.md` | Full DB schema (DDL), RLS policies, Edge Function flows — source of truth for the data model |
| `DATABASE_ERD.md` | Visual entity relationships, indexing, migration conventions |
| `API_REFERENCE.md` | Every REST/RPC endpoint and Edge Function as a formal contract |
| `INTEGRATIONS.md` | Claude API, market data, RevenueCat, push notifications, storage |
| `BACKGROUND_JOBS.md` | Scheduled jobs, rate-limit design, idempotency |
| `ERROR_HANDLING.md` | Error envelope, status codes, retry guidance, logging rules |
| `ENVIRONMENT_VARIABLES.md` | Every secret, per environment |
| `BACKEND_README.md` | Backend-specific reading order + a consolidated backend gaps table |

## 03-design/ — What it looks like and how it flows
| File | Covers |
|---|---|
| `DESIGN_SYSTEM.md` | Colors, typography, spacing, motion, elevation, component states, breakpoints, icon/asset specs |
| `CONTENT_STYLE.md` | Tone of voice, terminology, microcopy patterns |
| `SCREENS_MOBILE.md` | Every screen + sub-screen, full component detail (baseline) |
| `SCREENS_TABLET.md` / `SCREENS_DESKTOP.md` | Layout adaptations from the mobile baseline |
| `SCREEN_CONTENTS.md` | Flat per-screen content reference |
| `SCREENS_AND_FLOWS.md` | Module-level screen inventory + navigation flow diagrams |
| `UI_FLOW_DIAGRAMS.md` | Per-screen mermaid flow diagrams (all 42 screens) + subscription-tier flow overlay |
| `DYNAMIC_LINKING.md` | Deep-link route table, notification→link mapping, share flows |

## 04-frontend/ — How the client is implemented
| File | Covers |
|---|---|
| `STATE_MANAGEMENT.md` | Riverpod provider architecture and conventions |
| `COMPONENT_LIBRARY.md` | Reusable widget catalog implementing the design system |
| `FORMS_VALIDATION.md` | Every input field's validation rule and error copy |
| `NAVIGATION_ROUTING.md` | go_router config implementing `03-design/DYNAMIC_LINKING.md`'s route table |
| `OFFLINE_CACHING.md` | Online-first MVP scope decision, caching TTLs, conflict handling |
| `FRONTEND_README.md` | Frontend-specific reading order + a consolidated frontend gaps table |

## 05-ops/ — Shared across every role
| File | Covers |
|---|---|
| `DEV_SETUP.md` | Local environment setup |
| `DEPLOYMENT.md` | CI/CD pipeline, staging→prod, rollback |
| `SECURITY_COMPLIANCE.md` | RLS review checklist, AI output compliance, incident response |
| `TESTING_STRATEGY.md` | Test layers, RLS/Edge Function testing, coverage priorities |