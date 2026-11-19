# Task 27 — Complete and run the full UI test suite

Date: 2026-11-19
Repo: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`
Toolchain: `..\tools\flutter\bin\flutter.bat` (FLUTTER_SUPPRESS_ANALYTICS=true, APPDATA/LOCALAPPDATA/TEMP/TMP redirected to `.tools-tmp`)

## 1. Test file inventory (plan Todo 27 list)

All 26 required files exist; `test/widget_test.dart` is absent.

```
tokens_test.dart              exists=True
theme_test.dart               exists=True
layout_test.dart              exists=True
avatar_mark_test.dart         exists=True
surfaces_test.dart            exists=True
contrast_test.dart            exists=True
chat_app_bar_test.dart        exists=True
bubble_test.dart              exists=True
message_list_test.dart        exists=True
message_time_test.dart        exists=True
empty_state_test.dart         exists=True
error_notice_test.dart        exists=True
composer_test.dart            exists=True
attachments_test.dart         exists=True
motion_test.dart              exists=True
settings_structure_test.dart  exists=True
settings_model_test.dart      exists=True
settings_voice_test.dart      exists=True
settings_scene_test.dart      exists=True
settings_comfy_test.dart      exists=True
settings_about_test.dart      exists=True
footprints_test.dart          exists=True
overlays_test.dart            exists=True
comfy_layout_test.dart        exists=True
a11y_test.dart                exists=True
text_scale_test.dart          exists=True
```

`Test-Path test\widget_test.dart` -> `False`

Declared test-case count (`Select-String "^\s*test(Widgets)?\("` across `test/*.dart`):

```
a11y_test.dart                 5
attachments_test.dart          2
avatar_mark_test.dart          3
bubble_test.dart               4
chat_app_bar_test.dart         3
comfy_layout_test.dart         1
composer_test.dart             2
contrast_test.dart             4
empty_state_test.dart          1
error_notice_test.dart         1
footprints_test.dart           2
layout_test.dart               3
message_list_test.dart         1
message_time_test.dart         1
motion_test.dart               2
overlays_test.dart             1
settings_about_test.dart       1
settings_comfy_test.dart       1
settings_model_test.dart       1
settings_scene_test.dart       1
settings_structure_test.dart   1
settings_voice_test.dart       1
surfaces_test.dart             4
text_scale_test.dart           3
theme_test.dart                3
tokens_test.dart               2
TOTAL = 54 declared test cases (>= 25 required)
```

## 2. `flutter analyze`

```
Analyzing dafeiyu...
No issues found! (ran in 1.2s)

EXITCODE=0
```

## 3. `flutter test` (full suite)

Raw summary line:

```
00:06 +54: All tests passed!
```

EXITCODE=0

Last 20 lines (raw):

```
00:04 +35: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/overlays_test.dart: showImageViewer opens a dialog with a 44px close button
00:04 +36: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_about_test.dart: about card shows the self-check block and privacy copy
00:05 +37: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_comfy_test.dart: comfy card shows connection button and workflow fields
00:05 +38: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:05 +39: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:05 +40: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:05 +41: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:05 +42: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:05 +43: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:06 +44: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:06 +45: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:06 +46: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:06 +47: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:06 +48: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:06 +49: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:06 +50: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:06 +51: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:06 +52: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:06 +53: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:06 +54: All tests passed!
```

Note: fast test files (tokens/theme/surfaces/contrast/text_scale) print progress lines that the runner overwrites via carriage returns, so they are not all visible as separate lines in the captured log. They were additionally run explicitly, all green:

```
flutter test test/tokens_test.dart test/theme_test.dart test/surfaces_test.dart test/contrast_test.dart test/text_scale_test.dart
...
00:01 +16: All tests passed!
EXITCODE=0
```

## 4. Scoped bare-hex scan

Command (grep equivalent via `Select-String`; `grep`/`rg` unavailable on this PowerShell host):

```
$files = Get-ChildItem lib\ui -Recurse -Filter *.dart -File
$files += Get-Item lib\main.dart, lib\feeds\footprints_page.dart, lib\comfy\comfy_page.dart
$files | Select-String -Pattern 'Color\(0x'
```

Hits (file:line). ALL hits are in `lib/ui/tokens.dart` (the single allowed file):

```
lib/ui/tokens.dart:52:  static const Color ink = Color(0xFF060A13);
lib/ui/tokens.dart:53:  static const Color surface = Color(0xFF0D1524);
lib/ui/tokens.dart:54:  static const Color surfaceAlt = Color(0xFF131F33);
lib/ui/tokens.dart:55:  static const Color surfaceHi = Color(0xFF1A2740);
lib/ui/tokens.dart:56:  static const Color primary = Color(0xFF7CC4FF);
lib/ui/tokens.dart:57:  static const Color primaryDeep = Color(0xFF2F6FD0);
lib/ui/tokens.dart:58:  static const Color primaryInk = Color(0xFF04101F);
lib/ui/tokens.dart:59:  static const Color warm = Color(0xFFFFB27A);
lib/ui/tokens.dart:60:  static const Color warmDeep = Color(0xFFE07A4A);
lib/ui/tokens.dart:61:  static const Color mint = Color(0xFF6BD08B);
lib/ui/tokens.dart:62:  static const Color danger = Color(0xFFFF8A8A);
lib/ui/tokens.dart:63:  static const Color text1 = Color(0xFFEEF4FF);
lib/ui/tokens.dart:64:  static const Color text2 = Color(0x9EFFFFFF);
lib/ui/tokens.dart:65:  static const Color text3 = Color(0x80FFFFFF);
lib/ui/tokens.dart:66:  static const Color text4 = Color(0x42FFFFFF);
lib/ui/tokens.dart:67:  static const Color line = Color(0x14FFFFFF);
lib/ui/tokens.dart:68:  static const Color lineStrong = Color(0x24FFFFFF);
lib/ui/tokens.dart:69:  static const Color bubbleSurface = Color(0xFF141F31);
lib/ui/tokens.dart:70:  static const Color bubbleMine = Color(0xFF152A45);
lib/ui/tokens.dart:71:  static const Color composerSurface = Color(0xE60B1424);
lib/ui/tokens.dart:333:  colors: [Color(0xFF5AB0FF), Color(0xFF2F6FD0)],
lib/ui/tokens.dart:336:  colors: [Color(0xFF8FD0FF), Color(0xFF2F6FD0)],
lib/ui/tokens.dart:341:  colors: [Color(0xB8060A13), Color(0x00060A13)],
lib/ui/tokens.dart:346:  colors: [Color(0x00060A13), Color(0xC7060A13)],
lib/ui/tokens.dart:380:  BoxShadow(color: Color(0x47000000), blurRadius: 18, offset: Offset(0, 6)),
lib/ui/tokens.dart:383:  BoxShadow(color: Color(0x3D7CC4FF), blurRadius: 16),
```

Result: PASS — no hits outside `lib/ui/tokens.dart`. `lib/scene/scene_stage.dart` is whitelisted and not in scope.

## 5. Emoji audit (widget-avatar 🐟)

Command (scanned `lib/ui/**`, `lib/main.dart`, `lib/feeds/footprints_page.dart`):

```
$files = Get-ChildItem lib\ui -Recurse -Filter *.dart -File
$files += Get-Item lib\main.dart, lib\feeds\footprints_page.dart
$files | Select-String -Pattern '🐟'
```

Hits:

```
lib/main.dart:1241:  mood: (args['mood'] ?? '🐟').toString(),
lib/main.dart:1781:  mood: (map['mood'] ?? '🐟').toString(),
```

(console rendered the emoji as `??`; file content confirmed via Read to be `'🐟'`.)

Both are the whitelisted persisted `mood` fallbacks in `lib/main.dart` (plan whitelist `lib/main.dart:1181`/`:1720` before line shifts). No widget-avatar usage remains:
- `lib/ui/**` -> 0 hits
- `lib/feeds/footprints_page.dart` -> 0 hits
- `lib/feeds/footprints.dart` data defaults -> untouched (whitelisted)

Result: PASS.

## 6. `MyApp` references

```
Get-ChildItem -Path test,lib -Recurse -Include *.dart -File | Select-String -Pattern 'MyApp'
(none)
```

Result: PASS (0 matches).

## Outcome

- `flutter analyze`: `No issues found!`, exit 0
- `flutter test`: `+54: All tests passed!`, exit 0, 54 test cases (>= 25), all 26 required files present
- `test/widget_test.dart`: absent
- `MyApp` references in test/lib: 0
- Bare-hex scan: only `lib/ui/tokens.dart`
- Emoji audit: only whitelisted mood fallbacks remain
- No product behavior changed; no test weakened.
