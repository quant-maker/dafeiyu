import 'dart:convert';

import 'db.dart' show Block, Episode;
import 'digest.dart';
import 'graph.dart';
import 'store.dart';
import 'timeline.dart';

/// 调模型的入口。注入成函数，为了方便测试与换源。
typedef MemoryChat = Future<String> Function(String prompt);

/// 算向量的入口。拿不到向量时传 null，记忆照样落库（只是检索退化为关键词）。
typedef MemoryEmbed = Future<List<double>> Function(String text);

/// 一段对话里的转折点。
class TranscriptTurn {
  final bool fromUser;
  final String text;

  const TranscriptTurn({required this.fromUser, required this.text});

  String render() => '${fromUser ? '主人' : '我'}：$text';
}

/// 一次维护做了什么。
class MaintenanceReport {
  int dayCards = 0;
  int weekCards = 0;
  int monthCards = 0;
  bool truncated = false;
  String? error;

  bool get didSomething => dayCards + weekCards + monthCards > 0;

  @override
  String toString() =>
      'Maintenance(day+$dayCards, week+$weekCards, month+$monthCards'
      '${truncated ? ', truncated' : ''}${error == null ? '' : ', error: $error'})';
}

/// 记忆的「管家」：把对话熬成情景，把情景熬成日结，再熬成周结月结。
///
/// 对应 docs/memory-design.md 的 P1。原则是只向上折一层、谱系永活：
/// 每个块的 directIds 指向下一层，effectiveIds 覆盖到全部原始情景。
class MemoryCurator {
  final MemoryStore store;
  final MemoryChat? chat;
  final MemoryEmbed? embed;

  /// 一次维护最多熬几篇日结，避免首次运行把模型额度打光。
  final int maxDayCardsPerRun;

  MemoryCurator({
    required this.store,
    this.chat,
    this.embed,
    this.maxDayCardsPerRun = 3,
  });

  // -------------------------------------------------------------- 情景抽取

  /// 把一段对话抽成 0–[maxPerChunk] 条情景，返回新落库的情景 id。
  ///
  /// 模型调用失败时返回 `null`，而不是空列表：调用方要能区分「这段没有值得记的」
  /// 和「这次没抽成」，后者不能前移摘要游标，否则这段对话就永远丢了。
  /// 返回 id 还有个用处：紧跟其后的星图抽取可以把边挂到具体情景上（证据）。
  Future<List<int>?> extractEpisodes(
    List<TranscriptTurn> turns, {
    DateTime? at,
    int maxPerChunk = 3,
    int importanceFallback = 3,
    bool localOnly = false,
  }) async {
    final fn = chat;
    if (fn == null) return const <int>[];
    final clean = turns
        .map((t) => TranscriptTurn(fromUser: t.fromUser, text: t.text.trim()))
        .where((t) => t.text.isNotEmpty)
        .toList();
    if (clean.isEmpty) return const <int>[];
    final transcript = clean.map((t) => t.render()).join('\n');
    if (transcript.length < 40) return const <int>[];

    final when = at ?? DateTime.now();
    List<EpisodeDraft> drafts;
    try {
      final raw = await fn(episodeExtractionPrompt(transcript));
      drafts = parseEpisodeDrafts(raw);
    } catch (_) {
      return null;
    }
    if (drafts.isEmpty) return const <int>[];

    final from = dayStartMs(when);
    final to = from + const Duration(days: 1).inMilliseconds;
    final added = <int>[];
    for (final d in drafts.take(maxPerChunk)) {
      final body = d.body.trim();
      if (body.isEmpty) continue;
      if (await store.hasSimilarEpisode(body, fromMs: from, toMs: to)) continue;
      List<double>? vec;
      final ef = embed;
      if (ef != null) {
        try {
          final v = await ef(body);
          if (v.isNotEmpty) vec = v;
        } catch (_) {
          // 向量失败不影响落库。
        }
      }
      final id = await store.addEpisode(
        at: when,
        title: d.title,
        body: body,
        vector: vec,
        importance: d.importance == 3 ? importanceFallback : d.importance,
        localOnly: localOnly,
      );
      if (id > 0) added.add(id);
    }
    return added;
  }

  // -------------------------------------------------------------- 星图抽取

  /// 抽出实体与关系，落到星图上。返回新建/强化的实体数。
  Future<int> extractGraph(
    List<TranscriptTurn> turns, {
    DateTime? at,
    int? episodeId,
    int maxEntities = 8,
  }) async {
    final fn = chat;
    if (fn == null) return 0;
    final transcript = turns
        .map((t) => TranscriptTurn(fromUser: t.fromUser, text: t.text.trim()))
        .where((t) => t.text.isNotEmpty)
        .map((t) => t.render())
        .join('\n');
    if (transcript.length < 30) return 0;

    GraphDraft draft;
    try {
      draft = parseGraph(await fn(graphExtractionPrompt(transcript)));
    } catch (_) {
      return 0;
    }
    if (draft.isEmpty) return 0;

    final when = at ?? DateTime.now();
    final ids = <String, int>{};
    for (final e in draft.entities.take(maxEntities)) {
      final id = await store.upsertEntity(
        name: e.name,
        kind: e.kind.value,
        importance: e.importance,
        at: when,
      );
      if (id > 0) ids[e.name] = id;
    }
    for (final edge in draft.edges) {
      final s = ids[edge.src];
      final d = ids[edge.dst];
      if (s == null || d == null) continue;
      await store.upsertEdge(
        src: s,
        dst: d,
        kind: edge.kind,
        label: edge.label,
        at: when,
        evidenceEpisode: episodeId,
      );
    }
    return ids.length;
  }

  // -------------------------------------------------------------- 分层维护

  /// 结账：把走完的那天/周/月折上去。可以反复调用，已折过的不会重复。
  Future<MaintenanceReport> runMaintenance({DateTime? now}) async {
    final report = MaintenanceReport();
    final fn = chat;
    if (fn == null) return report;
    final t = now ?? DateTime.now();

    try {
      final continued = await _foldDays(fn, t, report);
      if (continued) {
        await _foldWeeks(fn, t, report);
        await _foldMonths(fn, t, report);
      }
    } catch (e) {
      report.error = e.toString();
    }
    return report;
  }

  /// 返回是否还能继续往上折（这一轮被日结上限截断时先不折周结，
  /// 否则剩下那几天以后再也进不了周结）。
  Future<bool> _foldDays(MemoryChat fn, DateTime now, MaintenanceReport report) async {
    // 只许把「可以外发」的情景折成日结：标了 localOnly 的只在手机里躺着，
    // 一旦进日结就会被当成 prompt 的一部分发给网关。
    final all = (await store.episodes(limit: 5000))
        .where((e) => !e.localOnly)
        .toList();
    if (all.isEmpty) return true;
    final byDay = <String, List<Episode>>{};
    for (final e in all) {
      byDay.putIfAbsent(dayKey(DateTime.fromMillisecondsSinceEpoch(e.at)), () => []).add(e);
    }
    final done = await store.blockTopics(1);
    final days = byDay.keys.toList()..sort();
    var made = 0;
    for (final key in days) {
      if (made >= maxDayCardsPerRun) {
        report.truncated = true;
        break;
      }
      if (done.contains('day:$key')) continue;
      final day = parseDayKey(key);
      if (day == null || !isDayComplete(day, now)) continue;
      final eps = byDay[key]!;
      final bodies = eps.map((e) => e.body).toList();
      final summary = cleanModelText(await fn(dayCardPrompt(dayLabel: dayLabel(key), episodes: bodies)));
      if (summary.isEmpty) continue;
      final ids = eps.map((e) => e.id).toList();
      await store.putBlock(
        tier: 1,
        topic: 'day:$key',
        summary: summary,
        directIds: ids,
        effectiveIds: ids,
        spanFrom: eps.first.at,
        spanTo: eps.last.at,
      );
      made++;
      report.dayCards++;
    }
    // 还有没折完的天就先别往上折：周结只折一次，提前结账会永久漏掉后补的那几天。
    return !report.truncated;
  }

  Future<void> _foldWeeks(MemoryChat fn, DateTime now, MaintenanceReport report) async {
    final dayBlocks = await store.blocksOfTier(1, limit: 1000);
    if (dayBlocks.isEmpty) return;
    final groups = <String, List<Block>>{};
    for (final b in dayBlocks) {
      final key = b.topic?.replaceFirst('day:', '') ?? '';
      final day = parseDayKey(key);
      if (day == null) continue;
      groups.putIfAbsent(weekKey(day), () => []).add(b);
    }
    // 有情景、却还没折成日结的那几天，所在的周先挂起。
    final doneDays = await store.blockTopics(1);
    final pendingWeeks = <String>{};
    for (final e in await store.episodes(limit: 5000)) {
      if (e.localOnly) continue;
      final key = dayKey(DateTime.fromMillisecondsSinceEpoch(e.at));
      if (doneDays.contains('day:$key')) continue;
      final day = parseDayKey(key);
      if (day != null) pendingWeeks.add(weekKey(day));
    }
    final done = await store.blockTopics(2);
    var made = 0;
    for (final entry in groups.entries) {
      if (made >= 2) break;
      final key = entry.key;
      if (done.contains('week:$key')) continue;
      if (pendingWeeks.contains(key)) continue;
      final blocks = entry.value;
      final firstDay = _firstSpan(blocks);
      if (firstDay == null) continue;
      if (!isWeekComplete(firstDay, now)) continue;
      final cards = _orderedSummaries(blocks);
      final summary = cleanModelText(await fn(rollupPrompt(label: weekLabel(key), level: '周', cards: cards)));
      if (summary.isEmpty) continue;
      await store.putBlock(
        tier: 2,
        topic: 'week:$key',
        summary: summary,
        directIds: blocks.map((b) => b.id).toList(),
        effectiveIds: _mergeIds(blocks),
        spanFrom: _minSpan(blocks, (b) => b.spanFrom),
        spanTo: _maxSpan(blocks, (b) => b.spanTo),
      );
      made++;
      report.weekCards++;
    }
  }

  Future<void> _foldMonths(MemoryChat fn, DateTime now, MaintenanceReport report) async {
    final weekBlocks = await store.blocksOfTier(2, limit: 500);
    if (weekBlocks.isEmpty) return;
    final groups = <String, List<Block>>{};
    for (final b in weekBlocks) {
      final key = (b.topic ?? '').replaceFirst('week:', '');
      final day = _firstSpan([b]);
      final month = day == null ? key.substring(0, key.length.clamp(0, 7)) : monthKey(day);
      groups.putIfAbsent(month, () => []).add(b);
    }
    // 有日结、却还没折成周结的周，所在的月先挂起，等周结补齐再折月。
    final doneWeeks = await store.blockTopics(2);
    final pendingMonths = <String>{};
    for (final b in await store.blocksOfTier(1, limit: 1000)) {
      final key = b.topic?.replaceFirst('day:', '') ?? '';
      final day = parseDayKey(key);
      if (day == null) continue;
      if (doneWeeks.contains('week:${weekKey(day)}')) continue;
      final at = b.spanFrom ?? b.createdAt;
      pendingMonths.add(monthKey(DateTime.fromMillisecondsSinceEpoch(at)));
    }
    final done = await store.blockTopics(3);
    for (final entry in groups.entries) {
      final key = entry.key;
      if (done.contains('month:$key')) continue;
      if (pendingMonths.contains(key)) continue;
      final blocks = entry.value;
      final firstDay = _firstSpan(blocks);
      if (firstDay == null) continue;
      if (!isMonthComplete(firstDay, now)) continue;
      final cards = _orderedSummaries(blocks);
      final summary = cleanModelText(await fn(rollupPrompt(label: monthLabel(key), level: '月', cards: cards)));
      if (summary.isEmpty) continue;
      await store.putBlock(
        tier: 3,
        topic: 'month:$key',
        summary: summary,
        directIds: blocks.map((b) => b.id).toList(),
        effectiveIds: _mergeIds(blocks),
        spanFrom: _minSpan(blocks, (b) => b.spanFrom),
        spanTo: _maxSpan(blocks, (b) => b.spanTo),
      );
      report.monthCards++;
    }
  }

  // -------------------------------------------------------------- 小工具

  DateTime? _firstSpan(List<Block> blocks) {
    for (final b in blocks) {
      if (b.spanFrom != null) return DateTime.fromMillisecondsSinceEpoch(b.spanFrom!);
    }
    if (blocks.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(blocks.first.createdAt);
  }

  int? _minSpan(List<Block> blocks, int? Function(Block) pick) {
    int? out;
    for (final b in blocks) {
      final v = pick(b);
      if (v == null) continue;
      if (out == null || v < out) out = v;
    }
    return out;
  }

  int? _maxSpan(List<Block> blocks, int? Function(Block) pick) {
    int? out;
    for (final b in blocks) {
      final v = pick(b);
      if (v == null) continue;
      if (out == null || v > out) out = v;
    }
    return out;
  }

  List<String> _orderedSummaries(List<Block> blocks) {
    final sorted = [...blocks]..sort((a, b) => (a.spanFrom ?? a.createdAt).compareTo(b.spanFrom ?? b.createdAt));
    return sorted.map((b) => b.summary).toList();
  }

  List<int> _mergeIds(List<Block> blocks) {
    final seen = <int>{};
    final out = <int>[];
    for (final b in blocks) {
      for (final id in _parseIds(b.effectiveIds)) {
        if (seen.add(id)) out.add(id);
      }
    }
    return out;
  }

  static List<int> _parseIds(String json) {
    try {
      final data = jsonDecode(json);
      if (data is! List) return const [];
      return data.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return const [];
    }
  }
}
