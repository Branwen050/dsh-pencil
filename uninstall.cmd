@echo off
setlocal
set "HERE=%~dp0"
set "PROFILE=%APPDATA%\dsh-desktop\harness\profiles\web"
set "PNPM=%APPDATA%\dsh-desktop\harness\.desktop-bin\pnpm.cmd"

if not exist "%PROFILE%\package.json" (
  echo [error] web profile not found: %PROFILE%
  exit /b 1
)
if not exist "%PNPM%" (
  echo [error] pnpm shim not found: %PNPM%
  exit /b 1
)

set "NODE="
if exist "%ProgramFiles%\nodejs\node.exe" set "NODE=%ProgramFiles%\nodejs\node.exe"
if not defined NODE if exist "D:\New Folder\node.exe" set "NODE=D:\New Folder\node.exe"
if not defined NODE (
  for /f "delims=" %%i in ('where node 2^>nul') do (
    echo %%i | findstr /i "\.desktop-bin\" >nul
    if errorlevel 1 if not defined NODE set "NODE=%%i"
  )
)
if not defined NODE (
  echo [error] no usable Node found
  exit /b 1
)

set "STAMP=%RANDOM%%RANDOM%"
copy /y "%PROFILE%\package.json" "%PROFILE%\package.json.bak-unpencil-%STAMP%" >nul

pushd "%PROFILE%"
call "%PNPM%" remove dsh-pencil
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" (
  echo [warn] pnpm remove returned %RC%, continuing with bundle cleanup
)
echo [1/2] dependency removed

"%NODE%" "%HERE%remove-bundle.mjs" dsh-pencil
echo [2/2] bundle entry removed

echo.
echo Also make sure the directory is gone:
if exist "%PROFILE%\node_modules\dsh-pencil" (
  echo   [warn] still present: %PROFILE%\node_modules\dsh-pencil
  echo          Desktop re-registers plugins from that directory on startup.
) else (
  echo   node_modules\dsh-pencil: removed
)

echo.
echo Restart DSH Desktop to apply.
endlocal
exit /b 0
