# TradeX design system
## Color palette, typography, and component styles

This document defines the visual standards for TradeX. Device-specific screen layouts live in [SCREENS_MOBILE.md](./SCREENS_MOBILE.md), [SCREENS_TABLET.md](./SCREENS_TABLET.md), and [SCREENS_DESKTOP.md](./SCREENS_DESKTOP.md). Route paths and deep linking rules live in [DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md).

### 1. Brand personality
Traders spend hours inside TradeX reading dense tables, charts, and journal entries. The interface favors clear legibility over visual flair. Core data like profit and loss, prices, and percentages should stand out immediately without competing with UI chrome. Color carries functional meaning (outcomes, alerts, and account tiers) rather than decorative branding.

### 2. Color palette

Dark mode is the default theme because traders typically work in low-light environments during long charting sessions. Light mode is fully supported as an alternate theme.

#### Brand
| Token | Hex | Usage |
|---|---|---|
| `brand-primary` | `#4F46E5` (Indigo 600) | Primary actions, active navigation states, links |
| `brand-primary-dark` | `#4338CA` (Indigo 700) | Primary button pressed state |
| `brand-secondary` | `#0EA5E9` (Sky 500) | Secondary accents and AI trading assistant highlights |

#### Semantic colors (trading specific)
Do not repurpose these tokens for general UI accents.

| Token | Hex | Usage |
|---|---|---|
| `outcome-win` | `#16A34A` (Green 600) | Win outcome badges, positive profit/loss, upward equity curve lines |
| `outcome-loss` | `#DC2626` (Red 600) | Loss outcome badges, negative profit/loss, downward equity curve lines |
| `outcome-breakeven` | `#D97706` (Amber 600) | Breakeven outcome badge |
| `alert` | `#F59E0B` (Amber 500) | Price alert triggers, warning banners |
| `premium-accent` | `#EAB308` (Yellow 500, gold) | Premium tier badges, locked feature indicators, upgrade prompts |
| `enterprise-accent` | `#7C3AED` (Violet 600) | Enterprise tier badges, organization dashboard chrome |

Accessibility note for color vision: red and green are high risk for colorblind users, yet profit and loss is the core signal in the product. Always pair `outcome-win` and `outcome-loss` with a non-color indicator: an arrow icon, a plus or minus sign, or explicit text like "Win" or "Loss". Never rely on color alone.

#### Dark mode neutrals
| Token | Hex | Usage |
|---|---|---|
| `bg-base` | `#0B0E14` | App background |
| `bg-surface` | `#151923` | Cards, sheets |
| `bg-surface-raised` | `#1E2430` | Modals, elevated cards |
| `border-subtle` | `#2A3140` | Dividers, card borders |
| `text-primary` | `#F5F6F8` | Primary text |
| `text-secondary` | `#9AA3B2` | Secondary and metadata text (timestamps, labels) |
| `text-disabled` | `#5A6272` | Disabled text |

#### Light mode neutrals
| Token | Hex | Usage |
|---|---|---|
| `bg-base` | `#FFFFFF` | App background |
| `bg-surface` | `#F7F8FA` | Cards, sheets |
| `bg-surface-raised` | `#FFFFFF` (with shadow) | Modals, elevated cards |
| `border-subtle` | `#E2E5EA` | Dividers, card borders |
| `text-primary` | `#12151C` | Primary text |
| `text-secondary` | `#5A6272` | Secondary and metadata text |
| `text-disabled` | `#B0B6C2` | Disabled text |

#### Chart colors
Used in portfolio dashboards and ticker detail views.

| Token | Hex | Usage |
|---|---|---|
| `chart-line-primary` | `brand-secondary` (`#0EA5E9`) | Equity curve line, indicator lines (SMA, MACD) |
| `chart-fill-positive` | `outcome-win` at 20% opacity | Positive bars in win/loss distribution, positive equity fill |
| `chart-fill-negative` | `outcome-loss` at 20% opacity | Negative bars in win/loss distribution, negative equity fill |
| `chart-gridline` | `border-subtle` | Axis gridlines |

### 3. Typography

| Role | Font | Notes |
|---|---|---|
| UI and body text | Inter | Application chrome, journal entries, and strategy copy |
| Numeric figures (prices, P/L, statistics) | IBM Plex Mono (or Roboto Mono) | Tabular figures to keep decimals aligned when values stack vertically |
| Rich text editor (Strategy notes) | Inter | Matches body text; headings use the scale below |

#### Type scale
| Style | Size / weight | Usage |
|---|---|---|
| Display | 28 / Bold | Primary portfolio stat figures |
| H1 | 22 / Semibold | Main screen titles |
| H2 | 18 / Semibold | Section headers and card group titles |
| Body | 15 / Regular | Standard interface text |
| Body Mono | 15 / Regular (mono) | Prices, profit and loss numbers, stat values |
| Caption | 13 / Regular | Timestamps, secondary labels, helper copy |
| Label | 12 / Medium (uppercase, tracked) | Badges and tag chips |

### 4. Spacing and grid
- Base unit: 4px. Standard scale: 4, 8, 12, 16, 24, 32, and 48px.
- Screen horizontal margins: 16px on mobile, 24px on tablet, and 32px or more on desktop (max content width centered at 1200px).
- Card padding: 16px.
- Minimum tap target: 44x44px on mobile and tablet.

### 5. Iconography
- Style: outline icons at rest, filled or duotone icons for active and selected states (navigation tabs, saved items).
- Icon set: Lucide or Phosphor. Both include financial icons such as trend lines, bells, stars, and chart indicators.
- Outcome indicators: up arrow for wins, down arrow for losses, and a horizontal dash for breakeven trades. Always display these alongside the corresponding semantic color tokens.
- Tier indicators: crown or star icon for Premium, building or organization icon for Enterprise.

### 6. Core components

#### Buttons
| Variant | Visual style |
|---|---|
| Primary | Filled `brand-primary`, white text, 8px corner radius |
| Secondary | Outlined with `border-subtle`, `text-primary` text |
| Destructive | Filled `outcome-loss`, white text (reserved strictly for delete or remove actions) |
| Disabled | `text-disabled` text on `bg-surface`, non-interactive |
| Premium locked | Secondary outline with a small lock icon and a `premium-accent` border |

#### Cards
Cards use `bg-surface` with a 12px corner radius, a 1px `border-subtle` border, and 16px internal padding. Elevated surfaces (modals and active selections) switch to `bg-surface-raised`. In dark mode, elevation is represented by the lighter surface token rather than a drop shadow. In light mode, elevated cards take a soft drop shadow.

#### Badges
| Type | Visual style |
|---|---|
| Outcome (win, loss, breakeven) | Rounded pill with an `outcome-*` background at 15% opacity, matching text color, and status icon |
| Tier (Free, Premium, Enterprise) | Rounded pill with a `premium-accent` or `enterprise-accent` border |
| Content category (Community posts) | Rounded pill on `bg-surface-raised` with `text-secondary` text |
| Strategy visibility | Inline lock or globe icon without a pill container |

#### Inputs
Form fields use a `bg-surface` fill, a 1px `border-subtle` stroke, an 8px corner radius, and a 44px minimum touch height. Focusing a field changes the border to `brand-primary`.

#### Charts
Chart colors follow the tokens defined in section 2. Axis labels use the Caption type style. Tooltips use a `bg-surface-raised` container with Body Mono figures for numeric values.

### 7. Accessibility
- Text contrast: maintain at least 4.5:1 for body text and 3:1 for large headings and icons against `bg-base` and `bg-surface` in both light and dark modes.
- Color perception: every instance of `outcome-win` or `outcome-loss` (badges, curves, chart legends) must include an icon or text label so users with deuteranopia or protanopia can read the state without relying on color.
- Touch target sizing: all interactive controls must be at least 44x44px.

### 8. Breakpoints and grid

| Breakpoint | Width | Columns | Gutter | Margin | Specification |
|---|---|---|---|---|---|
| Mobile | Under 600px | 4 | 16px | 16px | [SCREENS_MOBILE.md](./SCREENS_MOBILE.md) |
| Tablet | 600 to 1200px | 8 | 20px | 24px | [SCREENS_TABLET.md](./SCREENS_TABLET.md) |
| Desktop | Over 1200px | 12 (centered, 1200px max content width) | 24px | 32px+ | [SCREENS_DESKTOP.md](./SCREENS_DESKTOP.md) |

Breakpoint changes alter layout structure only (column count, pane visibility, and navigation mode). Component tokens, typography scales, and color values remain identical across screen sizes. When a mobile or tablet device rotates between portrait and landscape, re-evaluate layout against width thresholds in this table.

### 9. Motion and transitions

| Token | Duration | Easing | Usage |
|---|---|---|---|
| `motion-instant` | 100ms | linear | Toggle switches, checkbox selections |
| `motion-fast` | 150ms | ease-out | Button press feedback, chip selections |
| `motion-standard` | 250ms | ease-in-out | Route navigation, tab switches, card accordion toggles |
| `motion-modal` | 300ms | ease-out (open), ease-in (close) | Bottom sheets, dialog open and close animations |
| `motion-chart` | 400ms | ease-in-out | Chart timeframe switches (such as weekly to monthly views) |

#### Screen transitions
On mobile and tablet, pushed screens slide in from the right and exit to the right. Keep platform-native navigation intact, especially the iOS edge-swipe back gesture. Bottom sheets slide up from the bottom of the screen while dimming the background. Desktop dialogs fade and scale between 96% and 100% rather than sliding from an edge.

#### Loading indicators
Use skeleton loaders with a looping shimmer effect (`motion-standard`) for loading states, as detailed in [SCREENS_MOBILE.md](./SCREENS_MOBILE.md). Do not use spinners as primary page loaders, except during the initial application launch splash screen.

#### Reduced motion
Check system accessibility preferences for reduced motion. When enabled, replace all slide and scale animations with simple opacity crossfades (`motion-fast`).

### 10. Elevation and shadow scale

| Level | Usage | Dark mode | Light mode |
|---|---|---|---|
| 0 | Base canvas | `bg-base` | `bg-base` |
| 1 | Flat cards and rows | `bg-surface` without shadow | `bg-surface` without shadow |
| 2 | Selected or raised cards | `bg-surface-raised` without shadow | `bg-surface-raised` with `0 1px 3px rgba(0,0,0,0.08)` shadow |
| 3 | Bottom sheets and popovers | `bg-surface-raised`, 1px top border `border-subtle`, and `0 -2px 8px rgba(0,0,0,0.24)` shadow | `bg-surface-raised` with `0 -2px 8px rgba(0,0,0,0.24)` shadow |
| 4 | Dialogs, toasts, and alerts | `bg-surface-raised` with `0 8px 24px rgba(0,0,0,0.32)` shadow | `bg-surface-raised` with `0 8px 24px rgba(0,0,0,0.12)` shadow |

Dark mode relies on step changes in background tint rather than heavy shadows because drop shadows are difficult to see against dark backgrounds. Light mode uses shadows because neutral background steps are closer in value.

### 11. Component states

These states extend the default and disabled definitions from section 6:

| Component | Hover (pointer devices only) | Focus (keyboard navigation) | Pressed / active |
|---|---|---|---|
| Buttons (all variants) | Background darkens by roughly 8% | 2px `brand-primary` outline with a 2px offset | Background darkens by roughly 16%, scales to 98% (`motion-fast`) |
| Input fields | Border changes to `text-secondary` | Border changes to `brand-primary` (2px width) | Focus border remains active during text input |
| Interactive cards | Elevates to level 2, border tints to `brand-primary` at 40% | 2px `brand-primary` outline | Background briefly switches to `bg-surface-raised` on tap (`motion-fast`) |
| List items | Background switches to `bg-surface-raised` | 2px inset `brand-primary` outline | Background briefly darkens |
| Chips and filter tags | Border changes to `brand-primary` | 2px `brand-primary` outline | Background fill changes to selected state |
| Navigation items | Background changes to `bg-surface` | 2px `brand-primary` outline | Active route uses the filled icon variant rather than a flash animation |

Hover states only render when a cursor is present (desktop and tablet with a mouse or trackpad). Touch screens do not show hover states; touch interaction goes directly from default to pressed.

### 12. Illustration guidelines

These specifications guide future artwork production:

- Style: flat two-tone line art using `brand-primary` combined with background neutrals. Avoid photorealism and heavy detail.
- Placement: empty states (journal entries, strategy notes, watchlists, social feed, notifications, saved posts), onboarding walkthrough slides, and the locked preview for free tier strategy notes.
- Tone: clean and functional. Avoid cartoon mascots and whimsical shapes.
- Dimensions: empty state artwork is approximately 120x120px on mobile and scales proportionally on tablet and desktop. Onboarding artwork spans full width inside its slide container.

### 13. Chart specifications

These rules apply to portfolio dashboard charts (equity curve, monthly growth, win/loss breakdown) and ticker detail charts:

- Number formatting: abbreviate currency amounts above $10,000 (such as $12.4K or $1.2M). Show full values with two decimal places below $10,000 (such as $1,234.56). Percentages always display one decimal place (64.3%). Tooltips always show the exact, unrounded value even when the chart axis is abbreviated.
- Date formatting: axis labels adjust based on the visible range. Single-month views show day numbers (12, 19, 26). Multi-month or annual views show abbreviated month names (Jan, Feb).
- Tooltip details: hovering on desktop or pressing and holding on mobile displays the exact date, unrounded value in Body Mono font, and the daily trade count for equity curves.
- Low data threshold: when a user has logged fewer than 5 trades with recorded profit or loss, show a muted placeholder line with a message prompting them to log more trades. Do not render an empty or single-point graph.
- Color consistency: charts only use the `chart-*` tokens defined in section 2.

### 14. Icon and splash asset requirements

| Asset | Technical requirement |
|---|---|
| iOS app icon | 1024x1024px source image without transparency. Do not round corners beforehand because iOS handles masking automatically. |
| Android adaptive icon | Separate foreground (432x432px with a centered 264x264px safe area) and background layers. |
| Web favicon | 512x512px master source, exported to 16, 32, 48, 180, 192, and 512px outputs. |
| Splash screen | Brand logo mark centered on `bg-base` dark background without additional illustrations. |
| Android notification icon | Monochrome silhouette with a transparent background following Android status bar conventions. |

The icon mark should be a simplified version of the wordmark logo so it remains recognizable at a 16px favicon resolution.
