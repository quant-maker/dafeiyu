# Task 24 — Unify image viewer, sheets and snackbars

## Summary
- Added `lib/ui/overlays.dart` with `showImageViewer(BuildContext context, Uint8List bytes)`:
  black `Dialog` (`insetPadding: 8`), `InteractiveViewer` + `Image.memory(..., fit: BoxFit.contain, semanticLabel: '图片')`,
  top-right 44×44 `IconButton` (`tooltip: '关闭'`, `Icons.close`, `Colors.white70`), barrier-dismissible (Dialog default).
- `lib/main.dart`: `_openImage` now delegates to `showImageViewer(context, base64Decode(b64))`;
  `_imageSheet` drops hardcoded `backgroundColor`/`shape` (theme `bottomSheetTheme` supplies surface + 24 rounded top);
  both `ListTile`s use `contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4)`; option text/callbacks unchanged.
  Snackbar call passes no custom colors.
- `lib/comfy/comfy_page.dart`: `_openFull` delegates to `showImageViewer(context, bytes)`; local dialog removed.
- `test/overlays_test.dart`: opens viewer via `ElevatedButton`, asserts `Dialog` present + close target ≥ 44×44, taps close and asserts `Dialog` gone (no `pumpAndSettle`).

## Verification

### InteractiveViewer removed from both source files
```
main.dart InteractiveViewer count: 0
comfy_page.dart InteractiveViewer count: 0
```

### flutter analyze (last lines)
```
Analyzing dafeiyu...
No issues found! (ran in 10.6s)
```

### flutter test (last lines)
```
00:06 +44: test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:07 +45: test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:07 +46: All tests passed!
```

## Files changed
- lib/ui/overlays.dart (new)
- lib/main.dart
- lib/comfy/comfy_page.dart
- test/overlays_test.dart (new)

## Commit
`feat(ui): unify image viewer, sheets and snackbars`
