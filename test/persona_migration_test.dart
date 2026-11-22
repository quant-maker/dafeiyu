import 'package:feiyu/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stored legacy default persona migrates to the new persona', () async {
    SharedPreferences.setMockInitialValues({
      'feiyu.settings.v3': '{"persona":${_json(kLegacyPresetPersona)},'
          '"baseUrl":"https://x/v1","apiKey":"k","model":"m"}',
    });

    final Settings s = await Settings.load();
    expect(s.persona, kPresetPersona);
  });

  test('a user-customised persona is left untouched', () async {
    SharedPreferences.setMockInitialValues({
      'feiyu.settings.v3': '{"persona":${_json('你是我专属的猫娘。')},'
          '"baseUrl":"https://x/v1","apiKey":"k","model":"m"}',
    });

    final Settings s = await Settings.load();
    expect(s.persona, '你是我专属的猫娘。');
  });

  test('missing persona key falls back to the new persona', () async {
    SharedPreferences.setMockInitialValues({'feiyu.settings.v3': '{}'});

    final Settings s = await Settings.load();
    expect(s.persona, kPresetPersona);
  });
}

/// Minimal JSON string encoder for the few characters used in the personas.
String _json(String value) {
  final String escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
  return '"$escaped"';
}
