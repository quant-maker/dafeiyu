import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'db.dart';

/// 手机/桌面：真正的 SQLite 文件，后台 isolate 里跑，不卡 UI。
Future<MemoryDb> openMemoryDb() async {
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}feiyu_memory.sqlite');
  return MemoryDb(NativeDatabase.createInBackground(file));
}
