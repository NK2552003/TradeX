# Frontend Feature Audit: Linking & Universal Graph

**Component:** `lib/features/linking/`  
**Target Files:**  
- `lib/features/linking/record_link_picker.dart`  
- `lib/features/linking/link_graph_service.dart`  

---

## 1. UI Performance & Hitching

- **Main Isolate Adjacency Recalculations (`link_graph_service.dart:110-130`):**
  - Graph rebuilds synchronously on every keystroke in `NoteEditorScreen`.
  - Causes dropped frames on large portfolios.
  - **Action:** Debounce graph rebuilds by 500ms and offload calculation using `compute()`.

---

## 2. Stale Ticker Picker Universe

- **Static Hardcoded Symbols (`link_graph_service.dart:36`):**
  - Cashtag picker pulls from static `DemoDataSource`, ignoring user's real watchlists.
  - **Action:** Wire picker to live user symbols.
