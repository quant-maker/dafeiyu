$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$log = Join-Path $root 'install.log'
New-Item -ItemType Directory -Force -Path $root | Out-Null
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }
function Unzip($zip, $dest) {
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
}

# ---------- JDK 17 ----------
$jdkDir = Join-Path $root 'jdk'
if (-not (Test-Path (Join-Path $jdkDir 'bin\java.exe'))) {
  $zip = Join-Path $root 'jdk.zip'
  if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 100MB) {
    Log 'JDK: downloading'
    & curl.exe -sL --retry 3 -m 1800 -o $zip 'https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip'
    if ($LASTEXITCODE -ne 0) { Log "JDK: download failed ($LASTEXITCODE)"; exit 10 }
  }
  Log ('JDK: zip ' + [math]::Round((Get-Item $zip).Length / 1MB, 1) + ' MB, extracting')
  $tmp = Join-Path $root '_jdk_x'
  Unzip $zip $tmp
  $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
  Move-Item $inner.FullName $jdkDir
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
}
Log ('JDK: ' + ((& (Join-Path $jdkDir 'bin\java.exe') -version 2>&1 | Select-Object -First 1) -join ''))

# ---------- Android cmdline-tools ----------
$sdk = Join-Path $root 'android-sdk'
$ctRoot = Join-Path $sdk 'cmdline-tools'
$sm = Join-Path $ctRoot 'latest\bin\sdkmanager.bat'
if (-not (Test-Path $sm)) {
  Log 'AndroidSDK: downloading cmdline-tools'
  $zip = Join-Path $root 'cmdline-tools.zip'
  & curl.exe -sL --retry 3 -m 1800 -o $zip 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip'
  if ($LASTEXITCODE -ne 0) { Log "AndroidSDK: download failed ($LASTEXITCODE)"; exit 11 }
  New-Item -ItemType Directory -Force -Path $ctRoot | Out-Null
  $tmp = Join-Path $root '_ct_x'
  Unzip $zip $tmp
  $inner = Join-Path $tmp 'cmdline-tools'
  if (Test-Path $inner) { Move-Item $inner (Join-Path $ctRoot 'latest') } else { Move-Item $tmp (Join-Path $ctRoot 'latest') }
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
  Log 'AndroidSDK: cmdline-tools ready'
}

$env:JAVA_HOME = $jdkDir
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:Path = (Join-Path $jdkDir 'bin') + ';' + (Join-Path $ctRoot 'latest\bin') + ';' + $env:Path

# ---------- SDK packages ----------
if (-not (Test-Path (Join-Path $sdk 'platforms\android-35'))) {
  Log 'AndroidSDK: accepting licenses'
  $yes = ('y' + "`r`n") * 80
  $yes | & $sm --licenses 2>&1 | Select-Object -Last 2 | ForEach-Object { Log "  $_" }
  foreach ($pkg in @('platform-tools', 'platforms;android-35', 'build-tools;35.0.0')) {
    Log "AndroidSDK: install $pkg"
    & $sm $pkg 2>&1 | Select-Object -Last 2 | ForEach-Object { Log "  $_" }
  }
}
Log 'AndroidSDK: done'

# ---------- Flutter (CN mirror) ----------
$flutterDir = Join-Path $root 'flutter'
if (-not (Test-Path (Join-Path $flutterDir 'bin\flutter.bat'))) {
  $zip = Join-Path $root 'flutter.zip'
  if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 500MB) {
    Log 'Flutter: downloading from CN mirror'
    & curl.exe -sL --retry 3 -m 3600 -o $zip 'https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.35.1-stable.zip'
    if ($LASTEXITCODE -ne 0) { Log "Flutter: download failed ($LASTEXITCODE)"; exit 12 }
  }
  Log ('Flutter: zip ' + [math]::Round((Get-Item $zip).Length / 1MB, 1) + ' MB, extracting')
  $tmp = Join-Path $root '_fl_x'
  Unzip $zip $tmp
  $inner = Join-Path $tmp 'flutter'
  Move-Item $inner $flutterDir
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
}
Log 'Flutter: configuring'
& (Join-Path $flutterDir 'bin\flutter.bat') config --android-sdk $sdk --no-analytics 2>&1 | Select-Object -Last 3 | ForEach-Object { Log "  $_" }
Log 'DONE'

