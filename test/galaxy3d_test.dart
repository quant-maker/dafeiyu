import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:feiyu/memory/galaxy.dart';
import 'package:flutter_test/flutter_test.dart';

GalaxyNode _node(int id, {double importance = 3, double strength = 1}) => GalaxyNode(
      id: id,
      label: 'n$id',
      kind: 'topic',
      importance: importance,
      strength: strength,
      firstSeen: id * 1000,
    );

void main() {
  group('三维布局', () {
    List<GalaxyNode> build(int n) {
      final nodes = <GalaxyNode>[for (var i = 0; i < n; i++) _node(i)];
      final links = <GalaxyLink>[
        for (var i = 1; i < n; i++) GalaxyLink(src: i - 1, dst: i, weight: 1),
      ];
      GalaxyLayout(nodes: nodes, links: links).simulate(iterations: 120);
      return nodes;
    }

    test('三个轴都落在 0.06..0.94，且不是扁的', () {
      final nodes = build(60);
      var minZ = 1.0, maxZ = 0.0;
      for (final n in nodes) {
        expect(n.x, inInclusiveRange(0.06, 0.94));
        expect(n.y, inInclusiveRange(0.06, 0.94));
        expect(n.z, inInclusiveRange(0.06, 0.94));
        if (n.z < minZ) minZ = n.z;
        if (n.z > maxZ) maxZ = n.z;
      }
      // 纵深有厚度，才叫三维；太薄就退化成一张纸。
      expect(maxZ - minZ, greaterThan(0.3));
    });

    test('同一份数据布局稳定', () {
      final a = build(40);
      final b = build(40);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].x, b[i].x);
        expect(a[i].y, b[i].y);
        expect(a[i].z, b[i].z);
      }
    });

    test('被钉住的节点在正中心', () {
      final nodes = <GalaxyNode>[_node(1), _node(2), _node(3)];
      nodes.first.pinned = true;
      GalaxyLayout(nodes: nodes, links: const <GalaxyLink>[]).simulate(iterations: 40);
      expect(nodes.first.x, moreOrLessEquals(0.5, epsilon: 0.01));
      expect(nodes.first.y, moreOrLessEquals(0.5, epsilon: 0.01));
      expect(nodes.first.z, moreOrLessEquals(0.5, epsilon: 0.01));
    });

    test('层级：越重要的越靠内圈', () {
      final nodes = <GalaxyNode>[
        for (var i = 0; i < 40; i++) _node(i, importance: i < 8 ? 5.0 : 2.0, strength: 1),
      ];
      GalaxyLayout(nodes: nodes, links: const <GalaxyLink>[])
          .simulate(iterations: 80);
      double r(GalaxyNode n) {
        final dx = n.x - 0.5, dy = n.y - 0.5, dz = n.z - 0.5;
        return math.sqrt(dx * dx + dy * dy + dz * dz);
      }

      final core = nodes.take(8).map(r).reduce((a, b) => a + b) / 8;
      final outer = nodes.skip(8).map(r).reduce((a, b) => a + b) / 32;
      expect(core, lessThan(outer * 0.8));
    });
  });

  group('透视投影', () {
    const size = Size(400, 300);

    test('正中心的点投到画面中心', () {
      final p = projectPoint(x: .5, y: .5, z: .5, size: size);
      expect(p.screen.dx, moreOrLessEquals(200, epsilon: 0.01));
      expect(p.screen.dy, moreOrLessEquals(150, epsilon: 0.01));
      expect(p.depth, moreOrLessEquals(0, epsilon: 1e-9));
    });

    test('近大远小：z 大的点更近、缩放更大', () {
      final near = projectPoint(x: .5, y: .5, z: .9, size: size);
      final far = projectPoint(x: .5, y: .5, z: .1, size: size);
      expect(near.depth, greaterThan(far.depth));
      expect(near.scale, greaterThan(far.scale));
    });

    test('转视角之后左右会换边', () {
      const x0 = .8;
      final a = projectPoint(x: x0, y: .5, z: .5, size: size, yaw: 0);
      final b = projectPoint(x: x0, y: .5, z: .5, size: size, yaw: 3.14159265358979);
      expect(a.screen.dx, greaterThan(size.width / 2));
      expect(b.screen.dx, lessThan(size.width / 2));
    });

    test('放大就是离屏幕中心更远', () {
      final base = projectPoint(x: .8, y: .5, z: .5, size: size, spread: 1);
      final zoomed = projectPoint(x: .8, y: .5, z: .5, size: size, spread: 2);
      expect((zoomed.screen.dx - 200).abs(), greaterThan((base.screen.dx - 200).abs()));
    });
  });

  group('密集区', () {
    test('按社区聚成团，重心在成员中间', () {
      final nodes = <GalaxyNode>[
        _node(1)..x = 0.2..y = 0.2..z = 0.2,
        _node(2)..x = 0.3..y = 0.3..z = 0.3,
        _node(3)..x = 0.8..y = 0.8..z = 0.8,
      ];
      final communities = <int, int>{1: 0, 2: 0, 3: 1};
      final blobs = clusterBlobs(nodes, communities);
      expect(blobs.length, 2);
      final big = blobs.first; // 按成员数从多到少
      expect(big.count, 2);
      expect(big.cx, moreOrLessEquals(0.25, epsilon: 1e-9));
      expect(big.cy, moreOrLessEquals(0.25, epsilon: 1e-9));
      expect(big.cz, moreOrLessEquals(0.25, epsilon: 1e-9));
      expect(big.radius, greaterThan(0.06));
    });
  });
}
