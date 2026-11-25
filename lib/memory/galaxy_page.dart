import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'db.dart';
import 'galaxy.dart';
import 'store.dart';

/// 「让她讲这件」：给一个名字，回一段她自己的话。
typedef GalaxyAsk = Future<String> Function(String name, List<String> related);

/// 星图：一张可以拖着看、点开就能听她讲当天记得什么的图。
class GalaxyPage extends StatefulWidget {
  final MemoryStore store;
  final GalaxyAsk? ask;

  const GalaxyPage({super.key, required this.store, this.ask});

  @override
  State<GalaxyPage> createState() => _GalaxyPageState();
}

class _GalaxyPageState extends State<GalaxyPage> {
  final GlobalKey _canvasKey = GlobalKey();

  List<GalaxyNode> _nodes = const [];
  List<GalaxyLink> _links = const [];
  Map<int, int> _communities = const {};
  Map<int, List<String>> _neighbours = const {};
  Map<int, Entity> _byId = const {};

  bool _loading = true;
  String? _error;

  /// 时间滑杆：1.0 = 看到现在，0 = 只看最早那一刻。
  double _time = 1.0;
  int _minSeen = 0;
  int _maxSeen = 0;

  GalaxyNode? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entities = await widget.store.entities(limit: 400);
      final edges = await widget.store.edges(limit: 3000);
      final nodes = <GalaxyNode>[];
      final byId = <int, Entity>{};
      for (final e in entities) {
        byId[e.id] = e;
        nodes.add(GalaxyNode(
          id: e.id,
          label: e.name,
          kind: e.kind,
          importance: e.importance.toDouble(),
          strength: e.strength,
          firstSeen: e.firstSeen,
          lastTouched: e.lastTouched,
        ));
      }
      final known = byId.keys.toSet();
      final links = <GalaxyLink>[];
      final neighbours = <int, List<String>>{};
      for (final ed in edges) {
        if (!known.contains(ed.src) || !known.contains(ed.dst)) continue;
        links.add(GalaxyLink(src: ed.src, dst: ed.dst, weight: ed.weight));
        neighbours.putIfAbsent(ed.src, () => []).add(byId[ed.dst]!.name);
        neighbours.putIfAbsent(ed.dst, () => []).add(byId[ed.src]!.name);
      }
      if (nodes.isNotEmpty) {
        GalaxyLayout(nodes: nodes, links: links).simulate();
      }
      final communities = detectCommunities(nodes, links);
      var minSeen = nodes.isEmpty ? 0 : nodes.first.firstSeen;
      var maxSeen = minSeen;
      for (final n in nodes) {
        if (n.firstSeen < minSeen) minSeen = n.firstSeen;
        if (n.firstSeen > maxSeen) maxSeen = n.firstSeen;
      }
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _links = links;
        _communities = communities;
        _neighbours = neighbours;
        _byId = byId;
        _minSeen = minSeen;
        _maxSeen = maxSeen;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  int get _cutoff {
    if (_maxSeen <= _minSeen) return _maxSeen;
    return (_minSeen + (_maxSeen - _minSeen) * _time).round();
  }

  bool _visible(GalaxyNode n) => n.firstSeen <= _cutoff;

  void _onTap(Offset local, Size size) {
    GalaxyNode? best;
    var bestD = 44.0;
    for (final n in _nodes) {
      if (!_visible(n)) continue;
      final dx = n.x * size.width - local.dx;
      final dy = n.y * size.height - local.dy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < bestD) {
        bestD = d;
        best = n;
      }
    }
    if (best == null) return;
    setState(() => _selected = best);
    _openSheet(best);
  }

  Future<void> _openSheet(GalaxyNode node) async {
    final entity = _byId[node.id];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        var story = '';
        var busy = false;
        String? storyError;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.s,
                AppSpacing.xl,
                AppSpacing.xxl + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _Dot(kind: node.kind, size: 12),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(node.label, style: AppType.title.copyWith(color: AppPalette.text1)),
                      ),
                      Text(_kindLabel(node.kind), style: AppType.caption.copyWith(color: AppPalette.text3)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${_when(node.firstSeen)} 第一次出现 · 最近 ${_when(node.lastTouched)} · '
                    '重要度 ${node.importance.round()}/5',
                    style: AppType.caption.copyWith(color: AppPalette.text3),
                  ),
                  if (entity?.summary != null && entity!.summary!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.m),
                    Text(entity.summary!.trim(), style: AppType.bodySmall.copyWith(color: AppPalette.text2)),
                  ],
                  if ((_neighbours[node.id] ?? const []).isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      '连着：${(_neighbours[node.id] ?? const []).take(6).join('、')}',
                      style: AppType.bodySmall.copyWith(color: AppPalette.text2),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.l),
                  if (story.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.m),
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadii.m),
                        border: Border.all(color: AppPalette.line),
                      ),
                      child: Text(story, style: AppType.body.copyWith(color: AppPalette.text1, height: 1.5)),
                    )
                  else if (storyError != null)
                    Text(storyError ?? '', style: AppType.caption.copyWith(color: AppPalette.danger)),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed: (busy || widget.ask == null)
                            ? null
                            : () async {
                                setSheet(() {
                                  busy = true;
                                  storyError = null;
                                });
                                try {
                                  final text = await widget.ask!(
                                    node.label,
                                    _neighbours[node.id] ?? const [],
                                  );
                                  setSheet(() {
                                    busy = false;
                                    story = text.trim();
                                  });
                                } catch (e) {
                                  setSheet(() {
                                    busy = false;
                                    storyError = '她说不上来：$e';
                                  });
                                }
                              },
                        child: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('让她讲这件'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('关上'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('记忆星图'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.l),
            child: Center(
              child: Text(
                '${_nodes.length} 颗星 · ${_links.length} 条线',
                style: AppType.caption.copyWith(color: AppPalette.text3),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: <Color>[Color(0xFF10181A), AppPalette.ink],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text('星图打不开了：$_error', style: AppType.body.copyWith(color: AppPalette.danger)),
                    ),
                  )
                : _nodes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.auto_awesome_outlined, size: 40, color: AppPalette.text4),
                              const SizedBox(height: AppSpacing.m),
                              Text(
                                '还没有星。\n多聊几句，她会把人、事、地方连起来。',
                                textAlign: TextAlign.center,
                                style: AppType.body.copyWith(color: AppPalette.text2, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (ctx, constraints) {
                          final size = Size(constraints.maxWidth, constraints.maxHeight);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) => _onTap(d.localPosition, size),
                            child: InteractiveViewer(
                              minScale: 0.6,
                              maxScale: 4,
                              boundaryMargin: const EdgeInsets.all(80),
                              child: SizedBox(
                                key: _canvasKey,
                                width: size.width,
                                height: size.height,
                                child: CustomPaint(
                                  painter: _GalaxyPainter(
                                    nodes: _nodes,
                                    links: _links,
                                    communities: _communities,
                                    visible: _visible,
                                    selected: _selected?.id,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
      bottomNavigationBar: _nodes.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.m),
              color: AppPalette.ink,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _time >= 0.999 ? '看：现在' : '看：${_when(_cutoff)}',
                    style: AppType.caption.copyWith(color: AppPalette.text2),
                  ),
                  Slider(
                    value: _time,
                    onChanged: (v) => setState(() => _time = v),
                  ),
                ],
              ),
            ),
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  final List<GalaxyNode> nodes;
  final List<GalaxyLink> links;
  final Map<int, int> communities;
  final bool Function(GalaxyNode) visible;
  final int? selected;

  _GalaxyPainter({
    required this.nodes,
    required this.links,
    required this.communities,
    required this.visible,
    this.selected,
  });

  static const List<Color> _communityColors = <Color>[
    Color(0xFF8FD3C4),
    Color(0xFFE0B15F),
    Color(0xFF7FA6C9),
    Color(0xFFA79BC4),
    Color(0xFFD9786B),
    Color(0xFF9FCB8F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pos = <int, Offset>{};
    for (final n in nodes) {
      if (!visible(n)) continue;
      pos[n.id] = Offset(n.x * size.width, n.y * size.height);
    }

    // 先画边，压在星下面。
    final linePaint = Paint()..strokeCap = StrokeCap.round;
    for (final l in links) {
      final a = pos[l.src];
      final b = pos[l.dst];
      if (a == null || b == null) continue;
      final w = (0.35 + 0.25 * l.weight).clamp(0.35, 1.6);
      linePaint
        ..color = AppPalette.primary.withValues(alpha: 0.10)
        ..strokeWidth = w;
      canvas.drawLine(a, b, linePaint);
    }

    for (final n in nodes) {
      final p = pos[n.id];
      if (p == null) continue;
      final base = _colorFor(n);
      final r = n.radius;
      final highlight = selected == n.id;

      final glow = Paint()
        ..shader = RadialGradient(
          colors: <Color>[base.withValues(alpha: 0.35 * n.alpha), base.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: p, radius: r * 3.2));
      canvas.drawCircle(p, r * 3.2, glow);

      canvas.drawCircle(p, r, Paint()..color = base.withValues(alpha: n.alpha.clamp(0.2, 1.0)));
      if (highlight) {
        canvas.drawCircle(
          p,
          r + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = AppPalette.text1.withValues(alpha: 0.8),
        );
      }
      if (n.radius >= 8 || highlight) {
        final tp = TextPainter(
          text: TextSpan(
            text: n.label,
            style: AppType.caption.copyWith(
              color: AppPalette.text1.withValues(alpha: 0.55 + 0.45 * n.alpha),
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 96);
        tp.paint(canvas, p + Offset(-tp.width / 2, r + 4));
      }
    }
  }

  Color _colorFor(GalaxyNode n) {
    final c = communities[n.id] ?? 0;
    return _communityColors[c % _communityColors.length];
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter old) =>
      old.nodes != nodes || old.selected != selected || old.links != links;
}

class _Dot extends StatelessWidget {
  final String kind;
  final double size;

  const _Dot({required this.kind, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kindColor(kind),
        boxShadow: <BoxShadow>[
          BoxShadow(color: _kindColor(kind).withValues(alpha: 0.5), blurRadius: size),
        ],
      ),
    );
  }
}

Color _kindColor(String kind) {
  switch (kind) {
    case 'person':
      return AppPalette.primary;
    case 'project':
      return const Color(0xFFE0B15F);
    case 'place':
      return const Color(0xFF7FA6C9);
    case 'topic':
      return const Color(0xFFA79BC4);
    case 'promise':
      return AppPalette.accent;
    default:
      return AppPalette.mint;
  }
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'person':
      return '人';
    case 'project':
      return '项目';
    case 'place':
      return '地方';
    case 'topic':
      return '话题';
    case 'promise':
      return '约定';
    default:
      return '事物';
  }
}

String _when(int ms) {
  if (ms <= 0) return '很久以前';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 60) return '刚刚';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
