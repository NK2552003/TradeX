# Frontend Feature Audit: Community & Social Trading

**Component:** `lib/features/community/`  
**Target Files:**  
- `lib/features/community/presentation/community_root_screen.dart`  
- `lib/features/community/presentation/views/community_feed_view.dart`  
- `lib/features/community/presentation/views/community_post_detail_view.dart`  
- `lib/features/community/presentation/widgets/community_author_header.dart`  
- `lib/features/community/presentation/widgets/community_composer_card.dart`  
- `lib/features/community/presentation/widgets/community_advisor_disclosure_sheet.dart`  

---

## 1. Dead Buttons & No-Op Handlers

| UI Control | File & Line | Failure Mechanism | Priority |
|---|---|---|:---:|
| "Quote" Post | `community_post_detail_view.dart:111` | `onQuote: () {}` empty closure; does nothing when tapped. | Medium |
| "Mute User" | `community_author_header.dart:257` | `onPressed: onMute ?? () {}` fallback closure. | Medium |
| "Report Post" | `community_author_header.dart:262` | `onPressed: onReport ?? () {}` fallback closure. | Medium |
| Pull-to-Refresh | `community_feed_view.dart:390` | Executes `setState(() {})` only; does not re-fetch from database! | Medium |

---

## 2. Layout & Mobile UX Flaws

- **Double Mobile Bottom Navigation Dock:**
  - `AppScaffold` bottom dock + `CommunityRootScreen` bottom tab bar render simultaneously on mobile devices, stealing ~140px of screen height.
  - **Action:** Move sub-tabs (`Feed`, `Explore`, `Audio Spaces`, `Bookmarks`) to a top bar.
- **Touch Target Accessibility (WCAG):**
  - Mute/Report buttons in `community_author_header.dart` measure 28x28px, failing WCAG 48x48px requirement.
  - **Action:** Enforce `BoxConstraints(minWidth: 48, minHeight: 48)`.
- **Simulated Audio Spaces (`community_live_rooms`):**
  - Audio spaces feature has no WebRTC/LiveKit/Agora stream. Animated waves run on a local timer.
  - **Action:** Add a "Beta / Coming Soon" badge or wire a real WebRTC audio bridge.

---

## 3. Privacy & Regulatory Traps

- **Silent Note Visibility Mutation (`community_composer_card.dart:898-917`):**
  - Attaching a private note silently executes `setVisibility(src.id, true)` without user prompt.
  - **Action:** Add an explicit confirmation dialog before flipping a private note to public.
- **Fabricated SEBI Registration Number (`community_advisor_disclosure_sheet.dart:130-143`):**
  - Displays hardcoded SEBI license `INH000009412` for all community posts.
  - **Action:** Delete the hardcoded license string immediately. Only render registered license if verified in author profile.
