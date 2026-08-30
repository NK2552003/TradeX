# TraderHub — Frontend Developer Docs

Everything needed to build the Flutter client (iOS/Android/Web/Desktop). Backend contracts live in a separate doc set (traderhub-backend-docs.zip) — this package is scoped to client-side implementation, screens, and design.

## Read in this order

**Orientation**
1. **[ARCHITECTURE.md](./ARCHITECTURE.md)** — stack, folder structure, environments.
2. **[DEV_SETUP.md](./DEV_SETUP.md)** — local setup, running the app, common issues.

**Design & content**
3. **[DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md)** — colors, typography, spacing, motion, elevation, component states, breakpoints.
4. **[CONTENT_STYLE.md](./CONTENT_STYLE.md)** — tone of voice, terminology, microcopy patterns.
5. **[COMPONENT_LIBRARY.md](./COMPONENT_LIBRARY.md)** — the actual reusable widget catalog implementing the design system.

**Screens**
6. **[SCREENS_MOBILE.md](./SCREENS_MOBILE.md)** — every screen + sub-screen, full component detail (baseline).
7. **[SCREENS_TABLET.md](./SCREENS_TABLET.md)** / **[SCREENS_DESKTOP.md](./SCREENS_DESKTOP.md)** — layout adaptations from the mobile baseline.
8. **[SCREEN_CONTENTS.md](./SCREEN_CONTENTS.md)** — flat per-screen content reference.
9. **[SCREENS_AND_FLOWS.md](./SCREENS_AND_FLOWS.md)** / **[UI_FLOW_DIAGRAMS.md](./UI_FLOW_DIAGRAMS.md)** — module-level and per-screen mermaid flow diagrams.

**Implementation**
10. **[STATE_MANAGEMENT.md](./STATE_MANAGEMENT.md)** — Riverpod provider architecture and conventions.
11. **[NAVIGATION_ROUTING.md](./NAVIGATION_ROUTING.md)** — go_router config implementing the deep-link route table.
12. **[DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md)** — the route table and feature-flow diagrams that § 11 implements.
13. **[FORMS_VALIDATION.md](./FORMS_VALIDATION.md)** — every input field's validation rule and error copy.
14. **[OFFLINE_CACHING.md](./OFFLINE_CACHING.md)** — what's cached, what requires connectivity, conflict handling.
15. **[FLUTTER_FOLDER_STRUCTURE.md](./FLUTTER_FOLDER_STRUCTURE.md)** — recommended lib/ and test/ layout for the Flutter app
16. **[../FULL_STACK_FOLDER_STRUCTURE.md](../FULL_STACK_FOLDER_STRUCTURE.md)** — combined Flutter frontend + Supabase backend layout

**Quality & release**
17. **[TESTING_STRATEGY.md](./TESTING_STRATEGY.md)** — widget/golden tests, RLS-aware testing, coverage priorities
18. **[DEPLOYMENT.md](./DEPLOYMENT.md)** — CI/CD, staging→prod, mobile build/release process

## Known gaps — flagged, not silently built around

| Gap | Where flagged | What's needed |
|---|---|---|
| Global desktop search has no route or backend query | NAVIGATION_ROUTING.md § 7, SCREENS_DESKTOP.md § 6 | Needs a design + implementation decision before building |
| No offline draft persistence for in-progress journal entries | OFFLINE_CACHING.md § 7 | Likely quick win (local storage), not yet committed |
| No client-side max length on long text fields (notes/psychology/etc.) | FORMS_VALIDATION.md § 9 | Needs a sanity cap decided, purely for UI performance |
| Enterprise screens have no routes, providers, or repositories yet | NAVIGATION_ROUTING.md § 7 | Deferred intentionally — Enterprise is post-MVP (ROADMAP.md, product doc set) |
| `ai-chat` backend contract now exists (API_DATA_MODEL.md § 10), but frontend has no chat UI implementation yet beyond the screen shell in SCREENS_MOBILE.md § 7 | API_REFERENCE.md § 2 | Backend is no longer the blocker — needs a streaming-UI implementation pass against the now-specced contract |
| No soft-delete on the backend means the "Undo" toast pattern (SCREENS_MOBILE.md cross-cutting states) only works while the delete request hasn't actually been confirmed server-side | API_REFERENCE.md § 1 (backend doc set) | Depends on a backend decision (soft delete vs. accept session-only Undo) — don't build a longer-lived Undo than the backend actually supports |
| Direct Message push notifications land in-app immediately (via the `notify_new_message` trigger) but actual FCM/APNs delivery timing is unresolved on the backend | API_DATA_MODEL.md § 11 (backend doc set) | Don't assume push arrives instantly when testing Conversation Detail's notification badge — the in-app `notifications` row and Notification Center will be correct regardless, only the push itself has an undecided delivery mechanism |
| Community Feed doesn't yet filter out a blocked user's posts client-side | DATABASE_ERD.md § 2 (backend doc set) | The `blocks` table exists but posts/comments stay public-read by design — the feed query needs an explicit filter against the current user's block list, this isn't handled by RLS |

This package assumes the backend doc set (traderhub-backend-docs.zip) as the contract for every API call referenced here — if that contract changes, these docs (especially STATE_MANAGEMENT.md and NAVIGATION_ROUTING.md) need a pass to stay accurate.
