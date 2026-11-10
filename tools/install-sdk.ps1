$ErrorActionPreference = 'Continue'
$root = 'C:\Users\xqli\Documents\deepseek-harness\default-workspace\tools'
$log = Join-Path $root 'sdk.log'
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $line; Write-Output $line }

$env:JAVA_HOME = Join-Path $root 'jdk'
$env:ANDROID_HOME = Join-Path $root 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = (Join-Path $root 'jdk\bin') + ';' + (Join-Path $root 'android-sdk\cmdline-tools\latest\bin') + ';' + $env:Path
$sm = Join-Path $root 'android-sdk\cmdline-tools\latest\bin\sdkmanager.bat'
$sdkRoot = Join-Path $root 'android-sdk'

Log 'licenses'
$tmpIn = Join-Path $env:TEMP 'sdk-yes.txt'
Set-Content -Path $tmpIn -Value (('y' + "`r`n") * 100) -NoNewline -Encoding ascii
& cmd.exe /c "`"$sm`" --sdk_root=`"$sdkRoot`" --licenses < `"$tmpIn`"" 2>&1 | Select-Object -Last 3 | ForEach-Object { Log "  $_" }

foreach ($pkg in @('platform-tools', 'platforms;android-35', 'build-tools;35.0.0')) {
  Log "install $pkg"
  & cmd.exe /c "`"$sm`" --sdk_root=`"$sdkRoot`" `"$pkg`" < `"$tmpIn`"" 2>&1 | Select-Object -Last 3 | ForEach-Object { Log "  $_" }
}

Log '--- verify ---'
Log ('platforms: ' + ((Get-ChildItem (Join-Path $sdkRoot 'platforms') -ErrorAction SilentlyContinue).Name -join ','))
Log ('build-tools: ' + ((Get-ChildItem (Join-Path $sdkRoot 'build-tools') -ErrorAction SilentlyContinue).Name -join ','))
Log ('adb: ' + (Test-Path (Join-Path $sdkRoot 'platform-tools\adb.exe')))
Log 'SDK DONE'
