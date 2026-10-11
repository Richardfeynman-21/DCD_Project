@echo off
setlocal enabledelayedexpansion
title FPGA Wild Animal Detection - Vivado Behavioral Simulation

echo ==================================================================
echo   FPGA WILD ANIMAL DETECTION SYSTEM - WINDOWS SIMULATION RUNNER
echo   Base: Abhishek ^& Megalingam 2025 + 4 Novelty Additions
echo ==================================================================
echo.

cd /d "%~dp0"

REM 1. Check if vivado is already in PATH
where vivado >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [INFO] Found Vivado in system PATH.
    set "VIVADO_CMD=vivado"
    goto RUN_SIM
)

REM 2. Look for Vivado in all common installation directories
echo [INFO] Vivado not in PATH. Searching standard installation paths...
for /d %%D in ("C:\Vivado\20*" "C:\Xilinx\Vivado\20*" "D:\Vivado\20*" "D:\Xilinx\Vivado\20*" "E:\Vivado\20*" "E:\Xilinx\Vivado\20*" "C:\tools\Xilinx\Vivado\20*") do (
    if exist "%%D\bin\vivado.bat" (
        echo [INFO] Found Vivado at: %%D\bin\vivado.bat
        set "VIVADO_CMD=%%D\bin\vivado.bat"
        set "PATH=%%D\bin;!PATH!"
        goto RUN_SIM
    )
)

echo.
echo [ERROR] Could not automatically locate vivado.bat.
echo.
echo Please run one of the following options:
echo   Option 1: In Vivado GUI, open Tcl Console at the bottom and enter:
echo             source scripts/run_simulation.tcl
echo.
echo   Option 2: Add Vivado's bin folder (e.g. C:\Vivado\2023.2\bin)
echo             to your Windows Environment PATH variable, then re-run this script.
echo.
pause
exit /b 1

:RUN_SIM
echo [INFO] Adding Vivado binary path to session environment...
echo [INFO] Launching Vivado behavioral simulation in batch mode...
echo.
call "%VIVADO_CMD%" -mode batch -source scripts/run_simulation.tcl

if %ERRORLEVEL% equ 0 (
    echo.
    echo ==================================================================
    echo    SIMULATION COMPLETED AND VERIFIED WITH 0 ERRORS!
    echo ==================================================================
) else (
    echo.
    echo [ERROR] Simulation batch run failed with code %ERRORLEVEL%.
    echo Please check the error messages above or in vivado.log.
)

echo.
pause
