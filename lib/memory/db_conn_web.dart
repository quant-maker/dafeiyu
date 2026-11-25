import 'package:drift/wasm.dart';

import 'db.dart';

/// 浏览器：sqlite3 编译成 wasm，数据库存在 Origin Private File System /
/// IndexedDB 里。`sqlite3.wasm` 与 `drift_worker.js` 由
/// `tools/fetch-web-assets.ps1` 放进 web/（换了 drift 版本要重跑一次）。
Future<MemoryDb> openMemoryDb() async {
  final result = await WasmDatabase.open(
    databaseName: 'feiyu_memory',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  return MemoryDb(result.resolvedExecutor);
}
