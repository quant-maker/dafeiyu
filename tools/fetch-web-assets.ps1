# 刷新 drift 的 web 运行资源：web/sqlite3.wasm + web/drift_worker.js
#
# 用法（仓库根目录）：
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/fetch-web-assets.ps1
#
# 为什么需要：drift 在浏览器里跑 sqlite 需要 sqlite3 的 wasm 与一个 worker 脚本，
# 两者都不由 flutter build 生成，必须随 web/ 一起提交。
param(
  [string]$FlutterRoot = $env:FLUTTER_ROOT,
  [string]$PubCache = $env:PUB_CACHE
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$web = Join-Path $repo 'web'
if (-not (Test-Path $web)) { throw "web/ 不存在：$web" }

if (-not $PubCache) { $PubCache = Join-Path $env:LOCALAPPDATA 'Pub\Cache' }
$drift = Get-ChildItem (Join-Path $PubCache 'hosted\pub.dev') -Directory -Filter 'drift-*' |
  Sort-Object Name -Descending | Select-Object -First 1
if (-not $drift) { throw "pub cache 里找不到 drift：$PubCache" }
$wasm = Join-Path $drift.FullName 'extension\devtools\build\sqlite3.wasm'
if (-not (Test-Path $wasm)) { throw "找不到 sqlite3.wasm：$wasm" }
Copy-Item $wasm (Join-Path $web 'sqlite3.wasm') -Force
'copied sqlite3.wasm ({0:N2} MB)' -f ((Get-Item (Join-Path $web 'sqlite3.wasm')).Length / 1MB)

if (-not $FlutterRoot) { throw '需要 FLUTTER_ROOT' }
$dart = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
Push-Location $repo
try {
  & $dart compile js -o web\drift_worker.js web\drift_worker.dart
  if ($LASTEXITCODE -ne 0) { throw 'dart compile js 失败' }
  'compiled drift_worker.js ({0:N2} MB)' -f ((Get-Item (Join-Path $web 'drift_worker.js')).Length / 1MB)
} finally { Pop-Location }
