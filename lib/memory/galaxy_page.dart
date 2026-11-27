import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'db.dart';
import 'galaxy.dart';
import 'galaxy_view.dart';
import 'store.dart';

/// 「让她讲这件」：给一个名字，回一段她自己的话。
typedef GalaxyAsk = Future<String> Function(String name, List<String> related);

/// 星图：一颗三维的记忆星系。
///
/// 层级不是画成一棵树，而是靠纵深：核心（主人、当下的项目）在很近的正面，
/// 旧事沉到深处、暗下去。社区是「信息交换密集区」，边是神经突触，
/// 亮光沿着突触流——流动本身就是「记忆在被调用」的样子。
class GalaxyPage extends StatefulWidget {
  final MemoryStore store;
  final GalaxyAsk? ask;

  const GalaxyPage({super.key, required this.store, this.ask});

  @override
  State<GalaxyPage> createState() => _GalaxyPageState();
}

class _GalaxyPageState extends State<GalaxyPage> with SingleTickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();

  List<GalaxyNode> _nodes = const [];
  List<GalaxyLink> _links = const [];
  List<GalaxyLink> _drawnLinks = const [];
  List<ClusterBlob> _blobs = const [];
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

  /// 视角：绕竖轴转、前后倾；双指缩放。
  double _yaw = 0.4;
  double _pitch = -0.26;
  double _zoom = 1.0;
  double _baseZoom = 1.0;

  /// 自转与流光都由同一个钟驱动，pause 时一起停。
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double get _yawNow => _yaw + _clock.value * math.pi * 2;

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
      final blobs = clusterBlobs(nodes, communities);
      // 每帧画三千条曲线不现实：只画最有分量的那几百条，剩下的靠密集区的光表达。
      final drawn = List<GalaxyLink>.of(links)
        ..sort((a, b) => b.weight.compareTo(a.weight));
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
        _drawnLinks = drawn.take(420).toList();
        _blobs = blobs;
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
    var bestD = 46.0;
    final yaw = _yawNow;
    for (final n in _nodes) {
      if (!_visible(n)) continue;
      final p = projectPoint(
        x: n.x,
        y: n.y,
        z: n.z,
        size: size,
        yaw: yaw,
        pitch: _pitch,
        spread: _zoom,
      );
      final d = (p.screen - local).distance;
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
                '${_nodes.length} 颗星 · ${_links.length} 条突触',
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
            colors: <Color>[Color(0xFF0C1416), AppPalette.ink],
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
                            onScaleStart: (d) {
                              _baseZoom = _zoom;
                            },
                            onScaleUpdate: (d) {
                              if (d.pointerCount <= 1) {
                                setState(() {
                                  _yaw += d.focalPointDelta.dx * 0.006;
                                  _pitch = (_pitch + d.focalPointDelta.dy * 0.005).clamp(-1.2, 1.2);
                                });
                              } else {
                                setState(() {
                                  _zoom = (_baseZoom * d.scale).clamp(0.55, 3.4);
                                });
                              }
                            },
                            child: AnimatedBuilder(
                              animation: _clock,
                              builder: (ctx, _) {
                                return SizedBox(
                                  key: _canvasKey,
                                  width: size.width,
                                  height: size.height,
                                  child: GalaxyView(
                                    nodes: _nodes,
                                    links: _drawnLinks,
                                    communities: _communities,
                                    blobs: _blobs,
                                    visible: _visible,
                                    selected: _selected?.id,
                                    yaw: _yawNow,
                                    pitch: _pitch,
                                    zoom: _zoom,
                                    phase: _clock.value,
                                  ),
                                );
                              },
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
                  Text(
                    '拖动转视角 · 双指缩放 · 点一颗星听她讲',
                    style: AppType.caption.copyWith(color: AppPalette.text4),
                  ),
                ],
              ),
            ),
    );
  }
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
