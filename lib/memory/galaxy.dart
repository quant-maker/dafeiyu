/// 星图的布局：力导向 + 社区聚类，全是纯计算（见 test/galaxy_test.dart）。
///
/// 坐标一律归一化到 0..1，画的时候再乘画布尺寸，这样换屏幕、换缩放都不用重算。
library;

import 'dart:math' as math;

class GalaxyNode {
  final int id;
  final String label;
  final String kind;
  final double importance;
  final double strength;

  /// 首次出现 / 最近被点亮，用来做时间滑杆。
  final int firstSeen;
  final int lastTouched;

  double x;
  double y;
  double vx = 0;
  double vy = 0;

  /// 布局时被钉住（比如「主人」总在中心）。
  bool pinned = false;

  GalaxyNode({
    required this.id,
    required this.label,
    required this.kind,
    this.importance = 3,
    this.strength = 1,
    this.firstSeen = 0,
    this.lastTouched = 0,
    this.x = 0,
    this.y = 0,
  });

  /// 半径：越重要、越常被点亮，星越大。
  double get radius => 4 + 10 * ((importance / 5).clamp(0.0, 1.0)) * strength.clamp(0.3, 1.5);

  /// 亮度：久不碰的星要暗下去，但不消失。
  double get alpha => 0.25 + 0.75 * strength.clamp(0.0, 1.0);
}

class GalaxyLink {
  final int src;
  final int dst;
  final double weight;

  const GalaxyLink({required this.src, required this.dst, this.weight = 1});
}

class GalaxyLayout {
  final List<GalaxyNode> nodes;
  final List<GalaxyLink> links;

  GalaxyLayout({required this.nodes, required this.links});

  /// Fruchterman–Reingold 的简化版：斥力 k²/d，引力 d²/k，线性降温。
  ///
  /// 输入输出都在 0..1 空间里。用固定种子，保证同一份数据每次布局一致
  /// （否则每次打开星图都会跳一下）。
  void simulate({int iterations = 320, int seed = 20261125}) {
    if (nodes.isEmpty) return;
    final rng = math.Random(seed);
    final n = nodes.length;

    // 初始位置：黄金角螺旋，避免全部重叠在原点。
    for (var i = 0; i < n; i++) {
      if (nodes[i].pinned) continue;
      final t = i * 2.399963229728653;
      final r = 0.08 + 0.42 * math.sqrt((i + 0.5) / n);
      nodes[i].x = 0.5 + r * math.cos(t);
      nodes[i].y = 0.5 + r * math.sin(t);
    }
    for (final p in nodes) {
      if (!p.pinned) continue;
      p.x = 0.5;
      p.y = 0.5;
    }

    final k = 0.55 / math.sqrt(n.toDouble());
    final byId = {for (final n in nodes) n.id: n};

    for (var step = 0; step < iterations; step++) {
      final temp = 0.12 * (1 - step / iterations) + 0.004;
      // 斥力：所有节点两两推。
      for (var i = 0; i < n; i++) {
        final a = nodes[i];
        for (var j = i + 1; j < n; j++) {
          final b = nodes[j];
          var dx = a.x - b.x;
          var dy = a.y - b.y;
          var d2 = dx * dx + dy * dy;
          if (d2 < 1e-6) {
            dx = (rng.nextDouble() - 0.5) * 0.01;
            dy = (rng.nextDouble() - 0.5) * 0.01;
            d2 = dx * dx + dy * dy + 1e-6;
          }
          final d = math.sqrt(d2);
          final f = (k * k) / d;
          final ux = dx / d;
          final uy = dy / d;
          a.vx += ux * f;
          a.vy += uy * f;
          b.vx -= ux * f;
          b.vy -= uy * f;
        }
      }
      // 引力：有边的互相拉，权重高的拉得紧。
      for (final l in links) {
        final a = byId[l.src];
        final b = byId[l.dst];
        if (a == null || b == null) continue;
        var dx = a.x - b.x;
        var dy = a.y - b.y;
        var d = math.sqrt(dx * dx + dy * dy);
        if (d < 1e-6) {
          dx = (rng.nextDouble() - 0.5) * 0.01;
          dy = (rng.nextDouble() - 0.5) * 0.01;
          d = math.sqrt(dx * dx + dy * dy) + 1e-6;
        }
        final f = (d * d) / k * (0.4 + 0.15 * l.weight.clamp(0.2, 5.0));
        final ux = dx / d;
        final uy = dy / d;
        a.vx -= ux * f;
        a.vy -= uy * f;
        b.vx += ux * f;
        b.vy += uy * f;
      }
      // 向心力：别让整张图飘走。
      for (final p in nodes) {
        if (p.pinned) continue;
        p.vx += (0.5 - p.x) * 0.6;
        p.vy += (0.5 - p.y) * 0.6;
        final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
        final cap = temp * 60;
        if (speed > cap && speed > 1e-9) {
          p.vx = p.vx / speed * cap;
          p.vy = p.vy / speed * cap;
        }
        p.x += p.vx;
        p.y += p.vy;
        p.vx = 0;
        p.vy = 0;
      }
    }
    _normalize();
  }

  /// 收拢到 0.06..0.94，留出边距。
  void _normalize() {
    if (nodes.isEmpty) return;
    var minX = nodes.first.x, maxX = nodes.first.x;
    var minY = nodes.first.y, maxY = nodes.first.y;
    for (final n in nodes) {
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.y > maxY) maxY = n.y;
    }
    final w = (maxX - minX).abs() < 1e-6 ? 1.0 : maxX - minX;
    final h = (maxY - minY).abs() < 1e-6 ? 1.0 : maxY - minY;
    final s = 0.88 / math.max(w, h);
    for (final n in nodes) {
      n.x = 0.5 + (n.x - (minX + maxX) / 2) * s;
      n.y = 0.5 + (n.y - (minY + maxY) / 2) * s;
    }
  }
}

/// 社区发现：标签传播。返回 节点 id → 社区 id（0..k-1）。
///
/// 只用来给星座上色、给「这是哪一簇」一个名字，不追求最优划分。
Map<int, int> detectCommunities(List<GalaxyNode> nodes, List<GalaxyLink> links, {int maxRounds = 12}) {
  final label = <int, int>{for (final n in nodes) n.id: n.id};
  if (nodes.isEmpty) return const {};
  final adj = <int, List<int>>{};
  for (final l in links) {
    if (!label.containsKey(l.src) || !label.containsKey(l.dst)) continue;
    adj.putIfAbsent(l.src, () => []).add(l.dst);
    adj.putIfAbsent(l.dst, () => []).add(l.src);
  }
  final order = nodes.map((n) => n.id).toList();
  for (var round = 0; round < maxRounds; round++) {
    var changed = false;
    for (final id in order) {
      final neighbours = adj[id];
      if (neighbours == null || neighbours.isEmpty) continue;
      final tally = <int, int>{};
      for (final nb in neighbours) {
        final l = label[nb]!;
        tally[l] = (tally[l] ?? 0) + 1;
      }
      var best = label[id]!;
      var bestCount = tally[best] ?? 0;
      tally.forEach((k, v) {
        if (v > bestCount || (v == bestCount && k < best)) {
          best = k;
          bestCount = v;
        }
      });
      if (best != label[id]) {
        label[id] = best;
        changed = true;
      }
    }
    if (!changed) break;
  }
  // 压缩成 0..k-1。
  final ids = <int, int>{};
  final out = <int, int>{};
  for (final id in order) {
    final l = label[id]!;
    ids.putIfAbsent(l, () => ids.length);
    out[id] = ids[l]!;
  }
  return out;
}
