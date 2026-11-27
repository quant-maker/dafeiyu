import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Why she might consider speaking up.
///
/// A trigger is only an *opportunity*: the model still has to pass the veto
/// gate before anything is said.
enum InitiativeTrigger {
  /// The app came back after a long pause.
  reopen,

  /// The user said something like "晚点再聊" and that time has come.
  pendingThread,

  /// A small follow-up offered shortly after she already replied.
  afterthought,

  /// The first real activity of a new local day.
  dayAnchor,

  /// Nobody has said anything (and she has not reached out) for hours.
  longSilence,

  /// The user explicitly asked her to try right now in Settings.
  manual,

  /// A single-shot check armed after a real interaction, so the web build
  /// still reaches out when the tab stays open and no lifecycle event fires.
  presence,

  /// Her own heartbeat: she woke up, went for a walk through the feeds, and
  /// decided this was worth saying out of the blue.
  heartbeat,
}

/// How long to wait before the next single-shot presence check, in minutes.
///
/// Always 25..70 inclusive; deterministic for a given seeded [Random] so the
/// scheduling can be unit tested.
int presenceDelayMinutes(Random rng) => 25 + rng.nextInt(46);

/// What kind of line she is about to say.
enum InitiativeMode { silent, chat, share }

/// 热聊里敢不敢再补一句。
///
/// 不是配额，是当下的判断依据：他刚说过话、你们还在同一个话题上、而且你
/// 没有连着说几句没人接。过了这个窗口就当聊天已经散了，别硬续。
bool followUpWorthTrying({
  required DateTime armedAt,
  required DateTime? lastReplyAt,
  required int unanswered,
  required DateTime now,
  Duration window = const Duration(minutes: 15),
}) {
  if (lastReplyAt == null) return false;
  // 他已经回了，自然会有一条正常的回复，不需要插话。
  if (lastReplyAt.isAfter(armedAt)) return false;
  // 连着两句没人接，就先收着。
  if (unanswered >= 2) return false;
  return now.difference(lastReplyAt) <= window;
}

/// A pause of this long before resuming counts as "he was away".
const Duration reopenGap = Duration(minutes: 40);

/// Silence for this long (with no proactive message) is worth a check.
const Duration longSilenceGap = Duration(hours: 6);

const List<String> _promiseMarkers = <String>[
  '开会',
  '晚点',
  '等下',
  '待会',
  '回头',
  '明天',
  '睡觉',
  '先忙',
  '出门',
  '上班',
  '下班',
  '吃饭',
  '了再',
  '再说',
];

/// True when the user's message promises to come back later.
bool promiseLike(String userText) =>
    _promiseMarkers.any(userText.contains);

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
