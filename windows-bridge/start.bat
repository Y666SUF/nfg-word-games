@echo off
cd /d "%~dp0"
if not exist node_modules (
  echo Installing bridge dependencies...
  call npm install
)
if not exist ..\\app\\dist (
  echo Building app...
  pushd ..\\app
  call npm install
  call npm run build
  popd
)
node word-games-server.js
