# Task 20 — ComfyUI section

## Commands

### flutter analyze
```
Analyzing dafeiyu...
No issues found! (ran in 2.4s)
```

### flutter test test/settings_comfy_test.dart
```
00:00 +0: loading .../test/settings_comfy_test.dart
00:00 +0: comfy card shows connection button and workflow fields
00:01 +1: All tests passed!
```

### flutter test (full)
```
00:08 +44: All tests passed!
```

## Notes
- URL field keeps its helperText; wrapped in `SettingsRow`.
- `测试连接` remains a `TextButton.icon` with `Icons.wifi_tethering`.
- Status renders through `InlineNotice` with info/danger/success based on `_comfyTesting` and `连不上`.
- Three workflow fields keep the same labels, hints and helperText; both `填入示例` buttons preserved.
- `_testComfy`, `kComfySdTurboWorkflow`, `kComfyImg2ImgWorkflow` untouched (verified via `git diff`).
- Removed the now-unused `_Label` helper (its last users were the Comfy labels).
