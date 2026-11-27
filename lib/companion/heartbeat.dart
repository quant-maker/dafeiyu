import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// How long until the next heartbeat.
///
/// A heartbeat is cheap on purpose: it only touches local state, and the
/// expensive parts (pulling feeds, maybe talking to a model) happen on a much
/// sparser cadence chosen by the caller. 4..12 minutes is frequent enough to
/// feel like someone is living between messages, and slow enough to survive a
/// phone that is left open for hours.
Duration nextBeatDelay(Random rng, {bool afterFailure = false}) {
  if (afterFailure) return Duration(minutes: 12 + rng.nextInt(9));
  return Duration(minutes: 4 + rng.nextInt(9));
}

/// Minimum spacing between two heartbeat-driven messages.
const Duration heartbeatMinGap = Duration(minutes: 12);

/// A soft daily ceiling for heartbeat messages. Higher than the old
/// opportunity budget because the whole point is that she no longer has to
/// wait for a slot — but not unlimited, or it becomes noise.
const int heartbeatDailyCap = 14;

/// Late night is capped separately instead of silenced.
const int heartbeatNightCap = 3;

/// Whether a heartbeat message may go out right now.
///
/// Deliberately simpler than the old opportunity gate: a minimum gap and a
/// daily ceiling, and nothing about "the user has been idle for N minutes" —
/// she may speak first whenever she has something.
bool heartbeatMayShare({
  required DateTime? lastShareAt,
  required DateTime now,
  required int sharesToday,
  required bool isNight,
}) {
  if (lastShareAt != null && now.difference(lastShareAt) < heartbeatMinGap) {
    return false;
  }
  final cap = isNight ? heartbeatNightCap : heartbeatDailyCap;
  return sharesToday < cap;
}

/// One person she keeps running into in the feeds.
class KnownVoice {
  KnownVoice({
    required this.name,
    required this.source,
    this.count = 1,
    DateTime? lastAt,
  }) : lastAt = lastAt ?? DateTime.now();

  final String name;
  final String source;
  int count;
  DateTime lastAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'source': source,
        'count': count,
        'lastAt': lastAt.toIso8601String(),
      };

  static KnownVoice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = (raw['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    return KnownVoice(
      name: name,
      source: (raw['source'] ?? '').toString().trim(),
      count: (raw['count'] as num?)?.toInt() ?? 1,
      lastAt: DateTime.tryParse((raw['lastAt'] ?? '').toString()),
    );
  }
}

/// The persisted heartbeat: when it last beat, how much she has been up to
/// today, what she just looked at, and the names she keeps seeing.
///
/// Its only job is to make time feel continuous across restarts — without it
/// every relaunch wipes her sense of "I was browsing ten minutes ago".
class HeartbeatState {
  HeartbeatState({
    this.lastBeatAt,
    this.lastBrowseAt,
    this.lastShareAt,
    this.lastFootprintAt,
    DateTime? day,
    this.beatsToday = 0,
    this.sharesToday = 0,
    this.sharesTonight = 0,
    this.lastNote = '',
    Map<String, KnownVoice>? voices,
  })  : day = day ?? _midnight(DateTime.now()),
        voices = voices ?? <String, KnownVoice>{};

  static const String key = 'feiyu.heartbeat.v1';

  /// How many distinct names to keep around.
  static const int maxVoices = 40;

  DateTime? lastBeatAt;
  DateTime? lastBrowseAt;
  DateTime? lastShareAt;
  DateTime? lastFootprintAt;

  /// Local midnight of the day the counters belong to.
  DateTime day;
  int beatsToday;
  int sharesToday;

  /// Shares sent between 22:00 and 07:00, capped separately.
  int sharesTonight;

  /// What she was just doing, in her own shorthand.
  String lastNote;

  /// `source:name` → who she saw there.
  final Map<String, KnownVoice> voices;

  static DateTime _midnight(DateTime t) => DateTime(t.year, t.month, t.day);

  static bool isNight(DateTime now) => now.hour >= 22 || now.hour < 7;

  /// Moves the counters to the current local day (no-op inside one day).
  void rollDay(DateTime now) {
    final today = _midnight(now);
    if (today == day) return;
    day = today;
    beatsToday = 0;
    sharesToday = 0;
    sharesTonight = 0;
  }

  void beat(DateTime now) {
    rollDay(now);
    lastBeatAt = now;
    beatsToday++;
  }

  /// Records that she ran into [name] while browsing [source].
  void seeVoice(String source, String name, DateTime now) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final key = '${source.trim()}:$clean';
    final existing = voices[key];
    if (existing == null) {
      voices[key] = KnownVoice(name: clean, source: source.trim(), lastAt: now);
      if (voices.length > maxVoices) {
        // Drop the oldest-seen names first; familiarity is about recency.
        final oldest = voices.entries.toList()
          ..sort((a, b) => a.value.lastAt.compareTo(b.value.lastAt));
        for (final entry in oldest.take(voices.length - maxVoices)) {
          voices.remove(entry.key);
        }
      }
      return;
    }
    existing
      ..count += 1
      ..lastAt = now;
  }

  /// Names she has met more than once, newest first.
  List<KnownVoice> get familiar {
    final list = voices.values.where((v) => v.count > 1).toList()
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return list;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lastBeatAt': lastBeatAt?.toIso8601String(),
        'lastBrowseAt': lastBrowseAt?.toIso8601String(),
        'lastShareAt': lastShareAt?.toIso8601String(),
        'lastFootprintAt': lastFootprintAt?.toIso8601String(),
        'day': day.toIso8601String(),
        'beatsToday': beatsToday,
        'sharesToday': sharesToday,
        'sharesTonight': sharesTonight,
        'lastNote': lastNote,
        'voices': voices.values.map((v) => v.toJson()).toList(),
      };

  static HeartbeatState fromJson(Map<String, dynamic> j) {
    final voices = <String, KnownVoice>{};
    final rawVoices = j['voices'];
    if (rawVoices is List) {
      for (final raw in rawVoices) {
        final v = KnownVoice.fromJson(raw);
        if (v != null) voices['${v.source}:${v.name}'] = v;
      }
    }
    return HeartbeatState(
      lastBeatAt: DateTime.tryParse((j['lastBeatAt'] ?? '').toString()),
      lastBrowseAt: DateTime.tryParse((j['lastBrowseAt'] ?? '').toString()),
      lastShareAt: DateTime.tryParse((j['lastShareAt'] ?? '').toString()),
      lastFootprintAt:
          DateTime.tryParse((j['lastFootprintAt'] ?? '').toString()),
      day: DateTime.tryParse((j['day'] ?? '').toString()),
      beatsToday: _intOf(j['beatsToday']),
      sharesToday: _intOf(j['sharesToday']),
      sharesTonight: _intOf(j['sharesTonight']),
      lastNote: (j['lastNote'] ?? '').toString(),
      voices: voices,
    );
  }

  /// Tolerant int read: stored JSON is not always written by this version.
  static int _intOf(Object? raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static Future<HeartbeatState> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(key);
      if (raw == null) return HeartbeatState();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return HeartbeatState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // Corrupt storage should never stop her from living.
    }
    return HeartbeatState();
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, jsonEncode(toJson()));
    } catch (_) {
      // Best effort: the in-memory state still drives this session.
    }
  }
}
