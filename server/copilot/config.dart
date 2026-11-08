import 'dart:io';

class CopilotConfig {
  CopilotConfig(this.values);
  final Map<String, String> values;

  static Future<CopilotConfig> load(String filename) async {
    final file = File(filename);
    final values = <String, String>{};
    if (await file.exists()) {
      for (final line in await file.readAsLines()) {
        final match = RegExp(
          r'^\s*(?:export\s+)?([A-Z_0-9]+)\s*=\s*(.*)$',
        ).firstMatch(line);
        if (match == null) continue;
        var value = match[2]!.trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        } else {
          value = value.split(' #').first.trim();
        }
        values[match[1]!] = value;
      }
    }
    values.addAll(Platform.environment);
    return CopilotConfig(values);
  }

  String get key => values['OPENAI_API_KEY'] ?? values['OPEN_AI_KEY'] ?? '';
  String get model => values['OPENAI_MODEL'] ?? 'gpt-5.4';
  String get voiceModel => values['OPENAI_VOICE_MODEL'] ?? 'gpt-realtime';
  String get host => values['COPILOT_HOST'] ?? '127.0.0.1';
  int get port => int.tryParse(values['COPILOT_PORT'] ?? '') ?? 8787;
  String get dataPath => values['COPILOT_DATA_DIR'] ?? '.copilot-data';
  String get supabaseUrl =>
      values['SUPABASE_URL'] ?? values['NEXT_PUBLIC_SUPABASE_URL'] ?? '';
  String get anonKey =>
      values['SUPABASE_ANON_KEY'] ??
      values['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
      '';
  bool get localOwner => values['COPILOT_LOCAL_OWNER'] == 'true';
  List<String> get origins => (values['COPILOT_ALLOWED_ORIGINS'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  bool allowsOrigin(String? origin) {
    if (origin == null) return true;
    final uri = Uri.tryParse(origin);
    return origins.contains(origin) ||
        (uri != null &&
            ['localhost', '127.0.0.1'].contains(uri.host) &&
            uri.scheme == 'http');
  }
}
