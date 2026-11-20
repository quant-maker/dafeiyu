import 'package:flutter_test/flutter_test.dart';
import 'package:feiyu/main.dart' show imageMimeFor, isUsableImageBase64;

void main() {
  test('png payload is png', () {
    expect(
      imageMimeFor('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='),
      'image/png',
    );
  });

  test('jpeg payload is jpeg', () {
    expect(
      imageMimeFor('/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8U'),
      'image/jpeg',
    );
  });

  test('gif / webp', () {
    expect(imageMimeFor('R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=='), 'image/gif');
    expect(imageMimeFor('UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA='), 'image/webp');
  });

  test('unknown falls back to jpeg', () {
    expect(imageMimeFor('AAAA'), 'image/jpeg');
  });

  test('reported 400 case is now png', () {
    expect(imageMimeFor('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42'), 'image/png');
  });

  test('usable png payload is true', () {
    expect(
      isUsableImageBase64(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='),
      isTrue,
    );
  });

  test('usable jpeg payload is true', () {
    expect(
      isUsableImageBase64(
          '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPDs0NDP/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AVN//2Q=='),
      isTrue,
    );
  });

  test('truncated (length not multiple of 4) is false', () {
    expect(
      isUsableImageBase64(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg='),
      isFalse,
    );
  });

  test('non-image base64 is false', () {
    expect(isUsableImageBase64('aGVsbG8='), isFalse);
  });

  test('unknown magic with valid base64 is false', () {
    expect(isUsableImageBase64('AAAAAAAAAAAAAAAA'), isFalse);
  });
}
