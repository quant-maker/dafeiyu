$ErrorActionPreference = 'Continue'
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$sdk = Join-Path $root 'android-sdk'
$log = Join-Path $root 'ndk.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$url = 'https://dl.google.com/android/repository/android-ndk-r27b-windows.zip'
$ndkDir = Join-Path $sdk 'ndk\27.0.12077973'
if (Test-Path (Join-Path $ndkDir 'source.properties')) { Log 'NDK already installed'; exit 0 }

# Content length
$head = & curl.exe -sIL -m 30 $url 2>&1
$len = ($head | Select-String -Pattern 'content-length:\s*(\d+)' | Select-Object -Last 1).Matches[0].Groups[1].Value
$total = [int64]$len
Log ("total bytes: $total (" + [math]::Round($total / 1MB, 1) + " MB)")

$parts = 8
$chunk = [math]::Ceiling($total / $parts)
$dir = Join-Path $root '_ndk_parts'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Get-ChildItem $dir -File | Remove-Item -Force -ErrorAction SilentlyContinue

$jobs = @()
for ($i = 0; $i -lt $parts; $i++) {
  $start = $i * $chunk
  $end = [Math]::Min($total - 1, ($i + 1) * $chunk - 1)
  $out = Join-Path $dir ("part{0:D2}" -f $i)
  $jobs += Start-Job -ScriptBlock {
    param($url, $start, $end, $out)
    $ok = $false
    for ($try = 1; $try -le 5; $try++) {
      & curl.exe -sL --retry 2 -m 3600 -r "$start-$end" -o $out $url
      if ($LASTEXITCODE -eq 0 -and (Test-Path $out)) {
        $need = $end - $start + 1
        if ((Get-Item $out).Length -ge $need) { $ok = $true; break }
      }
      Start-Sleep -Seconds 3
    }
    if ($ok) { "part ok $out" } else { "part FAILED $out" }
  } -ArgumentList $url, $start, $end, $out
}

$jobs | Wait-Job | Out-Null
$res = $jobs | Receive-Job
$jobs | Remove-Job
$res | ForEach-Object { Log "  $_" }
$failed = $res | Where-Object { $_ -like '*FAILED*' }
if ($failed) { Log 'SOME PARTS FAILED'; exit 13 }

$zip = Join-Path $root 'ndk-r27b.zip'
$fs = [IO.File]::Create($zip)
Get-ChildItem $dir -File | Sort-Object Name | ForEach-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName)
  $fs.Write($bytes, 0, $bytes.Length)
}
$fs.Close()
$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Log "assembled zip: $size MB"
Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
if ($size -lt 300) { Log 'ZIP TOO SMALL'; exit 14 }

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
