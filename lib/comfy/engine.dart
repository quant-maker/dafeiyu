import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// A pair of values the drawing page needs from Settings.
class ComfyConfig {
  const ComfyConfig({required this.baseUrl, required this.workflowJson});

  final String baseUrl;
  final String workflowJson;
}

/// The engine status reported by the local web server.
class ComfyEngineStatus {
  const ComfyEngineStatus({
    required this.supported,
    required this.running,
    required this.startable,
    this.port = 8188,
    this.dir = '',
  });

  const ComfyEngineStatus.unsupported()
      : supported = false,
        running = false,
        startable = false,
        port = 0,
        dir = '';

  final bool supported;
  final bool running;
  final bool startable;
  final int port;
  final String dir;
}

/// Start/stop the ComfyUI engine on the desktop.
///
/// A browser can't spawn processes, so on web this talks to the local dev
/// server's `/comfyctl/*` endpoints (server.mjs). On Android there is nothing
/// to talk to: [supported] is false and the UI hides the action.
class ComfyEngine {
  static bool get supported => kIsWeb;

  static String get _base => '${Uri.base.origin}/comfyctl';

  static Future<ComfyEngineStatus> health() async {
    if (!supported) return const ComfyEngineStatus.unsupported();
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const ComfyEngineStatus.unsupported();
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return ComfyEngineStatus(
        supported: true,
        running: j['running'] == true,
        startable: j['startable'] == true,
        port: (j['port'] as num?)?.toInt() ?? 8188,
        dir: (j['dir'] ?? '').toString(),
      );
    } catch (_) {
      return const ComfyEngineStatus.unsupported();
    }
  }

  /// Null means the launch was accepted; otherwise an error to show.
  static Future<String?> start() async {
    if (!supported) return '只能在 Web 版（本机 server.mjs）里启动';
    try {
      final res = await http
          .post(Uri.parse('$_base/start'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 || res.statusCode == 202) return null;
      return _detail(res) ?? 'HTTP ${res.statusCode}';
    } catch (e) {
      return '启动失败：$e';
    }
  }

  static Future<String?> stop() async {
    if (!supported) return '只能在 Web 版（本机 server.mjs）里停止';
    try {
      final res = await http
          .post(Uri.parse('$_base/stop'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      return _detail(res) ?? 'HTTP ${res.statusCode}';
    } catch (e) {
      return '停止失败：$e';
    }
  }

  static String? _detail(http.Response res) {
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final err = j['error'];
      return err?.toString();
    } catch (_) {
      return null;
    }
  }
}
