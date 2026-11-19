# Task 12 — Restyle the error bar with InlineNotice

Date: 2026-11-19
Files: `lib/main.dart`, `test/error_notice_test.dart` (new)

## Implementation

`_ChatPageState._errorBar()` is now:

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
  child: InlineNotice(
    tone: NoticeTone.danger,
    message: _error!,
    onDismiss: () => setState(() => _error = null),
  ),
)
```

- No `ContentFrame` wrapper — the shell already constrains width.
- Copyability preserved: `InlineNotice` renders the message in a `SelectableText`.
- `_error` assignment points and clearing timing unchanged; only the visual
  wrapper changed.
- Removed the ad-hoc `Color(0xFF3B1D22)` / `Color(0xFF7A2A35)` error surface.

## Verification

`Select-String lib/main.dart -Pattern '0xFF3B1D22|0xFF7A2A35'`: **0 matches**.

`flutter analyze` (repo):

```
Analyzing dafeiyu...
No issues found! (ran in 2.2s)
```

`flutter test` (repo, last 15 lines):

```
00:01 +16: ...layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +17: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:01 +18: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:01 +19: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +20: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +21: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +22: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +23: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +24: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +25: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +26: ...surfaces_test.dart: gallery renders every component without exceptions
00:02 +27: ...surfaces_test.dart: InlineNotice dismiss control fires callback
00:02 +28: ...surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:02 +29: ...surfaces_test.dart: Pill with success tone renders its label
00:02 +30: All tests passed!
```

`test/error_notice_test.dart` (surface forced to 320×640):
- dismiss control (`tooltip: '关闭'`) exists,
- tapping it fires the callback,
- `tester.takeException()` → null.
