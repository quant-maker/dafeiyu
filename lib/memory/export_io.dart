import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 把导出的 JSON 写到应用文档目录，返回文件路径。
///
/// 手机上用户看不到「下载」目录，所以落在 App 私有目录里，并在设置页显示路径，
/// 方便他拷出去。失败返回 null（调用方自己决定怎么提示）。
Future<String?> saveMemoryExport(String json, {String? name}) async {
  try {
    final Directory dir = await getApplicationDocumentsDirectory();
    final DateTime now = DateTime.now();
    final String base = name ?? _stamp(now);
    final File file = File('${dir.path}/$base.json');
    await file.writeAsString(json, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'feiyu-memory-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}';
}
