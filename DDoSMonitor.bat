@echo off
setlocal enabledelayedexpansion

rem Set the title of the command prompt to "taravasks"
title taravasks - DDoS Monitor

rem Set the text color to green on black (classic hacker style)
color 0a

rem Default values
set logFolder=logs
set logFile=%logFolder%\connectionlog.txt
set tempFile=%logFolder%\temp_connections.txt
set systemLogFile=%logFolder%\systemlog.txt
set timeWindow=5
set threshold=100

rem Check if settings file exists, if not create it with default values
if not exist settings.txt (
    echo logFolder=logs > settings.txt
    echo timeWindow=5 >> settings.txt
    echo threshold=100 >> settings.txt
)

rem Load settings from the settings.txt file
for /f "tokens=1,2 delims==" %%a in (settings.txt) do (
    set %%a=%%b
)

rem Create the log folder if it doesn't exist
if not exist %logFolder% (
    mkdir %logFolder%
)

rem Function to display the settings menu
:SettingsMenu
cls
echo *********************************************
echo *            taravasks - DDoS MONITOR      *
echo *********************************************
echo.
echo 1. Change Log Folder Location
echo 2. Change Check Frequency (Time Interval)
echo 3. Change DDoS Threshold
echo 4. Save and Return to Main Screen
echo 5. Exit
echo.
set /p option=Choose an option:

if "%option%"=="1" goto :ChangeLogFolder
if "%option%"=="2" goto :ChangeTimeWindow
if "%option%"=="3" goto :ChangeThreshold
if "%option%"=="4" goto :SaveSettings
if "%option%"=="5" exit

goto :SettingsMenu

:ChangeLogFolder
cls
echo [Settings] Current Log Folder Location: %logFolder%
echo.
set /p newLogFolder=Enter new log folder location (full path):
set logFolder=%newLogFolder%
set logFile=%logFolder%\connectionlog.txt
set tempFile=%logFolder%\temp_connections.txt
set systemLogFile=%logFolder%\systemlog.txt
goto :SettingsMenu

:ChangeTimeWindow
cls
echo [Settings] Current Check Frequency: %timeWindow% seconds
echo.
set /p newTimeWindow=Enter new check frequency (in seconds):
set timeWindow=%newTimeWindow%
goto :SettingsMenu

:ChangeThreshold
cls
echo [Settings] Current DDoS Threshold: %threshold% connections
echo.
set /p newThreshold=Enter new DDoS threshold (number of connections):
set threshold=%newThreshold%
goto :SettingsMenu

:SaveSettings
cls
rem Save settings to file
echo logFolder=%logFolder% > settings.txt
echo timeWindow=%timeWindow% >> settings.txt
echo threshold=%threshold% >> settings.txt
echo [Settings] Saved successfully!
timeout /t 2 > nul
goto :Start

rem Function to simulate a loading bar
:LoadingBar
set /a counter=0
set /a maxCount=30
for /L %%i in (1,1,%maxCount%) do (
    set /a counter+=1
    set /a progress=(counter*100)/maxCount
    set bar=
    for /L %%j in (1,1,!counter!) do set bar=!bar!#
    cls
    echo [!] Checking for DDoS attack...
    echo.
    echo Progress: !bar! !progress!%%
    timeout /t 1 > nul
)
goto :EOF

rem Loop to constantly check the network activity
:Start
cls
echo *********************************************
echo *            taravasks - DDoS MONITOR      *
echo *********************************************
echo.
echo [!] Monitoring network activity for potential DDoS attack...
echo [!] Checking every %timeWindow% seconds...
echo.

rem Get network connections and count occurrences of each IP address
rem We need to filter out just the IPs and ensure proper parsing
netstat -n | findstr /i "tcp" | findstr /v "127.0.0.1" | findstr /v "::1" > %tempFile%

rem Reset variables
set ipCount=0
set mostConnections=0
set mostConnectionsIP=

rem Initialize the IP count map (empty initially)
for /f "tokens=3" %%a in (%tempFile%) do (
    set ip=%%a
    rem Strip off the port part if it's included (e.g., 192.168.1.1:12345 -> 192.168.1.1)
    for /f "tokens=1 delims=:" %%b in ("!ip!") do set ip=%%b
    
    rem Count the number of connections from this IP
    set /a ipCount=0
    for /f "tokens=3" %%c in ('find /c "%%a" %tempFile%') do (
        set currentCount=%%c
        if !currentCount! gtr !mostConnections! (
            set mostConnections=!currentCount!
            set mostConnectionsIP=%%a
        )
    )
)

rem If the number of connections from an IP exceeds the threshold, alert the user
if %mostConnections% geq %threshold% (
    rem Flashing text effect
    echo [ALERT] Potential DDoS attack detected!
    echo.
    echo [ALERT] IP Address with most connections: !mostConnectionsIP!
    echo [ALERT] Total connections from that IP: !mostConnections!
    echo.
    echo [ALERT] Logging details...
    timeout /t 1 > nul
    
    rem Log the DDoS detection with the date, time, and connection details
    echo %date% %time% - DDoS detected from IP: !mostConnectionsIP! with !mostConnections! connections >> %logFile%
    
    rem Log this event in the system log
    echo %date% %time% - DDoS detection event logged. IP: !mostConnectionsIP!, Connections: !mostConnections! >> %systemLogFile%

    rem Create an effect for the "Would you like to block" prompt
    set /a delay=2
    for /L %%i in (1,1,3) do (
        set /a delay+=1
        echo.
        echo [WARNING] Would you like to block this IP? (Y/N)
        set /p blockChoice=
        if /i "%blockChoice%"=="Y" (
            rem Flashing text when blocking
            echo [BLOCKING] Blocking IP address: !mostConnectionsIP!
            netsh advfirewall firewall add rule name="Block DDoS IP" dir=in interface=all action=block remoteip=!mostConnectionsIP!
            echo [BLOCKED] IP address !mostConnectionsIP! has been blocked.
            
            rem Log the blocking action in system log
            echo %date% %time% - Blocked IP: !mostConnectionsIP! >> %systemLogFile%
            
            goto Start
        )
    )
) else (
    rem Show normal status in hacker-like format
    echo [STATUS] Network connections are normal. Total connections: %ipCount%
    
    rem Log the normal status event in system log
    echo %date% %time% - Normal network status. Total connections: %ipCount% >> %systemLogFile%
)

rem Pause for the specified time window before checking again
timeout /t %timeWindow% > nul
goto Start
