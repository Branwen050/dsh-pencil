@echo off
setlocal
set "HERE=%~dp0"
set "TOKEN=%~1"

if "%TOKEN%"=="" (
  echo Usage: publish-npm.cmd ^<npm_token^>
  echo.
  echo Create a token at https://www.npmjs.com/settings/branwen050/tokens
  echo   Type:        Granular Access Token
  echo   Permissions: Read and write
  echo   Packages:    All packages
  echo   Bypass 2FA:  checked
  exit /b 1
)

rem --- locate a real Node and the npm CLI that ships with it ---
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
if not exist "%NPMCLI%" (
  echo [error] npm CLI not found next to %NODE%
  exit /b 1
)
echo [info] node: %NODE%

rem --- store the token for the registry ---
call "%NODE%" "%NPMCLI%" config set "//registry.npmjs.org/:_authToken" "%TOKEN%" --registry https://registry.npmjs.org
if errorlevel 1 (
  echo [error] failed to write token
  exit /b 1
)

echo [auth] checking identity...
call "%NODE%" "%NPMCLI%" whoami --registry https://registry.npmjs.org
if errorlevel 1 (
  echo [error] token rejected. Recreate it with Read+write and Bypass 2FA.
  exit /b 1
)

echo.
echo [publish] uploading %HERE% ...
pushd "%HERE%"
call "%NODE%" "%NPMCLI%" publish --registry https://registry.npmjs.org
set "RC=%ERRORLEVEL%"
popd

if not "%RC%"=="0" (
  echo.
  echo [error] publish failed, exit code %RC%
  exit /b %RC%
)

echo.
echo [done] published. Verify with: npm view dsh-pencil
endlocal
exit /b 0
