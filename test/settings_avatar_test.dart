import 'package:feiyu/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old settings json without avatar loads with null avatar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'feiyu.settings.v3':
          '{"baseUrl":"http://x/v1","apiKey":"k","model":"m","persona":"p"}',
    });

    final Settings s = await Settings.load();
    expect(s.avatar, isNull);
  });

  test('save then load round-trips the base64 avatar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final Settings s = await Settings.load();
    s.avatar = 'ABC123';
    await s.save();

    final Settings t = await Settings.load();
    expect(t.avatar, 'ABC123');
  });
}
