# Implementation Plan: Redesign of Linked Strategies, Journal & Notes

## Executive Summary

This document outlines the complete redesign of three core features:
1. **Linked Strategies** — Where you define your playbooks and rules first
2. **Linked Journal** — Where you execute and log the trades based on those strategies
3. **Linked Notes** — Where you review, tag, and reflect on the execution

The redesign focuses on:
- Professional, consistent UI components across all three features
- Proper desktop and mobile layouts (responsive, not just overlay)
- Dynamic linking between all three features (nothing hardcoded)
- Simplified user flow with clear guidance
- Reduced block sizes and improved component density
- Onboarding guides for each feature

---

## 1. Current State Analysis

### 1.1 Existing Structure

**Strategies Feature:**
- Location: `/workspace/lib/features/strategies/`
- Main screens: `strategies_screen.dart`, `strategy_detail_screen.dart`, `strategy_editor_screen.dart`
- Blocks: `strategy_note_blocks.dart` (1271 lines), `strategy_cards.dart`
- Repository: `strategies_repository.dart`

**Journal Feature:**
- Location: `/workspace/lib/features/journal/`
- Main screens: `journal_screen.dart`, `journal_entry_screen.dart`, `journal_editor_screen.dart`
- Blocks: `journal_note_blocks.dart` (1107 lines), `journal_cards.dart`
- Repository: `journal_repository.dart`

**Notes Feature:**
- Location: `/workspace/lib/features/notes/`
- Main screens: `notes_screen.dart`, `note_preview_screen.dart`, `note_editor_screen.dart`
- Blocks: `notes_blocks.dart` (631 lines), `notes_cards.dart`
- Repository: `notes_repository.dart`

### 1.2 Key Issues to Address

1. **Complex Working**: The current flow has too many states and surfaces
2. **Layout Consistency**: Desktop and mobile layouts need proper differentiation
3. **Component Sizes**: Cards and blocks are too large, need reduction
4. **User Guidance**: No onboarding or "what to do first" guides
5. **Dynamic Linking**: Links between features need to be fully dynamic
6. **Professional Layout**: Components should feel properly positioned, not broken

---

## 2. Design Principles

### 2.1 User Flow Simplification

**Current Flow (Too Complex):**
```
List → Document → Editor → Back to List
       ↓
    Multiple views, states, and transitions
```

**New Flow (Simplified):**
```
Landing Page (with Guide) → List/Grid → Detail/Edit
     ↓
  Clear entry point with "Get Started" guidance
```

### 2.2 Responsive Layout Strategy

**Desktop (≥1024px):**
- Three-column layout where applicable
- Permanent sidebar for navigation
- Expanded content area with proper spacing
- Multi-panel workbench view

**Tablet (768px - 1023px):**
- Two-column layout
- Collapsible sidebar
- Adaptive card grids (2 columns)

**Mobile (<768px):**
- Single column layout
- Bottom navigation or hamburger menu
- Full-width cards
- Stacked components

### 2.3 Component Density

**Current → New:**
- Card heights: Reduce by 20-30%
- Spacing: Use tighter spacing tokens (sm → xs where appropriate)
- Font sizes: Slightly reduced for density
- Icon sizes: Consistent 16-20px range
- Padding: Compact variants for dense views

---

## 3. Implementation Phases

### Phase 1: Core UI Components (Week 1)

#### 3.1.1 Create Reusable Widget Library

**File: `/workspace/lib/core/app-ui/components/`**

Create these new reusable components:

1. **`app_feature_header.dart`**
   - Unified header component for all three features
   - Contains: eyebrow, title, description, CTA button
   - Responsive: stacked on mobile, horizontal on desktop

2. **`app_stat_strip_compact.dart`**
   - Compact version of stat strips
   - 20% smaller than current implementation
   - Supports 2-6 metrics
   - Responsive grid (2 cols mobile, 4 cols desktop)

3. **`app_filter_bar_collapsible.dart`**
   - Collapsible filter bar
   - Auto-collapse on mobile
   - Persistent on desktop
   - Supports: search, dropdowns, toggles, tags

4. **`app_card_grid_responsive.dart`**
   - Auto-layout grid for cards
   - Configurable columns per breakpoint
   - Built-in pagination support
   - Empty state handling

5. **`app_guide_overlay.dart`**
   - Non-intrusive guide overlay
   - Step-by-step walkthrough
   - Dismissible with "Don't show again"
   - Re-accessible from help icon

6. **`app_link_chips.dart`**
   - Dynamic link display chips
   - Shows linked items count
   - Tap to navigate or unlink
   - Color-coded by kind (strategy/journal/note)

7. **`app_empty_state_guide.dart`**
   - Empty state with guidance
   - "What to do first" messaging
   - CTA buttons for common actions
   - Illustrations optional

8. **`app_detail_layout.dart`**
   - Unified detail page layout
   - Header + content + sidebar structure
   - Responsive sidebar (drawer on mobile)
   - Breadcrumb navigation

#### 3.1.2 Update Theme Tokens

**File: `/workspace/lib/core/app-ui/theme/app_tokens.dart`**

Add new spacing and size tokens:
```dart
// Compact spacing for denser layouts
static const double spacingXxs = 4.0;
static const double spacingCompact = 12.0;

// Reduced card dimensions
static const double cardHeightCompact = 120.0;
static const double cardHeightStandard = 160.0;

// Responsive breakpoints
static const double breakpointMobile = 768.0;
static const double breakpointTablet = 1024.0;
```

---

### Phase 2: Landing Pages Redesign (Week 2)

#### 3.2.1 Strategies Landing Page

**File: `/workspace/lib/features/strategies/ui/strategies_landing_page.dart`**

**Structure:**
```
┌─────────────────────────────────────────────────────┐
│  [AppFeatureHeader]                                  │
│  Eyebrow: "Where you define your playbooks"         │
│  Title: "Linked Strategies"                          │
│  Description: "Define rules first, trade later"      │
│  CTA: [+ New Playbook] [📖 View Guide]              │
├─────────────────────────────────────────────────────┤
│  [AppStatStripCompact]                               │
│  Total | Live | Testing | Win Rate | Net P/L        │
├─────────────────────────────────────────────────────┤
│  [AppFilterBarCollapsible]                           │
│  Search | Status | Tag | Ticker | Sort              │
├─────────────────────────────────────────────────────┤
│  [AppCardGridResponsive]                             │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐               │
│  │ Card │ │ Card │ │ Card │ │ Card │               │
│  └──────┘ └──────┘ └──────┘ └──────┘               │
└─────────────────────────────────────────────────────┘
```

**Features:**
- First-time user sees guide overlay
- Empty state shows "Create your first playbook" with template gallery
- Cards show: name, status badge, trade count, win rate, linked notes count
- Quick actions: favorite, edit, delete (on hover for desktop)

#### 3.2.2 Journal Landing Page

**File: `/workspace/lib/features/journal/ui/journal_landing_page.dart`**

**Structure:**
```
┌─────────────────────────────────────────────────────┐
│  [AppFeatureHeader]                                  │
│  Eyebrow: "Your trading practice"                   │
│  Title: "Linked Journal"                             │
│  Description: "Capture decisions, learn outcomes"   │
│  CTA: [+ Log Trade] [📖 View Guide]                 │
├─────────────────────────────────────────────────────┤
│  [AppStatStripCompact]                               │
│  Total | Open | Win Rate | Net P/L | Avg R          │
├─────────────────────────────────────────────────────┤
│  [EquityCurveSpark] (compact, 48px height)          │
├─────────────────────────────────────────────────────┤
│  [AppFilterBarCollapsible]                           │
│  Search | Outcome | Tag | Ticker | Sort             │
├─────────────────────────────────────────────────────┤
│  [AppCardGridResponsive]                             │
│  Grouped by month (optional toggle)                 │
└─────────────────────────────────────────────────────┘
```

**Features:**
- Guide explains: "Log a trade → Link to strategy → Add notes"
- Empty state: "No trades yet" with quick import options
- Cards show: ticker, side, P/L, R-multiple, strategy link, notes count
- Month grouping toggle for chronological views

#### 3.2.3 Notes Landing Page

**File: `/workspace/lib/features/notes/ui/notes_landing_page.dart`**

**Structure:**
```
┌─────────────────────────────────────────────────────┐
│  [AppFeatureHeader]                                  │
│  Eyebrow: "The research notebook"                   │
│  Title: "Linked Notes"                               │
│  Description: "Ideas, observations, connections"    │
│  CTA: [+ New Note] [📖 View Guide]                  │
├─────────────────────────────────────────────────────┤
│  [AppStatStripCompact]                               │
│  Total | This Week | Public | Words                 │
├─────────────────────────────────────────────────────┤
│  [UiTabs]                                            │
│  [My Notes] [Trade Reviews] [Playbooks]             │
├─────────────────────────────────────────────────────┤
│  [AppFilterBarCollapsible]                           │
│  Search | Type | Tag | Sort                         │
├─────────────────────────────────────────────────────┤
│  [AppCardGridResponsive]                             │
│  Density toggle: Comfortable | Compact              │
└─────────────────────────────────────────────────────┘
```

**Features:**
- Guide explains: "Write note → Link trades/strategies → Tag & organize"
- Tab switching between notes and linked writing views
- Cards show: type indicator, title, preview, linked items, tags
- Density toggle for compact/comfortable views

---

### Phase 3: Detail Pages Redesign (Week 3)

#### 3.3.1 Strategy Detail Page

**File: `/workspace/lib/features/strategies/ui/strategy_detail_redesigned.dart`**

**Desktop Layout (3-column):**
```
┌──────────────┬─────────────────────────┬──────────────┐
│ [Back]       │  Strategy Name         │ [Edit]       │
│              │  Status • Category     │ [Favorite]   │
├──────────────┤                         ├──────────────┤
│ Navigation   │  Content Area          │ Linked Items │
│ • Overview   │  (Markdown render)     │              │
│ • Rules      │                        │ Trades (12)  │
│ • Performance│                        │ ┌──────────┐ │
│ • Versions   │  [Performance Stats]   │ │ Trade 1  │ │
│              │  Win Rate | Net P/L    │ │ Trade 2  │ │
│              │  Equity Curve          │ └──────────┘ │
│              │                        │ Notes (3)    │
│              │                        │ ┌──────────┐ │
│              │                        │ │ Note 1   │ │
│              │                        │ └──────────┘ │
└──────────────┴─────────────────────────┴──────────────┘
```

**Mobile Layout (stacked):**
```
┌─────────────────────────────────────┐
│ [← Back]            [Edit] [⋮ More] │
│                                     │
│  Strategy Name                      │
│  Status • Category                  │
├─────────────────────────────────────┤
│ [Performance Stats - 2x2 grid]      │
├─────────────────────────────────────┤
│ [Tab Bar: Overview|Rules|Trades]   │
├─────────────────────────────────────┤
│ Content Area                        │
│ (scrollable)                        │
└─────────────────────────────────────┘
```

#### 3.3.2 Journal Entry Detail Page

**File: `/workspace/lib/features/journal/ui/journal_entry_redesigned.dart`**

**Key Features:**
- Pre-trade checklist (if present)
- Trade details (entry, exit, size, P/L)
- Psychology score indicator
- Linked strategy chip
- Linked notes section
- Chart screenshots gallery
- Edit history timeline

#### 3.3.3 Note Detail Page

**File: `/workspace/lib/features/notes/ui/note_detail_redesigned.dart`**

**Key Features:**
- Markdown renderer with syntax highlighting
- Linked trades section (clickable chips)
- Linked strategies section
- Tags management
- Comments section (for public notes)
- Engagement stats (views, likes)

---

### Phase 4: Editor Pages Redesign (Week 4)

#### 3.4.1 Unified Editor Patterns

All three editors follow the same pattern:

**Desktop:**
```
┌─────────────────────────────────────────────────────┐
│ [← Cancel]  [Document Title]      [Save] [Publish]  │
├─────────────────────────────────────────────────────┤
│ ┌─────────────────┐ ┌─────────────────────────────┐ │
│ │ Table of        │ │                             │ │
│ │ Contents        │ │  Main Editing Area          │ │
│ │                 │ │  (Markdown or Form)         │ │
│ │ Sections list   │ │                             │ │
│ │ Jump links      │ │                             │ │
│ └─────────────────┘ └─────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ [Link Picker]  [Tag Input]  [Attachment Upload]     │
└─────────────────────────────────────────────────────┘
```

**Mobile:**
```
┌─────────────────────────────────────┐
│ [←]  [Title]           [Save] [⋮]  │
├─────────────────────────────────────┤
│ [Toolbar: Bold|Italic|Link|...]    │
├─────────────────────────────────────┤
│                                     │
│  Full-width editing area            │
│                                     │
├─────────────────────────────────────┤
│ [Bottom Sheet: Links|Tags|Files]   │
└─────────────────────────────────────┘
```

#### 3.4.2 Strategy Editor

**File: `/workspace/lib/features/strategies/ui/strategy_editor_redesigned.dart`**

**Sections (guided):**
1. Name & Category (required)
2. Entry Rules (markdown, guided prompts)
3. Invalidation Conditions (markdown)
4. Stop Loss Rules (markdown)
5. Position Sizing (markdown)
6. Exit Strategy (markdown)
7. Tags & Instruments

**Guidance Features:**
- Template snippets for each section
- Example text toggle
- Validation warnings (empty required sections)
- Auto-save with version notes

#### 3.4.3 Journal Editor

**File: `/workspace/lib/features/journal/ui/journal_editor_redesigned.dart`**

**Form Fields:**
- Ticker (autocomplete)
- Side (Long/Short toggle)
- Entry Price, Exit Price, Size
- P/L (auto-calculated)
- R-Multiple (auto-calculated)
- Strategy (dropdown from user's strategies)
- Psychology Score (1-10 slider)
- Pre/Post Trade Checklists
- Notes (markdown)
- Screenshots (drag-drop upload)

**Smart Features:**
- Screenshot AI parsing (optional)
- Strategy suggestion based on tags
- Auto-calculate fields

#### 3.4.4 Note Editor

**File: `/workspace/lib/features/notes/ui/note_editor_redesigned.dart`**

**Features:**
- Rich markdown editor
- AI refactor toolbar
- Link picker for trades/strategies
- Tag autocomplete
- Attachment upload
- Checklist builder
- Word count and reading time

---

### Phase 5: Dynamic Linking System (Week 5)

#### 3.5.1 Link Graph Service Enhancement

**File: `/workspace/lib/features/linking/link_graph_service.dart`**

Ensure all links are:
- Bidirectional (source knows target, target knows source)
- Resilient (tolerate missing records gracefully)
- Type-safe (AppLinkRef with kind validation)
- Performant (cached, batch updates)

#### 3.5.2 Link Picker Component

**File: `/workspace/lib/core/app-ui/components/app_link_picker.dart`**

A unified picker for all three features:
- Search across available items
- Filter by kind (strategy/journal/note)
- Recent items quick-select
- Create-new option if nothing found
- Multi-select support

#### 3.5.3 Link Display Components

**File: `/workspace/lib/core/app-ui/components/app_link_display.dart`**

Shows linked items with:
- Count badges
- Preview chips (first 3 items)
- "+N more" overflow indicator
- Tap to navigate
- Long-press to unlink (with confirmation)

---

### Phase 6: User Guides & Onboarding (Week 6)

#### 3.6.1 Guide Content Structure

Each feature gets a comprehensive guide:

**Strategies Guide:**
```
Step 1: Why playbooks matter
  - "Define your edge before risking capital"
  
Step 2: Choose a template or start blank
  - Show template gallery
  - Explain each template type
  
Step 3: Fill in the rules
  - Entry conditions (be specific)
  - Invalidation (when to stand down)
  - Stop loss (protect capital)
  - Sizing (risk per trade)
  - Exit (take profits)
  
Step 4: Test it
  - Mark as "Testing" status
  - Log trades under it
  - Review performance
  
Step 5: Go live or iterate
  - Promote to "Live" when ready
  - Or revise based on results
  
Step 6: Review and refine
  - Check win rate and P/L
  - Read linked notes
  - Update playbook
```

**Journal Guide:**
```
Step 1: Log the trade
  - Enter ticker, side, prices
  - Or import from screenshot
  
Step 2: Link to strategy
  - Select which playbook you followed
  - Or mark as "discretionary"
  
Step 3: Add context
  - Pre-trade checklist
  - Psychology score
  - What you were thinking
  
Step 4: Review outcome
  - P/L auto-calculated
  - R-multiple tells the story
  - Add lessons learned
  
Step 5: Connect to notes
  - Link relevant trader notes
  - Tag for future reference
  
Step 6: Learn patterns
  - Review your equity curve
  - Find repeating mistakes
  - Celebrate wins
```

**Notes Guide:**
```
Step 1: Choose your purpose
  - Analysis: market breakdown
  - Plan: what you'll do
  - Review: what happened
  - Idea: something to explore
  - Cheat sheet: quick reference
  
Step 2: Write freely
  - Markdown formatting
  - Add charts/screenshots
  - Use checklists
  
Step 3: Link everything
  - Connect to trades
  - File under playbooks
  - Cross-reference other notes
  
Step 4: Tag and organize
  - Add topic tags
  - Link tickers
  - Keep it findable
  
Step 5: Share or keep private
  - Publish for community
  - Or keep personal
  - Control visibility
  
Step 6: Revisit and refine
  - Update as markets change
  - Track your evolution
  - Build your library
```

#### 3.6.2 Guide Implementation

**File: `/workspace/lib/core/app-ui/components/app_feature_guide.dart`**

Features:
- Carousel-style step-through
- Progress indicator
- Skip/Dismiss options
- "Don't show again" persistence
- Re-accessible via Help icon
- Contextual (shows relevant steps based on state)

---

## 4. File Structure Changes

### 4.1 New Directory Structure

```
/workspace/lib/
├── core/
│   └── app-ui/
│       ├── components/          # NEW: Reusable components
│       │   ├── app_feature_header.dart
│       │   ├── app_stat_strip_compact.dart
│       │   ├── app_filter_bar_collapsible.dart
│       │   ├── app_card_grid_responsive.dart
│       │   ├── app_guide_overlay.dart
│       │   ├── app_link_chips.dart
│       │   ├── app_empty_state_guide.dart
│       │   ├── app_detail_layout.dart
│       │   ├── app_link_picker.dart
│       │   ├── app_link_display.dart
│       │   └── app_feature_guide.dart
│       ├── blocks/
│       │   ├── strategy_blocks_redesigned.dart   # NEW
│       │   ├── journal_blocks_redesigned.dart    # NEW
│       │   └── notes_blocks_redesigned.dart      # NEW
│       └── cards/
│           ├── strategy_card_compact.dart        # NEW
│           ├── journal_card_compact.dart         # NEW
│           └── notes_card_compact.dart           # NEW
│
└── features/
    ├── strategies/
    │   └── ui/
    │       ├── strategies_landing_page.dart      # NEW
    │       ├── strategy_detail_redesigned.dart   # NEW
    │       ├── strategy_editor_redesigned.dart   # NEW
    │       └── strategies_guide.dart             # NEW
    │
    ├── journal/
    │   └── ui/
    │       ├── journal_landing_page.dart         # NEW
    │       ├── journal_entry_redesigned.dart     # NEW
    │       ├── journal_editor_redesigned.dart    # NEW
    │       └── journal_guide.dart                # NEW
    │
    └── notes/
        └── ui/
            ├── notes_landing_page.dart           # NEW
            ├── note_detail_redesigned.dart       # NEW
            ├── note_editor_redesigned.dart       # NEW
            └── notes_guide.dart                  # NEW
```

### 4.2 Deprecation Strategy

Old files remain during transition:
- Mark old components with `@Deprecated('Use new component instead')`
- Gradual migration over 2 sprints
- Remove old files after full migration

---

## 5. Technical Requirements

### 5.1 State Management

- Continue using existing repository pattern
- No new state management libraries
- Streams for real-time updates preserved
- Optimistic updates for better UX

### 5.2 Performance Targets

- Initial load: < 500ms
- Card render: < 50ms each
- Navigation: < 200ms
- Link resolution: cached, < 100ms

### 5.3 Accessibility

- All interactive elements: 44x44px minimum touch target
- Color contrast: WCAG AA compliant
- Screen reader labels on all cards
- Keyboard navigation support (desktop)

### 5.4 Testing Strategy

- Unit tests for new components
- Widget tests for layouts
- Integration tests for flows
- Manual testing on 3 device sizes

---

## 6. Success Metrics

### 6.1 User Experience

- Time to first action reduced by 40%
- Guide completion rate > 60%
- User errors reduced by 50%
- Session duration increased by 20%

### 6.2 Technical

- Bundle size increase < 5%
- No regression in Lighthouse scores
- All existing tests passing
- Code coverage > 80% for new files

### 6.3 Adoption

- 80% of users complete onboarding guide
- 60% increase in linked items (strategies↔journal↔notes)
- 40% increase in feature usage frequency

---

## 7. Rollout Plan

### Week 1-2: Foundation
- Create reusable components
- Update theme tokens
- Set up new file structure

### Week 3-4: Landing Pages
- Implement redesigned landing pages
- A/B test with small user group
- Gather feedback

### Week 5-6: Detail & Editor Pages
- Complete detail page redesigns
- Implement editor improvements
- Integrate dynamic linking

### Week 7-8: Guides & Polish
- Write and implement all guides
- Final QA pass
- Performance optimization
- Documentation

### Week 9: Launch
- Deploy to production
- Monitor metrics
- Hotfix any critical issues

---

## 8. Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Scope creep | High | Strict adherence to this plan |
| Performance regression | Medium | Continuous profiling |
| User confusion | Medium | Clear migration path, tooltips |
| Breaking changes | High | Backward compatibility layer |
| Timeline slip | Medium | Prioritize core features first |

---

## 9. Next Steps

1. **Review this plan** with stakeholders
2. **Create tickets** for each phase
3. **Set up branches** for parallel work
4. **Begin Phase 1** immediately

---

## Appendix A: Mock Data Sources

All data comes from existing repositories:
- `StrategiesRepository.watchAll()`
- `JournalRepository.watchAll()`
- `NotesRepository.watchAll()`
- `AppLinkGraphService.watch()`

No hardcoded data. All displays are reactive to repository changes.

## Appendix B: Design Tokens Reference

See `/workspace/lib/core/app-ui/theme/app_tokens.dart` for:
- Colors
- Spacing
- Typography
- Radii
- Shadows
- Motion

## Appendix C: Existing Components to Reuse

- `UiCard`, `UiButton`, `UiBadge`
- `UiPage`, `UiTabs`, `UiSkeleton`
- `AppHoverLift`, `AppCountUp`
- `UiDialog`, `UiToast`
- All from `/workspace/lib/core/flutter-ui/`
