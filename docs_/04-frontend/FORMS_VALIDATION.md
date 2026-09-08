# Forms and validation: TradeX

This document catalogs every input field across the application, its validation rules, and the error copy shown to users following [CONTENT_STYLE.md](./CONTENT_STYLE.md) microcopy standards. For component implementations, consult [COMPONENT_LIBRARY.md](./COMPONENT_LIBRARY.md).

## 1. Validation philosophy
- Validate inline on blur rather than on every keystroke. Evaluate fields when the user finishes and moves away, not while they type. The only exceptions are asynchronous availability checks, such as handle uniqueness, which display an inline indicator instead of an error state.
- Client validation improves responsiveness but never replaces server validation. Database constraints, row-level security policies, and edge functions enforce final business rules. Never bypass backend error handling under the assumption that client validation succeeded.
- Error messages follow specific guidance from CONTENT_STYLE.md: use clear phrasing such as "Enter a valid ticker symbol" rather than vague notices like "Invalid input".

## 2. Authentication fields
| Field | Validation rule | Error message |
|---|---|---|
| Email (Sign Up, Log In, Forgot Password) | Valid email format | "Enter a valid email address" |
| Password (Sign Up) | Minimum 8 characters, at least 1 number | "Password needs at least 8 characters and a number" |
| Handle (Sign Up) | 3 to 20 alphanumeric characters or underscores, unique | "Handle is taken" or "Handles can only contain letters, numbers, and underscores" |

## 3. Journal entry fields
| Field | Validation rule | Error message |
|---|---|---|
| Ticker | Required if trade fields are filled; otherwise optional | "Add a ticker or clear the trade fields" |
| Entry, Exit, Stop loss, Target | Numeric, greater than 0 if present; optional individually | "Enter a valid price" |
| Size | Numeric, greater than 0 if present | "Enter a valid size" |
| Side | Enumeration (long, short); required only when price fields are populated | None (segmented control, defaults to unset) |
| Net P/L | Auto-calculated from trade parameters; manual override permitted | None (numeric format only) |
| Notes, Psychology, Mistakes, Lessons | Optional, unconstrained length on client | None |
| Tags | Optional, each tag between 1 and 30 characters | "Tags cannot be longer than 30 characters" |
| Screenshot upload | Maximum 10MB; PNG or JPEG only | "Image must be under 10MB" or "Only PNG or JPEG images" |

Cross-field rule: if entry price, exit price, and position size are all populated while trade side remains unset, block submission with the message "Select long or short".

## 4. Strategy note fields
| Field | Validation rule | Error message |
|---|---|---|
| Title | Required, 1 to 100 characters | "Give this strategy a title" |
| Content (rich text) | Required, cannot be blank | "Write something before saving" |
| Category | Optional | None |
| Visibility | Defaults to Private; selecting Public prompts confirmation | None |

## 5. Watchlist fields
| Field | Validation rule | Error message |
|---|---|---|
| Watchlist name | Required, 1 to 50 characters, unique per account | "Name this watchlist" |
| Ticker search | Must match a symbol returned by autocomplete search | "Select a ticker from the list" |
| Price alert threshold | Numeric, greater than 0 | "Enter a valid price" |

## 6. Community fields
| Field | Validation rule | Error message |
|---|---|---|
| Post category | Required selection across the six categories | "Choose a category for your post" |
| Post text | Required, 1 to 2,000 characters | "Write something" or "Posts are limited to 2000 characters" |
| Ticker tag | Optional symbol link | None |
| Comment text | Required, 1 to 500 characters | "Write a comment" |

## 7. Profile fields
| Field | Validation rule | Error message |
|---|---|---|
| Bio | Optional, maximum 300 characters | "Bio cannot be longer than 300 characters" |
| Experience level, Trading style | Optional selection from predefined options | None |

## 8. Subscription and enterprise fields
| Field | Validation rule | Error message |
|---|---|---|
| Team member invitation email | Valid email address not currently registered in the organization | "Enter a valid email" or "Already a team member" |
| API key name | Required, 1 to 50 characters | "Name this key" |

## 9. Open considerations
The client currently imposes no character cap on rich text journal or strategy notes, relying on database text capacity. Establishing a practical limit, such as 10,000 characters, would guard against UI performance slowdowns caused by pasting large external documents.
