import 'dart:convert';

import 'package:drift/drift.dart' as dr;
import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';
import 'db_conn.dart';
import 'scoring.dart';
import 'timeline.dart';

export 'scoring.dart' show quantizeVector, cosineInt8, cosine;

/// 某天零点的毫秒时间戳。
int dayStartMs(DateTime t) => DateTime(t.year, t.month, t.day).millisecondsSinceEpoch;

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

  /// 关键词候选：够长就走 FTS5 trigram（快、能命中子串），太短退化成 LIKE。
  Future<List<Episode>> _keywordCandidates(String query, {int limit = 300}) async {
    final q = query.trim();
    if (q.isEmpty) return const <Episode>[];
    if (q.length >= 3) {
      try {
        final rows = await db.customSelect(
          'SELECT rowid AS id FROM episode_fts WHERE episode_fts MATCH ? LIMIT ?',
          variables: <dr.Variable>[dr.Variable.withString('"$q"'), dr.Variable.withInt(limit)],
        ).get();
        final ids = rows.map((r) => r.read<int>('id')).toList();
        if (ids.isNotEmpty) {
          final list = await (db.select(db.episodes)..where((e) => e.id.isIn(ids))).get();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {
        // FTS 不可用（老库/特殊构建）就掉回 LIKE。
      }
    }
    return (db.select(db.episodes)
          ..where((e) => e.title.like('%$q%') | e.body.like('%$q%'))
          ..orderBy([(e) => dr.OrderingTerm(expression: e.at, mode: dr.OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  /// 沿实体边做一跳扩展：从种子情景出发找到它们提到的人/事，
  /// 再收集那些实体连着的其他情景，给一个递减的加成。
  Future<Map<int, double>> _graphBoost(List<int> seedPaths) async {
    if (seedPaths.isEmpty) return const <int, double>{};
    try {
      final seedEdges = await (db.select(db.edges)
            ..where((e) => e.evidenceEpisode.isIn(seedPaths) & e.invalidatedAt.isNull())
            ..limit(400))
          .get();
      final seeds = <int>{};
      for (final e in seedEdges) {
        seeds.add(e.src);
        seeds.add(e.dst);
      }
      if (seeds.isEmpty) return const <int, double>{};
      final near = await (db.select(db.edges)
            ..where((e) => (e.src.isIn(seeds) | e.dst.isIn(seeds)) & e.invalidatedAt.isNull())
            ..limit(800))
          .get();
      final boost = <int, double>{};
      for (final e in near) {
        final ep = e.evidenceEpisode;
        if (ep == null || seedPaths.contains(ep)) continue;
        final w = 0.18 * (e.weight.clamp(0.2, 5.0) / 5.0);
        if (w > (boost[ep] ?? 0)) boost[ep] = w;
      }
      return boost;
    } catch (_) {
      return const <int, double>{};
    }
  }

  /// 混合召回：FTS5 关键词 + int8 向量 + 实体图一跳扩展，再按 相关×重要×新鲜×重复 排序。
  Future<List<Episode>> search({
    List<double>? vector,
    String? keyword,
    int k = 3,
    double threshold = 0.30,
    bool includeLocalOnly = true,
    bool expand = true,
  }) async {
    final query = (keyword ?? '').trim();
    final qv = (vector == null || vector.isEmpty) ? null : quantizeVector(vector);

    // 候选：有关键词就先用 FTS/LIKE 圈一批，否则全取（手机上量不会太大）。
    List<Episode> pool;
    if (query.isNotEmpty) {
      pool = await _keywordCandidates(query);
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

    if (!expand || scored.isEmpty) {
      return scored.take(k).map((m) => m.key).toList();
    }

    // 图扩展：种子用当前前几名，接回来的情景按加成重新计分。
    final seeds = scored.take(k).map((m) => m.key.id).toList();
    final boost = await _graphBoost(seeds);
    if (boost.isEmpty) return scored.take(k).map((m) => m.key).toList();

    final seen = scored.map((m) => m.key.id).toSet();
    final missing = boost.keys.where((id) => !seen.contains(id)).toList();
    final extra = <MapEntry<Episode, double>>[];
    if (missing.isNotEmpty) {
      final rows = await (db.select(db.episodes)..where((e) => e.id.isIn(missing))).get();
      for (final e in rows) {
        if (!includeLocalOnly && e.localOnly) continue;
        final rec = recencyScore(DateTime.fromMillisecondsSinceEpoch(e.at), now);
        final base = hybridScore(
          relevance: boost[e.id] ?? 0.18,
          importance: e.weight,
          recency: rec,
          repetition: 0.5,
        );
        extra.add(MapEntry(e, base));
      }
    }
    final merged = <MapEntry<Episode, double>>[...scored, ...extra]
      ..sort((a, b) => b.value.compareTo(a.value));
    return merged.take(k).map((m) => m.key).toList();
  }

  // ---------------------------------------------------------------- 分层块

  /// 按时间升序取情景，供日结/层叠使用。
  Future<List<Episode>> episodes({int limit = 5000, int? fromMs, int? toMs}) {
    final q = db.select(db.episodes);
    if (fromMs != null) q.where((e) => e.at.isBiggerOrEqualValue(fromMs));
    if (toMs != null) q.where((e) => e.at.isSmallerThanValue(toMs));
    q.orderBy([(e) => dr.OrderingTerm(expression: e.at, mode: dr.OrderingMode.asc)]);
    q.limit(limit);
    return q.get();
  }

  /// 同一天里是否已经有几乎一样的情景（避免重复抽取）。
  Future<bool> hasSimilarEpisode(String body, {required int fromMs, required int toMs}) async {
    final t = body.trim();
    if (t.isEmpty) return false;
    final rows = await episodes(fromMs: fromMs, toMs: toMs, limit: 500);
    for (final e in rows) {
      if (e.body == t) return true;
      final a = e.body.length < t.length ? e.body : t;
      final b = e.body.length < t.length ? t : e.body;
      if (a.length >= 12 && b.contains(a)) return true;
    }
    return false;
  }

  Future<List<Block>> blocksOfTier(int tier, {int limit = 500}) {
    final q = db.select(db.blocks)
      ..where((b) => b.tier.equals(tier))
      ..orderBy([(b) => dr.OrderingTerm(expression: b.createdAt, mode: dr.OrderingMode.asc)])
      ..limit(limit);
    return q.get();
  }

  Future<Set<String>> blockTopics(int tier) async {
    final rows = await (db.selectOnly(db.blocks)
          ..addColumns([db.blocks.topic])
          ..where(db.blocks.tier.equals(tier)))
        .get();
    return rows.map((r) => r.read(db.blocks.topic)).whereType<String>().toSet();
  }

  Future<int> putBlock({
    required int tier,
    required String topic,
    required String summary,
    required List<int> directIds,
    required List<int> effectiveIds,
    int? spanFrom,
    int? spanTo,
    DateTime? createdAt,
  }) {
    return db.into(db.blocks).insert(
          BlocksCompanion.insert(
            tier: tier,
            topic: dr.Value(topic),
            summary: summary,
            directIds: jsonEncode(directIds),
            effectiveIds: jsonEncode(effectiveIds),
            createdAt: (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
            spanFrom: dr.Value(spanFrom),
            spanTo: dr.Value(spanTo),
          ),
        );
  }

  Future<void> deleteBlock(int id) async {
    await (db.delete(db.blocks)..where((b) => b.id.equals(id))).go();
  }

  Future<int> blockCount({int? tier}) async {
    final c = db.blocks.id.count();
    final q = db.selectOnly(db.blocks)..addColumns(<dr.Expression<Object>>[c]);
    if (tier != null) q.where(db.blocks.tier.equals(tier));
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  /// 常驻 prompt 的时间线：最近两篇日结 + 今天的情景。
  Future<String> timelinePrompt({int maxChars = 900}) async {
    final now = DateTime.now();
    final cards = await blocksOfTier(1, limit: 200);
    final recent = cards.where((c) => (c.topic ?? '').startsWith('day:')).toList();
    final tail = recent.length > 2 ? recent.sublist(recent.length - 2) : recent;
    final buf = StringBuffer();
    for (final c in tail) {
      final key = (c.topic ?? '').replaceFirst('day:', '');
      final line = '【${dayLabel(key)}】${c.summary}';
      if (buf.length + line.length > maxChars) break;
      buf.writeln(line);
    }
    final todays = await episodes(fromMs: dayStartMs(now), limit: 4);
    if (todays.isNotEmpty) {
      buf.writeln('今天我记下的：');
      for (final e in todays) {
        final line = '- ${e.body}';
        if (buf.length + line.length > maxChars) break;
        buf.writeln(line);
      }
    }
    if (buf.isEmpty) return '';
    return '我自己的记忆（自然使用，别照念）：\n${buf.toString().trim()}';
  }

  // ---------------------------------------------------------------- 星与边

  Future<List<Entity>> entities({int limit = 800}) {
    final q = db.select(db.entities)
      ..orderBy([(e) => dr.OrderingTerm(expression: e.lastTouched, mode: dr.OrderingMode.desc)])
      ..limit(limit);
    return q.get();
  }

  Future<Entity?> entityById(int id) =>
      (db.select(db.entities)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// 建星或强化已有的星。返回实体 id。
  Future<int> upsertEntity({
    required String name,
    String kind = 'thing',
    int importance = 3,
    DateTime? at,
    String? summary,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return 0;
    final when = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final hit = await (db.select(db.entities)
          ..where((e) => e.name.equals(n))
          ..limit(1))
        .getSingleOrNull();
    if (hit == null) {
      return db.into(db.entities).insert(
            EntitiesCompanion.insert(
              name: n,
              kind: dr.Value(kind),
              importance: dr.Value(importance),
              firstSeen: when,
              lastTouched: when,
              summary: dr.Value(summary),
            ),
          );
    }
    await (db.update(db.entities)..where((e) => e.id.equals(hit.id))).write(
      EntitiesCompanion(
        kind: dr.Value(hit.kind == 'thing' ? kind : hit.kind),
        importance: dr.Value(importance > hit.importance ? importance : hit.importance),
        lastTouched: dr.Value(when),
        strength: dr.Value(reinforce(hit.strength)),
        summary: dr.Value(summary ?? hit.summary),
      ),
    );
    return hit.id;
  }

  /// 手动点亮一颗星（被聊到、被点开）。
  Future<void> touchEntity(int id, {DateTime? at}) async {
    final e = await entityById(id);
    if (e == null) return;
    await (db.update(db.entities)..where((t) => t.id.equals(id))).write(
      EntitiesCompanion(
        strength: dr.Value(reinforce(e.strength)),
        lastTouched: dr.Value((at ?? DateTime.now()).millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<Edge>> edges({bool activeOnly = true, int limit = 3000}) {
    final q = db.select(db.edges);
    if (activeOnly) q.where((e) => e.invalidatedAt.isNull());
    q.orderBy([(e) => dr.OrderingTerm(expression: e.lastSeen, mode: dr.OrderingMode.desc)]);
    q.limit(limit);
    return q.get();
  }

  /// 连线。同一对星、同一种关系只留一条，重复出现就把权重压上去。
  Future<int> upsertEdge({
    required int src,
    required int dst,
    String kind = 'mentions',
    String? label,
    DateTime? at,
    int? evidenceEpisode,
  }) async {
    if (src == 0 || dst == 0 || src == dst) return 0;
    final when = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final hit = await (db.select(db.edges)
          ..where((e) => e.src.equals(src) & e.dst.equals(dst) & e.kind.equals(kind) & e.invalidatedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (hit == null) {
      return db.into(db.edges).insert(
            EdgesCompanion.insert(
              src: src,
              dst: dst,
              kind: dr.Value(kind),
              label: dr.Value(label),
              firstSeen: when,
              lastSeen: when,
              evidenceEpisode: dr.Value(evidenceEpisode),
            ),
          );
    }
    await (db.update(db.edges)..where((e) => e.id.equals(hit.id))).write(
      EdgesCompanion(
        lastSeen: dr.Value(when),
        weight: dr.Value((hit.weight + 0.2).clamp(0.2, 5.0)),
        label: dr.Value(label ?? hit.label),
        evidenceEpisode: dr.Value(evidenceEpisode ?? hit.evidenceEpisode),
      ),
    );
    return hit.id;
  }

  /// 关系不成立了：不删，只打上失效时间（双时间，能回看）。
  Future<void> invalidateEdge(int id, {DateTime? at}) async {
    await (db.update(db.edges)..where((e) => e.id.equals(id))).write(
      EdgesCompanion(invalidatedAt: dr.Value((at ?? DateTime.now()).millisecondsSinceEpoch)),
    );
  }

  Future<void> invalidateFact(int id, {DateTime? at}) async {
    await (db.update(db.facts)..where((f) => f.id.equals(id))).write(
      FactsCompanion(invalidatedAt: dr.Value((at ?? DateTime.now()).millisecondsSinceEpoch)),
    );
  }

  Future<int> entityCount() async {
    final c = db.entities.id.count();
    final row = await (db.selectOnly(db.entities)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<int> edgeCount() async {
    final c = db.edges.id.count();
    final row = await (db.selectOnly(db.edges)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
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
        'blocks': await blockCount(),
        'entities': await entityCount(),
        'edges': await edgeCount(),
      };

  /// 主动开口的素材：挑一颗久没碰过、但有细节的星，交给她决定提不提。
  Future<String> hookLine({int staleDays = 21, DateTime? now}) async {
    try {
      final at = now ?? DateTime.now();
      final cutoff = at.subtract(Duration(days: staleDays)).millisecondsSinceEpoch;
      final rows = await entities(limit: 800);
      if (rows.isEmpty) return '';
      rows.sort((a, b) => a.lastTouched.compareTo(b.lastTouched));
      for (final e in rows) {
        if (e.lastTouched >= cutoff) break;
        final detail = (e.summary ?? '').trim();
        if (detail.length < 4) continue;
        final days = at
            .difference(DateTime.fromMillisecondsSinceEpoch(e.lastTouched))
            .inDays
            .clamp(1, 999);
        final short = detail.length > 80 ? '${detail.substring(0, 80)}…' : detail;
        return '你已经 $days 天没提过「${e.name}」了，上次说到：$short';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// 记性体检：够不够厚、有没有打架的事实、哪些星快灭了。
  Future<MemoryHealth> health({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final facts = await this.facts(includeInvalidated: false);
    final eps = await episodes(limit: 2000);
    final stars = await entities(limit: 800);

    // 同一主谓却有不同宾语 → 说法打架。
    final groups = <String, List<Fact>>{};
    for (final f in facts) {
      final subj = (f.subject ?? '').trim();
      final pred = (f.predicate ?? '').trim();
      final obj = (f.object ?? '').trim();
      if (subj.isEmpty || pred.isEmpty || obj.isEmpty) continue;
      groups.putIfAbsent('$subj|$pred', () => <Fact>[]).add(f);
    }
    final conflicts = <String>[];
    for (final entry in groups.entries) {
      final objs = entry.value.map((f) => (f.object ?? '').trim()).toSet();
      if (objs.length > 1) {
        final label = entry.key.replaceFirst('|', ' 的 ');
        conflicts.add('$label：${objs.join(' / ')}');
        if (conflicts.length >= 5) break;
      }
    }

    // 超过 30 天没被碰过、而且本来就淡的星。
    final staleCutoff = at.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final stale = <String>[];
    for (final s in stars) {
      if (s.lastTouched < staleCutoff && s.strength < 1.0) {
        stale.add(s.name);
        if (stale.length >= 5) break;
      }
    }

    var localOnly = 0;
    for (final e in eps) {
      if (e.localOnly) localOnly++;
    }

    return MemoryHealth(
      episodes: eps.length,
      facts: facts.length,
      entities: stars.length,
      edges: await edgeCount(),
      dayCards: await blockCount(tier: 1),
      weekCards: await blockCount(tier: 2),
      monthCards: await blockCount(tier: 3),
      localOnly: localOnly,
      oldestAt: eps.isEmpty ? 0 : eps.first.at,
      newestAt: eps.isEmpty ? 0 : eps.last.at,
      conflicts: conflicts,
      staleStars: stale,
      generatedAt: at.millisecondsSinceEpoch,
    );
  }
}

/// 体检结果，纯数据，方便测试和界面直接用。
class MemoryHealth {
  final int episodes;
  final int facts;
  final int entities;
  final int edges;
  final int dayCards;
  final int weekCards;
  final int monthCards;
  final int localOnly;
  final int oldestAt;
  final int newestAt;
  final List<String> conflicts;
  final List<String> staleStars;
  final int generatedAt;

  const MemoryHealth({
    required this.episodes,
    required this.facts,
    required this.entities,
    required this.edges,
    required this.dayCards,
    required this.weekCards,
    required this.monthCards,
    required this.localOnly,
    required this.oldestAt,
    required this.newestAt,
    required this.conflicts,
    required this.staleStars,
    required this.generatedAt,
  });

  /// 0..1：情景、事实、星三样都有一点才算「记得住」。
  double get fullness {
    double part(int n, int target) => (n / target).clamp(0.0, 1.0);
    return (part(episodes, 30) * 0.5 + part(facts, 15) * 0.3 + part(entities, 20) * 0.2);
  }

  int get spanDays {
    if (oldestAt <= 0 || newestAt <= oldestAt) return 0;
    return DateTime.fromMillisecondsSinceEpoch(newestAt)
            .difference(DateTime.fromMillisecondsSinceEpoch(oldestAt))
            .inDays +
        1;
  }
}
