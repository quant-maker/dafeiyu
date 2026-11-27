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
| 语音输入 | 录音后转写：手机默认走本机离线模型（Dolphin / SenseVoice，下载一次，不用 Key）；Web 走浏览器 Web Speech，也可切云端转写 |
| 语音朗读 | 默认系统 TTS（不花钱、不用 Key）；可选本机 Kokoro（离线，下载一次） |
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

### ComfyUI 一键启动（仅 Web）

`server.mjs` 多了 `/comfyctl/{health,start,stop}`：会话页长按画笔、或者绘画页右上角 ▶，
就能在这台电脑上启停 ComfyUI，不用再回桌面双击 bat。默认找
`%USERPROFILE%\WorkSpace\sexy\run_comfy_hidden.cmd`（你们那套 supervisor），
装在别处就用环境变量改：

```powershell
$env:COMFY_DIR   = 'D:\ComfyUI'                       # 安装目录
$env:COMFY_START = 'D:\ComfyUI\run_hidden.cmd'        # 启动脚本（会常驻）
node server/server.mjs
```

停止时服务端会写 `stop.flag` 并杀掉 8188 的监听进程，和 `停止大肥鱼.cmd` 的握手方式一致。

内置了两套文生图工作流（设置 → ComfyUI 一键切换）：**SD-Turbo** 是默认值，4 步出图、CPU 也能跑；
**Z-Image Turbo** 8 步、质量更好，需要显卡和 `z_image_turbo_bf16` / `qwen_3_4b` / `ae` 三个模型文件。

提示词中英文都能写：这类模型的文本编码器只认英文，中文会先由对话模型翻成英文再送进 ComfyUI
（否则出来就是那张灰糊糊的「水墨画」）。翻译结果按原文缓存，同一句话不会重复花 token。

### 离线语音（不用 Key）

语音识别默认走本机模型：Dolphin（99 MB，快）或 SenseVoice（228 MB，方言更强），
在设置 → 声音 → 语音识别里下载一次，之后录音在手机上转文字，断网也能用。
语音朗读默认用系统 TTS，同样不需要 Key；想要更自然的声音可以切「本机 Kokoro」（147 MB）。

模型从 `hf-mirror.com` 拉（GitHub 在国内经常解析不了），下不动会自动退回 GitHub。

### 心跳（她自己活着的那部分）

不是「你多久没说话所以我来找你」，而是她自己有心跳：每 4~12 分钟醒一下，
看时间、记一笔，大约每 40 分钟出门逛一次 HN / V2EX / 华尔街见闻，
遇到眼熟的名字会记住（同一来源同一个人），觉得有意思就写进「她的足迹」。

想说话的时候她就说，不必等你先开口：两条主动消息至少隔 12 分钟，
白天最多 14 条、夜里（22:00–07:00）最多 3 条，其余时候「这次没什么想说的」
也是正常结果。所有节奏都在本地算，不会因为关掉 App 就积攒一堆待发消息——
心跳只在 App 开着时跳，这点她也知道，不会答应「我今晚一定找你」这种做不到的事。

设置 → 记忆与会话 → 主动开口：开关（新的安装默认打开）、空闲多久算你不在、
「现在试一次」，以及一行心跳状态（上次跳的时间、今天跳了几次、刚才逛到了什么）。

### Android（CI）

推 `v*` tag 或在 Actions 手动触发 `build` 工作流，会产出 arm64 APK 并挂到 Release，无需本地构建。

## 安全与边界

- 仓库里 `lib/main.dart` 只保存占位符 `__FEIYU_KEY__`。CI 在存在 `FEIYU_KEY` secret 时注入；本地 Web 构建不注入，首次运行在设置里手填 Key。
- 把 Web 目录部署到公网前，务必改成运行时输入 Key，否则等于公开你的 Key。
- 自动记忆会产生额外模型调用（每 3 轮一次，很短），可在设置里关闭。

## 状态

v0.15.7：记忆系统 P0 落地（SQLite/drift，取代原来的 24 条便利贴与单 JSON 归档，旧数据自动迁移）。四层记忆（工作 / 情景 / 事实 / 分层块）与星图可视化见 `docs/memory-design.md`，P1–P5 按那份文档推进。
