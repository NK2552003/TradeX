

### Timeline
Three separate engagements (`CLIENT_BRIEF_UIUX.md`, `CLIENT_BRIEF_FRONTEND.md`, `CLIENT_BRIEF_BACKEND.md`) running concurrently rather than one person doing everything in sequence:

| Track | Est. duration | Can start |
|---|---|---|
| UI/UX design | 4–6 weeks | Immediately — full screen/design spec already exists (`03-design/`), now including the 3 Direct Messages screens |
| Backend | 5–7 weeks | Immediately — full schema/API spec exists (`02-architecture/`), independent of design; includes `conversations`/`messages`/`blocks` and the `notify_new_message` trigger |
| Frontend | 5–7 weeks | Blocked on the design system milestone (~week 1–2 of the UI/UX track); can build against the documented API contract before the backend finishes, per `06-business/DOC_ACCESS_MAP.md` |

```mermaid
gantt
    title TraderHub — Parallel Freelance Build
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

**Critical path: Frontend.** It's blocked at the start by the design system milestone, and it needs the backend meaningfully done before final integration/QA — so it roughly bookends the other two tracks rather than running fully independently of them. Total wall-clock time lands around **8–10 weeks**.
