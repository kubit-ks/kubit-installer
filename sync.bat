@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Kubit - Sync me GitHub
color 0A

REM ─────────────────────────────────────────────────────────────
REM  Kubit Sync — minimal, i fokusuar
REM  Perdorimi:  C:\Kubit\sync.bat  (dopio-klik, cdo here)
REM
REM  Cka ben:
REM   - Auto-elevation UAC
REM   - Ndalon KubitAPI ne mes
REM   - Ruan db.js + portet
REM   - git fetch + reset --hard origin/main
REM   - Restoron db.js + portet
REM   - npm install nese deps ndryshuan
REM   - vite build
REM   - Restart KubitAPI
REM
REM  Nese db.js mungon (instalim i pare) → node setup.cjs per konfigurim
REM ─────────────────────────────────────────────────────────────

set "SCRIPT_VERSION=2026-04-21.2"
REM INSTALL_DIR eshte gjithmone C:\Kubit - s'varet nga ku ekzekutohet sync.bat
set "INSTALL_DIR=C:\Kubit"
set "LOG=%TEMP%\kubit-sync.log"

echo [%date% %time%] sync.bat v!SCRIPT_VERSION! filloi > "%LOG%"
echo [%date% %time%] Script path: %~f0 >> "%LOG%"
echo [%date% %time%] INSTALL_DIR = %INSTALL_DIR% >> "%LOG%"

REM ── Auto-elevation ──
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Po kerkohen privilegjet e Administratorit...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b 0
)

REM ── Self-relocate ne TEMP nese skripti po punon brenda INSTALL_DIR ──
REM (per te shmangur bllokimin nga git reset)
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
if /I "!SCRIPT_DIR!"=="%INSTALL_DIR%" (
    set "RELOC=%TEMP%\kubit-sync-run.bat"
    copy /Y "%~f0" "!RELOC!" >nul
    echo [%date% %time%] Relaunching from TEMP >> "%LOG%"
    start "" /wait cmd /c "!RELOC!"
    exit /b 0
)

REM ── Verifiko qe INSTALL_DIR ekziston ──
if not exist "%INSTALL_DIR%" (
    echo.
    echo [X] Folderi %INSTALL_DIR% nuk ekziston.
    echo     Perdor install-fresh.bat per instalim te ri.
    echo [%date% %time%] ERROR: INSTALL_DIR missing >> "%LOG%"
    goto :end
)

cd /d "%INSTALL_DIR%"

echo.
echo ==================================================
echo   KUBIT SYNC — v!SCRIPT_VERSION!
echo   Folder:  %INSTALL_DIR%
echo ==================================================
echo.

REM ── Verifiko qe eshte git repo ──
if not exist "%INSTALL_DIR%\.git" (
    echo [X] %INSTALL_DIR% nuk eshte git repo.
    echo     Perdor install-fresh.bat per instalim te ri.
    echo [%date% %time%] ERROR: not a git repo >> "%LOG%"
    goto :end
)

REM ── Ruaj konfigurimin e klientit ──
echo [1/6] Ruaj konfigurimin lokal...
if exist "server\db.js" copy /Y "server\db.js" "%TEMP%\kubit-db.bak" >nul

set "API_PORT=3002"
set "WEB_PORT=5173"
for /f "tokens=5 delims= " %%P in ('findstr /R "^const PORT" server\index.js 2^>nul') do (
    set "T=%%P"
    set "T=!T:;=!"
    if not "!T!"=="" set "API_PORT=!T!"
)
for /f "tokens=2 delims=:," %%P in ('findstr /C:"port:" vite.config.js 2^>nul') do (
    set "T=%%P"
    set "T=!T: =!"
    if not "!T!"=="" set "WEB_PORT=!T!"
)
echo     API=!API_PORT!  Frontend=!WEB_PORT!
echo [%date% %time%] ports saved: API=!API_PORT! WEB=!WEB_PORT! >> "%LOG%"
echo.

REM ── Ndalo KubitAPI (leshon file locks) ──
echo [2/6] Ndalim i KubitAPI service...
sc query KubitAPI >nul 2>&1
if not errorlevel 1 (
    net stop KubitAPI >nul 2>&1
    timeout /t 2 /nobreak >nul
)
echo.

REM ── Leje + pastrim ──
takeown /F "%INSTALL_DIR%" /R /A >nul 2>&1
icacls "%INSTALL_DIR%" /grant Administrators:F /T /C /Q >nul 2>&1
attrib -R "%INSTALL_DIR%\*.*" /S /D >nul 2>&1

REM ── git fetch + reset (me 3 retries) ──
echo [3/6] Git fetch + reset nga origin/main...
git fetch origin >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [X] git fetch deshtoi. Kontrollo %LOG%
    goto :fail
)

set "OK=0"
for /L %%i in (1,1,3) do (
    if "!OK!"=="0" (
        git reset --hard origin/main >> "%LOG%" 2>&1
        if not errorlevel 1 (
            set "OK=1"
        ) else (
            echo     [!] Retry %%i deshtoi. Pritja 3 sek...
            timeout /t 3 /nobreak >nul
            git clean -fdx >> "%LOG%" 2>&1
        )
    )
)
if "!OK!"=="0" (
    echo [X] git reset deshtoi 3 here. Kontrollo %LOG%
    goto :fail
)
echo     Kodi u freskua.
echo.

REM ── Restoro db.js + portet ──
echo [4/6] Restorim i konfigurimit...
if exist "%TEMP%\kubit-db.bak" copy /Y "%TEMP%\kubit-db.bak" "server\db.js" >nul

powershell -NoProfile -Command "$p = Get-Content 'server\index.js' -Raw; $p = $p -replace '(?m)^const PORT\s*=\s*\d+', ('const PORT = ' + !API_PORT!); Set-Content -NoNewline 'server\index.js' -Value $p -Encoding UTF8" >> "%LOG%" 2>&1
if exist "vite.config.js" (
    powershell -NoProfile -Command "$v = Get-Content 'vite.config.js' -Raw; $v = $v -replace 'port:\s*\d+', ('port: ' + !WEB_PORT!); $v = $v -replace 'http://localhost:\d+', ('http://localhost:' + !API_PORT!); Set-Content -NoNewline 'vite.config.js' -Value $v -Encoding UTF8" >> "%LOG%" 2>&1
)
echo     db.js + portet e restauruara.
echo.

REM ── Instalim i pare (nese db.js mungon) ──
if not exist "server\db.js" (
    echo [!] server\db.js mungon - Instalim i pare.
    echo     Po nis setup.cjs per konfigurim DB...
    echo.
    call node setup.cjs
    if errorlevel 1 (
        echo [X] setup.cjs deshtoi.
        goto :fail
    )
)

REM ── npm install (vetem nese node_modules mungon ose package ndryshoi) ──
echo [5/6] Verifikim i paketave npm...
if not exist "node_modules" (
    echo     Frontend npm install...
    call npm install --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
)
if not exist "server\node_modules" (
    echo     Server npm install...
    pushd server
    call npm install --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
    popd
)

REM ── Build frontend + restart service ──
echo [6/6] Build + Restart service...
call npm run build >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [X] Build deshtoi. Kontrollo %LOG%
    goto :fail
)

sc query KubitAPI >nul 2>&1
if errorlevel 1 (
    REM Sherbimi s'ekziston - instalo
    if exist "scripts\install-service.cjs" (
        call node scripts\install-service.cjs >> "%LOG%" 2>&1
    )
) else (
    net start KubitAPI >nul 2>&1
)

echo.
echo ==================================================
echo   SYNC U KRY ME SUKSES
echo ==================================================
sc query KubitAPI 2>nul | findstr /C:"STATE" 2>nul
echo.
echo URL:  http://localhost:!API_PORT!
echo Log:  %LOG%
echo [%date% %time%] SUCCESS >> "%LOG%"
goto :end

:fail
echo.
echo ==================================================
echo   [X] SYNC DESHTOI
echo ==================================================
echo Log: %LOG%

:end
echo.
echo Shtyp ENTER per te mbyllur...
pause >nul
endlocal
