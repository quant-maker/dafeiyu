# Task 18 — Settings · persona + voice card restyle

## What changed

`lib/main.dart`, settings "人设" and "语音" cards only (presentation).

### 人设
- `TextField(minLines: 5, maxLines: 12)` wrapped in `SettingsRow(label: '人设（system prompt）', description: '她说话的方式，可随时改写')`.

### 语音 (single card, three `SectionHeader`s preserved)
- `语音朗读`: `SwitchListTile` → `_SettingsSwitch` (a `Row` of `Expanded(Column(AppType.bodySmall/text1 title, AppType.caption/text3 subtitle))` + `Switch`).
  - Engine `DropdownButtonFormField<String>` in `SettingsRow(label: '发音引擎')`.
  - When `_ttsEngine == 'local'`: voice `DropdownButtonFormField<int>` in `SettingsRow(label: '音色')` (reads `LocalTtsImpl.voices` unchanged), speed `Slider` with right-side `AppType.caption` value, `TextButton.icon` download button.
  - Re-added `double _ttsProgress = 0;`; download callback now `engine.download(onProgress: (p) { if (mounted) setState(() => _ttsProgress = p); })`, and when `_downloadingTts` a `LinearProgressIndicator(value: _ttsProgress)` + `%` text renders. Old download logic otherwise identical.
- `语音识别`: preset dropdown in `SettingsRow(label: '语音识别服务', description: '录音后上传这里转文字，不用手机自带识别')`; `local` shows `SettingsRow(label: '离线模型')` (reads `LocalAsrImpl.models` unchanged); non-`same`/non-`local` shows `Base URL` + `API Key` rows; transcript model row.
- `看图模型`: `_SettingsSwitch` + provider/base/key/model rows when enabled.
- Field names, controllers, `_save` payload, `LocalTtsImpl.voices` / `LocalAsrImpl.models` reads, `_testComfy` untouched.

## Commands

```powershell
$env:APPDATA / LOCALAPPDATA / TEMP / TMP -> ..\.tools-tmp\*
$env:FLUTTER_SUPPRESS_ANALYTICS=true
..\tools\flutter\bin\flutter.bat analyze
..\tools\flutter\bin\flutter.bat test
```

```
Analyzing dafeiyu...
No issues found! (ran in 2.4s)

00:05 +40: .../test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:05 +41: .../test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:06 +42: All tests passed!
```

## Diff guard (`git diff -U0 lib/main.dart` since commit 1)

- `_loadModels` / `_save`: no hunk touches either function body.
- `providerById`: only a call site (`final p = providerById(id)`) is reindented inside `SettingsRow`.
- `_downloadTts`: the only edit is the progress hook required by this todo —
  `await engine.download()` → `await engine.download(onProgress: (p) { if (mounted) setState(() => _ttsProgress = p); })`
  plus `_ttsProgress = 0` in the existing start `setState`. Download/save/ready/error flow is otherwise byte-identical.

```
-                    final p = providerById(id);
+                      final p = providerById(id);
```

## Test

`test/settings_voice_test.dart`: TTS off initially → `find.text('发音引擎')` findsNothing; tap `find.byType(Switch).first` → engine row findsOneWidget; open engine dropdown and choose 本机 Kokoro → `音色` row and `Icons.download_outlined` download button appear. Does not assert `_ttsModelReady`.
