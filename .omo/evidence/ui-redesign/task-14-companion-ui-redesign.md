# Task 14 — Restyle attachment and listening bars

## Scope
- Created `lib/ui/attachments.dart` with `PendingImageBar` (StatelessWidget) and
  `ListeningBar` (StatefulWidget owning its own `AnimationController`).
- Replaced `_pendingImageBar()` / `_listeningBar()` in `_ChatPageState`
  (`lib/main.dart`) to delegate to the new widgets; display conditions unchanged.
- Added `test/attachments_test.dart` (320x640, real 1x1 PNG, 120-char hint,
  `pump(Duration(...))` only, no `pumpAndSettle`).

## Commands and raw results

### `flutter analyze` (last 20 lines)
```
$ (env redirected to ..\.tools-tmp)
$ ..\tools\flutter\bin\flutter.bat analyze
Analyzing dafeiyu...
No issues found! (ran in 2.3s)
```

### `flutter test` (last 20 lines)
```
00:01 +15: .../composer_test.dart: idle composer sends and keeps image/mic enabled
00:01 +16: .../composer_test.dart: idle composer sends and keeps image/mic enabled
00:02 +17: .../empty_state_test.dart: renders samples and reports the tapped one
00:02 +18: .../empty_state_test.dart: renders samples and reports the tapped one
00:02 +19: .../error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +20: .../error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +21: .../error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +22: .../error_notice_test.dart: danger notice dismisses on a 320 wide page
00:02 +23: .../message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +24: .../message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +25: .../message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +26: .../message_list_test.dart: default top padding equals status bar plus app bar height
00:03 +27: .../message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:03 +28: .../message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:03 +29: .../message_time_test.dart: time header shows at index 0 and after a 5 minute gap
00:03 +30: .../surfaces_test.dart: gallery renders every component without exceptions
00:03 +31: .../surfaces_test.dart: InlineNotice dismiss control fires callback
00:04 +32: .../surfaces_test.dart: GhostIconButton is discoverable by tooltip
00:04 +33: .../surfaces_test.dart: Pill with success tone renders its label
00:04 +34: All tests passed!
```

Targeted run of the new file:
```
00:00 +0: PendingImageBar shows the image and removes on tap
00:00 +1: ListeningBar keeps a long hint on a single line
00:00 +2: All tests passed!
```

### `grep -n "graphic_eq" lib/main.dart`
```
graphic_eq count: 0
```

## Notes
- Old inline `Icons.graphic_eq` icon removed with the rewrite.
- Only one `AnimationController` exists for the chat page, and it lives inside
  `_ListeningBarState` (controller created in `_ChatPageState` was not added).
