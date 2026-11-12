@echo off
chcp 65001 >nul
title SAGI V4.5 vMix Bridge
echo.
echo ==========================================
echo   SAGI LIVE MATCH DIRECTOR - vMix Bridge
echo ==========================================
echo.
echo 正在连接 vMix，请保持 vMix 已打开...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$u='https://raw.githubusercontent.com/suny820916/-sagi-event-system/main/intro/vmix-bridge-v45.ps1';" ^
  "try {$code=(New-Object Net.WebClient).DownloadString($u); Invoke-Expression $code} catch {Write-Host ('[ERROR] '+$_.Exception.Message) -ForegroundColor Red; Read-Host '按回车关闭'}"

echo.
pause
