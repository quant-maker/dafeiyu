import 'package:feiyu/ui/surfaces.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:feiyu/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('gallery renders every component without exceptions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionCard(
              title: '模型',
              subtitle: '选择对话使用的模型',
              trailing: GhostIconButton(
                icon: Icons.refresh,
                tooltip: '刷新',
                onPressed: () {},
              ),
              children: <Widget>[
                SectionHeader(label: '基础设置'),
                SettingsRow(
                  label: 'Base URL',
                  description: 'OpenAI 兼容接口地址',
                  child: const SizedBox(height: 24),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    const Pill(label: 'neutral'),
                    const Pill(label: 'primary', tone: PillTone.primary),
                    const Pill(label: 'success', tone: PillTone.success),
                    const Pill(label: 'danger', tone: PillTone.danger),
                    const Pill(label: 'selected', selected: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: <Widget>[
                StatusDot(color: AppPalette.mint),
                SizedBox(width: 8),
                StatusDot(color: AppPalette.danger, glow: true),
                SizedBox(width: 8),
                StatusDot(color: AppPalette.primary, pulse: true),
              ],
            ),
            const SizedBox(height: 16),
            const GhostIconButton(
              icon: Icons.add_photo_alternate_outlined,
              tooltip: '发图片',
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: '保存', icon: Icons.check, onPressed: () {}),
            const SizedBox(height: 12),
            const PrimaryButton(label: '保存中', loading: true),
            const SizedBox(height: 16),
            InlineNotice(
              tone: NoticeTone.danger,
              message: '请求失败，请稍后重试',
              onDismiss: () {},
            ),
            const SizedBox(height: 12),
            const InlineNotice(
              tone: NoticeTone.info,
              message: '提示信息',
            ),
            const SizedBox(height: 12),
            const InlineNotice(
              tone: NoticeTone.success,
              message: '已保存',
            ),
          ],
        ),
      ),
    );

    // StatusDot(pulse: true) animates forever; never use pumpAndSettle here.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('InlineNotice dismiss control fires callback', (
    WidgetTester tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      _app(
        InlineNotice(
          tone: NoticeTone.danger,
          message: '出错了',
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('GhostIconButton is discoverable by tooltip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GhostIconButton(
          icon: Icons.add_photo_alternate_outlined,
          tooltip: '发图片',
          onPressed: () {},
        ),
      ),
    );

    expect(find.byTooltip('发图片'), findsOneWidget);
    expect(find.byType(GhostIconButton), findsOneWidget);
  });

  testWidgets('Pill with success tone renders its label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Pill(label: 'x', tone: PillTone.success),
      ),
    );

    expect(find.text('x'), findsOneWidget);
  });
}
