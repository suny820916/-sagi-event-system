@echo off
title SAGI V4.3.1 vMix Bridge
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0vmix-bridge-v431.ps1"
pause
