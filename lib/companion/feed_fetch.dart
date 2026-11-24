import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'feed_inbox.dart';

/// A minimal JSON GET seam so tests never touch the network.
typedef JsonFetcher = Future<String?> Function(String url);

const String hnFrontPageUrl =
    'https://hn.algolia.com/api/v1/search?tags=front_page';
const String v2exHotUrl = 'https://www.v2ex.com/api/topics/hot.json';
const String githubNewReposUrl =
    'https://api.github.com/search/repositories?q=created:%3E2026-11-01&sort=stars&per_page=10';

/// The same GitHub query with a *rolling* window.
///
/// The literal date above was correct the day it was written and silently
/// degrades into "no repositories" a few weeks later, so the living code path
/// recomputes it. Kept beside the constant because the tests compare against
/// [githubNewReposUrl].
String rollingGithubNewReposUrl({DateTime? now, int days = 14}) {
  final DateTime from =
      (now ?? DateTime.now()).toUtc().subtract(Duration(days: days));
  final String d =
      '${from.year.toString().padLeft(4, '0')}-'
      '${from.month.toString().padLeft(2, '0')}-'
      '${from.day.toString().padLeft(2, '0')}';
  return 'https://api.github.com/search/repositories'
      '?q=created:%3E$d&sort=stars&per_page=10';
}

const int _perSource = 4;

/// Pulls headlines from HN, V2EX and GitHub.
///
/// Every source is parsed defensively: a bad response, a truncated body or a
/// malformed field simply contributes nothing. This function never throws.
Future<List<FeedItem>> fetchFeeds({required JsonFetcher httpGet}) async {
  final out = <FeedItem>[];
  out.addAll(await _fetchHn(httpGet));
  out.addAll(await _fetchV2ex(httpGet));
  out.addAll(await _fetchGitHub(httpGet));
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
      out.add(FeedItem(title: title, url: url, source: 'HN'));
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
      out.add(FeedItem(title: title, url: url, source: 'V2EX'));
    }
    return out;
  } catch (_) {
    return const <FeedItem>[];
  }
}

Future<List<FeedItem>> _fetchGitHub(JsonFetcher httpGet) async {
  try {
    final decoded = await _decode(httpGet, rollingGithubNewReposUrl());
    if (decoded is! Map) return const <FeedItem>[];
    final items = decoded['items'];
    if (items is! List) return const <FeedItem>[];
    final out = <FeedItem>[];
    for (final repo in items) {
      if (out.length >= _perSource) break;
      if (repo is! Map) continue;
      final name = (repo['full_name'] ?? '').toString().trim();
      final url = (repo['html_url'] ?? '').toString().trim();
      if (name.isEmpty || url.isEmpty) continue;
      out.add(FeedItem(title: name, url: url, source: 'GitHub'));
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
