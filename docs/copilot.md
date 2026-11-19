# AlphaJournal copilot

The copilot is a new Dart implementation informed by the behavior of the local OpenDots reference. It uses the AlphaJournal component library and the existing app authentication. It does not use the OpenDots TypeScript application, CopilotKit Intelligence, Composio, or a second AI provider.

## Trader skills

Open **Trader skills** from the trader workspace or the Copilot welcome page. In a conversation, type `/` to see matching commands. Both `/trader-budget` and `/budget` select the budget skill. Selecting a command keeps the rest of your draft editable.

Ask a question in ordinary language to let Copilot choose. For example, “Use these target weights to size a $5,000 paper portfolio and check my proposed orders” uses budget sizing and risk checks. A copy request can start from public filings, pass target weights to sizing and pass proposals to risk. Broker produces a draft ticket for review.

Code-enabled profiles can run the eleven supplied Python tools in a temporary provider sandbox when OpenAI is configured. The bundled toolkit in `supabase/functions/ai-gateway/trader-skills.json` contains the original scripts, skill guides, supporting data and MIT license. Include it when deploying either backend. Public data comes from permitted research or supplied files. Replies carry results into later turns. Text-only profiles can guide the workflow using supplied data. Recurring checks require a configured schedule on the dedicated worker.

## Hosted deployment on alphajournal.in

With `COPILOT_API_URL` empty, the app uses Supabase workspace storage and the existing authenticated `ai-gateway` Edge Function. AI keys stay in [Edge Function secrets](https://supabase.com/docs/guides/functions/secrets); they are never copied into the browser or downloaded from Supabase. Sign-in and the gateway's account/quota checks are required.

Apply `supabase/migrations/20261108065544_copilot_workspaces.sql` once in the project's SQL editor before deploying the frontend. It adds only account-owned copilot state with RLS; it does not change market data or existing notes. Alternatively, set a scoped `SUPABASE_ACCESS_TOKEN` with database query permission and run:

```sh
python3 scripts/deploy_copilot_storage.py --project-ref ylxwgkhtwrizdmuhlhxs
```

The script verifies RLS, owner policy and grants after deployment. It is repeatable and does not replay unrelated migrations. The **Copilot deployment checks** GitHub workflow also offers this as a manual `deploy_storage` option from `main`, using the repository's `SUPABASE_ACCESS_TOKEN` secret.

Configure `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the Cloudflare build environment, then run:

```sh
python3 scripts/prepare_client_config.py
flutter build web --release
```

Deployment environment values override `.env` and `.env.example`. Only public allowlisted values are bundled. Leave `COPILOT_API_URL` empty for Supabase mode. The existing `ai-gateway` must be deployed with its provider secrets; no new AI key is needed in Cloudflare.

Hosted mode supports saved conversations, specialist prompts, spaces/pages with revision-conflict protection, selected-page context, memories and account settings. The Edge gateway supports OpenAI Responses API web search and image/PDF/text attachments when an OpenAI key is configured; hosted replies are progressively emitted to the composer after the gateway response is saved. It does not run the Dart worker's live voice, computer/MCP actions or background schedules. Use a dedicated authenticated HTTPS Dart worker via `COPILOT_API_URL` for those integrations. Existing Dart-worker workspaces are not automatically migrated into Supabase.

After deployment, sign in on `alphajournal.in`, send a message, reload to confirm persistence, and check a second account cannot see that conversation. A successful build alone does not verify live storage migration or provider quotas.

### Web search configuration

Use `OPENAI_MODEL=gpt-4o` in the backend environment. For hosted mode,
set this value and `OPENAI_API_KEY` (or `OPEN_AI_KEY`) in Supabase Edge Function
secrets; the repository `.env` only configures the separately running Dart worker.
Deploy `ai-gateway` including its `responses.ts` module after updating the code.

With Supabase CLI 3, after authenticating to the project:

```sh
npx supabase secrets set OPENAI_MODEL=gpt-4o --remote=ylxwgkhtwrizdmuhlhxs
npx supabase functions deploy ai-gateway --remote=ylxwgkhtwrizdmuhlhxs --use-api
```

Keep the provider key server-side. Search and Deep research require OpenAI;
Auto can use web search when an OpenAI key is configured and research is enabled
for both the workspace and specialist. Source citations are rendered as links.
Provider errors distinguish invalid keys, quota exhaustion, rate limits, and
model permissions. Without an OpenAI key, Auto retains the text-only provider fallback.

Run `scripts/verify_copilot_community_startup.sh` for the automated search,
community navigation, and startup regression checks (Node 22.18+ and Flutter).

## Dedicated Dart worker

## Run it

From the AlphaJournal directory:

```sh
flutter pub get
dart run bin/copilot.dart
```

The service reads `OPEN_AI_KEY` from the repository's `.env`; process environment variables take precedence. The existing Supabase URL and anonymous key verify the signed-in app user's access token. Each verified account has a separate persisted workspace. The actual OpenAI key stays on the service and is never included in Flutter assets or requests from the client.

To use the separately running Dart worker, explicitly configure its URL (use `http://127.0.0.1:8787` locally). For a hosted worker:

```sh
flutter run --dart-define=COPILOT_API_URL=https://copilot.example.com
```

Use `http://10.0.2.2:8787` for an Android emulator reaching its host, or a reachable server address for physical devices. Remote clients need an authenticated HTTPS deployment. Microphone access on the web needs localhost or HTTPS. `COPILOT_API_URL` is public configuration, not an API key.

For local development without signing in:

```sh
COPILOT_LOCAL_OWNER=true dart run bin/copilot.dart
```

This mode is explicitly restricted to a loopback bind and loopback clients and uses its own `local-owner` workspace. It is not a remote deployment mode. Normal authenticated mode remains the default.

## Interface and features

| Area | Implementation |
| --- | --- |
| Desktop | One centered conversation by default; Workspace opens one optional second pane. No third pane. |
| Tablet | Conversation and Workspace tabs. |
| Phone | Conversation and full-screen Library navigation; keyboard-safe composer. |
| Interaction | Existing AlphaJournal controls and theme tokens; no haptics. System, light, and dark appearance. |
| Specialists | Create, edit, and delete roles; individual instructions and research, data analysis, memory, app, learning, space, and computer permissions. |
| Conversations | Streaming Responses API, cancellation, pin/rename/delete/search, images/PDF/text attachments, source links, work logs, downloadable generated files, contextual entry points from AlphaJournal. |
| Research and analysis | OpenAI web search and hosted code interpreter using the same `OPEN_AI_KEY`. |
| Spaces and pages | Search, list/grid views, nested pages, move pages, visual rich-text editing, formatting toolbar, slash commands, undo/redo, Markdown source and rendered reading modes, export, autosave, revision conflicts, local draft recovery, page-specific conversation context. |
| Review | Exact proposed page, preference, lesson, MCP, and computer actions are reviewed in chat. Approved local writes are idempotent. Permissions are rechecked at execution. |
| Memory and learning | Owner-managed preferences; specialists propose reusable lessons with evidence. The owner reviews and publishes skills before future use. This replaces the reference's cloud learning containers with local Dart behavior. |
| Scheduled work | One-time or recurring server-side prompts in the original conversation, pause/resume, explicit retry after interruption, persisted run history. The Dart service must stay running. |
| Calls | OpenAI Realtime, PCM microphone audio, AI voice, captions, timer, mute, speaker mute, minimize, delegated background analysis, persisted transcripts and call history. Audio playback buffers each utterance. |
| Connections | HTTPS MCP servers with per-specialist and per-tool access. Reviewed writes; optionally trusted read-only tool names. Tool discovery appears after a conversation contacts the server. |
| Computers | Dart adapter for isolated OpenBot computers, separate owner/specialist identities, persistent browser/files, terminal, takeover, permission controls, and activity. Requires the separately running service below. |
| Slack | Signed Events API webhook, workspace/user allowlists, mention-to-thread binding, reply status, and durable event deduplication. Requires a Slack bot connection. |

This reimplementation keeps the requested workflows while using different internals. The document editor uses Flutter Quill for visual editing and the project's Markdown editor for source editing. MCP endpoints supply connected-app functionality; no embedded Composio account-onboarding service is included.

### Composer

The composer has a right-aligned specialist selector, file attachments, clipboard actions, a prompt library, voice control, and character/word counts. Enter adds a line; Ctrl/Cmd+Enter sends. The action menu can paste text at the selection, copy the draft, or clear it. Attach up to four PNG, JPEG, WebP, PDF, TXT, Markdown, or CSV files, each under 6 MB and within the combined upload limit. Failed submissions retain the draft and attachments.

On wide layouts, Search and Deep research appear as separate controls. Phones use a compact mode menu; the writing area contracts when the keyboard leaves less room, and attachment chips scroll horizontally. Auto lets the model choose tools. Search explicitly runs OpenAI web search. Deep research uses the configured Responses model with a larger web-search context and instructions to compare and cite sources; it is not a separate dedicated deep-research-model job. Both modes respect workspace and specialist research permissions and use the same server-side `OPEN_AI_KEY`.

## Configuration

| Variable | Default / purpose |
| --- | --- |
| `OPEN_AI_KEY` | Required for model, research, code interpreter, and voice requests. |
| `OPENAI_MODEL` | `gpt-4o` |
| `OPENAI_VOICE_MODEL` | `gpt-realtime` |
| `COPILOT_HOST`, `COPILOT_PORT` | `127.0.0.1`, `8787` |
| `COPILOT_DATA_DIR` | `.copilot-data`, ignored by Git; back this directory up. |
| `COPILOT_ALLOWED_ORIGINS` | Comma-separated exact web origins. Localhost HTTP origins are allowed for development. |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Existing authentication; `NEXT_PUBLIC_` aliases are accepted on the server. |
| `COPILOT_LOCAL_OWNER` | `false`; loopback-only development bypass. |

The store uses atomic JSON file replacement and an exclusive process lock. Run one service process per data directory. Restart recovery marks active work interrupted and does not replay external actions. On a failed or interrupted model continuation, a future message rebuilds context from saved text and action receipts; attachments may need to be sent again. Generated files can expire at OpenAI and may need regeneration.

## Optional services

An OpenAI key powers the AI but cannot grant access to a user's Slack, email, calendar, GitHub, or a hosted computer. Those accounts and services require their own authorization.

For apps, open **Workspace → Connections**, supply a public HTTPS MCP endpoint and its token if required, then enable apps globally and for the chosen specialist. Select allowed tools. Only explicitly trusted read-only names bypass review. Credentials are stored in the server workspace, so restrict access to its data directory.

For computers, run a compatible OpenBot supervisor/computer deployment, then set `COMPUTER_SUPERVISOR_URL`, `COMPUTER_SUPERVISOR_TOKEN`, and `COMPUTER_TOKEN`. Set `COMPUTER_NAMESPACE` if the container prefix differs from `opendots`. The adapter validates supervisor-reported bot/container identity and destination port, derives a separate HMAC credential for each owner/specialist, and uses the supervisor's `/computers` and `/computers/:id/ensure|stop` endpoints. Computer workspace files and browser profiles persist in that service's volumes. No computer command is executed on the AlphaJournal host. Enable the desired permissions in **Workspace → Computer** and start the computer there.

For Slack, create a bot with `app_mentions:read`, `chat:write`, and the history permission appropriate to the channels it will use. Subscribe to `app_mention` and the relevant message events; invite the bot to the channel. Set the Events request URL to `https://your-service/v1/slack/events`. Configure:

- `SLACK_SIGNING_SECRET` and `SLACK_BOT_TOKEN`
- `SLACK_OWNER_ID`: the existing Supabase user ID whose workspace receives Slack threads
- `SLACK_TEAM_ID` and comma-separated `SLACK_ALLOWED_USER_IDS`
- `SLACK_SPECIALIST_ID`, default `analyst`

The webhook verifies signatures and request age, limits accepted workspaces/users, ignores bot messages, and requires an initial mention before following thread replies. Actions needing approval are reviewed inside AlphaJournal. Failed delivery is shown in Connections; the service does not blindly replay outbound Slack messages.

## Verification

The automated suite covers workspace persistence and account isolation, stale edits, nested-page constraints, tool permissions, streamed text/citations/files, exact-once approval, denial, cancellation, interrupted work, stale client responses, HTTP authentication/CORS, credential redaction, all three layouts, and local page-draft recovery. The calculator regression opens Options P&L through the mobile More destination and checks that keyboard appearance preserves both calculator state and typed input.

```sh
dart analyze
flutter test test/features/copilot test/features/calculators/calculator_keyboard_test.dart
flutter build web --release
```

Live OpenAI text streaming, the propose → approve → persist page flow, and an authenticated Realtime session configuration were verified with the configured key. Optional Slack and OpenBot integrations require connected-service testing in the target deployment; microphone capture and speaker playback also need a real-device check.

The focused suite and application mounting checks pass. A broader run found eight existing failures (narrow calendar layout, community navigation, and backend fixtures for journal, strategies, notes, profile, billing, and notifications). The same eight failures were reproduced from an isolated checkout of the unchanged repository. The calculator keyboard regression fails against that baseline and passes with this fix.

## Research studio and answer upgrade (2026-11-16)

Copilot now exposes **60 curated output formats** in six categories: Evidence,
Markets, Fundamentals, Risk, Journal, and Explain. The searchable studio previews
and copies each prompt, accepts a topic, and returns an editable composer draft.
The same studio is available beneath existing answers for transformations.
See [the format catalog](copilot-research-formats.md) for every workflow and its
specific analytical instruction. These are 60 research/output workflows using
one validated visual contract, not 60 new external service integrations.

`research_panel` renders a direct summary, responsive sortable/paginated table,
copyable TSV, expandable evidence trail, publication/event dates, limitations,
and next steps. Invalid optional fields degrade gracefully. The existing
company, person, earnings, financials, macro, ratings, screener, sentiment,
comparison, timeline, setup, and media cards retain their existing behavior with
consistent surfaces, spacing, scaled metric widths, and stacked mobile tables.
Long guidance is shown as prose rather than truncated into a numeric tile.
Comparison matrices now honor declared column names, and financial statement
rows without period columns remain visible.

Answer tools provide a reading view, source filtering, source/domain counts,
reference copying, Markdown inspection/copying, an outline, creation timestamp,
and a context-specific Check latest follow-up. Source counts and inferred answer
structure are not labeled as verified research. Saved hosted/worker metadata
records observed web-tool use; time-sensitive responses with no recorded search
show a visible unverified-current-information notice.

### Freshness behavior

Both the Supabase gateway and Dart worker inject a runtime UTC clock for each
request. The policy resolves relative dates, checks publication date versus event
date versus data period, prefers original sources and corrections, labels older
context, and requires quote timestamps/timezones and delayed-market status.
Latest-news requests prefer a 24-hour window, widened transparently to seven
days if needed; financial reporting uses the actual latest reporting period.
Explicit historical ranges remain valid.

Time-sensitive prompts force the real web-search tool on the first generation
step when research is enabled. `external_web_access: true` explicitly permits
live retrieval. Search permissions are preserved. A clock or search call cannot
guarantee every retrieved page is current or every model claim correct. When
search is disabled/unavailable, instructions require disclosure and the UI
marks time-sensitive answers without recorded search as unverified.

### Typing and dark theme

`aiTypingCharacterInterval` in `lib/core/app-ui/motion/ai_typewriter.dart` controls
the default **25 ms per grapheme** reveal. Incoming chunks extend the queue.
Emoji/combining characters remain intact. Skip reveals all queued text and makes
later chunks immediate for that answer; reopening saved history is instant.
Reduced motion bypasses animation and cursor blinking. A fixed-size blinking
cursor follows prose and code; code stays monospaced during reveal, then uses
the existing syntax highlighting when complete. Structured JSON blocks show
loading cards while incomplete.

The chat follows output growth smoothly near the bottom and stops following
when the user scrolls up. New message keys preserve typing state. All surfaces, text, controls, and the blinking cursor inherit the active
application theme. There is no separate purple palette. Light and dark mode
remain supported through the existing design tokens.

### Research and implementation references

- [Perplexity Pro Search](https://www.perplexity.ai/help-center/en/articles/10352903-what-is-pro-search): sourced answers, multi-step research, and visible research activity informed the answer-first layout and progressive disclosure.
- [OpenAI web search](https://developers.openai.com/api/docs/guides/tools-web-search): tool choice can require search; `external_web_access` controls live access; citation annotations supply source URLs. The implementation keeps the existing OpenAI integration, without adding a Perplexity subscription or key.
- [Supabase changelog](https://supabase.com/changelog.md): reviewed before changing the hosted function; no SDK upgrade or database migration is introduced by this upgrade.

Deploy the updated Flutter bundle **and** `ai-gateway` (including
`research-policy.ts` and `responses.ts`) to activate all hosted changes. Restart
the Dart worker if using that deployment. No database migration or new provider
key is required. Local tests mock provider/network boundaries; production
provider quality, credentials, and quotas still require a signed-in smoke test.
The live app link showed the signed-out landing page in the verification browser.

### Automatic output selection

Natural-language questions are routed automatically to a relevant research
format or existing native card. Examples: earnings → earnings card; compare →
comparison card; position sizing → sizing worksheet; review my trade → debrief;
current market briefing → session brief. A small composer hint previews the
suggestion and Change format opens the studio. An explicit studio choice or
plain-text/code-only request takes priority. Ambiguous questions leave the
structure to the model using conversation context; mixed questions may use one
main and one complementary format. Routing adds instructions to the provider
request without rewriting the user's saved question or consuming an extra AI
call. It does not change the user's search permissions or source-focus setting.
