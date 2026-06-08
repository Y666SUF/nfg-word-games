@echo off
setlocal
cd /d "%~dp0\.."

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
echo Starting NFG Word Games server on port 19877...
echo   Health:  http://127.0.0.1:19877/api/word-games/health
echo   Leaderboard: http://127.0.0.1:19877/api/word-games/leaderboard
echo.
echo Keep this window open while playing. Press Ctrl+C to stop.
py -m uvicorn server:app --host 0.0.0.0 --port 19877
