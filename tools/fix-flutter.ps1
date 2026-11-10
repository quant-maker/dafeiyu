$ErrorActionPreference = 'Continue'
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$log = Join-Path $root 'flutter-fix.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$flutterDir = Join-Path $root 'flutter'
if (Test-Path (Join-Path $flutterDir 'packages\flutter_tools\pubspec.yaml')) { Log 'flutter already complete'; exit 0 }

Log 'removing broken extraction'
if (Test-Path $flutterDir) { Remove-Item $flutterDir -Recurse -Force -ErrorAction SilentlyContinue }

$zip = Join-Path $root 'flutter.zip'
if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 500MB) {
  Log 'downloading flutter sdk (CN mirror)'
  & curl.exe -sL --retry 3 -m 3600 -o $zip 'https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.35.1-stable.zip'
  if ($LASTEXITCODE -ne 0) { Log "download failed $LASTEXITCODE"; exit 12 }
}
Log ('zip ' + [math]::Round((Get-Item $zip).Length / 1MB, 1) + ' MB')

$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
Log "extracting via $tar"
& $tar -xf $zip -C $root
Log "tar exit $LASTEXITCODE"

if (Test-Path (Join-Path $flutterDir 'packages\flutter_tools\pubspec.yaml')) {
  Log ('OK: files=' + (Get-ChildItem $flutterDir -Recurse -File | Measure-Object).Count)
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
} else {
  Log 'STILL BROKEN'
}
Log 'FLUTTER FIX DONE'
