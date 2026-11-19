# Task 15 — Entrance, streaming caret, press feedback, mood pulse, scroll-to-bottom

## Scope
- `lib/ui/message_list.dart`: only the newest message's `MessageBubble` is wrapped
  in `TweenAnimationBuilder<double>(key: ValueKey(messages.last), .6 -> 1,
  AppDurations.entrance, Curves.easeOutCubic)` with opacity + 6px translate.
  Also passes `trailing: const StreamingCaret()` to the last assistant bubble when
  `busy && !waitingFirstToken`.
- `lib/ui/bubble.dart`: new `StreamingCaret` StatefulWidget owning its own
  `AnimationController(1200ms)..repeat(reverse: true)`, disposed; renders a 2x16
  rounded `AppPalette.warm` bar keyed `streaming-caret` inside a `FadeTransition`.
- `lib/ui/composer.dart`: new private `_PressableSend` drives
  `AnimatedScale(.96, 120ms)` via `GestureDetector` onTapDown/Cancel/Up; keeps the
  `'发送'` tooltip and calls `onSend` exactly once per tap.
- `lib/ui/chat_app_bar.dart`: `StatusDot(..., pulse: mood == SceneMood.thinking)`;
  color mapping unchanged; no `busy` parameter added.
- `lib/main.dart`: `_showJump` + `_onScroll` listener added in `initState`,
  removed before `_scroll.dispose()` in `dispose`; scroll-to-bottom 40px button in
  the body `Stack` (`Positioned(right: 12, bottom: 8)`, `AnimatedOpacity`,
  `IgnorePointer`, `arrow_downward`, `tooltip: '回到底部'`). No new
  `AnimationController` in `_ChatPageState`.
- `test/motion_test.dart`: newest bubble entrance opacity reaches 1 and caret is
  present after 300ms; caret absent while `waitingFirstToken`; no `pumpAndSettle`.

## Commands and raw results

Environment: `FLUTTER_SUPPRESS_ANALYTICS=true`; `APPDATA`/`LOCALAPPDATA`/`TEMP`/
`PUB_CACHE` redirected to `..\.tools-tmp\*`.

### `flutter analyze` (raw last lines)
```
Analyzing dafeiyu...
No issues found! (ran in 2.3s)
```

### `flutter test` (raw last 20 lines)
```
00:02 +17: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/empty_state_test.dart: renders samples and reports the tapped one
00:02 +18: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/empty_state_test.dart: renders samples and reports the tapped one
00:02 +19: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +20: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +21: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +22: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +23: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +24: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +25: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +26: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +27: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:03 +28: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:03 +29: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:03 +30: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/motion_test.dart: newest bubble fades in and shows the streaming caret
00:03 +31: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:03 +32: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:04 +33: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: InlineNotice dismiss control fires callback
00:04 +34: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:04 +35: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: Pill with success tone renders its label
00:04 +36: All tests passed!
```

### Grep checks
```
$ grep -c "AnimationController(" lib/main.dart
0
$ grep -n "_scroll.removeListener" lib/main.dart
490:    _scroll.removeListener(_onScroll);
$ grep -c "pumpAndSettle" test/motion_test.dart
0
```

## Cleanup
- Removed crash log `flutter_05.log` produced by the first analyzer run before the
  APPDATA redirection was applied.
- No packages added, no `// ignore:`.

## Risks
- `ValueKey<Message>(messages.last)` relies on `Message` identity; since
  `Message` does not override `==`, each newly appended message is a new identity
  and replays the entrance, while historical entries keep their keys.
- Historical bubbles are not wrapped, so scrolling/rebulding cannot replay their
  animation.
