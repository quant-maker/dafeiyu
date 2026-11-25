/// 时间分层的小工具：把时刻折算成「日 / 周 / 月」的键，判断某个周期是否已经走完。
///
/// 这些函数全是纯函数，方便单测（见 test/timeline_test.dart）。
library;

String _two(int v) => v.toString().padLeft(2, '0');

/// 当天零点。
DateTime dayStart(DateTime t) => DateTime(t.year, t.month, t.day);

/// 当天最后一毫秒（不含）。
DateTime dayEnd(DateTime t) => dayStart(t).add(const Duration(days: 1));

/// `2026-11-25`
String dayKey(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

DateTime? parseDayKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final t = DateTime(y, mo, d);
  if (t.month != mo || t.day != d) return null;
  return t;
}

/// 所在周的周一（ISO：周一为一周之始）。
DateTime weekStart(DateTime t) {
  final d = dayStart(t);
  return d.subtract(Duration(days: d.weekday - 1));
}

int _isoWeekNumber(DateTime thursday) {
  final jan1 = DateTime(thursday.year, 1, 1);
  final dayOfYear = thursday.difference(jan1).inDays + 1;
  return ((dayOfYear - 1) ~/ 7) + 1;
}

/// `2026-W48`，用该周周四所在的年份做年号（ISO 规则）。
String weekKey(DateTime t) {
  final ws = weekStart(t);
  final thursday = ws.add(const Duration(days: 3));
  return '${thursday.year}-W${_two(_isoWeekNumber(thursday))}';
}

/// `2026-11`
String monthKey(DateTime t) => '${t.year}-${_two(t.month)}';

/// 这一天是否可以结账了：过去的整天算走完，今天要过了 23 点。
bool isDayComplete(DateTime day, DateTime now) {
  final d = dayStart(day);
  final today = dayStart(now);
  if (d.isBefore(today)) return true;
  if (d.isAfter(today)) return false;
  return now.hour >= 23;
}

/// 这一周是否走完（下周一已经到来）。
bool isWeekComplete(DateTime anyDayInWeek, DateTime now) {
  final next = weekStart(anyDayInWeek).add(const Duration(days: 7));
  return !dayStart(now).isBefore(next);
}

/// 这个月是否走完（下个月一号已经到来）。
bool isMonthComplete(DateTime anyDayInMonth, DateTime now) {
  final next = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);
  return !dayStart(now).isBefore(next);
}

/// 给人看的日期标签，用在日记与提示词里。
String dayLabel(String key) {
  final d = parseDayKey(key);
  if (d == null) return key;
  return '${d.month}月${d.day}日';
}

/// 周标签：`11月24日那周`
String weekLabel(String key) {
  final m = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(key.trim());
  if (m == null) return key;
  final year = int.parse(m.group(1)!);
  final week = int.parse(m.group(2)!);
  // 该年 1 月 4 日必在第一周。
  final jan4 = DateTime(year, 1, 4);
  final firstMonday = weekStart(jan4);
  final monday = firstMonday.add(Duration(days: (week - 1) * 7));
  return '${monday.month}月${monday.day}日那周';
}

/// 月标签：`2026年11月`
String monthLabel(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key.trim());
  if (m == null) return key;
  return '${m.group(1)}年${int.parse(m.group(2)!)}月';
}
