$ErrorActionPreference = 'Continue'
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$sdk = Join-Path $root 'android-sdk'
$log = Join-Path $root 'ndk2.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$url = 'https://dl.google.com/android/repository/android-ndk-r27b-windows.zip'
$zip = Join-Path $root 'ndk-r27b.zip'
$ndkDir = Join-Path $sdk 'ndk\27.0.12077973'

if (Test-Path (Join-Path $ndkDir 'source.properties')) { Log 'NDK already installed'; exit 0 }

if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 600MB) {
  $head = & curl.exe -sIL -m 30 $url 2>&1
  $total = [int64](($head | Select-String -Pattern 'content-length:\s*(\d+)' | Select-Object -Last 1).Matches[0].Groups[1].Value)
  Log ("total " + [math]::Round($total / 1MB, 1) + " MB")
  $parts = 8
  $chunk = [math]::Ceiling($total / $parts)
  $dir = Join-Path $root '_ndk_parts'
  if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $jobs = @()
  for ($i = 0; $i -lt $parts; $i++) {
    $start = $i * $chunk
    $end = [Math]::Min($total - 1, ($i + 1) * $chunk - 1)
    $out = Join-Path $dir ("part{0:D2}" -f $i)
    $jobs += Start-Job -ScriptBlock {
      param($url, $start, $end, $out)
      $need = $end - $start + 1
      for ($try = 1; $try -le 6; $try++) {
        & curl.exe -sL --retry 2 -m 3600 -r "$start-$end" -o $out $url
        if ((Test-Path $out) -and (Get-Item $out).Length -eq $need) { return "OK $out $((Get-Item $out).Length)" }
        Start-Sleep -Seconds 3
      }
      "FAIL $out " + (if (Test-Path $out) { (Get-Item $out).Length } else { 0 })
    } -ArgumentList $url, $start, $end, $out
  }
  $jobs | Wait-Job | Out-Null
  $res = $jobs | Receive-Job
  $jobs | Remove-Job
  $res | ForEach-Object { Log "  $_" }
  if ($res | Where-Object { $_ -like 'FAIL*' }) { Log 'PARTS FAILED'; exit 13 }

  $fs = [IO.File]::Create($zip)
  Get-ChildItem $dir -File | Sort-Object Name | ForEach-Object {
    $in = [IO.File]::OpenRead($_.FullName)
    $in.CopyTo($fs)
    $in.Close()
  }
  $fs.Close()
  Remove-Item $dir -Recurse -Force
}
$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Log "zip $size MB"

# integrity check
try {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $z = [IO.Compression.ZipFile]::OpenRead($zip)
  Log ("zip ok, entries=" + $z.Entries.Count)
  $z.Dispose()
} catch {
  Log ("ZIP CORRUPT: " + $_.Exception.Message)
  Remove-Item $zip -Force
  exit 15
}

Log 'extracting with bsdtar'
$tmp = Join-Path $root '_ndk_x'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
& (Join-Path $env:SystemRoot 'System32\tar.exe') -xf $zip -C $tmp
Log "tar exit $LASTEXITCODE"
$inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
if (-not $inner) { Log 'no inner dir'; exit 16 }
if (Test-Path $ndkDir) { Remove-Item $ndkDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $ndkDir -Parent) | Out-Null
Move-Item $inner.FullName $ndkDir
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zip -Force -ErrorAction SilentlyContinue
$sp = Join-Path $ndkDir 'source.properties'
if (Test-Path $sp) { Log ('NDK OK: ' + (Get-Content $sp | Select-String 'Pkg.Revision').Line) }
else { Log 'NDK STILL BROKEN' }
