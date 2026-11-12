@echo off
chcp 65001 >nul
title SAGI V4.5 vMix Bridge
echo.
echo ==========================================
echo   SAGI LIVE MATCH DIRECTOR - vMix Bridge
echo ==========================================
echo.
echo Starting bridge. Keep vMix open...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$u='https://raw.githubusercontent.com/suny820916/-sagi-event-system/main/intro/vmix-bridge-v45.ps1';" ^
  "try {$wc=New-Object Net.WebClient; $wc.Headers.Add('Cache-Control','no-cache'); $code=$wc.DownloadString($u+'?v=454'); Invoke-Expression $code} catch {Write-Host ('[ERROR] '+$_.Exception.Message) -ForegroundColor Red; Read-Host 'Press Enter to close'}"

echo.
pause
