# Todo 26 · Responsive & real screenshot QA (320 / 390 / 768 / 1280)

## What was added (debug-only preview branch)

`lib/main.dart`:

- Top-level `final List<Message> kPreviewMessages` — 6 mixed zh/en messages, each with an explicit
  `at:` timestamp, one carrying a 1×1 transparent PNG in `imageBase64`. Not `const` (`Message` has
  no const constructor and `content` is mutable).
- `_ChatPageState._preview` set at the START of `initState`:
  `_preview = kIsWeb && Uri.base.queryParameters['seed'] == '1';`
- Inside `ChatStore.load().then(...)`, first branch:
  `if (_preview) { setState(() => _messages = List.of(kPreviewMessages)); _scrollToEnd(animate: false); return; }`
  → saved history is never applied, `ChatStore.save` is never reached on that path.
- `_resetIdleTimer()` returns early when `_preview`, so no proactive idle timer is scheduled.
- Comment `// debug-only preview, never persisted` marks the branch.
- `_messages` changed from `final List<Message> _messages = []` to `List<Message> _messages = []`
  to allow the seed assignment; the no-parameter startup path is unchanged.

The preview only activates with `?seed=1` on web. `/` still loads saved history exactly as before.

## Build / analyze / test

`flutter pub get` → exit 0 (`Got dependencies!`).

`flutter analyze` (tail):

```
Analyzing dafeiyu...
No issues found! (ran in 2.8s)
```

`flutter test` (tail, 54 tests):

```
00:08 +52: .../test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:08 +53: .../test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:09 +54: All tests passed!
```

`flutter build web --release --base-href /` (exit 0, tail):

```
Compiling lib\main.dart for the Web...
Font asset "CupertinoIcons.ttf" was tree-shaken, reducing it from 257628 to 1472 bytes (99.4% reduction).
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 9896 bytes (99.4% reduction).
Compiling lib\main.dart for the Web...                             33.4s
✓ Built build\web
```

Built in THIS repo root (never `tools/build-web.ps1`, which builds the sibling `feiyu_app`).

## Serving

`node server/server.mjs` on port 8090 serving `build/web`.

Note: port 8090 was already occupied by a stale server (PID 32808) serving a DIFFERENT build
(`.last_build_id` mismatch). It was stopped and our server (PID 26720) was started; the served
`.last_build_id` then matched `build/web/.last_build_id` (`f6bc95316868713c6dc4b3854629d4bd`).
This is why an early probe rendered the empty state for `?seed=1` — it was not our build.

Server is stopped after capture (see cleanup).

## Method

Real Chromium via the `/playwright` skill (Playwright MCP), viewport set with
`page.setViewportSize({width, height})`. Flutter CanvasKit draws text into a `<canvas>`, so
measurements come from the Flutter semantics DOM exposed by the browser:

- Enable semantics via `flt-semantics-placeholder` (programmatic click).
- Content width = `getBoundingClientRect()` of the `flt-semantics[role="group"]` message row inside
  `ContentFrame` (the row spans the framed column, so its width equals the measured content width).
- Horizontal scrollbar: `document.documentElement.scrollWidth <= document.documentElement.clientWidth`.
- Console: `page.on('console')` + `page.on('pageerror')`, scanned for `RenderFlex overflowed`,
  `overflow`, or any page exception.
- Settings opened by real mouse down/up on the 设置 semantics button (long-press to settle); the
  settings page (title 设置, 保存 button) was confirmed via semantics before the screenshot.

## Results (12 screenshots)

| Viewport | State | Screenshot | Measured content width | RenderFlex overflow / exception | Horizontal scrollbar |
|---|---|---|---|---|---|
| 320×640 | empty | `.omo/evidence/ui-redesign/shots/empty-320x640.png` | 320 px (EmptyState, x=0) | none | no (scrollWidth 320 ≤ clientWidth 320) |
| 320×640 | seed messages | `.omo/evidence/ui-redesign/shots/seed-320x640.png` | 320 px (message column, x=0) | none | no (320 ≤ 320) |
| 320×640 | settings | `.omo/evidence/ui-redesign/shots/settings-320x640.png` | 288 px (settings list, x=16) | none | no (320 ≤ 320) |
| 390×844 | empty | `.omo/evidence/ui-redesign/shots/empty-390x844.png` | 327 px (EmptyState, x=31) | none | no (390 ≤ 390) |
| 390×844 | seed messages | `.omo/evidence/ui-redesign/shots/seed-390x844.png` | 390 px (message column, x=0) | none | no (390 ≤ 390) |
| 390×844 | settings | `.omo/evidence/ui-redesign/shots/settings-390x844.png` | 358 px (settings list, x=16) | none | no (390 ≤ 390) |
| 768×1024 | empty | `.omo/evidence/ui-redesign/shots/empty-768x1024.png` | 404 px (EmptyState, x=182) | none | no (768 ≤ 768) |
| 768×1024 | seed messages | `.omo/evidence/ui-redesign/shots/seed-768x1024.png` | **720 px** (message column, x=24) | none | no (768 ≤ 768) |
| 768×1024 | settings | `.omo/evidence/ui-redesign/shots/settings-768x1024.png` | 736 px (settings list, x=16) | none | no (768 ≤ 768) |
| 1280×800 | empty | `.omo/evidence/ui-redesign/shots/empty-1280x800.png` | 404 px (EmptyState, x=438) | none | no (1280 ≤ 1280) |
| 1280×800 | seed messages | `.omo/evidence/ui-redesign/shots/seed-1280x800.png` | **720 px** (message column, x=280) | none | no (1280 ≤ 1280) |
| 1280×800 | settings | `.omo/evidence/ui-redesign/shots/settings-1280x800.png` | 1248 px (settings list, x=16) | none | no (1280 ≤ 1280) |

Key checks:
- Message content column caps at exactly **720 px** on 768 and 1280 and is horizontally centred
  (x=24 at 768, x=280 at 1280) → `ContentFrame(maxWidth: 720)` is effective.
- No `RenderFlex overflowed` log and no page exception in any state at any viewport.
- No horizontal scrollbar anywhere; AppBar icons and composer stayed within the viewport.
- EmptyState rows all within the viewport; settings list scrolls vertically (its widest row equals
  viewport − 32 px padding, expected).

### Console notes

On the settings page only, the browser logs a benign network error while the page tries to refresh
the model list against a previously saved `api.deepseek.com` key:

```
error: Access to fetch at 'https://api.deepseek.com/v1/models' ... blocked by CORS policy
error: Failed to load resource: net::ERR_FAILED
```

This is a network/CORS failure of an explicit model-refresh request, not a Flutter layout exception
(no `RenderFlex overflowed`, no page exception). Chat and empty states logged zero errors.

## Cleanup

- Temporary server process on port 8090 stopped after capture.
- `kPreviewMessages` / `_preview` intentionally kept (approved debug branch).
- Screenshots/evidence remain untracked under `.omo/`.
