@echo off
REM ClothesDryer - download runtime dependencies (sqlite3.exe) into this folder.
REM Double-click this file, or run it from a terminal. Pass /force to re-download.
setlocal
set ARGS=
if /I "%~1"=="/force" set ARGS=-Force
if /I "%~1"=="-force" set ARGS=-Force
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-libraries.ps1" %ARGS%
echo.
pause
