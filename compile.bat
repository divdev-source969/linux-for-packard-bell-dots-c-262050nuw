@echo off
REM ============================================================
REM  DOT-OS Builder for Windows  (Packard Bell Dot 262050NUW)
REM  Double-click to build the 32-bit Linux ISO via WSL Ubuntu.
REM  Requires: Ubuntu app from Microsoft Store (WSL2), internet.
REM ============================================================
echo.
echo  DOT-OS Builder - building 32-bit ISO for Packard Bell Dot
echo.

REM --- locate the builder script next to this .bat
set "HERE=%~dp0"
if not exist "%HERE%wsl-dot-os-builder.sh" (
    echo  [ERROR] wsl-dot-os-builder.sh not found next to compile.bat!
    echo  Download both files into the same folder, then retry.
    pause
    exit /b 1
)

REM --- make sure WSL exists
echo  Checking WSL...
where wsl >nul 2>nul
if errorlevel 1 (
    echo  [ERROR] WSL not found. Open PowerShell as Admin and run:  wsl --install
    echo  Then reboot, install Ubuntu from the Microsoft Store, and retry.
    pause
    exit /b 1
)

REM --- check Ubuntu is installed
echo  Checking Ubuntu...
wsl -l -v | findstr /I "Ubuntu" >nul
if errorlevel 1 (
    echo  [ERROR] Ubuntu not installed in WSL.
    echo  Install "Ubuntu" from the Microsoft Store, set a username/password, retry.
    pause
    exit /b 1
)

REM --- copy the script into WSL home and run it
echo  Starting build inside Ubuntu (30-90 minutes)...
echo  Keep this window open. You may be asked for your Ubuntu password.
echo.
wsl -e bash -lc "cp \"$(wslpath '%HERE%wsl-dot-os-builder.sh')\" ~/wsl-dot-os-builder.sh && chmod +x ~/wsl-dot-os-builder.sh && ~/wsl-dot-os-builder.sh"

if errorlevel 1 (
    echo.
    echo  [BUILD FAILED] Copy ALL output above and paste it to the AI chat for a fix.
    pause
    exit /b 1
)

echo.
echo  ================================================
echo   DONE! The ISO should be on your Windows Desktop:
echo     DOT-OS-i386.iso
echo   Flash it to USB with Rufus, boot the Dot,
echo   then run:  sudo dot-detect
echo  ================================================
pause
