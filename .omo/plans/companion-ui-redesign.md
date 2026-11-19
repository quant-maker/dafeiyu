# companion-ui-redesign - Work Plan

## TL;DR (For humans)

<!-- Fill this LAST, after the detailed plan below is written, so it summarizes the REAL plan. -->
<!-- Plain English for a non-engineer: NO file paths, NO todo numbers, NO wave/agent/tool names. -->

**What you'll get:** 一个视觉上统一、可读、有质感的「夜间陪伴」界面：聊天气泡重新设计、头像不再是 emoji、设置页从调试面板变成分组卡片、足迹与画画页与主界面同一套语言。功能、联网、记忆、语音、存档全部保持原样。

**Why this approach:** 现在难看的根因不是某一处配色，而是没有设计系统——2925 行单文件里散落几十个裸色值，每个页面各写各的阴影和圆角。所以先建立一套令牌与共享组件，再把四个页面接上去；这样改一次全局一致，以后也不会再漂。

**What it will NOT do:** 不改任何网络/流式/模型/Key/记忆/语音识别/存档逻辑；不加新依赖、新字体、浅色模式、新页面或新设置项；不改人设与提示词；不动已保存数据的结构。

**Effort:** Large
**Risk:** Medium - 触及四个页面的视觉层，仓库里没有可用的既有测试（模板测试目前是坏的），所以验证依赖分析器 + 新增组件测试 + 真实截图 QA。

**Decisions I made for you:** 我把它当作「开放式美化请求」处理，因此采用了默认方案而不是反复追问——如果你心里有具体方向，说一句我就改。
1. 视觉方向=深藏青底 + 柔和天蓝主色 + 一点暖橘作点缀的「夜间陪伴」，沿用现有房间场景，不换风格只做统一。
2. 房间场景保留，默认压暗从 25% 提到 42%，并在文字后加渐变遮罩（原有开关/滑块/换图全部保留）。
3. 消息改成真气泡：她在左（小鱼头像+名字+不透明深色气泡），你在右（不透明深蓝气泡+主色描边），取代现在的「浮字+三层阴影+竖细线」。
4. 头像用代码画的鱼形标记替代 🐟 emoji（可随主题着色、任意尺寸清晰）。
5. 不引入任何新依赖或网络字体（离线优先、16MB 预算）。
6. 只做深色，不加浅色模式与主题切换。
7. 拆出 `lib/ui/` 放主题与共享组件，业务逻辑原地不动。
8. 气泡不用逐条 BackdropFilter（长列表性能），改用不透明色块+描边保证任意背景下都可读；只在输入栏保留一处玻璃模糊。

Your next move: 直接开始执行（`$start-work companion-ui-redesign`），或先让我把这份计划再送去对抗式复核。详细执行细节见下。

---

> TL;DR (machine): Large effort / Medium risk. 28 implementation todos in 5 waves + 4 final verifiers. Builds `lib/ui/` design system (tokens, theme, avatar, bubbles, composer, surfaces, scrim, layout), rewires chat + settings + footprints + ComfyUI, hardens a11y/responsive, replaces the broken template test with real widget tests. No logic, network, storage, dependency, or schema changes. Todo 28 is discovered work: clear the repo's pre-existing 14 analyzer issues so every analyze gate is real.

## Scope

### Must have

1. **设计令牌单一来源**：`lib/ui/tokens.dart` 定义全部颜色/字号/间距/圆角/渐变/阴影/时长，`lib/ui/theme.dart` 输出 `ThemeData` 与 `AppTokens` ThemeExtension；`FeiyuApp` 注册该主题。界面层（`lib/ui/**`、`lib/main.dart`、`lib/feeds/footprints_page.dart`、`lib/comfy/comfy_page.dart`）不再出现裸 `Color(0x...)`（例外：`tokens.dart` 自身；`lib/scene/scene_stage.dart` 见 Must NOT 白名单）。
2. **共享组件**：`AvatarMark`（CustomPainter 鱼形）、`MessageBubble`、`TypingDots`、`Composer`、`EmptyState`、`ChatAppBar`、`ReadabilityScrim`、`ContentFrame`、`SectionCard`/`SectionHeader`/`SettingsRow`、`Pill`、`StatusDot`、`GhostIconButton`、`PrimaryButton`、`InlineNotice`、`ListeningBar`。
3. **聊天页重做**：AppBar（头像/名字/状态/图标簇）、可读性遮罩、空状态、消息列表（含时间分组、最大宽度居中）、左右气泡、打字指示、流式光标、错误条、滚动到底按钮。
4. **输入栏重做**：玻璃胶囊、图片/语音/发送/停止四种状态、待发送图片预览、聆听提示条。
5. **设置页重组**：分组卡片（模型 / 人设 / 语音 / 记忆与会话 / 场景 / ComfyUI / 关于），字段、控制器、`_save` 载荷与顺序完全不变。
6. **足迹页重做**：日期分组、卡片层级、空状态、心情胶囊。
7. **ComfyUI 页重做**：状态卡（窄屏不溢出）、提示词区、按钮层级、结果图网格、错误与进度。
8. **动效与可访问性**：气泡入场、发送按压反馈、打字点、呼吸感保留；语义标签、44px 点击区、`textScaler` 1.3x 不裁切。
9. **响应式**：320 / 390 / 768 / 1280 四个宽度下无溢出、正文行宽受 `ContentFrame`（720）约束。
10. **可用测试**：删除引用不存在 `MyApp` 的模板测试，新增组件级 hermetic 测试与令牌对比度测试；`flutter analyze` 零 issue、`flutter test` 全绿、`flutter build web --release` 成功。

### Must NOT have (guardrails, anti-slop, scope boundaries)

- **不改业务逻辑**：SSE 流式、`_runAgent`、模型/厂商解析、Key 处理、记忆抽取、主动消息计时、ASR/TTS 流程、存档、足迹生成、Comfy 客户端协议——一行都不改行为。
- **不改数据**：`feiyu.settings.v3`、`feiyu.footprints.v1`、对话存储键、`Settings`/`Footprint` 的 JSON 形状、字段名、默认值语义保持不变。唯一允许的默认值调整：`sceneDim` 新装默认 `.25` → `.42`，**恰好三处**——`Settings` 构造（`lib/main.dart:141`）、`load()` fallback（`lib/main.dart:192`）、`ChatPage.build` 的 `_settings?.sceneDim` fallback（`lib/main.dart:1739`，只影响设置载入完成前的默认值）。不得改任何已保存的用户值。
- **不加依赖**：`pubspec.yaml` 的 dependencies 保持原样；不加 google_fonts、不加动画包、不加 icon 包。
- **不加功能**：不新增页面/tab/路由/引导/设置项/开关；不改按钮的既有行为与跳转；不重命名任何面向用户的既有文案含义（可调整呈现方式，如分组标题）。
- **不加主题模式**：不做浅色主题、不做主题切换。
- **不删场景**：`SceneStage` 的房间/视频/情绪/压暗逻辑全部保留，只在其上叠加可读性层。
- **不写假测试**：不允许用 grep/文本搜索冒充验证；验收必须是可执行的编译/测试/截图断言。
- **不做过度抽象**：不为一次性 UI 建通用框架；组件只服务本 App 的四个页面。`ContentFrame` 是唯一跨页布局原语，不建 `AppPage`。
- **三处显式豁免（白名单，除此之外一律禁止）**：
  1. **已持久化的 mood（心情）默认值**共 4 处：`lib/feeds/footprints.dart:19,35`、`lib/main.dart:1181`、`lib/main.dart:1720` 的 `'🐟'`。它们是写入已存在足迹数据的默认值，不属于视觉层，**保持原样**。因此「🐟 清零」只针对 **widget 头像用法**（形如 `Text('🐟'` / `Center(child: Text('🐟'`），范围是 `lib/ui/**`、`lib/main.dart`、`lib/feeds/footprints_page.dart`；数据默认值行不在检查范围内。
  2. **场景渲染色**：`lib/scene/scene_stage.dart` 内部的 `Color(0x...)` 是房间/人物/氛围的绘制常量，**保持原样**（本计划只在其上叠加可读性层，不改内部）；裸色 grep 不覆盖该文件。
  3. Todo 26 的 `?seed=1` 预览分支是**唯一**允许新增的非视觉代码（用于自动化截图）；它必须不写存储、不影响无参启动路径，且不得扩展成任何面向用户的功能。

### Design spec (authoritative — executor copies these values verbatim)

**Palette** (`AppPalette`, all `const`):

| name | value | use |
|---|---|---|
| `ink` | `#060A13` | 页面最底/遮罩终点 |
| `surface` | `#0D1524` | 次级页面底色 |
| `surfaceAlt` | `#131F33` | 卡片底 |
| `surfaceHi` | `#1A2740` | 悬浮/置顶元素 |
| `primary` | `#7CC4FF` | 主色（动作、她） |
| `primaryDeep` | `#2F6FD0` | 渐变深端 |
| `primaryInk` | `#04101F` | 主色上的文字/图标 |
| `warm` | `#FFB27A` | 暖点缀（思考中、打字点） |
| `warmDeep` | `#E07A4A` | 暖色深端 |
| `mint` | `#6BD08B` | 在线/成功 |
| `danger` | `#FF8A8A` | 错误 |
| `text1` | `#EEF4FF` | 正文 |
| `text2` | `0x9EFFFFFF`（62% 白） | 次要正文 |
| `text3` | `0x80FFFFFF`（50% 白） | 说明/时间（**不是 40%**：40% 在 `ink` 上只有 3.76:1，达不到 4.5:1） |
| `text4` | `0x42FFFFFF`（26% 白） | 装饰（不承载信息） |

线条：`line = Colors.white @ .08`，`lineStrong = Colors.white @ .14`。
前景色值必须是**实际色**而非 `.withValues` 计算结果的变量名（`text2/3/4` 用 build 期 `const Color(0x…)` 预乘值，避免每次 build 重算）：`text2 = 0x9EFFFFFF`、`text3 = 0x80FFFFFF`、`text4 = 0x42FFFFFF`、`line = 0x14FFFFFF`、`lineStrong = 0x24FFFFFF`。

**Type scale** (`AppType`, `TextStyle` const, `fontFamily` 留空用系统字):

| token | size / height / weight / letterSpacing |
|---|---|
| `display` | 26 / 1.2 / w600 / -0.3 |
| `title` | 18 / 1.3 / w600 / 0 |
| `subtitle` | 15 / 1.4 / w600 / 0 |
| `body` | 15.5 / 1.68 / w400 / 0.1 |
| `bodySmall` | 13.5 / 1.6 / w400 / 0 |
| `caption` | 12 / 1.45 / w400 / 0.1 |
| `label` | 11 / 1.3 / w600 / 1.2 |
| `mono` | 11.5 / 1.6 / `fontFamily: 'monospace'` |

**Spacing** (`AppSpacing`): `xs 4, s 8, m 12, l 16, xl 20, xxl 24, xxxl 32`.
**Radii** (`AppRadii`): `s 8, m 12, l 16, xl 20, pill 26, full 999`，**外加气泡专用** `bubble 18, bubbleImage 14, bubbleTail 6`（三者也是 token，禁止在组件里写裸数字）。
**Durations** (`AppDurations`): `fast 140ms, base 220ms, entrance 200ms, breathe 1400ms`；曲线统一 `Curves.easeOutCubic`（呼吸用 `Curves.easeInOut`）。
**Gradients** (`AppGradients`): `send = [#5AB0FF, #2F6FD0]`；`avatar = [#8FD0FF, #2F6FD0]`；`scrimTop = [ink @ .72, ink @ 0]`；`scrimBottom = [ink @ 0, ink @ .78]`。
**Shadows** (`AppShadows`): `soft = [BoxShadow(0x47000000, blur 18, offset (0,6))]`；`glow = [BoxShadow(0x3D7CC4FF, blur 16)]`。
**Geometry**: `ContentFrame` 最大宽 **720**，水平内边距 16；聊天气泡最大宽 `min(available * 0.80, 560)`；气泡圆角 18、说话人一侧上角 6；AppBar 高 68；头像尺寸 `s 26 / m 34 / l 96`；点击区最小 44；发送钮 42；图标按钮 38。
**Bubble surfaces**: 她在左 = `AppPalette.bubbleSurface`（**不透明**常量 `0xD9141F31` **改为 `0xFF141F31`**）+ `line` 描边；你在右 = `AppPalette.bubbleMine`（**不透明** `0xFF152A45`）+ `primary @ .28` 描边 —— **不许用半透明底承载正文**（半透明底压在任意照片上无法保证对比度，见 Contrast contract）。两者都不使用 `BackdropFilter`。`bubbleSurface` / `bubbleMine` 是 `tokens.dart` 里的命名常量，`bubble.dart` 只能引用它们，**不得**出现字面量 `Color(0x...)`。输入栏底色走常量 `AppPalette.composerSurface`（`0xE60B1424`，90% 深色 + 唯一一处模糊；它承载输入文字，所以必须保持足够不透明：即使压在纯白照片上也仍有 >10:1）。
**Contrast contract（可算、可测、无照片依赖）**: 气泡与静态卡片必须用**不透明色**；输入栏是唯一允许半透明的表面（`0xE60B1424` + 模糊，已按最坏情况「压在纯白照片上」验证正文 ≥10:1）。`contrast_test.dart` **必须先用 `Color.alphaBlend(fg, bg)` 把带 alpha 的前景合成到背景上、再套 WCAG 公式**（`Color.computeLuminance()` 会忽略 alpha，直接用会把 50% 白算成纯白、让失败用例无法失败），对以下 8 组做纯 Dart 断言：
`text1/bubbleSurface ≥ 7`、`text1/bubbleMine ≥ 7`、`text1/surfaceAlt ≥ 7`、`text1/ink ≥ 7`、`text2/surfaceAlt ≥ 4.5`、`text2/ink ≥ 4.5`、`text3/ink ≥ 4.5`、`text3/surfaceAlt ≥ 4.5`。
场景照片那一层**不作为正文对比度的依据**——可读性由 `ReadabilityScrim` 的固定 alpha 结构保证，并由 widget test 断言该层的渐变取值，而不是去采样像素。

## Verification strategy

> Zero human intervention - all verification is agent-executed.

- **Test decision:** tests-after，框架 `flutter_test`（已随 SDK 提供，不新增依赖）。测试必须 hermetic：不初始化平台通道、不读 `SharedPreferences`、不加载 `assets/scene` 视频/图片。测试对象是 `lib/ui/` 组件与 `AppTheme.dark()`，不是 `FeiyuApp` 整体（整体含 `SceneStage` 的 video_player 与 `Settings.load()`，会污染单测）。**设置页例外说明**：`SettingsPage.initState` 会调用 `LocalTtsImpl.create()`（`lib/main.dart:2257`，底层 path_provider 在单测里抛 `MissingPluginException`，现有 `.catchError` 已吞掉），因此设置页测试只断言 UI 结构，**不得**依赖 `_ttsModelReady`，也不得断言该插件调用成功。
- **静态门槛:** `flutter analyze` 退出码 0 且输出无 `error` / `warning` / `info`（flutter_lints 5）。**注意**：现状 `test/widget_test.dart:16` 引用不存在的 `MyApp`，所以今天 `flutter analyze` 与 `flutter test` 都是失败的——**Todo 1 的第一步就删除它并放入最小可用测试**，否则后面所有验收都不可信。
- **构建门槛:** `flutter pub get` → `flutter build web --release --base-href /` 成功（Windows 下如未装 web 依赖，先 `flutter config --enable-web`；不得跳过，因为 Web 是唯一可自动截图的目标）。
- **测试归属（优先于任何 todo 里的「（Todo 27）」字样）**：**凡是某个 todo 的验收引用了一个测试文件，该 todo 必须自己创建它**（可以是先满足该 todo 断言的最小用例）。Todo 27 只做「补全 + 全仓运行 + 去重」，不得承担前置 todo 的验收。禁止用 `flutter test --plain-name` 在文件不存在时靠「零用例匹配也退出 0」制造假通过。
- **工具链前置（在所有门槛之前执行）**：先运行 `flutter pub get`（仓库 `pubspec.lock` 相对 `pubspec.yaml` 已过期，缺 `video_player`/`record`/`flutter_tts` 等条目；若离线用 `flutter pub get --offline`，pub 缓存在 `..\tools\pub-cache`）。再确认 `flutter --version` 可用；若不在 PATH，用 `tools/install-toolchain.ps1` 或**已知可用的 SDK 路径** `..\tools\flutter\bin\flutter`（3.35.1，SDK 根目录由 `tools/build-web.ps1:2-7` 的 `$root` / `FLUTTER_ROOT` 指定）。**若最终无法获得可用工具链，立即停止并写入证据文件，不得用「代码看起来对」冒充通过。** 浏览器截图用宿主可用的 Playwright 能力（`/playwright` skill 或等价浏览器 MCP）执行，不需要往 `pubspec.yaml` 加 `integration_test`。**`tools/build-web.ps1` 不在本计划的使用范围内**——它构建的是同级的另一个工程 `feiyu_app`（源来自 `feiyu_app_src`），用它验证会得到旧 UI 的假通过。
- **视觉门槛（补充性证据，不是唯一判据）**: 本地 `flutter build web --release` + `node server/server.mjs`，在 **320×640、390×844、768×1024、1280×800 四档**截「空状态 / 有消息 / 设置页」。截图由执行代理按可判定清单核对（内容区宽度、控制台 `RenderFlex overflowed` 日志、横向滚动条）；**凡是能用 widget test 断言的，一律不要只靠截图**。
- **证据目录:** `.omo/evidence/ui-redesign/task-<N>-<slug>.md`（命令输出）与 `.omo/evidence/ui-redesign/task-<N>-<slug>.png`（截图）。所有 QA 命令的真实 stdout/stderr 必须落盘，不以「看起来没问题」充当证据。

## Execution strategy

### Parallel execution waves

- **Wave 1（地基，串行依赖最重）**：令牌 → 主题 → 布局 → 头像 → 表面组件。主题依赖令牌；其余组件依赖两者。
- **Wave 2（聊天静态面）**：遮罩、AppBar、气泡、时间分组、空状态、错误提示。依赖 Wave 1。
- **Wave 3（聊天交互面）**：输入栏、待发图/聆听条、滚到底、流式光标与入场动效、状态点。依赖 Wave 2。
- **Wave 4（次级页面，可并行）**：设置壳 → 五个分组；足迹；Comfy。设置内部串行（同一文件同一 region），足迹与 Comfy 可与设置并行。
- **Wave 5（加固）**：对话框/弹层主题、可访问性、响应式、测试替换与对比度测试。依赖 Wave 2-4。
- **Final wave**：F1-F4 并行。

同一波内若两个 todo 改同一文件（`lib/main.dart` 的聊天区），必须串行或由同一执行者在同一批次内顺序应用；**禁止并行编辑同一个 Dart 文件**。注意：每个 todo 的 `Can parallelize with` 只表示**没有逻辑依赖**，不表示可以并发编辑；Wave 2 的 6/7/8/9/11/12 全部改 `lib/main.dart`，所以它们的实际执行顺序必须串行（7 → 9 → 6 → 8 → 11 → 12 即可满足所有依赖）。

### Dependency matrix

| Todo | Depends on (authoritative) | Blocks (direct) | Can parallelize with |
| --- | --- | --- | --- |
| 1 tokens | — | 2,3,4,5（其余为传递依赖） | — |
| 2 theme | 1 | 4,5,6,7,9 | 3 |
| 3 layout | 1 | 6 | 2,4,5 |
| 4 avatar | 1,2 | 7,9,11,22 | 3,5 |
| 5 surfaces | 1,2 | 7,9,11,12,13,14,16,22,23 | 3,4 |
| 6 scrim | 2,3 | 8 | 7,9 |
| 7 app bar | 2,4,5 | 8,9,14 | 6 |
| 8 chat shell | 6,7 | 15 | — |
| 9 bubbles | 2,4,5,7 | 10,13,15 | 6,11,12 |
| 10 time grouping | 9 | — | 11,12 |
| 11 empty state | 4,5 | — | 9,10,12 |
| 12 error notice | 5 | — | 9,10,11 |
| 13 composer | 5,9 | 15 | 14 |
| 14 pending/listening | 5,7 | 15 | 13 |
| 15 motion | 8,9,13,14 | 25 | 16 |
| 16 settings shell | 5 | 17,24 | 22,23 |
| 17 settings model | 16 | 18 | 22,23 |
| 18 settings persona/voice | 17 | 19,20,21 | 22,23 |
| 19 settings memory/scene | 18 | 20,21 | 22,23 |
| 20 settings comfy | 19 | 21 | 22,23 |
| 21 settings about | 20 | 24 | 22,23 |
| 22 footprints | 4,5 | 24 | 16-21,23 |
| 23 comfy page | 5 | 24 | 16-22 |
| 24 overlay theming | 16,17,18,19,20,21,22,23 | 25,26 | — |
| 25 a11y | 15,24 | 26 | — |
| 26 responsive QA | 24,25 | 27, F3 | — |
| 27 tests | 1-26 | F1-F4 | — |

> 本表的「Depends on」与每个 todo 里 `Parallelization:` 行必须一致；若冲突，以 todo 行为准并修正本表。同一波内只有无依赖关系的 todo 才能并行，且**同一 Dart 文件永不并行编辑**。

## Todos

> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->

### Wave 1 - Foundation

- [x] 1. 预检 + 新建 `lib/ui/tokens.dart`：调色板、字阶、间距、圆角、渐变、阴影、时长与 `AppTokens` ThemeExtension
  What to do / Must NOT do: **先做预检（本 todo 的第一件事，不要跳过）**：(a) 运行 `flutter pub get`（仓库 lock 已过期；离线用 `--offline`，缓存 `..\tools\pub-cache`），再运行 `flutter --version` 并记录结果；不可用时用 `tools/install-toolchain.ps1` 或已知路径 `..\tools\flutter\bin\flutter`（3.35.1）；(b) 删除 `test/widget_test.dart`（它引用不存在的 `MyApp`，会让 `flutter analyze` 与 `flutter test` 全仓失败），并**立刻**新建最小 `test/tokens_test.dart`（只断言 `AppTokens.standard().palette.primary == AppPalette.primary` 与 `AppTokens.standard().radii.bubble == 18`，不依赖 Todo 2），保证 `flutter test` 有可运行的用例；(c) 记录 `git status --short`，确认工作树里没有别人的未提交改动被覆盖。然后按上文 `### Design spec` 逐字落表。文件内只允许 `const` 与 `ThemeExtension` 样板（`copyWith`/`lerp` 必须实现且 `lerp` 对每个字段做 `Color.lerp`/`lerpDouble`）。`AppTokens extends ThemeExtension<AppTokens>` 承载 `palette, spacing, radii, gradients, shadows, durations` 六组；`AppType` 独立为 `abstract final class`，不在 extension 里。**必须**提供 `static AppTokens standard()` 工厂返回全部字段的规范值（Todo 2 直接使用它），以及 `static AppTokens of(BuildContext context)`（返回 `Theme.of(context).extension<AppTokens>() ?? AppTokens.standard()`，保证测试环境不崩）。不得引入 `flutter/material.dart` 之外的包；不得放任何 widget。
  Parallelization: Wave 1 | Blocked by: none | Blocks: 2,3,4,5 | Can parallelize with: —
  References: 现有色值来源 `lib/main.dart:380-390`（seed `0xFF4AA3FF`、scaffold `0xFF0B1220`）、`lib/main.dart:1754-1758`（头像渐变 `7CC4FF→2F6FD0`）、`lib/main.dart:2147-2152`（发送钮 `5AB0FF→2F6FD0`）、`lib/feeds/footprints_page.dart:120-123`（卡片 `16223A`/阴影）、`lib/comfy/comfy_page.dart:230-234`（状态卡 `16223A`）；坏测试 `test/widget_test.dart:11-16`（`const MyApp()` 未定义，App 实际类为 `FeiyuApp`，见 `lib/main.dart:376`）；工具链 `tools/install-toolchain.ps1`、`tools/build-web.ps1:2-7`（SDK 根目录 `..\tools\flutter`，3.35.1）、`pubspec.yaml:30-47` 与 `pubspec.lock`（lock 缺失新依赖，需 `pub get`）；Flutter ThemeExtension 契约见 https://api.flutter.dev/flutter/material/ThemeExtension-class.html
  Acceptance criteria (agent-executable): `flutter --version` 的输出已落盘（不可用时证据文件必须写明阻塞原因并停止）；`test/widget_test.dart` 不存在；`flutter test` 退出码 0（至少有 1 个用例）；`flutter analyze` 退出码 0；`flutter analyze lib/ui/tokens.dart` 退出码 0；文件内出现 `class AppTokens extends ThemeExtension<AppTokens>`、`static AppTokens standard()`、`static AppTokens of(`、`AppTokens copyWith`、`AppTokens lerp`；`grep -c "Color(0x" lib/ui/tokens.dart` ≥ 10（不看是否写 `const`，只看颜色字面量数量）；`tokens.dart` 内不出现 `Widget`、`StatelessWidget`、`build(`。
  QA scenarios (name the exact tool + invocation): happy — `flutter analyze` + `flutter test` 均退出码 0；failure — 故意把 `lerp` 里某一字段写成 `return this`，Todo 27 的 `test/tokens_test.dart` 必须能在 `Color.lerp` 断言处失败（执行完恢复正确实现），以此证明测试不是摆设。Evidence `.omo/evidence/ui-redesign/task-1-companion-ui-redesign.md`
  Commit: Y | feat(ui): add design tokens and AppTokens extension

- [x] 28. 清理既存 analyzer 债务（不改变业务行为），让 `flutter analyze` 全仓归零
  What to do / Must NOT do: T1 实测全仓 `flutter analyze` 退出码 1，共 14 条既存问题，全部落在本计划允许触碰的文件里（`lib/main.dart`、`lib/voice/*`），会阻塞后续每个 analyze 门。逐条只做「等价修复」，不改变行为：
    1. `lib/main.dart:404` `unused_field _speech`（若确无引用）：删除该字段及其初始化/释放引用；若仍有隐式用法则改为实际使用，不得保留死字段。
    2. `lib/main.dart:2219` `unused_field _ttsProgress`：本计划 Todo 18 会真正使用它；本 todo 先删除字段与赋值，Todo 18 再按需加回（或现在就接到 TTS 下载进度的 `LinearProgressIndicator` 上——二选一，保持零警告）。
    3. `lib/main.dart:2259` `invalid_return_type_for_catch_error`：把 `.catchError((Object _) => false)` 改为 `.catchError((Object _) {})`，错误吞掉语义不变。
    4. `lib/main.dart:1336-1339` 四条 `valid_regexps`：先读出原始字符串，修复非法转义/字符类，**保持正则意图不变**；修完必须能说明「修复前匹配什么、修复后匹配什么」。
    5. `lib/main.dart:300,1577,1635` `prefer_interpolation_to_compose_strings`：改成插值，输出字符串逐字符一致。
    6. `lib/voice/local_asr.dart:23` 多余插值、`local_asr_io.dart:1` / `local_tts_io.dart:1` 悬空库文档注释、`local_tts_io.dart:17` `unused_field _playing`：等价清理。
  不得改任何业务分支、网络调用、存储格式、提示词；不得为了消警告加 `// ignore:` 注释（除非该 lint 在 Flutter 3.35 下确为误报，且必须在证据里说明理由）。
  Parallelization: Wave 1（插队，先于 2-27）| Blocked by: 1 | Blocks: 2-27（全部 analyze 门）
  References: T1 证据 `.omo/evidence/ui-redesign/task-1-companion-ui-redesign.md`（14 条原始输出）；`lib/main.dart:300,404,1336-1339,1577,1635,2219,2259`；`lib/voice/local_asr.dart:23`、`lib/voice/local_asr_io.dart:1`、`lib/voice/local_tts_io.dart:1,17`
  Acceptance criteria (agent-executable): `flutter analyze` 全仓退出码 0 且输出 `No issues found!`；`flutter test` 退出码 0；`git diff` 中不出现任何 `// ignore:` 新增；逐条问题的删除/替换可在 diff 中定位。
  QA scenarios (name the exact tool + invocation): happy — `flutter analyze` 与 `flutter test` 双绿并贴原始输出；failure — 临时把 `_playing` 字段加回且不使用，`flutter analyze` 必须重新报 `unused_field`（证明门是活的），随后移除。Evidence `.omo/evidence/ui-redesign/task-28-companion-ui-redesign.md`
  Commit: Y | chore(lint): clear pre-existing analyzer debt

- [x] 2. 新建 `lib/ui/theme.dart`：`AppTheme.dark()` 组装 `ThemeData` 并注册到 `FeiyuApp`
  What to do / Must NOT do: `AppTheme.dark()` 返回 `ThemeData(useMaterial3: true, brightness: dark, colorScheme: ColorScheme.fromSeed(seedColor: AppPalette.primaryDeep, brightness: dark).copyWith(primary: AppPalette.primary, surface: AppPalette.surface, error: AppPalette.danger), scaffoldBackgroundColor: AppPalette.ink, extensions: [AppTokens.standard()])`，并显式设置组件主题：`appBarTheme`（背景 transparent、`elevation 0`、`scrolledUnderElevation 0`、`titleTextStyle` 用 `AppType.title`）、`textTheme`（`bodyMedium = AppType.body`、`bodySmall`、`titleMedium = AppType.title`、`labelLarge`、`displaySmall = AppType.display`）、`iconTheme`（`color text2, size 20`）、`inputDecorationTheme`（filled、fillColor `Colors.white @ .05`、`border OutlineInputBorder(borderSide line, radius AppRadii.l)`、focusedBorder primary @ .55、`contentPadding 14`）、`filledButtonTheme`、`textButtonTheme`、`outlinedButtonTheme`、`switchTheme`（thumb primary）、`sliderTheme`（trackHeight 5、activeTrack primary、inactiveTrack lineStrong、thumb radius 9）、`snackBarTheme`（floating、surfaceHi、圆角 14）、`dialogTheme: DialogThemeData(backgroundColor: AppPalette.surfaceAlt, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)))`（Flutter 3.35 里 `ThemeData.dialogTheme` 的类型是 `DialogThemeData`，不是 `DialogTheme` widget）、`bottomSheetTheme`（surfaceAlt、顶部圆角 24）、`dividerTheme`（color line, thickness 1）、`listTileTheme`、`dropdownMenuTheme`、`progressIndicatorTheme`（primary）、`tooltipTheme`（surfaceHi、`textStyle caption`）。在 `lib/main.dart:376-392` 用 `theme: AppTheme.dark()` 替换内联 `ThemeData`，保留 `title`/`debugShowCheckedModeBanner`/`home`。不得改 `home`、不得改路由、不得改 `MaterialApp` 其他字段。
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 4,5,6,7,9 | Can parallelize with: 3
  References: `lib/main.dart:376-392`（当前唯一 ThemeData）、`lib/main.dart:2430-2433`（设置页 AppBar 依赖默认 appBarTheme）、`lib/feeds/footprints_page.dart:45-49` 与 `lib/comfy/comfy_page.dart:120-128`（两页硬编码 AppBar 背景，Todo 22/23 会移除）
  Acceptance criteria (agent-executable): `flutter analyze` 退出码 0；`grep -n "AppTheme.dark()" lib/main.dart` 恰有 1 处；`lib/main.dart` 内不再出现 `ColorScheme.fromSeed`；**本 todo 创建** `test/theme_test.dart` 并断言 `AppTheme.dark().colorScheme.primary == AppPalette.primary`、`AppTheme.dark().extension<AppTokens>() != null`、`AppTheme.dark().appBarTheme.backgroundColor == Colors.transparent`。
  QA scenarios: happy — `flutter test test/theme_test.dart` 通过；failure — 让 `AppTheme.dark()` 漏掉 `extensions`，该测试 `extension<AppTokens>()` 断言必须失败。Evidence `.omo/evidence/ui-redesign/task-2-companion-ui-redesign.md`
  Commit: Y | feat(ui): add AppTheme with component themes

- [x] 3. 新建 `lib/ui/layout.dart`：`ContentFrame`（唯一的跨页布局原语）
  What to do / Must NOT do: `ContentFrame({maxWidth = 720, padding = EdgeInsets.symmetric(horizontal: 16), child})` 用 `LayoutBuilder` + `ConstrainedBox` + `Padding` 实现；内容超宽时水平居中。**不建 `AppPage`**（各页仍用各自的 `Scaffold`，避免为一次性用途造框架）。必须 `MediaQuery.textScaler` 友好：不设固定高度、不裁切文本。
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 6 | Can parallelize with: 2,4,5
  References: `lib/main.dart:1874-1886`（消息列表当前无宽度约束）、`lib/feeds/footprints_page.dart:78-80`（ListView padding 16/12/16/40）、`lib/comfy/comfy_page.dart:129-130`（同款 padding）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "class AppPage" lib/ui/layout.dart` 返回 0 行；本 todo **创建** `test/layout_test.dart`，在 `tester.view.physicalSize` 1280 宽下断言内容实际宽度 ≤ 720、在 360 宽下断言内边距为 16 且不溢出；`flutter test test/layout_test.dart` 通过（**不要**用 `--plain-name`，避免零匹配假通过）。
  QA scenarios: happy — `flutter test test/layout_test.dart` 的 1280/360 两个宽度断言都通过；failure — 把 `maxWidth` 临时设为 `double.infinity`，宽度断言必须失败。Evidence `.omo/evidence/ui-redesign/task-3-companion-ui-redesign.md`
  Commit: Y | feat(ui): add responsive ContentFrame

- [x] 4. 新建 `lib/ui/avatar_mark.dart`：`AvatarMark` 与 `_FishPainter`
  What to do / Must NOT do: 用 `CustomPaint` 画鱼：椭圆身体（渐变 `AppGradients.avatar`）、三角尾鳍、上鳍、两颗高光、一只眼（`primaryInk` 深色点）、外圈 1px `lineStrong`；比例基于 `size` 归一化，`size` 取 `26/34/96` 时都不糊。`AvatarMark({size = 34, bool ring = true, bool glow = false})`；`ring` 控制外圈与内底色，`glow` 加 `AppShadows.glow`。必须 `ExcludeSemantics` 或 `Semantics(label: '大肥鱼的标记', image: true)` 二选一（统一选 `Semantics(image: true, label: '大肥鱼')` 并用 `ExcludeSemantics` 包住 painter）。不得使用任何 emoji 字符。
  Parallelization: Wave 1 | Blocked by: 1,2 | Blocks: 7,9,11,22 | Can parallelize with: 3,5
  References: 被替换的 emoji 用法 `lib/main.dart:1751-1760`、`lib/main.dart:1828-1839`、`lib/main.dart:1913-1916`、`lib/feeds/footprints_page.dart:130-138`；渐变来源 `lib/main.dart:1754-1758`
  Acceptance criteria (agent-executable): `flutter analyze lib/ui/avatar_mark.dart` 0 issue；本 todo **创建** `test/avatar_mark_test.dart` 并用 `tester.pumpWidget(AvatarMark(size: 34))` 断言 `find.byType(CustomPaint)` 存在且 `tester.getSize` 为 34×34、`size: 96` 时为 96×96（证明尺寸是参数化的）；`grep -n "🐟" lib/ui/avatar_mark.dart` 返回 0 行。**不要**在这里断言全仓 `🐟` 为 0——`lib/feeds/footprints.dart:19,35` 的数据默认值是白名单豁免。
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/avatar_mark_test.dart` 两个尺寸断言通过；failure — 把 painter 尺寸依赖写成硬编码 `34`，`size: 96` 断言失败。视觉清晰度用 `tester.getSize` + 渲染无异常判定，不以「看起来清晰」为判据。Evidence `.omo/evidence/ui-redesign/task-4-companion-ui-redesign.md`
  Commit: Y | feat(ui): draw a themed fish avatar mark

- [x] 5. 新建 `lib/ui/surfaces.dart`：卡片、分组标题、行、胶囊、状态点、图标按钮、主按钮、内联提示
  What to do / Must NOT do: **先在 `lib/ui/surfaces.dart` 顶部定义两个枚举**（全项目只此一份，后续 todo 一律引用）：`enum NoticeTone { info, success, danger }` 与 `enum PillTone { neutral, primary, success, danger }`。然后实现 `SectionCard({super.key, title, subtitle, children, trailing})`（**不透明** `AppPalette.surfaceAlt` 底、`line` 描边、`AppRadii.xl`、padding 16、标题用 `AppType.label` 且**保持原文案不做大小写变换**——中文没有大小写）、`SectionHeader`、`SettingsRow({label, description, child})`（label `bodySmall` text2、description `caption` text3、child 独占一行）、`Pill({required String label, bool selected = false, VoidCallback? onTap, IconData? icon, PillTone tone = PillTone.neutral})`（圆角 full；`selected == true` 时按 `PillTone.primary` 处理；neutral 底 white @ .05 + `line` 描边、success 用 `mint @ .14` + `mint @ .30` 描边、danger 用 `danger @ .14` + `.30`；文字用 `AppType.caption`，`tone` 决定文字色：neutral→text2、primary→primary、success→mint、danger→danger）、`StatusDot({color, pulse})`（9px 圆 + 可选 `glow`）、`GhostIconButton({required IconData icon, required String tooltip, VoidCallback? onPressed, Color? color, double size = 38})`（白 @ .05 底、圆角 m、hover/pressed overlay，`IconButton` 的 `tooltip` 必须非空）、`PrimaryButton({label, icon, onPressed, loading})`（48 高、圆角 full、`AppGradients.send`、文字/图标 `primaryInk`、loading 时换 16px `CircularProgressIndicator`）、`InlineNotice({required String message, NoticeTone tone = NoticeTone.danger, VoidCallback? onDismiss})`（背景为该色 @ .10、描边 @ .28、图标 16、文字 12.5、关闭按钮 44 点击区，message 用 `SelectableText` 以保留可复制）。所有组件必须只读 `AppTokens.of(context)` 或 `AppPalette`，不得新增裸 hex。
  Parallelization: Wave 1 | Blocked by: 1,2 | Blocks: 7,9,11,12,13,14,16,22,23 | Can parallelize with: 3,4
  References: 设置页现有 `_Label` `lib/main.dart:2915-2925`；自检卡 `lib/main.dart:2437-2459`；错误条 `lib/main.dart:1796-1818`；Comfy 状态卡 `lib/comfy/comfy_page.dart:216-255`；发送钮 `lib/main.dart:2147-2158`
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "Color(0x" lib/ui/surfaces.dart` 返回 0 行（全部走 tokens）；`grep -n "enum NoticeTone\|enum PillTone" lib/ui/surfaces.dart` 各命中 1 处；本 todo **创建** `test/surfaces_test.dart` 断言 `InlineNotice` 在 `onDismiss != null` 时渲染关闭按钮、`GhostIconButton` 的 `tooltip` 可通过 `find.byTooltip` 找到、`Pill(tone: PillTone.success)` 能渲染。
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/surfaces_test.dart` 通过且在 all-components 页面 `tester.takeException()` 为 null；failure — 给 `GhostIconButton` 传空 tooltip，`find.byTooltip('')` 断言必须失败。Evidence `.omo/evidence/ui-redesign/task-5-companion-ui-redesign.md`
  Commit: Y | feat(ui): add shared surface, pill, status and button components

### Wave 2 - Chat surface

- [x] 6. 新建 `lib/ui/scrim.dart` 并把可读性遮罩接入聊天页
  What to do / Must NOT do: `ReadabilityScrim({double strength = 1})`：实现为 `IgnorePointer(child: Stack(children: [Positioned(top: 0, left: 0, right: 0, height: 140, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: topCenter, end: bottomCenter, colors: AppGradients.scrimTop)))), Positioned(bottom: 0, left: 0, right: 0, height: 220, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: topCenter, end: bottomCenter, colors: AppGradients.scrimBottom))))]))`（**只保留这一种实现**，不要再写 Column/Expanded 版本）。在 `lib/main.dart` 的 `Scaffold.body` 外包一层 `Stack(children: [Positioned.fill(child: ReadabilityScrim()), bodyColumn])`。同时把 `Settings({... this.sceneDim = .42 ...})`（`lib/main.dart:141`）、`load()` fallback（`lib/main.dart:192`）**以及 `build()` 里的第三处 fallback**（`lib/main.dart:1739` 的 `_settings?.sceneDim ?? .25`）全部从 `.25` 改为 `.42`——三处都要改，否则设置载入前会闪现旧暗度。不得改 `SceneStage` 的任何内部逻辑与参数含义。不得删除 `_atmosphere()`。本 todo 只加一次遮罩；Todo 8 重组外壳时必须**移除**这里的包裹而不是叠加第二层。
  Parallelization: Wave 2 | Blocked by: 2,3 | Blocks: 8 | Can parallelize with: 7,9
  References: `lib/main.dart:1736-1794`（ChatPage build 与透明 Scaffold）、`lib/main.dart:1783-1791`（body Column）、`lib/scene/scene_stage.dart:266-288`（现有 `_atmosphere`，保留）、`lib/main.dart:141`、`lib/main.dart:192`、`lib/main.dart:1739`（三处 `sceneDim` 的 `.25`）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -c "this.sceneDim = .42" lib/main.dart` 结果为 1、`grep -c "?? .42" lib/main.dart` 结果为 2（load fallback + build fallback）、`grep -c "?? .25" lib/main.dart` 与 `grep -c "sceneDim = .25" lib/main.dart` 均为 0；本 todo **创建** `test/contrast_test.dart`：**第一部分**是纯 Dart 断言（无 widget），断言 `text1` 在 `bubbleSurface`/`bubbleMine`/`surfaceAlt`/`ink` 上均 ≥ 7:1、`text2` 与 `text3` 在 `surfaceAlt`/`ink` 上均 ≥ 4.5:1（**必须先 `Color.alphaBlend` 合成**），并把 8 个实测比值写进证据文件；**第二部分**是 `testWidgets` 组，pump `ReadabilityScrim` 后用 `find.byType(DecoratedBox)` 取 `BoxDecoration.gradient` 校验上下两个渐变的 alpha 与设计值一致。
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/contrast_test.dart` 全部数值断言通过；failure — 把 `text3` 改回 0x66FFFFFF，`text3/ink` 断言失败（实测约 3.76:1）。Evidence `.omo/evidence/ui-redesign/task-6-companion-ui-redesign.md`
  Commit: Y | feat(ui): add readability scrim over the scene

- [x] 7. 新建 `lib/ui/chat_app_bar.dart` 并替换聊天页 AppBar
  What to do / Must NOT do: `ChatAppBar` **必须声明为** `class ChatAppBar extends StatelessWidget implements PreferredSizeWidget`（否则 `Scaffold.appBar: ChatAppBar(...)` 无法通过编译——`appBar` 形参类型是 `PreferredSizeWidget?`），并实现 `@override Size get preferredSize => const Size.fromHeight(height);`。暴露 `static const double height = 68;`（**内容高度**，不含状态栏）；`build` 直接返回 `Padding(padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top), child: SizedBox(height: height, child: Row(...)))`——**不要**在 build 里再返回 `PreferredSize`（那会双重包装）。因为 `extendBodyBehindAppBar: true` 时 Scaffold 不会替 AppBar 加状态栏内边距，漏了就会画到状态栏底下。**构造函数签名必须逐字写成** `ChatAppBar({super.key, required String title, required String status, required SceneMood mood, required VoidCallback onFootprints, required VoidCallback onComfy, required VoidCallback onNewChat, required VoidCallback onSettings})`。左边 `AvatarMark(size: 34, glow: true)` + 标题 `AppType.title` + 状态行 `AppType.caption`（`text3`，`maxLines: 1`，`overflow: ellipsis`，`Flexible` 包裹）+ 状态点 `StatusDot`；`mood` 参数用来决定状态点颜色（`SceneMood` 映射：`idle → mint`、`listening → primary`、`thinking → warm`、`speaking → primary`、`away → text3`；**不得**忽略该参数）。右边四个 `GhostIconButton` 放进一个 `Container(padding 4, decoration: white @ .05, radius AppRadii.m)` 簇，图标依次 `photo_library_outlined`/`brush_outlined`/`auto_awesome_outlined`/`tune`，tooltip 沿用原文案「她的足迹」「画画（ComfyUI）」「新会话」「设置」。背景必须是 `Colors.transparent`，不画底线。在 `lib/main.dart:1744-1782` 用该组件替换内联 AppBar，四个回调保持不变。`_statusLine()` 保持原返回值（不改内容），只在新组件内做截断。
  Parallelization: Wave 2 | Blocked by: 2,4,5 | Blocks: 8,9,14 | Can parallelize with: 6
  References: `lib/main.dart:1744-1782`（现有 AppBar）、`lib/main.dart:1483-1490`（`_statusLine`）、`lib/main.dart:1768`（`_statusLine` 唯一调用点）、`lib/scene/scene_stage.dart:8-16`（`SceneMood`）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "🐟" lib/ui/chat_app_bar.dart` 返回 0 行（头像必须用 `AvatarMark`）；本 todo **创建** `test/chat_app_bar_test.dart` 断言四个 tooltip 均存在、状态文本超长时 `Text.maxLines == 1`、`ChatAppBar.height == 68`；在 390×844 的 `tester.view.physicalSize` 下 `tester.takeException()` 为 null。
  QA scenarios: happy — `flutter test test/chat_app_bar_test.dart` 在 390 宽下四个 tooltip 全部命中且无异常；failure — 传入 120 字符状态文本，`tester.pumpWidget` 后出现 `RenderFlex overflowed`，`takeException()` 非 null 即失败。Evidence `.omo/evidence/ui-redesign/task-7-companion-ui-redesign.md`
  Commit: Y | feat(ui): rebuild chat app bar with avatar and icon cluster

- [x] 8. 重组聊天页外壳：`ContentFrame` + `ReadabilityScrim` + `ChatAppBar` 装配
  What to do / Must NOT do: 把 `lib/main.dart:1736-1794` 重组为：`SceneStage(enabled: _settings?.sceneEnabled ?? true, dim: _settings?.sceneDim ?? .42, image: _settings?.sceneImage ?? '', mood: _mood, child: Scaffold(backgroundColor: Colors.transparent, extendBodyBehindAppBar: true, appBar: ChatAppBar(...), body: Stack(children: [Positioned.fill(child: ReadabilityScrim()), ContentFrame(padding: EdgeInsets.zero, child: Column(...))])))`。
  `ChatAppBar` 的调用参数：`title: '大肥鱼'`、`status: _statusLine()`、`mood: _mood`、四个回调 `onFootprints: _openFootprints, onComfy: _openComfy, onNewChat: _clear, onSettings: _openSettings`。
  **四个 SceneStage 参数一个都不能少**（`mood` 必填，漏了直接编译失败；`enabled/dim/image` 漏了会静默丢掉用户的场景设置）。**必须移除 Todo 6 加的临时包裹层**——`ReadabilityScrim` 在文件里只出现一次。**`ContentFrame` 必须在这里真正套上**（Todo 10/26 的宽度断言依赖它），且 `padding: EdgeInsets.zero` 以免与列表/输入栏自身的内边距叠加。`Column` 顺序保持：错误条 → 消息区 → 待发图条 → 聆听条 → 输入栏，子 widget 显示条件不变。**本 todo 不移动 `_composer`**：底部安全区此刻仍由 `_composer` 内部现有的 `SafeArea` 负责（它要到 Todo 13 才迁进 `lib/ui/composer.dart`），所以 `Column` 唯一要做的就是**不要**再额外包一层 `SafeArea`。`Scaffold` 保持默认 `resizeToAvoidBottomInset: true`，让键盘顶起输入栏。
  Parallelization: Wave 2 | Blocked by: 6,7 | Blocks: 15
  References: `lib/main.dart:1736-1794`（原结构）、`lib/main.dart:1785-1789`（条件渲染顺序）、`lib/main.dart:1737-1741`（SceneStage 现有四个参数）、`lib/scene/scene_stage.dart:21-39`（构造签名，`mood` 为 required）、`lib/main.dart:400`（`SingleTickerProviderStateMixin`：本 todo 不改它；`_dots` 是否还存在取决于 Todo 9 是否已执行，**不要**在本 todo 手动增删 ticker）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -c "ReadabilityScrim" lib/main.dart` 结果为 1；`grep -c "ContentFrame(" lib/main.dart` 结果为 1；`grep -c "SceneStage(" lib/main.dart` 结果为 1，且该构造函数实参里含 `mood: _mood`；`grep -n "extendBodyBehindAppBar" lib/main.dart` 命中 1 处；`grep -c "SafeArea(" lib/main.dart` 结果为 **2**（`_imageSheet` 一处 + `_composer` 一处，后者要到 Todo 13 才迁走；本 todo 只保证聊天 `Column` 没有新增 SafeArea）；`flutter test` 全绿。
  QA scenarios: happy — 390×844 起服务截图：AppBar 悬浮、首条消息在 `ChatAppBar.height`（68）+ 状态栏之下、内容区居中；failure — 漏传 `mood` 编译失败；去掉 `ContentFrame` 后 1280 视口内容宽度 > 720（Todo 26 测量失败）。视觉证据合并到 Todo 26 的四档截图（`.omo/evidence/ui-redesign/shots/seed-390x844.png` 等）与 `.omo/evidence/ui-redesign/task-8-companion-ui-redesign.md`。
  Commit: Y | refactor(ui): assemble chat shell with scrim, frame and app bar

- [x] 9. 新建 `lib/ui/bubble.dart`（`MessageBubble` + `TypingDots`）与 `lib/ui/message_list.dart`（`MessageList`），替换 `_message`/`_userLine`/`_TypingDots`/`_messageList`
  What to do / Must NOT do: `MessageBubble({required String content, required bool mine, bool showName = false, String? name, Widget? image, bool typing = false, Widget? trailing, double maxWidth = 560})`：
    - 她在左：`Row(crossAxisAlignment: start, children: [AvatarMark(size: 26, ring: false), SizedBox(8), Flexible(Column(crossAxisAlignment: start, children: [if (showName) name, bubble]))])`；气泡 `Container(constraints: BoxConstraints(maxWidth: min(available * .80, maxWidth)), padding: EdgeInsets.symmetric(h 14, v 11), decoration: BoxDecoration(color: AppPalette.bubbleSurface, borderRadius: BorderRadius.only(topLeft: AppRadii.bubbleTail, 其余 AppRadii.bubble), border: Border.all(color: AppPalette.line)))`；正文 `SelectableText(content, style: AppType.body.copyWith(color: AppPalette.text1))`。
    - 你在右：`Row(mainAxisAlignment: end, children: [Flexible(bubble)])`；气泡底色 `AppPalette.bubbleMine`（不透明）、描边 `AppPalette.primary.withValues(alpha: .28)`、圆角仅 `topRight: AppRadii.bubbleTail`、其余 `AppRadii.bubble`；正文 `AppType.bodySmall.copyWith(color: AppPalette.text1, fontSize: 15)`。
    - 图片：`ClipRRect(borderRadius: BorderRadius.circular(AppRadii.bubbleImage), child: GestureDetector(onTap: ..., child: Image.memory(..., width: 260)))`；必须在图片外层加 `Semantics(label: '图片消息')`。
    - `typing: true` 时气泡内渲染 `TypingDots`。
    - 气泡**不得**使用 `BackdropFilter`，**不得**使用 `Shadow` 修饰文字，**不得**使用半透明气泡底。
  `TypingDots({int count = 3, Color color = AppPalette.warm})` 为 `StatefulWidget`，**内部**自建 `AnimationController(duration: 1200ms)..repeat()` 并在 `dispose()` 释放；点 6px、间距 5、相位差 .2、opacity .25→1。
  `MessageList({required List<Message> messages, required bool busy, required bool waitingFirstToken, required void Function(String) onOpenImage, ScrollController? controller, EdgeInsets? padding})` 为 `StatelessWidget`；`controller` 必须转交给 `ListView.builder`（否则 `_scrollToEnd` 静默失效——执行时已抓到并修复，commit c4f40bb）；`padding == null` 时使用 `EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top, 0, 20)`。**为什么只加 `padding.top`**：在 `extendBodyBehindAppBar: true` 下，Scaffold 已经把 body 的 `MediaQuery.padding.top` 改写成「AppBar 底边偏移」（= 状态栏 + AppBar 内容高度），再额外加 `ChatAppBar.height` 会重复算 68px（实测会变成 160 而不是 92）。`list` 的 `Message` 类型来自 `../main.dart`（`import '../main.dart' show Message;`，这是本计划**唯一**允许的分层反向引用，因为 `Message` 是现有纯数据模型，移动它会扩大改动面）；测试里只构造 `Message`，不 pump `FeiyuApp`。内部保留原 `ListView.builder` 的 `typing` 判定与 `_message` 视觉逻辑（把 `lib/main.dart:1874-1886` 搬过来，`itemCount`/`itemBuilder` 语义不变），以便脱离 `_ChatPageState` 单独测试。
  删除 `lib/main.dart:1958-1973` 的 `_etchShadows` 与 `_etched`、`lib/main.dart:2169-2191` 的 `_TypingDots`，以及 **`_dots` 字段（`lib/main.dart:427` 附近）、`initState` 里创建 `_dots` 并 `..repeat()` 的那行、`dispose()` 里对 `_dots` 的释放**——因为 `_dots` 的唯一使用者就是 `_TypingDots`，留着会让 `flutter analyze` 报 `unused_field`，而 Todo 15 也不再需要它。把 `_message`/`_userLine` 重写为对 `MessageBubble` 的薄封装（保留原签名与 `typing`/`isNewest`/`showLabel` 语义），`_messageList()` 改为返回 `MessageList(messages: _messages, busy: _busy, waitingFirstToken: _waitingFirstToken, onOpenImage: _openImage)`。
  Parallelization: Wave 2 | Blocked by: 2,4,5,7 | Blocks: 10,13,15 | Can parallelize with: 6,11,12
  References: `lib/main.dart:1888-2038`（现状全文）、`lib/main.dart:1874-1886`（`_messageList`）、`lib/main.dart:2169-2191`（`_TypingDots`）、`lib/main.dart:425-435` 与 `484-492`（`_dots` 的创建与释放）、`lib/main.dart:1941`（typing 分支）、`_openImage` `lib/main.dart:2040-2049`
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue（含无 `unused_field`）；`grep -n "_etchShadows\|_etched" lib/main.dart` 返回 0 行；`grep -n "_dots" lib/main.dart` 返回 0 行；`grep -n "Color(0x" lib/ui/bubble.dart` 返回 0 行；本 todo **创建** `test/bubble_test.dart` 与 `test/message_list_test.dart` 并断言：`mine: true` 时气泡右对齐（`tester.getCenter(bubble).dx > screenWidth/2`）、`mine: false` 时左对齐且存在 `AvatarMark`、`typing: true` 时存在 `TypingDots` 且 `content` 文本不被渲染、200 字中文在 390 宽下气泡宽度 ≤ 屏幕宽 × .80；`MessageList` 的默认 `padding.top` 在 `Scaffold(extendBodyBehindAppBar: true, appBar: ChatAppBar(...))` 场景下等于 body 的 `MediaQuery.padding.top`（测试里把状态栏设为 24、AppBar 内容 68 → 断言 92，**必须**在真实 Scaffold 里断言，不能拿裸 `MediaQuery` 自造）且 3 条消息渲染成功。
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/bubble_test.dart test/message_list_test.dart` 全部通过（只用 `tester.pump(Duration(...))`，**绝不使用 `pumpAndSettle`**，因为 `TypingDots` 有无限循环动画）；failure — 把 `maxWidth` 设为 `double.infinity`，宽度断言失败；把气泡色改回半透明 hex，`grep` 验收失败。Evidence `.omo/evidence/ui-redesign/task-9-companion-ui-redesign.md`
  Commit: Y | feat(ui): replace etched text with opaque message bubbles

- [x] 10. 时间分组：在 `MessageList` 里加 `_shouldShowTime(index)` + 居中时间标题
  What to do / Must NOT do: 在 `lib/ui/message_list.dart` 的 `itemBuilder` 中，当 `index == 0` 或 `messages[index].at.difference(messages[index - 1].at).inMinutes >= 5` 时，在气泡上方插入居中的 `Text(_timeLabel(m.at), style: AppType.caption.copyWith(color: AppPalette.text3))`，上下 padding 各 8。`Message.at` 已存在（`lib/main.dart:317-318` 字段与构造默认值，`toStore()` 在 `331-336` 持久化 `'at'`），**不要**新增或修改字段。分组间距：同一说话人连续消息 4px，切换说话人 14px。时间格式 `HH:mm`，跨天时前缀 `M月d日 `（自己写 3 行格式化，不引入 intl）。不得改变 `_messages` 的任何持久化字段。
  Parallelization: Wave 2 | Blocked by: 9 | Blocks: — | Can parallelize with: 11,12
  References: `lib/main.dart:317-336`（`Message.at` 字段、构造默认值与 `toStore()` 持久化）、`lib/ui/message_list.dart`（Todo 9 创建）、`lib/main.dart:1874-1886`（原 `_messageList`）、`lib/feeds/footprints.dart:39-50`（日期/时间格式参考，不得耦合足迹模块）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；本 todo **创建** `test/message_time_test.dart`：构造 3 条消息（间隔 1 分钟 / 6 分钟）断言时间标题恰好出现 2 次；`grep -n "intl" pubspec.yaml` 返回 0 行。
  QA scenarios: happy — `flutter test test/message_time_test.dart` 通过（时间标题 2 次）；failure — 把阈值改成 0，期望的 2 次会变成 3 次并失败。Evidence `.omo/evidence/ui-redesign/task-10-companion-ui-redesign.md`
  Commit: Y | feat(ui): add time grouping to the message list

- [x] 11. 新建 `lib/ui/empty_state.dart` 并替换 `_emptyState`
  What to do / Must NOT do: `EmptyState({required List<String> samples, required ValueChanged<String> onSample, String? buildTag})`：96 的 `AvatarMark(glow: true)`、标题「今天想聊点什么？」`AppType.title`、副文案 `caption` `text3`（保留原文案含 build tag 的形式：`'可以按麦克风说话，也可以发一张图给它看。  ·  $buildTag'`）、三个 `Pill` 示例（文案沿用 `['今天有什么好玩的', '帮我看看这张图', '你还记得我吗']`），`Wrap(spacing 8, runSpacing 10, alignment center)`。整体垂直居中、`SingleChildScrollView` 防溢出；**不要再套 `ContentFrame`**（外层 Todo 8 已经约束过宽度，再套会出现双倍 16px 内边距）。替换 `lib/main.dart:1820-1872`，保持 `_send(t)` 回调。
  Parallelization: Wave 2 | Blocked by: 4,5 | Blocks: — | Can parallelize with: 9,10,12
  References: `lib/main.dart:1820-1872`（现状全文）、`lib/main.dart:1821`（samples 常量）、`lib/main.dart:1844`（build tag 文案）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "🐟" lib/ui/empty_state.dart` 返回 0 行；本 todo **创建** `test/empty_state_test.dart` 断言三个示例文案都可见、点击第一个回调收到 `'今天有什么好玩的'`。
  QA scenarios: happy — 空会话截图显示鱼形标记与三个胶囊（视觉证据见 `.omo/evidence/ui-redesign/shots/empty-*.png`）；failure — 移除 `onSample` 回调后 `empty_state_test.dart` 的 tap 断言失败。Evidence `.omo/evidence/ui-redesign/task-11-companion-ui-redesign.md`
  Commit: Y | feat(ui): rebuild the empty state with a drawn avatar

- [x] 12. 错误条改用 `InlineNotice`
  What to do / Must NOT do: `_errorBar()`（`lib/main.dart:1796-1818`）改为 `Padding(padding: EdgeInsets.fromLTRB(12, 8, 12, 4), child: InlineNotice(tone: NoticeTone.danger, message: _error!, onDismiss: () => setState(() => _error = null)))`；**不要再套 `ContentFrame`**（外层 Todo 8 已约束宽度）。文案保持 `SelectableText` 的「可选中复制」能力（`InlineNotice` 内部用 `SelectableText` 承载 message）。不得改变 `_error` 的赋值点与清除时机。
  Parallelization: Wave 2 | Blocked by: 5 | Blocks: — | Can parallelize with: 9,10,11
  References: `lib/main.dart:1796-1818`
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "0xFF3B1D22\|0xFF7A2A35" lib/main.dart` 返回 0 行；本 todo **创建** `test/error_notice_test.dart`，直接 `pumpWidget` 一个含 `InlineNotice(tone: NoticeTone.danger, message: 'x', onDismiss: ...)` 的页面，断言点关闭后回调触发，且 320 宽下 `takeException()` 为 null。
  QA scenarios: happy — `flutter test test/error_notice_test.dart` 通过；failure — 移除 `onDismiss` 后关闭按钮消失，测试的 tap 断言失败。Evidence `.omo/evidence/ui-redesign/task-12-companion-ui-redesign.md`
  Commit: Y | refactor(ui): restyle the error bar with InlineNotice

### Wave 3 - Chat interaction

- [x] 13. 新建 `lib/ui/composer.dart` 并替换 `_composer`
  What to do / Must NOT do: `Composer({required TextEditingController controller, required bool busy, required bool listening, required VoidCallback onImage, required VoidCallback onMic, required VoidCallback onSend, required VoidCallback onStop, required ValueChanged<String>? onSubmitted, String hint = '和大肥鱼说点什么…'})`：外层 `Padding(10,4,10,10)` + **唯一一处** `SafeArea(top: false)` + `ClipRRect(radius AppRadii.pill)` + **唯一一处** `BackdropFilter(sigma 18)` + `Container(color: AppPalette.composerSurface, border: lineStrong @ .10, radius AppRadii.pill, shadow soft)`；行内：`GhostIconButton(icon: Icons.add_photo_alternate_outlined, tooltip: '发图片', onPressed: busy ? null : onImage)`、`Expanded(TextField(...))`、`GhostIconButton(icon: listening ? Icons.stop_circle_outlined : Icons.mic_none, tooltip: listening ? '停止' : '说话', onPressed: busy ? null : onMic)`、右侧 `busy ? GhostIconButton(icon: Icons.stop_circle, tooltip: '停止生成', color: AppPalette.danger, onPressed: onStop) : 42 圆形渐变发送钮(icon: Icons.arrow_upward, tooltip: '发送', onPressed: onSend)`。`busy` 时图片与麦克风按钮 `onPressed: null`。监听态 hint 改为「正在听…」，麦克风图标染 `primary`。**必须**保留原有全部回调与禁用条件（`_busy ? null : ...`）。**安全区只在这里做一次**——调用方（聊天页 Column）不要再包 `SafeArea`，否则底部会出现双倍内边距。
  Parallelization: Wave 3 | Blocked by: 5,9 | Blocks: 15 | Can parallelize with: 14
  References: `lib/main.dart:2089-2166`（现状全文）、`lib/main.dart:2090-2093`（现有唯一 `SafeArea(top:false)`，迁移后聊天页不再保留）、`lib/main.dart:2112-2117`（图片）、`2135-2140`（麦克风）、`2141-2158`（发送/停止）、`lib/main.dart:2124`（`onSubmitted: (_) => _send()`）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -c "BackdropFilter" lib/main.dart` 返回 0 且 `grep -c "BackdropFilter" lib/ui/composer.dart` 返回 1；`grep -c "SafeArea(" lib/main.dart` ≤ 1 且该处不得包裹聊天页 `Column`（安全区只在新组件里）；本 todo **创建** `test/composer_test.dart` 断言：`busy: false` 时发送按钮可点且 `onSend` 被调用一次；`busy: true` 时出现停止按钮、发送按钮不存在、图片按钮 `onPressed == null`。
  QA scenarios: happy — `flutter test test/composer_test.dart` 全部通过，且三行文本输入后 `tester.takeException()` 为 null；failure — 忘记在 `busy` 时禁用图片按钮，`onImage == null` 断言失败。Evidence `.omo/evidence/ui-redesign/task-13-companion-ui-redesign.md`
  Commit: Y | feat(ui): rebuild the composer with a single glass layer

- [x] 14. 待发送图片条与聆听条重做（`lib/ui` 内）
  What to do / Must not do: 新建 `lib/ui/attachments.dart`：`PendingImageBar({required Uint8List bytes, required VoidCallback onRemove})`（54×54 圆角 12 缩略图 + `caption` 文案「图片已就绪」+ 44px 关闭钮，整体在 `ContentFrame` 内、浅色 info 底）；`ListeningBar({required String hint})` 为 `StatefulWidget`，**内部**自建 `AnimationController(duration: 1200ms)..repeat(reverse: true)` 并在 `dispose()` 释放（不要外部传入 Animation，避免与 Todo 15 的时序耦合）：左侧 3 根按相位缩放的竖条（高 6〜14），颜色 `primary`，文案 `caption` `text3`，`maxLines 1` + ellipsis。替换 `lib/main.dart:2051-2067` 与 `2069-2087`，`_voiceHint` 语义不变（为空时显示「正在听…」）。
  Parallelization: Wave 3 | Blocked by: 5,7 | Blocks: 15 | Can parallelize with: 13
  References: `lib/main.dart:2051-2067`（`_pendingImageBar`）、`lib/main.dart:2069-2087`（`_listeningBar`）、`lib/main.dart:2061`（文案）、`lib/main.dart:2078`（`_voiceHint`）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "graphic_eq" lib/main.dart` 返回 0 行；本 todo **创建** `test/attachments_test.dart`：在 320×640 下渲染 `PendingImageBar`（用 1×1 PNG 字节）与 `ListeningBar(hint: '正' * 120)`，断言两条状态栏均单行（`Text.maxLines == 1`）且 `takeException()` 为 null；只 `pump(Duration(...))`，禁止 `pumpAndSettle`。
  QA scenarios: happy — `flutter test test/attachments_test.dart` 通过；failure — 传入 120 字 `hint` 且去掉 ellipsis，`takeException()` 非 null 即失败。Evidence `.omo/evidence/ui-redesign/task-14-companion-ui-redesign.md`
  Commit: Y | feat(ui): restyle attachment and listening bars

- [x] 15. 动效：入场、流式光标、发送按压、状态点脉冲、滚动到底按钮
  What to do / Must NOT do: (a) 最新气泡入场用 `TweenAnimationBuilder` 做 opacity .6→1 + `Transform.translate(y 6→0)`，200ms `easeOutCubic`，key 仍为 `ValueKey(m)`，**只在 `index == messages.length - 1` 时包**（否则历史消息每次 rebuild 都会重放）；(b) 流式光标：新建 `StreamingCaret` 组件（放 `lib/ui/bubble.dart`），**内部**自建 `AnimationController(duration: 1200ms)..repeat(reverse: true)` 并在 `dispose()` 释放；渲染为 2×16 圆角 `warm` 竖条、`Key('streaming-caret')`；当 `_busy && !_waitingFirstToken` 且最后一条是 assistant 时，通过 `MessageBubble` 的 `trailing` 传入。**不要在 `_ChatPageState` 里新建任何 `AnimationController`**——该类仍是 `SingleTickerProviderStateMixin`（`lib/main.dart:400`），第二个 ticker 会直接断言崩溃；`_dots` 已在 Todo 9 删除，所以本 todo 不得再引用它；(c) 发送钮 `AnimatedScale(scale: pressed ? .96 : 1, duration 120ms)`；(d) `StatusDot` 的脉冲由 `mood == SceneMood.thinking` 驱动（`ChatAppBar` 的签名已经固定为只收 `mood`，**不要**再给它加 `busy` 参数）：thinking 时用 `warm` 并以 1400ms 呼吸，其余按 Todo 7 的 mood→颜色映射（脉冲动画在 `StatusDot` 组件内部自建 controller 并 dispose）；(e) 滚动到底：`_scroll` 增加 `_onScroll` listener（**在 `initState` 里加一次**，不要在 `build` 里加），`_showJump = _scroll.hasClients && _scroll.offset < _scroll.position.maxScrollExtent - 240`，在消息区右下 `Positioned(right: 12, bottom: 8)` 放 40 圆形按钮（`arrow_downward`，`onPressed: _scrollToEnd`），`AnimatedOpacity` 200ms。**必须在 `dispose()` 里 `_scroll.removeListener(_onScroll)`**，并且 `_onScroll` 内先判 `if (!mounted) return;`。**不得**改变 `_scrollToEnd` 的既有动画参数与调用点。
  Parallelization: Wave 3 | Blocked by: 8,9,13,14 | Blocks: 25 | Can parallelize with: 16
  References: `lib/main.dart:1948-1955`（现有入场动画）、`lib/main.dart:493-504`（`_scrollToEnd`）、`lib/main.dart:402`（`_scroll` 控制器）、`lib/main.dart:400`（`SingleTickerProviderStateMixin`）、`lib/main.dart:427-435/484-492`（`_dots`，Todo 9 已删）、`lib/main.dart:1483-1489`（忙碌态文案）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "_scroll.removeListener" lib/main.dart` 命中 1 处；`grep -c "AnimationController(" lib/main.dart` 结果为 0（所有 controller 都在 `lib/ui/` 组件内部）；本 todo **创建** `test/motion_test.dart`：用 `pump(Duration(milliseconds: 300))` 后断言最新气泡 `opacity == 1`，并在 `busy` 时找到 `Key('streaming-caret')`；`flutter test` 无「A Timer is still pending」「Ticker was still active」「setState after dispose」。
  **测试纪律：任何渲染 `TypingDots`/`StreamingCaret`/`StatusDot(pulse: true)`/`ListeningBar` 的测试都禁止使用 `pumpAndSettle`（无限循环动画永不 settle），只用 `pump(Duration(...))`。**
  QA scenarios: happy — 动画行为由 `motion_test.dart` 断言（t=300ms 后最新气泡不透明度为 1、busy 时存在 `Key('streaming-caret')`），不另录屏；failure — 删除 controller 的 `dispose()`，`flutter test` 在 teardown 报 "AnimationController was not disposed" 并失败。Evidence `.omo/evidence/ui-redesign/task-15-companion-ui-redesign.md`
  Commit: Y | feat(ui): add entrance, streaming caret and scroll-to-bottom

### Wave 4 - Secondary screens

- [x] 16. 设置页外壳：AppBar（保存按钮）、分组容器、可滚动布局
  What to do / Must NOT do: `lib/main.dart:2427-2912` 的 build 改为：`Scaffold(backgroundColor: AppPalette.ink, appBar: AppBar(title: const Text('设置'), actions: [Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton(onPressed: _save, child: const Text('保存')))]), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [...]))`。
  **顶层分组固定为 7 张卡，顺序与归属如下（不要再自创第 8 张）**：
  1. `模型`：厂商 / Base URL / API Key / 模型下拉 / 手填模型 / 拉取状态
  2. `人设`：persona 多行输入
  3. `语音`：卡内用 `SectionHeader` 分三段——`语音朗读`（开关/引擎/音色/语速/下载）、`语音识别`（预设/离线模型/Base/Key/转写模型）、`看图模型`（开关/provider/base/key/model）
  4. `记忆与会话`：自动记忆开关 / 记忆列表 / 主动开口开关 + 空闲分钟
  5. `场景`：场景开关 / 房间背景下拉 / 压暗滑块
  6. `ComfyUI`：地址 + 测试连接 + 状态 + 三个工作流
  7. `关于`：build 标记 / 自检 / 隐私说明
  分组子项之间统一 `SizedBox(height: 14)`；分组之间 `SizedBox(height: 16)`。每张卡必须带稳定 key：`settings-section-model` / `-persona` / `-voice` / `-memory` / `-scene` / `-comfy` / `-about`（`SectionCard(key: ValueKey('settings-section-model'), ...)`）。**同时删除与分组标题同名的那条字段标签**：实际仓库里唯一的匹配是 `lib/main.dart:2509` 的 `const _Label('模型')`（它是「模型」下拉的字段标签，不是独立分组标题）；删掉它，因为新的 `SectionCard(title: '模型')` 已经是分组标题、下拉标签由 Todo 17 的 `SettingsRow` 接管。只删这一条标签、不动控件，**不要删 `_Label` 类**（其余标签承载真实说明文案）。**本 todo 只做外壳与分组迁移，不改任何字段控件**——把现有控件原样搬进对应 `SectionCard` 后，后续 todo 逐个替换控件样式。
  Parallelization: Wave 4 | Blocked by: 5 | Blocks: 17,24 | Can parallelize with: 22,23
  References: `lib/main.dart:2427-2912`（完整 build）、`lib/main.dart:2434-2436`（ListView）、`_save` `lib/main.dart:2392-2425`（不得改）、`_Label` `lib/main.dart:2915-2925`（本 todo 后删除）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -c "SectionCard(" lib/main.dart` 结果恰为 7；`grep -n "const _Label('模型')" lib/main.dart` 返回 0 行（只删与分组标题同名的那一条，**不要删 `_Label` 类**——其余标签承载真实说明文案，例如「Base URL（OpenAI 兼容…）」，由 Todo 17-20 的 `SettingsRow` 接管）；本 todo **创建** `test/settings_structure_test.dart`，用 `pumpWidget(MaterialApp(theme: AppTheme.dark(), home: SettingsPage(initial: Settings(baseUrl: 'https://x/v1', apiKey: '', model: 'm', persona: 'p'), memory: Memory())))` 断言 7 张卡的 `Key`（`settings-section-model/persona/voice/memory/scene/comfy/about`）各恰好 1 个；`_save` 的 diff 必须为空（`git diff` 中 `_save` 函数体零改动）。
  QA scenarios: happy — `flutter test test/settings_structure_test.dart` 通过（7 个稳定 key 各 1 次）；failure — 删掉「场景」分组的包裹，key 断言失败。Evidence `.omo/evidence/ui-redesign/task-16-companion-ui-redesign.md`
  Commit: Y | refactor(settings): group settings into section cards

- [x] 17. 设置·模型分组重做（厂商 / Base URL / Key / 模型）
  What to do / Must NOT do: 把 `lib/main.dart:2460-2557` 的控件替换为 `SettingsRow` 包裹：厂商 `DropdownButtonFormField`（`isExpanded`、`AppType.bodySmall` 项目文字）、Base URL `TextField`、API Key `TextField(obscureText, suffixIcon: IconButton(tooltip: '刷新模型列表', ...))`、模型 `DropdownButtonFormField` + 手填 `TextField`；「已拉取 N 个模型」改成 `Pill(label: '已拉取 $_models.length 个模型', tone: PillTone.success)`。`_modelError` 改成 `InlineNotice(tone: NoticeTone.danger)`。**不得**改 `_loadModels`、`providerById` 跳转逻辑、controller 名称、`onChanged` 副作用。
  Parallelization: Wave 4 | Blocked by: 16 | Blocks: 18 | Can parallelize with: 22,23
  References: `lib/main.dart:2460-2484`（厂商下拉与切换逻辑）、`2486-2507`（Base/Key）、`2509-2557`（模型下拉+手填+计数）、`_loadModels` `lib/main.dart:2368-2390`、`_modelError` 渲染 `2510-2514`
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`git diff -U0 lib/main.dart` 中 **`_loadModels(` 与 `providerById(` 的函数定义体**不出现（即这两个函数未被修改；允许其调用点因包进 `SettingsRow` 而缩进变化）；本 todo **创建** `test/settings_model_test.dart` 断言切换厂商后 `_base.text` 变为该预设 `baseUrl`。
  QA scenarios: happy — `flutter test test/settings_model_test.dart` 通过（切换厂商后 baseUrl 字段断言）；设置页整页视觉证据见 `.omo/evidence/ui-redesign/shots/settings-*.png`；failure — 把 `onChanged` 里的 `_loadModels()` 删掉，模型测试的「切换后触发拉取」断言失败。Evidence `.omo/evidence/ui-redesign/task-17-companion-ui-redesign.md`
  Commit: Y | feat(settings): restyle the model section

- [x] 18. 设置·人设 + `语音`卡内三段（语音朗读 / 语音识别 / 看图模型）重做
  What to do / Must NOT do: 人设 `TextField(minLines 5, maxLines 12)` 放进 `SettingsRow`；语音朗读：`SwitchListTile` → 自定义 `Switch` 行（标题 `bodySmall` text1、副标题 `caption` text3、`contentPadding: zero`），引擎/音色两个 `DropdownButtonFormField`、语速 `Slider` 右侧数值 `caption`、下载按钮 `TextButton.icon`；`_downloadingTts` 时显示 `LinearProgressIndicator(value: _ttsProgress)` + 百分比；ASR：预设下拉、`local` 时离线模型下拉、非 `same/local` 时 Base/Key 输入、转写模型输入；看图：开关 + provider/base/key/model 四个输入。**不得**改任何字段名、`_save` 载荷、`LocalTtsImpl.voices`/`LocalAsrImpl.models` 的读取方式、`_downloadTts` 与 `_testComfy` 的行为。
  Parallelization: Wave 4 | Blocked by: 17 | Blocks: 19,20,21 | Can parallelize with: 22,23
  References: `lib/main.dart:2559-2560`（人设）、`2562-2629`（TTS）、`2630-2682`（ASR）、`2683-2728`（看图）、`_downloadTts` `lib/main.dart:2347-2366`、`LocalTtsImpl.voices` `lib/voice/local_tts_web.dart:6-15`
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`git diff` 中 `_downloadTts`、`_save` 零改动；本 todo **创建** `test/settings_voice_test.dart` 断言打开「语音朗读」后出现引擎下拉、切到 `local` 后出现音色下拉与下载按钮。
  QA scenarios: happy — `flutter test test/settings_voice_test.dart` 通过（开关后才出现引擎/音色/下载控件）；整页视觉证据见 `.omo/evidence/ui-redesign/shots/settings-*.png`；failure — 把 `if (_ttsEnabled)` 条件删掉，语音测试的「初始不显示引擎下拉」断言失败。Evidence `.omo/evidence/ui-redesign/task-18-companion-ui-redesign.md`
  Commit: Y | feat(settings): restyle voice, ASR and vision sections

- [x] 19. 设置·记忆与会话 / 场景 两组重做
  What to do / Must NOT do: 记忆：`SwitchListTile` 自动记忆 + 副标题；显示「现在记得 N 条」+ 事实列表（每条 `bodySmall` text2，前置 6px `primary` 圆点，而不是 `·` 字符）；空态文案保留。主动开口：开关 + 空闲滑块（右侧分钟数 `caption`）。场景：开关、房间背景下拉（`FutureBuilder<List<String>>` 保留）、压暗滑块（百分比 `caption`）；`dim` 的取值与回调不变。**不得**改 `_proactiveIdleMinutes`/`_sceneDim` 的 clamp 与 divisions。
  Parallelization: Wave 4 | Blocked by: 18 | Blocks: 20,21 | Can parallelize with: 22,23
  References: `lib/main.dart:2813-2865`（场景）、`2866-2894`（主动）、`2895-2903`（记忆列表）、`_sceneChoices`/`_sceneLabel` `lib/main.dart:2300-2318`
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；本 todo **创建** `test/settings_scene_test.dart` 断言关闭场景开关后房间背景下拉消失、压暗滑块消失；`git diff` 中 `_sceneChoices` 零改动。
  QA scenarios: happy — `flutter test test/settings_scene_test.dart` 通过（关闭开关后下拉与滑块消失）；整页视觉证据见 `.omo/evidence/ui-redesign/shots/settings-*.png`；failure — 把 `if (_sceneEnabled)` 改成 `if (true)`，场景测试的「关闭后下拉消失」断言失败。Evidence `.omo/evidence/ui-redesign/task-19-companion-ui-redesign.md`
  Commit: Y | feat(settings): restyle memory, proactive and scene sections

- [x] 20. 设置·ComfyUI 分组重做
  What to do / Must NOT do: 地址输入 + 「测试连接」`TextButton.icon` + 状态用 `InlineNotice(tone: _comfyTesting ? NoticeTone.info : (_comfyStatus.contains('连不上') ? NoticeTone.danger : NoticeTone.success))`；三个工作流输入（文生图 / 去背景 / 图片编辑）+ 两个「填入示例」按钮；`helperText` 保留原文案。**不得**改 `_testComfy` 逻辑与示例 JSON 内容（`kComfySdTurboWorkflow` / `kComfyImg2ImgWorkflow`）。
  Parallelization: Wave 4 | Blocked by: 19 | Blocks: 21 | Can parallelize with: 22,23
  References: `lib/main.dart:2731-2812`（Comfy 设置组）、`_testComfy` `lib/main.dart:2320-2345`、`lib/main.dart:48-68`（示例工作流常量）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "填入示例（SD-Turbo）" lib/main.dart` 命中 1 处（文案未丢）；`_testComfy` 零改动（`git diff`）；本 todo **创建** `test/settings_comfy_test.dart` 渲染设置页中的 Comfy 卡，断言「测试连接」按钮与三个工作流输入均存在、320 宽下 `takeException()` 为 null。
  QA scenarios: happy — `flutter test test/settings_comfy_test.dart` 通过；failure — 移除 `_comfyStatus` 的渲染条件，状态断言失败。Evidence `.omo/evidence/ui-redesign/task-20-companion-ui-redesign.md`
  Commit: Y | feat(settings): restyle the ComfyUI section

- [x] 21. 设置·关于分组：自检、隐私说明、构建标记
  What to do / Must NOT do: 把 `lib/main.dart:2437-2459` 的自检卡内容**移入 Todo 16 已经创建的那张「关于」卡**（不要再新建第二张 `SectionCard`）：一个 `Pill(label: 'build $kBuildTag')` + `SelectableText` 等宽 `AppType.mono` `text3` 的自检块（内容与原来逐字一致：build/baseUrl/model/key 长度二行不少）+ 隐私说明（原文案 `'所有数据只存在这台设备上：Key、对话、记忆都不经过任何第三方服务器。'`）+ 版本号 `0.8.0+8`（可硬编码，不引入 package_info_plus）。**不得**移除自检内容，**不得**把 key 明文显示（已是长度），**不得**让 `grep -c "SectionCard(" lib/main.dart` 从 7 变成 8。
  Parallelization: Wave 4 | Blocked by: 20 | Blocks: 24 | Can parallelize with: 22,23
  References: `lib/main.dart:2437-2459`（自检卡）、`2895-2908`（记忆统计与隐私文案）、`lib/main.dart:27-34`（`kBuildTag`）、`pubspec.yaml:19`（version）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "所有数据只存在这台设备上" lib/main.dart` 命中 1 处；`grep -n "kBuildTag" lib/main.dart` ≥ 1；本 todo **创建** `test/settings_about_test.dart` 断言自检块文本包含 `build=` 与 `key长度=`，且 `SectionCard` 数量仍为 7。
  QA scenarios: happy — `flutter test test/settings_about_test.dart` 通过（self-check 文本、隐私句、7 张卡）；整页视觉证据见 `.omo/evidence/ui-redesign/shots/settings-*.png`；failure — 删掉自检 `SelectableText`，about 测试失败。Evidence `.omo/evidence/ui-redesign/task-21-companion-ui-redesign.md`
  Commit: Y | feat(settings): add an about section with the self-check block

- [x] 22. 足迹页重做（`lib/feeds/footprints_page.dart`）
  What to do / Must NOT do: `Scaffold(backgroundColor: AppPalette.ink)`、`AppBar(backgroundColor: Colors.transparent, scrolledUnderElevation: 0, title: const Text('她的足迹'), actions: [GhostIconButton(icon: Icons.auto_awesome_outlined, tooltip: '补记一个瞬间', onPressed: _working ? null : _add)])`；body 用 `ContentFrame` + `ListView`；日期分组标题改为 `AppType.label`（`text3`，letterSpacing 1.2）+ 右侧 `Expanded(Divider(color: line))`；卡片 `Container(color: AppPalette.surfaceAlt, radius AppRadii.xl, padding 16, border line)`：顶部 `AvatarMark(size: 28)` + 标题 `subtitle` + 时间 `caption` `text3`；正文 `bodySmall.copyWith(fontSize 14, height 1.7, color: text2)`；右下心情用 `Pill(label: f.mood)`。空状态：`AvatarMark(size: 72)` + 原文案 + `text3`。**不得**改 `_add`/`onDistill`/分组逻辑/`Footprint` 字段。
  Parallelization: Wave 4 | Blocked by: 4,5 | Blocks: 24 | Can parallelize with: 16-21,23
  References: `lib/feeds/footprints_page.dart:37-113`（build）、`115-164`（`_card`）、`lib/feeds/footprints.dart:7-51`（模型，只读）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "🐟" lib/feeds/footprints_page.dart` 返回 0 行；`grep -n "0xFF0B1220\|0xFF101A2C\|0xFF16223A" lib/feeds/footprints_page.dart` 返回 0 行；本 todo **创建** `test/footprints_test.dart` 用 3 条假 `Footprint` 渲染页面，断言 3 个标题可见、心情 `Pill` 渲染、空列表时显示空态文案，两次 `takeException()` 均为 null。
  QA scenarios: happy — `flutter test test/footprints_test.dart` 通过（有数据态 + 空态各一次）；failure — 把卡片颜色改回裸 hex，上述 `grep` 验收失败。Evidence `.omo/evidence/ui-redesign/task-22-companion-ui-redesign.md`
  Commit: Y | feat(footprints): restyle her moments page

- [x] 23. ComfyUI 页重做（`lib/comfy/comfy_page.dart`）
  What to do / Must NOT do: `Scaffold(backgroundColor: ink)` + 透明 AppBar（`refresh` 用 `GhostIconButton`）；body `ContentFrame` + `ListView`；状态卡：**列布局**（第一行 `StatusDot` + 状态文案 `bodySmall`；第二行 baseUrl `caption` `text3`；连不上时第三行 help `caption` `warm`）——必须修掉现有 `Row` 在 320 宽下的横向挤压；提示词/反向提示词用主题化 `TextField`（`maxLines 6/2`、`labelText` 保留）；按钮行：`PrimaryButton(label: '生成', loading: _busy, onPressed: _busy || !_online ? null : _generate)` + `TextButton(onPressed: _online ? () async { await _client.clearQueue(); await _refresh(); } : null, child: const Text('清队列'))`；`_busy` 时 `LinearProgressIndicator` + `_stage` 文案；错误用 `InlineNotice(tone: NoticeTone.danger)`；结果图改为 `LayoutBuilder`：宽 ≥ 600 时 2 列 `GridView`（`shrinkWrap`, `NeverScrollableScrollPhysics`, `spacing 12`），否则单列；点击仍 `_openFull`。**不得**改 `ComfyClient` 协议、`_generate` 流程、`patchWorkflow`、`jsonDecodeMap`。
  Parallelization: Wave 4 | Blocked by: 5 | Blocks: 24 | Can parallelize with: 16-22
  References: `lib/comfy/comfy_page.dart:118-203`（build）、`216-255`（`_statusCard`）、`lib/comfy/comfy.dart`（客户端，只读）、`_openFull` `lib/comfy/comfy_page.dart:205-214`
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -n "0xFF0B1220\|0xFF101A2C\|0xFF16223A\|0xFF6BD08B\|0xFFFF9A9A\|0xFFFF8A8A" lib/comfy/comfy_page.dart` 返回 0 行；本 todo **创建** `test/comfy_layout_test.dart` 在 320 宽下 `takeException()` 为 null（`ComfyPage` 的 `_refresh` 在 widget test 里走 flutter_test 的假 HttpClient，会立即返回失败，不触真网）；`_generate`/`_client` 零改动。
  QA scenarios: happy — 320 宽「连不上」状态截图，帮助文案换行而非被挤成竖排；failure — 恢复旧的 `Row` 布局，`comfy_layout_test.dart` 在 320 宽下报 overflow。Evidence `.omo/evidence/ui-redesign/task-23-companion-ui-redesign.png`
  Commit: Y | feat(comfy): restyle the drawing console

### Wave 5 - Hardening

- [x] 24. 弹层统一：图片查看、图片来源选择、提示条
  What to do / Must NOT do: `_openImage`（`lib/main.dart:2040-2049`）与 Comfy `_openFull`（`lib/comfy/comfy_page.dart:205-214`）统一为同一 `showImageViewer(context, bytes)` 工具（放 `lib/ui/overlays.dart`）：黑底、`insetPadding 8`、`InteractiveViewer`、右上角 44px 关闭钮（`Icons.close`, white 70%）、轻触背景关闭；图片来源 `_imageSheet` 用 `showModalBottomSheet` 统一底色/圆角/行高（`ListTile` 两个选项文案不变）；所有 `SnackBar` 走 `snackBarTheme`（floating、radius 14、`surfaceHi`）。**不得**改图片来源选项的行为（相机/相册）与错误处理。
  Parallelization: Wave 5 | Blocked by: 16,17,18,19,20,21,22,23 | Blocks: 25,26 | Can parallelize with: —
  References: `lib/main.dart:2040-2049`（`_openImage`）、`lib/main.dart` 中 `_imageSheet`（`grep -n "_imageSheet" lib/main.dart`）、`lib/comfy/comfy_page.dart:205-214`、`lib/main.dart:30-...`（SnackBar 调用点以 `grep -n "showSnackBar" lib/main.dart lib/feeds/footprints_page.dart` 全量列出）
  Acceptance criteria (agent-executable): `flutter analyze` 0 issue；`grep -c "InteractiveViewer" lib/main.dart` 返回 0（已抽象）；本 todo **创建** `test/overlays_test.dart` 打开 `showImageViewer` 后断言关闭钮的 `tester.getSize` ≥ 44×44 且点击后对话框消失；`grep -c "InteractiveViewer" lib/comfy/comfy_page.dart` 返回 0。
  QA scenarios: happy — `flutter test test/overlays_test.dart` 通过；failure — 把关闭钮缩到 20px，`getSize` 断言失败。Evidence `.omo/evidence/ui-redesign/task-24-companion-ui-redesign.md`
  Commit: Y | feat(ui): unify image viewer, sheets and snackbars

- [x] 25. 可访问性与文本缩放加固
  What to do / Must NOT do: (a) 所有纯图标按钮必须带非空 `tooltip`（含新组件内部）；(b) 图片 `Image.memory` 包 `Semantics(label: ...)`（消息图「图片消息」、Comfy 结果「生成结果」、缩略图「待发送图片」）；(c) 检查所有 `Container(height: ...)` 包裹文本的地方改为 padding（`grep -n "height: 22\|height: 16" lib/main.dart lib/ui/*.dart` 逐一确认）；(d) `textScaler = 1.3` 下跑 320 宽：用 widget test（`MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(1.3)), ...)`）断言不溢出；(e) 对比度由 Todo 6 的 `contrast_test.dart` 守住——**不得把这些 token 的 alpha 降到 Design spec 声明的值以下**（`text3` 固定 50%，已经算过：40% 只有 3.76:1、44% 只有 4.34:1，都达不到 4.5:1）。不得引入 `flutter_semantics` 之类新包。
  Parallelization: Wave 5 | Blocked by: 15,24 | Blocks: 26 | Can parallelize with: —
  References: `lib/main.dart:2063`（无 tooltip 的关闭按钮示例）、`lib/main.dart:2112-2117`/`2135-2140`（已有 tooltip 的先例）、`test/widget_test.dart` 之外无 a11y 测试；WCAG 对比度公式 https://www.w3.org/WAI/WCAG22/Techniques/general/G18
  Acceptance criteria (agent-executable): 本 todo **创建** `test/a11y_test.dart`：**逐个** pump `ChatAppBar`、`Composer`、`EmptyState`、`MessageBubble`（含图片）、`SectionCard` 的组件页，断言这些组件内部的每个 `IconButton` 实例 `tooltip != null && tooltip!.isNotEmpty`（不扫整页，避免把 Flutter 内置按钮误判）；**创建** `test/text_scale_test.dart` 在 `textScaler: 1.3` + 320×640 下渲染 `MessageList`/`Composer`/`SectionCard`，断言 `takeException()` 为 null；对比度数值（8 组）由 Todo 6 的 `contrast_test.dart` 覆盖并写入 `.omo/evidence/ui-redesign/task-25-companion-ui-redesign.md`。
  QA scenarios: happy — `flutter test test/a11y_test.dart test/text_scale_test.dart` 通过；failure — 把 `text3` alpha 降到 .20，`contrast_test.dart` 的对比度断言失败。Evidence `.omo/evidence/ui-redesign/task-25-companion-ui-redesign.md`
  Commit: Y | fix(a11y): semantics, tap targets and text scaling

- [x] 26. 响应式与真实截图 QA（320 / 390 / 768 / 1280）
  What to do / Must NOT do: 依次构建并用本地服务器验证：`flutter pub get` → `flutter build web --release --base-href /` **在仓库根目录**（不要用 `tools/build-web.ps1`，它构建的是同级 `feiyu_app`）→ `node server/server.mjs`（默认 8090）。用浏览器在 4 个视口各截 3 张：空状态、有消息、设置页。
  假对话注入（**必须确定，不能靠竞态**）：声明字段 `bool _preview = false;`，在 `_ChatPageState.initState` 里**第一行**赋值 `_preview = kIsWeb && Uri.base.queryParameters['seed'] == '1';`；在 `ChatStore.load().then(...)` 的回调里，**先**判断 `if (_preview) { setState(() => _messages = List.of(kPreviewMessages)); return; }`，即预览模式下**完全不应用已保存历史**（既避免竞态，也不会把用户的真实对话截进证据图）。`kPreviewMessages` 是 `lib/main.dart` 里的顶层 `final List<Message>`（**不能用 `const`：`Message` 没有 const 构造且 `content` 可变**），6 条中英混合消息均显式传 `at:`（含 1 张 1×1 base64 小图）；`_preview` 为真时**不启动** `_idleTimer`（主动消息不会触发），且全程**不得**调用 `ChatStore.save`。截图判据：无 `RenderFlex overflowed` 控制台日志、内容在 1280 下宽度 ≤ 720、AppBar 图标不换行、输入栏可见。**不得**为了截图而改动无参启动路径的行为；代码注释写明「debug-only preview, never persisted」。该分支是 Must NOT 里已声明的唯一新增非视觉代码。
  Parallelization: Wave 5 | Blocked by: 24,25 | Blocks: 27, F3
  References: `server/server.mjs`（本地托管与 `/v1` 反代；默认服务 `../build/web` 即本仓库构建产物）、`README.md:37-42`（构建与启动命令）、`lib/main.dart:431-500`（`initState` 与 `ChatStore.load` 回调）、`lib/main.dart:1350-1360`（`_idleTimer` 安排）、`tools/build-web.ps1:1-10`（**反例**：证明该脚本构建的是同级 `feiyu_app`，本计划不得使用）
  Acceptance criteria (agent-executable): 12 张截图 + 一份 `task-26-companion-ui-redesign.md` 记录每个视口的关键测量（截图宽高、内容区宽度、是否出现 `RenderFlex overflowed` 控制台日志）；`flutter build web --release --base-href /` 退出码 0。
  QA scenarios: happy — 12 张截图由执行代理按可判定清单逐条核对（内容区实测宽度 ≤ 720、控制台无 `RenderFlex overflowed`、无横向滚动条、输入栏在视口内），结论与证据写入证据文件；failure — 把 `ContentFrame` 的 `maxWidth` 设为 2000，1280 视口的内容宽度测量 > 720，此项失败。Evidence `.omo/evidence/ui-redesign/task-26-companion-ui-redesign.md` + `.png`×12
  Commit: Y | test(ui): add seeded preview mode and responsive screenshots

- [x] 27. 补全并全仓运行 UI 测试集（各 todo 已自建其验收测试）
  What to do / Must NOT do: 确认 `test/widget_test.dart` 已被 Todo 1 删除（若仍在则删除）。把前面各 todo **已创建**的测试补全为完整断言（`theme_test`、`tokens_test`、`avatar_mark_test`、`bubble_test`、`message_list_test`、`composer_test`、`empty_state_test`、`message_time_test`、`chat_app_bar_test`、`surfaces_test`、`error_notice_test`、`attachments_test`、`layout_test`、`contrast_test`、`motion_test`、`settings_structure_test`、`settings_model_test`、`settings_voice_test`、`settings_scene_test`、`settings_comfy_test`、`settings_about_test`、`footprints_test`、`overlays_test`、`comfy_layout_test`、`a11y_test`、`text_scale_test`），并**全仓运行一次**。**不得**把任何前置 todo 的验收推迟到这里；**不得**写只做字符串搜索的「测试」。另加一条纯色检查（**范围严格限定**，不要扫全仓）：`grep -rn "Color(0x" lib/ui lib/main.dart lib/feeds/footprints_page.dart lib/comfy/comfy_page.dart --include=*.dart` 只允许命中 `lib/ui/tokens.dart`。`lib/scene/scene_stage.dart` 是**明确白名单**：它属于场景渲染层，本计划禁止改动其内部（见 Must NOT「不删场景」），所以它的裸色不计入。所有测试必须 hermetic：不 `pumpWidget(FeiyuApp())`、不触网、不读 `SharedPreferences`、不加载 video/asset；需要 `Settings`/`Memory` 时直接构造——`Settings(baseUrl: 'https://x/v1', apiKey: '', model: 'm', persona: 'p')`（其余字段均带默认值，见 `lib/main.dart:133-165`）、`Memory()`（无参，见 `lib/main.dart:269`）。
  Parallelization: Wave 5 | Blocked by: 1-26 | Blocks: F1-F4
  References: `lib/main.dart:100-165`（`Settings` 构造）、`lib/main.dart:269`（`Memory`）、`test/tokens_test.dart`（Todo 1 建立的最小版本）
  Acceptance criteria (agent-executable): `flutter analyze` 退出码 0 且输出无 `error|warning|info`；`flutter test` 退出码 0 且报告的用例数 ≥ 25（每个测试文件都必须真实存在并被运行）；`ls test/widget_test.dart` 不存在；`grep -rn "MyApp" test/ lib/` 返回 0 行；`grep -rn "Color(0x" lib/ui lib/main.dart lib/feeds/footprints_page.dart lib/comfy/comfy_page.dart --include=*.dart` 只命中 `lib/ui/tokens.dart`（`lib/scene/**` 为已声明白名单）。
  QA scenarios: happy — `flutter test --reporter expanded` 全绿；failure — 故意把 `AppPalette.primary` 改成低对比度灰色，`contrast_test.dart` 必须失败（证明测试有效），随后恢复。Evidence `.omo/evidence/ui-redesign/task-27-companion-ui-redesign.md`
  Commit: N | verification-only todo: no file changes (all 26 test files are created by their owning todos); the gate is the run itself, no empty commit is created.

## Final verification wave

> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit — 逐条核对本计划的 28 个 todo：每条 References 指向的内容存在、Acceptance 可执行、Commit 已落地；输出 PASS/FAIL 列表与未完成项。
- [x] F2. Code quality review — `flutter analyze` 零 issue；无 `unused_field`/`unused_import`；无重复的动画 controller 泄漏；`lib/ui/` 每个文件职责单一；`git diff` 中 `_send`/`_runAgent`/`_transcribe`/`_toggleVoice`/`_downloadTts`/`_testComfy`/`_loadModels`/`_save`/`_add`/`ComfyClient` 零改动。
- [x] F3. Real QA（由执行代理实际运行，不是人工目测）— `flutter pub get` → `flutter test` 全绿 → `flutter build web --release` 成功 → `node server/server.mjs` + Playwright 在 320/390/768/1280 各截空态/有消息/设置页并核对可判定清单（宽度、控制台 overflow、横向滚动条）。
- [x] F4. Scope fidelity — 对照 `## Scope` 的 Must NOT have：无新依赖、无新页面/设置项、无浅色主题、场景功能保留、数据形状未变、白名单外的裸 hex/emoji 为 0。

## Commit strategy

- 每个 todo 一个提交，前缀 `feat(ui)` / `feat(settings)` / `feat(footprints)` / `feat(comfy)` / `refactor(ui)` / `fix(a11y)` / `test(ui)`，scope 对应模块；标题用祈使句、≤ 72 字符。
- Wave 1 的 1-5 可合并为一个 `feat(ui): add the design system foundation`，但**仅当**执行者确认 `flutter analyze` 在合并点仍为 0。
- 禁止提交注入后的 `kInjectedKey`（`README.md:52-54`）；提交前 `grep -n "__FEIYU_KEY__" lib/main.dart` 必须仍命中占位符（`lib/main.dart:27` 的常量以拼接形式存在，注意不要误改 `lib/main.dart:28-30` 的哨兵逻辑）。
- 不提交 `build/`、`.dart_tool/`、`.omo/evidence/` 之外的产物；`dafeiyu.bundle` 保持原样。

## Success criteria

1. `flutter analyze` 退出码 0，无 error/warning/info。
2. `flutter test` 退出码 0，≥ 25 个用例全绿，且无 Timer/dispose 泄漏。
3. `flutter build web --release --base-href /` 成功；`node server/server.mjs` 起服务后 4 个视口 × 3 种状态共 12 张截图由执行代理按清单核对：无 `RenderFlex overflowed` 日志、内容区宽度 ≤ 720、无横向滚动条、输入栏可见。
4. 对比度：`contrast_test.dart` 的 8 组纯 Dart 断言全部通过（正文 ≥ 7:1、次要文本 ≥ 4.5:1，均在不透明 token 上计算）；`ReadabilityScrim` 的渐变 alpha 与设计值一致（widget test 断言，不采样照片像素）。
5. `lib/main.dart` 中不再有 `_etchShadows`、`_etched`、`ColorScheme.fromSeed`、`BackdropFilter`；widget 头像用法不再含 `🐟`（白名单：`lib/feeds/footprints.dart:19,35`、`lib/main.dart:1181,1720` 的已持久化 mood 默认值）；`lib/ui/` 与 `lib/main.dart`、`lib/feeds/footprints_page.dart`、`lib/comfy/comfy_page.dart` 不再出现裸 `Color(0x...)`（唯一例外：`lib/ui/tokens.dart`）。
6. 业务行为零差异：`git diff` 中 `_send`、`_runAgent`、`_transcribe`、`_toggleVoice`、`_downloadTts`、`_testComfy`、`_loadModels`、`_save`、`_add`、`ComfyClient` 全部零改动。
7. 设置页 7 张分组卡齐全且标题与 Todo 16 的清单逐字一致；所有既有字段可编辑，`_save` 载荷与改动前逐字段一致（`git diff` + `test/settings_*_test.dart` 断言）。
8. 320 宽与 `textScaler: 1.3` 下无横向滚动条、无溢出异常（`text_scale_test.dart` 断言 `takeException()` 为 null）。
