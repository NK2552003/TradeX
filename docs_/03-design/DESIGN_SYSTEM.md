# Design System — TraderHub
## Color Palette, Typography, and Component Styles for UI/UX

Foundational visual language for TraderHub. Screens are specced separately per device: [SCREENS_MOBILE.md](./SCREENS_MOBILE.md), [SCREENS_TABLET.md](./SCREENS_TABLET.md), [SCREENS_DESKTOP.md](./SCREENS_DESKTOP.md). Navigation/deep-link behavior is in [DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md).

### 1. Brand Personality
Trust, clarity, discipline. TraderHub is a tool traders live in for hours — dense with numbers, charts, and journal text — so the system prioritizes **legibility and calm** over decoration. Data (P/L, prices, percentages) should never compete visually with chrome; color is reserved almost entirely for meaning (win/loss/alert/premium), not branding flourish.

### 2. Color Palette

**Dark mode is the default theme** (traders commonly work in low-light, chart-heavy sessions for extended periods); light mode is a supported alternative, not an afterthought.

#### Brand
| Token | Hex | Usage |
|---|---|---|
| `brand-primary` | `#4F46E5` (Indigo 600) | Primary actions, active nav state, links |
| `brand-primary-dark` | `#4338CA` (Indigo 700) | Primary button pressed state |
| `brand-secondary` | `#0EA5E9` (Sky 500) | Secondary accents, AI-feature highlights (ties AI Trading Assistant surfaces together) |

#### Semantic (trading-specific — do not repurpose for anything else)
| Token | Hex | Usage |
|---|---|---|
| `outcome-win` | `#16A34A` (Green 600) | Win outcome badge, positive P/L, equity curve upward segments |
| `outcome-loss` | `#DC2626` (Red 600) | Loss outcome badge, negative P/L, equity curve downward segments |
| `outcome-breakeven` | `#D97706` (Amber 600) | Breakeven outcome badge |
| `alert` | `#F59E0B` (Amber 500) | Price alert triggers, warning banners |
| `premium-accent` | `#EAB308` (Yellow 500, gold-leaning) | Premium tier badge, "Premium" locked-feature indicators, upgrade CTAs |
| `enterprise-accent` | `#7C3AED` (Violet 600) | Enterprise tier badge, Org Dashboard chrome |

Colorblind note: red/green is the single highest-risk pairing in this app (P/L is the core signal). `outcome-win`/`outcome-loss` must always be paired with a non-color cue — an up/down icon, a `+`/`−` sign, or badge text ("Win"/"Loss") — never color alone.

#### Neutrals — Dark mode
| Token | Hex | Usage |
|---|---|---|
| `bg-base` | `#0B0E14` | App background |
| `bg-surface` | `#151923` | Cards, sheets |
| `bg-surface-raised` | `#1E2430` | Modals, elevated cards |
| `border-subtle` | `#2A3140` | Dividers, card borders |
| `text-primary` | `#F5F6F8` | Primary text |
| `text-secondary` | `#9AA3B2` | Secondary/meta text (timestamps, labels) |
| `text-disabled` | `#5A6272` | Disabled text |

#### Neutrals — Light mode
| Token | Hex | Usage |
|---|---|---|
| `bg-base` | `#FFFFFF` | App background |
| `bg-surface` | `#F7F8FA` | Cards, sheets |
| `bg-surface-raised` | `#FFFFFF` (with shadow) | Modals, elevated cards |
| `border-subtle` | `#E2E5EA` | Dividers, card borders |
| `text-primary` | `#12151C` | Primary text |
| `text-secondary` | `#5A6272` | Secondary/meta text |
| `text-disabled` | `#B0B6C2` | Disabled text |

#### Charts (Portfolio Dashboard, Ticker Detail)
| Token | Hex | Usage |
|---|---|---|
| `chart-line-primary` | `brand-secondary` (`#0EA5E9`) | Equity curve line, indicator lines (SMA/MACD) |
| `chart-fill-positive` | `outcome-win` @ 20% opacity | Win/Loss Distribution positive bars, area fill under equity curve when net positive |
| `chart-fill-negative` | `outcome-loss` @ 20% opacity | Win/Loss Distribution negative bars, area fill when net negative |
| `chart-gridline` | `border-subtle` | Axis gridlines |

### 3. Typography
| Role | Font | Notes |
|---|---|---|
| UI / body text | Inter | Full app chrome, journal/strategy body text |
| Numeric data (prices, P/L, stats) | IBM Plex Mono (or Roboto Mono) | Tabular figures for aligned decimals — critical anywhere prices/P&L stack vertically (Journal List, Portfolio Dashboard stat cards, Watchlist rows) |
| Rich text editor content (Strategy Notes) | Inter | Matches body; headings within the editor use the same scale as below |

**Type scale:**
| Style | Size / Weight | Usage |
|---|---|---|
| Display | 28 / Bold | Portfolio Dashboard headline stat values |
| H1 | 22 / Semibold | Screen titles |
| H2 | 18 / Semibold | Section headers (card group titles) |
| Body | 15 / Regular | Default body text |
| Body Mono | 15 / Regular (mono) | Prices, P/L figures, stat values |
| Caption | 13 / Regular | Timestamps, meta text, helper text |
| Label | 12 / Medium, uppercase, letter-spaced | Badge text, tag chips |

### 4. Spacing & Grid
- Base unit: 4px. Standard spacing scale: 4 / 8 / 12 / 16 / 24 / 32 / 48
- Screen horizontal padding: 16px (mobile), 24px (tablet), 32px+ (desktop, capped content width ~1200px for readability)
- Card padding: 16px
- Minimum tap target: 44×44px (mobile/tablet)

### 5. Iconography
- Style: outline icons at rest, filled/duotone for active/selected state (nav tabs, favorited items)
- Recommended set: Lucide (or Phosphor) — both have full coverage for finance-app needs (trending-up/down, bell, star, chart icons)
- Outcome icons: up-arrow (win), down-arrow (loss), dash/tilde (breakeven) — always paired with `outcome-*` colors, never color-only (§ 2)
- Tier badges: small crown or star icon for Premium, building/org icon for Enterprise

### 6. Core Components

**Buttons**
| Variant | Style |
|---|---|
| Primary | Filled `brand-primary`, white text, 8px corner radius |
| Secondary | Outlined `border-subtle`, `text-primary` text |
| Destructive | Filled `outcome-loss`, white text — delete/remove actions only |
| Disabled | `text-disabled` on `bg-surface`, no interaction |
| Premium-locked | Secondary style + small lock icon + `premium-accent` accent border |

**Cards** — `bg-surface`, 12px corner radius, 1px `border-subtle` border, 16px padding. Elevated cards (modals, active states) use `bg-surface-raised` with a soft shadow (dark mode: shadow via lighter surface, not drop-shadow).

**Badges**
| Type | Style |
|---|---|
| Outcome (win/loss/breakeven) | Pill, `outcome-*` background @ 15% opacity, `outcome-*` text + icon |
| Tier (Free/Premium/Enterprise) | Pill, `premium-accent` or `enterprise-accent` outline |
| Content type (Community posts) | Pill, `bg-surface-raised` background, `text-secondary` text |
| Visibility (Private/Public on Strategy Notes) | Small icon only (lock / globe), no pill |

**Inputs** — `bg-surface` background, `border-subtle` border (1px), `brand-primary` border on focus, 8px corner radius, 44px min height.

**Charts** — see § 2 Charts table. All charts share consistent axis label typography (Caption style) and a single tooltip style (`bg-surface-raised`, Body Mono for values).

### 7. Accessibility
- Minimum contrast: 4.5:1 for body text, 3:1 for large text/icons, against both `bg-base` and `bg-surface` in both themes
- `outcome-win`/`outcome-loss` pairing verified for deuteranopia/protanopia — icon + text label required alongside color everywhere it appears (journal outcome badges, equity curve, Win/Loss Distribution chart legend)
- All interactive elements meet the 44×44px minimum tap target regardless of device

### 8. Breakpoints & Grid
| Breakpoint | Width | Columns | Gutter | Margin | Doc |
|---|---|---|---|---|---|
| Mobile | < 600px | 4 | 16px | 16px | [SCREENS_MOBILE.md](./SCREENS_MOBILE.md) |
| Tablet | 600–1200px | 8 | 20px | 24px | [SCREENS_TABLET.md](./SCREENS_TABLET.md) |
| Desktop | > 1200px | 12 (content capped ~1200px, centered) | 24px | 32px+ | [SCREENS_DESKTOP.md](./SCREENS_DESKTOP.md) |

Transition between breakpoints is layout-only (reflow, pane count, nav pattern) — component styling (§ 6), color (§ 2), and type scale (§ 3) do not change by breakpoint. Orientation change on mobile/tablet (portrait↔landscape) re-evaluates against this same table using the new width, not a separate ruleset.

### 9. Motion & Transitions
| Token | Duration | Easing | Usage |
|---|---|---|---|
| `motion-instant` | 100ms | linear | Toggle switches, checkbox states |
| `motion-fast` | 150ms | ease-out | Button press feedback, chip selection |
| `motion-standard` | 250ms | ease-in-out | Screen push/pop, tab switch, card expand/collapse |
| `motion-modal` | 300ms | ease-out (enter) / ease-in (exit) | Bottom sheet slide-up, dialog fade+scale-in |
| `motion-chart` | 400ms | ease-in-out | Chart data transitions (e.g. switching Weekly↔Monthly on Portfolio Dashboard) |

**Screen transition patterns** (mobile/tablet): push new screens slide in from the right, pop slides out to the right (platform-native — do not override iOS's native back-swipe feel). Bottom sheets slide up from the bottom edge and dim the backdrop. Desktop dialogs fade+scale from 96%→100% rather than sliding (no "edge" to slide from in a windowed context).

**Loading:** skeleton placeholders (§ Cross-cutting states, SCREENS_MOBILE.md) use a subtle shimmer sweep, `motion-standard` duration, looping — never a spinner as the primary loading indicator except the very first cold-launch splash frame.

**Reduced motion:** respect OS-level "reduce motion" settings — fall back to simple opacity crossfades (`motion-fast`) in place of slide/scale transitions everywhere in this section.

### 10. Elevation & Shadow Scale
| Level | Usage | Dark mode treatment | Light mode treatment |
|---|---|---|---|
| 0 | Base screen background | `bg-base` | `bg-base` |
| 1 | Cards, list rows | `bg-surface`, no shadow | `bg-surface`, no shadow |
| 2 | Raised cards, active/selected card state | `bg-surface-raised`, no shadow (lighter fill reads as "raised" in dark mode) | `bg-surface-raised` + shadow `0 1px 3px rgba(0,0,0,0.08)` |
| 3 | Bottom sheets, popovers | `bg-surface-raised` + 1px top border `border-subtle` (sheets), shadow `0 -2px 8px rgba(0,0,0,0.24)` | Same shadow, no border needed |
| 4 | Modals/dialogs, toasts | `bg-surface-raised` + shadow `0 8px 24px rgba(0,0,0,0.32)` | shadow `0 8px 24px rgba(0,0,0,0.12)` |

Dark mode leans on surface-color steps rather than heavy shadows (shadows barely read against near-black backgrounds); light mode leans on shadow since surface steps are subtler there.

### 11. Component States
Beyond the default/disabled states already in § 6:

| Component | Hover (desktop only) | Focus (keyboard/a11y) | Pressed/Active |
|---|---|---|---|
| Buttons (all variants) | Background darkens ~8% | 2px `brand-primary` outline, 2px offset | Background darkens ~16%, scale 98% (`motion-fast`) |
| Inputs | Border → `text-secondary` | Border → `brand-primary` (2px) | — (focus state persists while typing) |
| Cards (journal/strategy/post/watchlist rows) | Elevate to Level 2 (§ 10), border → `brand-primary` @ 40% | 2px `brand-primary` outline | Background → `bg-surface-raised` briefly on tap (`motion-fast`) |
| List rows (Followers, Notification Center, Team Management) | Background → `bg-surface-raised` | 2px inset `brand-primary` outline | Background darkens briefly |
| Chips/Tags (filters, categories) | Border → `brand-primary` | 2px `brand-primary` outline | Fill toggles to selected state |
| Nav items (sidebar/rail/tab bar) | Background → `bg-surface` (desktop/tablet only) | 2px `brand-primary` outline | Active state uses filled icon variant (§ 5), not a pressed-flash |

Hover only applies where a real pointer exists (desktop, and tablet with a trackpad/mouse) — mobile touch has no hover state; pressed/active is the only additional state beyond default there.

### 12. Illustration Style Direction
No illustration assets exist yet — this is direction for whoever produces them (designer or an image-generation pass), not artwork itself.
- **Style:** simple line-art / duotone (two-tone using `brand-primary` + a neutral), flat — no photorealism, no busy detail. Matches the "calm, data-first" brand personality (§ 1).
- **Where illustrations appear:** empty states (Journal List, Strategy List, Watchlist List, Community Feed, Notification Center, Saved Posts — see SCREENS_MOBILE.md cross-cutting states), Splash/Onboarding carousel (5 slides, one per pillar), the Free-tier Strategy Notes locked state.
- **Tone:** illustrative, not cartoonish — this is a tool for serious financial record-keeping; avoid mascot characters or overly playful shapes.
- **Sizing:** empty-state illustrations ~120×120px (mobile), scale proportionally on tablet/desktop; onboarding illustrations full-bleed within their carousel slide.

### 13. Chart Spec Detail
Applies to Equity Curve, Monthly Growth, and Win/Loss Distribution (Portfolio Dashboard) and price/indicator charts (Ticker Detail):
- **Number formatting:** currency values abbreviate above $10,000 (`$12.4K`, `$1.2M`); below that, full value with 2 decimals (`$1,234.56`). Percentages always 1 decimal (`64.3%`). Never abbreviate in tooltips — tooltips always show the full precise value even if the axis label is abbreviated.
- **Date formatting:** axis labels adapt to range — day-of-month only for a single month view (`12`, `19`, `26`), abbreviated month for a year view (`Jan`, `Feb`).
- **Tooltip content:** on hover (desktop, § 11) or tap-and-hold (mobile/tablet) — shows the exact date, exact value (Body Mono style, § 3), and for Equity Curve additionally shows the day's individual trade count.
- **Empty/insufficient-data state:** fewer than 5 journal entries with `pnl` set → charts render a muted placeholder curve/bars with a centered message ("Log a few more trades to see your equity curve") rather than a misleadingly sparse real chart.
- **Color mapping:** reuses `chart-*` tokens from § 2 exactly — no chart introduces a new color outside that token set.

### 14. App Icon & Splash Assets
Specification only — actual artwork production is outside this doc's scope.
| Asset | Requirement |
|---|---|
| iOS App Icon | 1024×1024px source, no transparency, no rounded corners pre-applied (iOS masks automatically) |
| Android Adaptive Icon | Separate foreground (432×432px, safe zone centered 264×264px) and background layers |
| Web Favicon | 512×512px source, exported to standard favicon sizes (16/32/48/180/192/512) |
| Splash screen | Logo mark centered on `bg-base` (dark) — no separate splash illustration; keep it minimal since it's on-screen for milliseconds |
| Notification icon (Android) | Monochrome, transparent background, per Android's status-bar icon requirements |

Icon mark should be a simplified/monochrome-friendly version of the full wordmark logo (§ 1) — legible at 16px favicon size, which the full wordmark is not.

