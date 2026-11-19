# Task 6 — Readability scrim over the scene

## Deliverables
- New `lib/ui/scrim.dart` — `ReadabilityScrim` (single IgnorePointer + Stack implementation).
- `lib/main.dart` — body wrapped in `Stack(children: [Positioned.fill(child: ReadabilityScrim()), Column(...)])`.
- `sceneDim` default `.25` → `.42` at exactly 3 sites.
- New `test/contrast_test.dart` — 8 pure-Dart WCAG pairs + widget gradient-alpha check.

## Verification

### `flutter analyze` (last 20 lines)
```
Analyzing dafeiyu...
No issues found! (ran in 3.6s)
```

### `flutter test` (last 20 lines)
```
00:01 +9: .../test/chat_app_bar_test.dart: renders all four action tooltips and the avatar mark
00:01 +10: .../test/chat_app_bar_test.dart: renders all four action tooltips and the avatar mark
00:01 +11: .../test/contrast_test.dart: ReadabilityScrim paints two fixed-alpha gradients
00:01 +12: .../test/contrast_test.dart: ReadabilityScrim paints two fixed-alpha gradients
00:01 +13: .../test/contrast_test.dart: ReadabilityScrim paints two fixed-alpha gradients
00:01 +14: .../test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:02 +15: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +16: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +17: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +18: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +19: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +20: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +21: .../test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +22: .../test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +23: .../test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:03 +24: .../test/surfaces_test.dart: gallery renders every component without exceptions
00:03 +25: .../test/surfaces_test.dart: InlineNotice dismiss control fires callback
00:03 +26: .../test/surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:03 +27: .../test/surfaces_test.dart: Pill with success tone renders its label
00:03 +28: All tests passed!
```

## Computed WCAG contrast ratios (fg alpha-blended over bg, then WCAG luminance)
| pair | ratio | threshold |
|---|---|---|
| text1 / bubbleSurface | 14.975 | ≥ 7 |
| text1 / bubbleMine | 13.126 | ≥ 7 |
| text1 / surfaceAlt | 14.959 | ≥ 7 |
| text1 / ink | 17.934 | ≥ 7 |
| text2 / surfaceAlt | 7.066 | ≥ 4.5 |
| text2 / ink | 7.738 | ≥ 4.5 |
| text3 / ink | 5.357 | ≥ 4.5 |
| text3 / surfaceAlt | 5.075 | ≥ 4.5 |

All 8 pass.

## `sceneDim` default verification
```
this.sceneDim = .42 : 1
?? .42 : 2
?? .25 : 0
sceneDim = .25 : 0
```

## Cleanup
- Analyzer APPDATA/LOCALAPPDATA/TEMP redirected to `..\.tools-tmp\*` to avoid the `.dartServer` PathAccessException.
- Crash log `flutter_04.log` produced by the first (unredirected) run is untracked/git-ignored; not committed.
- Only `lib/ui/scrim.dart`, `lib/main.dart`, `test/contrast_test.dart` committed. Parallel-worker changes (`message_list.dart`, `message_time_test.dart`, `.flutter-plugins-dependencies`) left untouched.

## Risks
- `ReadabilityScrim.strength` is accepted but intentionally unused (fixed geometry per spec); no analyzer warning because it is a public field.
- Todo 8 will restructure the shell; this todo only adds the temporary Stack wrapper as specified.
