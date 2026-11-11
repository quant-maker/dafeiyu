import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:video_player/video_player.dart';

/// Where the character currently is in her little life.
enum SceneMood { idle, listening, thinking, speaking, away }

/// The room behind the conversation.
///
/// The picture does **not** follow the phone: parallax felt seasick when held in
/// hand. It stays still; only a slow warm bloom drifts across it so the room
/// reads as lit rather than frozen.
///
/// Assets (all optional, first match wins):
///   room.webp / room.jpg / room.png  — the room
///   room.mp4                         — a looping room clip (wins over stills)
///   idle.mp4 / talk.mp4 / think.mp4  — her, for state changes
class SceneStage extends StatefulWidget {
  final SceneMood mood;
  final Widget child;
  final bool enabled;

  /// 0 = leave the room as bright as it is, 1 = nearly black.
  final double dim;

  const SceneStage({
    super.key,
    required this.mood,
    required this.child,
    this.enabled = true,
    this.dim = .5,
  });

  @override
  State<SceneStage> createState() => _SceneStageState();
}

class _SceneStageState extends State<SceneStage> with TickerProviderStateMixin {
  final Map<String, VideoPlayerController> _clips = {};
  final Map<String, bool> _available = {};
  String _current = 'idle';
  String? _roomImage;

  late final AnimationController _breathe;
  late final AnimationController _fade;
  late final AnimationController _light;

  static const _imageCandidates = [
    'assets/scene/room.webp',
    'assets/scene/room.jpg',
    'assets/scene/room.png',
  ];

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
    _breathe = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: 1);
    _light = AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
    _loadClips();
    _detectRoomImage();
  }

  Future<void> _detectRoomImage() async {
    for (final path in _imageCandidates) {
      try {
        await rootBundle.load(path);
        if (mounted) setState(() => _roomImage = path);
        return;
      } catch (_) {
        // try the next one
      }
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
    _light.dispose();
    _breathe.dispose();
    _fade.dispose();
    for (final c in _clips.values) {
      c.dispose();
    }
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
        _lighting(),
        _atmosphere(),
        widget.child,
      ],
    );
  }

  Widget _background() {
    if (_available['room'] == true) return _video('room');
    final image = _roomImage;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0A0F18)),
        if (image != null)
          Image.asset(
            image,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => CustomPaint(painter: _RoomPainter(breathe: _breathe)),
          )
        else
          CustomPaint(painter: _RoomPainter(breathe: _breathe)),
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

  /// Slow ambient light: a warm bloom drifting across the room plus a soft cool
  /// fill from the other side. No parallax, nothing that follows the hand.
  Widget _lighting() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _light,
        builder: (context, _) {
          final t = _light.value * 2 * math.pi;
          final dx = math.sin(t) * .18;
          final dy = math.cos(t * .7) * .09;
          final pulse = .5 + .5 * math.sin(t * 1.3);
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(dx, dy - .35),
                    radius: 1.25,
                    colors: [
                      const Color(0xFFFFE2B8).withValues(alpha: .08 + pulse * .05),
                      const Color(0x00FFE2B8),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-.7, .25),
                    radius: .95,
                    colors: [
                      const Color(0xFF8FD0FF).withValues(alpha: .04 + pulse * .03),
                      const Color(0x008FD0FF),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// A gentle edge darkening so white text keeps its contrast.
  Widget _atmosphere() {
    final d = widget.dim.clamp(0.0, 1.0);
    final top = (.08 + d * .58).clamp(0.0, .92);
    final mid = (.03 + d * .42).clamp(0.0, .92);
    final bottom = (.12 + d * .58).clamp(0.0, .92);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: top),
              Colors.black.withValues(alpha: mid),
              Colors.black.withValues(alpha: bottom),
            ],
            stops: const [0.0, 0.48, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A room drawn with code, used when no photo is available.
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

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF20304A), Color(0xFF172235), Color(0xFF121A28)],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );

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
      canvas.drawLine(Offset(w * .5 + i * w * .06, horizon), Offset(w * .5 + i * w * .11, h), plank);
    }

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
    canvas.drawRect(
      win,
      Paint()
        ..color = const Color(0xFF0E1622)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    final sofa = Rect.fromLTWH(w * .14, h * .58, w * .52, h * .20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sofa, const Radius.circular(22)),
      Paint()..color = const Color(0xFF2B3A52),
    );

    final lampX = w * .10;
    final lampTop = h * .34;
    canvas.drawLine(
      Offset(lampX, lampTop + 16),
      Offset(lampX, h * .72),
      Paint()
        ..color = const Color(0xFF3A3A44)
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      Offset(lampX, lampTop + 2),
      90 + t * 14,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x44FFD9A0), const Color(0x11FFD9A0), const Color(0x00FFD9A0)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(lampX, lampTop), radius: 104 + t * 14)),
    );

    final grain = Paint();
    for (var i = 0; i < 800; i++) {
      grain.color = Colors.white.withValues(alpha: _rnd.nextDouble() * .05);
      canvas.drawCircle(Offset(_rnd.nextDouble() * w, _rnd.nextDouble() * h), _rnd.nextDouble() * .9, grain);
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => false;
}
