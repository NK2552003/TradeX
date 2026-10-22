# Frontend Feature Audit: Financial Calculators

**Component:** `lib/features/calculators/`  
**Target Files:**  
- `lib/features/calculators/ui/calculators_screen.dart`  
- `lib/features/calculators/ui/position_size_screen.dart`  
- `lib/features/calculators/ui/risk_reward_screen.dart`  
- `lib/features/calculators/logic/tax_calculators.dart`  

---

## 1. Mathematical Formatting & UI Crashes

- **Division by Zero & `double.infinity` (`risk_reward_screen.dart`):**
  - When entry price equals stop loss, R:R calculation evaluates to `double.infinity`.
  - Calling `toStringAsFixed(2)` or passing `Infinity` into linear progress indicators crashes the widget tree.
  - **Action:** Add `if (!ratio.isFinite) return 0.0;` guards.

---

## 2. Statutory Tax UI (Indian Finance Act 2024)

- **Outdated Tax Rates in UI (`tax_calculators.dart:18-44`):**
  - UI labels and calculations display STCG 15% and LTCG 10% (exemption ₹1,00,000).
  - Statutory rates under Finance Act 2024 are STCG 20%, LTCG 12.5% (exemption ₹1,25,000).
  - **Action:** Update UI labels and provide a toggle for Pre-July 2024 vs Post-July 2024 tax regimes.

---

## 3. Disconnected Workflows

- **No "Export to Journal" CTA:**
  - After calculating optimal position size or R:R, the trader has no button to transfer values into a new journal trade entry.
  - **Action:** Add `UiButton(label: 'Log Trade with this Size', onPressed: () => ...)`.
