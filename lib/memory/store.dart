import 'dart:convert';

import 'package:drift/drift.dart' as dr;
import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';
import 'db_conn.dart';
import 'scoring.dart';

export 'scoring.dart' show quantizeVector, cosineInt8, cosine;

/// 记忆的唯一入口：事实、情景、检索、旧数据迁移。
///
/// 设计原则（见 docs/memory-design.md）：
///  - 只压增量，绝不重写历史
///  - 衰减只降权重，不删数据
///  - 事实带双时间（firstSeen / lastSeen）与重要度
class MemoryStore {
  final MemoryDb db;

  MemoryStore(this.db);

  static Future<MemoryStore> open() async {
    final store = MemoryStore(await openMemoryDb());
    await store._migrateLegacy();
    return store;
  }

  Future<void> close() => db.close();

  // ---------------------------------------------------------------- 事实

  Future<List<Fact>> facts({bool includeInvalidated = false}) {
    final q = db.select(db.facts);
    if (!includeInvalidated) q.where((t) => t.invalidatedAt.isNull());
    q.orderBy([
      (t) => dr.OrderingTerm(expression: t.importance, mode: dr.OrderingMode.desc),
      (t) => dr.OrderingTerm(expression: t.lastSeen, mode: dr.OrderingMode.desc),
    ]);
    return q.get();
  }

  Future<int> factCount() async {
    final c = db.facts.id.count();
    final row = await (db.selectOnly(db.facts)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  /// 稳定注入用：按 重要度 × 新鲜度 取，字符预算封顶。
  Future<String> factsPrompt({int maxChars = 1200}) async {
    final all = await facts();
    if (all.isEmpty) return '';
    final now = DateTime.now();
    final scored = all
        .map((f) => MapEntry(
              f,
              0.7 * (f.importance / 5.0) +
                  0.3 * recencyScore(DateTime.fromMillisecondsSinceEpoch(f.lastSeen), now),
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final lines = <String>[];
    var used = 0;
    for (final e in scored) {
      final line = '- ${e.key.content}';
      if (used + line.length > maxChars) break;
      lines.add(line);
      used += line.length + 1;
    }
    if (lines.isEmpty) return '';
    return '你记得关于主人的这些事（长期记忆，自然使用，不要逐条复述）：\n${lines.join('\n')}';
  }

  Future<void> addFact(String text, {int importance = 3, bool localOnly = false}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.facts).insert(
          FactsCompanion.insert(
            content: t,
            importance: dr.Value(importance),
            firstSeen: now,
            lastSeen: now,
            localOnly: dr.Value(localOnly),
          ),
        );
  }

  Future<void> updateFactText(int id, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await (db.update(db.facts)..where((f) => f.id.equals(id))).write(
      FactsCompanion(
        content: dr.Value(t),
        lastSeen: dr.Value(DateTime.now().millisecondsSinceEpoch),
        hitCount: dr.Value(1),
      ),
    );
  }

  Future<void> deleteFact(int id) async {
    await (db.delete(db.facts)..where((f) => f.id.equals(id))).go();
  }

  /// 合并新抽取出来的事实：重复的只加权重，不新增行。
  /// 超出 [maxRows] 时按「重要度 × 新鲜度」淘汰分数最低的，而不是 FIFO。
  Future<void> mergeFacts(Iterable<String> incoming, {int maxRows = 200}) async {
    final existing = await facts();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final raw in incoming) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      Fact? hit;
      for (final f in existing) {
        if (f.content == t ||
            (f.content.length > 8 && t.length > 8 && (f.content.contains(t) || t.contains(f.content)))) {
          hit = f;
          break;
        }
      }
      if (hit == null) {
        final id = await db.into(db.facts).insert(
              FactsCompanion.insert(
                content: t,
                importance: const dr.Value(3),
                firstSeen: now,
                lastSeen: now,
              ),
            );
        existing.add(await (db.select(db.facts)..where((f) => f.id.equals(id))).getSingle());
      } else {
        await (db.update(db.facts)..where((f) => f.id.equals(hit!.id))).write(
          FactsCompanion(
            hitCount: dr.Value(hit.hitCount + 1),
            lastSeen: dr.Value(now),
            importance: dr.Value((hit.importance + 1).clamp(1, 5)),
          ),
        );
      }
    }
    await _evictFacts(maxRows);
  }

  Future<void> _evictFacts(int maxRows) async {
    final all = await facts();
    if (all.length <= maxRows) return;
    final now = DateTime.now();
    final ranked = all.toList()
      ..sort((a, b) {
        double s(Fact f) =>
            (f.importance / 5.0) *
            recencyScore(DateTime.fromMillisecondsSinceEpoch(f.lastSeen), now);
        return s(a).compareTo(s(b));
      });
    final drop = all.length - maxRows;
    for (var i = 0; i < drop; i++) {
      await deleteFact(ranked[i].id);
    }
  }

  // ---------------------------------------------------------------- 情景

  Future<int> episodeCount() async {
    final c = db.episodes.id.count();
    final row = await (db.selectOnly(db.episodes)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<int> addEpisode({
    DateTime? at,
    String? title,
    required String body,
    List<double>? vector,
    int importance = 3,
    String? rawRef,
    String? place,
    String? session,
    bool localOnly = false,
    int? localOnlyOverride,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return 0;
    final when = at ?? DateTime.now();
    final vec = (vector == null || vector.isEmpty) ? null : quantizeVector(vector);
    return db.into(db.episodes).insert(
          EpisodesCompanion.insert(
            at: when.millisecondsSinceEpoch,
            title: (title == null || title.trim().isEmpty)
                ? text.substring(0, text.length < 24 ? text.length : 24)
                : title.trim(),
            body: text,
            session: dr.Value(session),
            place: dr.Value(place),
            rawRef: dr.Value(rawRef),
            weight: dr.Value((importance / 5.0).clamp(0.2, 1.0)),
            vec: dr.Value(vec),
            vecDims: dr.Value(vec?.length ?? 0),
            localOnly: dr.Value(localOnly),
          ),
        );
  }

  /// 今天的最后 [count] 条摘要，常驻在 prompt 里。
  Future<String> recentDigest({DateTime? now, int count = 2}) async {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
    final rows = await (db.select(db.episodes)
          ..where((e) => e.at.isBiggerOrEqualValue(start))
          ..orderBy([(e) => dr.OrderingTerm(expression: e.at, mode: dr.OrderingMode.asc)]))
        .get();
    if (rows.isEmpty) return '';
    final pick = rows.length > count ? rows.sublist(rows.length - count) : rows;
    return '今天早些时候的摘要：\n${pick.map((e) => '- ${e.body}').join('\n')}';
  }

  /// 混合召回：向量相似度与关键词取大，再按 相关×重要×新鲜×重复 排序。
  Future<List<Episode>> search({
    List<double>? vector,
    String? keyword,
    int k = 3,
    double threshold = 0.30,
    bool includeLocalOnly = true,
  }) async {
    final query = (keyword ?? '').trim();
    final qv = (vector == null || vector.isEmpty) ? null : quantizeVector(vector);

    // 候选：有关键词就先用 LIKE 圈一批，否则全取（手机上量不会太大）。
    List<Episode> pool;
    if (query.isNotEmpty) {
      pool = await (db.select(db.episodes)
            ..where((e) => e.title.like('%$query%') | e.body.like('%$query%'))
            ..orderBy([(e) => dr.OrderingTerm(expression: e.at, mode: dr.OrderingMode.desc)])
            ..limit(300))
          .get();
      if (pool.length < 5) {
        pool = await (db.select(db.episodes)
              ..orderBy([(e) => dr.OrderingTerm(expression: e.at, mode: dr.OrderingMode.desc)])
              ..limit(2000))
            .get();
      }
    } else {
      pool = await (db.select(db.episodes)
            ..orderBy([(e) => dr.OrderingTerm(expression: e.at, mode: dr.OrderingMode.desc)])
            ..limit(2000))
        .get();
    }
    if (pool.isEmpty) return const [];

    final now = DateTime.now();
    final scored = <MapEntry<Episode, double>>[];
    for (final e in pool) {
      if (!includeLocalOnly && e.localOnly) continue;
      var rel = 0.0;
      if (qv != null && e.vec != null) {
        final sim = cosineInt8(qv, e.vec!);
        if (sim > rel) rel = sim;
      }
      if (query.isNotEmpty && (e.title.contains(query) || e.body.contains(query))) {
        if (rel < 0.9) rel = 0.9;
      }
      final rec = recencyScore(DateTime.fromMillisecondsSinceEpoch(e.at), now);
      final score = hybridScore(
        relevance: rel,
        importance: e.weight,
        recency: rec,
        repetition: 0.5,
      );
      if (score >= threshold) scored.add(MapEntry(e, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(k).map((m) => m.key).toList();
  }

  // ---------------------------------------------------------------- 旧数据

  /// 把 SharedPreferences 里的 24 条事实与 JSON 档案导入数据库，只做一次。
  /// 旧 key 保留不动，作为回滚备份。
  Future<void> _migrateLegacy() async {
    try {
      if (await db.meta('legacy_v1_migrated') == '1') return;
      final sp = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final legacyFacts = sp.getStringList('feiyu.memory.v1') ?? const <String>[];
      for (final f in legacyFacts) {
        final t = f.trim();
        if (t.isEmpty) continue;
        await db.into(db.facts).insert(
              FactsCompanion.insert(
                content: t,
                importance: const dr.Value(3),
                firstSeen: now.millisecondsSinceEpoch,
                lastSeen: now.millisecondsSinceEpoch,
              ),
            );
      }

      final raw = sp.getString('feiyu.archive.v1');
      if (raw != null && raw.isNotEmpty) {
        try {
          for (final item in (jsonDecode(raw) as List)) {
            final m = (item as Map).cast<String, dynamic>();
            final day = (m['day'] ?? '') as String;
            final text = ((m['text'] ?? '') as String).trim();
            if (text.isEmpty) continue;
            final vec = ((m['v'] ?? const <dynamic>[]) as List)
                .map((e) => (e as num).toDouble())
                .toList();
            await addEpisode(
              at: DateTime.tryParse(day) ?? now,
              body: text,
              vector: vec.isEmpty ? null : vec,
              importance: 3,
            );
          }
        } catch (_) {}
      }

      await db.setMeta('legacy_v1_migrated', '1');
    } catch (_) {
      // 迁移失败不该挡住启动，下次再试。
    }
  }

  Future<Map<String, int>> stats() async => {
        'facts': await factCount(),
        'episodes': await episodeCount(),
      };
}
