# Todo 7 — Chat App Bar

Date: 2026-11-19
Scope: `lib/ui/chat_app_bar.dart` (new), `lib/main.dart` (appBar swap + import), `test/chat_app_bar_test.dart` (new).

## What changed

- Added `ChatAppBar extends StatelessWidget implements PreferredSizeWidget` with
  `static const double height = 68` (content height, excludes status bar) and
  `preferredSize => const Size.fromHeight(height)`.
- `build` returns `Padding(top: MediaQuery.padding.top)` wrapping a
  `SizedBox(height: 68)` row: `AvatarMark(size: 34, glow: true)` → title/status
  column (`Flexible`, status `maxLines: 1` + ellipsis) → `StatusDot` colored from
  `SceneMood` → four `GhostIconButton`s (36) inside one `Container` cluster.
- Mood → color: idle→mint, listening→primary, thinking→warm, speaking→primary,
  away→text3.
- Tooltips: `她的足迹`, `画画（ComfyUI）`, `新会话`, `设置`.
- Replaced the inline `AppBar` in `_ChatPageState.build` with `ChatAppBar`; the
  callbacks and `_statusLine()` content are unchanged.
- Transparent background, no elevation/shadow, no bottom border, no emoji.

## flutter analyze (raw last lines)

```
Analyzing dafeiyu...
No issues found! (ran in 3.9s)
```

Command:
`$env:FLUTTER_SUPPRESS_ANALYTICS='true'; flutter analyze`
(APPDATA/LOCALAPPDATA/TEMP redirected to `..\.tools-tmp\*` to avoid the analyzer
`.dartServer` permission crash.)

## flutter test (raw last 20 lines)

```
00:00 +0: loading C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/avatar_mark_test.dart
00:00 +0: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/avatar_mark_test.dart: renders a square mark at the requested size
00:00 +1: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/avatar_mark_test.dart: scales to large sizes
00:00 +2: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/avatar_mark_test.dart: does not render an emoji
00:00 +3: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/chat_app_bar_test.dart: renders all four action tooltips and the avatar mark
00:01 +4: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/chat_app_bar_test.dart: renders all four action tooltips and the avatar mark
00:01 +5: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +6: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +7: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +8: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +9: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +10: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:01 +11: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:01 +12: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:01 +13: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:01 +14: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:01 +15: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: InlineNotice dismiss control fires callback
00:01 +16: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:01 +17: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: Pill with success tone renders its label
00:01 +18: All tests passed!
```

## test/chat_app_bar_test.dart coverage

- All four tooltips found; `find.text('🐟')` absent.
- `ChatAppBar.height == 68`.
- 120-char status at 390×844: no exception (`takeException() == null`).
