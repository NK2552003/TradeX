# TradeX delivery timeline

## Project delivery timeline

Work is structured across three parallel development tracks:

| Track | Estimated duration | Prerequisites |
|---|---|---|
| UI/UX design | 4 to 6 weeks | Starts immediately. Full screen and interaction specifications are documented in `03-design/`. |
| Backend | 5 to 7 weeks | Starts immediately. Complete database schema and API contracts are documented in `02-architecture/`. |
| Frontend | 5 to 7 weeks | Begins once the design system milestone is reached (around week 2 of design). Development proceeds against documented API mocks prior to backend completion. |

```mermaid
gantt
    title TradeX: Parallel Freelance Build
    dateFormat  2026-08-04
    axisFormat  %W

    section UI/UX
    Design system approved        :uiux1, 2026-08-06, 12d
    Mobile screens (all ~48 + empty screen states)      :uiux2, after uiux1, 22d
    Tablet + desktop adaptations  :uiux3, after uiux2, 10d
    Final handoff                 :uiux4, after uiux3, 5d

    section Backend
    Schema + auth + RLS           :be1, 2026-08-06, 14d
    Core feature APIs              :be2, after be1, 14d
    Direct Messages + blocking      :be2b, after be2, 4d
    AI features + integrations       :be3, after be2b, 14d
    Hardening + prod cutover          :be4, after be3, 7d

    section Frontend
    Scaffold + auth                :fe1, after uiux1, 7d
    Core modules                   :fe2, after fe1, 21d
    Community + Direct Messages     :fe2b, after fe2, 8d
    Portfolio + AI                   :fe3, after fe2b, 18d
    Notifications + Subscriptions     :fe4, after fe3, 10d
    Polish + store submission          :fe5, after fe4, 10d
```

Critical path: Frontend. Development is initially blocked on design system approval, and final integration requires backend completion. Total calendar time is estimated at 8 to 10 weeks.
