import 'package:shared_preferences/shared_preferences.dart';

/// Moves local values written by pre-AlphaJournal builds to the current key
/// namespace. The migration is idempotent and never overwrites a newer value.
class LegacyBrandStorageMigration {
  const LegacyBrandStorageMigration._();

  static const String _legacyPrefix = 'tradex';
  static const String _currentPrefix = 'alphajournal';

  static Future<void> run() async {
    final preferences = await SharedPreferences.getInstance();
    final legacyKeys = preferences
        .getKeys()
        .where((key) => key.startsWith(_legacyPrefix))
        .toList(growable: false);

    for (final legacyKey in legacyKeys) {
      final currentKey =
          '$_currentPrefix${legacyKey.substring(_legacyPrefix.length)}';
      if (!preferences.containsKey(currentKey)) {
        await _copyValue(preferences, legacyKey, currentKey);
      }
      await preferences.remove(legacyKey);
    }
  }

  static Future<void> _copyValue(
    SharedPreferences preferences,
    String sourceKey,
    String destinationKey,
  ) async {
    final value = preferences.get(sourceKey);
    switch (value) {
      case bool boolValue:
        await preferences.setBool(destinationKey, boolValue);
      case int intValue:
        await preferences.setInt(destinationKey, intValue);
      case double doubleValue:
        await preferences.setDouble(destinationKey, doubleValue);
      case String stringValue:
        await preferences.setString(destinationKey, stringValue);
      case List<String> stringList:
        await preferences.setStringList(destinationKey, stringList);
      case null:
        break;
      default:
        throw StateError(
          'Unsupported local preference type for $sourceKey: ${value.runtimeType}',
        );
    }
  }
}
