/// 时间感的原料：模型看不见系统时钟，也看不出两条消息之间隔了多久。
///
/// 把「现在」「上次说话离现在多远」「某条消息是哪天」整理成短句塞进系统提示，
/// 它才不会在凌晨说早上好、把三天前的事说成「刚才」。
library;

const List<String> kWeekdays = <String>[
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// 一天里的时段，用中文日常说法。
String dayPart(DateTime t) {
  final int h = t.hour;
  if (h < 5) return '深夜';
  if (h < 8) return '清晨';
  if (h < 11) return '上午';
  if (h < 13) return '中午';
  if (h < 18) return '下午';
  if (h < 23) return '晚上';
  return '深夜';
}

/// 「刚刚 / 12 分钟前 / 3 小时前 / 5 天前 / 2 个月前 / 1 年前」。
String humanGap(Duration d) {
  if (d.inSeconds < 90) return '刚刚';
  if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
  if (d.inHours < 24) return '${d.inHours} 小时前';
  if (d.inDays < 30) return '${d.inDays} 天前';
  if (d.inDays < 365) return '${d.inDays ~/ 30} 个月前';
  return '${d.inDays ~/ 365} 年前';
}

/// 「今天 / 昨天 / 前天 / 5 天前 / 3 个月前」。
String relativeDay(DateTime t, DateTime now) {
  final int days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(t.year, t.month, t.day))
      .inDays;
  if (days <= 0) return '今天';
  if (days == 1) return '昨天';
  if (days == 2) return '前天';
  if (days < 30) return '$days 天前';
  if (days < 365) return '${days ~/ 30} 个月前';
  return '${days ~/ 365} 年前';
}

/// 「2026年11月27日 周五 10:23（上午）」。
String clockLine(DateTime now) {
  return '${now.year}年${now.month}月${now.day}日 ${kWeekdays[now.weekday - 1]} '
      '${_two(now.hour)}:${_two(now.minute)}（${dayPart(now)}）';
}

/// 「11月26日 22:03」：够短，放在消息列表前面不抢戏。
String shortStamp(DateTime t) {
  return '${t.month}月${t.day}日 ${_two(t.hour)}:${_two(t.minute)}';
}

/// One line of the recent-timeline block.
class RecentTurn {
  const RecentTurn(this.at, {required this.mine, required this.text});

  final DateTime at;

  /// true 表示这条是助手自己说的。
  final bool mine;
  final String text;
}

/// 塞进系统提示的那一小段「时间感」。
///
/// [previous] 是上一轮对话的时间（不含正在回复的这条），[recent] 是最近几条
/// 有内容的消息。两者都为空时只给出现在几点。
String timeContextLine({
  required DateTime now,
  DateTime? previous,
  List<RecentTurn> recent = const <RecentTurn>[],
}) {
  final StringBuffer buf = StringBuffer('现在是 ${clockLine(now)}。');

  if (previous != null) {
    buf.write('上次说话是${relativeDay(previous, now)}${dayPart(previous)}'
        '（${shortStamp(previous)}，${humanGap(now.difference(previous))}）。');
  }

  if (recent.length > 1) {
    final List<RecentTurn> tail =
        recent.length > 6 ? recent.sublist(recent.length - 6) : recent;
    buf.write('最近几条消息的时间：');
    buf.write(tail.map((RecentTurn t) {
      final String who = t.mine ? '你' : '对方';
      final String text = t.text.replaceAll('\n', ' ').trim();
      final String short = text.length > 20 ? '${text.substring(0, 20)}…' : text;
      return '${shortStamp(t.at)} $who：$short';
    }).join('；'));
    buf.write('。');
  }

  buf.write('对话记录里的消息不带时间戳，按上面的时间判断先后和间隔：'
      '别把几天前的事说成「刚才」，别在深夜说「早上好」；'
      '对方问几点、几号、多久没聊，就照这里答，不确定就别编。');
  return buf.toString();
}

