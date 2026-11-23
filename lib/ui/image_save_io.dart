import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes [bytes] as a PNG into the app documents directory and returns its path.
Future<String?> saveImageBytes(Uint8List bytes, {String prefix = 'feiyu'}) async {
  final Directory dir = await getApplicationDocumentsDirectory();
  final int ts = DateTime.now().millisecondsSinceEpoch;
  final File file = File('${dir.path}/${prefix}_$ts.png');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
