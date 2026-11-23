import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One headline pulled from a feed, waiting to be turned into a share.
class FeedItem {
  FeedItem({
    required this.title,
    required this.url,
    required this.source,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String title;
  final String url;
  final String source;
  final DateTime at;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'url': url,
        'source': source,
        'at': at.toIso8601String(),
      };

  /// Returns null instead of throwing on a malformed entry.
  static FeedItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = (raw['title'] ?? '').toString().trim();
    final url = (raw['url'] ?? '').toString().trim();
    if (title.isEmpty || url.isEmpty) return null;
    final source = (raw['source'] ?? '').toString().trim();
    final at = DateTime.tryParse((raw['at'] ?? '').toString()) ?? DateTime.now();
    return FeedItem(title: title, url: url, source: source, at: at);
  }
}

/// A quiet, local buffer of headlines she might share later.
///
/// This is deliberately separate from the chat history and from
/// `SharedUrlStore`: it is the *pre-share* material the veto gate reads.
/// The newest [maxItems] items live in [SharedPreferences] under [key].
class FeedInbox {
  FeedInbox._(this._items);

  factory FeedInbox.empty() => FeedInbox._(<FeedItem>[]);

  static const String key = 'feiyu.inbox.v1';
  static const int maxItems = 12;

  final List<FeedItem> _items;

  static Future<FeedInbox> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final items = decoded
              .map(FeedItem.fromJson)
              .whereType<FeedItem>()
              .toList()
            ..sort((a, b) => b.at.compareTo(a.at));
          if (items.length > maxItems) items.removeRange(maxItems, items.length);
          return FeedInbox._(items);
        }
      }
    } catch (_) {
      // Corrupt or unavailable storage: start empty, the heartbeat still works.
    }
    return FeedInbox.empty();
  }

  /// Newest first.
  List<FeedItem> get items => List<FeedItem>.unmodifiable(_items);

  /// Items that have not been consumed by a share yet.
  int get unsharedCount => _items.length;

  /// Merges [incoming] into the buffer, de-duplicating by URL and keeping the
  /// newest [maxItems]. Returns how many genuinely new items were accepted.
  Future<int> addAll(Iterable<FeedItem> incoming) async {
    final known = _items.map((e) => e.url).toSet();
    final accepted = <FeedItem>[];
    for (final item in incoming) {
      final url = item.url.trim();
      if (url.isEmpty || known.contains(url)) continue;
      known.add(url);
      accepted.add(item);
    }
    if (accepted.isNotEmpty) {
      _items
        ..addAll(accepted)
        ..sort((a, b) => b.at.compareTo(a.at));
      _trim();
      await _persist();
    }
    return accepted.length;
  }

  /// Drops anything older than [maxAge] so stale headlines never pile up.
  Future<void> prune({Duration maxAge = const Duration(hours: 48)}) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final before = _items.length;
    _items.removeWhere((e) => e.at.isBefore(cutoff));
    if (_items.length != before) await _persist();
  }

  /// Removes items whose URL was just shared, so they are not offered twice.
  Future<void> markShared(Iterable<String> urls) async {
    final set = urls.map((u) => u.trim()).where((u) => u.isNotEmpty).toSet();
    if (set.isEmpty) return;
    final before = _items.length;
    _items.removeWhere((e) => set.contains(e.url.trim()));
    if (_items.length != before) await _persist();
  }

  void _trim() {
    if (_items.length > maxItems) _items.removeRange(maxItems, _items.length);
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        key,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort persistence; the in-memory buffer still de-duplicates.
    }
  }
}
