# Task 3 — ContentFrame (`lib/ui/layout.dart`)

Date: 2026-11-19
Scope: `lib/ui/layout.dart`, `test/layout_test.dart`

## Files

- `lib/ui/layout.dart` — `class ContentFrame extends StatelessWidget`, constructor:
  `ContentFrame({super.key, this.maxWidth = 720, this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.l), required this.child})`.
  Implementation: `LayoutBuilder` + horizontal side padding `(available - maxWidth) / 2`
  when `available > maxWidth` + `ConstrainedBox(maxWidth: maxWidth)` + inner `Padding`.
  No fixed heights, no clipping, no `OverflowBox`, no `MediaQuery.removePadding`.
- `test/layout_test.dart` — 3 widget tests.

`grep -n "class AppPage" lib/ui/layout.dart` → 0 matches (no `AppPage` created).

## Toolchain

`..\tools\flutter\bin\flutter.bat` (Flutter 3.35.1). The flutter tool could not use
`C:\Users\xqli\AppData\Local\Temp` (OS error 5 / access denied) and
`C:\Users\xqli\AppData\Roaming\.dart-tool` (access denied) in this environment, so
`APPDATA`, `LOCALAPPDATA`, `TEMP`/`TMP` were redirected to `$PWD\.tools-tmp\*`
(inside the workspace). Note: redirecting to the parent `..\.tools-tmp` also fails — the
sandbox only allows writes inside the project directory.

## Raw output — `flutter analyze` (last 20 lines)

```
Analyzing dafeiyu...
No issues found! (ran in 12.1s)
```

EXIT=0

## Raw output — `flutter test --no-pub` (last 20 lines)

```
00:00 +0: loading C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/avatar_mark_test.dart
00:00 +0: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/avatar_mark_test.dart: renders a square mark at the requested size
00:00 +1: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:00 +2: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:00 +3: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:00 +4: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:00 +5: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:00 +6: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:00 +7: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:00 +8: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:00 +9: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:00 +10: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:00 +11: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: gallery renders every component without exceptions
00:01 +12: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: InlineNotice dismiss control fires callback
00:01 +13: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:01 +14: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/surfaces_test.dart: Pill with success tone renders its label
00:01 +15: All tests passed!
```

(The suite also contains `avatar_mark_test.dart` / `surfaces_test.dart` from parallel Wave 1
work; all run green. Layout tests themselves: `flutter test --no-pub test/layout_test.dart`
→ `+3: All tests passed!`.)

## Measured widths

`tester.view.physicalSize`, `devicePixelRatio = 1`,
pump `MaterialApp(home: Scaffold(body: ContentFrame(child: SizedBox.expand(key: ...))))`.

| Viewport | Framed block (incl. 16px inner padding) | Content (child) width | Left content offset |
|---|---|---|---|
| 1280 × 800 | 720 (≤ 720) | 688 | 296 (280 outer margin + 16 inner padding) |
| 360 × 640 | 360 (full width) | 328 | 16 |

- Wide: side margin `(1280 - 720) / 2 = 280`, so the framed block is horizontally centred; right outer margin equals left (asserted by symmetry check).
- Narrow: 16px padding each side → `360 - 16 - 16 = 328`.
- `find.byType(OverflowBox)` → `findsNothing`; `tester.takeException()` → `null` in both viewports.
