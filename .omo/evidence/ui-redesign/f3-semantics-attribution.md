# F3 addendum — attribution of the semantics-tap TypeError

Date: 2026-11-19
Repo: `C:\Users\xqli\Documents\deepseek-harness\default-workspace\dafeiyu`
Purpose: determine whether the F3 console exception is an app defect or a Flutter Web engine/SDK defect.
Scope: diagnostic only. **No product code was modified** (`lib/`, `test/`, `pubspec.yaml` untouched).

## Symptom under investigation (recorded in `f3-qa.md`)

In the release web build, after enabling Flutter accessibility semantics, tapping an
interactive control throws:

```
TypeError: Cannot read properties of null (reading 'a')
TypeError: Cannot read properties of null (reading 'toString')
   at KN.aws / KN.aw8 (main.dart.js)
```

Taps with semantics OFF are clean.

## Experiment

Throwaway project, outside the repo, built with the same Flutter SDK:

- `flutter create --platforms=web` → `default-workspace/tmp/semrepro`
- `lib/main.dart` replaced with a 30-line stock app:
  `MaterialApp(home: Scaffold(appBar: AppBar(title: Text('r')), body: Center(child: Column(children: [ElevatedButton(onPressed: (){}, child: Text('tap')), Text('ok')]))))`
  — **zero custom `Semantics` widgets, zero app logic**
- `flutter build web --release --base-href /`
- Served on a scratch port; driven with Playwright (real Chrome, trusted keyboard to
  activate `flt-semantics-placeholder`, then `page.touchscreen.tap` on the button's
  semantics node center), capturing `page.on('pageerror')` and console.

## Result: repro PASS → SDK-level fault

Minimal app, semantics ON, tapping the button:

```
TypeError: Cannot read properties of null (reading 'a')
    at wJ.WP (main.dart.js:21605:5)
    at tear_off.<anonymous> (main.dart.js:3286:67)
    at Zu.jL (main.dart.js:21672:27)
    at ZB.$1 (main.dart.js:21933:3)
    at Zv.$1 (main.dart.js:21888:35)
    at WM.$1 (main.dart.js:21675:41)
    at a_5.XI (main.dart.js:27633:32)
    at a_5.q2 (main.dart.js:27636:13)
    at a_8.$1 (main.dart.js:27645:21)
    at aiZ (main.dart.js:5987:29)
```

The identical touch tap with semantics **OFF** produced `0` page errors.

Environment: Flutter **3.35.1** stable (revision `20f8274939`), Dart 3.9.0.

## Conclusion

A stock, dependency-free Flutter web app reproduces the same null-dereference on a
semantics-enabled tap. Therefore this is a **pre-existing Flutter Web engine/semantics
defect in SDK 3.35.1**, not introduced by, nor fixable within, this UI redesign.

The app's own custom `Semantics` wrappers are not implicated and are unchanged:

- `lib/ui/avatar_mark.dart:52` — `Semantics(image: true, label: '大肥鱼', child: ExcludeSemantics(...))`
- `lib/ui/bubble.dart:72` — `Semantics(label: '图片消息', child: ClipRRect(...))`
- `lib/ui/surfaces.dart:233` — `Semantics(button: true, child: MouseRegion(... GestureDetector(onTap: onTap)))`

Removing all of them would not make the minimal app stop crashing, because it has none.

## Implication for the F3 gate

The F3 REJECT was raised solely against the semantics-ON tap path. With the fault
attributed to the SDK, the remaining F3 obligations — build succeeds, tests pass,
app renders, no console errors on the default (semantics-off) path, layout/overflow
clean — stand as the app-level gate. The SDK defect is recorded here as an
environment limitation, explicitly **not** claimed as a pass.
