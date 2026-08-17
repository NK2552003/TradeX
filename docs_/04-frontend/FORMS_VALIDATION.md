# Forms & Validation — TraderHub

Every input field across the app, its validation rule, and the error copy shown (per [CONTENT_STYLE.md](./CONTENT_STYLE.md) § 4 microcopy conventions). Widget implementations: [COMPONENT_LIBRARY.md](./COMPONENT_LIBRARY.md) § 4.

### 1. Validation philosophy
- **Inline, on blur — not on every keystroke.** Validate a field when the user leaves it, not while they're actively typing (exception: live availability checks like handle uniqueness, which are inherently async and shown as a trailing icon rather than an error).
- **Client-side validation is a UX convenience, not the source of truth** — every field is re-validated server-side (Postgres constraints, RLS, Edge Function checks per the backend doc set) regardless of what the client already checked. Never skip a server round-trip's error handling because "the client already validated this."
- **Error copy follows CONTENT_STYLE.md § 4:** specific, not generic ("Enter a valid ticker symbol," never "Invalid input").

### 2. Auth fields
| Field | Rule | Error copy |
|---|---|---|
| Email (Sign Up / Log In / Forgot Password) | Valid email format | "Enter a valid email address" |
| Password (Sign Up) | Min 8 chars, at least 1 number | "Password needs at least 8 characters and a number" |
| Handle (Sign Up) | 3-20 chars, alphanumeric + underscore, live uniqueness check | "Handle is taken" / "Handles can only contain letters, numbers, and underscores" |

### 3. Journal Entry fields
| Field | Rule | Error copy |
|---|---|---|
| Ticker | Non-empty if any trade fields are filled; otherwise optional (a pure text-note entry with no ticker is valid) | "Add a ticker or clear the trade fields" |
| Entry price / Exit price / Stop loss / Target | Numeric, > 0 if present; all optional individually | "Enter a valid price" |
| Size | Numeric, > 0 if present | "Enter a valid size" |
| Side | Enum (long/short), required only if any price field is filled | — (segmented control, can't be invalid, just unset) |
| P/L | Auto-computed from entry/exit/size/side when all four are present; manually editable override always allowed regardless of computed value | — (no validation beyond numeric) |
| Notes / Psychology / Mistakes Made / Lessons Learned | All optional, no length cap enforced client-side (server may cap — confirm against `text` column limits, effectively unbounded in Postgres) | — |
| Tags | Optional, each tag 1-30 chars | "Tags can't be longer than 30 characters" |
| Screenshot upload | Max 10MB, `image/png` or `image/jpeg` only (matches backend API_REFERENCE.md § 2 limit) | "Image must be under 10MB" / "Only PNG or JPEG images" |

**Cross-field rule:** if Entry, Exit, and Size are all present but Side is not set, block save with "Select long or short" — this is the one case where an otherwise-optional field becomes required because the others imply a complete trade record.

### 4. Strategy Notes fields
| Field | Rule | Error copy |
|---|---|---|
| Title | Required, 1-100 chars | "Give this strategy a title" |
| Content (rich text) | Required, non-empty (a strategy with only a title and no body can't be saved) | "Write something before saving" |
| Category | Optional | — |
| Visibility | Defaults to Private; switching to Public shows a one-time confirmation ("This strategy will be visible on your public profile") rather than a hard validation error | — |

### 5. Watchlist fields
| Field | Rule | Error copy |
|---|---|---|
| Watchlist name | Required, 1-50 chars, unique per user (soft check — not a hard DB constraint, just prevents obvious duplicates client-side) | "Name this watchlist" |
| Ticker (Add Ticker) | Must resolve to a known symbol via the ticker autocomplete — free-text entry that doesn't match any suggestion is blocked | "Select a ticker from the list" |
| Price alert threshold | Numeric, > 0 | "Enter a valid price" |

### 6. Community fields
| Field | Rule | Error copy |
|---|---|---|
| Post content type | Required (one of six, no default pre-selected — forces an explicit choice per PRD.md's content categorization intent) | "Choose a category for your post" |
| Post text | Required, 1-2000 chars | "Write something" / "Posts are limited to 2000 characters" |
| Ticker tag (post) | Optional | — |
| Comment text | Required, 1-500 chars | "Write a comment" |

### 7. Profile fields
| Field | Rule | Error copy |
|---|---|---|
| Bio | Optional, max 300 chars | "Bio can't be longer than 300 characters" |
| Experience level / Trading style | Optional, enum picker — no free text, so no validation needed beyond selection | — |

### 8. Subscription / Enterprise fields (post-MVP for the latter)
| Field | Rule | Error copy |
|---|---|---|
| Team member invite email | Valid email format, must not already be a member | "Enter a valid email" / "Already a team member" |
| API key name | Required, 1-50 chars | "Name this key" |

### 9. Not yet decided
- Whether journal/strategy text fields need a client-side max length at all (currently only capped by Postgres `text` column limits, which are effectively unbounded) — worth a sanity cap (e.g. 10,000 chars) purely to prevent an accidental paste-of-a-whole-document from degrading UI performance, not for data-integrity reasons.
