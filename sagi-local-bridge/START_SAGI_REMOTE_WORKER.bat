@echo off
title SAGI REMOTE WORKER
cd /d "%~dp0"
echo.
echo ==============================================
echo  SAGI REMOTE WORKER - Instagram over PC network
echo ==============================================
echo.
where python >nul 2>nul
if errorlevel 1 (
  echo Python not found. Install Python 3 and enable Add Python to PATH.
  pause
  exit /b 1
)
python -m pip install --disable-pip-version-check --quiet --upgrade requests yt-dlp
echo.
python remote_worker.py
pause
