import 'package:feiyu/main.dart';
import 'package:feiyu/ui/surfaces.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('about card shows the self-check block and privacy copy', (tester) async {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: SettingsPage(
          initial: Settings(
            baseUrl: 'https://x/v1',
            apiKey: '',
            model: 'm',
            persona: 'p',
          ),
          memory: Memory(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('build='), findsWidgets);
    expect(find.textContaining('key长度='), findsOneWidget);
    expect(
      find.text('所有数据只存在这台设备上：Key、对话、记忆都不经过任何第三方服务器。'),
      findsOneWidget,
    );
    expect(find.byType(SectionCard), findsNWidgets(7));
    expect(tester.takeException(), isNull);
  });
}
