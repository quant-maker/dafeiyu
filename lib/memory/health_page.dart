import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'store.dart';

/// 记忆体检：一眼看出她还记得多少、有没有说法打架、哪些星快灭了。
class MemoryHealthPage extends StatefulWidget {
  final MemoryStore store;

  const MemoryHealthPage({super.key, required this.store});

  @override
  State<MemoryHealthPage> createState() => _MemoryHealthPageState();
}

class _MemoryHealthPageState extends State<MemoryHealthPage> {
  MemoryHealth? _health;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final h = await widget.store.health();
      if (!mounted) return;
      setState(() {
        _health = h;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _health;
    return Scaffold(
      backgroundColor: AppPalette.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('记忆体检'),
        actions: <Widget>[
          IconButton(
            tooltip: '重新检查',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text('体检做不了：$_error', style: AppType.body.copyWith(color: AppPalette.danger)),
                  ),
                )
              : h == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.xxl),
                      children: <Widget>[
                        _card(
                          title: '记性',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: h.fullness,
                                  minHeight: 8,
                                  backgroundColor: AppPalette.surfaceAlt,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.primary),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s),
                              Text(
                                _verdict(h),
                                style: AppType.bodySmall.copyWith(color: AppPalette.text2, height: 1.5),
                              ),
                              if (h.spanDays > 0) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  '记得 ${h.spanDays} 天里的事，最新一条 ${_when(h.newestAt)}',
                                  style: AppType.caption.copyWith(color: AppPalette.text3),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _card(
                          title: '存了多少',
                          child: Wrap(
                            spacing: AppSpacing.m,
                            runSpacing: AppSpacing.s,
                            children: <Widget>[
                              _stat('情景', h.episodes),
                              _stat('事实', h.facts),
                              _stat('星', h.entities),
                              _stat('连线', h.edges),
                              _stat('日结', h.dayCards),
                              _stat('周结', h.weekCards),
                              _stat('月结', h.monthCards),
                              if (h.localOnly > 0) _stat('只存本地', h.localOnly),
                            ],
                          ),
                        ),
                        _card(
                          title: '说法打架',
                          empty: h.conflicts.isEmpty,
                          emptyText: '没有互相矛盾的说法。',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              for (final c in h.conflicts)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '· $c',
                                    style: AppType.bodySmall.copyWith(color: AppPalette.accent, height: 1.5),
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                '这些是她自己记岔了，可以在「记忆」里改掉。',
                                style: AppType.caption.copyWith(color: AppPalette.text3),
                              ),
                            ],
                          ),
                        ),
                        _card(
                          title: '快忘掉的星',
                          empty: h.staleStars.isEmpty,
                          emptyText: '星星都还亮着。',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                h.staleStars.join('、'),
                                style: AppType.body.copyWith(color: AppPalette.text1, height: 1.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '一个多月没提到、也快淡没了。再聊起来就会重新亮。',
                                style: AppType.caption.copyWith(color: AppPalette.text3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  String _verdict(MemoryHealth h) {
    if (h.episodes == 0) return '还没开始记。多聊几句，她会自己动笔。';
    if (h.fullness < 0.25) return '刚起步，只记得零星几件事。';
    if (h.fullness < 0.6) return '已经在攒了，人和事开始连成片。';
    return '记得挺厚了，日常提起的人、事、地方她基本都接得住。';
  }

  Widget _card({
    required String title,
    required Widget child,
    bool empty = false,
    String emptyText = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(AppRadii.l),
          border: Border.all(color: AppPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: AppType.label.copyWith(color: AppPalette.text3)),
            const SizedBox(height: AppSpacing.s),
            if (empty)
              Text(emptyText, style: AppType.bodySmall.copyWith(color: AppPalette.text3))
            else
              child,
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.s),
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('$n', style: AppType.mono.copyWith(color: AppPalette.primary, fontSize: 13)),
          const SizedBox(width: 6),
          Text(label, style: AppType.caption.copyWith(color: AppPalette.text3)),
        ],
      ),
    );
  }
}

String _when(int ms) {
  if (ms <= 0) return '没有';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = DateTime.now().difference(d);
  if (diff.inHours < 1) return '刚刚';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
