# 大肥鱼 · dafeiyu

一个能装进口袋的 AI 伴侣客户端：**自己的 Key、随便换模型、数据只留本机**。

- Android：Flutter 原生 App（APK 16 MB 左右，arm64）
- Web：同一套代码编成静态站，本地起一个小服务器即可用
- 模型：任何 OpenAI 兼容接口（`/chat/completions` + `/models`）
- 隐私：API Key、对话、记忆都只存在设备本地，不经过任何第三方服务器

## 功能

| 功能 | 说明 |
|---|---|
| 流式对话 | SSE 逐字输出，可随时中断 |
| 语音输入 | Android 走系统 `SpeechRecognizer`；Web 走浏览器 Web Speech |
| 拍照 / 选图 | 以 OpenAI `image_url` content part 发给视觉模型 |
| 自动记忆 | 每 3 轮抽取一次关于主人的长期事实，存本地 SQLite，按重要度保留并注入 system prompt |
| 记忆库 | drift/SQLite：事实 / 情景 / 实体 / 关系 / 分层块，向量 int8 量化后本地检索 |
| 人设可改 | 内置一段「大肥鱼」system prompt，随时替换 |
| 模型下拉 | 从 `/models` 拉取列表，也可手填 |

## 目录

```
lib/                    Flutter 客户端（main.dart 为入口与核心编排）
  ui/ scene/ voice/     界面、房间场景、语音
  memory/ companion/    记忆归档、主动搭话引擎
  feeds/ comfy/         足迹、ComfyUI 出图
server/server.mjs       本地 Web 服务器：托管页面 + 反代 /v1（解决浏览器 CORS）
tools/                  本地构建脚本（Windows / PowerShell，仅 Web）
  build-web.ps1         编译 Web 版（在仓库根目录直接构建）
  fetch-web-assets.ps1  刷新 web/sqlite3.wasm 与 web/drift_worker.js（换 drift 版本时跑）
  install-toolchain.ps1 无管理员安装 JDK + Android SDK + Flutter
.github/workflows/      CI：打 tag 时构建并发布 Android APK / macOS / Web
```

## 构建

本地只构建 Web；Android APK / macOS / Web 包由 GitHub Actions 在打 tag 时发布（见 `.github/workflows/build.yml`）。

### Web（本地）

```powershell
tools\build-web.ps1          # 产物：build\web
node server/server.mjs       # 打开 http://127.0.0.1:8090
```

页面的 Base URL 会自动取当前 origin + `/v1`，直接走本地反代，不会被 CORS 拦。

### Android（CI）

推 `v*` tag 或在 Actions 手动触发 `build` 工作流，会产出 arm64 APK 并挂到 Release，无需本地构建。

## 安全与边界

- 仓库里 `lib/main.dart` 只保存占位符 `__FEIYU_KEY__`。CI 在存在 `FEIYU_KEY` secret 时注入；本地 Web 构建不注入，首次运行在设置里手填 Key。
- 把 Web 目录部署到公网前，务必改成运行时输入 Key，否则等于公开你的 Key。
- 自动记忆会产生额外模型调用（每 3 轮一次，很短），可在设置里关闭。

## 状态

v0.15.7：记忆系统 P0 落地（SQLite/drift，取代原来的 24 条便利贴与单 JSON 归档，旧数据自动迁移）。四层记忆（工作 / 情景 / 事实 / 分层块）与星图可视化见 `docs/memory-design.md`，P1–P5 按那份文档推进。
