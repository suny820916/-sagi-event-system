@echo off
title SAGI LOCAL BRIDGE
cd /d "%~dp0"
echo.
echo ==============================================
echo  SAGI LOCAL BRIDGE - Instagram Direct Download
echo ==============================================
echo.
where python >nul 2>nul
if errorlevel 1 (
  echo Python not found. Install Python 3 first and enable "Add Python to PATH".
  pause
  exit /b 1
)
python -m pip install --disable-pip-version-check --quiet --upgrade flask yt-dlp
echo.
echo Starting SAGI LOCAL BRIDGE...
echo Keep this window open.
echo.
python server.py
pause
