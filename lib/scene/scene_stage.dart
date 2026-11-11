import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:video_player/video_player.dart';

/// Where the character currently is in her little life.
enum SceneMood { idle, listening, thinking, speaking, away }

/// Full-bleed room. The phone screen itself is the glass: nothing is tinted or
/// blurred on top of it, the conversation simply sits on the picture.
///
/// Assets are optional. Drop files into `assets/scene/` and they are picked up:
///   room.mp4 / room.jpg  — the room (video wins over the still)
///   idle.mp4             — she sits there breathing
///   talk.mp4             — she talks (played while a reply streams)
///   think.mp4            — looking away, thinking
///   away.mp4             — she got up (for outfit changes)
class SceneStage extends StatefulWidget {
  final SceneMood mood;
  final Widget child;
  final bool enabled;

  const SceneStage({
    super.key,
    required this.mood,
    required this.child,
    this.enabled = true,
  });

  @override
  State<SceneStage> createState() => _SceneStageState();
}

class _SceneStageState extends State<SceneStage> with TickerProviderStateMixin {
  final Map<String, VideoPlayerController> _clips = {};
  final Map<String, bool> _available = {};
  String _current = 'idle';
  late final AnimationController _breathe;
  late final AnimationController _fade;

  /// Normalised tilt in [-1, 1]; drives a small parallax shift.
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _accel;
  Offset _target = Offset.zero;

  static const _candidates = <String, String>{
    'room': 'assets/scene/room.mp4',
    'idle': 'assets/scene/idle.mp4',
    'talk': 'assets/scene/talk.mp4',
    'think': 'assets/scene/think.mp4',
    'away': 'assets/scene/away.mp4',
  };

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: 1);
    _loadClips();
    _listenTilt();
  }

  /// Phones: accelerometer tilt. Desktop/web: pointer position (handled by the
  /// Listener in build). Both feed the same smoothed value.
  void _listenTilt() {
    try {
      _accel = accelerometerEventStream().listen((e) {
        // x is left/right, y is up/down (m/s^2). ~4 m/s^2 is a comfortable range.
        _target = Offset((e.x / 4).clamp(-1.0, 1.0), (e.y / 4).clamp(-1.0, 1.0));
        _tilt.value = Offset(
          _tilt.value.dx * .82 + _target.dx * .18,
          _tilt.value.dy * .82 + _target.dy * .18,
        );
      }, onError: (_) {});
    } catch (_) {
      // No sensors: pointer parallax still applies.
    }
  }

  Future<void> _loadClips() async {
    for (final entry in _candidates.entries) {
      try {
        final controller = VideoPlayerController.asset(entry.value);
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        _clips[entry.key] = controller;
        _available[entry.key] = true;
        if (entry.key == 'room' || entry.key == 'idle') unawaited(controller.play());
      } catch (_) {
        _available[entry.key] = false;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SceneStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final want = switch (widget.mood) {
      SceneMood.idle => 'idle',
      SceneMood.listening => 'idle',
      SceneMood.thinking => 'think',
      SceneMood.speaking => 'talk',
      SceneMood.away => 'away',
    };
    _switchTo(want);
  }

  void _switchTo(String key) {
    if (key == _current) return;
    final next = _clips[key];
    if (next == null) return;
    final prev = _clips[_current];
    _current = key;
    _fade.reverse().then((_) {
      prev?.pause();
      next.seekTo(Duration.zero);
      next.play();
      if (mounted) _fade.forward();
    });
  }

  @override
  void dispose() {
    _accel?.cancel();
    _tilt.dispose();
    for (final c in _clips.values) {
      c.dispose();
    }
    _breathe.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        final size = box?.size;
        if (size == null) return;
        final nx = (event.localPosition.dx / size.width - .5) * 2;
        final ny = (event.localPosition.dy / size.height - .5) * 2;
        _target = Offset(nx.clamp(-1.0, 1.0), ny.clamp(-1.0, 1.0));
        _tilt.value = Offset(
          _tilt.value.dx * .75 + _target.dx * .25,
          _tilt.value.dy * .75 + _target.dy * .25,
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _parallax(_background()),
          if (_available['idle'] == true) _parallax(_character(), amount: .6),
          _atmosphere(),
          widget.child,
        ],
      ),
    );
  }

  /// Slight over-scale + counter-shift so the room feels layered behind the text.
  Widget _parallax(Widget child, {double amount = 1.0}) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _tilt,
      builder: (context, off, inner) => Transform.scale(
        scale: 1.10,
        child: Transform.translate(
          offset: Offset(-off.dx * 16 * amount, -off.dy * 12 * amount),
          child: inner,
        ),
      ),
      child: child,
    );
  }

  Widget _background() {
    if (_available['room'] == true) return _video('room');
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0A0F18)),
        Image.asset(
          'assets/scene/room.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CustomPaint(painter: _RoomPainter(breathe: _breathe)),
        ),
      ],
    );
  }

  Widget _character() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _fade,
        builder: (context, _) => Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: _video(_current),
        ),
      ),
    );
  }

  Widget _video(String key) {
    final controller = _clips[key];
    if (controller == null) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  /// Light only: a slight edge vignette so text stays readable. No pane.
  Widget _atmosphere() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: .62),
              Colors.black.withValues(alpha: .46),
              Colors.black.withValues(alpha: .66),
            ],
            stops: const [0.0, 0.48, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A room drawn with code: window, shelves, sofa, rug, plant, floor planks and
/// film grain. Detail is what stops it from reading as "blurry gradient".
class _RoomPainter extends CustomPainter {
  _RoomPainter({required this.breathe}) : super(repaint: breathe);
  final Animation<double> breathe;
  final math.Random _rnd = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final t = breathe.value;
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.66;

    // ---- wall ----
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF20304A), Color(0xFF172235), Color(0xFF121A28)],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );

    // ---- floor planks (perspective) ----
    final floor = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2118), Color(0xFF17120D)],
        ).createShader(floor),
    );
    final plank = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: .28)
      ..strokeWidth = 1;
    for (var i = -6; i <= 6; i++) {
      final x = w * .5 + i * w * .11;
      canvas.drawLine(Offset(w * .5 + i * w * .06, horizon), Offset(x, h), plank);
    }
    for (var k = 1; k <= 3; k++) {
      final y = horizon + (h - horizon) * (k * k / 12.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), plank..strokeWidth = .8);
    }

    // ---- window (right), bright and sharp ----
    final win = Rect.fromLTWH(w * .60, h * .10, w * .34, h * .40);
    canvas.drawRect(
      win,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8FD0FF), Color(0xFF4E86C6), Color(0xFF2B4A72)],
        ).createShader(win),
    );
    final frame = Paint()
      ..color = const Color(0xFF0E1622)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRect(win, frame);
    final mullion = Paint()
      ..color = const Color(0xFF0E1622)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(win.center.dx, win.top), Offset(win.center.dx, win.bottom), mullion);
    canvas.drawLine(Offset(win.left, win.center.dy), Offset(win.right, win.center.dy), mullion);

    // light spilling from the window onto the floor
    canvas.drawPath(
      Path()
        ..moveTo(win.left, win.bottom)
        ..lineTo(win.right, win.bottom)
        ..lineTo(win.right + w * .10, h)
        ..lineTo(win.left - w * .16, h)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x33CFE9FF), const Color(0x00CFE9FF)],
        ).createShader(Rect.fromLTWH(0, win.bottom, w, h - win.bottom)),
    );

    // ---- bookshelf (left) ----
    final shelf = Rect.fromLTWH(w * .02, h * .20, w * .30, h * .46);
    canvas.drawRect(shelf, Paint()..color = const Color(0xFF1B140D));
    final shelfLine = Paint()
      ..color = const Color(0xFF3A2A1A)
      ..strokeWidth = 3;
    for (var i = 0; i <= 4; i++) {
      final y = shelf.top + shelf.height * (i / 4);
      canvas.drawLine(Offset(shelf.left, y), Offset(shelf.right, y), shelfLine);
    }
    final bookColors = [
      const Color(0xFF7A4B3A),
      const Color(0xFF4B6A58),
      const Color(0xFF56507E),
      const Color(0xFF8A6A3C),
    ];
    var seed = 3;
    for (var row = 0; row < 4; row++) {
      var x = shelf.left + 8;
      final y0 = shelf.top + shelf.height * (row / 4) + 4;
      final rowH = shelf.height / 4 - 10;
      while (x < shelf.right - 14) {
        final bw = 6.0 + (seed * 7 % 9);
        final bh = rowH * (0.62 + ((seed * 13) % 30) / 100);
        canvas.drawRect(
          Rect.fromLTWH(x, y0 + (rowH - bh), bw.toDouble(), bh),
          Paint()..color = bookColors[seed % bookColors.length],
        );
        x += bw + 3;
        seed++;
      }
    }

    // ---- rug ----
    final rugCenter = Offset(w * .52, h * .88);
    canvas.drawOval(
      Rect.fromCenter(center: rugCenter, width: w * .72, height: h * .16),
      Paint()..color = const Color(0xFF2C2436),
    );
    for (var i = 1; i <= 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: rugCenter, width: w * .72 - i * w * .09, height: h * .16 - i * h * .022),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF4B3E5C).withValues(alpha: .8),
      );
    }

    // ---- sofa ----
    final sofa = Rect.fromLTWH(w * .14, h * .58, w * .52, h * .20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sofa, const Radius.circular(22)),
      Paint()..color = const Color(0xFF2B3A52),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(sofa.left, sofa.top, sofa.width, sofa.height * .42), const Radius.circular(18)),
      Paint()..color = const Color(0xFF35486400),
    );
    final cushion = Paint()..color = const Color(0xFF3B5070);
    for (var i = 0; i < 2; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sofa.left + 14 + i * (sofa.width / 2), sofa.top + 12, sofa.width / 2 - 20, sofa.height * .40),
          const Radius.circular(12),
        ),
        cushion,
      );
    }
    // armrests
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(sofa.left - 8, sofa.top + 6, 16, sofa.height), const Radius.circular(8)),
      Paint()..color = const Color(0xFF26334A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(sofa.right - 8, sofa.top + 6, 16, sofa.height), const Radius.circular(8)),
      Paint()..color = const Color(0xFF26334A),
    );

    // ---- plant ----
    final pot = Rect.fromLTWH(w * .72, h * .70, w * .09, h * .075);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pot, const Radius.circular(6)),
      Paint()..color = const Color(0xFF6B4A35),
    );
    final leaf = Paint()..color = const Color(0xFF3C6B4A);
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + (i - 2.5) * 0.42;
      final base = Offset(pot.center.dx, pot.top);
      final tip = base + Offset(math.cos(angle) * h * .10, math.sin(angle) * h * .10);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            (base.dx + tip.dx) / 2 + math.cos(angle + 1.2) * 12,
            (base.dy + tip.dy) / 2 + math.sin(angle + 1.2) * 12,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            (base.dx + tip.dx) / 2 - math.cos(angle + 1.2) * 12,
            (base.dy + tip.dy) / 2 - math.sin(angle + 1.2) * 12,
            base.dx,
            base.dy,
          ),
        leaf,
      );
    }

    // ---- floor lamp with warm halo ----
    final lampX = w * .10;
    final lampTop = h * .34;
    canvas.drawLine(
      Offset(lampX, lampTop + 16),
      Offset(lampX, h * .72),
      Paint()
        ..color = const Color(0xFF3A3A44)
        ..strokeWidth = 3,
    );
    canvas.drawPath(
      Path()
        ..moveTo(lampX - 22, lampTop + 14)
        ..lineTo(lampX + 22, lampTop + 14)
        ..lineTo(lampX + 14, lampTop - 16)
        ..lineTo(lampX - 14, lampTop - 16)
        ..close(),
      Paint()..color = const Color(0xFFE8C98A),
    );
    canvas.drawCircle(
      Offset(lampX, lampTop + 2),
      90 + t * 14,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x44FFD9A0),
            const Color(0x11FFD9A0),
            const Color(0x00FFD9A0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(lampX, lampTop), radius: 104 + t * 14)),
    );

    // ---- film grain: high frequency detail kills the "smooth blur" look ----
    final grain = Paint();
    for (var i = 0; i < 900; i++) {
      final x = _rnd.nextDouble() * w;
      final y = _rnd.nextDouble() * h;
      grain.color = Colors.white.withValues(alpha: _rnd.nextDouble() * .05);
      canvas.drawCircle(Offset(x, y), _rnd.nextDouble() * .9, grain);
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => false;
}
