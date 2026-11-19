# Task 13 — Composer (single glass layer)

Date: 2026-11-19
Scope: `lib/ui/composer.dart` (new), `lib/main.dart` (`_composer()` delegation + import swap), `test/composer_test.dart` (new).

## Changed files
- `lib/ui/composer.dart` — new `Composer` StatelessWidget. One `Padding(10,4,10,10)` → one `SafeArea(top:false)` → one `ClipRRect(pill)` → one `BackdropFilter(sigma 18)` → glass `Container` (`AppPalette.composerSurface`, pill radius, `lineStrong @ .10` border, `AppShadows.soft`) → `Row` of image / text field / mic / send-stop.
- `lib/main.dart` — `_composer()` now returns `Composer(controller: _input, busy: _busy, listening: _listening, onImage: _imageSheet, onMic: _toggleVoice, onSend: _send, onStop: _stop, onSubmitted: (_) => _send(), hint: _listening ? '正在听…' : '和大肥鱼说点什么…')`; removed inline composer and now-unused `dart:ui as ui` import; added `import 'ui/composer.dart';`.
- `test/composer_test.dart` — 390-wide widget tests for idle send + busy state.

## Commands & raw results

### `flutter analyze` (redirected APPDATA/LOCALAPPDATA/TEMP/HOME to `../.tools-tmp/*`)
```
Analyzing dafeiyu...
No issues found! (ran in 2.2s)
```

### `flutter test` (last 20 lines)
```
00:01 +13: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/composer_test.dart: idle composer sends and keeps image/mic enabled
00:01 +14: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/composer_test.dart: idle composer sends and keeps image/mic enabled
00:01 +15: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/empty_state_test.dart: renders samples and reports the tapped one
00:01 +16: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/empty_state_test.dart: renders samples and reports the tapped one
00:01 +17: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +18: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:02 +19: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +20: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +21: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +22: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +23: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +24: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +25: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +26: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +27: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +28: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:03 +29: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: InlineNotice dismiss control fires callback
00:03 +30: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:03 +31: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: Pill with success tone renders its label
00:03 +32: All tests passed!
```

## Grep assertions
```
main_backdroplines=0
composer_backdroplines=1
main_safearea=1
```
- `lib/main.dart` has 0 `BackdropFilter`; `lib/ui/composer.dart` has exactly 1.
- `lib/main.dart` has exactly 1 `SafeArea(` (the image-sheet dialog at line ~783); the chat column is NOT wrapped in `SafeArea`.

## QA scenarios
- happy: `flutter test test/composer_test.dart` passes; idle send tap invokes `onSend` once; no exceptions.
- failure: omitting `busy ? null : onImage` would fail the busy-state `onPressed == null` assertion.

## Cleanup
- Removed the analyzer crash log `flutter_05.log`.
- Did not commit `.flutter-plugins-dependencies` (tooling side effect, reverted).

## Risks
- Send button is a 42px gradient container wrapping the default `IconButton`; tap target is clamped to 42 by the tight container (spec geometry). No overflow under the 390-wide test.
