import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How much "精神口粮" she has actually eaten.
///
/// Only numbers the provider reported are counted — if the gateway omits
/// `usage`, nothing is invented. That keeps the answer honest when she is
/// asked "你今天用了多少 token".
class UsageMeter {
  UsageMeter({
    DateTime? day,
    this.inToday = 0,
    this.outToday = 0,
    this.requestsToday = 0,
    this.inTotal = 0,
    this.outTotal = 0,
    this.requestsTotal = 0,
  }) : day = day ?? DateTime.now();

  static const String storageKey = 'feiyu.usage.v1';

  DateTime day;
  int inToday;
  int outToday;
  int requestsToday;
  int inTotal;
  int outTotal;
  int requestsTotal;

  int get todayTokens => inToday + outToday;
  int get totalTokens => inTotal + outTotal;

  /// Resets the "today" counters when the local date changes.
  void rollDay(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(day.year, day.month, day.day) == today) return;
    day = today;
    inToday = 0;
    outToday = 0;
    requestsToday = 0;
  }

  /// Records one API call. Unknown fields stay zero instead of being guessed.
  void add({
    int input = 0,
    int output = 0,
    DateTime? at,
    int requests = 1,
  }) {
    final now = at ?? DateTime.now();
    rollDay(now);
    inToday += input < 0 ? 0 : input;
    outToday += output < 0 ? 0 : output;
    inTotal += input < 0 ? 0 : input;
    outTotal += output < 0 ? 0 : output;
    requestsToday += requests;
    requestsTotal += requests;
  }

  /// What she can say when asked. Empty when nothing has been measured yet.
  String get promptLine {
    if (requestsTotal == 0) return '';
    final StringBuffer buf = StringBuffer(
      '你自己的用量（接口真的报了数，才记在这里）：'
      '今天 $requestsToday 次调用，吃了 ${_num(todayTokens)} token'
      '（读 ${_num(inToday)}、说 ${_num(outToday)}）；'
      '累计 $requestsTotal 次、${_num(totalTokens)} token。'
      '被问起「你用了多少 token」就按这个答，',
    );
    if (requestsToday == 0) {
      buf.write('今天还没真正调用过模型；');
    }
    buf.write('没报数的调用不算在里面，别自己编一个更大的数。');
    return buf.toString();
  }

  /// One compact line for the settings page.
  String get settingsLine {
    if (requestsTotal == 0) return '还没有记录（接口没报过用量）';
    return '今天 ${_num(todayTokens)} token'
        '（读 ${_num(inToday)} / 说 ${_num(outToday)}，$requestsToday 次）'
        ' · 累计 ${_num(totalTokens)} token / $requestsTotal 次';
  }

  static String _num(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
    }
    if (n >= 10000) return '${(n / 1000).round()}k';
    return '$n';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'day': day.toIso8601String(),
        'inToday': inToday,
        'outToday': outToday,
        'requestsToday': requestsToday,
        'inTotal': inTotal,
        'outTotal': outTotal,
        'requestsTotal': requestsTotal,
      };

  static int _intOf(Object? raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? ''}') ?? 0;
  }

  static UsageMeter fromJson(Object? raw) {
    if (raw is! Map) return UsageMeter();
    final at = DateTime.tryParse((raw['day'] ?? '').toString());
    final meter = UsageMeter(
      day: at,
      inToday: _intOf(raw['inToday']),
      outToday: _intOf(raw['outToday']),
      requestsToday: _intOf(raw['requestsToday']),
      inTotal: _intOf(raw['inTotal']),
      outTotal: _intOf(raw['outTotal']),
      requestsTotal: _intOf(raw['requestsTotal']),
    );
    meter.rollDay(DateTime.now());
    return meter;
  }

  static Future<UsageMeter> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(storageKey);
      if (raw == null) return UsageMeter();
      return UsageMeter.fromJson(jsonDecode(raw));
    } catch (_) {
      return UsageMeter();
    }
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(storageKey, jsonEncode(toJson()));
    } catch (_) {
      // Best effort: the in-memory numbers still answer this session.
    }
  }
}
