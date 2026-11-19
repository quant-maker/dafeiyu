# Task 19 — memory / proactive / scene sections

## Commands

### flutter analyze
```
Analyzing dafeiyu...
No issues found! (ran in 2.3s)
```

### flutter test test/settings_scene_test.dart
```
00:00 +0: loading .../test/settings_scene_test.dart
00:00 +0: scene dropdown and dim slider hide when disabled
00:01 +1: All tests passed!
```

### flutter test (full)
```
00:07 +43: All tests passed!
```

## Notes
- Memory switch row now uses `_SettingsSwitch` (Expanded Column + Switch).
- Fact list uses a 6px `AppPalette.primary` dot instead of the `· ` prefix.
- Scene dim slider moved inside the `_sceneEnabled` branch so both dropdown and slider hide when the scene is disabled.
- `_sceneChoices` / `_sceneLabel` untouched.
