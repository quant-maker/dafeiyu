$ErrorActionPreference = 'Continue'
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$ws = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace'
$log = Join-Path $root 'web.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$env:FLUTTER_ROOT = Join-Path $root 'flutter'
$env:JAVA_HOME = Join-Path $root 'jdk'
$env:ANDROID_HOME = Join-Path $root 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = (Join-Path $root 'jdk\bin') + ';' + (Join-Path $root 'flutter\bin') + ';' + $env:Path
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:APPDATA = Join-Path $root 'appdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$tmp = Join-Path $ws 'tmp'; New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$env:TMP = $tmp; $env:TEMP = $tmp
$env:PUB_CACHE = Join-Path $root 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $root 'gradle-home'
$env:ANDROID_USER_HOME = Join-Path $root 'android-user'

$dart = Join-Path $root 'flutter\bin\cache\dart-sdk\bin\dart.exe'
$snap = Join-Path $root 'flutter\bin\cache\flutter_tools.snapshot'
function Flutter { param([string[]]$a) & $dart $snap @a 2>&1 }

$app = Join-Path $ws 'feiyu_app'
Push-Location $app
try {
  if (-not (Test-Path (Join-Path $app 'web\index.html'))) {
    Log 'adding web platform'
    Flutter @('create', '--platforms', 'web', '--no-pub', '.') | Select-Object -Last 5 | ForEach-Object { Log "  $_" }
  }
  Log 'pub get'
  Flutter @('pub', 'get') | Select-Object -Last 4 | ForEach-Object { Log "  $_" }

  # Sync source and inject the gateway key from the local launcher (never printed).
  Copy-Item (Join-Path $ws 'feiyu_app_src\main.dart') (Join-Path $app 'lib\main.dart') -Force
Copy-Item (Join-Path $ws 'feiyu_app_src\memory') (Join-Path $app 'lib\memory') -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path (Join-Path $ws 'feiyu_app_src\scene')) { Copy-Item (Join-Path $ws 'feiyu_app_src\scene') (Join-Path $app 'lib\scene') -Recurse -Force }
  $wrapper = Join-Path $env:USERPROFILE '.local\bin\claude'
  $mm = if (Test-Path $wrapper) { Select-String -Path $wrapper -Pattern '^GW_TOKEN="\$\{GW_TOKEN:-(.+)\}"' } else { $null }
  if ($mm) {
    $key = $mm.Matches[0].Groups[1].Value
    $mf = Join-Path $app 'lib\main.dart'
    $src = [IO.File]::ReadAllText($mf)
    [IO.File]::WriteAllText($mf, $src.Replace('__FEIYU_KEY__', $key), (New-Object Text.UTF8Encoding($false)))
    Log 'key injected into lib/main.dart'
  } else {
    Log 'WARN: gateway key not found; app will ask for it'
  }

  Log 'build web --release'
  Flutter @('build', 'web', '--release', '--pwa-strategy=none') | ForEach-Object { Log "  $_" }
  $out = Join-Path $app 'build\web'
  if (Test-Path (Join-Path $out 'index.html')) {
    $size = [math]::Round(((Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
    Log "WEB OK: $out ($size MB)"
  } else {
    Log 'WEB BUILD FAILED'
  }
} finally { Pop-Location }
Log 'WEB DONE'
