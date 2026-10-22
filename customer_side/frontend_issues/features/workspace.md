# Frontend Feature Audit: Core Workspace

**Component:** `lib/features/workspace/`  
**Target Files:**  
- `lib/features/workspace/ui/workspace_screen.dart`  
- `lib/core/widgets/app_scaffold.dart`  

---

## 1. Layout & Breakpoint Defects

- **Desktop Carousel Pagination Card Occlusion (`workspace_screen.dart:350-420`):**
  - On viewports between 768px and 904px, Writing Desk carousels display 2.5 cards.
  - The right arrow navigation button overlays the rightmost card title and outcome badge, causing accidental clicks.
  - **Action:** Anchor carousel pagination buttons in the section header row.

---

## 2. Navigation & State Retention

- **Search & Filter State Evaporation:**
  - Returning from an inner editor (Note, Trade, Strategy) wipes the user's active search query and resets calendar date pickers.
  - **Action:** Retain search/filter state in a persistent controller/provider.
