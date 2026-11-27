import 'dart:io';
import 'dart:ui' as ui;

import 'package:feiyu/memory/galaxy.dart';
import 'package:feiyu/memory/galaxy_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 离线渲染一张星图，用来肉眼检查它到底长什么样。
///
/// 断言只要求"画出来了、不是全黑"，具体好不好看由人看 tmp/galaxy_preview.png。
void main() {
  testWidgets('星图能画出来', (tester) async {
    tester.view.physicalSize = const Size(900, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final rng = _Seeded();
    final nodes = <GalaxyNode>[];
    for (var i = 0; i < 90; i++) {
      nodes.add(GalaxyNode(
        id: i,
        label: '记忆$i',
        kind: const <String>['person', 'topic', 'project', 'place'][i % 4],
        importance: 1 + (i % 5),
        strength: 0.4 + rng.nextDouble() * 0.6,
        firstSeen: i * 1000,
      ));
    }
    final links = <GalaxyLink>[];
    for (var i = 1; i < nodes.length; i++) {
      for (var k = 0; k < 3; k++) {
        final src = (i + k * 7) % nodes.length;
        if (src == i) continue;
        links.add(GalaxyLink(src: i, dst: src, weight: 0.5 + rng.nextDouble() * 2.5));
      }
    }
    GalaxyLayout(nodes: nodes, links: links).simulate(iterations: 200);
    final communities = detectCommunities(nodes, links);
    final blobs = clusterBlobs(nodes, communities);

    // 贴图要在真实引擎里生成，测试环境得放进 runAsync。
    final glow = await tester.runAsync(() async {
      const double s = 96;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          const Offset(s / 2, s / 2),
          s / 2,
          const <Color>[Color(0xFFFFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
          const <double>[0, 0.3, 1],
        );
      canvas.drawCircle(const Offset(s / 2, s / 2), s / 2, paint);
      return recorder.endRecording().toImage(s.toInt(), s.toInt());
    });

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: ColoredBox(
        color: const Color(0xFF050607),
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 900,
            height: 640,
            child: GalaxyView(
              nodes: nodes,
              links: links.take(420).toList(),
              communities: communities,
              blobs: blobs,
              visible: (_) => true,
              yaw: 0.4,
              pitch: -0.26,
              zoom: 1.0,
              phase: 0.35,
              selected: nodes[3].id,
              glowImage: glow,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    expect(bytes, isNotNull);
    final file = File('tmp/galaxy_preview.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.lengthSync(), greaterThan(20000));
  });
}

class _Seeded {
  int _state = 20261127;
  double nextDouble() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}
