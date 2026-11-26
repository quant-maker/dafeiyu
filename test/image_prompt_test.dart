import 'package:feiyu/comfy/prompt.dart';
import 'package:flutter_test/flutter_test.dart';

/// SD-Turbo's text encoder is English-only; a Chinese prompt comes back as a
/// gray wash. These tests pin down the translate-once behaviour.
void main() {
  test('English prompts are sent untouched', () async {
    int calls = 0;
    final ImagePromptTranslator prompts = ImagePromptTranslator(
      translate: (String text) async {
        calls++;
        return 'should not be used';
      },
    );

    expect(
      await prompts.english('a small whale by the window, night, warm lamp'),
      'a small whale by the window, night, warm lamp',
    );
    expect(calls, 0);
  });

  test('Chinese prompts are translated once and cached', () async {
    int calls = 0;
    final ImagePromptTranslator prompts = ImagePromptTranslator(
      translate: (String text) async {
        calls++;
        expect(text, '一只小鲸鱼');
        return 'a small whale, best quality, highly detailed\n';
      },
    );

    final String first = await prompts.english('一只小鲸鱼');
    final String second = await prompts.english('  一只小鲸鱼 ');
    expect(first, 'a small whale, best quality, highly detailed');
    expect(second, first);
    expect(calls, 1);
  });

  test('a failed translation falls back to the original text', () async {
    final ImagePromptTranslator prompts = ImagePromptTranslator(
      translate: (String text) async => throw StateError('offline'),
    );

    expect(await prompts.english('水墨山水'), '水墨山水');
    expect(prompts.cachedCount, 0);
  });

  test('a translator that answers in Chinese is not trusted', () async {
    final ImagePromptTranslator prompts = ImagePromptTranslator(
      translate: (String text) async => '一只鲸鱼',
    );

    expect(await prompts.english('一只鲸鱼'), '一只鲸鱼');
    expect(prompts.cachedCount, 0);
  });
}
