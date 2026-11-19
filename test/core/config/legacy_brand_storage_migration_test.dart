import 'package:alphajournal/core/config/legacy_brand_storage_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('moves legacy local values without replacing current values', () async {
    SharedPreferences.setMockInitialValues({
      'tradex_theme_v1': 'dark',
      'tradex_flags_v1': <String>['one', 'two'],
      'tradex_count_v1': 4,
      'alphajournal_theme_v1': 'light',
    });

    await LegacyBrandStorageMigration.run();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('alphajournal_theme_v1'), 'light');
    expect(preferences.getStringList('alphajournal_flags_v1'), <String>[
      'one',
      'two',
    ]);
    expect(preferences.getInt('alphajournal_count_v1'), 4);
    expect(
      preferences.getKeys().where((key) => key.startsWith('tradex')),
      isEmpty,
    );
  });
}
