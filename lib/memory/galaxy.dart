/// 星图的布局：力导向 + 社区聚类，全是纯计算（见 test/galaxy3d_test.dart）。
///
/// 坐标一律归一化到 0..1 的三维空间，画的时候再做透视投影，这样换屏幕、
/// 换视角、换缩放都不用重算。
library;

import 'dart:math' as math;

import 'dart:ui' show Offset, Size;

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
  double z;
  double vx = 0;
  double vy = 0;
  double vz = 0;

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
    this.z = 0,
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

  /// Fruchterman–Reingold 的简化版，放在三维里跑：斥力 k²/d、引力 d²/k、线性降温。
  ///
  /// 用固定种子，保证同一份数据每次布局一致（否则每次打开星图都会跳一下）。
  void simulate({int iterations = 320, int seed = 20261125}) {
    if (nodes.isEmpty) return;
    final rng = math.Random(seed);
    final n = nodes.length;

    // 初始位置：斐波那契球面，天然是个球，不会全挤在一层里。
    final golden = math.pi * (3 - math.sqrt(5));
    for (var i = 0; i < n; i++) {
      if (nodes[i].pinned) continue;
      final t = i * golden;
      final u = n == 1 ? 0.5 : (i + 0.5) / n;
      final r = 0.12 + 0.36 * math.pow(u, 1 / 3).toDouble();
      final phi = math.acos(1 - 2 * u);
      nodes[i].x = 0.5 + r * math.sin(phi) * math.cos(t);
      nodes[i].y = 0.5 + r * math.sin(phi) * math.sin(t);
      nodes[i].z = 0.5 + r * math.cos(phi);
    }
    for (final p in nodes) {
      if (!p.pinned) continue;
      p.x = 0.5;
      p.y = 0.5;
      p.z = 0.5;
    }

    final k = 0.55 / math.pow(n.toDouble(), 1 / 3);
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
          var dz = a.z - b.z;
          var d2 = dx * dx + dy * dy + dz * dz;
          if (d2 < 1e-6) {
            dx = (rng.nextDouble() - 0.5) * 0.01;
            dy = (rng.nextDouble() - 0.5) * 0.01;
            dz = (rng.nextDouble() - 0.5) * 0.01;
            d2 = dx * dx + dy * dy + dz * dz + 1e-6;
          }
          final d = math.sqrt(d2);
          final f = (k * k) / d;
          final ux = dx / d;
          final uy = dy / d;
          final uz = dz / d;
          a.vx += ux * f;
          a.vy += uy * f;
          a.vz += uz * f;
          b.vx -= ux * f;
          b.vy -= uy * f;
          b.vz -= uz * f;
        }
      }
      // 引力：有边的互相拉，权重高的拉得紧。
      for (final l in links) {
        final a = byId[l.src];
        final b = byId[l.dst];
        if (a == null || b == null) continue;
        var dx = a.x - b.x;
        var dy = a.y - b.y;
        var dz = a.z - b.z;
        var d = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (d < 1e-6) {
          dx = (rng.nextDouble() - 0.5) * 0.01;
          dy = (rng.nextDouble() - 0.5) * 0.01;
          dz = (rng.nextDouble() - 0.5) * 0.01;
          d = math.sqrt(dx * dx + dy * dy + dz * dz) + 1e-6;
        }
        final f = (d * d) / k * (0.4 + 0.15 * l.weight.clamp(0.2, 5.0));
        final ux = dx / d;
        final uy = dy / d;
        final uz = dz / d;
        a.vx -= ux * f;
        a.vy -= uy * f;
        a.vz -= uz * f;
        b.vx += ux * f;
        b.vy += uy * f;
        b.vz += uz * f;
      }
      // 向心力：别让整个星系飘走。
      for (final p in nodes) {
        if (p.pinned) continue;
        p.vx += (0.5 - p.x) * 0.6;
        p.vy += (0.5 - p.y) * 0.6;
        p.vz += (0.5 - p.z) * 0.6;
        final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy + p.vz * p.vz);
        final cap = temp * 60;
        if (speed > cap && speed > 1e-9) {
          p.vx = p.vx / speed * cap;
          p.vy = p.vy / speed * cap;
          p.vz = p.vz / speed * cap;
        }
        p.x += p.vx;
        p.y += p.vy;
        p.z += p.vz;
        p.vx = 0;
        p.vy = 0;
        p.vz = 0;
      }
    }
    _normalize();
    _applyHierarchy(seed: seed);
  }

  /// 层级：把重要性分成三层，往三个半径上拉一点。
  ///
  /// 核心（最近常被提起的人、事）离中心近、正面、亮；旧事沉到外圈、背面、暗。
  /// 只拉六成，免得布局被摆成三个整齐的同心球——那样就不像星系了。
  void _applyHierarchy({int seed = 20261125}) {
    if (nodes.isEmpty) return;
    final ranked = List<GalaxyNode>.of(nodes)
      ..sort((a, b) {
        final sa = a.importance * 0.7 + a.strength * 0.3;
        final sb = b.importance * 0.7 + b.strength * 0.3;
        return sb.compareTo(sa);
      });
    final n = ranked.length;
    final rng = math.Random(seed ^ 0x5f3a);
    for (var i = 0; i < n; i++) {
      final node = ranked[i];
      if (node.pinned) continue;
      final tier = i < (n * 0.18).ceil()
          ? 0.30
          : i < (n * 0.55).ceil()
              ? 0.62
              : 0.95;
      final dx = node.x - 0.5, dy = node.y - 0.5, dz = node.z - 0.5;
      final len = math.sqrt(dx * dx + dy * dy + dz * dz);
      // 正好在球心的点没有方向，给它一个随机的。
      var ux = dx, uy = dy, uz = dz;
      if (len < 1e-4) {
        final a = rng.nextDouble() * math.pi * 2;
        final b = rng.nextDouble() * math.pi;
        ux = math.sin(b) * math.cos(a);
        uy = math.sin(b) * math.sin(a);
        uz = math.cos(b);
      } else {
        ux = dx / len;
        uy = dy / len;
        uz = dz / len;
      }
      const keep = 0.4; // 六成拉向目标半径
      final target = tier * (0.92 + 0.16 * rng.nextDouble());
      final r = len * (1 - keep) + target * keep;
      node.x = (0.5 + ux * r).clamp(0.06, 0.94);
      node.y = (0.5 + uy * r).clamp(0.06, 0.94);
      node.z = (0.5 + uz * r).clamp(0.06, 0.94);
    }
  }

  /// 收成一团：等比例缩放，保持球体不被压扁。
  void _normalize() {
    if (nodes.isEmpty) return;
    var minX = nodes.first.x, maxX = nodes.first.x;
    var minY = nodes.first.y, maxY = nodes.first.y;
    var minZ = nodes.first.z, maxZ = nodes.first.z;
    for (final n in nodes) {
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.y > maxY) maxY = n.y;
      if (n.z < minZ) minZ = n.z;
      if (n.z > maxZ) maxZ = n.z;
    }
    final w = (maxX - minX).abs() < 1e-6 ? 1.0 : maxX - minX;
    final h = (maxY - minY).abs() < 1e-6 ? 1.0 : maxY - minY;
    final d = (maxZ - minZ).abs() < 1e-6 ? 1.0 : maxZ - minZ;
    final s = 0.88 / math.max(w, math.max(h, d));
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final cz = (minZ + maxZ) / 2;
    for (final n in nodes) {
      n.x = 0.5 + (n.x - cx) * s;
      n.y = 0.5 + (n.y - cy) * s;
      n.z = 0.5 + (n.z - cz) * s;
    }
  }
}

/// 一个三维点投到屏幕上的结果。
class Projected {
  const Projected(this.screen, this.depth, this.scale);

  /// 屏幕坐标（像素）。
  final Offset screen;

  /// 旋转后的纵深：>0 朝观众，<0 在背后。用来排序和调亮度。
  final double depth;

  /// 透视缩放（近大远小）。
  final double scale;

  @override
  String toString() => 'Projected($screen, depth=$depth, scale=$scale)';
}

/// 把 0..1 空间里的点投到屏幕上。
///
/// 绕 Y 轴转 [yaw]、绕 X 轴抬 [pitch]，然后做一个简单的针孔透视。
/// 纯函数，方便单测：同一组参数必须永远得到同一个结果。
Projected projectPoint({
  required double x,
  required double y,
  required double z,
  required Size size,
  double yaw = 0,
  double pitch = 0,
  double spread = 1.0,
  double focal = 1.9,
}) {
  // 以中心为原点，范围约 -0.5..0.5。
  final cx = x - 0.5;
  final cy = y - 0.5;
  final cz = z - 0.5;

  final cosY = math.cos(yaw), sinY = math.sin(yaw);
  final x1 = cx * cosY + cz * sinY;
  final z1 = -cx * sinY + cz * cosY;

  final cosP = math.cos(pitch), sinP = math.sin(pitch);
  final y2 = cy * cosP - z1 * sinP;
  final z2 = cy * sinP + z1 * cosP;

  // 近大远小：focal / (focal - z2)。
  final denom = math.max(0.35, focal - z2);
  final scale = focal / denom;

  final unit = size.shortestSide * 0.62 * spread;
  final screen = Offset(
    size.width / 2 + x1 * unit * scale,
    size.height / 2 + y2 * unit * scale,
  );
  return Projected(screen, z2, scale);
}

/// 每个社区的重心与半径，用来画「信息交换密集区」的那团光。
class ClusterBlob {
  const ClusterBlob({
    required this.community,
    required this.cx,
    required this.cy,
    required this.cz,
    required this.radius,
    required this.count,
  });

  final int community;
  final double cx;
  final double cy;
  final double cz;

  /// 归一化空间里的半径（0..1）。
  final double radius;
  final int count;
}

List<ClusterBlob> clusterBlobs(
  List<GalaxyNode> nodes,
  Map<int, int> communities,
) {
  final sums = <int, List<double>>{};
  for (final n in nodes) {
    final c = communities[n.id] ?? 0;
    final acc = sums.putIfAbsent(c, () => <double>[0, 0, 0, 0]);
    acc[0] += n.x;
    acc[1] += n.y;
    acc[2] += n.z;
    acc[3] += 1;
  }
  final blobs = <ClusterBlob>[];
  sums.forEach((community, acc) {
    final count = acc[3].round();
    if (count <= 0) return;
    final cx = acc[0] / count;
    final cy = acc[1] / count;
    final cz = acc[2] / count;
    // 半径按到重心的最大距离算，再留一点余量。
    var maxD = 0.06;
    for (final n in nodes) {
      if ((communities[n.id] ?? 0) != community) continue;
      final dx = n.x - cx, dy = n.y - cy, dz = n.z - cz;
      final d = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (d > maxD) maxD = d;
    }
    blobs.add(ClusterBlob(
      community: community,
      cx: cx,
      cy: cy,
      cz: cz,
      radius: (maxD * 1.35).clamp(0.06, 0.42),
      count: count,
    ));
  });
  blobs.sort((a, b) => b.count.compareTo(a.count));
  return blobs;
}

/// 社区发现：标签传播。返回 节点 id → 社区 id（0..k-1）。
///
/// 只用来给星座上色、给「这是哪一簇」一个名字，不追求最优划分。
Map<int, int> detectCommunities(List<GalaxyNode> nodes, List<GalaxyLink> links,
    {int maxRounds = 12}) {
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
