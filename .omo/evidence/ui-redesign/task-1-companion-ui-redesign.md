# Task 1 — Design tokens + AppTokens extension (evidence)

Date: 2026-11-19
Repo: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`
Plan: `.omo/plans/companion-ui-redesign.md` (Todo 1)

## Toolchain

`flutter` is **not on PATH**. The SDK at `..\tools\flutter` (3.35.1) is used directly.
The Flutter/Dart CLI cannot create telemetry/state files under the real `%APPDATA%`
(Windows access denied), so every command runs with `APPDATA`/`LOCALAPPDATA`/`HOME`/
`TEMP` pointed at `C:\Users\xqli\Documents\deepseek-harness\default-workspace\.tools-tmp\*`
and `FLUTTER_SUPPRESS_ANALYTICS=true`. This is environment-only; no repo file changed.

### `..\tools\flutter\bin\flutter.bat --version`

```
Flutter 3.35.1 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 20f8274939 (1 year, 3 months ago) • 2025-08-14 10:53:09 -0700
Engine • hash 6cd51c08a88e7bbe848a762c20ad3ecb8b063c0e (revision 1e9a811bf8) (14 months ago) • 2025-08-13 23:35:25.000Z
Tools • Dart 3.9.0 • DevTools 2.48.0
```

## Git status BEFORE any change

```
?? .omo/
```

After `flutter pub get` (generated changes, not authored by this task):

```
 M .flutter-plugins-dependencies
 M pubspec.lock
?? .omo/
```

## `flutter pub get --offline` (PUB_CACHE=..\tools\pub-cache)

```
Resolving dependencies...
Downloading packages...
+ archive 3.6.1
+ audioplayers 6.7.1
...
+ video_player 2.10.1
+ video_player_android 2.9.5
+ video_player_avfoundation 2.8.9
+ video_player_platform_interface 6.7.0
+ video_player_web 2.4.0
Changed 41 dependencies!
1 package has newer versions incompatible with dependency constraints.
```

`pubspec.lock` was stale (missing video_player/record/flutter_tts/path_provider/etc.)
and is now regenerated.

## `flutter test` (whole repo)

```
00:00 +0: loading C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/tokens_test.dart
00:00 +0: standard tokens expose canonical palette and bubble radius
00:00 +1: lerp blends a changed palette color
00:00 +2: All tests passed!

TEST_EXIT=0
```

## `flutter analyze` (whole repo) — raw last 30 lines

```
Analyzing dafeiyu...

   info - Use interpolation to compose strings and values - lib\main.dart:300:12 - prefer_interpolation_to_compose_strings
warning - The value of the field '_speech' isn't used - lib\main.dart:404:26 - unused_field
   info - Invalid regular expression syntax - lib\main.dart:1336:28 - valid_regexps
   info - Invalid regular expression syntax - lib\main.dart:1337:28 - valid_regexps
   info - Invalid regular expression syntax - lib\main.dart:1338:28 - valid_regexps
   info - Invalid regular expression syntax - lib\main.dart:1339:28 - valid_regexps
   info - Use interpolation to compose strings and values - lib\main.dart:1577:12 - prefer_interpolation_to_compose_strings
   info - Use interpolation to compose strings and values - lib\main.dart:1635:12 - prefer_interpolation_to_compose_strings
warning - The value of the field '_ttsProgress' isn't used - lib\main.dart:2219:10 - unused_field
warning - A value of type 'bool' can't be returned by the 'onError' handler because it must be assignable to 'FutureOr<Null>' - lib\main.dart:2259:33 - invalid_return_type_for_catch_error
   info - Unnecessary use of string interpolation - lib\voice\local_asr.dart:23:28 - unnecessary_string_interpolations
   info - Dangling library doc comment - lib\voice\local_asr_io.dart:1:1 - dangling_library_doc_comments
   info - Dangling library doc comment - lib\voice\local_tts_io.dart:1:1 - dangling_library_doc_comments
warning - The value of the field '_playing' isn't used - lib\voice\local_tts_io.dart:17:7 - unused_field

14 issues found. (ran in 15.6s)
ANALYZE_EXIT=1
```

**IMPORTANT:** all 14 issues are in `lib/main.dart` / `lib/voice/**`, which Todo 1
must NOT edit (theme registration is Todo 2). They are **pre-existing** and unrelated
to tokens.dart. Scoped analysis of this task's files is clean:

```
> flutter analyze lib/ui/tokens.dart
Analyzing tokens.dart...
No issues found! (ran in 10.0s)
ANALYZE_TOKENS_EXIT=0

> flutter analyze test/tokens_test.dart
Analyzing tokens_test.dart...
No issues found! (ran in 12.3s)
ANALYZE_TEST_EXIT=0
```

Passing variant with warning/info severity non-fatal (proves there are zero analyzer
**errors** anywhere in the repo):

```
> flutter analyze --no-fatal-infos --no-fatal-warnings
14 issues found. (ran in ...)
NO_FATAL_BOTH_EXIT=0
```

## Acceptance checks (8)

| # | Check | Result |
|---|---|---|
| 1 | `flutter --version` output recorded | PASS (see above) |
| 2 | `test/widget_test.dart` absent | PASS (`Test-Path` = False) |
| 3 | `flutter test` exit 0 with >=1 case | PASS (2 cases) |
| 4 | `flutter analyze` whole repo exit 0 | FAIL — 14 pre-existing issues in `lib/main.dart` / `lib/voice/**`, out of Todo-1 allowed scope; scoped `flutter analyze lib/ui/tokens.dart` exit 0 |
| 5 | tokens.dart contains `class AppTokens extends ThemeExtension<AppTokens>` | PASS (line 466) |
| 6 | tokens.dart contains `static AppTokens standard()`, `static AppTokens of(`, `AppTokens copyWith`, `AppTokens lerp` | PASS (lines 492, 494, 498, 517) |
| 7 | `grep -c "Color(0x" lib/ui/tokens.dart` >= 10 | PASS (26) |
| 8 | tokens.dart contains no `Widget`, `StatelessWidget`, `build(` | PASS (0 matches) |

## Grep / symbol evidence

```
---GREP Color---
26
---Symbols---
466: class AppTokens extends ThemeExtension<AppTokens> {
492: static AppTokens standard() => _standard;
494: static AppTokens of(BuildContext context) =>
498: AppTokens copyWith({
517: AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
---Forbidden---
(none)
---widget_test exists---
False
```

## Failure QA (test is not a rubber stamp)

Temporarily replaced the palette lerp field with `palette: palette` (returned the
left side instead of blending), ran `flutter test test/tokens_test.dart`:

```
00:00 +0: standard tokens expose canonical palette and bubble radius
00:00 +1: lerp blends a changed palette color
00:00 +1 -1: lerp blends a changed palette color [E]
  Expected: not Color:<Color(alpha: 1.0000, red: 0.4863, green: 0.7686, blue: 1.0000, colorSpace: ColorSpace.sRGB)>
    Actual: Color:<Color(alpha: 1.0000, red: 0.4863, green: 0.7686, blue: 1.0000, colorSpace: ColorSpace.sRGB)>

  test\tokens_test.dart 19:5  main.<fn>

00:00 +1 -1: Some tests failed.
EXIT=1
```

Restored `AppPalette.lerp(palette, other.palette, t)` and re-ran the full suite:
`+2: All tests passed!` (exit 0, recorded above).

## Files changed by this task

- `lib/ui/tokens.dart` (new)
- `test/tokens_test.dart` (new)
- `test/widget_test.dart` (deleted)
- `pubspec.lock` (regenerated by required `flutter pub get`)

Not committed (generated, outside the allowed commit list): `.flutter-plugins-dependencies`,
`.omo/**`.
