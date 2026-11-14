@echo off
setlocal
REM ============================================================
REM  DOT-OS Builder for Windows (Packard Bell Dot 262050NUW)
REM  Builds the current DOT-OS ISO, including the installDotos command.
REM  Requires WSL2 with an Ubuntu distribution and internet access.
REM ============================================================
echo.
echo  DOT-OS Builder - building 32-bit ISO with the installer
 echo.

set "HERE=%~dp0"
set "BUILDER_WIN=%HERE%wsl-dot-os-builder.sh"
if not exist "%BUILDER_WIN%" (
    echo [ERROR] wsl-dot-os-builder.sh was not found next to compile.bat.
    pause
    exit /b 1
)

where wsl >nul 2>nul
if errorlevel 1 (
    echo [ERROR] WSL was not found. Open PowerShell as Administrator and run: wsl --install
    pause
    exit /b 1
)

wsl -l -q | findstr /I "Ubuntu" >nul
if errorlevel 1 (
    echo [ERROR] No Ubuntu distribution was found in WSL.
    echo Install Ubuntu from the Microsoft Store, complete first-run setup, then retry.
    pause
    exit /b 1
)

REM Resolve the Windows script path to a WSL path before invoking bash.
for /f "delims=" %%I in ('wsl wslpath -a "%BUILDER_WIN%"') do set "BUILDER_WSL=%%I"
if not defined BUILDER_WSL (
    echo [ERROR] Could not convert the builder path for WSL.
    pause
    exit /b 1
)

echo Starting the DOT-OS build in WSL. This can take 30-90 minutes.
echo Keep this window open; Ubuntu may ask for your password.
echo.
wsl -e bash -lc "cp '%BUILDER_WSL%' ~/wsl-dot-os-builder.sh && sed -i 's/\r$//' ~/wsl-dot-os-builder.sh && chmod +x ~/wsl-dot-os-builder.sh && ~/wsl-dot-os-builder.sh"
if errorlevel 1 (
    echo.
    echo [BUILD FAILED] Review the output above for the error.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Build finished. Look for DOT-OS-i386.iso on your Desktop.
echo  In the live system, run installDotos to launch the installer.
echo ============================================================
pause
endlocal
