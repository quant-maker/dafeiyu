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

const String _githubFixture = '''
{"items":[
  {"full_name":"a/one","html_url":"https://github.com/a/one"},
  {"full_name":"a/two","html_url":"https://github.com/a/two"},
  {"full_name":"a/three","html_url":"https://github.com/a/three"},
  {"full_name":"a/four","html_url":"https://github.com/a/four"},
  {"full_name":"a/five","html_url":"https://github.com/a/five"}
]}
''';

Future<String?> _fixtureFetcher(String url) async {
  if (url == hnFrontPageUrl) return _hnFixture;
  if (url == v2exHotUrl) return _v2exFixture;
  if (url == rollingGithubNewReposUrl()) return _githubFixture;
  return null;
}

void main() {
  test('parses all three sources and caps each at four', () async {
    final items = await fetchFeeds(httpGet: _fixtureFetcher);

    expect(items, hasLength(12));
    expect(items.where((e) => e.source == 'HN'), hasLength(4));
    expect(items.where((e) => e.source == 'V2EX'), hasLength(4));
    expect(items.where((e) => e.source == 'GitHub'), hasLength(4));
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
