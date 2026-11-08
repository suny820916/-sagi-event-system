@echo off
title SAGI V4.3 vMix Bridge
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0vmix-bridge-v43.ps1"
pause
