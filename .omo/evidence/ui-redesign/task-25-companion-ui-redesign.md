# Task 25 — Harden accessibility and text scaling

## Summary
- Audited every raw `IconButton` that the redesign introduced across
  `lib/ui/**`, `lib/main.dart`, `lib/feeds/footprints_page.dart` and
  `lib/comfy/comfy_page.dart`. All icon-only buttons already carry a
  non-empty tooltip; no spot-fixes were required.
  - `lib/ui/attachments.dart` — “移除图片”
  - `lib/ui/overlays.dart` — “关闭”
  - `lib/ui/surfaces.dart` (`InlineNotice`) — “关闭”
  - `lib/main.dart` — “回到底部”, “刷新模型列表”
  - `GhostIconButton` enforces `tooltip.length > 0` via assert.
- Verified image semantics are present:
  - message image: `MessageBubble` wraps the image in `Semantics(label: '图片消息')`
  - comfy results: `Image.memory(..., semanticLabel: '生成结果')`
  - pending attachment: `Image.memory(..., semanticLabel: '待发送图片')`
  - viewer image: `Image.memory(..., semanticLabel: '图片')`
- No `RenderFlex` overflow surfaced at `TextScaler.linear(1.3)` on a
  320×640 canvas, so no layout edits were needed. No fixed text heights were
  introduced.
- Added `test/a11y_test.dart` (5 tests) auditing tooltip coverage for
  `ChatAppBar`, `Composer`, `EmptyState`, `MessageBubble` (with an image, also
  asserting the `'图片消息'` semantics label) and `SectionCard`.
- Added `test/text_scale_test.dart` (3 tests) rendering `MessageList`
  (3 messages, `busy: false`), `Composer` and a long-text `SectionCard` under
  `MediaQueryData(textScaler: TextScaler.linear(1.3), size: Size(320, 640))`
  and asserting `tester.takeException()` is null.

## Fixes made
- None required in `lib/` — audit + tests only. (No loosened assertions, no
  `// ignore:`, no `pumpAndSettle`.)

## Verification

### flutter analyze (last 20 raw lines)
```
Analyzing dafeiyu...
No issues found! (ran in 2.5s)
```

### flutter test (last 20 raw lines)
```
00:06 +35: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/overlays_test.dart: showImageViewer opens a dialog with a 44px close button
00:06 +36: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_about_test.dart: about card shows the self-check block and privacy copy
00:07 +37: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_comfy_test.dart: comfy card shows connection button and workflow fields
00:07 +38: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:08 +39: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:08 +40: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:08 +41: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:08 +42: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:08 +43: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_model_test.dart: switching provider updates the base url field
00:08 +44: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_scene_test.dart: scene dropdown and dim slider hide when disabled
00:08 +45: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_scene_test.dart: scene dropdown and dim slider hide when disabled
00:08 +46: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_scene_test.dart: scene dropdown and dim slider hide when disabled
00:08 +47: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:08 +48: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:08 +49: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:08 +50: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:08 +51: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:08 +52: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:08 +53: C:/Users/xqli/Documents/deepseek-harness/default-workspace/dafeiyu/test/settings_voice_test.dart: tts controls appear only when enabled and engine is local
00:08 +54: All tests passed!
```

## Files changed
- `test/a11y_test.dart` (new)
- `test/text_scale_test.dart` (new)

## Cleanup
- No temporary files left in the repo. Flutter logs live under
  `../.tools-tmp/` (outside version control). No sub-agent worktrees.
