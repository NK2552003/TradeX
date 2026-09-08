# Developer setup guide

## 1. Prerequisites
- Flutter SDK (stable channel, 3.x or newer): verify with `flutter --version`
- Dart SDK (bundled with Flutter)
- Supabase CLI: install with `npm install -g supabase`
- Xcode for iOS development, Android Studio for Android emulation
- Supabase account (free tier suffices for development)
- RevenueCat account for subscription entitlement handling
- Anthropic API key for AI assistant edge functions
- Market data API key (Alpaca, Finnhub, or Twelve Data, free tier)

## 2. Clone and install
```bash
git clone <your-repo-url>
cd TradeX
flutter pub get
```

## 3. Environment variables
Create a `.env` file at the project root. Never commit this file to source control:
```text
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
```

Server secrets such as the Anthropic key and market data provider credentials reside in Supabase Edge Function secrets, not the Flutter client `.env`:
```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxx
supabase secrets set MARKET_DATA_API_KEY=xxxx
```

## 4. Local Supabase environment
```bash
supabase init
supabase start          # Starts local Postgres, Auth, and Storage services
supabase db push         # Applies database migrations from supabase/migrations/
```

## 5. Running the application
```bash
flutter run -d chrome      # Web target
flutter run -d ios         # iOS simulator (macOS required)
flutter run -d android     # Android emulator
```

## 6. Code generation
Run code generation whenever modifying Freezed data models or annotated Riverpod providers:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## 7. Running tests
```bash
flutter test                       # Unit and widget test suite
flutter test integration_test/     # End-to-end integration tests
```

## 8. Deploying edge functions
```bash
supabase functions deploy ai-insight
```

## 9. Building release artifacts
```bash
flutter build apk --release              # Android release bundle
flutter build ios --release              # iOS release bundle (archive via Xcode)
flutter build web --release              # Web production build
```

## 10. Troubleshooting common issues
| Issue | Recommended resolution |
|---|---|
| `MissingPluginException` on launch | Run `flutter clean && flutter pub get`, then rebuild the native binary |
| Supabase RLS blocking client queries | Review policy declarations in `API_DATA_MODEL.md`; verify roles with `supabase db diff` |
| Build runner conflicts after schema updates | Delete conflicting `.g.dart` and `.freezed.dart` files, then re-run `build_runner` |
