@echo off
title SAGI V4.5 vMix Bridge
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0vmix-bridge-v45.ps1"
pause
