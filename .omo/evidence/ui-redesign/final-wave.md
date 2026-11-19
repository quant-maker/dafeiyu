# Final Verification Wave — results

Date: 2026-11-19
Plan: `.omo/plans/companion-ui-redesign.md`
Repo: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`

All four final-wave reviewers ran independently and returned a clear verdict.
ALL FOUR APPROVE.

| Gate | Verdict | Reviewer | Key evidence |
|---|---|---|---|
| F1 Plan compliance | **APPROVE** | oracle (`ses_e0c91c9edffeQMMVymSsK06wPt`) | 28/28 rows `[x]`; every row has a task evidence `.md`; all 26 promised test files exist; every `Commit: Y` message present in `git log`; all three amendments (Todo 27 `Commit: N`, consolidated shot refs, Comfy screenshots) verified |
| F2 Code quality | **APPROVE** | oracle (`ses_e0c91c522ffe5HRx8c4lGG1vPy`) | analyze clean, 55 tests pass, single `MessageBubble`/single blur/single `SafeArea`, controllers disposed, scroll button bounded inside the message `Expanded`, image decode keyed on payload |
| F3 Real QA | **APPROVE** | general (`ses_e0ca3fc92ffe7sQ2UiPHozjK0o`) | pub get / analyze (`No issues found!`) / test (`+55`) / `build web --release` all pass; 320/390/768/1280 × `/` and `/?seed=1` render with 0 console errors, 0 page errors, 0 failed requests, no horizontal overflow; settings 7/7 titles + scroll-to-bottom; footprints open/return; composer send fires a request; ComfyUI `已连接`; 14 screenshots, non-blank (stddev 16.2–45.4) |
| F4 Scope fidelity | **APPROVE** | oracle (`ses_e0ca3f76cffew4FZPDAQAMCTSF`) | no new deps, no new pages/settings, no light theme, scene preserved, data shapes unchanged, zero out-of-whitelist bare hex/emoji |

## Known caveat (recorded, not claimed as pass)

The Flutter Web **3.35.1 engine** throws a `TypeError` on a control tap once
accessibility semantics is enabled. Proven SDK-level: a stock `flutter create`
web app with zero custom `Semantics` reproduces it; the same tap with semantics
OFF yields 0 page errors. See `f3-semantics-attribution.md`.

This is a pre-existing SDK defect, outside the redesign's scope and not fixable
from app code. It does not affect the default (semantics-off) path that all
F3 measurements used.

## Machine-unverifiable dimension

Pixel-level aesthetics were not machine-verified: no vision-capable model was
available in this environment. Screenshots are archived under `shots/` (14 PNGs)
for human review.
