@echo off
setlocal
set "TOKEN=%~1"

if "%TOKEN%"=="" (
  echo Usage: fix-npm.cmd ^<npm_token^>
  echo.
  echo What it does:
  echo   1. point the "latest" dist-tag back to 0.1.1 ^(clean manifest^)
  echo   2. deprecate 0.1.2 ^(ships a manifest with a UTF-8 BOM^)
  echo.
  echo Create a token at https://www.npmjs.com/settings/branwen050/tokens
  echo   Granular Access Token / Read and write / All packages / Bypass 2FA
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
for %%i in ("%NODE%") do set "NODEDIR=%%~dpi"
set "NPMCLI=%NODEDIR%node_modules\npm\bin\npm-cli.js"

call "%NODE%" "%NPMCLI%" config set "//registry.npmjs.org/:_authToken" "%TOKEN%" --registry https://registry.npmjs.org >nul
if errorlevel 1 ( echo [error] failed to store token & exit /b 1 )

echo [auth] verifying...
call "%NODE%" "%NPMCLI%" whoami --registry https://registry.npmjs.org
if errorlevel 1 ( echo [error] token rejected & exit /b 1 )

echo.
echo [1/2] latest -^> 0.1.1
call "%NODE%" "%NPMCLI%" dist-tag add dsh-pencil@0.1.1 latest --registry https://registry.npmjs.org
if errorlevel 1 ( echo [error] dist-tag failed & exit /b 1 )

echo.
echo [2/2] deprecating 0.1.2
call "%NODE%" "%NPMCLI%" deprecate "dsh-pencil@0.1.2" "broken manifest (UTF-8 BOM) - install 0.1.1 instead" --registry https://registry.npmjs.org
if errorlevel 1 ( echo [warn] deprecate failed, dist-tag change still applied )

echo.
echo ---- current dist-tags ----
call "%NODE%" "%NPMCLI%" dist-tag ls dsh-pencil --registry https://registry.npmjs.org

echo.
echo Done. `npm install dsh-pencil` now resolves to 0.1.1.
endlocal
exit /b 0
