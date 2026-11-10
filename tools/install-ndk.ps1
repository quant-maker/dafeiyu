$ErrorActionPreference = 'Continue'
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$sdk = Join-Path $root 'android-sdk'
$log = Join-Path $root 'ndk.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$ndkDir = Join-Path $sdk 'ndk\27.0.12077973'
if (Test-Path (Join-Path $ndkDir 'source.properties')) {
  $rev = (Get-Content (Join-Path $ndkDir 'source.properties') | Select-String 'Pkg.Revision').Line
  if ($rev -match '27\.0\.12077973') { Log 'NDK already present'; exit 0 }
}

$zip = Join-Path $root 'ndk-r27b.zip'
$url = 'https://dl.google.com/android/repository/android-ndk-r27b-windows.zip'
for ($i = 1; $i -le 6; $i++) {
  Log "download attempt $i"
  & curl.exe -sL -C - --retry 3 -m 7200 -o $zip $url
  $code = $LASTEXITCODE
  $size = if (Test-Path $zip) { [math]::Round((Get-Item $zip).Length / 1MB, 1) } else { 0 }
  Log "  exit=$code size=$size MB"
  if ($code -eq 0) { break }
  Start-Sleep -Seconds 5
}

$size = if (Test-Path $zip) { [math]::Round((Get-Item $zip).Length / 1MB, 1) } else { 0 }
Log "final zip $size MB"
if ($size -lt 300) { Log 'NDK DOWNLOAD INCOMPLETE'; exit 12 }

Log 'extracting'
if (Test-Path $ndkDir) { Remove-Item $ndkDir -Recurse -Force -ErrorAction SilentlyContinue }
$tmp = Join-Path $root '_ndk_x'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
$inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
Move-Item $inner.FullName $ndkDir
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Log ('NDK OK: ' + (Get-Content (Join-Path $ndkDir 'source.properties') | Select-String 'Pkg.Revision').Line)
