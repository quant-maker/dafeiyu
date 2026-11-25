import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' as dr show Value;
import 'package:drift/native.dart';
import 'package:feiyu/memory/db.dart';
import 'package:feiyu/memory/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

/// 真库测试：用 drift 的内存库跑一遍存取逻辑。
///
/// Windows 上 pub 里的 sqlite3 包不带二进制，借用系统自带的 winsqlite3.dll。
/// 它没有 FTS5，所以这里顺带验证「没有 FTS 也能用」这条退化路径。
MemoryStore _store() => MemoryStore(MemoryDb(NativeDatabase.memory()));

DateTime _daysAgo(int days, {int hour = 10}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour).subtract(Duration(days: days));
}

void main() {
  setUpAll(() {
    if (Platform.isWindows) {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open(r'C:\Windows\System32\winsqlite3.dll'),
      );
    }
  });

  group('facts', () {
    test('adds, edits, deletes and counts', () async {
      final s = _store();
      addTearDown(s.close);
      await s.addFact('她喜欢在早上写代码', importance: 4);
      expect(await s.factCount(), 1);
      final added = (await s.facts()).single;
      expect(added.content, '她喜欢在早上写代码');
      expect(added.importance, 4);

      await s.updateFactText(added.id, '她喜欢在凌晨写代码');
      expect((await s.facts()).single.content, '她喜欢在凌晨写代码');

      await s.deleteFact(added.id);
      expect(await s.factCount(), 0);
    });

    test('prompt skips local-only facts', () async {
      final s = _store();
      addTearDown(s.close);
      await s.addFact('她的生日是三月十二', importance: 5);
      await s.addFact('她的银行卡密码是六个八', importance: 5, localOnly: true);
      final prompt = await s.factsPrompt();
      expect(prompt, contains('生日'));
      expect(prompt, isNot(contains('密码')));
    });

    test('merge dedupes by substring and bumps hit count', () async {
      final s = _store();
      addTearDown(s.close);
      await s.mergeFacts(<String>['她养了一只叫团子的猫']);
      final before = (await s.facts()).single.hitCount;
      await s.mergeFacts(<String>['她养了一只叫团子的猫']);
      final facts = await s.facts();
      expect(facts.length, 1);
      expect(facts.single.hitCount, before + 1);
    });

    test('merge evicts the least important when over the cap', () async {
      final s = _store();
      addTearDown(s.close);
      for (var i = 0; i < 5; i++) {
        await s.mergeFacts(<String>['琐事第 $i 条'], maxRows: 3);
      }
      final facts = await s.facts();
      expect(facts.length, 3);
    });

    test('keeping one side of a conflict invalidates the rest', () async {
      final s = _store();
      addTearDown(s.close);
      await s.addFact('她在杭州工作', subject: '她', predicate: '所在城市', object: '杭州');
      await s.addFact('她在上海工作', subject: '她', predicate: '所在城市', object: '上海');
      final all = await s.facts();
      expect(all.length, 2);

      await s.keepFact(all.first.id, all.map((f) => f.id));
      final live = await s.facts();
      expect(live.length, 1);
      expect(live.single.importance, greaterThanOrEqualTo(4));
      expect((await s.facts(includeInvalidated: true)).length, 2);
    });
  });

  group('episodes', () {
    test('stores a quantized vector and searches by keyword without FTS', () async {
      final s = _store();
      addTearDown(s.close);
      await s.addEpisode(
        at: _daysAgo(1),
        title: '改星图',
        body: '她把记忆星图的布局从对称换成力导向，说这样看着更像星座。',
        vector: List<double>.generate(1024, (i) => i == 0 ? 1.0 : 0.0),
      );
      await s.addEpisode(at: _daysAgo(2), title: '别的', body: '随便聊了两句天气。');

      final hits = await s.search(keyword: '力导向', k: 3);
      expect(hits, isNotEmpty);
      expect(hits.first.title, '改星图');

      final byVector = await s.search(
        vector: List<double>.generate(1024, (i) => i == 0 ? 1.0 : 0.0),
        k: 3,
        threshold: 0.1,
      );
      expect(byVector, isNotEmpty);
    });

    test('limit keeps the newest episodes, returned oldest-to-newest', () async {
      final s = _store();
      addTearDown(s.close);
      for (var i = 0; i < 3; i++) {
        await s.addEpisode(at: _daysAgo(3 - i), body: '第 $i 天的事');
      }
      final row = await s.episodes(limit: 2);
      expect(row.length, 2);
      expect(row.first.body, '第 1 天的事');
      expect(row.last.body, '第 2 天的事');
    });

    test('local-only episodes never reach the timeline prompt', () async {
      final s = _store();
      addTearDown(s.close);
      await s.addEpisode(body: '今天去医院复查，医生说是好消息。', localOnly: true);
      await s.addEpisode(body: '今天把星图的时间滑杆做好了。');
      final prompt = await s.timelinePrompt();
      expect(prompt, contains('时间滑杆'));
      expect(prompt, isNot(contains('医院')));
    });
  });

  group('stars', () {
    test('alias keeps one star per person', () async {
      final s = _store();
      addTearDown(s.close);
      final a = await s.upsertEntity(name: '王总', kind: 'person', importance: 3);
      final b = await s.upsertEntity(name: '王总', kind: 'person', importance: 4);
      expect(b, a);
      expect(await s.entityCount(), 1);
      expect((await s.entityById(a))!.importance, 4);
    });

    test('merging reroutes edges and drops the duplicate', () async {
      final s = _store();
      addTearDown(s.close);
      final a = await s.upsertEntity(name: '甲', kind: 'person');
      final b = await s.upsertEntity(name: '乙', kind: 'person');
      final c = await s.upsertEntity(name: '丙', kind: 'person');
      await s.upsertEdge(src: a, dst: c, kind: 'mentions');
      await s.upsertEdge(src: b, dst: c, kind: 'mentions');

      await s.mergeEntities(a, b);
      expect(await s.entityCount(), 2);
      final live = await s.edges();
      expect(live.where((e) => e.src == a && e.dst == c).length, 1);
      expect(live.any((e) => e.src == b || e.dst == b), isFalse);
    });

    test('forgetting a star removes it and silences its edges', () async {
      final s = _store();
      addTearDown(s.close);
      final a = await s.upsertEntity(name: '甲', kind: 'person');
      final b = await s.upsertEntity(name: '乙', kind: 'person');
      await s.upsertEdge(src: a, dst: b, kind: 'mentions');
      await s.forgetEntity(a);
      expect(await s.entityCount(), 1);
      expect(await s.edges(), isEmpty);
      expect((await s.edges(activeOnly: false)).length, 1);
    });

    test('keeping a fading star lifts it back to full strength', () async {
      final s = _store();
      addTearDown(s.close);
      final id = await s.upsertEntity(name: '老同学', kind: 'person');
      await s.keepEntity(id);
      final e = await s.entityById(id);
      expect(e!.strength, 1.0);
      expect(e.lastTouched, greaterThan(0));
    });
  });

  group('nightly sweep', () {
    test('decays old stars and invalidates dead edges', () async {
      final s = _store();
      addTearDown(s.close);
      final a = await s.upsertEntity(name: '甲', kind: 'person', at: _daysAgo(90));
      final b = await s.upsertEntity(name: '乙', kind: 'person', at: _daysAgo(90));
      await s.upsertEdge(src: a, dst: b, kind: 'mentions', at: _daysAgo(200));
      await (s.db.update(s.db.entities)..where((t) => t.id.equals(a))).write(
        EntitiesCompanion(
          strength: const dr.Value(0.5),
          lastTouched: dr.Value(_daysAgo(60).millisecondsSinceEpoch),
        ),
      );
      // 一条又淡又久没被碰到的边应该被扫掉。
      await (s.db.update(s.db.edges)..where((t) => t.src.equals(a))).write(
        EdgesCompanion(weight: const dr.Value(0.2)),
      );

      await s.nightlySweep();
      final star = await s.entityById(a);
      expect(star!.strength, lessThan(0.5));
      expect(await s.edges(), isEmpty);
    });
  });

  group('health and housekeeping', () {
    test('counts what is in there', () async {
      final s = _store();
      addTearDown(s.close);
      await s.addFact('一条事实');
      await s.addEpisode(at: _daysAgo(5), body: '五天前的事');
      await s.addEpisode(body: '今天的事');
      await s.addEpisode(body: '今天更晚的事');
      await s.upsertEntity(name: '甲', kind: 'person');

      final h = await s.health();
      expect(h.episodes, 3);
      expect(h.facts, 1);
      expect(h.entities, 1);
      expect(h.spanDays, 6);
      expect(h.fullness, greaterThan(0));
    });

    test('export has every section and wipe empties them', () async {
      final s = _store();
      addTearDown(s.close);
      await s.addFact('一条事实');
      await s.addEpisode(body: '一段情景');
      await s.upsertEntity(name: '甲', kind: 'person');

      final snap = await s.exportSnapshot();
      for (final key in <String>['facts', 'episodes', 'entities', 'edges', 'blocks']) {
        expect(snap.containsKey(key), isTrue, reason: 'missing $key');
      }
      expect((snap['facts'] as List<dynamic>).length, 1);

      await s.wipe();
      final h = await s.health();
      expect(h.facts, 0);
      expect(h.episodes, 0);
      expect(h.entities, 0);
    });
  });
}
