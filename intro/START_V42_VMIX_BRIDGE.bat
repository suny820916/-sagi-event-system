@echo off
title SAGI V4.2 vMix Bridge
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0vmix-bridge-v42.ps1"
pause
