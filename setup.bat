@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Kubit Ticket System - Setup automatik
color 0B

REM ====== Konfigurimi global ======
set "REPO_URL=https://github.com/kubit-ks/Kubit-Ticket-System.git"
set "INSTALL_DIR=C:\Kubit"
REM setup.bat shperndahet nga nje repo publik i vecante (kubit-installer).
REM Repo kryesor mbetet privat - klienti autentifikohet vetem per git clone.
set "SETUP_RAW_URL=https://raw.githubusercontent.com/kubit-ks/kubit-installer/main/setup.bat"

REM ====== A. Auto-elevation (nese nuk eshte Admin, relaunch si Admin) ======
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Po kerkohen privilegjet e Administratorit...
    echo   Prano kerkesen ne dritaren UAC qe del.
    echo.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b 0
)

REM ====== B. Self-update (shkarko versionin me te ri nga GitHub) ======
REM Kapercehet nese scripti ekzekutohet me argumentin "--no-update" (pas nje update-i
REM qe me vone e rithrret veten, per te shmangur loop te pafundme).
if /I not "%~1"=="--no-update" (
    echo.
    echo ======================================================
    echo    Duke kontrolluar per version te ri te setup.bat ...
    echo ======================================================
    set "TEMP_SETUP=%TEMP%\kubit-setup-latest.bat"
    powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -Uri '%SETUP_RAW_URL%' -OutFile '%TEMP_SETUP%' -TimeoutSec 15 } catch { exit 1 }"
    if not exist "%TEMP_SETUP%" (
        echo [!] Nuk munda ta kontrolloj update-in ^(pa internet?^). Vazhdoj me versionin lokal.
    ) else (
        REM Krahaso hash-et - nese ndryshon, zevendeso veten dhe relaunch
        for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Path '%~f0' -Algorithm SHA256).Hash"') do set "LOCAL_HASH=%%H"
        for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Path '%TEMP_SETUP%' -Algorithm SHA256).Hash"') do set "REMOTE_HASH=%%H"
        if /I not "!LOCAL_HASH!"=="!REMOTE_HASH!" (
            echo.
            echo [!] U gjet version i ri i setup.bat ne GitHub.
            echo     Po e zevendesoj versionin lokal dhe rinisem...
            copy /Y "%TEMP_SETUP%" "%~f0" >nul
            del "%TEMP_SETUP%" >nul 2>&1
            start "" /wait cmd /c "%~f0" --no-update
            exit /b 0
        ) else (
            echo     Version aktual - nuk ka update.
            del "%TEMP_SETUP%" >nul 2>&1
        )
    )
)

echo.
echo ======================================================
echo    KUBIT TICKET SYSTEM - Setup automatik per klient
echo ======================================================
echo.

echo Instalimi do te kryhet ne: %INSTALL_DIR%
echo Repo: %REPO_URL%
echo.
choice /C YN /N /M "Vazhdo? [Y/N] "
if errorlevel 2 exit /b 0
echo.

REM ====== 1. Git ======
echo ------------------------------------------------------
echo [1/7] Kontroll i Git
echo ------------------------------------------------------
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo Git nuk u gjet. Po provoj instalimin me winget...
    where winget >nul 2>&1
    if !errorlevel! neq 0 (
        echo [X] winget nuk eshte i disponueshem.
        echo     Instalo Git manualisht nga https://git-scm.com  dhe ekzekuto perseri.
        pause & exit /b 1
    )
    winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
    if !errorlevel! neq 0 (
        echo [X] Instalimi i Git deshtoi.
        pause & exit /b 1
    )
    echo.
    echo [!] Git u instalua. MBYLL kete dritare dhe hape perseri setup.bat
    echo     qe PATH-i i ri te njihet nga sistemi.
    pause & exit /b 0
) else (
    for /f "tokens=*" %%i in ('git --version') do echo     %%i
)
echo.

REM ====== 2. Node.js ======
echo ------------------------------------------------------
echo [2/7] Kontroll i Node.js
echo ------------------------------------------------------
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo Node.js nuk u gjet. Po provoj instalimin me winget...
    where winget >nul 2>&1
    if !errorlevel! neq 0 (
        echo [X] winget nuk eshte i disponueshem.
        echo     Instalo Node.js LTS manualisht nga https://nodejs.org  dhe ekzekuto perseri.
        pause & exit /b 1
    )
    winget install --id OpenJS.NodeJS.LTS -e --silent --accept-source-agreements --accept-package-agreements
    if !errorlevel! neq 0 (
        echo [X] Instalimi i Node.js deshtoi.
        pause & exit /b 1
    )
    echo.
    echo [!] Node.js u instalua. MBYLL kete dritare dhe hape perseri setup.bat
    pause & exit /b 0
) else (
    for /f "tokens=*" %%i in ('node --version') do echo     Node %%i
    for /f "tokens=*" %%i in ('npm --version') do echo     npm %%i
)
echo.

REM ====== 3. Clone ose Pull ======
echo ------------------------------------------------------
echo [3/7] Marr kodin me te fundit nga GitHub
echo ------------------------------------------------------
REM Aktivizo credential manager te Windows qe Git ta ruaje PAT-in
git config --global credential.helper manager >nul 2>&1

if exist "%INSTALL_DIR%\.git" (
    echo Repo ekziston - bej git pull...
    pushd "%INSTALL_DIR%"
    git pull --ff-only
    if !errorlevel! neq 0 (
        echo [X] git pull deshtoi. Kontrollo manualisht ne %INSTALL_DIR%.
        popd & pause & exit /b 1
    )
    popd
) else (
    if exist "%INSTALL_DIR%" (
        echo [X] Folderi %INSTALL_DIR% ekziston por nuk eshte git repo.
        echo     Hiqe ose riemerto ate dhe ekzekuto perseri setup.bat
        pause & exit /b 1
    )
    echo.
    echo [!] Repo eshte PRIVAT - do te dale dritarja e autentifikimit.
    echo     Kur te dale prompt-i i GitHub:
    echo       Username: emri yt ne GitHub ^(ose "kubit-ks"^)
    echo       Password: Personal Access Token ^(jo fjalekalimi^)
    echo.
    echo     Krijo PAT-in ne: https://github.com/settings/tokens/new
    echo     Zgjidh scope: "repo" ^(Full control of private repositories^)
    echo.
    pause
    git clone "%REPO_URL%" "%INSTALL_DIR%"
    if !errorlevel! neq 0 (
        echo [X] git clone deshtoi. Kontrollo autentifikimin dhe provo perseri.
        pause & exit /b 1
    )
)
cd /d "%INSTALL_DIR%"
echo.

REM ====== 4. Instalim i varesive ======
echo ------------------------------------------------------
echo [4/7] Instalim i paketave npm (mund te zgjase disa minuta)
echo ------------------------------------------------------
echo Frontend...
if exist "package-lock.json" (
    call npm ci --no-audit --no-fund
) else (
    call npm install --no-audit --no-fund
)
if %errorlevel% neq 0 (
    echo [!] Provoj npm install si rezerve...
    call npm install --no-audit --no-fund
    if !errorlevel! neq 0 (echo [X] Varesite frontend deshtuan & pause & exit /b 1)
)

echo Server...
pushd server
if exist "package-lock.json" (
    call npm ci --no-audit --no-fund
) else (
    call npm install --no-audit --no-fund
)
if %errorlevel% neq 0 (
    call npm install --no-audit --no-fund
    if !errorlevel! neq 0 (echo [X] Varesite server deshtuan & popd & pause & exit /b 1)
)
popd
echo.

REM ====== 5. Konfigurimi i DB ======
echo ------------------------------------------------------
echo [5/7] Konfigurimi i Database
echo ------------------------------------------------------
if exist "server\db.js" (
    echo     server\db.js ekziston - kapercej konfigurimin interaktiv.
    echo     Nese deshiron ta rikonfigurosh, fshi server\db.js dhe ekzekuto perseri.
) else (
    echo Nis setup-in interaktiv per SQL Server...
    call node setup.cjs
    if !errorlevel! neq 0 (
        echo [X] setup.cjs deshtoi.
        pause & exit /b 1
    )
)
echo.

REM ====== 6. Build frontend ======
echo ------------------------------------------------------
echo [6/7] Ndertoj frontend (vite build)
echo ------------------------------------------------------
call npm run build
if %errorlevel% neq 0 (echo [X] Build deshtoi & pause & exit /b 1)
echo.

REM ====== 7. Windows Service ======
echo ------------------------------------------------------
echo [7/7] Instalim i Windows Service "KubitAPI"
echo ------------------------------------------------------
sc query KubitAPI >nul 2>&1
if %errorlevel% equ 0 (
    echo     Sherbimi ekziston - po e ristartoj...
    net stop KubitAPI >nul 2>&1
    timeout /t 2 /nobreak >nul
    net start KubitAPI
    if !errorlevel! neq 0 (
        echo [!] Startimi deshtoi. Kontrollo manualisht:  Get-Service KubitAPI
    )
) else (
    call node scripts\install-service.cjs
    if !errorlevel! neq 0 (
        echo [X] Instalimi i sherbimit deshtoi.
        pause & exit /b 1
    )
)
echo.

REM ====== Firewall ======
echo ------------------------------------------------------
echo Rregulli i firewall per portin 3002
echo ------------------------------------------------------
netsh advfirewall firewall show rule name="Kubit API" >nul 2>&1
if %errorlevel% neq 0 (
    netsh advfirewall firewall add rule name="Kubit API" dir=in action=allow protocol=TCP localport=3002 >nul
    echo     Rregulli u shtua.
) else (
    echo     Rregulli ekziston tashme.
)
echo.

REM ====== Status perfundimtar ======
echo ======================================================
echo    INSTALIMI PERFUNDOI ME SUKSES
echo ======================================================
echo.
echo Statusi i sherbimit:
sc query KubitAPI | findstr /C:"STATE"
echo.
echo URL:   http://localhost:3002
echo Logs:  %INSTALL_DIR%\server\daemon\
echo.
echo ------------------------------------------------------
echo HAPAT E FUNDIT (manual) per auto-update nga GitHub:
echo ------------------------------------------------------
echo  1. Hap: https://github.com/kubit-ks/Kubit-Ticket-System/settings/actions/runners
echo  2. Kliko  "New self-hosted runner"  -^>  Windows  -^>  x64
echo  3. Ndiq komandat PowerShell te GitHub per download + config
echo  4. Kur te pyesi per "labels" shto:  kubit-client
echo  5. Kur te pyesi "Would you like to run as service?" pergjigju:  Y
echo.
echo Pas kesaj, cdo "git push" ne main do te perditesoje automatikisht
echo aplikacionin ne kete server.
echo.
pause
endlocal
