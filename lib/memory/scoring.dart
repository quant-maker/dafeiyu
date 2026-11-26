library;

import 'dart:math' as math;
import 'dart:typed_data';

/// 记忆打分的纯函数集合。刻意不依赖数据库与 Flutter，方便单测。
///
/// 参考 Generative Agents 的 recency × importance × relevance，加两项：
///  - 重复提及（同一件事被说多次，说明重要）
///  - 时间衰减（久未触碰的星变暗，但不删）

/// 半衰期 14 天的新鲜度：今天 1.0，两周前 0.5，一个月前 0.25。
double recencyScore(DateTime at, DateTime now, {double halfLifeDays = 14}) {
  final days = now.difference(at).inSeconds / 86400.0;
  if (days <= 0) return 1.0;
  return math.pow(0.5, days / halfLifeDays).toDouble();
}

/// 记忆强度衰减。τ 越大衰减越慢（人 180 天、项目 90 天、琐事 7 天）。
/// 下限 0.15：星变暗但不会消失（可逆，绝不删数据）。
double decayStrength(double strength, Duration elapsed, {Duration tau = const Duration(days: 90)}) {
  final ratio = elapsed.inSeconds / math.max(1, tau.inSeconds);
  final next = strength * math.exp(-ratio);
  return next < 0.15 ? 0.15 : (next > 1.0 ? 1.0 : next);
}

/// 被想起一次的回涨。
double reinforce(double strength, {double delta = 0.3}) {
  final next = strength + delta;
  return next > 1.0 ? 1.0 : next;
}

/// 混合召回打分：相关 0.5、重要 0.2、新鲜 0.2、重复 0.1。
double hybridScore({
  required double relevance,
  required double importance,
  required double recency,
  required double repetition,
}) {
  double c(double v) => v.isNaN ? 0 : (v < 0 ? 0 : (v > 1 ? 1 : v));
  return 0.5 * c(relevance) + 0.2 * c(importance) + 0.2 * c(recency) + 0.1 * c(repetition);
}

/// 余弦相似度（double）。
double cosine(List<double> a, List<double> b) {
  final n = math.min(a.length, b.length);
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < n; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

/// 向量压缩的默认维度。Qwen3-Embedding-4B 是 2560 维，截断到 1024 后
/// 仍保留绝大部分方向信息（MRL），存储从 10KB/条 降到 1KB/条。
const int kVectorDims = 1024;

/// 把向量缩放到单位长度。int8 量化假定分量落在 [-1,1]；不是所有 embedding
/// 端点都返回归一化向量（有的范数是几十），不先归一化就会被 127 截断丢方向。
/// 余弦本身对缩放不变，所以这步只影响精度，不影响排序语义。
List<double> unitVector(List<double> v) {
  var norm = 0.0;
  for (final x in v) {
    norm += x * x;
  }
  if (norm <= 1e-12) return v;
  final s = 1.0 / math.sqrt(norm);
  return <double>[for (final x in v) x * s];
}

/// 把 [List<double>] 压成 int8：截断到 [dims] 维后按最大值缩放。
/// 归一化向量的分量都在 [-1,1]，固定尺度 127 即可，省掉每条的 scale。
Uint8List quantizeVector(List<double> v, {int dims = kVectorDims}) {
  final n = math.min(v.length, dims);
  final out = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final q = (v[i] * 127.0).round();
    out[i] = q > 127 ? 127 : (q < -127 ? 129 : (q & 0xFF)); // -127..127，存补码
  }
  return out;
}

/// 与 [quantizeVector] 配套的余弦：把 int8 解回 [-1,1] 再算。
double cosineInt8(Uint8List a, Uint8List b) {
  final n = math.min(a.length, b.length);
  if (n == 0) return 0;
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < n; i++) {
    final x = a[i] > 127 ? (a[i] - 256) / 127.0 : a[i] / 127.0;
    final y = b[i] > 127 ? (b[i] - 256) / 127.0 : b[i] / 127.0;
    dot += x * y;
    na += x * x;
    nb += y * y;
  }
  if (na == 0 || nb == 0) return 0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}
