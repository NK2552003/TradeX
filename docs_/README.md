# TradeX project documentation

Master index for project documentation, organized into a single folder tree. All role-specific documents have been consolidated and deduplicated so each file lives in one distinct folder.

## Folder structure

```text
docs_/
├── 01-product/        Product scope, roadmap, and feature specs
├── 02-architecture/   System architecture, database schema, APIs, and integrations
├── 03-design/         Visual design system, screens, UI flows, and navigation
├── 04-frontend/       Flutter implementation: state, components, forms, and routing
├── 05-ops/            Local setup, deployment, security, and testing
├── 06-business/       Client briefs, freelancer briefs, and contractor agreements
└── *.md               Cross-cutting handoffs that belong to no single folder
```

The runnable database lives outside this tree, in [`database/`](../database/): `schema.sql`, `migrations/`, `rls_policies.sql` and `erd.dbml`. Those files are authoritative; every schema description in `02-architecture/` is a reading of them.

---

## Categorization by document type

### 1. Product requirements doc (PRD)
- [PRD.md](./01-product/PRD.md): Complete product scope, user personas, core pillars, subscription tier gating, revenue model, and milestone release plan.
- [FEATURES_LIST.md](./01-product/FEATURES_LIST.md): Feature inventory cataloging capabilities across each functional module and subscription level.

### 2. Requirements doc
- [TIME_ESTIMATION.md](./01-product/TIME_ESTIMATION.md): Delivery timelines, critical path milestones, resource requirements, and risk buffers.
- [FORMS_VALIDATION.md](./04-frontend/FORMS_VALIDATION.md): Field-level functional input constraints, regex requirements, and validation rules.
- [SECURITY_COMPLIANCE.md](./05-ops/SECURITY_COMPLIANCE.md): Security requirements, regulatory compliance, data classification, and AI disclosure standards.
- [TESTING_STRATEGY.md](./05-ops/TESTING_STRATEGY.md): Quality assurance requirements, coverage standards, and verification criteria.

### 3. Systems design doc
- [ARCHITECTURE.md](./02-architecture/ARCHITECTURE.md): End-to-end system architecture, service topology, layer boundaries, and technology stack.
- [DATABASE_ERD.md](./02-architecture/DATABASE_ERD.md): Database entity relationships, primary and foreign key structures, indexes, and schema design.
- [BACKGROUND_JOBS.md](./02-architecture/BACKGROUND_JOBS.md): Background workers, scheduled cron infrastructure, queue mechanics, and rate limits.
- [INTEGRATIONS.md](./02-architecture/INTEGRATIONS.md): Third-party system integrations (Anthropic Claude, market data feeds, RevenueCat, Sentry).
- [ERROR_HANDLING.md](./02-architecture/ERROR_HANDLING.md): Global error architecture, status code standards, retry lifecycles, and failure logging.
- [FULL_STACK_FOLDER_STRUCTURE.md](./FULL_STACK_FOLDER_STRUCTURE.md): Full-stack monorepo system structure uniting client and backend codebases.
- [AUTH_FLOWCHART_AND_SCHEMA.md](./AUTH_FLOWCHART_AND_SCHEMA.md): Complete authentication subsystem design, session refresh pipelines, and credential flows.

### 4. Technical design doc (TDD)
- [API_DATA_MODEL.md](./02-architecture/API_DATA_MODEL.md): Relational schema DDL specifications, column constraints, and row-level security policy implementations.
- [API_REFERENCE.md](./02-architecture/API_REFERENCE.md): REST API contracts, edge function request/response payloads, and status codes.
- [DESIGN_SYSTEM.md](./03-design/DESIGN_SYSTEM.md): Visual technical specifications: color tokens, typography scales, elevation, motion, and breakpoints.
- [DYNAMIC_LINKING.md](./03-design/DYNAMIC_LINKING.md): Deep-linking mechanics, URL schema routing tables, and notification payload handlers.
- [SCREENS_MOBILE.md](./03-design/SCREENS_MOBILE.md): Mobile UI technical specification, component hierarchy, and interaction state inventory.
- [SCREENS_TABLET.md](./03-design/SCREENS_TABLET.md): Tablet adaptive layout design, master-detail viewports, and split-pane behavior.
- [SCREENS_DESKTOP.md](./03-design/SCREENS_DESKTOP.md): Multi-pane workstation desktop layout, keyboard shortcuts, and desktop UI architecture.
- [SCREENS_AND_FLOWS.md](./03-design/SCREENS_AND_FLOWS.md): Module navigation paths, pipeline flows, and cross-screen data propagation.
- [UI_FLOW_DIAGRAMS.md](./03-design/UI_FLOW_DIAGRAMS.md): State machine diagrams for every screen, covering loading, empty, and error paths.
- [SCREEN_CONTENTS.md](./03-design/SCREEN_CONTENTS.md): Detailed field and component element specifications across all screens.
- [STATE_MANAGEMENT.md](./04-frontend/STATE_MANAGEMENT.md): Riverpod provider architecture, stream subscriptions, and caching policies.
- [NAVIGATION_ROUTING.md](./04-frontend/NAVIGATION_ROUTING.md): Navigation as shipped — the `AppScaffold` shell swap and per-screen subpage stacks — plus the `go_router` migration target and its deep-link resolvers.
- [OFFLINE_CACHING.md](./04-frontend/OFFLINE_CACHING.md): Cache invalidation rules, memory lifecycle management, and conflict handling.
- [COMPONENT_LIBRARY.md](./04-frontend/COMPONENT_LIBRARY.md): Reusable UI component catalog and architectural block specifications.
- [FLUTTER_FOLDER_STRUCTURE.md](./04-frontend/FLUTTER_FOLDER_STRUCTURE.md): Feature-driven Flutter client code organization and architectural boundaries.
- [LINKED_NOTES_BACKEND_HANDOFF.md](./LINKED_NOTES_BACKEND_HANDOFF.md): The combined handoff for trader notes, journal notes and strategy notes — the link graph, its tables and triggers, the full write timeline, every endpoint and the acceptance tests. Backs migrations 009–012.
- [NOTES_BACKEND_HANDOFF.md](./NOTES_BACKEND_HANDOFF.md): Notes engagement (likes, comments, views) and the AI refactor Edge Function. Still authoritative for everything it covers.
- [BACKEND_HANDOFF_GUIDELINE.md](./BACKEND_HANDOFF_GUIDELINE.md): Backend implementation conventions, edge function standards, and security rules.

### 5. Runbook / SOPs
- [DEV_SETUP.md](./05-ops/DEV_SETUP.md): Step-by-step developer environment onboarding, local emulator execution, and common troubleshooting.
- [DEPLOYMENT.md](./05-ops/DEPLOYMENT.md): Continuous integration pipeline execution, multi-environment deployment runbook, and rollback protocols.
- [ENVIRONMENT_VARIABLES.md](./02-architecture/ENVIRONMENT_VARIABLES.md): Operational guide to secret management, API keys, and environment variables across deployment tiers.

### 6. Incident report
- *No incidents recorded to date. This category is reserved for post-incident reviews, root cause analyses, and outage retrospectives.*

### 7. Other
- [README.md](./README.md): Master documentation hub, module index, and navigation roadmap.
- [BACKEND_README.md](./02-architecture/BACKEND_README.md): Backend onboarding order, architecture orientation, and technical debt log.
- [FRONTEND_README.md](./04-frontend/FRONTEND_README.md): Client onboarding guide, reading progression, and implementation status.
- [CONTENT_STYLE.md](./03-design/CONTENT_STYLE.md): Editorial style guide, voice and tone standards, and product microcopy glossary.

---

## Module directory reference

### 01-product: Product scope and roadmap
| File | Covers |
|---|---|
| `PRD.md` | Complete product scope: core pillars, user profiles, module features, subscription tiers, revenue model, and release plan |
| `FEATURES_LIST.md` | Plain feature list detailing what the app does by module, including tier flags |
| `TIME_ESTIMATION.md` | Delivery timelines, critical path schedules, and scope conflict assessments |

### 02-architecture: Backend architecture and systems
| File | Covers |
|---|---|
| `ARCHITECTURE.md` | Technical stack, high-level architecture diagram, folder structure, and environment targets |
| `API_DATA_MODEL.md` | Complete database schema (DDL), RLS policies, and Edge Function flows |
| `DATABASE_ERD.md` | Entity relationship diagram, the link graph and its five triggers, every index as shipped, and migration conventions |
| `API_REFERENCE.md` | Endpoint definitions and Edge Function contracts |
| `INTEGRATIONS.md` | Claude API, market data providers, RevenueCat, push notifications, and storage |
| `BACKGROUND_JOBS.md` | Scheduled background routines, rate limiting, and idempotency guarantees |
| `ERROR_HANDLING.md` | Standard error envelopes, HTTP status codes, retry logic, and logging guidelines |
| `ENVIRONMENT_VARIABLES.md` | Required environment variables and secrets per deployment tier |
| `BACKEND_README.md` | Backend developer onboarding order and technical debt inventory |

### 03-design: Visual design system and interface flows
| File | Covers |
|---|---|
| `DESIGN_SYSTEM.md` | Color palettes, typography, spacing, motion tokens, elevations, component states, and breakpoints |
| `CONTENT_STYLE.md` | Tone of voice, product terminology, and interface copy guidelines |
| `SCREENS_MOBILE.md` | Mobile baseline screens and component inventories |
| `SCREENS_TABLET.md` / `SCREENS_DESKTOP.md` | Tablet and desktop layout adaptations from the mobile baseline |
| `SCREEN_CONTENTS.md` | Screen-by-screen content inventory and layout specifications |
| `SCREENS_AND_FLOWS.md` | Module-level screen catalog and primary navigation paths |
| `UI_FLOW_DIAGRAMS.md` | Mermaid flow diagrams per screen with tier gate overlays |
| `DYNAMIC_LINKING.md` | Deep linking routes, notification payload mappings, and share handlers |

### 04-frontend: Client implementation
| File | Covers |
|---|---|
| `STATE_MANAGEMENT.md` | Riverpod provider architecture, code generation, and state caching patterns |
| `COMPONENT_LIBRARY.md` | Catalog of reusable Flutter components implementing the design system |
| `FORMS_VALIDATION.md` | Input validation rules and corresponding user error copy |
| `NAVIGATION_ROUTING.md` | Navigation as shipped (shell swap, per-screen subpage stacks) and the `go_router` target for the routes in `03-design/DYNAMIC_LINKING.md` |
| `OFFLINE_CACHING.md` | Online-first caching strategy, cache TTL durations, and data conflict policies |
| `FRONTEND_README.md` | Frontend reading order and implementation gaps |

### 05-ops: Operational documentation across all roles
| File | Covers |
|---|---|
| `DEV_SETUP.md` | Local developer environment setup instructions |
| `DEPLOYMENT.md` | CI/CD build pipelines, staging environments, production deployments, and rollbacks |
| `SECURITY_COMPLIANCE.md` | RLS audit checklists, AI output compliance, and incident response procedures |
| `TESTING_STRATEGY.md` | Automated testing tiers, edge function test suites, and coverage expectations |

### Root of `docs_/`: cross-cutting documents
These belong to no single folder because they span product, schema and client at once.

| File | Covers |
|---|---|
| `LINKED_NOTES_BACKEND_HANDOFF.md` | Trader notes + journal notes + strategy notes as one linked system: the three edge types, the join table and the four trigger-maintained mirrors, the write timeline for every link operation, `strategy_performance`, the public read path, all endpoints, and 17 acceptance tests. The contract behind `database/migrations/009`–`012` |
| `NOTES_BACKEND_HANDOFF.md` | Note engagement (likes, comments, view counts) and the `note-ai-refactor` Edge Function |
| `BACKEND_HANDOFF_GUIDELINE.md` | Conventions every handoff follows: envelopes, Edge Function structure, security rules |
| `AUTH_FLOWCHART_AND_SCHEMA.md` | Auth subsystem: signup trigger, session refresh, profile creation, referral resolution |
| `FULL_STACK_FOLDER_STRUCTURE.md` | How the Flutter client and the Supabase project sit side by side |

### Reading order for a backend engineer picking up the notes system
1. `BACKEND_HANDOFF_GUIDELINE.md` — the conventions everything else assumes.
2. `LINKED_NOTES_BACKEND_HANDOFF.md` sections 1–3 — the model, then the link graph and its triggers.
3. `02-architecture/DATABASE_ERD.md` — the same graph as a diagram, with the shipped indexes.
4. `database/README.md` — the run order, the two non-additive migrations, the three buckets.
5. `LINKED_NOTES_BACKEND_HANDOFF.md` sections 4–14 — mapping, endpoints, storage, the public boundary, rollout, acceptance tests.