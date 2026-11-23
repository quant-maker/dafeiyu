import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One highlight she chose to keep: the memorable part of a day, written in
/// her own voice. Browsing the feed is like scrolling her Moments.
class Footprint {
  final String id;
  final DateTime at;
  final String title;
  final String body;
  final String mood;

  Footprint({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.mood = '🐟',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'title': title,
        'body': body,
        'mood': mood,
      };

  static Footprint fromJson(Map<String, dynamic> j) => Footprint(
        id: (j['id'] ?? '') as String,
        at: DateTime.tryParse((j['at'] ?? '') as String) ?? DateTime.now(),
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        mood: (j['mood'] ?? '🐟') as String,
      );

  /// 今天 / 昨天 / 11月9日
  String get dayLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(at.year, at.month, at.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${at.month}月${at.day}日';
  }

  String get timeLabel =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

/// Builds the footprint that records a share she just made.
///
/// [source] is the feed she pulled it from (`HN` / `V2EX` / `GitHub`), or
/// `网页` when it did not come from the inbox. The body keeps the first 160
/// characters of what she said so 足迹 shows the find, not the whole message.
Footprint footprintFromShare({
  required String source,
  required String text,
  required DateTime at,
}) {
  final title = source.trim().isEmpty ? '网页' : source.trim();
  final trimmed = text.trim();
  final body = trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
  return Footprint(
    id: at.microsecondsSinceEpoch.toString(),
    at: at,
    title: title,
    body: body,
    mood: '🌐',
  );
}

class FootprintStore {
  static const _k = 'feiyu.footprints.v1';
  static const maxEntries = 500;

  static Future<List<Footprint>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Footprint.fromJson((e as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Footprint> items) async {
    final sp = await SharedPreferences.getInstance();
    final keep = items.length > maxEntries ? items.sublist(0, maxEntries) : items;
    await sp.setString(_k, jsonEncode(keep.map((e) => e.toJson()).toList()));
  }
}
