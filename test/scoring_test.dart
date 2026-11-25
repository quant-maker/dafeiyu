import 'dart:typed_data';

import 'package:feiyu/memory/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int daysAgo) =>
    DateTime(2026, 6, 1).subtract(Duration(days: daysAgo));

void main() {
  group('recency', () {
    test('今天满分，两个半衰期后四分之一', () {
      final now = at(0);
      expect(recencyScore(now, now), 1.0);
      expect(recencyScore(at(14), now), closeTo(0.5, 1e-9));
      expect(recencyScore(at(28), now), closeTo(0.25, 1e-9));
    });

    test('未来时间戳不溢出', () {
      expect(recencyScore(at(-5), at(0)), 1.0);
    });
  });

  group('decay', () {
    test('一个 τ 后衰减到 1/e', () {
      final s = decayStrength(1.0, const Duration(days: 90));
      expect(s, closeTo(0.3679, 1e-3));
    });

    test('有下限，星永远不会灭', () {
      expect(decayStrength(1.0, const Duration(days: 3650)), 0.15);
      expect(decayStrength(0.2, const Duration(days: 3650)), 0.15);
    });

    test('reinforce 封顶 1.0', () {
      expect(reinforce(0.5), closeTo(0.8, 1e-9));
      expect(reinforce(0.95), 1.0);
    });
  });

  group('hybridScore', () {
    test('权重按 0.5/0.2/0.2/0.1 叠加', () {
      final s = hybridScore(
        relevance: 1,
        importance: 0.5,
        recency: 0.5,
        repetition: 0.0,
      );
      expect(s, closeTo(0.5 + 0.1 + 0.1, 1e-9));
    });

    test('脏输入被夹住而不是把排序带歪', () {
      expect(
        hybridScore(
          relevance: double.nan,
          importance: 9,
          recency: -3,
          repetition: 0.5,
        ),
        closeTo(0.2 + 0.05, 1e-9),
      );
    });
  });

  group('quantize', () {
    test('截断到目标维度并按 127 缩放', () {
      final v = List<double>.filled(2000, 0.5);
      final q = quantizeVector(v, dims: 8);
      expect(q.length, 8);
      expect(q.first, 64); // 0.5 * 127 ≈ 64（向零取整）
    });

    test('-1 存成 0x81 补码，不是 127', () {
      expect(quantizeVector(<double>[-1], dims: 1)[0], 129);
      expect(quantizeVector(<double>[1], dims: 1)[0], 127);
    });

    test('int8 余弦与 double 余弦基本一致', () {
      final a = <double>[0.6, -0.8, 0.0];
      final b = <double>[0.8, 0.6, 0.0];
      final qa = quantizeVector(a, dims: 3);
      final qb = quantizeVector(b, dims: 3);
      expect(qa, isA<Uint8List>());
      expect(cosineInt8(qa, qb), closeTo(cosine(a, b), 1e-3));
    });

    test('零向量不除零', () {
      expect(cosineInt8(quantizeVector(<double>[0, 0], dims: 2), quantizeVector(<double>[0, 0], dims: 2)), 0);
    });
  });
}
