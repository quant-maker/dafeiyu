import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The small daily budget behind proactive speech, persisted so a restart is
/// not a reset.
///
/// Everything here used to live only in memory on the root state: killing the
/// app four times let her open twelve conversations in a day (the cap is three)
/// and wiped the "you ignored me" penalty, which is the only thing that stops
/// her from nagging.
class InitiativeBudget {
  InitiativeBudget({
    required this.day,
    this.sent = 0,
    this.opportunities = 0,
    this.ignoredStreak = 0,
    this.unsure = 0,
    this.lastAt,
  });

  /// Local midnight of the day these counters belong to.
  DateTime day;
  int sent;
  int opportunities;
  int ignoredStreak;

  /// Messages she sent without a working veto (the gate timed out or the
  /// provider answered with junk). Capped separately from [sent] so a flaky
  /// gateway cannot turn "speak when unsure" into a stream of messages.
  int unsure;

  /// When she last said something, kept across restarts so the minimum gap
  /// between two proactive messages survives a relaunch.
  DateTime? lastAt;

  static const String key = 'feiyu.budget.v1';

  static DateTime _midnight(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Zero the counters when the stored day is not today.
  bool rollTo(DateTime now) {
    final DateTime today = _midnight(now);
    if (day == today) return false;
    day = today;
    sent = 0;
    opportunities = 0;
    ignoredStreak = 0;
    unsure = 0;
    return true;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': day.toIso8601String(),
    'sent': sent,
    'opportunities': opportunities,
    'ignoredStreak': ignoredStreak,
    'unsure': unsure,
    if (lastAt != null) 'lastAt': lastAt!.toIso8601String(),
  };

  static InitiativeBudget _fresh(DateTime now) =>
      InitiativeBudget(day: _midnight(now));

  /// Coerce a stored value to a non-negative int without ever throwing.
  static int _count(dynamic v) {
    final int n;
    if (v is num) {
      n = v.toInt();
    } else if (v is String) {
      n = int.tryParse(v.trim()) ?? 0;
    } else {
      n = 0;
    }
    return n < 0 ? 0 : n;
  }

  static InitiativeBudget fromJson(Map<String, dynamic> j, DateTime now) {
    final dynamic rawDay = j['day'];
    final DateTime? day =
        rawDay is String ? DateTime.tryParse(rawDay) : null;
    final dynamic rawLast = j['lastAt'];
    return InitiativeBudget(
      day: day == null ? _midnight(now) : _midnight(day),
      sent: _count(j['sent']),
      opportunities: _count(j['opportunities']),
      ignoredStreak: _count(j['ignoredStreak']),
      unsure: _count(j['unsure']),
      lastAt: rawLast is String ? DateTime.tryParse(rawLast) : null,
    );
  }

  /// Never throws: a read failure just means "fresh day, fresh budget".
  static Future<InitiativeBudget> load({DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final String? raw = sp.getString(key);
      if (raw == null) return _fresh(at);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return _fresh(at);
      return fromJson(decoded.cast<String, dynamic>(), at);
    } catch (_) {
      return _fresh(at);
    }
  }

  Future<void> save() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setString(key, jsonEncode(toJson()));
    } catch (_) {
      // Storage full or unavailable: the in-memory counters still hold for
      // this session, which is exactly the old behaviour.
    }
  }
}
