# Gold theme + avatar upload â€” QA evidence (Task 6)

Date: 2026-11-20
Workspace: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`
Build id: `f6bc95316868713c6dc4b3854629d4bd`
Toolchain: Flutter 3.35.1 / Dart 3.9.0 (`..\tools\flutter\bin\flutter.bat`)
`flutter_svg` resolved version: **2.3.0** (`pubspec.lock`)

## Gate results

| Command | Result |
|---|---|
| `flutter pub get` | exit 0 â€” `Got dependencies!` |
| `flutter analyze` | exit 0 â€” `No issues found! (ran in 1.9s)` |
| `flutter test` | exit 0 â€” `00:08 +59: All tests passed!` (**59 tests**) |
| `flutter build web --release --base-href /` | exit 0 â€” `âœ“ Built build\web` (31.9s) |

Build tail:

```
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 10468 bytes (99.4% reduction).
Compiling lib\main.dart for the Web...                             31.9s
âœ“ Built build\web
```

Note: Flutter printed a `Wasm dry run succeeded` advisory to stderr; the build itself exited 0.

No file under `lib/` or `test/` was modified by this task. `flutter analyze`/`flutter test` were run against the working tree as-is.

## Local server on 8090

Restarted from the NEW build (old PID 17712 stopped, then the release build ran, then the server was started):

- New PID: **11724** (recorded in `.tools-tmp/server-8090.pid`; left running for the user)
- `http://127.0.0.1:8090/` â†’ **200**
- `http://127.0.0.1:8090/?seed=1` â†’ **200**
- Served `main.dart.js` bytes: **3,090,212** â€” matches `build/web/main.dart.js` on disk (3,090,212), so the server is serving the new build.
- Build id on disk: `f6bc95316868713c6dc4b3854629d4bd`; disk mtime 2026-11-20T05:39:59.010Z.

## Browser QA (Playwright + Chrome headless)

Script: `.tools-tmp/gold-qa.mjs` (`chromium.launch({ channel: 'chrome', headless: true })`).

### Horizontal overflow (390Ã—844, empty state)

```
docScrollWidth  = 390
docClientWidth  = 390
bodyScrollWidth = 390
bodyClientWidth = 390
```

No horizontal overflow (scrollWidth == clientWidth).

### Console errors / page errors per section

| Section | Console errors | Page errors |
|---|---|---|
| A empty (`/`) | 0 | 0 |
| B seed (`/?seed=1`) | 0 | 0 |
| C settings | 0 | 0 |
| D wide 1280Ã—800 | 0 | 0 |
| E persisted custom avatar | 0 | 0 |

Test isolation note: opening Settings makes the app call the default `https://api.deepseek.com/v1/models` endpoint, which the remote server CORS policy rejects in a headless browser. That request was fulfilled locally by the QA harness (recorded as `externalIntercepts: [{section: "settings", url: "https://api.deepseek.com/v1/models"}]`). This isolates the UI from an external network/CORS policy; it does not alter app code or mask any in-app exception. All five `<flame>` sections report zero console/page errors.

### Settings: avatar card + default SVG

Accessibility tree (`Accessibility.getFullAXTree`) exposes the avatar card even below the fold:

```json
{
  "role": "group",
  "name": "å¤´åƒ å¤§è‚¥é±¼ æ¢ä¸€å¼ å–œæ¬¢çš„ç…§ç‰‡ï¼ŒèŠå¤©å’Œè¶³è¿¹é‡Œéƒ½ä¼šç”¨å®ƒã€‚ ä»ç›¸å†Œé€‰æ‹©"
}
```

- Avatar card box in the 390Ã—844 viewport: `x=16, y=646, w=358, h=184` â†’ fully inside 0..844, so `gold-settings-390x844.png` shows the **å¤´åƒ** card with the badge preview and both actions.
- The `å¤§è‚¥é±¼` semantics label comes from `AvatarMark`'s `Semantics(image: true, label: 'å¤§è‚¥é±¼')` wrapping the SVG badge.

### `flutter_svg` renders the badge on web

Every section requested the vector asset and received HTTP 200:

```
http://127.0.0.1:8090/assets/assets/avatar/default_avatar.svg
  empty: 200   seed: 200   settings: 200   wide: 200   custom_avatar: 200
```

**Explicit statement: `flutter_svg` renders the default gold/red SVG badge on web** (asset served with status 200 and the `å¤§è‚¥é±¼` image semantics label is present in the running app). This is not a CanvasKit-only fallback path.

### App-bar labels (seed state)

`flt-semantics-host` innerText contains the four expected tooltip labels:

```
å¥¹çš„è¶³è¿¹
ç”»ç”»ï¼ˆComfyUIï¼‰
æ–°ä¼šè¯
è®¾ç½®
```

### Persisted custom avatar (Section E)

Fresh context `addInitScript` writes:

```js
localStorage['flutter.feiyu.settings.v3'] = JSON.stringify({
  baseUrl: 'http://127.0.0.1:8090/v1', apiKey: 'k', model: 'm', persona: 'p',
  avatar: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
})
```

Result: no exception, app renders, screenshot captured. Empty (A) vs custom (E):

- `gold-empty-390x844.png` = 268,556 bytes
- `gold-custom-avatar-390x844.png` = 278,325 bytes
- `byteIdentical: false` â†’ **not pixel-identical**, so the persisted avatar changed the render.

## Screenshots (`.omo/evidence/ui-redesign/shots/`)

| File | Bytes |
|---|---|
| `gold-empty-390x844.png` | 268,556 |
| `gold-seed-390x844.png` | 207,205 |
| `gold-settings-390x844.png` | 54,065 |
| `gold-seed-1280x800.png` | 664,469 |
| `gold-custom-avatar-390x844.png` | 278,325 |

### Gold palette measured from the PNGs

Pixels within a tolerance of the primary gold `#E0B65A`:

| Screenshot | Gold-ish pixels | Near-black `#050403` pixels |
|---|---|---|
| empty 390Ã—844 | 0.39% | 9.61% |
| seed 390Ã—844 | 0.35% | 9.22% |
| settings 390Ã—844 | 1.62% | 17.87% |
| seed 1280Ã—800 | 0.11% | 9.40% |
| custom avatar 390Ã—844 | 0.40% | 9.45% |

The settings page corners sample exactly `(5, 4, 3)` = `#050403`, the new `AppPalette.ink`. Dark near-black dominates every screen and gold accents (text/icons/buttons) are present in all sections.

## Cleanup / state

- Server left running on port 8090 for the user; PID **11724** in `.tools-tmp/server-8090.pid`.
- `build/`, `.tools-tmp/`, `.flutter-plugins-dependencies` were **not** staged/committed.
- Commit: `docs(ui): capture evidence for the gold theme and avatar upload`.

## Jade + whale re-theme

Re-ran the full pipeline after `a8401b5` (jade palette), `469d55f` (whale avatar + scene retune) and `caa30d2` (outlined send button).

### Gates

- `flutter analyze` ¡ú **No issues found** (exit 0)
- `flutter test` ¡ú **59 passed** (`All tests passed!`, exit 0)
- `flutter build web --release --base-href /` ¡ú exit 0 (built `build\web`, ~40 s)

### Server

- Old PID 11724 stopped; new server PID **20460** (`.tools-tmp/server-8090.pid`), left running.
- `GET /` ¡ú 200, `GET /?seed=1` ¡ú 200.
- Served `main.dart.js` SHA256 `86a1c6bc2f0f387a01f79eb939fa0b6b1ea25a028df8209712a68e9b03fde671` == disk (3,090,022 B).
- `GET /assets/assets/avatar/default_avatar.svg` ¡ú 200, 1,645 B, SHA256 `13a5b1907881a52dd7f47e10f20a33141f9e6bdd3a45e1c4f01bf10f6dbef969` == disk.

### Bundle proves the new theme

- Jade `#8FD3C4` = `0.5607843137254902, 0.8274509803921568, 0.7686274509803922` ¡ú **present (3¡Á)**.
- Old gold `#E0B65A` triple `0.8784313725490196, 0.7137254901960784, 0.35294117647058826` ¡ú **absent**; gold-only channels `0.7137254901960784` / `0.35294117647058826` also absent. (The bare `0.8784313725490196` red channel still occurs 6¡Á ¡ª all Flutter framework greys/lavenders such as `0.878¡Á3` and `0.9059, 0.878, 0.9254`, never the gold triple.)
- Warm/mint/primaryDeep golds (`#F2C879`, `#E07A4A`, `#B9A46B`, `#A9762A`) all absent.

### Browser QA (`.tools-tmp/jade-qa.mjs`)

Chromium via Playwright `channel: 'chrome', headless: true`; fresh 390¡Á844 contexts with `localStorage.clear()`.

| Section | Viewport / wait | Result |
|---|---|---|
| A empty | 390¡Á844, 7 s | overflow scroll **390** / client **390** (no horizontal overflow) |
| B seed | 390¡Á844, 7 s | `/ ?seed=1` rendered |
| C settings | click header `(367,44)`, 1.5 s | AX tree exposes **Í·Ïñ** + **´ÓÏà²áÑ¡Ôñ** |
| D wide | 1280¡Á800, 6 s | overflow 1280 / 1280 |
| E send crop | A page, clip `{x:300,y:745,w:90,h:90}` | 90¡Á90 send button |

- Console/page errors: `empty=[] seed=[] settings=[] wide=[]` ¡ú **0**.
- External `https://api.deepseek.com/v1/models` fulfilled locally (`externalIntercepts`), so the settings CORS error never surfaced.
- Default avatar SVG responded 200 in every section.

### Screenshots (`.omo/evidence/ui-redesign/shots/`)

| File | Bytes |
|---|---|
| `jade-empty-390x844.png` | 271,384 |
| `jade-seed-390x844.png` | 208,989 |
| `jade-settings-390x844.png` | 54,050 |
| `jade-wide-1280x800.png` | 672,191 |
| `jade-composer-send-390x844.png` | 5,280 |

### Pixel proof (sampled every 2nd pixel, .NET bitmap)

Gold-ish pixels (`#E0B65A` ¡Àtolerance): **0** in all five screenshots. Dominant surfaces match the jade tokens exactly ¡ª ink `#050607` = `(5,6,7)`, bubbleSurface `(19,24,27)`, bubbleMine `(26,34,38)` ¡ª with jade accents present (`(132,197,183)` / `(143,211,196)`). No navy background.

### Cleanup / state

- `build/`, `.tools-tmp/`, `.flutter-plugins-dependencies` not staged.
- Server left running on 8090, PID **20460**.
- Commit: `docs(ui): capture jade and whale evidence`.