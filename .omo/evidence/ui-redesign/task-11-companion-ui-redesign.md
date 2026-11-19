# Task 11 — Rebuild the empty state with a drawn avatar

Date: 2026-11-19
Files: `lib/ui/empty_state.dart` (new), `lib/main.dart`, `test/empty_state_test.dart` (new)
Commit: `01a4f8a feat(ui): rebuild the empty state with a drawn avatar`

## Implementation

- New `EmptyState({required List<String> samples, required ValueChanged<String> onSample, String? buildTag})`.
- `Center` → `SingleChildScrollView(vertical, padding: EdgeInsets.fromLTRB(28, 0, 28, 40))` →
  `Column(mainAxisSize: min)`:
  - `AvatarMark(size: 96, glow: true)` (drawn CustomPaint fish, no emoji)
  - 20px gap; title `今天想聊点什么？` in `AppType.title` / `AppPalette.text1`
  - 8px gap; hint in `AppType.caption` / `AppPalette.text3`; `· $buildTag` only appended when
    `buildTag` is non-null and non-empty
  - 26px gap; `Wrap(spacing: 8, runSpacing: 10, alignment: WrapAlignment.center)` of
    `Pill(label: s, onTap: () => onSample(s))`
- No `ContentFrame` inside: the chat shell's `ContentFrame` already constrains width.
- `_ChatPageState._emptyState()` is now a thin wrapper:
  `EmptyState(samples: const [...], onSample: _send, buildTag: kBuildTag)`.
  `_send` still takes an optional `String?`; persistence/streaming untouched.

## Verification

`grep`/`Select-String` — `🐟` in `lib/ui/empty_state.dart`: **0 matches**.

`flutter analyze` (repo):

```
Analyzing dafeiyu...
No issues found! (ran in 2.4s)
```

`flutter test` (repo, last 15 lines):

```
00:01 +15: ...layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +16: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +17: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +18: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +19: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +20: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +21: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +22: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +23: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +24: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:03 +25: ...surfaces_test.dart: gallery renders every component without exceptions
00:03 +26: ...surfaces_test.dart: InlineNotice dismiss control fires callback
00:03 +27: ...surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:03 +28: ...surfaces_test.dart: Pill with success tone renders its label
00:03 +29: All tests passed!
```

`test/empty_state_test.dart` assertions:
- all 3 sample labels found exactly once,
- tapping `今天有什么好玩的` delivers that string to `onSample`,
- `find.text('🐟')` → `findsNothing`,
- `tester.takeException()` → null.
