# Frontend Feature Audit: Trade Journal

**Component:** `lib/features/journal/`  
**Target Files:**  
- `lib/features/journal/ui/journal_screen.dart`  
- `lib/features/journal/ui/journal_entry_screen.dart`  
- `lib/features/journal/ui/journal_editor_screen.dart`  

---

## 1. Layout & Viewport Flaws

- **Spreadsheet Table Squishing on Mobile (`journal_screen.dart:1500-1560`):**
  - In `_JournalTableView`, 9 data columns (Date, Symbol, Type, Qty, Entry, Exit, P&L, Status, Strategy) are crammed into a fixed row on mobile viewports (<600px).
  - Text strings wrap awkwardly and P&L badges are squished into vertical lines.
  - **Action:** Switch to vertical card view (`UiCard`) on screens < 600px; enable horizontal scrolling for spreadsheet tables on screens >= 600px.

---

## 2. Privacy & Logic Bugs

- **Inverted Link Graph Privacy Bug (`journal_entry_screen.dart:142-143`):**
  - `_isPublicViewer` evaluates to `true` whenever `_entry.isPublic` is true.
  - Calling `_graph.bundleForJournal(_entry, onlyPublic: _isPublicViewer)` hides the author's own private linked notes and strategies from their own view!
  - **Action:** Decouple: `_isPublicViewer => widget.isPublicContext || (!widget.canEdit && _entry.isPublic)`.

---

## 3. Disconnected Trade Logging Flows

- **No Calculator Import:**
  - Cannot import values calculated in `PositionSizeScreen` or `RiskRewardScreen` into `JournalEditorScreen`.
  - **Action:** Add draft trade parameter ingestion in `JournalEditorScreen(initialTrade: ...)`.
