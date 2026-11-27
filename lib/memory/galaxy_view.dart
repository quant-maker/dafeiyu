import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'galaxy.dart';

/// 记忆星系的三维画面。
///
/// 只是一个画布：视角、缩放、时间都从外面传进来，手势和页面状态留在
/// [GalaxyPage] 里，这样它既能被页面用，也能被测试离线渲染成图。
class GalaxyView extends StatefulWidget {
  const GalaxyView({
    super.key,
    required this.nodes,
    required this.links,
    required this.communities,
    required this.blobs,
    required this.visible,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.phase,
    this.selected,
    this.glowImage,
  });

  final List<GalaxyNode> nodes;
  final List<GalaxyLink> links;
  final Map<int, int> communities;
  final List<ClusterBlob> blobs;
  final bool Function(GalaxyNode) visible;
  final double yaw;
  final double pitch;
  final double zoom;
  final double phase;
  final int? selected;

  /// 已经渲染好的光点贴图（离线截图测试用；正常运行时为空，自己生成）。
  final ui.Image? glowImage;

  @override
  State<GalaxyView> createState() => _GalaxyViewState();
}

class _GalaxyViewState extends State<GalaxyView> {
  ui.Image? _glow;

  @override
  void initState() {
    super.initState();
    _glow = widget.glowImage;
    if (_glow == null) _buildGlow();
  }

  /// 预渲染一次光点贴图：每帧给几百颗星画径向渐变太贵，贴图便宜得多。
  Future<void> _buildGlow() async {
    const double s = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(s / 2, s / 2),
        s / 2,
        const <Color>[
          Color(0xFFFFFFFF),
          Color(0x99FFFFFF),
          Color(0x00FFFFFF),
        ],
        const <double>[0, 0.3, 1],
      );
    canvas.drawCircle(const Offset(s / 2, s / 2), s / 2, paint);
    final image = await recorder.endRecording().toImage(s.toInt(), s.toInt());
    if (!mounted) return;
    setState(() => _glow = image);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GalaxyPainter(
        nodes: widget.nodes,
        links: widget.links,
        communities: widget.communities,
        blobs: widget.blobs,
        visible: widget.visible,
        selected: widget.selected,
        yaw: widget.yaw,
        pitch: widget.pitch,
        zoom: widget.zoom,
        phase: widget.phase,
        glow: _glow,
      ),
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  final List<GalaxyNode> nodes;
  final List<GalaxyLink> links;
  final Map<int, int> communities;
  final List<ClusterBlob> blobs;
  final bool Function(GalaxyNode) visible;
  final int? selected;
  final double yaw;
  final double pitch;
  final double zoom;
  final double phase;
  final ui.Image? glow;

  _GalaxyPainter({
    required this.nodes,
    required this.links,
    required this.communities,
    required this.blobs,
    required this.visible,
    this.selected,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.phase,
    required this.glow,
  });

  static const List<Color> _communityColors = <Color>[
    Color(0xFF8FD3C4),
    Color(0xFFE0B15F),
    Color(0xFF7FA6C9),
    Color(0xFFA79BC4),
    Color(0xFFD9786B),
    Color(0xFF9FCB8F),
  ];

  Color _colorFor(GalaxyNode n) {
    final c = communities[n.id] ?? 0;
    return _communityColors[c % _communityColors.length];
  }

  void _sprite(Canvas canvas, Projected p, double diameter, Color color, double alpha) {
    final image = glow;
    if (image == null || alpha <= 0.003 || diameter <= 0.5) {
      if (alpha <= 0.003 || diameter <= 0.5) return;
      canvas.drawCircle(
        p.screen,
        diameter / 2,
        Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
      return;
    }
    final rect = Rect.fromCenter(center: p.screen, width: diameter, height: diameter);
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(
        color.withValues(alpha: alpha.clamp(0.0, 1.0)),
        BlendMode.modulate,
      );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );
  }

  Projected _project(
    Size size,
    double x,
    double y,
    double z,
  ) =>
      projectPoint(
        x: x,
        y: y,
        z: z,
        size: size,
        yaw: yaw,
        pitch: pitch,
        spread: zoom,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final byId = <int, GalaxyNode>{for (final n in nodes) n.id: n};
    final projected = <int, Projected>{};
    for (final n in nodes) {
      if (!visible(n)) continue;
      projected[n.id] = _project(size, n.x, n.y, n.z);
    }
    if (projected.isEmpty) return;

    // 0. 远处的尘埃：一批固定的微光点，给足纵深和星空的底子（便宜但有用）。
    final dustPaint = Paint();
    for (var i = 0; i < 220; i++) {
      final a = i * 2.399963229728653;
      final u = (i + 0.5) / 220;
      final rr = 0.30 + 0.62 * math.sqrt(u);
      final dx = 0.5 + rr * math.cos(a);
      final dy = 0.5 + rr * math.sin(a * 1.7);
      final dz = 0.5 + rr * math.cos(a * 2.3);
      final p = _project(size, dx, dy, dz);
      final fade = ((p.depth + 0.55) / 1.1).clamp(0.05, 1.0);
      dustPaint.color = AppPalette.text4.withValues(alpha: 0.08 + 0.24 * fade);
      canvas.drawCircle(p.screen, 0.5 + 0.8 * fade, dustPaint);
    }

    // 1. 信息交换密集区：先铺一层很淡的光，像神经网络里活动最密的那块。
    for (final blob in blobs.take(4)) {
      final c = _project(size, blob.cx, blob.cy, blob.cz);
      final color = _communityColors[blob.community % _communityColors.length];
      final diameter = size.shortestSide * 0.62 * blob.radius * 1.15 * c.scale * zoom;
      final dense = (blob.count / 16).clamp(0.3, 1.2);
      _sprite(canvas, c, diameter, color, (0.012 + 0.010 * dense) * c.scale.clamp(0.4, 1.0));
    }

    // 2. 突触：带弧度的连线，近的亮、远的暗。
    final strokes = <({Path path, double depth, double weight, double scale})>[];
    for (final l in links) {
      final a = projected[l.src];
      final b = projected[l.dst];
      if (a == null || b == null) continue;
      final nodeA = byId[l.src];
      final nodeB = byId[l.dst];
      if (nodeA == null || nodeB == null) continue;
      final ctrl = _arcControl(size, nodeA, nodeB, l.weight);
      strokes.add((
        path: Path()
          ..moveTo(a.screen.dx, a.screen.dy)
          ..quadraticBezierTo(ctrl.screen.dx, ctrl.screen.dy, b.screen.dx, b.screen.dy),
        depth: (a.depth + b.depth) / 2,
        weight: l.weight,
        scale: (a.scale + b.scale) / 2,
      ));
    }
    strokes.sort((x, y) => x.depth.compareTo(y.depth));
    for (final s in strokes) {
      final fade = ((s.depth + 0.55) / 1.1).clamp(0.12, 1.0);
      final alpha = (0.030 + 0.045 * s.weight.clamp(0.2, 3.0)) * fade;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (0.35 + 0.16 * s.weight.clamp(0.2, 4.0)) * s.scale
        ..color = AppPalette.primary.withValues(alpha: alpha.clamp(0.0, 0.26));
      canvas.drawPath(s.path, paint);
    }

    // 3. 流动的亮光：沿突触跑的小光点，越重的边跑得越快。
    if (links.isNotEmpty) {
      final pulseCount = math.min(64, math.max(14, links.length));
      for (var i = 0; i < pulseCount; i++) {
        final link = links[(i * 37 + 11) % links.length];
        final a = projected[link.src];
        final b = projected[link.dst];
        final nodeA = byId[link.src];
        final nodeB = byId[link.dst];
        if (a == null || b == null || nodeA == null || nodeB == null) continue;
        final speed = 2 + link.weight.clamp(0.5, 3.0);
        final t = (phase * 60 * 0.08 * speed + i * 0.61803398875) % 1.0;
        final ctrl = _arcControl(size, nodeA, nodeB, link.weight);
        final point = _bezier(a.screen, ctrl.screen, b.screen, t);
        final depth = a.depth + (b.depth - a.depth) * t;
        final fade = ((depth + 0.55) / 1.1).clamp(0.1, 1.0);
        final brightness = (0.30 + 0.45 * link.weight.clamp(0.2, 2.5)).clamp(0.25, 0.95);
        final scale = a.scale + (b.scale - a.scale) * t;
        _sprite(canvas, Projected(point, depth, scale), 7.0 * scale * zoom, AppPalette.warm, brightness * fade);
      }
    }

    // 4. 星星本体：按纵深从远到近画，前面的压住后面的。
    final ordered = nodes.where((n) => projected.containsKey(n.id)).toList()
      ..sort((a, b) => projected[a.id]!.depth.compareTo(projected[b.id]!.depth));
    var labels = 0;
    for (final n in ordered) {
      final p = projected[n.id]!;
      final base = _colorFor(n);
      final r = n.radius * (0.8 + 0.34 * p.scale);
      final highlight = selected == n.id;
      final depthFade = ((p.depth + 0.55) / 1.1).clamp(0.16, 1.0);

      _sprite(canvas, p, r * 2.7, base, 0.16 * n.alpha * depthFade * depthFade);
      canvas.drawCircle(
        p.screen,
        r,
        Paint()..color = base.withValues(alpha: (n.alpha * depthFade).clamp(0.16, 1.0)),
      );
      if (highlight) {
        canvas.drawCircle(
          p.screen,
          r + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = AppPalette.text1.withValues(alpha: 0.85),
        );
      }
      final wantLabel = highlight || (p.depth > -0.02 && (r >= 7.0 || labels < 10));
      if (wantLabel && labels < 26) {
        labels++;
        final tp = TextPainter(
          text: TextSpan(
            text: n.label,
            style: AppType.caption.copyWith(
              color: AppPalette.text1.withValues(alpha: 0.32 + 0.62 * depthFade),
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 96);
        tp.paint(canvas, p.screen + Offset(-tp.width / 2, r + 4));
      }
    }
  }

  /// 弧顶往星系外侧推一点，让连线浮在球面上而不是穿过球心。
  Projected _arcControl(Size size, GalaxyNode a, GalaxyNode b, double weight) {
    final mx = (a.x + b.x) / 2 - 0.5;
    final my = (a.y + b.y) / 2 - 0.5;
    final mz = (a.z + b.z) / 2 - 0.5;
    final len = math.sqrt(mx * mx + my * my + mz * mz);
    final bend = 0.16 + 0.05 * weight.clamp(0.2, 4.0);
    return _project(
      size,
      (a.x + b.x) / 2 + (len > 1e-4 ? mx / len * bend : 0),
      (a.y + b.y) / 2 + (len > 1e-4 ? my / len * bend : 0),
      (a.z + b.z) / 2 + (len > 1e-4 ? mz / len * bend : 0),
    );
  }

  static Offset _bezier(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
      u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter old) =>
      old.nodes != nodes ||
      old.links != links ||
      old.selected != selected ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.phase != phase ||
      old.glow != glow;
}
