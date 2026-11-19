# Task 28 — clear pre-existing analyzer debt

Plan: `.omo/plans/companion-ui-redesign.md` (Todo 28)
Date: 2026-11-19
Agent: sole implementer

## Goal

Make `flutter analyze` (whole repo) report `No issues found!` with exit 0, without changing behavior, without adding `// ignore:` comments, without touching files outside `lib/main.dart` + `lib/voice/*`.

## Toolchain / env

`flutter` not on PATH; used `..\tools\flutter\bin\flutter.bat` (Flutter 3.35.1, Dart 3.9.0).
`APPDATA` / `LOCALAPPDATA` / `TEMP` redirected to `..\.tools-tmp\*` because the analyzer could not create `%LOCALAPPDATA%\.dartServer` (access denied).
`FLUTTER_SUPPRESS_ANALYTICS=true`.

## Before (baseline, reproduced from Todo 1)

```
info    - Use interpolation to compose strings and values - lib\main.dart:300:12 - prefer_interpolation_to_compose_strings
warning - The value of the field '_speech' isn't used - lib\main.dart:404:26 - unused_field
info    - Invalid regular expression syntax - lib\main.dart:1336:28 - valid_regexps
info    - Invalid regular expression syntax - lib\main.dart:1337:28 - valid_regexps
info    - Invalid regular expression syntax - lib\main.dart:1338:28 - valid_regexps
info    - Invalid regular expression syntax - lib\main.dart:1339:28 - valid_regexps
info    - Use interpolation to compose strings and values - lib\main.dart:1577:12 - prefer_interpolation_to_compose_strings
info    - Use interpolation to compose strings and values - lib\main.dart:1635:12 - prefer_interpolation_to_compose_strings
warning - The value of the field '_ttsProgress' isn't used - lib\main.dart:2219:10 - unused_field
warning - A value of type 'bool' can't be returned by the 'onError' handler ... - lib\main.dart:2259:33 - invalid_return_type_for_catch_error
info    - Unnecessary use of string interpolation - lib\voice\local_asr.dart:23:28 - unnecessary_string_interpolations
info    - Dangling library doc comment - lib\voice\local_asr_io.dart:1:1 - dangling_library_doc_comments
info    - Dangling library doc comment - lib\voice\local_tts_io.dart:1:1 - dangling_library_doc_comments
warning - The value of the field '_playing' isn't used - lib\voice\local_tts_io.dart:17:7 - unused_field
flutter.bat : 14 issues found. (ran in 14.4s)
```

## Per-item before / after

### 1. `_speech` unused field (`lib/main.dart:404`)

- Verified references: `Select-String -Pattern "_speech" lib/main.dart` → **only** line 404 (the declaration). Zero reads anywhere in `lib/`.
- Voice recognition paths use `AudioRecorder _recorder` + `LocalAsrImpl`, not `stt.SpeechToText`; `_speech` was dead.
- After removing `_speech`, the only remaining use of the `speech_to_text` import was that field, so the now-unused import `import 'package:speech_to_text/speech_to_text.dart' as stt;` was also removed (otherwise it becomes a new `unused_import` info).
- Before: field `final stt.SpeechToText _speech = stt.SpeechToText();` + unused import.
- After: both deleted. Behavior unchanged (field was never read).

### 2. `_ttsProgress` unused field (`lib/main.dart:2219`)

- Verified references: declaration (2219), `_ttsProgress = 0` in `_downloadTts` (2350), `_ttsProgress = p` in the `onProgress` callback (2355). Zero reads.
- Removed the field, the `_ttsProgress = 0` assignment, and the `onProgress` callback (which existed only to write the unused field). `engine.download()` is still awaited with identical download behavior; only the (never-read) progress value was dropped.
- Note: **Todo 18 will re-add `_ttsProgress`** when it wires the TTS download progress bar, per plan.

### 3. `invalid_return_type_for_catch_error` (`lib/main.dart:2259`)

- Before: `.catchError((Object _) => false)`
- After: `.catchError((Object _) {})`
- Same "swallow the plugin error" semantics; the handler now returns `void`/`Null`, which is what `Future<...Null>` expects.

### 4. Four `valid_regexps` (`lib/main.dart:1336-1339`)

The raw patterns used Perl/PCRE-style inline flags `(?is)` / `(?s)`, which are **invalid in Dart's ECMAScript RegExp**. Verified with `dart` that the old patterns throw `FormatException: Invalid group` at construction — i.e. `_htmlToText` would have thrown on every call. The intent was case-insensitive + dotAll, which Dart expresses via constructor named args. Rewritten using `caseSensitive: false, dotAll: true` so they now actually match the intended inputs:

| # | before (invalid) | intent | after |
|---|---|---|---|
| 1 | `RegExp(r'(?is)<script.*?</script>')` | case-insensitive + dotAll `<script>…</script>` | `RegExp(r'<script.*?</script>', caseSensitive: false, dotAll: true)` |
| 2 | `RegExp(r'(?is)<style.*?</style>')` | case-insensitive + dotAll `<style>…</style>` | `RegExp(r'<style.*?</style>', caseSensitive: false, dotAll: true)` |
| 3 | `RegExp(r'(?is)<head.*?</head>')` | case-insensitive + dotAll `<head>…</head>` | `RegExp(r'<head.*?</head>', caseSensitive: false, dotAll: true)` |
| 4 | `RegExp(r'(?s)<[^>]+>')` | dotAll `<…>` any tag | `RegExp(r'<[^>]+>', dotAll: true)` |

- before: throws `FormatException` (invalid group) — i.e. matches nothing / crashes.
- after: matches the same inputs the flags intended. Verified with `dart`:
  - `script`: `<SCRIPT>a\nb</SCRIPT>` → true, `<script>alert(1)</script>` → true
  - `style`: `<STYLE>x</STYLE>` → true
  - `head`: `<HEAD>\n<title>t</title>\n</HEAD>` → true
  - tags: `<a\nhref=x>` → true, `<b>` → true, `plain` → false
- Not dead code: `_htmlToText` is used by the URL-reading path; fixing the regexes restores its intended (previously crashing) behavior — these lines do not alter the matching *intent*, only correct the invalid syntax.

### 5. `prefer_interpolation_to_compose_strings` (`300 / 1577 / 1635`)

Byte-identical output, converted from `'prefix\n' + <expr>.join(...)` to `'prefix\n${<expr>.join(...)}'`:

- 300: `'…不要逐条复述）：\n' + facts.map((f) => '- $f').join('\n')` → `'…不要逐条复述）：\n${facts.map((f) => '- $f').join('\n')}'`
- 1577: `'今天早些时候的摘要：\n' + pick.map((e) => '- ${e.text}').join('\n')` → `'今天早些时候的摘要：\n${pick.map((e) => '- ${e.text}').join('\n')}'`
- 1635: `'找到这些旧记录：\n' + hits.map((e) => '【${e.day}】${e.text}').join('\n\n')` → `'找到这些旧记录：\n${hits.map((e) => '【${e.day}】${e.text}').join('\n\n')}'`

### 6. `lib/voice/*`

- `local_asr.dart:23` unnecessary interpolation: `Directory('${Platform.environment['HOME'] ?? '.'}')` → `Directory(Platform.environment['HOME'] ?? '.')` (same string).
- `local_asr_io.dart:1` dangling `///` → `//`.
- `local_tts_io.dart:1` dangling `///` → `//`.
- `local_tts_io.dart:17` `_playing`: verified only the declaration (17) and one write `_playing++;` (123), zero reads → removed both the field and the increment. No read ever used it; playback behavior unchanged.

## After — raw command outputs

### `flutter analyze` (last 25 lines)

```
Analyzing dafeiyu...
No issues found! (ran in 12.9s)
EXIT=0
```

### `flutter test` (last 25 lines)

```
00:00 +0: loading C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/tokens_test.dart
00:00 +0: standard tokens expose canonical palette and bubble radius
00:00 +1: lerp blends a changed palette color
00:00 +2: All tests passed!
EXIT=0
```

### `git diff --stat`

```
 .flutter-plugins-dependencies |  2 +-
 lib/main.dart                 | 24 +++++++++---------------
 lib/voice/local_asr.dart      |  2 +-
 lib/voice/local_asr_io.dart   |  2 +-
 lib/voice/local_tts_io.dart   |  4 +---
 5 files changed, 13 insertions(+), 21 deletions(-)
```

(`.flutter-plugins-dependencies` was already modified before this task began — `git status` at start showed ` M .flutter-plugins-dependencies`; it is **not** committed here.)

## Guard checks

- No `// ignore:` / `// ignore_for_file:` added: `git diff | Select-String "// ignore"` → no matches.
- Files changed by this task: exactly `lib/main.dart`, `lib/voice/local_asr.dart`, `lib/voice/local_asr_io.dart`, `lib/voice/local_tts_io.dart`.
- Untouched: `lib/ui/**`, `test/**`, `pubspec.yaml`, `.omo/plans/**`.
- No behavior change: only dead fields/import, invalid-regex syntax (restored to intended match), interpolation formatting, doc-comment marker, and a swallowed-error handler return type.
