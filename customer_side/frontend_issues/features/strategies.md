# Frontend Feature Audit: Strategies & Playbooks

**Component:** `lib/features/strategies/`  
**Target Files:**  
- `lib/features/strategies/ui/strategies_screen.dart`  
- `lib/features/strategies/ui/strategy_detail_screen.dart`  
- `lib/features/strategies/ui/strategy_editor_screen.dart`  

---

## 1. Dead Buttons & No-Op Handlers

| UI Control | File & Line | Failure Mechanism | Priority |
|---|---|---|:---:|
| Header "More Options" Menu | `strategy_editor_screen.dart:1158` | Child `UiIconButton` has `onPressed: null`; completely inactive. | Low |

---

## 2. Layout & Tablet Breakpoint Flaws

- **Split Mode Layout Squishing (`strategy_editor_screen.dart:45-55`):**
  - In `Split` mode, write and preview panes are forced side-by-side in a horizontal `Row`.
  - On devices with width < 840px (portrait iPad, foldable screens, mobile), each pane receives < 380px, causing extreme clipping of checklists and parameter tables.
  - **Action:** Automatically disable `Split` mode when `constraints.maxWidth < 840px`, forcing tabbed `Write` or `Read` mode.

---

## 3. Privacy & Logic Safeguards

- **Inverted Link Graph Privacy Bug (`strategy_detail_screen.dart:279-281`):**
  - Public strategy hides author's private executed trades from their own view.
  - **Action:** Allow owners to view private linked trades regardless of strategy public status.
- **Accidental Public Disclosure of Proprietary Edge (`strategy_editor_screen.dart:400-450`):**
  - Toggling visibility to "Public" publishes alpha/edge without a warning dialog.
  - **Action:** Present an explicit confirmation modal explaining public visibility.
