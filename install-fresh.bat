@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Kubit Ticket System - Instalim i ri
color 0B

REM ====== Konfigurimi ======
set "SCRIPT_VERSION=2026-04-21.6"
set "REPO_URL=https://github.com/kubit-ks/Kubit-Ticket-System.git"
set "INSTALL_DIR=C:\Kubit"
set "LOG=%TEMP%\kubit-install-fresh.log"

echo [%date% %time%] Instalimi filloi - install-fresh.bat v!SCRIPT_VERSION! > "%LOG%"
echo [%date% %time%] Script path: %~f0 >> "%LOG%"

REM ====== Nese skripti po ekzekutohet brenda INSTALL_DIR, zhvendose ne TEMP ======
REM Kjo parandalon bllokim te .bat-eve gjate git reset --hard
set "SCRIPT_DIR=%~dp0"
if /I "!SCRIPT_DIR:~0,8!"=="%INSTALL_DIR:~0,8%" (
    echo [!] Skripti po punon brenda %INSTALL_DIR%. Duke e zhvendosur ne %%TEMP%%...
    set "NEW_PATH=%TEMP%\kubit-install-fresh-v!SCRIPT_VERSION!.bat"
    copy /Y "%~f0" "!NEW_PATH!" >nul
    echo [%date% %time%] Relaunching from !NEW_PATH! >> "%LOG%"
    start "" /wait cmd /c "!NEW_PATH!"
    exit /b 0
)

REM ====== A. Auto-elevation ======
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Po kerkohen privilegjet e Administratorit...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b 0
)

echo.
echo ======================================================
echo    KUBIT TICKET SYSTEM - Instalim i plote nga fillimi
echo    Script version: !SCRIPT_VERSION!
echo ======================================================
echo.
echo Folderi i instalimit:  %INSTALL_DIR%
echo Repo i burimit:        %REPO_URL%
echo Log:                   %LOG%
echo.
echo Hapat qe do behen automatikisht:
echo   1. Verifikim/instalim i Git dhe Node.js (me winget)
echo   2. Verifikim i ODBC Driver per SQL Server
echo   3. Klon i kodit nga GitHub (do kerkohet login nje here)
echo   4. Shkarkim i TE GJITHA varsive npm paraprakisht
echo   5. Konfigurim interaktiv i DB + portit
echo   6. Build i frontend-it
echo   7. Instalim si Windows Service (auto-start ne boot)
echo   8. Rregull firewall
echo.
set "ANS="
set /p "ANS=Vazhdo? [Y/N] (default Y): "
if "!ANS!"=="" set "ANS=Y"
if /I not "!ANS!"=="Y" (echo Anulluar. & goto :end)
echo.

REM ====== 1. Git ======
echo ------------------------------------------------------
echo [1/8] Git
echo ------------------------------------------------------
echo [%date% %time%] HAPI 1 - Git >> "%LOG%"
where git >nul 2>&1
if errorlevel 1 (
    echo Git nuk u gjet. Po instalohet me winget...
    where winget >nul 2>&1
    if errorlevel 1 (
        echo [X] winget mungon. Instalo Git nga https://git-scm.com dhe ri-ekzekuto.
        goto :fail
    )
    winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements >> "%LOG%" 2>&1
    echo [!] Git u instalua. MBYLL dhe hape perseri install-fresh.bat
    goto :end
) else (
    for /f "tokens=*" %%i in ('git --version') do echo     %%i
)
echo.

REM ====== 2. Node.js ======
echo ------------------------------------------------------
echo [2/8] Node.js
echo ------------------------------------------------------
echo [%date% %time%] HAPI 2 - Node.js >> "%LOG%"
where node >nul 2>&1
if errorlevel 1 (
    echo Node.js nuk u gjet. Po instalohet me winget...
    where winget >nul 2>&1
    if errorlevel 1 (
        echo [X] winget mungon. Instalo Node.js LTS nga https://nodejs.org
        goto :fail
    )
    winget install --id OpenJS.NodeJS.LTS -e --silent --accept-source-agreements --accept-package-agreements >> "%LOG%" 2>&1
    echo [!] Node.js u instalua. MBYLL dhe hape perseri install-fresh.bat
    goto :end
) else (
    for /f "tokens=*" %%i in ('node --version') do echo     Node %%i
    for /f "tokens=*" %%i in ('npm --version') do echo     npm %%i
)
echo.

REM ====== 3. ODBC Driver (per msnodesqlv8 Windows Auth) ======
echo ------------------------------------------------------
echo [3/8] Verifikim i SQL Server ODBC Driver
echo ------------------------------------------------------
echo [%date% %time%] HAPI 3 - ODBC check >> "%LOG%"
set "ODBC_FOUND=0"
reg query "HKLM\SOFTWARE\ODBC\ODBCINST.INI\ODBC Driver 17 for SQL Server" >nul 2>&1
if not errorlevel 1 set "ODBC_FOUND=1" & echo     ODBC Driver 17 i gjetur
reg query "HKLM\SOFTWARE\ODBC\ODBCINST.INI\ODBC Driver 18 for SQL Server" >nul 2>&1
if not errorlevel 1 set "ODBC_FOUND=1" & echo     ODBC Driver 18 i gjetur
if "!ODBC_FOUND!"=="0" (
    echo [!] Nuk u gjet ODBC Driver 17/18 per SQL Server.
    echo     Po e instaloj me winget...
    where winget >nul 2>&1
    if not errorlevel 1 (
        winget install --id Microsoft.msodbcsql.17 -e --silent --accept-source-agreements --accept-package-agreements >> "%LOG%" 2>&1
        if errorlevel 1 (
            echo [!] Instalimi automatik deshtoi. Shkarkoje manualisht nga:
            echo     https://www.microsoft.com/en-us/download/details.aspx?id=56567
            echo     ^(vazhdoj gjithsesi, por lidhja me DB mund te deshtoje^)
        ) else (
            echo     ODBC Driver 17 u instalua.
        )
    ) else (
        echo [!] winget mungon. Instalo ODBC Driver manualisht ne rast se DB s'lidhet.
    )
)
echo.

REM ====== 4. Clone repo ======
echo ------------------------------------------------------
echo [4/8] Klonim i kodit nga GitHub
echo ------------------------------------------------------
echo [%date% %time%] HAPI 4 - git clone >> "%LOG%"
REM Aktivizo Git Credential Manager qe PAT-i te ruhet
git config --global credential.helper manager >nul 2>&1

REM Verifiko gjendjen e %INSTALL_DIR%
set "REPO_STATE=NEW"
if exist "%INSTALL_DIR%\.git" set "REPO_STATE=HAS_GIT"
if not exist "%INSTALL_DIR%\.git" if exist "%INSTALL_DIR%" set "REPO_STATE=DIR_NO_GIT"

if "!REPO_STATE!"=="HAS_GIT" (
    REM Verifiko qe .git eshte valid
    pushd "%INSTALL_DIR%"
    git rev-parse --git-dir >nul 2>&1
    if errorlevel 1 (
        popd
        echo [!] .git eshte i korruptuar ^(mbetur nga instalim i nderprerje^).
        echo [%date% %time%] Corrupted .git detected >> "%LOG%"
        set "REPO_STATE=CORRUPTED"
    ) else (
        echo Repo ekziston dhe eshte valid. Po pergatit update...
        REM Ruaj db.js perpara reset-it
        if exist "server\db.js" copy /Y "server\db.js" "%TEMP%\kubit-db-preserve.js" >nul

        REM 1. Ndalo sherbimin KubitAPI nese po punon (mund te mbaje file locks)
        sc query KubitAPI >nul 2>&1
        if not errorlevel 1 (
            echo     Ndalim i KubitAPI service perkohesisht...
            net stop KubitAPI >nul 2>&1
            timeout /t 2 /nobreak >nul
        )

        REM 2. Merr pronesine + leje te plota per te gjithe folderin
        echo     Konfigurimi i lejeve...
        takeown /F "%INSTALL_DIR%" /R /A >nul 2>&1
        icacls "%INSTALL_DIR%" /grant Administrators:F /T /C /Q >nul 2>&1

        REM 3. Hiq ReadOnly nga cdo skedar
        attrib -R "%INSTALL_DIR%\*.*" /S /D >nul 2>&1

        REM 4. Fshij .bat-et tracked (do rikrijohen nga git reset)
        for %%F in (install.bat install-fresh.bat update.bat setup.bat setup-offline.bat) do (
            if exist "%%F" del /F /Q "%%F" >nul 2>&1
        )

        REM 5. Git fetch
        git fetch origin >> "%LOG%" 2>&1
        if errorlevel 1 (
            echo [X] git fetch deshtoi. Kontrollo %LOG%
            popd & goto :fail
        )

        REM 6. Git reset me retry (Windows Defender mund bllokoje transientisht)
        set "RESET_OK=0"
        for /L %%i in (1,1,3) do (
            if "!RESET_OK!"=="0" (
                git reset --hard origin/main >> "%LOG%" 2>&1
                if not errorlevel 1 set "RESET_OK=1"
                if "!RESET_OK!"=="0" (
                    echo     [!] Provoj %%i dehstoi. Prisni 3 sekonda dhe rrepeto...
                    timeout /t 3 /nobreak >nul
                    git clean -fdx >> "%LOG%" 2>&1
                )
            )
        )

        if "!RESET_OK!"=="0" (
            echo [X] git reset deshtoi 3 here. Po provoj rebuild ne temp dhe kopjim...
            echo [%date% %time%] Falling back to TMP clone + xcopy >> "%LOG%"
            popd
            set "TMP_CLONE=%TEMP%\kubit-tmp-clone-update"
            if exist "!TMP_CLONE!" rmdir /S /Q "!TMP_CLONE!"
            git clone "%REPO_URL%" "!TMP_CLONE!" >> "%LOG%" 2>&1
            if errorlevel 1 (
                echo [X] Clone ne temp deshtoi. Kontrollo %LOG%
                goto :fail
            )
            REM Zhvendos .git e re, pastaj kopjo skedaret
            rmdir /S /Q "%INSTALL_DIR%\.git" 2>nul
            move /Y "!TMP_CLONE!\.git" "%INSTALL_DIR%\.git" >nul
            xcopy /E /Y /Q /H /I /R "!TMP_CLONE!\*" "%INSTALL_DIR%\" >nul
            rmdir /S /Q "!TMP_CLONE!" 2>nul
            pushd "%INSTALL_DIR%"
        )

        if exist "%TEMP%\kubit-db-preserve.js" copy /Y "%TEMP%\kubit-db-preserve.js" "server\db.js" >nul
        popd
    )
)

if "!REPO_STATE!"=="CORRUPTED" (
    echo     Po e riparoj folderin - ruaj db.js nese ekziston dhe klonoj perseri.
    if exist "%INSTALL_DIR%\server\db.js" copy /Y "%INSTALL_DIR%\server\db.js" "%TEMP%\kubit-db-preserve.js" >nul
    REM Hiq .git-in e korruptuar + node_modules (do re-instalohen)
    rmdir /S /Q "%INSTALL_DIR%\.git" 2>nul
    REM Nese folderi ka edhe skedare te tjere, klonoj ne dir te perkohshem dhe me vone e merge
    set "TMP_CLONE=%TEMP%\kubit-tmp-clone"
    if exist "!TMP_CLONE!" rmdir /S /Q "!TMP_CLONE!"
    echo.
    echo [!] Do kerkohet login GitHub ne dritaren e re.
    echo.
    pause
    git clone "%REPO_URL%" "!TMP_CLONE!" >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo [X] git clone deshtoi. Shiko %LOG%
        goto :fail
    )
    REM Zhvendos .git nga temp te install dir
    move /Y "!TMP_CLONE!\.git" "%INSTALL_DIR%\.git" >nul
    REM Kopjoj skedaret e munguar (git pull do ti sjelli te tjere)
    xcopy /E /Y /Q /H /I "!TMP_CLONE!\*" "%INSTALL_DIR%\" >nul
    rmdir /S /Q "!TMP_CLONE!" 2>nul
    if exist "%TEMP%\kubit-db-preserve.js" copy /Y "%TEMP%\kubit-db-preserve.js" "%INSTALL_DIR%\server\db.js" >nul
    echo     Repo u riparuar ne %INSTALL_DIR%
    set "REPO_STATE=HAS_GIT"
)

if "!REPO_STATE!"=="DIR_NO_GIT" (
    REM Folderi ekziston por pa .git - ndreq automatikisht
    dir /b "%INSTALL_DIR%" 2>nul | findstr /R /V "^$" >nul
    if errorlevel 1 (
        REM Folder bosh - thjesht klonoj
        rmdir "%INSTALL_DIR%" 2>nul
        set "REPO_STATE=NEW"
    ) else (
        echo [!] Folderi %INSTALL_DIR% ka skedare por pa .git. Po ndreq automatikisht...
        echo [%date% %time%] DIR_NO_GIT auto-recovery >> "%LOG%"
        REM Ruaj db.js
        if exist "%INSTALL_DIR%\server\db.js" (
            copy /Y "%INSTALL_DIR%\server\db.js" "%TEMP%\kubit-db-preserve.js" >nul
            echo     server\db.js u ruajt
        )
        REM Klonim ne TEMP
        echo.
        echo [!] Repo eshte PRIVAT - do kerkohet login GitHub.
        echo.
        pause
        set "TMP_CLONE_REPAIR=%TEMP%\kubit-repair-clone"
        if exist "!TMP_CLONE_REPAIR!" rmdir /S /Q "!TMP_CLONE_REPAIR!"
        git clone "%REPO_URL%" "!TMP_CLONE_REPAIR!" >> "%LOG%" 2>&1
        if errorlevel 1 (
            echo [X] git clone deshtoi. Shiko %LOG%
            goto :fail
        )
        REM Zhvendos .git e re te install dir
        move /Y "!TMP_CLONE_REPAIR!\.git" "%INSTALL_DIR%\.git" >nul
        REM xcopy gjithshka, mbishkruan skedaret ekzistues
        xcopy /E /Y /Q /H /I /R "!TMP_CLONE_REPAIR!\*" "%INSTALL_DIR%\" >nul 2>&1
        rmdir /S /Q "!TMP_CLONE_REPAIR!" 2>nul
        REM Restoro db.js
        if exist "%TEMP%\kubit-db-preserve.js" copy /Y "%TEMP%\kubit-db-preserve.js" "%INSTALL_DIR%\server\db.js" >nul
        echo     Folder-i u riparua me sukses.
        set "REPO_STATE=HAS_GIT"
    )
)

if "!REPO_STATE!"=="NEW" (
    echo.
    echo [!] Repo eshte PRIVAT. Do te dale dritarja e autentifikimit GitHub.
    echo     Kliko "Sign in with your browser" OSE "Token" dhe jep PAT-in.
    echo     Credentials ruhen ne Windows Credential Manager per update-e te ardhshme.
    echo.
    pause
    git clone "%REPO_URL%" "%INSTALL_DIR%" >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo [X] git clone deshtoi. Shiko %LOG%
        goto :fail
    )
)

cd /d "%INSTALL_DIR%"
echo     Kodi u shkarkua ne %INSTALL_DIR%
echo.

REM ====== 5. npm install - te gjitha varsite PARAPRAKISHT ======
echo ------------------------------------------------------
echo [5/8] Shkarkim i te gjitha varsive npm (paraprakisht)
echo ------------------------------------------------------
echo [%date% %time%] HAPI 5 - npm install >> "%LOG%"
echo Kjo mund te zgjase 2-5 minuta ne shkarkimin e pare.
echo Output i plote regjistrohet ne: %LOG%
echo.
echo     Frontend npm install...
if exist "package-lock.json" (
    call npm ci --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
) else (
    call npm install --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
)
if errorlevel 1 (
    echo     [!] npm ci deshtoi, po provoj npm install...
    call npm install --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
    if errorlevel 1 (echo [X] Varesite frontend deshtuan. Shiko %LOG% & goto :fail)
)
echo     Frontend OK (varesite e shkarkuara ne node_modules)

echo     Server npm install...
pushd server
if exist "package-lock.json" (
    call npm ci --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
) else (
    call npm install --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
)
if errorlevel 1 (
    call npm install --no-audit --no-fund --loglevel=error >> "%LOG%" 2>&1
    if errorlevel 1 (echo [X] Varesite server deshtuan. Shiko %LOG% & popd & goto :fail)
)
popd
echo     Server OK (varesite e shkarkuara ne server\node_modules)
echo     ^(perfshire bcrypt, mssql, msnodesqlv8, node-windows, etj.^)
echo.

REM ====== 6. Konfigurim DB interaktiv ======
echo ------------------------------------------------------
echo [6/8] Konfigurim i SQL Server (interaktiv)
echo ------------------------------------------------------
echo [%date% %time%] HAPI 6 - setup.cjs >> "%LOG%"

REM Nese db.js eshte shablloni i paracaktuar nga git (Server=.), fshije qe setup.cjs
REM te pyese user-in. Nese eshte db.js i ruajtur nga install i meparshem valid, ruaje.
set "DB_VALID=0"
if exist "server\db.js" (
    findstr /C:"Server=." /C:"Trusted_Connection=yes" "server\db.js" >nul 2>&1
    if errorlevel 1 (
        REM s'eshte shablloni default - besojme qe eshte i konfiguruar
        set "DB_VALID=1"
    ) else (
        REM eshte shablloni - fshije qe setup.cjs te pyese
        del "server\db.js" >nul 2>&1
        echo [%date% %time%] db.js ishte shablloni default - u fshi >> "%LOG%"
    )
)

if "!DB_VALID!"=="1" (
    echo     server\db.js ekziston i konfiguruar. Po kapercej.
    echo [%date% %time%] db.js preserved >> "%LOG%"
    echo     Duke ndertuar frontend...
    call npm run build >> "%LOG%" 2>&1
    set "BUILD_EXIT=!errorlevel!"
    echo [%date% %time%] build exit=!BUILD_EXIT! >> "%LOG%"
    if not "!BUILD_EXIT!"=="0" (
        echo [X] Build deshtoi. Shiko %LOG%
        goto :fail
    )
    echo     Build OK.
) else (
    echo Nis setup-in interaktiv ^(merr detajet per SQL Server^)...
    echo.
    echo Format per "Server name":
    echo   - Default instance:  localhost  ose  .
    echo   - Named instance:    localhost\SQLEXPRESS
    echo   - PC tjeter:         SERVERNAME  ose  192.168.x.x
    echo   - Me port custom:    localhost,1433
    echo.
    echo [%date% %time%] starting setup.cjs interactive >> "%LOG%"
    call node setup.cjs
    set "CJS_EXIT=!errorlevel!"
    echo [%date% %time%] setup.cjs exit=!CJS_EXIT! >> "%LOG%"
    if not "!CJS_EXIT!"=="0" (
        echo.
        echo [X] Konfigurimi i DB deshtoi ^(exit !CJS_EXIT!^).
        echo     Ri-ekzekuto install-fresh.bat me te dhenat e sakta.
        goto :fail
    )
)
echo.

REM ====== 7. Windows Service ======
echo ------------------------------------------------------
echo [7/8] Instalim i Windows Service KubitAPI
echo ------------------------------------------------------
echo [%date% %time%] HAPI 7 - Service >> "%LOG%"
sc query KubitAPI >nul 2>&1
if not errorlevel 1 (
    echo     Sherbimi ekziston - po e ristartoj...
    net stop KubitAPI >nul 2>&1
    timeout /t 2 /nobreak >nul
    net start KubitAPI
) else (
    call node scripts\install-service.cjs >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo [X] Instalimi i sherbimit deshtoi. Shiko %LOG%
        goto :fail
    )
)
echo.

REM ====== 8. Firewall + port detektim ======
echo ------------------------------------------------------
echo [8/8] Konfigurim firewall
echo ------------------------------------------------------
echo [%date% %time%] HAPI 8 - Firewall >> "%LOG%"
set "API_PORT=3002"
for /f "tokens=5 delims= " %%P in ('findstr /R "^const PORT" server\index.js') do (
    set "TMP=%%P"
    set "TMP=!TMP:;=!"
    if not "!TMP!"=="" set "API_PORT=!TMP!"
)
netsh advfirewall firewall show rule name="Kubit API" >nul 2>&1
if not errorlevel 1 netsh advfirewall firewall delete rule name="Kubit API" >nul 2>&1
netsh advfirewall firewall add rule name="Kubit API" dir=in action=allow protocol=TCP localport=!API_PORT! >nul
echo     Port !API_PORT! i hapur ne firewall.
echo.

echo ======================================================
echo    INSTALIMI PERFUNDOI ME SUKSES
echo ======================================================
echo [%date% %time%] SUCCESS >> "%LOG%"
echo.
sc query KubitAPI 2>nul | findstr /C:"STATE" 2>nul
echo.
echo URL:     http://localhost:!API_PORT!
echo Folder:  %INSTALL_DIR%
echo Log:     %LOG%
echo.
echo Login i paracaktuar:
echo   username: admin
echo   password: admin
echo.
echo [!] Ndrysho passwordin e admin-it ne hyrjen e pare.
echo.
echo Per update-e te ardhshme, ekzekuto:  update.bat
goto :end

:fail
echo.
echo ======================================================
echo    [X] INSTALIMI DESHTOI
echo ======================================================
echo.
echo Kontrollo log file per detaje:
echo   %LOG%

:end
echo.
echo Shtyp ENTER per te mbyllur...
pause >nul
endlocal
