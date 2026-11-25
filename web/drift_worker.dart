// drift 的 web worker 入口：把 sqlite 放到独立线程里跑，避免卡 UI。
//
// 编译方式（在仓库根目录执行）：
//   dart compile js -o web/drift_worker.js web/drift_worker.dart
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
