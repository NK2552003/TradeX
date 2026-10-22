# Frontend Feature Audit: Notes & Writing Desk

**Component:** `lib/features/notes/`  
**Target Files:**  
- `lib/features/notes/ui/notes_screen.dart`  
- `lib/features/notes/ui/note_editor_screen.dart`  
- `lib/features/notes/ui/note_preview_screen.dart`  
- `lib/features/notes/data/note_attachments.dart`  
- `lib/core/markdown_kit/html_block.dart`  

---

## 1. Critical Security Vulnerability in Frontend Exporter

- **Local File Inclusion (LFI) via PDF Exporter (`note_attachments.dart:117-131` & `note_preview_screen.dart:188`):**
  - Markdown image tags (`![file](/Users/victim/.ssh/id_rsa)`) are resolved via `File(source).readAsBytes()` without sandbox checks.
  - Generates PDFs containing private host filesystem data.
  - **Action:** Restrict `File` reads strictly to the sandboxed application document directory.

---

## 2. Layout, Keyboard & Overlay Flaws

- **Double Keyboard Inset Bug (`note_editor_screen.dart:1300-1370`):**
  - Combining `resizeToAvoidBottomInset: true` on parent Scaffold with `Positioned(bottom: baseBottom + gutter)` shifts the toolbar upwards by keyboard inset twice.
  - Floating toolbar hovers 200px in the middle of the screen; `MarkdownSlashPalette` gets pushed off the top.
  - **Action:** Set `resizeToAvoidBottomInset: false` on Scaffold or zero out `baseBottom` when `inset > 0`.
- **Synchronous Markdown AST Parsing (`note_editor_screen.dart:154-158`):**
  - `_body.addListener` fires full-document regex extraction on every keystroke, causing 35ms frame drops on notes > 500 lines.
  - **Action:** Debounce by 250ms and offload tokenization to Dart `compute()`.

---

## 3. Dead UI Controls & Privacy Bugs

- **Dead HTML `<a>` Links (`html_block.dart:512-514`):**
  - HTML anchor tags in MarkdownKit are styled but lack a `TapGestureRecognizer`; clicking them is a no-op.
  - **Action:** Attach `TapGestureRecognizer` that invokes `url_launcher`.
- **Inverted Link Graph Privacy Bug (`note_preview_screen.dart:150-154, 167-169`):**
  - Author viewing their own public note in private workspace cannot see their own private linked trades.
  - **Action:** Fix `_isPublicViewer` logic.
