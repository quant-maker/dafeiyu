import 'package:drift/drift.dart';

part 'db.g.dart';

/// 一次值得记住的交流。
class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get at => integer()();
  TextColumn get session => text().nullable()();
  TextColumn get place => text().nullable()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get rawRef => text().nullable()();
  RealColumn get weight => real().withDefault(const Constant(1))();
  BlobColumn get vec => blob().nullable()();
  IntColumn get vecDims => integer().withDefault(const Constant(0))();
  BoolColumn get localOnly => boolean().withDefault(const Constant(false))();
}

/// 可校验的事实，取代过去 24 条便利贴。
class Facts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 人话版本。列名不能叫 text——那会和 drift 的 `Table.text()` 撞名。
  TextColumn get content => text()();

  /// 三元组在结构化抽取后才填，旧数据只有 [content]。
  TextColumn get subject => text().nullable()();
  TextColumn get predicate => text().nullable()();
  TextColumn get object => text().nullable()();

  RealColumn get confidence => real().withDefault(const Constant(0.7))();
  IntColumn get importance => integer().withDefault(const Constant(3))();
  IntColumn get firstSeen => integer()();
  IntColumn get lastSeen => integer()();
  IntColumn get hitCount => integer().withDefault(const Constant(1))();
  IntColumn get evidenceEpisode => integer().nullable()();
  IntColumn get invalidatedAt => integer().nullable()();
  BoolColumn get localOnly => boolean().withDefault(const Constant(false))();
}

/// 星图上的星。
class Entities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get alias => text().nullable()();

  /// person | project | place | topic | promise | thing
  TextColumn get kind => text().withDefault(const Constant('thing'))();
  IntColumn get importance => integer().withDefault(const Constant(3))();
  RealColumn get strength => real().withDefault(const Constant(1))();
  IntColumn get firstSeen => integer()();
  IntColumn get lastTouched => integer()();
  TextColumn get summary => text().nullable()();
  RealColumn get x => real().nullable()();
  RealColumn get y => real().nullable()();
}

/// 星之间的边。
class Edges extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get src => integer()();
  IntColumn get dst => integer()();

  /// semantic | temporal | causal | entity | mentions
  TextColumn get kind => text().withDefault(const Constant('semantic'))();
  TextColumn get label => text().nullable()();
  RealColumn get weight => real().withDefault(const Constant(1))();
  IntColumn get firstSeen => integer()();
  IntColumn get lastSeen => integer()();
  IntColumn get evidenceEpisode => integer().nullable()();
  IntColumn get invalidatedAt => integer().nullable()();
}

/// 分层块：tier 1 = day，2 = week，3 = month。只折上一层，谱系永活。
class Blocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tier => integer()();
  TextColumn get topic => text().nullable()();
  TextColumn get summary => text()();

  /// JSON 数组：上一层 block id 或 episode id。
  TextColumn get directIds => text()();

  /// JSON 数组：覆盖到的全部 episode id。
  TextColumn get effectiveIds => text()();
  IntColumn get createdAt => integer()();
  IntColumn get spanFrom => integer().nullable()();
  IntColumn get spanTo => integer().nullable()();
}

class MetaRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Episodes, Facts, Entities, Edges, Blocks, MetaRows])
class MemoryDb extends _$MemoryDb {
  MemoryDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_episode_at ON episodes(at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_fact_seen ON facts(last_seen)',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// 全文索引。trigram 对中文友好（unicode61 会把整句当一个词）。
  /// 老版本 SQLite 没有 trigram 时退化为普通 FTS5，再不行就放弃并留下标记。
  Future<void> _createFts() async {
    try {
      await customStatement(
        "CREATE VIRTUAL TABLE IF NOT EXISTS episode_fts USING fts5("
        "title, body, content='episodes', content_rowid='id', tokenize='trigram')",
      );
      await _createFtsTriggers();
    } catch (_) {
      try {
        await customStatement(
          "CREATE VIRTUAL TABLE IF NOT EXISTS episode_fts USING fts5("
          "title, body, content='episodes', content_rowid='id')",
        );
        await _createFtsTriggers();
      } catch (_) {
        // 没有 FTS 也能用：检索退化为 LIKE + 向量。
      }
    }
  }

  Future<void> _createFtsTriggers() async {
    for (final sql in const [
      "CREATE TRIGGER IF NOT EXISTS episode_ai AFTER INSERT ON episodes BEGIN "
          "INSERT INTO episode_fts(rowid, title, body) VALUES (new.id, new.title, new.body); END",
      "CREATE TRIGGER IF NOT EXISTS episode_ad AFTER DELETE ON episodes BEGIN "
          "INSERT INTO episode_fts(episode_fts, rowid, title, body) VALUES('delete', old.id, old.title, old.body); END",
      "CREATE TRIGGER IF NOT EXISTS episode_au AFTER UPDATE ON episodes BEGIN "
          "INSERT INTO episode_fts(episode_fts, rowid, title, body) VALUES('delete', old.id, old.title, old.body); "
          "INSERT INTO episode_fts(rowid, title, body) VALUES (new.id, new.title, new.body); END",
    ]) {
      try {
        await customStatement(sql);
      } catch (_) {}
    }
  }

  Future<String?> meta(String key) async {
    final row = await (select(metaRows)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) async {
    await into(metaRows).insert(
      MetaRowsCompanion.insert(key: key, value: value),
      mode: InsertMode.insertOrReplace,
    );
  }
}
