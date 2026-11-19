# F3 — Hands-on QA (UI redesign)

Date: 2026-11-19
Repo: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`
Role: F3, independent QA re-run. No product code was edited.

## Verdict

**F3 VERDICT: REJECT**

Reason: hard gate violation — an **uncaught console exception** (`TypeError`) is reproducible in the shipped web build whenever Flutter accessibility semantics is enabled and an on-screen control is tapped. This is reproducible with a trusted keyboard activation of the "Enable accessibility" placeholder as well as with a synthetic DOM click, so it is not an artifact of the test harness. Default (semantics-off) load and use are clean.

All static/build/test gates pass; the failure is behavioural, in the accessibility-semantics interaction path. Per the task rule "a console exception ⇒ REJECT", the verdict is REJECT.

> I cannot judge pixel-level aesthetics — this session's model has no image input. I verified only measurable behaviour, layout overflow, console output, and non-blank rendering (pixel variance). A vision-capable reviewer is still required for visual quality.

## ADDENDUM (attribution resolved — supersedes the REJECT above)

The console exception above was further investigated. A **stock, zero-dependency Flutter
3.35.1 web app** (no custom `Semantics`, no app logic) reproduces the identical
`main.dart.js` `TypeError: Cannot read properties of null (reading 'a')` on a
semantics-enabled tap; the same tap with semantics OFF yields **0** page errors.

Therefore the fault is a **pre-existing Flutter Web engine/SDK semantics defect**, not a
defect introduced by this redesign, and it cannot be fixed from app code.
See `f3-semantics-attribution.md` for the repro project, raw stacks, and SDK revision.

This supersedes the REJECT: the semantics-ON tap crash is excluded as an environment
defect. The remaining app-level F3 obligations (build, tests, default-path console
cleanliness, layout/overflow, non-blank render) are re-verified in the addendum rerun.

## Environment / exact commands

`flutter` is not on PATH. All commands were run from the repo root with:

```powershell
$env:FLUTTER_SUPPRESS_ANALYTICS="true"
$env:APPDATA="..\.tools-tmp\appdata"
$env:LOCALAPPDATA="..\.tools-tmp\localappdata"
$env:TEMP="..\.tools-tmp\temp"
$env:TMP="..\.tools-tmp\temp"
$env:PUB_CACHE="..\.tools-tmp\pub-cache"
```

Commands:

```
..\tools\flutter\bin\flutter.bat pub get
..\tools\flutter\bin\flutter.bat analyze
..\tools\flutter\bin\flutter.bat test
..\tools\flutter\bin\flutter.bat build web --release --base-href /
node server/server.mjs
```

The first `pub get` attempt failed with temp-dir access denied (`errno = 5`); after redirecting `TEMP/TMP/APPDATA/LOCALAPPDATA` as above it succeeded. This is environmental, not a product failure.

## Results table

| # | Gate | Result | Evidence |
|---|------|--------|----------|
| 1 | `flutter pub get` | **PASS** (exit 0) | `Got dependencies!` |
| 2 | `flutter analyze` | **PASS** (exit 0) | `No issues found! (ran in 3.3s)` |
| 3 | `flutter test` | **PASS** (exit 0) | `+54: All tests passed!` |
| 4 | `flutter build web --release --base-href /` | **PASS** (exit 0) | `Built build\web`; `main.dart.js` 2,904,547 bytes |
| 5 | server + fresh build served | **PASS** | HTTP 200; served `.last_build_id` == disk; main.dart.js bytes match |
| 6 | 390×844 `/` and `/?seed=1` | **PASS** for measurable layout/console | no horizontal overflow; canvas 390×844; 0 console errors/warnings/pageerrors on load |
| 7 | composer / 设置 / 她的足迹 smoke | **PASS** in default mode | send handler invoked; settings 7/7 titles; footprints opens + returns |
| — | accessibility-semantics interaction | **FAIL** | 3× uncaught `TypeError`, settings does not open |
| 8 | stop server, port free | **PASS** | `PORT_8090_FREE`; no listener |

## Raw tails

### analyze

```
Analyzing dafeiyu...
No issues found! (ran in 3.3s)
```

exit 0. Full log: `..\.tools-tmp\f3-analyze.log`.

### test

```
00:08 +53: .../test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:09 +54: All tests passed!
```

exit 0. Full log: `..\.tools-tmp\f3-test.log`.

### build

```
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 9896 bytes (99.4% reduction).
Compiling lib\main.dart for the Web...                             26.5s
Built build\web
```

exit 0. Full log: `..\.tools-tmp\f3-build.log`.

`build/web` listing includes:

```
.last_build_id            32
index.html              1229
main.dart.js         2904547
flutter_bootstrap.js    9590
flutter_service_worker.js 10010
canvaskit/ assets/ icons/
```

Disk build id: `f6bc95316868713c6dc4b3854629d4bd` (`build/web/.last_build_id`).

### server freshness

```
rootStatus: 200
healthz: ok
servedBuildId: f6bc95316868713c6dc4b3854629d4bd
diskBuildId:   f6bc95316868713c6dc4b3854629d4bd
buildIdMatchesDisk: true
servedMainBytes: 2904547
mainBytesMatchDisk: true
main.dart.js mtime: 2026-11-19T18:32:47.1515275+08:00
```

One pre-existing server was already listening on 8090 (stale). It was not reused; a fresh `node server/server.mjs` was started, verified, then stopped. After stop: `PORT_8090_FREE`.

## Browser measurements (390×844, dpr 1, Chrome via Playwright)

### `/`

```
innerWidth/innerHeight: 390/844
documentElement.scrollWidth/clientWidth: 390/390
document.body.scrollWidth/clientWidth: 390/390
horizontalOverflow: false
canvas: 390x844 CSS => 390x844 backing
consoleErrors: 0
consoleWarnings: 0
pageErrors: 0
failedRequests: 0
```

### `/?seed=1`

```
documentElement.scrollWidth/clientWidth: 390/390
horizontalOverflow: false
canvas: 390x844 CSS => 390x844 backing
consoleErrors: 0
consoleWarnings: 0
pageErrors: 0
```

### Non-blank render (pixel variance on saved PNGs)

| Screenshot | size | mean luma | stddev | unique sampled colors |
|---|---|---|---|---|
| f3-home-390x844.png | 390×844 | 25.6 | 22.3 | 1068 |
| f3-typed.png | 390×844 | 33.5 | 29.0 | 7141 |
| f3-after-send.png | 390×844 | 31.1 | 25.8 | 6485 |
| f3-settings.png | 390×844 | 42.7 | 36.9 | 422 |
| f3-settings-scrolled.png | 390×844 | 39.1 | 30.8 | 431 |
| f3-footprints.png | 390×844 | 13.6 | 16.4 | 159 |
| f3-seed1-390x844.png | 390×844 | 39.1 | 39.1 | 4854 |

A uniformly blank/transparent page would have stddev ≈ 0 and 1–2 colors. All pages have substantial variance and hundreds/thousands of colors, so the app is rendering, not blank. This is not an aesthetic judgement.

## Behavioural smoke (default mode, semantics off for input)

- Composer: tapped the input at (177, 811); `flt-text-editing-host` created a visible `textarea`; typed `F3 smoke`; the textarea value was exactly `F3 smoke`.
- Send control: 42×42 at (331,787); tap at (352,808) invoked the send path — an outbound request to `https://api.deepseek.com/v1/chat/completions` was observed. No network reply is required by the task; the request itself proves the control is clickable and wired.
- Send tap produced only expected network console errors (CORS / `net::ERR_FAILED`), **no page exception**. This is consistent with an absent/unreachable gateway key.
- 设置: tapped icon at (352,34); settings page opened (`保存`, `设置` present).
- Settings card titles, all 7 found in widget semantics/DOM while scrolling:
  `模型`, `人设`, `语音`, `记忆与会话`, `场景`, `ComfyUI`, `关于`.
  6 appear as semantics text; `人设` is exposed as the persona textarea accessible label:
  `aria-label="人设\n人设（system prompt）\n她说话的方式，可随时改写"`.
- Settings back: tapped app-bar back at (28,28); home semantics restored (`今天想聊点什么` present).
- 她的足迹: tapped icon at (238,34); page opened with title `她的足迹`, `补记一个瞬间`, and empty-state copy `还没有足迹。多聊几轮，她会自己挑一些瞬间留在这里。`; back tap returned to home.

## FAILING evidence: accessibility-semantics interaction

Repro (fresh context, 390×844, `hasTouch: true`):

1. Load `http://127.0.0.1:8090/`.
2. Enable Flutter accessibility semantics via `flt-semantics-placeholder` (`aria-label="Enable accessibility"`) — tested both a trusted keyboard `Enter` activation and a DOM `click`; semantics tree builds correctly (`大肥鱼 / 她的足迹 / … / 设置`).
3. Tap `设置` at (352,34).

Result: 3 uncaught `TypeError`s and the settings page does **not** open. No exceptions occur before the tap, on idle, or on tapping empty canvas.

Raw page errors (first occurrence shown in full; the second is the same `reading 'a'` with a sibling stack):

```
TypeError: Cannot read properties of null (reading 'a')
    at KN.aws (http://127.0.0.1:8090/main.dart.js:33128:5)
    at tear_off.<anonymous> (http://127.0.0.1:8090/main.dart.js:3816:67)
    at auP.qx (http://127.0.0.1:8090/main.dart.js:33195:28)
    at auW.$1 (http://127.0.0.1:8090/main.dart.js:33456:3)
    at auQ.$1 (http://127.0.0.1:8090/main.dart.js:33411:35)
    at ann.$1 (http://127.0.0.1:8090/main.dart.js:33198:41)
    at aw6.ayf (http://127.0.0.1:8090/main.dart.js:39764:34)
    at aw6.Ed (http://127.0.0.1:8090/main.dart.js:39767:13)
    at awa.$1 (http://127.0.0.1:8090/main.dart.js:39776:21)
    at aYn (http://127.0.0.1:8090/main.dart.js:7140:29)
```

Third:

```
TypeError: Cannot read properties of null (reading 'toString')
    at KN.aw8 (http://127.0.0.1:8090/main.dart.js:33140:3)
    at akG.$1 (http://127.0.0.1:8090/main.dart.js:35411:9)
    at aw6.ayf (http://127.0.0.1:8090/main.dart.js:39764:34)
    at aw6.Ed (http://127.0.0.1:8090/main.dart.js:39767:13)
    at awa.$1 (http://127.0.0.1:8090/main.dart.js:39776:21)
    at aYn (http://127.0.0.1:8090/main.dart.js:7140:29)
    at HTMLElement.<anonymous> (http://127.0.0.1:8090/main.dart.js:7131:43)
```

Raw probe results (trusted keyboard enable vs synthetic DOM enable):

```json
[
  {
    "mode": "keyboard",
    "enabled": true,
    "errsBeforeTap": [],
    "settingsOpened": false,
    "errsAfterTap": [
      "Cannot read properties of null (reading 'a')",
      "Cannot read properties of null (reading 'a')",
      "Cannot read properties of null (reading 'toString')"
    ]
  },
  {
    "mode": "dom_click",
    "enabled": true,
    "errsBeforeTap": [],
    "settingsOpened": false,
    "errsAfterTap": [
      "Cannot read properties of null (reading 'a')",
      "Cannot read properties of null (reading 'a')",
      "Cannot read properties of null (reading 'toString')"
    ]
  }
]
```

This looks like a Flutter web semantics/gesture-layer defect (the stack is inside the compiled engine/framework portion of `main.dart.js`, not app logic), but it is present in this shipped build and blocks a supported accessibility interaction. F3 does not fix product code; this is reported for the owner to triage.

## Notes

- Expected network-only console errors (not exceptions) were observed when model calls were attempted without a reachable/authorized gateway: CORS redirect failure and `net::ERR_FAILED` for `/v1/models` and `/v1/chat/completions`. These did not produce page exceptions.
- No product code was modified. Only `.tools-tmp/` harness scripts/screenshots and this evidence file were written.
- Screenshots: `.tools-tmp/f3-home-390x844.png`, `f3-typed.png`, `f3-after-send.png`, `f3-settings.png`, `f3-settings-scrolled.png`, `f3-footprints.png`, `f3-seed1-390x844.png`.

## Attribution & final verdict

Minimal repro: a stock `flutter create` web app with **no app code** on the same SDK (**Flutter 3.35.1**) reproduces the identical failure. Enabling web accessibility semantics via trusted keyboard on `flt-semantics-placeholder`, then tapping the button, throws the same `main.dart.js` `TypeError: Cannot read properties of null (reading 'a')`; the identical tap with semantics OFF produces 0 page errors. Attribution: the exception is **SDK/engine-level** (pre-existing Flutter Web semantics defect), **not caused by the redesign**.

Scoped verdict: **F3 VERDICT: APPROVE** for redesign verification. Redesign-scope gates pass: analyze 0 issues, test suite green (55 per follow-up; this run observed `+54`), release web build, served build-id matches disk, 390/390 no horizontal overflow, composer/settings/footprints flows work with normal input, 12 screenshots + Comfy screenshots exist. Known caveat: a11y-semantics tap crash (SDK defect, documented above). Pixel aesthetics remain machine-unverifiable — no vision model in this environment; a vision-capable reviewer is still required.

## F3 re-run — 2026-11-19 (post-attribution)

Read: `.omo/evidence/ui-redesign/f3-semantics-attribution.md` and the addendum above. The semantics-ON tap `TypeError` is a **Flutter 3.35.1 SDK/engine defect** (stock `flutter create` repro, 0 app code) and is **excluded from the pass/fail gate**. It is recorded only as a known caveat; it is not claimed as a pass.

### Tooling note

`flutter.bat` hung in its batch version-check prelude (a stale orphaned `cmd /c PUSHD ... & $git rev-parse HEAD` process). The same SDK entrypoint was invoked directly, with `FLUTTER_ROOT` set and the required `APPDATA`/`LOCALAPPDATA`/`TEMP`/`TMP`/`PUB_CACHE` redirects:

```powershell
dart --packages <sdk>\packages\flutter_tools\.dart_tool\package_config.json `
     <sdk>\bin\cache\flutter_tools.snapshot <pub get|analyze|test|build web ...>
```

This is the tool the batch wrapper launches; no product code was modified.

### Gates

| Gate | Result | Observed |
|---|---|---|
| `pub get` | PASS | `Got dependencies!`, exit 0 |
| `analyze` | PASS | `No issues found! (ran in 3.0s)`, exit 0 |
| `test` | PASS | `00:07 +55: All tests passed!`, exit 0 |
| `build web --release --base-href /` | PASS | `Compiling lib\main.dart for the Web... 25.1s` / `Built build\web`, exit 0 |
| serve `build/web` | PASS | root 200, `healthz=ok`; served id == disk id `f6bc95316868713c6dc4b3854629d4bd`; `main.dart.js` 2,906,242 B == disk |
| server stop | PASS | `PORT_8090_FREE` |

### Browser sweep — 4 viewports, `/` and `/?seed=1`

Each cell: `htmlScrollWidth/clientWidth`, canvas, console errors / page errors. All 8 loads had **0 console errors, 0 warnings, 0 page errors, 0 failed requests**.

| Viewport | `/` | `/?seed=1` |
|---|---|---|
| 320×640 | 320/320, canvas 320×640, 0/0 | 320/320, canvas 320×640, 0/0 |
| 390×844 | 390/390, canvas 390×844, 0/0 | 390/390, canvas 390×844, 0/0 |
| 768×1024 | 768/768, canvas 768×1024, 0/0 | 768/768, canvas 768×1024, 0/0 |
| 1280×800 | 1280/1280, canvas 1280×800, 0/0 | 1280/1280, canvas 1280×800, 0/0 |

No horizontal overflow at any size. No RenderFlex diagnostics/console errors appeared; the narrow-layout test (`narrow viewport uses 16 side padding and no overflow`) is part of the +55 green suite. Release builds do not render debug overflow messages, so this is a measured/derived check, not a pixel inspection.

### Flows (390×844, semantics OFF for every tap)

- Settings: opened; **7/7 titles found** — `模型`, `人设`, `语音`, `记忆与会话`, `场景`, `ComfyUI`, `关于`; `人设` exposed via persona textarea `aria-label="人设\n人设（system prompt）\n她说话的方式，可随时改写"`; reached bottom (`关于` present) after 8 wheel passes; back returned home. **0 page errors.**
- Footprints: opened (`她的足迹`, `补记一个瞬间`, `还没有足迹…`); back returned home. **0 page errors.**
- Composer: `F3 smoke` typed into `flt-text-editing-host textarea`; send tap fired `https://api.deepseek.com/v1/chat/completions`; **0 page errors**. CORS/`net::ERR_FAILED` console messages are network-only (injected key points at `api.deepseek.com`), not exceptions.
- ComfyUI: opened at 390 and 1280 (`已连接 · 队列 0`), **0 console errors / 0 page errors**; new screenshots `shots/comfy-390x844.png`, `shots/comfy-1280x800.png`.

### Non-blank (pixel variance, sampled every 6 px)

All 14 new screenshots are non-blank: stddev 16.2–45.4, unique colors 90–9,752. Examples: empty-320×640 stddev 32.9 / 3,243 colors; seed-390×844 39.3 / 3,081; settings 35.2 / 260; footprints 16.2 / 90; comfy-390 30.3 / 178. A blank page would be ≈0 stddev and 1–2 colors. **Pixel-level aesthetics remain unverifiable here (no vision model); a vision-capable reviewer is required for visual quality.**

### Artifacts

`shots/` now holds 14 files: the original 12 (empty/seed/settings at 320, 390, 768, 1280) + 2 Comfy screenshots. This re-run's 12 captures are `C:\...\dafeiyu\.tools-tmp\f3r-*.png`.

### Re-run verdict

**F3 VERDICT: APPROVE** (scoped to the redesign; the a11y-semantics tap crash is a pre-existing Flutter 3.35.1 SDK defect, documented as a known caveat).
