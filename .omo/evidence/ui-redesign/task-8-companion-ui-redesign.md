# Task 8 — Reassemble chat shell (`_ChatPageState.build`)

Plan: `.omo/plans/companion-ui-redesign.md` (Todo 8, lines 251-259)
Scope: `lib/main.dart` only.

## Change

`_ChatPageState.build` now returns:

- `SceneStage(enabled: _settings?.sceneEnabled ?? true, dim: _settings?.sceneDim ?? .42, image: _settings?.sceneImage ?? '', mood: _mood, child: ...)` — all four params retained.
- `Scaffold(backgroundColor: Colors.transparent, extendBodyBehindAppBar: true, appBar: ChatAppBar(...), body: Stack(...))`.
- Body `Stack`: `Positioned.fill(child: ReadabilityScrim())` + `ContentFrame(padding: EdgeInsets.zero, child: Column(...))`.
- Column child order and conditions unchanged: error bar → Expanded(messages/empty) → pending image bar → listening bar → composer.
- No `SafeArea` added around the Column; `_composer` keeps its own.
- Added `import 'ui/layout.dart';` for `ContentFrame`.

Todo 6's temporary `Column`-in-`Stack` wrapper was replaced by the final shell (single scrim, single frame).

## Toolchain

SDK: `..\tools\flutter\bin\flutter.bat` (Flutter 3.35.1 / Dart 3.9.0)
Env: `FLUTTER_SUPPRESS_ANALYTICS=true`, `APPDATA`/`LOCALAPPDATA`/`TEMP`/`TMP` redirected to `..\.tools-tmp\*` (host temp is access-denied to Dart's `createTempSync`).

## `flutter analyze` (last 20 lines)

```
Analyzing dafeiyu...
No issues found! (ran in 1.3s)
EXIT=0
```

## `flutter test --no-pub` (last 20 lines)

```
00:01 +9: .../test/chat_app_bar_test.dart: renders all four action tooltips and the avatar mark
00:01 +10: .../test/chat_app_bar_test.dart: renders all four action tooltips and the avatar mark
00:01 +11: .../test/contrast_test.dart: ReadabilityScrim paints two fixed-alpha gradients
00:01 +12: .../test/contrast_test.dart: ReadabilityScrim paints two fixed-alpha gradients
00:01 +13: .../test/contrast_test.dart: ReadabilityScrim paints two fixed-alpha gradients
00:01 +14: .../test/layout_test.dart: wide viewport keeps the framed block within 720 and centred
00:01 +15: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:01 +16: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:01 +17: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +18: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +19: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +20: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +21: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +22: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:02 +23: .../test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:02 +24: .../test/surfaces_test.dart: gallery renders every component without exceptions
00:02 +25: .../test/surfaces_test.dart: InlineNotice dismiss control fires callback
00:02 +26: .../test/surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:02 +27: .../test/surfaces_test.dart: Pill with success tone renders its label
00:02 +28: All tests passed!
EXIT=0
```

## Grep acceptance values (`lib/main.dart`, `Select-String -SimpleMatch`)

| check | expected | actual |
|---|---|---|
| `ReadabilityScrim` | 1 | 1 |
| `ContentFrame(` | 1 | 1 |
| `SceneStage(` | 1 | 1 |
| call contains `mood: _mood` | yes | yes (SceneStage call line 1735) |
| `extendBodyBehindAppBar` | 1 | 1 (line 1739) |
| `SafeArea(` | 2 | 2 (`_imageSheet` + `_composer`) |

Raw:

```
ReadabilityScrim=1
ContentFrame(=1
SceneStage(=1
mood: _mood occurrences=2
extendBodyBehindAppBar:
  line 1739: extendBodyBehindAppBar: true,
SafeArea(=2
```

Note: `mood: _mood` appears twice because both `SceneStage` and `ChatAppBar` receive it; `SceneStage(` itself is unique.

## Cleanup

- Removed crash artifact `flutter_05.log` produced by an analyze attempt without redirected `LOCALAPPDATA`.
- `flutter pub get` refreshed `.flutter-plugins-dependencies` only; not staged/committed.
