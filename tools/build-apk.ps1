$ErrorActionPreference = 'Continue'
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$ws = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace'
$log = Join-Path $root 'build.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$env:FLUTTER_ROOT = Join-Path $root 'flutter'
$env:JAVA_HOME = Join-Path $root 'jdk'
$env:ANDROID_HOME = Join-Path $root 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = (Join-Path $root 'jdk\bin') + ';' + (Join-Path $root 'android-sdk\platform-tools') + ';' + (Join-Path $root 'flutter\bin') + ';' + $env:Path
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:APPDATA = Join-Path $root 'appdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$tmp = Join-Path $ws 'tmp'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$env:TMP = $tmp
$env:TEMP = $tmp
$pubCache = Join-Path $root 'pub-cache'
New-Item -ItemType Directory -Force -Path $pubCache | Out-Null
$env:PUB_CACHE = $pubCache
# Gradle also writes to %USERPROFILE%\.gradle by default; keep it inside the workspace.
$env:GRADLE_USER_HOME = Join-Path $root 'gradle-home'
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
# AGP refuses conflicting preference roots, so expose exactly ONE: the JVM user.home
# (set in android/gradle.properties). Do not also export ANDROID_USER_HOME etc.
$env:ANDROID_USER_HOME = Join-Path $root 'android-user'
New-Item -ItemType Directory -Force -Path $env:ANDROID_USER_HOME | Out-Null
Remove-Item Env:ANDROID_PREFS_ROOT -ErrorAction SilentlyContinue
Remove-Item Env:ANDROID_SDK_HOME -ErrorAction SilentlyContinue
# Android SDK licenses + build output all live under the workspace already.

$dart = Join-Path $root 'flutter\bin\cache\dart-sdk\bin\dart.exe'
$snap = Join-Path $root 'flutter\bin\cache\flutter_tools.snapshot'
function Flutter { param([string[]]$a) & $dart $snap @a 2>&1 }

$app = Join-Path $ws 'feiyu_app'
if (-not (Test-Path (Join-Path $app 'pubspec.yaml'))) {
  Log 'create'
  Flutter @('create', '--no-pub', '--org', 'app.feiyu', '--project-name', 'feiyu', '--platforms', 'android', $app) | Select-Object -Last 4 | ForEach-Object { Log "  $_" }
}
if (-not (Test-Path (Join-Path $app 'pubspec.yaml'))) { Log 'CREATE FAILED'; exit 20 }
Log 'created'

Copy-Item (Join-Path $ws 'feiyu_app_src\main.dart') (Join-Path $app 'lib\main.dart') -Force
Log 'main.dart installed'

Push-Location $app
try {
  Log 'pub add'
  Flutter @('pub', 'add', 'http', 'shared_preferences', 'speech_to_text', 'image_picker') | Select-Object -Last 5 | ForEach-Object { Log "  $_" }
  Log 'pub get done'
  Log 'build apk --release'
  Flutter @('build', 'apk', '--release', '--split-per-abi') | Select-Object -Last 30 | ForEach-Object { Log "  $_" }
  $apk = Join-Path $app 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
  if (Test-Path $apk) {
    Copy-Item $apk (Join-Path $ws 'feiyu.apk') -Force
    Log ('APK OK: ' + [math]::Round((Get-Item $apk).Length / 1MB, 1) + ' MB -> ' + (Join-Path $ws 'feiyu.apk'))
  } else { Log 'APK NOT FOUND' }
} finally { Pop-Location }
Log 'DONE'
