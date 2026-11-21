const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = process.cwd();
const read = (relativePath) =>
  fs.readFileSync(path.join(root, relativePath), 'utf8');

test('native identity and AlphaJournal callbacks are consistent', () => {
  const constants = read('lib/core/config/app_constants.dart');
  assert.match(read('pubspec.yaml'), /^name: alphajournal$/m);
  assert.match(read('lib/app.dart'), /class AlphaJournalApp extends StatefulWidget/);
  assert.match(constants, /https:\/\/app\.alphajournal\.in\/auth\/callback/);
  assert.match(constants, /alphajournal:\/\/auth\/callback/);
  assert.match(
    constants,
    /https:\/\/app\.alphajournal\.in\/auth\/forgot-password/,
  );

  for (const file of [
    'lib/features/auth/presentation/pages/login_page.dart',
    'lib/features/auth/presentation/pages/signup_page.dart',
    'lib/features/auth/data/services/supabase_auth_backend_service.dart',
    'lib/features/auth/data/repositories/supabase_auth_otp_repository.dart',
    'lib/features/settings/data/repositories/profile_settings_repository.dart',
  ]) {
    assert.doesNotMatch(read(file), /alphajournal:\/\/auth\/callback/);
  }

  assert.match(read('supabase/config.toml'), /alphajournal:\/\/auth\/callback/);
  assert.doesNotMatch(read('supabase/config.toml'), /tradex:\/\//);

  const androidBuild = read('android/app/build.gradle.kts');
  assert.match(androidBuild, /applicationId = "com\.nk2552003\.alphajournal"/);
  assert.match(androidBuild, /namespace = "com\.nk2552003\.alphajournal"/);
  assert.match(
    read('ios/Runner.xcodeproj/project.pbxproj'),
    /PRODUCT_BUNDLE_IDENTIFIER = com\.nk2552003\.alphajournal;/,
  );
  assert.match(
    read('web/manifest.json'),
    /"id": "com\.nk2552003\.alphajournal"/,
  );
  assert.match(
    read('macos/Runner/Configs/AppInfo.xcconfig'),
    /PRODUCT_NAME = AlphaJournal/,
  );
  assert.match(read('windows/runner/main.cpp'), /L"AlphaJournal"/);
  assert.match(read('linux/runner/my_application.cc'), /"AlphaJournal"/);
  assert.equal(
    fs.existsSync(
      path.join(
        root,
        'android/app/src/main/kotlin/com/nk2552003/alphajournal/MainActivity.kt',
      ),
    ),
    true,
  );
});

test('mobile transports explicitly reject cleartext traffic', () => {
  const manifest = read('android/app/src/main/AndroidManifest.xml');
  assert.match(manifest, /android:usesCleartextTraffic="false"/);
  assert.match(manifest, /android:networkSecurityConfig="@xml\/network_security_config"/);
  assert.equal(
    (manifest.match(/<intent-filter android:autoVerify="true">/g) || []).length,
    6,
  );
  assert.match(
    read('android/app/src/main/res/xml/network_security_config.xml'),
    /cleartextTrafficPermitted="false"/,
  );

  const plist = read('ios/Runner/Info.plist');
  assert.match(plist, /<key>NSAppTransportSecurity<\/key>/);
  assert.match(plist, /<key>NSAllowsArbitraryLoads<\/key>\s*<false\/>/);
});

test('web deployment declares transport and content security headers', () => {
  const headers = read('web/_headers');
  assert.match(headers, /Strict-Transport-Security:/);
  assert.match(headers, /Content-Security-Policy:/);
  assert.match(headers, /frame-ancestors 'none'/);
  assert.match(headers, /object-src 'none'/);
  assert.match(headers, /script-src[^;]*https:\/\/www\.gstatic\.com/);
  assert.match(headers, /connect-src[^;]*https:\/\/www\.gstatic\.com/);
});

test('authenticated Edge Functions do not publish wildcard CORS', () => {
  const files = [
    'supabase/functions/admin-delete-user/index.ts',
    'supabase/functions/ai-chat/index.ts',
    'supabase/functions/ai-gateway/index.ts',
    'supabase/functions/ai-voice/index.ts',
    'supabase/functions/ai-voice/voice.ts',
    'supabase/functions/create-business-checkout/index.ts',
    'supabase/functions/note-ai-refactor/index.ts',
  ];
  for (const file of files) {
    assert.doesNotMatch(
      read(file),
      /Access-Control-Allow-Origin['"]?\s*:\s*['"]\*['"]/,
      file,
    );
  }
  assert.match(read('supabase/functions/_shared/cors.ts'), /PRODUCTION_ORIGINS/);
});

test('database migration removes implicit SECURITY DEFINER execution', () => {
  const migration = read(
    'supabase/migrations/20261119030000_security_hardening.sql',
  );
  assert.match(migration, /REVOKE CREATE ON SCHEMA public FROM PUBLIC/);
  assert.match(
    migration,
    /ALTER DEFAULT PRIVILEGES IN SCHEMA public[\s\S]*REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC/,
  );
  assert.match(migration, /public\.public_document\(text,\s*uuid\)/);
  assert.match(migration, /public\.is_admin_caller\(\)/);
});

test('Git ignore policy keeps build inputs and excludes local secrets', () => {
  const rootIgnore = read('.gitignore');
  const androidIgnore = read('android/.gitignore');
  const wrapperProperties = read(
    'android/gradle/wrapper/gradle-wrapper.properties',
  );

  assert.match(rootIgnore, /^\.env\.\*$/m);
  assert.match(rootIgnore, /^!\.env\.example$/m);
  assert.match(rootIgnore, /^assets\/config\/client\.env$/m);
  assert.match(rootIgnore, /^node_modules\/$/m);
  assert.match(rootIgnore, /^supabase\/\.temp\/$/m);
  assert.doesNotMatch(rootIgnore, /^!\.github\/\*\*$/m);
  assert.doesNotMatch(rootIgnore, /^!lib\/.*\*\*$/m);
  assert.doesNotMatch(rootIgnore, /android\/gradlew(?:\.bat)?$/m);
  assert.doesNotMatch(rootIgnore, /android\/.*gradle-wrapper\.jar$/m);
  assert.doesNotMatch(androidIgnore, /^\/gradlew(?:\.bat)?$/m);
  assert.doesNotMatch(androidIgnore, /^gradle-wrapper\.jar$/m);
  assert.match(
    wrapperProperties,
    /^distributionSha256Sum=[a-f0-9]{64}$/m,
  );
  assert.match(
    wrapperProperties,
    /distributionSha256Sum=b84e04fa845fecba48551f425957641074fcc00a88a84d2aae5808743b35fc85/,
  );
  for (const file of [
    'android/gradlew',
    'android/gradlew.bat',
    'android/gradle/wrapper/gradle-wrapper.jar',
  ]) {
    assert.equal(fs.existsSync(path.join(root, file)), true, file);
  }
  const wrapperHash = crypto
    .createHash('sha256')
    .update(
      fs.readFileSync(
        path.join(root, 'android/gradle/wrapper/gradle-wrapper.jar'),
      ),
    )
    .digest('hex');
  assert.equal(
    wrapperHash,
    '16caeaf66d57a0d1d2087fef6a97efa62de8da69afa5b908f40db35afc4342da',
  );
});
