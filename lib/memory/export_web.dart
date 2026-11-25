// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// 浏览器里直接触发下载，返回文件名。
Future<String?> saveMemoryExport(String json, {String? name}) async {
  try {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final String fallback =
        'feiyu-memory-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
    final String base = name ?? fallback;
    final String filename = '$base.json';
    final html.Blob blob = html.Blob(<Object>[json], 'application/json');
    final String url = html.Url.createObjectUrlFromBlob(blob);
    final html.AnchorElement anchor = html.AnchorElement(href: url)..download = filename;
    anchor.click();
    html.Url.revokeObjectUrl(url);
    return filename;
  } catch (_) {
    return null;
  }
}
