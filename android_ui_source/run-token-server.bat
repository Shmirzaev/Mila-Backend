@echo off
setlocal

set ROOT=%~dp0
set SERVER=%ROOT%token-server\server.py
set VENV_PY=%ROOT%token-server\.venv\Scripts\python.exe

if exist "%VENV_PY%" (
  "%VENV_PY%" "%SERVER%"
  goto :eof
)

where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%SERVER%"
  goto :eof
)

where python >nul 2>nul
if %ERRORLEVEL%==0 (
  python "%SERVER%"
  goto :eof
)

echo Python was not found on PATH.
echo Run token-server\server.py with the same Python environment you already use for your MILA agent,
echo or install Python and the packages from token-server\requirements.txt first.
exit /b 1
