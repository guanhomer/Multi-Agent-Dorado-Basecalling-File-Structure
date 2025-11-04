@echo off
setlocal enabledelayedexpansion
title Toggle Agent Lock State
color 0A

:: ------------------------------------------------------------
:: toggle_agent.bat — Lock/unlock an agent in status\agent_status.csv
:: Double-click to run. The window stays open (uses PAUSE).
:: ------------------------------------------------------------

:: Defaults
set "SCRIPT_DIR=%~dp0"
set "STATUS_DIR=%SCRIPT_DIR%status"
set "CSV=%STATUS_DIR%\agent_status.csv"
set "LOCKDIR=%CSV%.lockdir"
:: set "AGENT_NAME=%COMPUTERNAME%"
set "AGENT_NAME=Analysis_PC"
set "CSV=%STATUS_DIR%\agent_status.csv"
set "LOCKDIR=%CSV%.lockdir"
set "ACTION=unlock"

:: Ensure status dir and CSV exist
if not exist "%STATUS_DIR%" (
  echo ERROR: Status folder not found.
  echo.
  pause
  exit /b 1
)
if not exist "%CSV%" (
  echo ERROR: Agent status file not found.
  echo.
  pause
  exit /b 1
)

:: Show table BEFORE
echo.
echo ==== agent_status.csv (before) ====================================
powershell -NoProfile -ExecutionPolicy Bypass ^
  -Command ^
    "$csv='%CSV%'; if (Test-Path $csv) { Import-Csv $csv | Sort-Object agent_name | Format-Table agent_name,lock_state,agent_state,last_folder_id,last_updated -AutoSize | Out-String -Width 4096 | Write-Output } else { Write-Output 'agent_status.csv not found.' }"
echo ===================================================================
echo.

:: -------- Interactive menu --------
echo.
set /p "TMPAGENT=Agent name (default: %AGENT_NAME%): "
if not "%TMPAGENT%"=="" set "AGENT_NAME=%TMPAGENT%"

echo Select action:
echo   [L]ock agent
echo   [U]nlock agent
set /p "CHOICE=Enter L or U (default U): "
if /I "%CHOICE%"=="L" set "ACTION=lock"
if /I "%CHOICE%"=="U" set "ACTION=unlock"

:: Validate action from args path
if /I not "%ACTION%"=="lock" if /I not "%ACTION%"=="unlock" (
  echo ERROR: Action must be "lock" or "unlock".
  echo.
  pause
  exit /b 1
)

echo Using:
echo   AGENT_NAME : %AGENT_NAME%
echo   ACTION     : %ACTION%
echo   STATUS_DIR : %STATUS_DIR%
echo.

:: -------- Acquire simple lock (mkdir is atomic) --------
set /a WAITED=0
:TRYLOCK
mkdir "%LOCKDIR%" 1>nul 2>nul
if errorlevel 1 (
  if %WAITED% GEQ 30 (
    echo ERROR: Could not acquire lock on "%CSV%" after 30s.
    echo.
    pause
    exit /b 2
  )
  timeout /t 1 >nul
  set /a WAITED+=1
  goto :TRYLOCK
)

:: -------- Update agent row --------
powershell -NoProfile -ExecutionPolicy Bypass ^
  -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$csv=[IO.Path]::GetFullPath('%CSV%');" ^
    "$agent='%AGENT_NAME%';" ^
    "$action='%ACTION%';" ^
    "$now=Get-Date -Format 'yyyy-MM-dd HH:mm:ss';" ^
    "$rows= if (Test-Path $csv) { Import-Csv -Path $csv } else { @() };" ^
    "if (-not $rows) { $rows=@() }" ^
    "$row=$rows | Where-Object { $_.agent_name -eq $agent } | Select-Object -First 1;" ^
    "if ($null -ne $row) {" ^
    "  if ($action -ieq 'lock') { $row.lock_state='locked' } else { $row.lock_state='unlocked' };" ^
    "  $row.last_updated=$now;" ^
    "  $rows | Sort-Object agent_name | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8;" ^
    "};" 

set PSSTATUS=%ERRORLEVEL%

:: Release lock
rmdir "%LOCKDIR%" 1>nul 2>nul

if not "%PSSTATUS%"=="0" (
  echo ERROR: Failed to update "%CSV%".
  echo.
  pause
  exit /b %PSSTATUS%
)

:: Show table AFTER
echo.
echo ==== agent_status.csv (after) =====================================
powershell -NoProfile -ExecutionPolicy Bypass ^
  -Command ^
    "$csv='%CSV%'; Import-Csv $csv | Sort-Object agent_name | Format-Table agent_name,lock_state,agent_state,last_folder_id,last_updated -AutoSize | Out-String -Width 4096 | Write-Output"
echo ===================================================================
echo.

echo OK: %AGENT_NAME% set to %ACTION% in "%CSV%".
echo.
pause
exit /b 0
