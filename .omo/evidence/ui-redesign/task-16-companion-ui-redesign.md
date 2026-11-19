# Task 16 — Settings page shell: AppBar, section cards, scroll layout

Commit message: `refactor(settings): group settings into section cards`

## Scope

- `lib/main.dart`: rebuilt `_SettingsPageState.build` into a seven-card `ListView` using `SectionCard` / `SectionHeader` from `lib/ui/surfaces.dart`.
- `test/settings_structure_test.dart`: new hermetic widget test asserting each of the 7 stable section keys appears exactly once.
- No control restyling; `_save`, controllers, `onChanged` logic, state fields, persistence, networking, voice and memory logic untouched.
- Deleted exactly one colliding field label: `const _Label('模型')` (model dropdown label). `_Label` class and all other labels remain.

## Card order / keys

1. `ValueKey('settings-section-model')` — `模型`: provider dropdown, Base URL, API Key, model dropdown + count/error, manual model field.
2. `ValueKey('settings-section-persona')` — `人设`: persona TextField.
3. `ValueKey('settings-section-voice')` — `语音`: `SectionHeader` `语音朗读` / `语音识别` / `看图模型`.
4. `ValueKey('settings-section-memory')` — `记忆与会话`: memory switch, memory facts list, proactive switch + idle slider.
5. `ValueKey('settings-section-scene')` — `场景`: scene switch, room dropdown (FutureBuilder), dim slider.
6. `ValueKey('settings-section-comfy')` — `ComfyUI`: url, test button, status, 3 workflows + example buttons.
7. `ValueKey('settings-section-about')` — `关于`: build self-check container + privacy text.

Spacing: `SizedBox(height: 14)` between children inside a card; `SizedBox(height: 16)` between cards.
Scaffold: `backgroundColor: AppPalette.ink`, AppBar title `设置`, right-padded `FilledButton('保存') -> _save`, body `ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 40))`.

## Verification greps

`SectionCard(` count:

```
7
```

`const _Label('模型')` lines (must be 0):

```
0
```

`const _Label` occurrences (class + other labels remain, must be > 0):

```
10
```

Note: `rg` is unavailable on this host; the equivalent counts were produced with
`Select-String -AllMatches`. `class _Label extends` remained at 1 occurrence.

`_save` untouched: it lives at `lib/main.dart:2082` and the earliest diff hunk for
`lib/main.dart` starts at old line 2119, i.e. after `_save`. All hunks stay inside the
rebuilt `build` method.

## Commands and results

Toolchain: `..\tools\flutter\bin\flutter.bat`, `FLUTTER_SUPPRESS_ANALYTICS=true`,
redirected `APPDATA`/`LOCALAPPDATA`/`TEMP`/`TMP` to `..\.tools-tmp\*`
(`TMP` is required: `flutter test` needs a writable `Directory.systemTemp`).

### `flutter analyze` (last lines)

```
Analyzing dafeiyu...
No issues found! (ran in 2.3s)
```

Raw log: `..\.tools-tmp\analyze-16.log`

### `flutter test` (last 20 lines)

```
00:03 +21: .../test/footprints_test.dart: renders every footprint title and its mood pill
00:03 +22: .../test/footprints_test.dart: renders every footprint title and its mood pill
00:03 +23: .../test/footprints_test.dart: renders every footprint title and its mood pill
00:03 +24: .../test/footprints_test.dart: renders every footprint title and its mood pill
00:03 +25: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +26: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:04 +27: .../test/message_time_test.dart: time header shows at index 0 after a 5 minute gap
00:04 +28: .../test/motion_test.dart: newest bubble fades in and shows the streaming caret
00:04 +29: .../test/motion_test.dart: newest bubble fades in and shows the streaming caret
00:04 +30: .../test/motion_test.dart: newest bubble fades in and shows the streaming caret
00:04 +31: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:04 +32: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:04 +33: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:04 +34: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +35: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +36: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +37: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +38: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +39: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +40: All tests passed!
```

Raw log: `..\.tools-tmp\test-16.log`

### New test

`test/settings_structure_test.dart` pumps
`MaterialApp(theme: AppTheme.dark(), home: SettingsPage(initial: Settings(baseUrl: 'https://x/v1', apiKey: '', model: 'm', persona: 'p'), memory: Memory()))`
on an enlarged logical surface (1200x8000) so all lazy `ListView` children build, then
asserts `find.byKey(ValueKey(...))` finds exactly one widget for each of the 7 keys.
It uses `pump(Duration(milliseconds: 100))` instead of `pumpAndSettle` because
`initState` may leave an indefinitely animating widget on-screen.

## Risks / notes

- The `build` body was re-indented while wrapping existing widgets into cards; the diff is
  larger than the pure structural change, but no widget behavior, controller, or callback
  was altered.
- The scene dim slider is still rendered unconditionally (its original behavior). Todo 19
  owns the conditional-visibility restyle.
- Card internal spacing was normalized from the previous ad-hoc 16/20/12 gaps to the
  required `SizedBox(height: 14)`; intra-group `SizedBox(height: 8)` and the memory-list
  `SizedBox(height: 6)` were preserved.
