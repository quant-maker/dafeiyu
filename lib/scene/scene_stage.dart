import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Where the character currently is in her little life.
enum SceneMood { idle, listening, thinking, speaking, away }

/// A room-behind-glass stage.
///
/// Assets are optional. Drop files into `assets/scene/` and they are picked up:
///   room.mp4    — looping living-room background (camera fixed)
///   idle.mp4    — she sits there, breathing, blinking
///   talk.mp4    — she talks (played while the model streams)
///   think.mp4   — looking away / thinking
///   away.mp4    — she got up (optional)
///
/// Every clip must be the same framing and loop cleanly. Missing clips fall
/// back to a painted scene so the app never shows an empty box.
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
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);
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
        if (_available['room'] == true) _videoLayer('room', fit: BoxFit.cover, opacity: 1),
        if (_available['idle'] == true || _available['talk'] == true) _characterLayer(),
        _atmosphere(),
        _glass(),
      ],
    );
  }

  Widget _background() {
    if (_available['room'] == true) return const ColoredBox(color: Color(0xFF0A0F1A));
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2438), Color(0xFF0C1626), Color(0xFF070B14)],
        ),
      ),
      child: CustomPaint(painter: _RoomPainter(breathe: _breathe)),
    );
  }

  Widget _characterLayer() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _fade,
        builder: (context, _) {
          return Opacity(
            opacity: _fade.value.clamp(0.0, 1.0),
            child: _videoLayer(_current, fit: BoxFit.cover, opacity: 1),
          );
        },
      ),
    );
  }

  Widget _videoLayer(String key, {required BoxFit fit, double opacity = 1}) {
    final controller = _clips[key];
    if (controller == null) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  /// Soft vignette + light shafts so the room feels lit, not flat.
  Widget _atmosphere() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.5),
            radius: 1.1,
            colors: [
              const Color(0x2210E0FF),
              const Color(0x00000000),
              Colors.black.withValues(alpha: .55),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: _breathe,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4AA3FF).withValues(alpha: .05 + _breathe.value * .04),
                  blurRadius: 120,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The glass sheet the conversation is printed on.
  Widget _glass() {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .10),
                Colors.white.withValues(alpha: .03),
                Colors.white.withValues(alpha: .06),
              ],
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: .18), width: 1),
              left: BorderSide(color: Colors.white.withValues(alpha: .10), width: 1),
              right: BorderSide(color: Colors.white.withValues(alpha: .06), width: 1),
            ),
          ),
          child: Stack(
            children: [
              // A single diagonal streak of light across the pane.
              Positioned(
                top: -80,
                left: -40,
                child: Transform.rotate(
                  angle: -0.35,
                  child: Container(
                    width: 260,
                    height: 620,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: .07),
                          Colors.white.withValues(alpha: .0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}



/// Placeholder room painted with code, used until real clips exist.
class _RoomPainter extends CustomPainter {
  _RoomPainter({required this.breathe}) : super(repaint: breathe);
  final Animation<double> breathe;

  @override
  void paint(Canvas canvas, Size size) {
    final t = breathe.value;
    final w = size.width;
    final h = size.height;

    // Floor
    final floor = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF17202F), Color(0xFF0B1018)],
      ).createShader(Rect.fromLTWH(0, h * .62, w, h * .38));
    canvas.drawRect(Rect.fromLTWH(0, h * .62, w, h * .38), floor);

    // Window glow
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x335BC8FF), const Color(0x00000000)],
        radius: .8,
      ).createShader(Rect.fromCircle(center: Offset(w * .78, h * .26), radius: w * .7));
    canvas.drawCircle(Offset(w * .78, h * .26), w * .7, glow);

    // Sofa
    final sofa = Paint()..color = const Color(0xFF1E2A3D);
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .12, h * .58, w * .56, h * .20),
      const Radius.circular(26),
    );
    canvas.drawRRect(r, sofa);
    final cushion = Paint()..color = const Color(0xFF27354C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * .15, h * .60, w * .50, h * .10), const Radius.circular(18)),
      cushion,
    );

    // Warm lamp with a slow breathing halo
    final lampCenter = Offset(w * .12, h * .40);
    canvas.drawCircle(
      lampCenter,
      26,
      Paint()..color = const Color(0xFF6E5A38).withValues(alpha: .55),
    );
    canvas.drawCircle(
      lampCenter,
      110 + t * 16,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x33FFD79A), const Color(0x00FFD79A)],
        ).createShader(Rect.fromCircle(center: lampCenter, radius: 120 + t * 16)),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => false;
}
