import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feiyu/ui/composer.dart';

void main() {
  testWidgets('鍥炶溅鍙戦€佸悗杈撳叆妗嗚繕鐣欑潃鐒︾偣', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    final FocusNode focus = FocusNode();
    final List<String> sent = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Composer(
            controller: controller,
            focusNode: focus,
            busy: false,
            listening: false,
            onImage: () {},
            onMic: () {},
            onSend: () {},
            onStop: () {},
            onSubmitted: sent.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '鍦ㄥ悧');
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    // A `send`-action submit normally drops focus; the composer has to win it
    // back or every message on the web needs a click first.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump();

    expect(sent, <String>['鍦ㄥ悧']);
    expect(focus.hasFocus, isTrue, reason: '鍙戦€佸悗鐒︾偣搴旂暀鍦ㄨ緭鍏ユ');
    focus.dispose();
    controller.dispose();
  });

  testWidgets('鍙戦€佹椂娌℃湁鐒︾偣灏变笉璇ユ姠', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    final FocusNode focus = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Composer(
            controller: controller,
            focusNode: focus,
            busy: false,
            listening: false,
            onImage: () {},
            onMic: () {},
            onSend: () {},
            onStop: () {},
            onSubmitted: (_) {},
          ),
        ),
      ),
    );

    expect(focus.hasFocus, isFalse);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    focus.dispose();
    controller.dispose();
  });
}
