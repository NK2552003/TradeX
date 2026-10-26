# Admin and affiliate workspace design

## Direction

An operations workspace for reviewing accounts, capital and partner earnings. The
primary visual emphasis is the work to do: review a request, inspect a record,
create a campaign or configure a payout. Summaries support those actions.

Use the existing TraderHub tokens: paper `#FFFFFF`, muted surface `#F5F5F4`, ink
`#232120`, brand blue `#4F63C4`, settled green `#237A50`, attention amber `#C98A2E`.
Dark mode resolves through the same semantic tokens. Noto Sans carries headings,
labels and explanations; tabular numerals align amounts. Monospace is reserved
for identifiers and references. No new palette or parallel control library.

Layout: left-aligned page identity and actions, followed by summaries, then the
primary task and supporting records. Titles and instructions wrap. A field or
record grows with its content instead of adopting a fixed card aspect ratio.

```
Page title                              Primary action / refresh
One short explanation of the task
Summary          Summary          Summary          Summary
Main task / working records                       Supporting detail
History / terms / secondary records
```

On a phone or narrow settings pane:

```
Page title
Explanation
Actions (wrap)
Summary
Task
Record identity
Field label
Field value
Record actions
```

Review against the brief: avoid treating every information group as an identical
metric tile. Retain real financial charts, make tables the focus of review pages,
and group application/payout fields by the decision they support. Shared card
headers own their spacing; tables own cell gutters and adapt to available pane
width. The same behavior applies to admin, affiliate and their settings pages.

## Verification scope

- Admin overview, analytics, risk policy/order/breach queues, audit filters and
  detail dialog, account governance (consumers, seats, affiliates, deletion).
- Affiliate overview, referrals and filters, campaigns and media, payouts and
  statements, application steps and approval review.
- Organization, team roles/invitation, desk risk, affiliate payout/tax settings;
  shared settings destinations remain covered by their existing regression suite.
- Scripted Flutter interactions, narrow panes, phone/tablet/desktop, larger text,
  keyboard insets, clipboard payloads and navigation return paths.
- Local preview data only for mutation tests. These scripts do not initiate real
  payments, invite real users, approve live accounts or purge production data.
