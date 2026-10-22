# Frontend Feature Audit: Public Site & Pricing

**Component:** `lib/features/public_site/`  
**Target Files:**  
- `lib/features/public_site/presentation/public_pricing_content.dart`  
- `lib/features/auth/presentation/widgets/tradex_footer.dart`  

---

## 1. Dead Buttons & Social Icons

| UI Control | File & Line | Failure Mechanism | Priority |
|---|---|---|:---:|
| Footer Social Icons | `tradex_footer.dart:388–450` | Twitter, Discord, Telegram, and GitHub icons emit `UiToast`; never open browser URLs. | Low |

---

## 2. Layout & Typography Overflow

- **Currency String Multi-Line Wrap on Narrow Phones (`public_pricing_content.dart:100-120`):**
  - On screens <= 360px wide, price strings like `₹14,999 / year` wrap into 3 vertical lines and clip savings chips.
  - **Action:** Wrap price labels in `FittedBox(fit: BoxFit.scaleDown, child: Text(...))`.

---

## 3. False Marketing Copy to Remove

- **`tradex_footer.dart:727`:**
  - Remove "AES-256 GCM client-side encryption" claims.
