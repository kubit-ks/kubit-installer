@echo off
title Kubit - Bootstrap Installer
color 0B
echo.
echo ======================================================
echo    KUBIT TICKET SYSTEM - Bootstrap
echo ======================================================
echo.
echo Duke shkarkuar setup.bat me te fundit nga GitHub ...
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/kubit-ks/kubit-installer/main/setup.bat' -OutFile \"$env:TEMP\kubit-setup.bat\" -TimeoutSec 30 } catch { Write-Host $_.Exception.Message; exit 1 }"
if not exist "%TEMP%\kubit-setup.bat" (
    echo.
    echo [X] Shkarkimi deshtoi. Kontrollo internetin dhe provo perseri.
    pause
    exit /b 1
)
echo Shkarkimi OK. Nis setup-in ...
echo.
start "" /wait "%TEMP%\kubit-setup.bat"
