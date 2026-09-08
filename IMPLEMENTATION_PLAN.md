# Implementation Plan: Linked Strategies, Journal & Notes Redesign

## Overview
Redesign three core trading features with professional layouts, dynamic linking, responsive design (desktop/mobile), and guided onboarding flows.

---

## 1. Linked Strategies — Define Playbooks & Rules First

### Purpose
Users define their trading strategies, rules, entry/exit criteria, and risk parameters before executing trades.

### New File Structure
```
lib/features/strategies/
├── data/
│   ├── repositories/
│   │   └── strategy_repository.dart
│   └── sources/
│       └── strategy_data_source.dart
├── models/
│   ├── strategy_model.dart
│   ├── strategy_rule_model.dart
│   └── strategy_version_model.dart
├── presentation/
│   ├── pages/
│   │   ├── strategies_root_page.dart        # Main landing page
│   │   ├── strategy_detail_page.dart        # Single strategy view/edit
│   │   ├── strategy_create_page.dart        # Create new strategy
│   │   ├── strategy_rules_page.dart         # Define rules
│   │   └── strategy_versions_page.dart      # Version history
│   └── widgets/
│       ├── strategy_card.dart               # Redesigned card
│       ├── strategy_list.dart               # Grid/list toggle
│       ├── rule_builder.dart                # Rule definition UI
│       ├── strategy_guide_overlay.dart      # Onboarding guide
│       └── strategy_link_picker.dart        # Link to journal entries
└── strategies_feature.dart                  # Feature export
```

### Key Components
- **StrategyCard**: Compact card showing name, category, win rate, trade count, linked journal entries
- **StrategyListBlock**: Responsive grid (desktop) / stacked cards (mobile)
- **RuleBuilderWidget**: Visual rule builder for entry/exit conditions
- **StrategyGuideOverlay**: Step-by-step guide ("What to do first → last")
- **LinkPicker**: Dynamically link strategies to journal trades

### User Flow
1. **First-time user**: See empty state with "Create Strategy" CTA + Guide overlay
2. **Create Strategy**: Name → Category → Define Rules → Save
3. **Define Rules**: Entry conditions, Exit conditions, Risk parameters, Position sizing
4. **Link to Trades**: Select from existing journal or wait for new trades
5. **Review Performance**: View linked trades, win rate, P/L attribution

---

## 2. Linked Journal — Execute & Log Trades

### Purpose
Log trades that are linked to predefined strategies, capturing execution details and outcomes.

### New File Structure
```
lib/features/journal/
├── data/
│   ├── repositories/
│   │   └── journal_repository.dart
│   └── sources/
│       └── journal_data_source.dart
├── models/
│   ├── trade_model.dart
│   ├── trade_execution_model.dart
│   └── trade_tag_model.dart
├── presentation/
│   ├── pages/
│   │   ├── journal_root_page.dart           # Main landing page
│   │   ├── trade_log_page.dart              # Log new trade
│   │   ├── trade_detail_page.dart           # Single trade view
│   │   ├── trade_analysis_page.dart         # Performance analysis
│   │   └── trade_calendar_page.dart         # Calendar view
│   └── widgets/
│       ├── trade_card.dart                  # Redesigned compact card
│       ├── trade_table.dart                 # Desktop table view
│       ├── trade_filter_bar.dart            # Search + filters
│       ├── trade_guide_overlay.dart         # Onboarding guide
│       ├── strategy_linker.dart             # Link trade to strategy
│       └── pnl_summary_card.dart            # P/L summary widget
└── journal_feature.dart                     # Feature export
```

### Key Components
- **TradeCard**: Compact card with ticker, side, P/L, R-multiple, strategy link, tags
- **TradeTable**: Sortable table for desktop (ticker, side, entry, exit, R, P/L, date)
- **FilterBar**: Search, outcome filter (win/loss/open), date range, strategy filter
- **TradeGuideOverlay**: Guide ("Select strategy → Enter trade details → Add notes → Save")
- **StrategyLinker**: Dropdown/picker to link trade to existing strategy

### User Flow
1. **First-time user**: Empty state with "Log Trade" CTA + Guide overlay
2. **Pre-trade Checklist**: Confirm setup alignment (optional gate)
3. **Log Trade**: Select strategy → Enter ticker/side/entry → Set stop/target → Save
4. **Update Trade**: Add exit price → Auto-calculates P/L, R-multiple → Add notes/tags
5. **Review**: Filter by strategy/outcome → Analyze performance

---

## 3. Linked Notes — Review, Tag & Reflect

### Purpose
Capture lessons learned, tag patterns, and reflect on trading execution tied to strategies and trades.

### New File Structure
```
lib/features/notes/
├── data/
│   ├── repositories/
│   │   └── notes_repository.dart
│   └── sources/
│       └── notes_data_source.dart
├── models/
│   ├── note_model.dart
│   ├── note_tag_model.dart
│   └── note_link_model.dart
├── presentation/
│   ├── pages/
│   │   ├── notes_root_page.dart             # Main landing page
│   │   ├── note_create_page.dart            # Create/edit note
│   │   ├── note_detail_page.dart            # Single note view
│   │   ├── notes_review_page.dart           # Review session
│   │   └── tags_manage_page.dart            # Tag management
│   └── widgets/
│       ├── note_card.dart                   # Redesigned note card
│       ├── note_grid.dart                   # Masonry/grid layout
│       ├── note_filter_bar.dart             # Search + tag filters
│       ├── note_guide_overlay.dart          # Onboarding guide
│       ├── tag_cloud.dart                   # Visual tag cloud
│       ├── note_linker.dart                 # Link to trade/strategy
│       └── reflection_prompt.dart           # Guided reflection questions
└── notes_feature.dart                       # Feature export
```

### Key Components
- **NoteCard**: Title, body preview, linked trade/strategy, tags, date
- **NoteGrid**: Masonry layout (desktop) / stacked (mobile)
- **TagCloud**: Visual representation of most-used tags
- **NoteGuideOverlay**: Guide ("Write note → Link to trade/strategy → Tag → Reflect")
- **ReflectionPrompt**: Pre-built prompts ("What went well?", "What would I change?")

### User Flow
1. **First-time user**: Empty state with "Create Note" CTA + Guide overlay
2. **Create Note**: Write title/body → Link to trade or strategy → Add tags → Save
3. **Tag & Categorize**: Use existing tags or create new ones
4. **Review Sessions**: Filter by tag/date → Read notes → Identify patterns
5. **Reflect**: Use guided prompts for structured reflection

---

## 4. Dynamic Linking System

### Cross-Feature Links
- **Strategy → Journal**: Show all trades linked to this strategy
- **Journal → Strategy**: Click strategy name to view full strategy details
- **Journal → Notes**: Show notes linked to this trade
- **Notes → Journal/Strategy**: Click links to navigate to source

### Implementation
- Use IDs for linking (no hardcoded strings)
- Mock data repository provides linked data
- Navigation uses route parameters for deep linking

---

## 5. Reusable Widgets (Redesigned)

### Cards (Reduced Size, Professional)
- `CompactStrategyCard`: 40% smaller padding, cleaner typography
- `CompactTradeCard`: Dense layout, color-coded P/L
- `CompactNoteCard`: Card with tag pills, link chips

### Layout Blocks
- `ResponsiveGrid`: Auto-columns based on screen width
- `SplitPane`: Master-detail for desktop, stacked for mobile
- `StickyHeader`: Section headers that stick on scroll

### Guides
- `OnboardingGuideOverlay`: Modal with steps, progress indicator
- `TooltipGuide`: Contextual hints on first interaction
- `EmptyStateWithGuide`: CTA + mini-guide for empty states

---

## 6. Responsive Design Strategy

### Desktop (>1024px)
- Three-column layout for detail pages
- Table views for lists
- Side-by-side comparisons
- Persistent sidebar navigation

### Tablet (600px - 1024px)
- Two-column layout
- Hybrid list/card views
- Collapsible sidebars

### Mobile (<600px)
- Single-column stacked layout
- Card-based lists
- Bottom sheet for filters/actions
- Full-screen modals for detail views

---

## 7. Theme Consistency
- Maintain existing color palette from `AppTokens`
- Use `UiCard`, `UiButton`, `UiBadge` from flutter-ui
- Apply consistent spacing via `theme.spacing`
- Motion via `AppMotion` utilities

---

## 8. Files to Create/Modify

### Create (New Features)
1. `lib/features/strategies/` (full feature module)
2. `lib/features/journal/` (full feature module)
3. `lib/features/notes/` (full feature module)

### Modify (Existing)
1. `lib/core/app-ui/cards/strategy_cards.dart` → Redesign components
2. `lib/core/app-ui/cards/journal_cards.dart` → Redesign components
3. `lib/core/app-ui/blocks/journal_blocks.dart` → Add new blocks
4. `lib/core/navigation/role_navigation_config.dart` → Add new routes
5. `lib/core/widgets/app_scaffold.dart` → Wire up new pages
6. `lib/core/data/demo_data_source.dart` → Add mock data for notes

---

## 9. Testing & Validation
- Verify responsive breakpoints
- Test linking navigation (click strategy → see trades)
- Validate guide overlays appear on first visit
- Ensure empty states are helpful

---

## Phase 1 Execution Order
1. Create data models for all three features
2. Build reusable redesigned cards
3. Implement Strategies feature (foundation)
4. Implement Journal feature (links to strategies)
5. Implement Notes feature (links to both)
6. Wire up navigation in app_scaffold
7. Add guide overlays and empty states
8. Test responsive layouts
