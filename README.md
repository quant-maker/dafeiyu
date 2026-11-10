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
| 自动记忆 | 每 3 轮抽取一次关于主人的长期事实，本地留存并注入 system prompt |
| 人设可改 | 内置一段「大肥鱼」system prompt，随时替换 |
| 模型下拉 | 从 `/models` 拉取列表，也可手填 |

## 目录

```
lib/main.dart          全部客户端代码（Flutter）
server/server.mjs      本地 Web 服务器：托管页面 + 反代 /v1（解决浏览器 CORS）
tools/                 构建脚本（Windows / PowerShell）
  build-web.ps1        编译 Web 版
  build-apk.ps1        编译 Android APK（--split-per-abi）
  install-toolchain.ps1 无管理员安装 JDK + Android SDK + Flutter
```

## 构建

### Web

```bash
flutter build web --release
node server/server.mjs      # 打开 http://127.0.0.1:8090
```

页面的 Base URL 会自动取当前 origin + `/v1`，直接走本地反代，不会被 CORS 拦。

### Android

```bash
flutter build apk --release --split-per-abi
# 产物：build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 安全与边界

- 构建脚本会从本地启动器读取网关 key 并**注入**到 `lib/main.dart`（替换 `__FEIYU_KEY__`）。
  仓库里只保存占位符版本，**不要提交注入后的文件**。
- 把 Web 目录部署到公网前，务必改成运行时输入 Key，否则等于公开你的 Key。
- 自动记忆会产生额外模型调用（每 3 轮一次，很短），可在设置里关闭。

## 状态

早期版本：单一会话、记忆按条累积、无后台推送。后续计划是本地剪辑历史、主动消息、桌面形象。
