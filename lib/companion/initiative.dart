import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// What a proactive turn should do.
enum InitiativeKind { chat, share, silence }

/// A single decision from [InitiativePolicy].
///
/// [delay] is how long to wait from the moment [InitiativePolicy.next] was
/// asked, [reason] is a short human-readable trace used only by debugPrint.
class InitiativeDecision {
  const InitiativeDecision(this.kind, this.delay, this.reason);

  final InitiativeKind kind;
  final Duration delay;
  final String reason;

  @override
  String toString() => 'InitiativeDecision(${kind.name}, $delay, $reason)';
}

/// Decides when she may reach out, and whether to chat or share something.
///
/// The whole policy is pure: time is passed in and randomness comes from an
/// injected [Random], so every branch can be unit-tested.
class InitiativePolicy {
  InitiativePolicy({required Random rng}) : _rng = rng;

  final Random _rng;

  static const Duration _cooldown = Duration(minutes: 40);
  static const Duration _minDelay = Duration(minutes: 10);
  static const double _shareChance = .45;
  static const int _dailyCap = 3;
  static const int _quietEndHour = 7;
  static const int _quietEndMinute = 30;

  InitiativeDecision next({
    required DateTime now,
    required DateTime? lastInteractionAt,
    required DateTime? lastProactiveAt,
    required int ignoredStreak,
    required int sentToday,
    required int meanMinutes,
    required bool shareEnabled,
  }) {
    // 1. Quiet hours: silence until 07:30 plus 0..40 min of jitter.
    if (_isQuiet(now)) {
      final jitter = Duration(minutes: _rng.nextInt(41));
      return InitiativeDecision(
        InitiativeKind.silence,
        _atLeastMin(_nextMorning(now).difference(now) + jitter),
        'quiet hours until 07:30',
      );
    }

    // 2. Three proactive messages a day is enough.
    if (sentToday >= _dailyCap) {
      return InitiativeDecision(
        InitiativeKind.silence,
        _nextMorning(now).difference(now),
        'daily cap $_dailyCap/$_dailyCap, waiting for tomorrow',
      );
    }

    // 3. Three unanswered proactive messages in a row: rest until tomorrow.
    if (ignoredStreak >= 3) {
      return InitiativeDecision(
        InitiativeKind.silence,
        _nextMorning(now).difference(now),
        'ignored $ignoredStreak times, resting today',
      );
    }

    final mean = meanMinutes.clamp(1, 24 * 60).toDouble();

    // 4. Exponential sample with the given mean, clamped to 0.5..3 means.
    final u = _rng.nextDouble().clamp(0.0, 0.999999);
    var minutes = -mean * log(1 - u);
    minutes = minutes.clamp(0.5 * mean, 3.0 * mean).toDouble();

    // 5. Stretch the gap when previous nudges went unanswered.
    minutes *= 1 + ignoredStreak;

    var delay = Duration(milliseconds: (minutes * 60000).round());

    // 6. Never sooner than 40 minutes after the previous proactive message.
    if (lastProactiveAt != null) {
      final untilCooldownEnd = lastProactiveAt.add(_cooldown).difference(now);
      if (untilCooldownEnd > delay) delay = untilCooldownEnd;
    }

    // 7. Never promise anything sooner than 10 minutes.
    delay = _atLeastMin(delay);

    // 8. Sometimes share a real fetched link instead of just chatting.
    final share = shareEnabled && _rng.nextDouble() < _shareChance;
    return InitiativeDecision(
      share ? InitiativeKind.share : InitiativeKind.chat,
      delay,
      'mean ${meanMinutes}m, ignored $ignoredStreak',
    );
  }

  bool _isQuiet(DateTime now) =>
      now.hour < _quietEndHour ||
      (now.hour == _quietEndHour && now.minute < _quietEndMinute);

  /// The next 07:30 strictly relevant to [now] (today when still before it).
  DateTime _nextMorning(DateTime now) {
    final today =
        DateTime(now.year, now.month, now.day, _quietEndHour, _quietEndMinute);
    if (now.isBefore(today)) return today;
    return DateTime(
        now.year, now.month, now.day + 1, _quietEndHour, _quietEndMinute);
  }

  Duration _atLeastMin(Duration delay) =>
      delay < _minDelay ? _minDelay : delay;
}

/// Remembers which links she already shared, so a session never repeats one.
///
/// The newest [maxItems] URLs live in [SharedPreferences] under [key].
class SharedUrlStore {
  SharedUrlStore._(this._urls);

  factory SharedUrlStore.empty() => SharedUrlStore._(<String>[]);

  static const String key = 'feiyu.shared.v1';
  static const int maxItems = 20;

  final List<String> _urls;

  static Future<SharedUrlStore> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final urls = decoded.whereType<String>().take(maxItems).toList();
          return SharedUrlStore._(urls);
        }
      }
    } catch (_) {
      // Corrupt or unavailable storage: start empty, sharing still works.
    }
    return SharedUrlStore.empty();
  }

  Set<String> get urls => Set<String>.unmodifiable(_urls);

  bool seen(String url) => _urls.contains(url.trim());

  Future<void> remember(Iterable<String> urls) async {
    for (final url in urls) {
      final clean = url.trim();
      if (clean.isEmpty) continue;
      _urls.remove(clean);
      _urls.insert(0, clean);
    }
    while (_urls.length > maxItems) {
      _urls.removeLast();
    }
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, jsonEncode(_urls));
    } catch (_) {
      // Best-effort persistence; the in-memory list still de-duplicates.
    }
  }
}

/// True when a model reply is nothing but a silence marker.
///
/// Accepts `SILENCE`, `[SILENCE]`, and any letter case, with surrounding
/// whitespace.
bool isSilenceReply(String text) {
  var t = text.trim().toUpperCase();
  if (t.startsWith('[') && t.endsWith(']')) {
    t = t.substring(1, t.length - 1).trim();
  }
  return t == 'SILENCE';
}

/// True when a share reply contains a URL that has not been shared before.
///
/// Shares without any link are rejected: the link must come from a real
/// `fetch_url` return, never from the model's imagination.
bool hasFreshLink(String text, Set<String> alreadyShared) {
  final urls = RegExp(r'''https?://[^\s<>'")\]}，。；！？]+''',
          caseSensitive: false)
      .allMatches(text)
      .map((m) => m.group(0)!.replaceAll(RegExp(r'[.,;!?]+$'), ''))
      .where((u) => u.isNotEmpty);
  if (urls.isEmpty) return false;
  return urls.any((u) => !alreadyShared.contains(u));
}
