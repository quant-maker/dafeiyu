import 'package:flutter/material.dart';

import 'footprints.dart';

/// Her Moments: a scroll of the moments she chose to keep.
class FootprintsPage extends StatefulWidget {
  final List<Footprint> items;
  final Future<Footprint?> Function() onDistill;

  const FootprintsPage({super.key, required this.items, required this.onDistill});

  @override
  State<FootprintsPage> createState() => _FootprintsPageState();
}

class _FootprintsPageState extends State<FootprintsPage> {
  late List<Footprint> _items = List.of(widget.items);
  bool _working = false;

  Future<void> _add() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final f = await widget.onDistill();
      if (f != null && mounted) {
        setState(() => _items = [f, ..._items]);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('这次没找到值得记的瞬间，再多聊几句')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // group by day label, preserving order
    final groups = <String, List<Footprint>>{};
    for (final f in _items) {
      groups.putIfAbsent(f.dayLabel, () => []).add(f);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101A2C),
        title: const Text('她的足迹'),
        actions: [
          IconButton(
            onPressed: _working ? null : _add,
            tooltip: '补记一个瞬间',
            icon: _working
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_outlined),
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🐟', style: TextStyle(fontSize: 46)),
                    const SizedBox(height: 16),
                    Text(
                      '还没有足迹。\n多聊几轮，她会自己挑一些瞬间留在这里。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: .55), height: 1.6),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: .7),
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Divider(color: Colors.white.withValues(alpha: .08), height: 1),
                        ),
                      ],
                    ),
                  ),
                  for (final f in entry.value) _card(f),
                ],
              ],
            ),
    );
  }

  Widget _card(Footprint f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16223A).withValues(alpha: .92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF7CC4FF), Color(0xFF2F6FD0)]),
                ),
                child: const Center(child: Text('🐟', style: TextStyle(fontSize: 15))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  f.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              Text(f.timeLabel, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .35))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            f.body,
            style: TextStyle(fontSize: 13.5, height: 1.65, color: Colors.white.withValues(alpha: .82)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(f.mood, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
