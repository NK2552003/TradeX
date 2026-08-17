# Developer Setup Guide

### 1. Prerequisites
- Flutter SDK (stable channel, 3.x+): `flutter --version`
- Dart (bundled with Flutter)
- Supabase CLI: `npm install -g supabase`
- Xcode (for iOS) / Android Studio (for Android)
- A Supabase account (free tier is enough to start)
- A RevenueCat account
- An Anthropic API key (for the AI insights Edge Function)
- A market data API key (Alpaca, Finnhub, or Twelve Data — free tier)

### 2. Clone & Install
```bash
git clone <your-repo-url>
cd traderhub
flutter pub get
```

### 3. Environment Variables
Create `.env` at project root (never commit this file):
```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
```
Server-side secrets (Claude API key, market data key) go into Supabase Edge Function secrets, NOT the Flutter `.env`:
```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxx
supabase secrets set MARKET_DATA_API_KEY=xxxx
```

### 4. Local Supabase
```bash
supabase init
supabase start          # spins up local Postgres, Auth, Storage
supabase db push         # applies migrations in supabase/migrations/
```

### 5. Run the App
```bash
flutter run -d chrome      # web
flutter run -d ios         # iOS simulator (macOS only)
flutter run -d android     # Android emulator
```

### 6. Code Generation
Whenever you add/change a `freezed` model or Riverpod provider:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 7. Testing
```bash
flutter test                       # unit + widget tests
flutter test integration_test/     # integration tests
```

### 8. Deploying Edge Functions
```bash
supabase functions deploy ai-insight
```

### 9. Building Release Artifacts
```bash
flutter build apk --release              # Android
flutter build ios --release              # iOS (then archive via Xcode)
flutter build web --release              # Web
```

### 10. Common Issues
| Symptom | Fix |
|---|---|
| `MissingPluginException` | Run `flutter clean && flutter pub get` then rebuild |
| Supabase RLS blocking queries | Check policies in `docs/API_DATA_MODEL.md`; test with `supabase db diff` |
| Codegen errors after model changes | Delete `.g.dart`/`.freezed.dart` files, rerun `build_runner build` |
