import 'package:feiyu/companion/feed_fetch.dart';
import 'package:flutter_test/flutter_test.dart';

const String _hnFixture = '''
{"hits":[
  {"title":"Rust in space","url":"https://example.com/rust","objectID":"1"},
  {"title":"Ask HN: what now","url":null,"objectID":"42"},
  {"title":"","url":"https://ignored.example","objectID":"3"},
  {"title":"A story","url":"https://a.example","objectID":"4"},
  {"title":"B story","url":"https://b.example","objectID":"5"},
  {"title":"C story","url":"https://c.example","objectID":"6"},
  {"title":"D story","url":"https://d.example","objectID":"7"}
]}
''';

const String _v2exFixture = '''
[
  {"title":"V1","url":"https://www.v2ex.com/t/1"},
  {"title":"V2","url":"https://www.v2ex.com/t/2"},
  {"title":"V3","url":"https://www.v2ex.com/t/3"},
  {"title":"V4","url":"https://www.v2ex.com/t/4"},
  {"title":"V5","url":"https://www.v2ex.com/t/5"}
]
''';

const String _wscnFixture = '''
{"code":20000,"data":{"items":[
  {"resource_type":"article","resource":{"title":"A1","uri":"https://wallstreetcn.com/articles/1"}},
  {"resource_type":"live","resource":{"title":"L1","content_text":"x","uri":"https://wallstreetcn.com/charts/2"}},
  {"resource_type":"article","resource":{"title":"","content_short":"short only","uri":"https://wallstreetcn.com/articles/3"}},
  {"resource_type":"article","resource":{"title":"A4","uri":"https://wallstreetcn.com/articles/4"}},
  {"resource_type":"article","resource":{"title":"A5","uri":"https://wallstreetcn.com/articles/5"}},
  {"resource_type":"article","resource":{"title":"A6","uri":"https://wallstreetcn.com/articles/6"}}
]}}
''';

Future<String?> _fixtureFetcher(String url) async {
  if (url == hnFrontPageUrl) return _hnFixture;
  if (url == v2exHotUrl) return _v2exFixture;
  if (url == wallstreetcnUrl) return _wscnFixture;
  return null;
}

void main() {
  test('parses all three sources and caps each at four', () async {
    final items = await fetchFeeds(httpGet: _fixtureFetcher);

    expect(items, hasLength(12));
    expect(items.where((e) => e.source == 'HN'), hasLength(4));
    expect(items.where((e) => e.source == 'V2EX'), hasLength(4));
    expect(items.where((e) => e.source == '华尔街见闻'), hasLength(4));
  });

  test('wallstreetcn falls back to content_short when title is blank',
      () async {
    final items = await fetchFeeds(httpGet: _fixtureFetcher);
    expect(
      items.any((e) => e.title == 'short only'),
      isTrue,
    );
  });

  test('HN falls back to the item discussion URL when url is null', () async {
    final items = await fetchFeeds(httpGet: _fixtureFetcher);
    final ask = items.firstWhere((e) => e.title == 'Ask HN: what now');
    expect(ask.url, 'https://news.ycombinator.com/item?id=42');
  });

  test('empty titles are skipped', () async {
    final items = await fetchFeeds(httpGet: _fixtureFetcher);
    expect(items.any((e) => e.url == 'https://ignored.example'), isFalse);
  });

  test('malformed JSON yields an empty list', () async {
    Future<String?> broken(String url) async => 'this is not json {';
    expect(await fetchFeeds(httpGet: broken), isEmpty);
  });

  test('a throwing or null fetcher never propagates', () async {
    Future<String?> nulls(String url) async => null;
    Future<String?> boom(String url) async => throw StateError('offline');
    expect(await fetchFeeds(httpGet: nulls), isEmpty);
    expect(await fetchFeeds(httpGet: boom), isEmpty);
  });
}
