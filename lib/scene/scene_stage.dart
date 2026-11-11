import 'dart:async';

import 'package:flutter/material.dart';
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
    return Stack(
      fit: StackFit.expand,
      children: [
        _background(),
        if (_available['idle'] == true) _character(),
        _atmosphere(),
        widget.child,
      ],
    );
  }

  Widget _background() {
    if (_available['room'] == true) {
      return _video('room');
    }
    // A still photo beats any painted placeholder; drop room.jpg in place.
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2438), Color(0xFF0C1626), Color(0xFF070B14)],
            ),
          ),
        ),
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

  /// Light only: a vignette so text near the edges stays readable, plus a slow
  /// ambient glow. No pane, no blur, no border.
  Widget _atmosphere() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.5),
            radius: 1.15,
            colors: [
              const Color(0x1A10E0FF),
              const Color(0x00000000),
              Colors.black.withValues(alpha: .42),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Placeholder room painted with code, used until real assets exist.
class _RoomPainter extends CustomPainter {
  _RoomPainter({required this.breathe}) : super(repaint: breathe);
  final Animation<double> breathe;

  @override
  void paint(Canvas canvas, Size size) {
    final t = breathe.value;
    final w = size.width;
    final h = size.height;

    final floor = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF17202F), Color(0xFF0B1018)],
      ).createShader(Rect.fromLTWH(0, h * .62, w, h * .38));
    canvas.drawRect(Rect.fromLTWH(0, h * .62, w, h * .38), floor);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x335BC8FF), const Color(0x00000000)],
        radius: .8,
      ).createShader(Rect.fromCircle(center: Offset(w * .78, h * .26), radius: w * .7));
    canvas.drawCircle(Offset(w * .78, h * .26), w * .7, glow);

    final sofa = Paint()..color = const Color(0xFF1E2A3D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * .12, h * .58, w * .56, h * .20), const Radius.circular(26)),
      sofa,
    );
    final cushion = Paint()..color = const Color(0xFF27354C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * .15, h * .60, w * .50, h * .10), const Radius.circular(18)),
      cushion,
    );

    final lamp = Offset(w * .12, h * .40);
    canvas.drawCircle(lamp, 26, Paint()..color = const Color(0xFF6E5A38).withValues(alpha: .55));
    canvas.drawCircle(
      lamp,
      110 + t * 16,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x33FFD79A), const Color(0x00FFD79A)],
        ).createShader(Rect.fromCircle(center: lamp, radius: 120 + t * 16)),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => false;
}
