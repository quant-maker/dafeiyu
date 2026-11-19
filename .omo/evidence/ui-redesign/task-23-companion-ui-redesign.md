# Task 23 — Restyle the ComfyUI console

Date: 2026-11-19
Files changed: `lib/comfy/comfy_page.dart`, `test/comfy_layout_test.dart`

## What changed

- `Scaffold` now uses `AppPalette.ink`, a transparent `AppBar` with
  `scrolledUnderElevation: 0`, the `ComfyUI` title and a `GhostIconButton`
  (tooltip `刷新状态`) for refresh.
- Body is `ContentFrame(child: ListView(padding: EdgeInsets.fromLTRB(0, 12, 0, 40)))`.
- Status card is a COLUMN (no more squeezing Row): `StatusDot` + status text
  (`AppType.bodySmall`), then base URL (`AppType.caption`, `text3`), then an
  offline-only wrapping help line (`AppType.caption`, `warm`). This fixes the
  narrow-width overflow.
- Prompt/negative `TextField`s themed by `AppTheme.dark()`; `maxLines` 6 / 2,
  original `labelText`/`hintText` strings kept.
- Buttons: `PrimaryButton(label: '生成', loading: _busy, ...)` +
  `TextButton(child: Text('清队列'))`.
- Busy: `LinearProgressIndicator` + stage caption (`text2`).
- Errors: `InlineNotice(tone: NoticeTone.danger)`.
- Results: `LayoutBuilder` — >=600 px → 2-column `GridView.count` (shrinkWrap,
  NeverScrollableScrollPhysics, 12 px spacing, ratio 1); otherwise single column.
  Each image is `ClipRRect(AppRadii.l)` → `GestureDetector(_openFull)` →
  `Image.memory(fit: BoxFit.cover, semanticLabel: '生成结果')`.
- Protocol/logic preserved: `_generate`, `_refresh`, `_client`, `_parseWorkflow`,
  `_openFull`, `ComfyClient`, `patchWorkflow`, all status semantics and strings.

## Verification

### Bare-color grep (expected 0)

```
PS> Select-String -Path "lib/comfy/comfy_page.dart" -Pattern "0xFF0B1220|0xFF101A2C|0xFF16223A|0xFF6BD08B|0xFFFF9A9A|0xFFFF8A8A" | Measure-Object | Select-Object -ExpandProperty Count
0
```

### flutter analyze (last 20 lines)

```
Analyzing dafeiyu...
No issues found! (ran in 15.8s)
```

### flutter test (last 20 lines)

```
00:03 +21: .../test/footprints_test.dart: renders every footprint title and its mood pill
00:03 +22: .../test/footprints_test.dart: renders every footprint title and its mood pill
00:03 +23: .../test/footprints_test.dart: renders every footprint title and its mood pill
00:03 +24: .../test/footprints_test.dart: renders every footprint title and its mood pill
00:03 +25: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +26: .../test/message_list_test.dart: default top padding equals status bar plus app bar height
00:04 +27: .../test/message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:04 +28: .../test/motion_test.dart: newest bubble fades in and shows the streaming caret
00:04 +29: .../test/motion_test.dart: newest bubble fades in and shows the streaming caret
00:04 +30: .../test/motion_test.dart: newest bubble fades in and shows the streaming caret
00:04 +31: .../test/motion_test.dart: newest bubble fades in and shows the streaming caret
00:05 +32: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +33: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +34: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +35: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +36: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +37: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:05 +38: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:06 +39: .../test/settings_structure_test.dart: settings page renders seven stable section cards
00:06 +40: All tests passed!
```

### comfy_layout_test.dart

Pumps `MaterialApp(theme: AppTheme.dark(), home: ComfyPage(baseUrl: 'http://127.0.0.1:9', workflowJson: ''))`
at 320×640, then `pump(500ms)` so the fake test HttpClient resolves `_refresh`
offline. Asserts `tester.takeException()` is null. No `pumpAndSettle`.

## Cleanup

- Redirected `APPDATA` / `LOCALAPPDATA` / `TEMP` / `TMP` to `.tools-tmp/*` so
  the Dart analysis server could start (user profile `.dartServer` was not
  writable).
- Removed the stray `flutter_05.log` tool-crash report produced by the first
  analyze attempt.

## Live screenshots (2026-11-19)

Served the existing `build/web` (no rebuild) with `node server/server.mjs`
(port 8090), loaded `http://127.0.0.1:8090/?seed=1`, enabled Flutter web
semantics via the `flt-semantics-placeholder`, and activated the app-bar
control `画画（ComfyUI）` (2nd of four 36 px `GhostIconButton`s) through its
semantics node. The `ComfyUI` route rendered with the status card and
prompt/negative fields.

- `.omo/evidence/ui-redesign/task-23-companion-ui-redesign.png` — 320×640, 21102 bytes
- `.omo/evidence/ui-redesign/task-23-companion-ui-redesign-390.png` — 390×844, 23925 bytes

Measured (Playwright, devicePixelRatio ≈ 1):

| Viewport | outer | scrollWidth | clientWidth | scrollWidth <= clientWidth |
|---|---|---|---|---|
| 320×640 | 320×640 | 320 | 320 | true |
| 390×844 | 390×844 | 390 | 390 | true |

Snapshot at both widths (no horizontal overflow):

```
320: Back(8,8,40,40) / heading "ComfyUI"(72,17,69,23) / 刷新状态(282,9,38,38)
     status card(16,68,288,74) / textbox 提示词(16,158,293,103)
     textbox 反向提示词（可空）(16,268,293,77) / 生成 group / 清队列(236,362,68,36)
390: Back(8,8,40,40) / heading "ComfyUI"(72,17,69,23) / 刷新状态(352,9,38,38)
     status card(16,68,358,74) / textbox 提示词(16,158,363,103)
     textbox 反向提示词（可空）(16,268,363,77) / 生成 group / 清队列(306,362,68,36)
```

Console (final clean load → navigate → both screenshots): **0 errors,
0 warnings**; only one log line
`[feiyu] settings loaded base=https://api.deepseek.com/v1 model=deepseek-v4.1-flash keyLen=13`.

### Note on Comfy status

The page showed `已连接 · 队列 0` rather than the anticipated offline state,
because this machine has a real ComfyUI listening on `127.0.0.1:8188` and
`server/server.mjs` reverse-proxies `/comfy/*` to it
(`/comfy/system_stats` returns 200 with `comfyui_version 0.45.0`). So the
screenshot captures the genuine **connected** state; the offline-only help line
is not visible in this environment. No product behaviour was changed.

### Automation note

Synthetic `page.mouse.click(x,y)` on the CanvasKit canvas raised two
Flutter-web pointer-binding `TypeError`s (`Cannot read properties of null
(reading 'a'/'toString')`). These are an artifact of clicking the raw canvas
outside the semantics hit-test path and did not occur in the final flow, which
activated the button through its semantics node and produced zero console
errors.

Server stopped afterwards; port 8090 confirmed free
(`Get-NetTCPConnection -LocalPort 8090` → none).
