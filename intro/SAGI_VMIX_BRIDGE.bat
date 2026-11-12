@echo off
chcp 65001 >nul
title SAGI V4.5 vMix Bridge
echo.
echo ==========================================
echo   SAGI LIVE MATCH DIRECTOR - vMix Bridge
echo ==========================================
echo.
echo 正在启动，请保持 vMix 已打开...
echo.

set "BRIDGE=%TEMP%\sagi-vmix-bridge-v45.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/suny820916/-sagi-event-system/main/intro/vmix-bridge-v45.ps1' -OutFile '%BRIDGE%' } catch { Write-Host '[ERROR] 无法下载 Bridge，请检查电脑网络。' -ForegroundColor Red; exit 1 }"

if not exist "%BRIDGE%" (
  echo.
  echo Bridge 下载失败。
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BRIDGE%"
echo.
pause
