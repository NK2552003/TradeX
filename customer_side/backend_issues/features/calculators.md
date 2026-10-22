# Backend Feature Audit: Financial Calculators

**Component:** `lib/features/calculators/`  
**Database Tables:** `public.calculator_history`  
**Files Evaluated:**  
- `backend_handoff/06-Calculator_History/tables.sql`  
- `lib/features/calculators/logic/tax_calculators.dart`  

---

## 1. 0% Calculator Persistence Integration

- **Unused `calculator_history` Table:**
  - Table was defined in `backend_handoff/06-Calculator_History/tables.sql`:
    ```sql
    CREATE TABLE IF NOT EXISTS calculator_history (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        calculator_type VARCHAR(64) NOT NULL,
        inputs JSONB NOT NULL,
        outputs JSONB NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    ```
  - Searching the entire app codebase returns **0 occurrences** of `calculator_history`.
  - **Action:** Add RLS policies (`FOR ALL TO authenticated USING (user_id = auth.uid())`) and expose endpoints for client persistence.

---

## 2. Statutory Capital Gains Tax Non-Compliance (Finance Act 2024)

- **Outdated Tax Constants:**
  - `tax_calculators.dart` hardcodes STCG at 15% (Finance Act 2024 increased to 20%).
  - Hardcodes LTCG at 10% (Finance Act 2024 increased to 12.5%).
  - Hardcodes LTCG exemption at ₹1,00,000 (Finance Act 2024 increased to ₹1,25,000).
  - **Action:** Update statutory backend tax engine formulas to reflect July 2024 amendments.
