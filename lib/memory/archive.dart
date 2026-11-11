import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// One compressed slice of the past: a paragraph plus its embedding.
class ArchiveEntry {
  final String day;
  final String text;
  final List<double> vector;

  ArchiveEntry({required this.day, required this.text, required this.vector});

  Map<String, dynamic> toJson() => {
        'day': day,
        'text': text,
        // Vectors are kept at reduced precision: recall does not need more.
        'v': vector.map((e) => double.parse(e.toStringAsFixed(4))).toList(),
      };

  static ArchiveEntry fromJson(Map<String, dynamic> j) => ArchiveEntry(
        day: (j['day'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        vector: ((j['v'] ?? const <dynamic>[]) as List).map((e) => (e as num).toDouble()).toList(),
      );
}

/// Layered memory: recent turns stay in the prompt, older material is
/// compressed into summaries and retrieved by similarity on demand.
class Archive {
  static const _k = 'feiyu.archive.v1';
  static const _maxEntries = 2000;

  final List<ArchiveEntry> entries = [];

  static Future<Archive> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    final a = Archive();
    if (raw == null) return a;
    try {
      for (final item in (jsonDecode(raw) as List)) {
        a.entries.add(ArchiveEntry.fromJson((item as Map).cast<String, dynamic>()));
      }
    } catch (_) {}
    return a;
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    while (entries.length > _maxEntries) {
      entries.removeAt(0);
    }
    await sp.setString(_k, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> add(ArchiveEntry entry) async {
    entries.add(entry);
    await save();
  }

  /// Newest-first similarity search; falls back to keyword matching when the
  /// query could not be embedded.
  List<ArchiveEntry> search(List<double>? queryVector, String keyword, {int k = 3}) {
    final scored = <MapEntry<ArchiveEntry, double>>[];
    final kw = keyword.trim().toLowerCase();
    for (final e in entries) {
      double score;
      if (queryVector != null && queryVector.length == e.vector.length) {
        score = _cosine(queryVector, e.vector);
      } else if (kw.isNotEmpty) {
        score = e.text.toLowerCase().contains(kw) ? 1 : 0;
      } else {
        score = 0;
      }
      if (score > 0.3) scored.add(MapEntry(e, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(k).map((m) => m.key).toList();
  }

  static double _cosine(List<double> a, List<double> b) {
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }
}

/// Thin wrapper over the gateway's embedding endpoint.
class Embedder {
  final String baseUrl;
  final String apiKey;
  final String model;

  Embedder({required this.baseUrl, required this.apiKey, required this.model});

  Future<List<double>?> embed(String text) async {
    try {
      final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final res = await http
          .post(
            Uri.parse('$base/embeddings'),
            headers: {'content-type': 'application/json', 'authorization': 'Bearer $apiKey'},
            body: jsonEncode({'model': model, 'input': text}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = (j['data'] as List?)?.first as Map?;
      final vec = data?['embedding'] as List?;
      if (vec == null) return null;
      return vec.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }
}
