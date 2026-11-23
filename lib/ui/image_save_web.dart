// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of [bytes] as a PNG and returns its filename.
Future<String?> saveImageBytes(Uint8List bytes, {String prefix = 'feiyu'}) async {
  final int ts = DateTime.now().millisecondsSinceEpoch;
  final String name = '${prefix}_$ts.png';
  final html.Blob blob = html.Blob(<Object>[bytes], 'image/png');
  final String url = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: url)..download = name;
  anchor.click();
  html.Url.revokeObjectUrl(url);
  return name;
}
