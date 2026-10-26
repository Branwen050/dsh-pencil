@echo off
setlocal
set "HERE=%~dp0"
set "PLUGIN=%HERE:~0,-1%"
set "PROFILE=%APPDATA%\dsh-desktop\harness\profiles\web"
set "PNPM=%APPDATA%\dsh-desktop\harness\.desktop-bin\pnpm.cmd"

if not exist "%PROFILE%\package.json" (
  echo [error] web profile not found: %PROFILE%
  echo         Start DSH Desktop once, then retry.
  exit /b 1
)
if not exist "%PNPM%" (
  echo [error] pnpm shim not found: %PNPM%
  exit /b 1
)

rem --- locate a real Node; PATH may point at DSH's Electron node ---
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
echo [info] node: %NODE%

rem --- backup manifests ---
set "STAMP=%RANDOM%%RANDOM%"
copy /y "%PROFILE%\package.json" "%PROFILE%\package.json.bak-pencil-%STAMP%" >nul
copy /y "%PROFILE%\pnpm-lock.yaml" "%PROFILE%\pnpm-lock.yaml.bak-pencil-%STAMP%" >nul
echo [1/3] backed up manifests ^(%STAMP%^)

rem --- step 1: link dependency ---
pushd "%PROFILE%"
call "%PNPM%" add "link:%PLUGIN%" --prefer-offline
if errorlevel 1 (
  popd
  echo [error] pnpm add failed
  exit /b 1
)
popd
echo [2/3] dependency linked

rem --- step 2: register bundle ---
"%NODE%" "%HERE%add-bundle.mjs"
if errorlevel 1 (
  echo [error] add-bundle failed
  exit /b 1
)
echo [3/3] bundle registered

echo.
echo Done. Fully quit DSH Desktop ^(tray icon - Exit^), then start it again.
endlocal
exit /b 0
