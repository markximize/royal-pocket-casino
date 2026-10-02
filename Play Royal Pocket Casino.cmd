@echo off
setlocal
rem Keep the runtime outside source control; saves live in LOVE's user-data folder.
set "previewRuntime=%~dp0.local-tools\love-11.5-win64\love.exe"
if exist "%previewRuntime%" goto launch
for /f "delims=" %%R in ('where love.exe 2^>nul') do set "previewRuntime=%%R"
if exist "%previewRuntime%" goto launch
echo LOVE 11.5 is needed to run this desktop preview.
echo Install it from https://love2d.org/ and reopen this launcher.
pause
exit /b 1
:launch
"%previewRuntime%" "%~dp0."
exit /b %errorlevel%
