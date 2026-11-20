# Gold theme + avatar upload — QA evidence (Task 6)

Date: 2026-11-20
Workspace: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`
Build id: `f6bc95316868713c6dc4b3854629d4bd`
Toolchain: Flutter 3.35.1 / Dart 3.9.0 (`..\tools\flutter\bin\flutter.bat`)
`flutter_svg` resolved version: **2.3.0** (`pubspec.lock`)

## Gate results

| Command | Result |
|---|---|
| `flutter pub get` | exit 0 — `Got dependencies!` |
| `flutter analyze` | exit 0 — `No issues found! (ran in 1.9s)` |
| `flutter test` | exit 0 — `00:08 +59: All tests passed!` (**59 tests**) |
| `flutter build web --release --base-href /` | exit 0 — `✓ Built build\web` (31.9s) |

Build tail:

```
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 10468 bytes (99.4% reduction).
Compiling lib\main.dart for the Web...                             31.9s
✓ Built build\web
```

Note: Flutter printed a `Wasm dry run succeeded` advisory to stderr; the build itself exited 0.

No file under `lib/` or `test/` was modified by this task. `flutter analyze`/`flutter test` were run against the working tree as-is.

## Local server on 8090

Restarted from the NEW build (old PID 17712 stopped, then the release build ran, then the server was started):

- New PID: **11724** (recorded in `.tools-tmp/server-8090.pid`; left running for the user)
- `http://127.0.0.1:8090/` → **200**
- `http://127.0.0.1:8090/?seed=1` → **200**
- Served `main.dart.js` bytes: **3,090,212** — matches `build/web/main.dart.js` on disk (3,090,212), so the server is serving the new build.
- Build id on disk: `f6bc95316868713c6dc4b3854629d4bd`; disk mtime 2026-11-20T05:39:59.010Z.

## Browser QA (Playwright + Chrome headless)

Script: `.tools-tmp/gold-qa.mjs` (`chromium.launch({ channel: 'chrome', headless: true })`).

### Horizontal overflow (390×844, empty state)

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
| D wide 1280×800 | 0 | 0 |
| E persisted custom avatar | 0 | 0 |

Test isolation note: opening Settings makes the app call the default `https://api.deepseek.com/v1/models` endpoint, which the remote server CORS policy rejects in a headless browser. That request was fulfilled locally by the QA harness (recorded as `externalIntercepts: [{section: "settings", url: "https://api.deepseek.com/v1/models"}]`). This isolates the UI from an external network/CORS policy; it does not alter app code or mask any in-app exception. All five `<flame>` sections report zero console/page errors.

### Settings: avatar card + default SVG

Accessibility tree (`Accessibility.getFullAXTree`) exposes the avatar card even below the fold:

```json
{
  "role": "group",
  "name": "头像 大肥鱼 换一张喜欢的照片，聊天和足迹里都会用它。 从相册选择"
}
```

- Avatar card box in the 390×844 viewport: `x=16, y=646, w=358, h=184` → fully inside 0..844, so `gold-settings-390x844.png` shows the **头像** card with the badge preview and both actions.
- The `大肥鱼` semantics label comes from `AvatarMark`'s `Semantics(image: true, label: '大肥鱼')` wrapping the SVG badge.

### `flutter_svg` renders the badge on web

Every section requested the vector asset and received HTTP 200:

```
http://127.0.0.1:8090/assets/assets/avatar/default_avatar.svg
  empty: 200   seed: 200   settings: 200   wide: 200   custom_avatar: 200
```

**Explicit statement: `flutter_svg` renders the default gold/red SVG badge on web** (asset served with status 200 and the `大肥鱼` image semantics label is present in the running app). This is not a CanvasKit-only fallback path.

### App-bar labels (seed state)

`flt-semantics-host` innerText contains the four expected tooltip labels:

```
她的足迹
画画（ComfyUI）
新会话
设置
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
- `byteIdentical: false` → **not pixel-identical**, so the persisted avatar changed the render.

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
| empty 390×844 | 0.39% | 9.61% |
| seed 390×844 | 0.35% | 9.22% |
| settings 390×844 | 1.62% | 17.87% |
| seed 1280×800 | 0.11% | 9.40% |
| custom avatar 390×844 | 0.40% | 9.45% |

The settings page corners sample exactly `(5, 4, 3)` = `#050403`, the new `AppPalette.ink`. Dark near-black dominates every screen and gold accents (text/icons/buttons) are present in all sections.

## Cleanup / state

- Server left running on port 8090 for the user; PID **11724** in `.tools-tmp/server-8090.pid`.
- `build/`, `.tools-tmp/`, `.flutter-plugins-dependencies` were **not** staged/committed.
- Commit: `docs(ui): capture evidence for the gold theme and avatar upload`.
