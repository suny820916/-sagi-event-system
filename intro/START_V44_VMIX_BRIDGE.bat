@echo off
title SAGI V4.4 vMix Bridge
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0vmix-bridge-v44.ps1"
pause
