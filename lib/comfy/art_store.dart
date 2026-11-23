import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// One generated picture she made, kept only on this device.
///
/// The pixels live as a base64 string ([b64]) so the whole gallery can be
/// stored as a single JSON string under one preference key.
class ArtItem {
  ArtItem({
    required this.id,
    required this.at,
    required this.prompt,
    required this.b64,
  });

  final String id;
  final DateTime at;
  final String prompt;
  final String b64;

  /// Decoded PNG bytes, ready for `Image.memory`.
  Uint8List get bytes => base64Decode(b64);

  /// Raw byte size of the decoded image, used to enforce the storage caps.
  int get byteSize => base64Decode(b64).length;

  /// `HH:mm`
  String get timeLabel =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  /// `HH:mm · <first 18 chars of prompt>`
  String get caption {
    final String text = prompt.length > 18 ? prompt.substring(0, 18) : prompt;
    return '$timeLabel · $text';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'at': at.toIso8601String(),
    'prompt': prompt,
    'b64': b64,
  };

  static ArtItem fromJson(Map<String, dynamic> j) => ArtItem(
    id: (j['id'] ?? '') as String,
    at: DateTime.tryParse((j['at'] ?? '') as String) ?? DateTime.now(),
    prompt: (j['prompt'] ?? '') as String,
    b64: (j['b64'] ?? '') as String,
  );
}

/// Persisted, newest-first wall of generated pictures.
class ArtStore {
  ArtStore();

  static const String key = 'feiyu.art.v1';
  static const int maxItems = 8;
  static const int maxItemBytes = 800 * 1024;
  static const int maxTotalBytes = 3 * 1024 * 1024;

  /// Newest first.
  final List<ArtItem> items = <ArtItem>[];

  static int _lastId = 0;

  /// Monotonic id derived from the current microsecond clock, so two images
  /// produced in the same tick still get distinct ids.
  static int _nextId() {
    final int now = DateTime.now().microsecondsSinceEpoch;
    final int id = now > _lastId ? now : _lastId + 1;
    _lastId = id;
    return id;
  }

  static Future<ArtStore> load() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final ArtStore store = ArtStore();
    final String? raw = sp.getString(key);
    if (raw != null) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final dynamic entry in decoded) {
            if (entry is Map) {
              store.items.add(ArtItem.fromJson(entry.cast<String, dynamic>()));
            }
          }
        }
      } catch (_) {
        // Corrupt data: start from an empty wall.
      }
    }
    store._enforce();
    return store;
  }

  int get totalBytes =>
      items.fold<int>(0, (int sum, ArtItem e) => sum + e.byteSize);

  String _encode() =>
      jsonEncode(items.map((ArtItem e) => e.toJson()).toList());

  /// Drop oversized tiles, order newest-first, then clamp count and total size.
  void _enforce() {
    items.removeWhere((ArtItem e) => e.byteSize > maxItemBytes);
    items.sort((ArtItem a, ArtItem b) {
      final int byTime = b.at.compareTo(a.at);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
    if (items.length > maxItems) {
      items.removeRange(maxItems, items.length);
    }
    while (items.isNotEmpty && totalBytes > maxTotalBytes) {
      items.removeLast();
    }
  }

  /// Prepend freshly generated pictures and persist them.
  ///
  /// Items larger than [maxItemBytes] are skipped entirely. The list is mutated
  /// synchronously before the first `await`, so callers can `setState` right
  /// after invoking this and then await the save.
  Future<void> addAll(Iterable<ArtItem> fresh) async {
    for (final ArtItem item in fresh) {
      if (item.byteSize > maxItemBytes) continue;
      items.add(
        ArtItem(
          id: _nextId().toString(),
          at: item.at,
          prompt: item.prompt,
          b64: item.b64,
        ),
      );
    }
    _enforce();
    await save();
  }

  /// Remove one tile by id and persist the rest.
  Future<void> remove(String id) async {
    items.removeWhere((ArtItem e) => e.id == id);
    await save();
  }

  /// Persist the wall. On a quota failure, drop the oldest half and retry once.
  /// If the retry also fails the error is rethrown.
  Future<void> save() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    try {
      await sp.setString(key, _encode());
    } catch (_) {
      final int keep = items.length ~/ 2;
      if (keep <= 0) {
        items.clear();
      } else {
        items.removeRange(keep, items.length);
      }
      await sp.setString(key, _encode());
    }
  }
}
