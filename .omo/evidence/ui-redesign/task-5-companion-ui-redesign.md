# Task 5 — Shared surface / pill / status / button components

## Deliverable
`lib/ui/surfaces.dart` with the shared component kit consumed by every later screen:

- enums `NoticeTone { info, success, danger }`, `PillTone { neutral, primary, success, danger }`
- `SectionCard` — opaque `AppPalette.surfaceAlt`, `AppPalette.line` border, `AppRadii.xl`, padding 16, title `AppType.label` (no case transform), optional subtitle/trailing
- `SectionHeader` — `AppType.label` / `text3`
- `SettingsRow` — label `bodySmall`/`text2`, description `caption`/`text3`, child on its own row
- `Pill` — `AppRadii.full`, tones: neutral white@.05 + line, primary primary@.16 + .30, success mint@.14 + .30, danger danger@.14 + .30; `selected` maps to primary
- `StatusDot` — 9px circle, optional glow; `pulse: true` uses an internal `_PulsingDot` StatefulWidget with own AnimationController (1400ms, repeat(reverse: true), disposed). Stateless when `pulse == false` (no ticker created)
- `GhostIconButton` — 38px default, white@.05 bg, `AppRadii.m`, hover/pressed overlays, wraps `IconButton` with tooltip, `assert(tooltip.length > 0)`
- `PrimaryButton` — 48 high, pill radius, `AppGradients.send`, `primaryInk` fg, loading swaps to 16px `CircularProgressIndicator`
- `InlineNotice` — tone@.10 bg, tone@.28 border, icon 16, text 12.5, `SelectableText` message, 44px dismiss target when `onDismiss != null`

## Constraints verified
- Zero literal `Color(0x` in `lib/ui/surfaces.dart` (`Select-String` count = 0); all colours via `AppPalette` / `Colors.white.withValues`.
- No `BackdropFilter`, no packages added, no `// ignore:`.
- No other files modified.

## Test file
`test/surfaces_test.dart` asserts:
1. full gallery (every component incl. `StatusDot(pulse: true)`) pumps with `takeException() == null`, using `pump(Duration)` only — never `pumpAndSettle`.
2. `InlineNotice(onDismiss: cb)` renders a close control and tapping it fires `cb`.
3. `find.byTooltip('发图片')` finds a `GhostIconButton`.
4. `Pill(label: 'x', tone: PillTone.success)` renders.

## Commands & raw results

Toolchain: `..\tools\flutter\bin\flutter.bat` (Flutter 3.35.1), with APPDATA/LOCALAPPDATA/TEMP redirected to `..\.tools-tmp\*`.

### `flutter analyze` (full repo) — last 20 lines
```
Analyzing dafeiyu...
No issues found! (ran in 10.6s)
```

### `flutter test test/surfaces_test.dart` — last 20 lines
```
00:00 +0: loading .../test/surfaces_test.dart
00:00 +0: gallery renders every component without exceptions
00:00 +1: InlineNotice dismiss control fires callback
00:00 +2: GhostIconButton is discoverable by tooltip
00:00 +3: Pill with success tone renders its label
00:00 +4: All tests passed!
```

### `flutter test` (full suite) — last 20 lines
```
00:00 +12: .../test/surfaces_test.dart: gallery renders every component without exceptions
00:01 +12: .../test/surfaces_test.dart: InlineNotice dismiss control fires callback
00:01 +13: .../test/surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:01 +14: .../test/surfaces_test.dart: Pill with success tone renders its label
00:01 +15: All tests passed!
```

## Risks / notes
- `const GhostIconButton` cannot assert `tooltip.isNotEmpty` (getter is not a constant expression). Used `assert(tooltip.length > 0)` — `String.length` is const-evaluable, so the constructor stays `const` AND the runtime non-empty check is preserved.
- `StatusDot` remains a `StatelessWidget`; the animation controller lives only inside the private `_PulsingDot` State, which is only inserted when `pulse == true`. No ticker leak when idle.
- Parallel Wave-1 files (`layout.dart`, `avatar_mark.dart`) appeared during the run; untouched.
