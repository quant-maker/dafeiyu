import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'feed_inbox.dart';

/// A minimal JSON GET seam so tests never touch the network.
typedef JsonFetcher = Future<String?> Function(String url);

const String hnFrontPageUrl =
    'https://hn.algolia.com/api/v1/search?tags=front_page';
const String v2exHotUrl = 'https://www.v2ex.com/api/topics/hot.json';

/// Wallstreetcn's public information flow.
///
/// It replaces the old GitHub "new repos" source, which was unreachable from
/// mainland networks (api.github.com resets the connection) and returned
/// nothing usable even when it did answer. This one is fast, keyless, and fits
/// her markets-and-quant character far better.
const String wallstreetcnUrl =
    'https://api-one-wscn.awtmt.com/apiv1/content/information-flow'
    '?channel=global&accept=article&limit=10';

const int _perSource = 4;

/// Pulls headlines from HN, V2EX and 华尔街见闻.
///
/// Every source is parsed defensively: a bad response, a truncated body or a
/// malformed field simply contributes nothing. This function never throws.
Future<List<FeedItem>> fetchFeeds({required JsonFetcher httpGet}) async {
  final out = <FeedItem>[];
  out.addAll(await _fetchHn(httpGet));
  out.addAll(await _fetchV2ex(httpGet));
  out.addAll(await _fetchWallstreetcn(httpGet));
  return out;
}

Future<List<FeedItem>> _fetchHn(JsonFetcher httpGet) async {
  try {
    final decoded = await _decode(httpGet, hnFrontPageUrl);
    if (decoded is! Map) return const <FeedItem>[];
    final hits = decoded['hits'];
    if (hits is! List) return const <FeedItem>[];
    final out = <FeedItem>[];
    for (final hit in hits) {
      if (out.length >= _perSource) break;
      if (hit is! Map) continue;
      final title = (hit['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final explicit = (hit['url'] ?? '').toString().trim();
      final objectId = (hit['objectID'] ?? '').toString().trim();
      final url = explicit.isNotEmpty
          ? explicit
          : (objectId.isNotEmpty
              ? 'https://news.ycombinator.com/item?id=$objectId'
              : '');
      if (url.isEmpty) continue;
      out.add(FeedItem(
        title: title,
        url: url,
        source: 'HN',
        author: (hit['author'] ?? '').toString().trim(),
      ));
    }
    return out;
  } catch (_) {
    return const <FeedItem>[];
  }
}

Future<List<FeedItem>> _fetchV2ex(JsonFetcher httpGet) async {
  try {
    final decoded = await _decode(httpGet, v2exHotUrl);
    if (decoded is! List) return const <FeedItem>[];
    final out = <FeedItem>[];
    for (final topic in decoded) {
      if (out.length >= _perSource) break;
      if (topic is! Map) continue;
      final title = (topic['title'] ?? '').toString().trim();
      final url = (topic['url'] ?? '').toString().trim();
      if (title.isEmpty || url.isEmpty) continue;
      final member = topic['member'];
      final author = member is Map ? (member['username'] ?? '').toString().trim() : '';
      out.add(FeedItem(
        title: title,
        url: url,
        source: 'V2EX',
        author: author,
      ));
    }
    return out;
  } catch (_) {
    return const <FeedItem>[];
  }
}

Future<List<FeedItem>> _fetchWallstreetcn(JsonFetcher httpGet) async {
  try {
    final decoded = await _decode(httpGet, wallstreetcnUrl);
    if (decoded is! Map) return const <FeedItem>[];
    final data = decoded['data'];
    if (data is! Map) return const <FeedItem>[];
    final items = data['items'];
    if (items is! List) return const <FeedItem>[];
    final out = <FeedItem>[];
    for (final entry in items) {
      if (out.length >= _perSource) break;
      if (entry is! Map) continue;
      // Articles and live flashes both carry their payload one level down.
      final resource = entry['resource'];
      if (resource is! Map) continue;
      // A blank title (not just a missing one) must fall through to the short
      // summary, otherwise flashes show up with nothing to say.
      var title = (resource['title'] ?? '').toString().trim();
      if (title.isEmpty) {
        title = (resource['content_short'] ?? '').toString().trim();
      }
      final url = (resource['uri'] ?? '').toString().trim();
      if (title.isEmpty || url.isEmpty) continue;
      out.add(FeedItem(title: title, url: url, source: '华尔街见闻'));
    }
    return out;
  } catch (_) {
    return const <FeedItem>[];
  }
}

Future<Object?> _decode(JsonFetcher httpGet, String url) async {
  final raw = await httpGet(url);
  if (raw == null || raw.trim().isEmpty) return null;
  return jsonDecode(raw);
}

/// Production wiring: on web the same-origin `/fetch?url=` proxy hides CORS;
/// on native the URL is fetched directly.
///
/// GitHub's search API (and some others) reject requests without a real
/// User-Agent, so always send one.
Future<String?> defaultJsonFetcher(String url) async {
  final target =
      kIsWeb ? '${Uri.base.origin}/fetch?url=${Uri.encodeComponent(url)}' : url;
  try {
    final res = await http
        .get(
          Uri.parse(target),
          headers: const {
            'accept': 'application/json',
            'user-agent': 'feiyu/1.0 (AI companion client)',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    // A misconfigured web build can return the SPA index.html at /fetch;
    // treat anything that is obviously HTML as a miss instead of trying to
    // jsonDecode it.
    if (body.trimLeft().startsWith('<')) return null;
    return body;
  } catch (_) {
    return null;
  }
}
