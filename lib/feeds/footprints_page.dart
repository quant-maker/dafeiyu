import 'package:flutter/material.dart';

import '../ui/avatar_mark.dart';
import '../ui/layout.dart';
import '../ui/surfaces.dart';
import '../ui/tokens.dart';
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
      backgroundColor: AppPalette.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('她的足迹'),
        actions: [
          GhostIconButton(
            icon: Icons.auto_awesome_outlined,
            tooltip: '补记一个瞬间',
            onPressed: _working ? null : _add,
          ),
        ],
      ),
      body: _items.isEmpty
          ? ContentFrame(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AvatarMark(size: 72),
                      const SizedBox(height: AppSpacing.l),
                      Text(
                        '还没有足迹。\n多聊几轮，她会自己挑一些瞬间留在这里。',
                        textAlign: TextAlign.center,
                        style: AppType.bodySmall.copyWith(
                          color: AppPalette.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ContentFrame(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
                      child: Row(
                        children: [
                          Text(
                            entry.key,
                            style: AppType.label.copyWith(
                              color: AppPalette.text3,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          const Expanded(
                            child: Divider(
                              color: AppPalette.line,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final f in entry.value) _card(f),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _card(Footprint f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AvatarMark(size: 28),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  f.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.subtitle.copyWith(color: AppPalette.text1),
                ),
              ),
              Text(
                f.timeLabel,
                style: AppType.caption.copyWith(color: AppPalette.text3),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            f.body,
            style: AppType.bodySmall.copyWith(
              fontSize: 14,
              height: 1.7,
              color: AppPalette.text2,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Align(
            alignment: Alignment.centerRight,
            child: Pill(label: f.mood),
          ),
        ],
      ),
    );
  }
}
