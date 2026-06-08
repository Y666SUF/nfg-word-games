@echo off
setlocal
cd /d "%~dp0\.."

echo.
echo NOTE: For iPhone leaderboards, use the NFG Platform launcher instead:
echo   C:\Users\Yusef\Documents\nfg-crash\run-electron-cloudflare.bat
echo.
echo That starts Word Games on port 19877 and exposes it at:
echo   https://y666suf.com/api/word-games/*
echo.
echo This script is for local dev/testing only.
echo.

if not exist "server.py" (
  echo ERROR: server.py not found in %CD%
  echo Run: git pull origin main
  pause
  exit /b 1
)

if not exist ".venv\Scripts\activate.bat" (
  echo Creating Python virtual environment...
  py -3 -m venv .venv
  if errorlevel 1 (
    echo Failed to create venv. Install Python 3 from https://www.python.org/downloads/
    pause
    exit /b 1
  )
)

call .venv\Scripts\activate.bat
pip install -r requirements.txt

echo.
echo Starting NFG Word Games LOCAL server on port 19877...
echo   Health: http://127.0.0.1:19877/api/word-games/health
echo   iPhone app uses https://y666suf.com ^(not this local URL^)
echo.
py -m uvicorn server:app --host 0.0.0.0 --port 19877
