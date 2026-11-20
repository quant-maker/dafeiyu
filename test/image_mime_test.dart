import 'package:flutter_test/flutter_test.dart';
import 'package:feiyu/main.dart' show imageMimeFor;

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
}
