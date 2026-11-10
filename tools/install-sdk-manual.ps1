$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$sdk = Join-Path $root 'android-sdk'
$log = Join-Path $root 'sdk.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$items = @(
  @{ name = 'platform-tools'; zip = 'platform-tools_r37.0.1-win.zip'; dest = (Join-Path $sdk 'platform-tools') },
  @{ name = 'platforms;android-35'; zip = 'platform-35_r02.zip'; dest = (Join-Path $sdk 'platforms\android-35') },
  @{ name = 'build-tools;35.0.0'; zip = 'build-tools_r35_windows.zip'; dest = (Join-Path $sdk 'build-tools\35.0.0') }
)

foreach ($it in $items) {
  if (Test-Path $it.dest) { Log ("skip " + $it.name + " (exists)"); continue }
  $zipPath = Join-Path $root $it.zip
  if (-not (Test-Path $zipPath)) {
    Log ("download " + $it.zip)
    & curl.exe -sL --retry 3 -m 2400 -o $zipPath ("https://dl.google.com/android/repository/" + $it.zip)
    if ($LASTEXITCODE -ne 0) { Log ("  download failed " + $LASTEXITCODE); continue }
  }
  Log ("  zip " + [math]::Round((Get-Item $zipPath).Length / 1MB, 1) + " MB")
  $tmp = Join-Path $root ('_x_' + $it.name.Replace(';', '_').Replace('.', '_'))
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tmp)
  $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
  $src = if ($inner) { $inner.FullName } else { $tmp }
  $parent = Split-Path $it.dest -Parent
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  Move-Item $src $it.dest -Force
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
  Log ("  installed into " + $it.dest)
}

Log '--- verify ---'
Log ('adb: ' + (Test-Path (Join-Path $sdk 'platform-tools\adb.exe')))
Log ('android.jar: ' + (Test-Path (Join-Path $sdk 'platforms\android-35\android.jar')))
Log ('aapt2: ' + (Test-Path (Join-Path $sdk 'build-tools\35.0.0\aapt2.exe')))
Log 'SDK MANUAL DONE'
