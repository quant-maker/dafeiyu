import 'package:flutter_test/flutter_test.dart';

import 'package:feiyu/companion/skills.dart';

void main() {
  group('Skill 等级', () {
    test('从 1 级开始，练够才升', () {
      final s = Skill(id: 'chat', name: '聊天');
      expect(s.level, 1);
      expect(s.levelProgress, 0);

      s.xp = Skill.xpForLevel(1) - 1;
      expect(s.level, 1);
      s.xp = Skill.xpForLevel(1);
      expect(s.level, 2);
    });

    test('进度条在当前等级内走', () {
      final s = Skill(id: 'draw', name: '画画');
      s.xp = Skill.xpForLevel(1);
      expect(s.level, 2);
      expect(s.levelProgress, 0);
      s.xp += Skill.xpForLevel(2) ~/ 2;
      expect(s.levelProgress, closeTo(.5, .01));
    });

    test('升级越来越慢', () {
      expect(Skill.xpForLevel(2), greaterThan(Skill.xpForLevel(1)));
      expect(Skill.xpForLevel(9), greaterThan(Skill.xpForLevel(8)));
    });
  });

  group('SkillBook', () {
    test('gain 会返回是否升级', () {
      final book = SkillBook.empty();
      // 画画一次 4 点；1 级要 20 点，所以前四次不升级，第五次升。
      for (var i = 0; i < 4; i++) {
        expect(book.gain('draw'), isFalse);
      }
      expect(book.gain('draw'), isTrue);
      expect(book.byId('draw').level, 2);
    });

    test('未知技能不会凭空加入', () {
      final book = SkillBook.empty();
      expect(book.gain('astrology'), isFalse);
      expect(book.all.any((s) => s.id == 'astrology'), isFalse);
    });

    test('提示里只列练过的技能', () {
      final book = SkillBook.empty();
      expect(book.promptLine(), contains('聊天'));
      expect(book.promptLine(), isNot(contains('画画')));
      book.gain('draw', xp: 40);
      final line = book.promptLine();
      expect(line, contains('画画 Lv'));
      expect(line, contains('本事'));
    });

    test('load 只恢复进度，不认文件里的目录', () async {
      final book = SkillBook.empty();
      book.gain('chat', xp: 100);
      final strongest = book.strongest;
      expect(strongest?.id, 'chat');
    });
  });
}
