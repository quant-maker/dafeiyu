# Builds the Web bundle from THIS repo (dafeiyu).
# Local builds are web-only. Android APKs / macOS / Web release zips are
# produced by GitHub Actions (.github/workflows/build.yml) when a v* tag is
# pushed or the workflow is run manually.
$ErrorActionPreference = 'Continue'
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$repo = Split-Path $PSScriptRoot -Parent
$log = Join-Path $root 'web.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$env:FLUTTER_ROOT = Join-Path $root 'flutter'
$env:APPDATA = Join-Path $root 'appdata'
$env:PUB_CACHE = Join-Path $root 'pub-cache'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$tmp = Join-Path (Split-Path $repo -Parent) 'tmp'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$env:TMP = $tmp; $env:TEMP = $tmp

$dart = Join-Path $root 'flutter\bin\cache\dart-sdk\bin\dart.exe'
$snap = Join-Path $root 'flutter\bin\cache\flutter_tools.snapshot'

Push-Location $repo
try {
  Log 'flutter build web --release'
  & $dart $snap build web --release --pwa-strategy=none --no-wasm-dry-run 2>&1 |
    ForEach-Object { Log "  $_" }
  if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

  $out = Join-Path $repo 'build\web'
  # sherpa-onnx ships a 14 MB wasm we never use on web (local ASR is native only).
  $dead = Join-Path $out 'assets\packages\sherpa_onnx_web'
  if (Test-Path $dead) { Remove-Item $dead -Recurse -Force; Log 'pruned sherpa web assets' }
  if (-not (Test-Path (Join-Path $out 'index.html'))) { throw 'no build/web/index.html' }

  $size = [math]::Round(((Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
  Log "WEB OK: $out ($size MB)"
} finally { Pop-Location }
Log 'WEB DONE'
