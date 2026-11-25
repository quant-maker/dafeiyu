import 'package:feiyu/memory/digest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractJsonArray', () {
    test('passes through a clean array', () {
      expect(extractJsonArray('[1,2]'), '[1,2]');
    });

    test('strips ```json fences and prose', () {
      const raw = '好的，结果如下：\n```json\n[{"a":1}]\n```\n需要再说吗？';
      expect(extractJsonArray(raw), '[{"a":1}]');
    });

    test('handles brackets inside strings', () {
      const raw = '前言 [{"body":"他说 [重要] 的事"}]]';
      expect(extractJsonArray(raw), '[{"body":"他说 [重要] 的事"}]');
    });

    test('returns empty array when there is none', () {
      expect(extractJsonArray('没有值得记的。'), '[]');
    });
  });

  group('parseEpisodeDrafts', () {
    test('reads title, body and importance', () {
      const raw = '[{"title":"改记忆库","body":"他决定用 sqlite 重做记忆。","importance":4}]';
      final out = parseEpisodeDrafts(raw);
      expect(out, hasLength(1));
      expect(out.first.title, '改记忆库');
      expect(out.first.body, '他决定用 sqlite 重做记忆。');
      expect(out.first.importance, 4);
    });

    test('clamps and coerces importance', () {
      const raw = '[{"title":"a","body":"甲","importance":9},'
          '{"title":"b","body":"乙","importance":"0"},'
          '{"title":"c","body":"丙","importance":"x"}]';
      final out = parseEpisodeDrafts(raw);
      expect(out.map((e) => e.importance).toList(), [5, 1, 3]);
    });

    test('skips entries without body and auto-titles', () {
      const raw = '[{"title":"空"},{"body":"他今天把 v0.15.8 发了出去，签名没变。"}]';
      final out = parseEpisodeDrafts(raw);
      expect(out, hasLength(1));
      expect(out.first.title, startsWith('他今天把'));
      expect(out.first.title.length, lessThanOrEqualTo(14));
    });

    test('falls back to the raw text when json is broken', () {
      const raw = '```\n他答应了明天给我看星图。\n```';
      final out = parseEpisodeDrafts(raw);
      expect(out, hasLength(1));
      expect(out.first.body, '他答应了明天给我看星图。');
    });

    test('empty output means nothing to remember', () {
      expect(parseEpisodeDrafts('[]'), isEmpty);
      expect(parseEpisodeDrafts('   '), isEmpty);
    });
  });

  group('parseFactLines', () {
    test('reads a json string array', () {
      expect(parseFactLines('["他怕冷","他周日不上班"]'), ['他怕冷', '他周日不上班']);
    });

    test('reads an object array', () {
      expect(parseFactLines('[{"text":"他养了一只猫"}]'), ['他养了一只猫']);
    });

    test('falls back to bullet lines', () {
      const raw = '- 他在改记忆系统\n- 他讨厌被问"还有什么可以帮您"';
      expect(parseFactLines(raw), ['他在改记忆系统', '他讨厌被问"还有什么可以帮您"']);
    });
  });

  group('prompts', () {
    test('carry the KEEP/DROP rules and the transcript', () {
      final p = episodeExtractionPrompt('主人：我用 sqlite 吧');
      expect(p, contains('第一人称'));
      expect(p, contains('不要写：寒暄'));
      expect(p, contains('主人：我用 sqlite 吧'));
      expect(p, contains('JSON 数组'));
    });

    test('day card prompt lists every fragment', () {
      final p = dayCardPrompt(dayLabel: '11月25日', episodes: const ['甲事', '乙事']);
      expect(p, contains('11月25日'));
      expect(p, contains('- 甲事'));
      expect(p, contains('- 乙事'));
    });

    test('cleanModelText removes fences and pleasantries', () {
      expect(cleanModelText('```\n正文\n```'), '正文');
      expect(cleanModelText('好的，以下是日记：\n正文开始'), '正文开始');
    });
  });
}
