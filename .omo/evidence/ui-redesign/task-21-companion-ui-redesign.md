# Task 21 — About section

## Commands

### flutter analyze
```
Analyzing dafeiyu...
No issues found! (ran in 2.2s)
```

### flutter test test/settings_about_test.dart
```
00:00 +0: loading .../test/settings_about_test.dart
00:00 +0: about card shows the self-check block and privacy copy
00:01 +1: All tests passed!
```

### flutter test (full)
```
00:06 +45: All tests passed!
```

### greps
```
SectionCard count: 7
line 2717: '所有数据只存在这台设备上：Key、对话、记忆都不经过任何第三方服务器。'
```

## Notes
- Self-check block moved into the existing `settings-section-about` `SectionCard` (no 8th card).
- `Pill(label: 'build $kBuildTag')` added above the `SelectableText` self-check block.
- Self-check lines unchanged: `build=`, `baseUrl=`, `model=`, `key长度=` (source length only — never the key itself).
- Privacy sentence verbatim; version `0.8.0+8` in `AppType.caption`/`text3`.
- Old self-check container literals `0xFF12203A` and `0xFF9FB6D6` removed (grep = 0).
