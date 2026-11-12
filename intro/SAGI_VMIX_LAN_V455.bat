@echo off
chcp 65001 >nul
title SAGI V4.5.5 LAN DIRECT
echo.
echo ==========================================
echo   SAGI LIVE MATCH DIRECTOR - LAN DIRECT
echo ==========================================
echo.
echo Starting local bridge...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root=Join-Path $env:LOCALAPPDATA 'SAGI\LiveMatchDirector'; New-Item -ItemType Directory -Force -Path $root | Out-Null; $cache=Join-Path $root 'vmix-bridge-v455-lan.ps1'; $u='https://suny820916.github.io/-sagi-event-system/intro/vmix-bridge-v455-lan.ps1?v=456'; try {Write-Host '[LOAD] Downloading LAN Bridge...' -ForegroundColor Cyan; $r=Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 15 -Headers @{'Cache-Control'='no-cache'}; $code=[string]$r.Content; [IO.File]::WriteAllText($cache,$code,(New-Object Text.UTF8Encoding($false)))} catch {if(Test-Path $cache){$code=[IO.File]::ReadAllText($cache,[Text.Encoding]::UTF8)} else {Write-Host '[ERROR] Cannot download LAN Bridge and no cached copy exists.' -ForegroundColor Red; Read-Host 'Press Enter to close'; exit}}; Invoke-Expression $code"

echo.
pause
