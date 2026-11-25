import 'package:feiyu/memory/digest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('looksSensitive', () {
    test('catches money and credentials', () {
      expect(looksSensitive('我这个月工资到账了'), isTrue);
      expect(looksSensitive('银行卡尾号 4321'), isTrue);
      expect(looksSensitive('验证码是 889900'), isTrue);
    });

    test('catches health and relationship topics', () {
      expect(looksSensitive('医生给的诊断是焦虑症'), isTrue);
      expect(looksSensitive('他最近在办离婚'), isTrue);
    });

    test('leaves ordinary chatter alone', () {
      expect(looksSensitive('今天写完了记忆模块的存储层'), isFalse);
      expect(looksSensitive('她喜欢喝冰美式'), isFalse);
      expect(looksSensitive(''), isFalse);
      expect(looksSensitive('   '), isFalse);
    });

    test('every marker is non-empty and trimmed', () {
      for (final m in sensitiveMarkers) {
        expect(m.trim(), m);
        expect(m.isEmpty, isFalse);
      }
      expect(sensitiveMarkers.length, greaterThan(10));
    });
  });
}
