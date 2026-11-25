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
}

/// How long to wait before the next single-shot presence check, in minutes.
///
/// Always 25..70 inclusive; deterministic for a given seeded [Random] so the
/// scheduling can be unit tested.
int presenceDelayMinutes(Random rng) => 25 + rng.nextInt(46);

/// What the veto gate decided an opportunity should become.
enum InitiativeMode { silent, chat, share }

/// Maps a raw veto reply to exactly one [InitiativeMode].
///
/// Anything that is not a recognised SPEAK variant is [InitiativeMode.silent];
/// a bare `SPEAK` means a plain chat message. Both ASCII and full-width colons
/// are accepted, plus stray backticks or quotes around the marker.
InitiativeMode parseVetoReply(String raw) {
  final t = raw.trim().toUpperCase().replaceAll('`', '').replaceAll('"', '');
  // An explicit silence decision wins, and this also covers a weak model that
  // merely echoed the whole menu ("SILENT / SPEAK:CHAT / SPEAK:SHARE"): if the
  // reply mentions SILENT at all we must not treat it as a go-ahead to share.
  if (t.contains('SILENT') || t.contains('SILENCE')) {
    return InitiativeMode.silent;
  }
  if (t.contains('SPEAK:SHARE') || t.contains('SPEAK：SHARE')) {
    return InitiativeMode.share;
  }
  if (t.contains('SPEAK:CHAT') || t.contains('SPEAK：CHAT')) {
    return InitiativeMode.chat;
  }
  if (t.contains('SPEAK')) return InitiativeMode.chat;
  return InitiativeMode.silent;
}

/// A concrete chance to speak, produced by [pickOpportunity].
class InitiativeOpportunity {
  const InitiativeOpportunity(this.trigger, this.reason);

  final InitiativeTrigger trigger;

  /// Short human-readable trace, only used by debugPrint.
  final String reason;

  @override
  String toString() => 'InitiativeOpportunity(${trigger.name}, $reason)';
}

/// A pause of this long before resuming counts as "he was away".
const Duration reopenGap = Duration(minutes: 40);

/// Silence for this long (with no proactive message) is worth a check.
const Duration longSilenceGap = Duration(hours: 6);

/// The floor between two proactive messages, whatever the trigger and whatever
/// the veto gate says.
///
/// This is the backstop that makes a burst physically impossible: a pile of
/// timers firing together, or a gate that answers "yes" to everything, still
/// yields at most one message per gap.
const Duration minProactiveGap = Duration(minutes: 45);

/// How many messages may go out in a day while the veto gate is unavailable
/// (timeout, network error, junk reply).
///
/// Kept separately from the normal daily cap so a flaky gateway degrades into
/// "slightly more talkative" instead of "will not stop talking".
const int maxUnsurePerDay = 2;

/// True when enough time has passed since the last proactive message.
///
/// A null [lastAt] means she has not spoken yet, which always allows.
bool gapAllowsSpeak(DateTime? lastAt, DateTime now) =>
    lastAt == null || now.difference(lastAt) >= minProactiveGap;

/// True when a message the gate could not judge may still be sent.
bool unsureAllowsSpeak(int unsureToday) => unsureToday < maxUnsurePerDay;

/// True between 00:00 and 07:30 local time.
bool inQuietHours(DateTime now) =>
    now.hour < 7 || (now.hour == 7 && now.minute < 30);

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

/// Picks the one opportunity that best matches the current state.
///
/// Pure: callers pass the clock and counters in, so every branch is testable.
/// Returns `null` when nothing should even be considered.
InitiativeOpportunity? pickOpportunity({
  required DateTime now,
  required DateTime? lastInteractionAt,
  required DateTime? lastProactiveAt,
  required int sentToday,
  required int ignoredStreak,
  required bool hadAfterthoughtForLastTurn,
  required bool dayAnchorDone,
  bool longSilenceDone = false,
}) {
  if (inQuietHours(now)) return null;
  if (sentToday >= 3) return null;
  if (ignoredStreak >= 3) return null;

  // He was gone for a while and has just come back.
  if (lastInteractionAt != null &&
      now.difference(lastInteractionAt) >= reopenGap) {
    final minutes = now.difference(lastInteractionAt).inMinutes;
    return InitiativeOpportunity(
      InitiativeTrigger.reopen,
      '离开了 $minutes 分钟又回来',
    );
  }

  // No proactive message for a long time today.
  final sinceProactive =
      lastProactiveAt == null ? null : now.difference(lastProactiveAt);
  if (!longSilenceDone &&
      (sinceProactive == null || sinceProactive >= longSilenceGap)) {
    return const InitiativeOpportunity(
      InitiativeTrigger.longSilence,
      '很久没主动说话了',
    );
  }

  // First activity of a new day.
  if (!dayAnchorDone) {
    return const InitiativeOpportunity(
      InitiativeTrigger.dayAnchor,
      '今天第一次见到主人',
    );
  }

  // A single small afterthought per assistant turn.
  if (!hadAfterthoughtForLastTurn) {
    return const InitiativeOpportunity(
      InitiativeTrigger.afterthought,
      '刚才那句话之后还想补一句',
    );
  }

  return null;
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
