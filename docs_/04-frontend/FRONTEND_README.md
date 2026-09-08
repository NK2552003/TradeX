# Frontend developer documentation: TradeX

This guide provides technical context for developing the Flutter client across iOS, Android, web, and desktop. Backend service contracts are documented separately; this guide focuses on client implementation, UI components, state management, and navigation.

## Recommended reading order

**Orientation**
1. [ARCHITECTURE.md](../02-architecture/ARCHITECTURE.md): Technology stack, folder organization, and environments.
2. [DEV_SETUP.md](../05-ops/DEV_SETUP.md): Local environment setup, running the application, and common troubleshooting steps.

**Design and content**
3. [DESIGN_SYSTEM.md](../03-design/DESIGN_SYSTEM.md): Colors, typography, spacing, motion, component states, and breakpoints.
4. [CONTENT_STYLE.md](../03-design/CONTENT_STYLE.md): Voice, terminology, and microcopy conventions.
5. [COMPONENT_LIBRARY.md](./COMPONENT_LIBRARY.md): Catalog of reusable widgets implementing the design tokens.

**Screens**
6. [SCREENS_MOBILE.md](../03-design/SCREENS_MOBILE.md): Baseline mobile screens and component states.
7. [SCREENS_TABLET.md](../03-design/SCREENS_TABLET.md) and [SCREENS_DESKTOP.md](../03-design/SCREENS_DESKTOP.md): Layout adaptations across tablet and desktop viewports.
8. [SCREEN_CONTENTS.md](../03-design/SCREEN_CONTENTS.md): Flat reference listing all screen elements.
9. [SCREENS_AND_FLOWS.md](../03-design/SCREENS_AND_FLOWS.md) and [UI_FLOW_DIAGRAMS.md](../03-design/UI_FLOW_DIAGRAMS.md): Module-level architecture and individual screen state flow diagrams.

**Implementation**
10. [STATE_MANAGEMENT.md](./STATE_MANAGEMENT.md): Riverpod provider architecture and state conventions.
11. [NAVIGATION_ROUTING.md](./NAVIGATION_ROUTING.md): Routing configuration with `go_router` implementing deep-link mappings.
12. [DYNAMIC_LINKING.md](../03-design/DYNAMIC_LINKING.md): Route tables and feature-flow specifications.
13. [FORMS_VALIDATION.md](./FORMS_VALIDATION.md): Form input validation rules and error messaging.
14. [OFFLINE_CACHING.md](./OFFLINE_CACHING.md): Cached datasets, network dependencies, and conflict resolution.
15. [FLUTTER_FOLDER_STRUCTURE.md](./FLUTTER_FOLDER_STRUCTURE.md): Code organization within `lib/` and `test/`.
16. [FULL_STACK_FOLDER_STRUCTURE.md](../FULL_STACK_FOLDER_STRUCTURE.md): Monorepo structure unifying Flutter and Supabase.

**Quality and release**
17. [TESTING_STRATEGY.md](../05-ops/TESTING_STRATEGY.md): Unit, widget, golden, and integration test coverage.
18. [DEPLOYMENT.md](../05-ops/DEPLOYMENT.md): Continuous integration, environments, and store release pipelines.

## Known gaps and technical considerations

| Gap | Reference | Required action |
|---|---|---|
| Global desktop search lacks dedicated routes and backend queries | NAVIGATION_ROUTING.md section 7, SCREENS_DESKTOP.md section 6 | Establish design and query architecture prior to implementation |
| In-progress trade drafts lack offline storage | OFFLINE_CACHING.md section 7 | Add local storage draft persistence to prevent lost user input |
| Client-side character limits omitted on free-form text areas | FORMS_VALIDATION.md section 9 | Introduce practical limits (such as 10,000 characters) to prevent rendering slowdowns |
| Enterprise screens lack routes, providers, and repositories | NAVIGATION_ROUTING.md section 7 | Deferred intentionally until post-MVP milestone |
| AI assistant chat interface pending streaming implementation | API_DATA_MODEL.md section 10 | Build streaming chat presentation layer against the specified backend contract |
| Database lacks soft deletion for instant undo actions | API_REFERENCE.md section 1 | Evaluate backend soft delete support before extending client undo persistence |
| Direct message push notification delivery mechanics unresolved | API_DATA_MODEL.md section 11 | Verify notification delivery mechanisms on mobile push services |
| Community feed lacks client-side filtering for blocked users | DATABASE_ERD.md section 2 | Filter public feed queries against the active user block list client-side |

This frontend implementation aligns with the backend API contracts. If backend definitions change, update the relevant client documents, especially STATE_MANAGEMENT.md and NAVIGATION_ROUTING.md.
