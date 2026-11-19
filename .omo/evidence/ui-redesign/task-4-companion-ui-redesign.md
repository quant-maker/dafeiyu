# Task 4 — Companion UI redesign: themed fish avatar mark

## Scope

Created `lib/ui/avatar_mark.dart` (`AvatarMark` + private `_FishPainter`) and
`test/avatar_mark_test.dart`. Replaces emoji avatars in app chrome with a drawn,
token-only fish mark.

## Design notes

- `AvatarMark({super.key, double size = 34, bool ring = true, bool glow = false})`.
- `_FishPainter` is parameterised by `size` only; every coordinate is a fraction
  of `size` (no magic `34` inside the painter).
- Draws, size-normalised: gradient body oval (`AppGradients.avatar` shader over the
  whole canvas), triangle tail, top fin, two specular highlights (`AppPalette.text1`
  at alpha), a dark eye (`AppPalette.primaryInk`), and — when `ring` — a 1px
  `AppPalette.lineStrong` rim plus a subtle `AppPalette.surfaceHi` inner backdrop.
- `glow: true` wraps the canvas in a circular `DecoratedBox` using `AppShadows.glow`.
- Accessibility: `Semantics(image: true, label: '大肥鱼', child: ExcludeSemantics(...))`.
- Colours are resolved at widget-build time and passed into the painter; `paint`
  never touches `Theme.of(context)`. `shouldRepaint` compares size/ring/gradient/colours.
- No emoji characters and no `// ignore:` in the source file.

## Commands and raw output

### `flutter pub get` (tail)

```
  web 1.1.1 (1.1.2 available)
Got dependencies!
62 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
```

### `flutter analyze` (repo-wide, last 20 lines)

```
Analyzing dafeiyu...

  error - Invalid constant value - lib\ui\surfaces.dart:326:15 - invalid_constant

flutter.bat : 1 issue found. (ran in 6.1s)
```

> Pre-existing, unrelated failure in `lib/ui/surfaces.dart` (another todo's
> uncommitted file: `assert(tooltip.isNotEmpty, ...)` in a `const` constructor).
> Todo 4 does not touch that file and does not commit it. Scoped analyze below
> proves the avatar mark itself is clean.

### `flutter analyze lib\ui\avatar_mark.dart` (last 20 lines)

```
Analyzing avatar_mark.dart...
No issues found! (ran in 1.1s)
```

### `flutter test test\avatar_mark_test.dart` (last 20 lines)

```
00:00 +0: loading C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/avatar_mark_test.dart
00:00 +0: renders a square mark at the requested size
00:00 +1: scales to large sizes
00:00 +2: does not render an emoji
00:00 +3: All tests passed!
```

## Measured sizes (from `tester.getSize` on the `CustomPaint`)

| `AvatarMark.size` | measured `CustomPaint` size |
|---|---|
| 34 | `Size(34.0, 34.0)` |
| 96 | `Size(96.0, 96.0)` |

## Emoji check

`Select-String -Path lib\ui\avatar_mark.dart -Pattern '🐟'` → 0 matching lines.

## Cleanup

- No new packages, no assets.
- `pub get` touched `.flutter-plugins-dependencies` (generated); reverted, not committed.
- Only `lib/ui/avatar_mark.dart` and `test/avatar_mark_test.dart` are committed.

## Risks

- Repo-wide `flutter analyze` currently fails only on the unrelated uncommitted
  `lib/ui/surfaces.dart:326`; it must be fixed by that file's owning todo.
