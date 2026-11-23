import 'dart:convert';
import 'dart:typed_data';

import 'package:feiyu/comfy/art_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds an artwork whose decoded size is exactly [bytes].
ArtItem _item(int index, {int bytes = 8, String prompt = '鲸鱼'}) {
  final Uint8List data = Uint8List(bytes);
  for (int i = 0; i < bytes; i++) {
    data[i] = i % 251;
  }
  return ArtItem(
    id: '',
    at: DateTime(2026, 11, 23, 10, index % 60),
    prompt: prompt,
    b64: base64Encode(data),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('keeps at most 8 items, newest first', () async {
    final ArtStore store = await ArtStore.load();
    await store.addAll(<ArtItem>[for (int i = 0; i < 10; i++) _item(i)]);

    expect(store.items.length, 8);
    // 10:09 is the newest of the ten; the two oldest (10:00, 10:01) are gone.
    expect(store.items.first.at.minute, 9);
    expect(store.items.last.at.minute, 2);
  });

  test('skips a single image larger than 800 KB', () async {
    final ArtStore store = await ArtStore.load();
    await store.addAll(<ArtItem>[
      _item(0, bytes: ArtStore.maxItemBytes + 1),
      _item(1),
    ]);

    expect(store.items.length, 1);
    expect(store.items.single.byteSize, lessThanOrEqualTo(ArtStore.maxItemBytes));
  });

  test('evicts oldest items until the 3 MB budget fits', () async {
    final ArtStore store = await ArtStore.load();
    const int tile = 700 * 1024; // five of these exceed 3 MB
    await store.addAll(<ArtItem>[
      for (int i = 0; i < 5; i++) _item(i, bytes: tile),
    ]);

    expect(store.items.length, 4);
    expect(store.totalBytes, lessThanOrEqualTo(ArtStore.maxTotalBytes));
    expect(store.items.first.at.minute, 4);
    expect(store.items.last.at.minute, 1);
  });

  test('remove drops only the matching id', () async {
    final ArtStore store = await ArtStore.load();
    await store.addAll(<ArtItem>[_item(0), _item(1)]);
    final String id = store.items.first.id;

    await store.remove(id);

    expect(store.items.length, 1);
    expect(store.items.any((ArtItem e) => e.id == id), isFalse);
  });

  test('orders across separate addAll calls newest first', () async {
    final ArtStore store = await ArtStore.load();
    await store.addAll(<ArtItem>[_item(0, prompt: '旧')]);
    await store.addAll(<ArtItem>[_item(1, prompt: '新')]);

    expect(store.items.first.prompt, '新');
    expect(store.items.last.prompt, '旧');
    expect(store.items.first.id, isNot(store.items.last.id));
  });

  test('persists through a load round-trip', () async {
    final ArtStore store = await ArtStore.load();
    await store.addAll(<ArtItem>[_item(0, prompt: '雨夜的便利店')]);

    final ArtStore again = await ArtStore.load();

    expect(again.items.length, 1);
    expect(again.items.single.prompt, '雨夜的便利店');
    expect(again.items.single.byteSize, 8);
  });

  test('caption is HH:mm plus the first 18 prompt characters', () {
    final ArtItem item = ArtItem(
      id: '1',
      at: DateTime(2026, 1, 1, 9, 5),
      prompt: '一只胖胖的小鲸鱼，坐在深夜窗边，暖色台灯',
      b64: base64Encode(<int>[1, 2, 3]),
    );

    expect(item.timeLabel, '09:05');
    expect(item.caption, '09:05 · 一只胖胖的小鲸鱼，坐在深夜窗边，暖色');
  });
}
