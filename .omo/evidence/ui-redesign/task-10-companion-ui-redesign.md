# Task 10 — Time grouping in the message list

Date: 2026-11-19
Files: `lib/ui/message_list.dart`, `test/message_time_test.dart`

## Implementation

- Added top-level private `String _timeLabel(DateTime at)` → `HH:mm` for today,
  `M月d日 HH:mm` otherwise. No `intl` dependency.
- `itemBuilder` now renders a centred header when `index == 0` or the gap to the
  previous message is `>= 5` minutes:
  `Padding(symmetric(vertical: 8), Center(Text(label, key: ValueKey('time-$index'), style: AppType.caption.copyWith(color: AppPalette.text3))))`.
- Existing 4px same-speaker / 14px speaker-change gap rhythm preserved; bubble tip
  padding contract (`MediaQuery.padding.top`) and `controller` wiring untouched.

## Meta test — header count

`test/message_time_test.dart` builds messages at `t0`, `t0+1min`, `t0+7min`.
Headers with `ValueKey<String>` starting `time-` → **2** (index 0 and index 2),
both `Text` with non-empty data. Keys asserted as `{time-0, time-2}`.

## `flutter analyze` (repo, last 20 lines)

```
Analyzing dafeiyu...
No issues found! (ran in 2.8s)
```

Scoped (`lib/ui/message_list.dart test/message_time_test.dart`):

```
Analyzing 2 items...
No issues found! (ran in 2.2s)
```

`grep -n "intl" pubspec.yaml` → 0 matches.

## `flutter test` (repo, last 20 lines)

```
00:01 +9: ...chat_app_bar_test.dart: renders all four action tooltips and the avatar mark
00:01 +10: ...chat_app_bar_test.dart: renders all four action tooltips and the avatar mark
00:01 +11: ...contrast_test.dart: ReadabilityScrim paints two fixed-alpha gradients
00:01 +12: ...contrast_test.dart: ReadabilityScrim paints two fixed-alpha gradients
00:01 +13: ...layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +14: ...layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +15: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:01 +16: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:01 +17: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +18: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +19: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +20: ...message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +21: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +22: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +23: ...message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +24: ...surfaces_test.dart: gallery renders every component without exceptions
00:03 +25: ...surfaces_test.dart: InlineNotice dismiss control fires callback
00:03 +26: ...surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:03 +27: ...surfaces_test.dart: Pill with success tone renders its label
00:03 +28: All tests passed!
```

Result: **28 tests passed** (was 23 before Task 5/contrast/surface additions plus this new one).
