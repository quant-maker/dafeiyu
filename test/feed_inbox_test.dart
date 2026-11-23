import 'package:feiyu/companion/feed_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FeedItem _item(String url, {String? title, DateTime? at}) => FeedItem(
      title: title ?? url,
      url: url,
      source: 'HN',
      at: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('addAll de-dupes by url', () async {
    final inbox = FeedInbox.empty();
    final added = await inbox.addAll([
      _item('https://a.example', title: 'first'),
      _item('https://a.example', title: 'duplicate'),
      _item('https://b.example'),
    ]);

    expect(added, 2);
    expect(inbox.items, hasLength(2));
    expect(
      inbox.items.firstWhere((e) => e.url == 'https://a.example').title,
      'first',
    );
    expect(inbox.unsharedCount, 2);
  });

  test('addAll keeps only the newest 12', () async {
    final inbox = FeedInbox.empty();
    final now = DateTime.now();
    final incoming = List<FeedItem>.generate(
      15,
      (i) => _item('https://x.example/$i', at: now.subtract(Duration(minutes: i))),
    );

    await inbox.addAll(incoming);

    expect(inbox.items, hasLength(12));
    expect(inbox.items.first.url, 'https://x.example/0');
    expect(inbox.items.last.url, 'https://x.example/11');
    expect(inbox.items.any((e) => e.url == 'https://x.example/14'), isFalse);
  });

  test('prune drops items older than the max age', () async {
    final inbox = FeedInbox.empty();
    final now = DateTime.now();
    await inbox.addAll([
      _item('https://old.example', at: now.subtract(const Duration(hours: 49))),
      _item('https://fresh.example', at: now.subtract(const Duration(hours: 1))),
    ]);

    await inbox.prune();

    expect(inbox.items, hasLength(1));
    expect(inbox.items.single.url, 'https://fresh.example');
  });

  test('prune honours a custom max age', () async {
    final inbox = FeedInbox.empty();
    final now = DateTime.now();
    await inbox.addAll([
      _item('https://a.example', at: now.subtract(const Duration(hours: 3))),
      _item('https://b.example', at: now.subtract(const Duration(minutes: 30))),
    ]);

    await inbox.prune(maxAge: const Duration(hours: 2));

    expect(inbox.items, hasLength(1));
    expect(inbox.items.single.url, 'https://b.example');
  });

  test('markShared removes consumed items', () async {
    final inbox = FeedInbox.empty();
    await inbox.addAll([
      _item('https://a.example'),
      _item('https://b.example'),
    ]);

    await inbox.markShared(['https://a.example']);

    expect(inbox.items, hasLength(1));
    expect(inbox.items.single.url, 'https://b.example');
  });
}
