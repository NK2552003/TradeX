# Customer frontend development

Run from the repository root:

```sh
scripts/dev_customer_frontend.sh demo 8456
scripts/dev_customer_frontend.sh account 8457
scripts/dev_customer_frontend.sh check
```

`demo` uses the explicit preview entrypoint; open the printed `/workspace?preview=customer` URL. `account` uses the normal application entrypoint and configured Supabase services. Neither mode manufactures a successful sign-in or a completed external transaction. Native development uses `flutter run` with the same entrypoint distinction. `tradex://note/<id>` and the other record schemes are registered on Android and iOS.

The check command runs static analysis, the complete Flutter regression suite and a release web build. Logs are saved in `validation/`. The regression suite exercises compact/desktop layouts, URL codecs, linked-record back navigation, access rules, real stream state handling and failed mutations.

## Authenticated assistant streaming

The client POSTs to the configured Supabase project's `/functions/v1/ai-copilot`, using the current user's session JWT. A provider key belongs on the server. The JSON request contains `thread_id`, `persona`, `stream: true` and up to 40 user/assistant messages from that conversation. It does not automatically upload portfolio or private workspace records.

The response must have `Content-Type: text/event-stream`. Send JSON `data: {"delta":"text"}` events (OpenAI-style `choices[].delta.content` is also accepted) followed by `data: [DONE]` or `data: {"type":"done"}`. Terminate errors with an error event or JSON error object. The frontend treats missing completion as interruption, preserves partial output and allows retry. Stop, thread changes and disposal close the request. Idle timeout is 30 seconds; the overall request limit is two minutes.

The frontend transport is implemented and tested with controlled streams. A deployed authenticated function and its provider credentials are still required for actual generated replies.

## Verified HTTPS links

The checkout currently uses development bundle IDs (`com.example.tradex`) and has no Apple Team ID or release certificate configuration. Custom-scheme development links are available. Verified HTTPS links additionally need an owned HTTPS domain and real signing identifiers.

Generate the public website association files using:

```sh
python3 scripts/generate_app_link_associations.py \
  --domain "$TRADEX_LINK_DOMAIN" \
  --android-package "$TRADEX_ANDROID_PACKAGE" \
  --android-sha256 "$TRADEX_ANDROID_SHA256" \
  --apple-team-id "$TRADEX_APPLE_TEAM_ID" \
  --ios-bundle-id "$TRADEX_IOS_BUNDLE_ID"
```

Output is isolated under `build/app-link-associations/.well-known`. Deploy those JSON files on that domain without redirects, add a matching HTTPS intent filter to the Android application and enable Associated Domains for the signed iOS target. Omitting Apple identifiers generates only the Android file. The script validates inputs and never reads private signing keys. Development identifiers must be replaced with the release application's identifiers before production setup is considered complete.

## Shareable view state

Community feed selections use `/community_feed?tab=for-you|live|following|signals|news|crypto|equities`. The AI workspace uses `/ai_copilot?tab=chat|insights|create`; desktop side panels use `panel=insights|create`. Unknown tab values select the default. The scope does not change the source page when an AI overlay is opened over another feature.

Authentication retains an internal `next` route, such as `/auth/login?next=%2Fnotes%2Frecord-id`. External destinations, unknown routes and nested authentication returns are rejected. Account-mode debug builds ignore preview-role URL parameters; only the explicit demo entrypoint enables preview identities.

References: [HTTP streamed requests](https://pub.dev/documentation/http/latest/http/Client/send.html), [Supabase user-authenticated Edge Functions](https://supabase.com/docs/guides/functions/auth).
