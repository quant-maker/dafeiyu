# F2 Code-Review Fixes

Repo: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`

## Fixes applied

1. **FAB/send-button collision (HIGH)** — `lib/main.dart`: moved the jump-to-bottom `Positioned` from `bottom: 8` to `bottom: 72` (above the composer) and wrapped its child in `ExcludeSemantics(excluding: !_showJump)`. `IgnorePointer(ignoring: !_showJump)` and the 40px size are unchanged.
2. **`_loadModels` mounted guard** — `lib/main.dart`: added `if (!mounted) return;` after the `http.get` await (before `setState`) and in the catch path.
3. **`_toggleVoice` / `_finishRecording` mounted guards** — `lib/main.dart`: added `if (!mounted) return;` after each await before `setState` in both normal and catch paths.
4. **Preview branch guard** — `lib/main.dart`: `ChatStore.load().then(...)` preview branch now returns early `if (!mounted) return;` before `setState`; `_preview` semantics preserved.
5. **Dead mixin** — `lib/main.dart`: removed `with SingleTickerProviderStateMixin` from `_ChatPageState`. No `createTicker` remains.
6. **Dead parameter** — `lib/ui/scrim.dart`: removed `strength` constructor field and its doc comment. Geometry unchanged.
7. **Dead stub** — `lib/main.dart`: removed the empty `if (...) { // convenient for local testing }` block from the "填入示例" handler; the assignment remains.
8. **Real ThemeExtension** — `lib/ui/surfaces.dart`: `_PulsingDotState` now creates its controller in `didChangeDependencies` using `AppTokens.of(context).durations.breathe` (value still 1400ms).
9. **Image decode per rebuild** — `lib/ui/message_list.dart`: added private `_MessageImage` StatefulWidget that decodes base64 once in `initState` and reuses `Uint8List` bytes via `Image.memory`. Keyed by the message (`ObjectKey(m)`); same widths (170 user / 260 assistant), `fit`, tap callback; `Semantics(label: '图片消息')` stays in `bubble.dart`.
10. **Footprints busy feedback (LOW)** — `lib/feeds/footprints_page.dart`: while `_working`, the app-bar action shows a 16px `CircularProgressIndicator(strokeWidth: 2)` in a 44px `SizedBox`, with the `'补记一个瞬间'` tooltip; otherwise the same `GhostIconButton` with `onPressed: _add`.
11. **ChatAppBar caveat comment** — `lib/ui/chat_app_bar.dart`: added a comment above `preferredSize` noting 68 is the content height and Scaffold's `primary: true` adds the status-bar inset, so the widget must stay `primary`.

## Raw command output

### `flutter analyze`
```
Analyzing dafeiyu...
No issues found! (ran in 15.6s)
```
Exit code: 0

### `flutter test`
```
00:10 +54: All tests passed!
```

### `grep -c "SingleTickerProviderStateMixin" lib/main.dart`
```
0
```

### `grep -n "bottom: 72" lib/main.dart`
```
1840:              bottom: 72,
```

### `grep -n "createTicker" lib/main.dart` (exit 1 = no matches)
```
(no output)
```

---

## Remaining F2 findings (round 2)

### Fix 1 — scroll-to-bottom button moved into message area
`lib/main.dart`: the jump-to-bottom `Positioned` is now a child of a `Stack` that wraps the `Expanded` message area (`right: 12, bottom: 8`), so it can never overlap the composer or the pending/listening bars. Old outer sibling `Positioned(bottom: 72)` removed. `_showJump`, `_onScroll`, listener add/remove, 40px size, tooltip and icon styling unchanged.

### Fix 2 — message image refreshes when payload changes
`lib/ui/message_list.dart`: `_MessageImage` is now keyed by `ValueKey<String>(b64)` instead of `ObjectKey(m)`, and `_MessageImageState` implements `didUpdateWidget` re-decoding into a mutable `Uint8List _bytes` when `widget.base64 != oldWidget.base64`. Content-only updates keep the same key and do not re-decode.

### Verification

#### `flutter analyze` (whole repo)
```
Analyzing dafeiyu...
No issues found! (ran in 12.9s)
```
Exit code: 0

#### `flutter test`
```
00:06 +55: All tests passed!
```

New test in `test/message_list_test.dart`: `message image re-decodes when its payload changes` — pumps a message with a 1×1 red PNG, mutates `message.imageBase64` in place to a 1×1 blue PNG, pumps again, and asserts the rendered `Image`'s `MemoryImage.bytes` equal the new decoded payload and are not identical to the old bytes.

#### `grep -n "bottom: 72" lib/main.dart`
```
(no matches)
```

#### `grep -n "Expanded(" lib/main.dart`
```
1829:Expanded(
2376:Expanded(
2568:Expanded(
2591:Expanded(
2650:Expanded(
2810:Expanded(
```
Line 1829 is the new message-area `Expanded` wrapping the `Stack` with the in-area scroll button.

