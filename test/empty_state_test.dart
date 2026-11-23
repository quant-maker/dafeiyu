import 'package:feiyu/ui/empty_state.dart';
import 'package:feiyu/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders samples and reports the tapped one', (
    WidgetTester tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: EmptyState(
            samples: const <String>['今天有什么好玩的', '帮我看看这张图', '你还记得我吗'],
            onSample: (String s) => tapped = s,
            buildTag: 'b4',
          ),
        ),
      ),
    );

    expect(find.text('今天有什么好玩的'), findsOneWidget);
    expect(find.text('帮我看看这张图'), findsOneWidget);
    expect(find.text('你还记得我吗'), findsOneWidget);

    await tester.tap(find.text('今天有什么好玩的'));
    await tester.pump();
    expect(tapped, '今天有什么好玩的');

    expect(find.text('🐟'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
