@echo off
chcp 65001 > nul
title NoBan service v8.1
set "LOCAL_VERSION=8.1"
setlocal EnableDelayedExpansion

:: ═════╣ Настройка ANSI цветов ╠═════
for /f %%a in ('echo prompt $E ^| cmd /q /k') do set "ESC=%%a"
set "C_PURP=%ESC%[38;2;217;184;240m"
set "C_BLUE=%ESC%[38;2;184;191;242m"
set "C_GREY=%ESC%[38;2;212;227;234m"
set "C_RED=%ESC%[38;2;255;106;106m"
set "C_GREEN=%ESC%[38;2;168;255;106m"
set "C_YELLOW=%ESC%[38;2;255;233;106m"
set "CL0=%ESC%[0m"

:: ═════╣ Проверка аргументов для NoBan.bat ╠═════
if "%~1"=="status_noban" ( call :test_service NoBan soft & call :tcp_enable & exit /b )
if "%~1"=="check_updates" (
    call :update_check_status
    if "!UpdateCheckStatus!"=="Включена" (
        if not "%~2"=="soft" ( start /b service check_updates soft ) else ( call :service_check_updates soft )
    )
    exit /b
)
if "%~1"=="load_game_filter" ( call :game_switch_status & exit /b )

:: ═════╣ Запрос на права администратора ╠═════
if "%1"=="admin" ( echo Старт с правами администратора ) else (
    echo Запрос на права администратора...
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit /b
)

:menu
cls
call :ipset_switch_status
call :game_switch_status
call :update_check_status

set "menu_choice=null"
echo %C_BLUE%────────────────── %C_PURP%NoBan v!LOCAL_VERSION! %C_BLUE%──────────────────►%CL0%
echo.
echo   %C_RED%[0] %C_GREY%Назад%CL0%
echo   %C_BLUE%[1] %C_GREY%Проверить статус%CL0%
echo   %C_BLUE%[2] %C_GREY%Выполнить диагностику%CL0%
echo   %C_BLUE%[3] %C_GREY%Проверка обновлений %C_YELLOW%[!UpdateCheckStatus!]%CL0%
echo   %C_BLUE%[4] %C_GREY%Переключить игровой фильтр %C_YELLOW%[!GameFilterStatus!]%CL0%
echo   %C_BLUE%[5] %C_GREY%Переключить ipset %C_YELLOW%[!IPsetStatus!]%CL0%
echo   %C_BLUE%[6] %C_GREY%Установить автозагрузку%CL0%
echo   %C_BLUE%[7] %C_GREY%Убрать автозагрузку / Остановить NoBan%CL0%
echo   %C_BLUE%[8] %C_GREY%Профессиональная разблокировка (Hosts)%CL0%
echo   %C_BLUE%[9] %C_GREY%Сбросить lists (Скачать оригиналы)%CL0%
echo   %C_BLUE%[10] %C_GREY%Добавление доменов%CL0%
echo.
echo %C_BLUE%────────────────── %C_PURP%NoBan v!LOCAL_VERSION! %C_BLUE%──────────────────►%CL0%
echo.
set /p menu_choice=%C_GREY%Введите выбор [0-10]:%C_PURP%

if "%menu_choice%"=="1" goto service_status
if "%menu_choice%"=="2" goto service_diagnostics
if "%menu_choice%"=="3" goto toggle_update_check
if "%menu_choice%"=="4" goto game_switch
if "%menu_choice%"=="5" goto ipset_switch
if "%menu_choice%"=="6" goto service_install
if "%menu_choice%"=="7" goto service_remove
if "%menu_choice%"=="8" goto auto_hosts_unlock
if "%menu_choice%"=="9" goto reset_lists_menu
if "%menu_choice%"=="10" goto add_domains_menu
if "%menu_choice%"=="0" exit /b
goto menu

:: ═════╣ 1. СТАТУС ╠═════
:service_status
cls
sc query "NoBan.exe" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\NoBan" /v NoBan 2^>nul') do echo %C_GREY%Service strategy installed from "%%B"%CL0%
)
call :test_service NoBan
call :test_service WinDivert
echo:
tasklist /FI "IMAGENAME eq NoBan.exe" | find /I "NoBan.exe" > nul
if !errorlevel!==0 (
    echo %C_GREEN%│ %C_GREY%NoBan активен%CL0%
	echo.
) else (
    echo %C_RED%│ %C_GREY%NoBan не активен%CL0%
	echo.
)
pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="
for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"
if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo %C_YELLOW%│ %C_GREY%"%ServiceName%" уже запущен как служба.%CL0%
    ) else (
        echo %C_GREEN%│ %C_GREY%"%ServiceName%" запущен.%CL0%
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! останавливается..."
) else if not "%~2"=="soft" (
    echo !C_RED!"%ServiceName%" не запущен.!CL0!
)
exit /b

:: ═════╣ 2. ДИАГНОСТИКА ╠═════
:service_diagnostics
cls
sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 ( call :PrintGreen "[+] BFE работает" ) else ( call :PrintRed "[-] BFE не запущен!" )

netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1

tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if !errorlevel!==0 ( call :PrintRed "[-] Adguard может ломать Discord!" ) else ( call :PrintGreen "[+] Adguard не найден" )

sc query | findstr /I "Killer" > nul
if !errorlevel!==0 ( call :PrintRed "[-] Найдены службы Killer!" ) else ( call :PrintGreen "[+] Killer не найден" )

sc query WinDidvert | findstr /I "RUNNING STOP_PENDING" > nul
if !errorlevel!==0 (
    tasklist /FI "IMAGENAME eq NoBan.exe" | find /I "NoBan.exe" > nul
    if !errorlevel!==1 (
        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
    )
)

echo.
set "CHOICE="
set /p "CHOICE=Очистить кэш Discord? (Y/N): "
if /i "!CHOICE!"=="Y" (
    taskkill /IM Discord.exe /F > nul 2>&1
    set "discordCacheDir=%appdata%\discord"
    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        if exist "!discordCacheDir!\%%~d" (
            rd /s /q "!discordCacheDir!\%%~d"
            if !errorlevel!==0 ( call :PrintGreen "[+] Удалено !discordCacheDir!\%%~d" ) else ( call :PrintRed "[-] Не удалось удалить !discordCacheDir!\%%~d" )
        )
    )
)
pause
goto menu

:: ═════╣ 3. ПРОВЕРКА ОБНОВЛЕНИЙ ╠═════
:update_check_status
chcp 65001 > nul
set "updateFlagFile=%~dp0bin\update_check.disabled"
if exist "%updateFlagFile%" (
    set "UpdateCheckStatus=Выключена"
) else (
    set "UpdateCheckStatus=Включена"
)
exit /b

:toggle_update_check
cls
if exist "%updateFlagFile%" (
    del /f /q "%updateFlagFile%"
    echo.
    echo %C_GREEN%│ %C_GREY%Проверка обновлений%CL0% %C_GREEN%включена%CL0%
    echo.
    pause
    goto service_check_updates
) else (
    echo DISABLED > "%updateFlagFile%"
    echo.
    echo %C_RED%│ %C_GREY%Проверка обновлений %C_RED%выключена%CL0%
    echo.
    pause
    goto menu
)

:service_check_updates
cls
echo.
echo %C_PURP%│ %C_GREY%Проверка обновлений...%CL0%
echo.
set "GITHUB_VERSION="
"%~dp0bin\curl.exe" -s -L -m 5 -o "%temp%\noban_ver.txt" "https://raw.githubusercontent.com/voanechay42/NoBan/main/service/version.txt"

if exist "%temp%\noban_ver.txt" (
    set /p GITHUB_VERSION=<"%temp%\noban_ver.txt"
    del "%temp%\noban_ver.txt"
    set "GITHUB_VERSION=!GITHUB_VERSION: =!"
    set "GITHUB_VERSION=!GITHUB_VERSION:v=!"
)

if not defined GITHUB_VERSION (
    cls
    echo.
    echo %C_RED%│ %C_GREY%Не удалось проверить обновления.%CL0%
    echo %C_RED%│ %C_GREY%Нет подключения к интернету или GitHub недоступен.%CL0%
	echo.
    if "%1"=="soft" exit /b
    pause
    goto menu
)

cls
echo.
echo %C_PURP%│ %C_GREY%Ваша версия: %C_BLUE%v%LOCAL_VERSION% %CL0%
echo %C_PURP%│ %C_GREY%Последняя версия: %C_BLUE%v!GITHUB_VERSION! %CL0%

if "%LOCAL_VERSION%"=="!GITHUB_VERSION!" (
    echo.
    echo %C_GREEN%│ %C_GREY%У вас установлена последняя версия.%CL0%
) else (
    echo.
    echo %C_PURP%│ %C_GREY%Открываю страницу для скачивания...%CL0%
    start "" "https://github.com/voanechay42/NoBan/releases/latest"
)
echo.
if "%1"=="soft" exit /b
pause
goto menu

:: ═════╣ 4. ИГРОВОЙ ФИЛЬТР ╠═════
:game_switch_status
set "gameFlagFile=%~dp0bin\game_filter.enabled"
if exist "%gameFlagFile%" (
    set "GameFilterStatus=enabled"
    set "GameFilterTCP=1024-65535"
    set "GameFilterUDP=1024-65535"
    set "GameFilter=1024-65535"
) else (
    set "GameFilterStatus=disabled"
    set "GameFilterTCP=12"
    set "GameFilterUDP=12"
    set "GameFilter=12"
)
exit /b

:game_switch
cls
if not exist "%gameFlagFile%" (
    echo ENABLED > "%gameFlagFile%"
	echo.
    echo %C_GREEN%│ %C_GREY%Игровой фильтр %C_GREEN%включён%CL0%
) else (
    del /f /q "%gameFlagFile%"
	echo.
    echo %C_RED%│ %C_GREY%Игровой фильтр %C_RED%выключен%CL0%
)
echo.
echo %C_YELLOW%│ %C_GREY%Перезапустите NoBan, чтобы изменения вступили в силу.%CL0%
echo.
pause
goto menu

:: ═════╣ 5. ПЕРЕКЛЮЧЕНИЕ IPSET ╠═════
:ipset_switch_status
set "listFile=%~dp0lists\ipset-all.txt"
if not exist "%listFile%" (
    set "IPsetStatus=any"
    exit /b
)
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"
if !lineCount!==0 (
    set "IPsetStatus=any"
) else (
    find "203.0.113.113/32" "%listFile%" >nul
    if !errorlevel!==0 ( set "IPsetStatus=none" ) else ( set "IPsetStatus=loaded" )
)
exit /b

:ipset_switch
cls
echo.
echo %C_YELLOW%│ %C_GREY%Останавка NoBan для освобождения файла...%CL0%
sc query NoBan >nul 2>&1
if !errorlevel!==0 ( net stop NoBan >nul 2>&1 )
taskkill /IM NoBan.exe /F >nul 2>&1
echo %C_YELLOW%│ %C_GREY%Ждем 3 секунды, чтобы Windows отпустила файл...%CL0%
echo.
timeout /t 3 /nobreak >nul

set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%~dp0lists\ipset-all.txt.backup"

if "%IPsetStatus%"=="loaded" goto ipset_to_none
if "%IPsetStatus%"=="none" goto ipset_to_any
if "%IPsetStatus%"=="any" goto ipset_to_loaded
goto menu

:ipset_to_none
echo Переключение в режим "none" (обход только по доменам)...
if exist "%backupFile%" del /f /q "%backupFile%"
if exist "%listFile%" (
    ren "%listFile%" "ipset-all.txt.backup"
    if exist "%listFile%" (
        call :PrintRed "[ОШИБКА] Не удалось переименовать файл! Он всё ещё занят."
        pause
        goto menu
    )
)
echo 203.0.113.113/32>"%listFile%"
goto ipset_done

:ipset_to_any
echo Переключение в режим "any" (обход всех IP)...
if exist "%listFile%" (
    del /f /q "%listFile%"
    if exist "%listFile%" (
        call :PrintRed "[ОШИБКА] Не удалось удалить файл! Он всё ещё занят."
        pause
        goto menu
    )
)
break > "%listFile%"
goto ipset_done

:ipset_to_loaded
echo Переключение в режим "loaded" (обход по списку IP)...
if not exist "%backupFile%" (
    call :PrintRed "[ОШИБКА] Резервная копия (.backup) не найдена!"
    pause
    goto menu
)
if exist "%listFile%" (
    del /f /q "%listFile%"
    if exist "%listFile%" (
        call :PrintRed "[ОШИБКА] Не удалось удалить файл! Он всё ещё занят."
        pause
        goto menu
    )
)
ren "%backupFile%" "ipset-all.txt"
if not exist "%listFile%" (
    call :PrintRed "[ОШИБКА] Не удалось восстановить файл из копии."
    pause
    goto menu
)
goto ipset_done

:ipset_done
echo.
call :PrintGreen "[УСПЕХ] Настройки ipset изменены."
echo [i] Не забудьте заново запустить профиль в NoBan.bat
pause
goto menu

:: ═════╣ 6. УСТАНОВКА АВТОЗАГРУЗКИ ╠═════
:service_install
cls
cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"
set "AUTOLOAD_PATH=%~dp0autoload\"

if not exist "!AUTOLOAD_PATH!" (
    echo.
    echo %C_RED%│ %C_GREY%Папка "autoload" не найдена!%CL0%
    echo.
    pause
    goto menu
)

echo %C_BLUE%─────────── %C_PURP%Выберите профиль %C_BLUE%──────────►%CL0%
echo.
set "count=0"
for %%f in ("!AUTOLOAD_PATH!*.bat") do (
    set "filename=%%~nxf"
    if /i not "!filename:~0,7!"=="service" (
        set /a count+=1
        echo !count!. %%~nf
        set "file!count!=%%f"
        set "name!count!=%%~nxf"
    )
)

if !count!==0 (
    echo.
    echo %C_RED%│ В папке "autoload" не найдено ни одного .bat-файла!%CL0%
    echo.
    pause
    goto menu
)

set "choice="
echo.
set /p "choice=Введите выбор [1-!count!]:"
if "!choice!"=="" goto :eof

set "selectedFile=!file%choice%!"
set "selectedFileName=!name%choice%!"
if not defined selectedFile (
    echo Неверный выбор!
    pause
    goto menu
)

:: ПУЛЕНЕПРОБИВАЕМЫЙ ПАРСЕР
set "args="
set "capture=0"
set "continued=0"
for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    set "test=!line:--wf-tcp=!"

    if !capture!==0 (
        if not "!test!"=="!line!" (
            set "capture=1"
            set "line=!line:*--wf-tcp=--wf-tcp!"
            if "!line:~-1!"=="^" (
                set "continued=1"
                set "line=!line:~0,-1!"
            )
            set "args=!line!"
        )
    ) else if !continued!==1 (
        set "continued=0"
        if "!line:~-1!"=="^" (
            set "continued=1"
            set "line=!line:~0,-1!"
        )
        set "args=!args! !line!"
    )
)

:: Подстановка путей
set "args=!args:%%BIN%%=%BIN_PATH%!"
set "args=!args:%%LISTS%%=%LISTS_PATH%!"
set "args=!args:%%GameFilter%%=%GameFilter%!"

:: КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Экранируем кавычки для команды sc create
set "args=!args:"=\"!"

if defined args if "!args:~0,1!"==" " set "args=!args:~1!"

call :tcp_enable
set "ARGS=!args!"
echo Final args: !ARGS!
set SRVCNAME=NoBan

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%NoBan.exe\" !ARGS!" DisplayName= "NoBan" start= auto
sc description %SRVCNAME% "Программное обеспечение для обхода DPI NoBan"
sc start %SRVCNAME%
reg add "HKLM\System\CurrentControlSet\Services\NoBan" /v NoBan /t REG_SZ /d "!selectedFileName!" /f

echo.
echo %C_GREEN%│ %C_GREY%NoBan успешно добавлен в Автозагрузку!%CL0%
echo.
pause
goto menu

:: ═════╣ 7. УДАЛЕНИЕ АВТОЗАГРУЗКИ ╠═════
:service_remove
cls
echo %C_YELLOW%│ %C_GREY%Останавливаю и удаляю службу NoBan...%CL0%
net stop NoBan >nul 2>&1
sc delete NoBan >nul 2>&1
taskkill /IM NoBan.exe /F >nul 2>&1
call :PrintGreen "│ Служба NoBan удалена, процесс остановлен."
pause
goto menu

:: ═════╣ 8. HOSTS РАЗБЛОКИРОВКА ╠═════
:auto_hosts_unlock
cls
echo %C_BLUE%───────── %C_PURP%Выберите сервис %C_BLUE%────────►%CL0%
echo.
echo   %C_RED%[0] %C_GREY%Назад%CL0%
echo   %C_BLUE%[1] %C_GREY%Spotify%CL0%
echo   %C_BLUE%[2] %C_GREY%Telegram Web%CL0%
echo   %C_BLUE%[3] %C_GREY%IntelliJ IDEA%CL0%
echo   %C_BLUE%[4] %C_GREY%Roblox (иконки)%CL0%
echo.
echo %C_BLUE%──────────────────────────────────►%CL0%
echo.
set /p "host_choice=Введите выбор [0-4]:%C_PURP%"
if "%host_choice%"=="1" set "HOST_FILE=hosts-spotify.txt"
if "%host_choice%"=="2" set "HOST_FILE=hosts-telegram.txt"
if "%host_choice%"=="3" set "HOST_FILE=hosts-intellij.txt"
if "%host_choice%"=="4" set "HOST_FILE=hosts-roblox.txt"
if "%host_choice%"=="0" goto menu

set "SOURCE=%~dp0lists\%HOST_FILE%"
set "DEST=%SystemRoot%\System32\drivers\etc\hosts"

if not exist "%SOURCE%" ( call :PrintRed "[ОШИБКА] Файл %SOURCE% не найден!" & pause & goto menu )

echo. >> "%DEST%"
echo # === NoBan Auto-Added %HOST_FILE% === >> "%DEST%"
findstr /v "^#" "%SOURCE%" >> "%DEST%"
ipconfig /flushdns >nul
call :PrintGreen "[УСПЕХ] Записи из %HOST_FILE% добавлены в hosts, DNS-кэш сброшен!"
pause
goto menu

:: ═════╣ 9. СБРОС LISTS ╠═════
:reset_lists_menu
cls
echo %C_BLUE%───────── %C_PURP%Сброс списков %C_BLUE%──────────►%CL0%
echo.
echo   %C_PURP%│ %C_GREY%Выбранные файлы будут заменены%CL0%
echo   %C_PURP%│ %C_GREY%на оригинальные версии с GitHub%CL0%
echo.
echo   %C_RED%[0] %C_GREY%Назад%CL0%
echo   %C_BLUE%[1] %C_GREY%white-list.txt%CL0%
echo   %C_BLUE%[2] %C_GREY%black-list.txt%CL0%
echo   %C_BLUE%[3] %C_GREY%ipset-all.txt%CL0%
echo   %C_BLUE%[4] %C_GREY%ipset-exclude.txt%CL0%
echo   %C_BLUE%[5] %C_GREY%Сбросить все файлы%CL0%
echo.
echo %C_BLUE%──────────────────────────────────►%CL0%
echo.
set /p "reset_choice=Введите выбор [0-5]:%C_PURP%"

if "%reset_choice%"=="0" goto menu
if "%reset_choice%"=="1" ( call :download_file "white-list.txt" & pause & goto menu )
if "%reset_choice%"=="2" ( call :download_file "black-list.txt" & pause & goto menu )
if "%reset_choice%"=="3" ( call :download_file "ipset-all.txt" & pause & goto menu )
if "%reset_choice%"=="4" ( call :download_file "ipset-exclude.txt" & pause & goto menu )
if "%reset_choice%"=="5" (
    call :download_file "white-list.txt"
    call :download_file "black-list.txt"
    call :download_file "ipset-all.txt"
    call :download_file "ipset-exclude.txt"
    pause
    goto menu
)
goto reset_lists_menu

:download_file
set "filename=%~1"
set "url=https://raw.githubusercontent.com/voanechay42/NoBan/main/service/%filename%"
set "target=%~dp0lists\%filename%.tmp"

echo [i] Скачивание %filename%...

pushd "%~dp0bin"
for /f %%A in ('curl.exe -s -L -m 15 -w "%%{http_code}" -o "%target%" "%url%"') do set "HTTP_CODE=%%A"
popd

if "!HTTP_CODE!"=="200" (
    move /y "%target%" "%~dp0lists\%filename%" >nul 2>&1
    if !errorlevel!==0 (
        call :PrintGreen "[+] %filename% успешно обновлен."
    ) else (
        call :PrintRed "[-] Ошибка: не удалось заменить %filename% (возможно, он занят NoBan.exe)."
        del /f /q "%target%"
    )
) else (
    call :PrintRed "[-] Ошибка скачивания! Код ответа: !HTTP_CODE! (Файл не найден на GitHub или нет сети)."
    del /f /q "%target%"
)
exit /b


:: ═════╣ 10. ДОБАВЛЕНИЕ ДОМЕНОВ ╠═════
:add_domains_menu
cls
echo %C_BLUE%───────── %C_PURP%Добавление доменов %C_BLUE%──────────►%CL0%
echo.
echo   %C_BLUE%│ %C_GREY%white-list - Домены, для которых %C_GREEN%применяются %C_GREY%правила обхода.
echo   %C_BLUE%│ %C_GREY%black-list - Домены, для которых %C_RED%не применяются %C_GREY%правила обхода.
echo.
echo   %C_RED%[0] %C_GREY%Назад%CL0%
echo   %C_BLUE%[1] %C_GREY%Добавить домены в %C_PURP%white-list%CL0%
echo   %C_BLUE%[2] %C_GREY%Добавить домены в %C_PURP%black-list%CL0%
echo.
echo %C_BLUE%───────────────────────────────────────►%CL0%
set "DOMAIN_TARGET="
set "domain_target_choice="
set /p "domain_target_choice=Введите выбор [0-2]:%C_PURP%"

if "!domain_target_choice!"=="0" goto menu
if "!domain_target_choice!"=="1" set "DOMAIN_TARGET=white-list.txt"
if "!domain_target_choice!"=="2" set "DOMAIN_TARGET=black-list.txt"
if not defined DOMAIN_TARGET goto add_domains_menu
goto add_domains_platform_menu

:add_domains_platform_menu
cls
echo %C_BLUE%────────── %C_PURP%Выберите площадку %C_BLUE%──────────►%CL0%
echo.
echo   %C_RED%[0] %C_GREY%Назад%CL0%
echo   %C_BLUE%[1] %C_GREY%Steam%CL0%
echo   %C_BLUE%[2] %C_GREY%Twitch%CL0%
echo   %C_BLUE%[3] %C_GREY%GitHub%CL0%
echo   %C_BLUE%[4] %C_GREY%Roblox%CL0%
echo   %C_BLUE%[5] %C_GREY%Rockstar Games%CL0%
echo   %C_BLUE%[6] %C_GREY%Google%CL0%
echo   %C_BLUE%[7] %C_GREY%Epic Games%CL0%
echo.
echo %C_BLUE%───────────────────────────────────────►%CL0%
echo.
set "domain_platform_choice="
set /p "domain_platform_choice=Введите выбор [0-7]:%C_PURP%"

if "!domain_platform_choice!"=="0" goto add_domains_menu
set "DOMAIN_FILE="
set "DOMAIN_NAME="
if "!domain_platform_choice!"=="1" ( set "DOMAIN_FILE=steam-domain.txt" & set "DOMAIN_NAME=Steam" )
if "!domain_platform_choice!"=="2" ( set "DOMAIN_FILE=twitch-domain.txt" & set "DOMAIN_NAME=Twitch" )
if "!domain_platform_choice!"=="3" ( set "DOMAIN_FILE=github-domain.txt" & set "DOMAIN_NAME=GitHub" )
if "!domain_platform_choice!"=="4" ( set "DOMAIN_FILE=roblox-domain.txt" & set "DOMAIN_NAME=Roblox" )
if "!domain_platform_choice!"=="5" ( set "DOMAIN_FILE=rockstar-domain.txt" & set "DOMAIN_NAME=Rockstar Games" )
if "!domain_platform_choice!"=="6" ( set "DOMAIN_FILE=google-domain.txt" & set "DOMAIN_NAME=Google" )
if "!domain_platform_choice!"=="7" ( set "DOMAIN_FILE=epicgames-domain.txt" & set "DOMAIN_NAME=Epic Games" )
if not defined DOMAIN_FILE goto add_domains_platform_menu
call :add_domain_file
echo.
pause
goto add_domains_platform_menu


:add_domain_file
set "DOMAIN_URL=https://raw.githubusercontent.com/voanechay42/NoBan/main/service/domains/%DOMAIN_FILE%"
set "DOMAIN_SOURCE=%~dp0lists\%DOMAIN_FILE%.tmp"
set "DOMAIN_DEST=%~dp0lists\%DOMAIN_TARGET%"
set "DOMAIN_OPPOSITE="
if /i "%DOMAIN_TARGET%"=="white-list.txt" set "DOMAIN_OPPOSITE=%~dp0lists\black-list.txt"
if /i "%DOMAIN_TARGET%"=="black-list.txt" set "DOMAIN_OPPOSITE=%~dp0lists\white-list.txt"
set "HTTP_CODE="
set "ADDED_COUNT=0"
set "CONFLICT_COUNT=0"

echo.
echo %C_PURP%│ %C_GREY%Скачивание списка %C_BLUE%%DOMAIN_NAME%...%CL0%
pushd "%~dp0bin"
for /f %%A in ('curl.exe -s -L -m 20 -w "%%{http_code}" -o "%DOMAIN_SOURCE%" "%DOMAIN_URL%"') do set "HTTP_CODE=%%A"
popd

if not "!HTTP_CODE!"=="200" (
    call :PrintRed "│ %C_GREY%Не удалось скачать список. HTTP: %C_RED%!HTTP_CODE!"
    del /f /q "%DOMAIN_SOURCE%" >nul 2>&1
    exit /b
)
if not exist "%DOMAIN_SOURCE%" (
    call :PrintRed "│ %C_GREY%Файл списка не был создан."
    exit /b
)
for %%F in ("%DOMAIN_SOURCE%") do if %%~zF==0 (
    call :PrintRed "│ %C_GREY%Скачанный список пустой. Локальные файлы не изменены."
    del /f /q "%DOMAIN_SOURCE%" >nul 2>&1
    exit /b
)
if not exist "%DOMAIN_DEST%" type nul > "%DOMAIN_DEST%"

echo %C_PURP%│ %C_GREY%Добавление в %C_BLUE%%DOMAIN_TARGET%...%CL0%
echo.
for /f "usebackq eol=# tokens=* delims=" %%D in ("%DOMAIN_SOURCE%") do (
    set "domain=%%D"
    if defined domain (
        findstr /i /x /c:"!domain!" "%DOMAIN_DEST%" >nul 2>&1
        if errorlevel 1 (
            >> "%DOMAIN_DEST%" echo(!domain!
            set /a ADDED_COUNT+=1
        )
        if defined DOMAIN_OPPOSITE (
            findstr /i /x /c:"!domain!" "%DOMAIN_OPPOSITE%" >nul 2>&1
            if not errorlevel 1 set /a CONFLICT_COUNT+=1
        )
    )
)
del /f /q "%DOMAIN_SOURCE%" >nul 2>&1

if !ADDED_COUNT! GTR 0 (
    call :PrintGreen "│ %C_GREY%Добавлено доменов: %C_BLUE%!ADDED_COUNT!"
) else (
    echo %C_YELLOW%│ %C_GREY%Все домены уже присутствуют в выбранном списке.%CL0%
    echo.
)
if !CONFLICT_COUNT! GTR 0 (
    echo %C_YELLOW%│ Внимание: !CONFLICT_COUNT! доменов также есть в противоположном списке.%CL0%
    echo %C_YELLOW%│ Проверьте пересечения вручную: black-list имеет приоритет исключения.%CL0%
)
call :PrintGreen "│ %C_GREY%Файл %C_BLUE%%DOMAIN_TARGET% %C_GREY%изменён."
exit /b

:: ═════╣ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ╠═════
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b

:PrintGreen
echo !C_GREEN!%~1!CL0!
exit /b

:PrintRed
echo !C_RED!%~1!CL0!
exit /b

:PrintYellow
echo !C_YELLOW!%~1!CL0!
exit /b