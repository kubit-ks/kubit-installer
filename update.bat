@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Kubit Ticket System - Update
color 0A

REM ====== Konfigurimi ======
set "INSTALL_DIR=C:\Kubit"
set "LOG=%TEMP%\kubit-update.log"

echo [%date% %time%] Update filloi > "%LOG%"

REM ====== A. Auto-elevation ======
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Po kerkohen privilegjet e Administratorit...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b 0
)

echo.
echo ======================================================
echo    KUBIT TICKET SYSTEM - Update nga Git
echo ======================================================
echo.

REM ====== B. Verifiko install dir ======
if not exist "%INSTALL_DIR%\.git" (
    echo [X] Instalimi nuk u gjet ne %INSTALL_DIR%
    echo     Ky skript update-on vetem instalime ekzistuese.
    echo     Per instalim te ri perdor setup-offline.bat ose setup.bat
    echo [%date% %time%] ERROR: .git not found >> "%LOG%"
    goto :end
)

cd /d "%INSTALL_DIR%"
echo Folderi: %INSTALL_DIR%
echo.

REM ====== 1. Backup i server\db.js ======
echo ------------------------------------------------------
echo [1/5] Backup i konfigurimit te DB
echo ------------------------------------------------------
set "DB_BACKUP=%TEMP%\kubit-db-backup.js"
if exist "server\db.js" (
    copy /Y "server\db.js" "%DB_BACKUP%" >nul
    echo     db.js u ruajt ne: %DB_BACKUP%
    echo [%date% %time%] db.js backup OK >> "%LOG%"
) else (
    echo [!] server\db.js nuk ekziston - do vazhdoj pa backup
    echo [%date% %time%] WARNING: db.js missing >> "%LOG%"
)
echo.

REM ====== 2. Git pull ======
echo ------------------------------------------------------
echo [2/5] Marr kodin e fundit nga Git
echo ------------------------------------------------------
where git >nul 2>&1
if errorlevel 1 (
    echo [X] git nuk eshte i instaluar
    echo [%date% %time%] ERROR: git missing >> "%LOG%"
    goto :fail
)

REM Nese db.js eshte e modifikuar, stash nese ka ndryshime qe s'jane committed
git stash push server\db.js >nul 2>&1

git pull --ff-only
set "PULL_EXIT=!errorlevel!"
echo [%date% %time%] git pull exit=!PULL_EXIT! >> "%LOG%"
if not "!PULL_EXIT!"=="0" (
    echo [X] git pull deshtoi ^(exit !PULL_EXIT!^)
    echo     Kontrollo manualisht ne %INSTALL_DIR%
    goto :fail
)
echo.

REM ====== 3. Restoro db.js ======
echo ------------------------------------------------------
echo [3/5] Restorim i konfigurimit te DB
echo ------------------------------------------------------
if exist "%DB_BACKUP%" (
    copy /Y "%DB_BACKUP%" "server\db.js" >nul
    echo     server\db.js u restaura nga backup.
    echo [%date% %time%] db.js restored >> "%LOG%"
) else (
    echo [!] Asnje backup - db.js mbetet nga git ^(mund te kete credentials te gabuar^)
)
echo.

REM ====== 4. npm install (nese package.json ka ndryshuar) ======
echo ------------------------------------------------------
echo [4/5] Verifikim i paketave npm
echo ------------------------------------------------------
echo     Frontend...
call npm install --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [!] npm install frontend deshtoi - kontrollo %LOG%
)
echo     Server...
pushd server
call npm install --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [!] npm install server deshtoi - kontrollo %LOG%
)
popd
echo.

REM ====== 5. Build + restart service ======
echo ------------------------------------------------------
echo [5/5] Build frontend + restart KubitAPI
echo ------------------------------------------------------
echo     Building frontend ^(vite build^)...
call npm run build >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [X] Build deshtoi - kontrollo %LOG%
    goto :fail
)
echo     Build OK.

echo     Restart KubitAPI service...
sc query KubitAPI >nul 2>&1
if not errorlevel 1 (
    net stop KubitAPI >nul 2>&1
    timeout /t 2 /nobreak >nul
    net start KubitAPI
    if errorlevel 1 (
        echo [!] Startimi i sherbimit deshtoi - kontrollo: Get-Service KubitAPI
    ) else (
        echo     Sherbimi po punon.
    )
) else (
    echo [!] Sherbimi KubitAPI nuk eshte instaluar.
    echo     Ekzekuto setup-offline.bat per ta instaluar.
)
echo.

echo ======================================================
echo    UPDATE PERFUNDOI ME SUKSES
echo ======================================================
echo [%date% %time%] SUCCESS >> "%LOG%"
echo.
sc query KubitAPI 2>nul | findstr /C:"STATE" 2>nul
echo.
echo URL: http://localhost:3002
echo Log: %LOG%
goto :end

:fail
echo.
echo ======================================================
echo    [X] UPDATE DESHTOI
echo ======================================================
echo.
echo Kontrollo log file: %LOG%

:end
echo.
echo Shtyp ENTER per te mbyllur...
pause >nul
endlocal
