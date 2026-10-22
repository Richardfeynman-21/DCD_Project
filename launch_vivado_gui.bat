@echo off
setlocal enabledelayedexpansion
title Launch Vivado GUI - FPGA Wild Animal Detection

echo ==================================================================
echo   LAUNCH VIVADO GUI (AUTOMATIC PATH AND ENVIRONMENT SETUP)
echo   Supports Vivado 2018.x - 2026.x on Windows
echo ==================================================================
echo.

cd /d "%~dp0"

REM 1. Check if vivado is already in PATH
where vivado >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [INFO] Found Vivado in system PATH.
    set "VIVADO_BIN=vivado"
    goto LAUNCH_GUI
)

REM 2. Search common installation directories
echo [INFO] Searching standard Vivado installation directories...
for /d %%D in ("C:\Vivado\20*" "C:\Xilinx\Vivado\20*" "D:\Vivado\20*" "D:\Xilinx\Vivado\20*" "E:\Vivado\20*" "E:\Xilinx\Vivado\20*" "C:\tools\Xilinx\Vivado\20*") do (
    if exist "%%D\bin\vivado.bat" (
        echo [INFO] Found Vivado at: %%D\bin\vivado.bat
        set "PATH=%%D\bin;!PATH!"
        set "VIVADO_BIN=%%D\bin\vivado.bat"
        goto LAUNCH_GUI
    )
)

echo.
echo [ERROR] Could not automatically locate vivado.bat.
echo Please ensure Vivado is installed or add Vivado\bin to your Windows PATH.
echo.
pause
exit /b 1

:LAUNCH_GUI
echo [INFO] Environment configured.
echo [INFO] Opening Vivado Project in GUI mode...
echo.

if exist "vivado_project\DCD_Project.xpr" (
    start "" "%VIVADO_BIN%" vivado_project\DCD_Project.xpr
) else (
    echo [INFO] Project file not found. Creating cleanly via scripts\create_project.tcl...
    call "%VIVADO_BIN%" -mode batch -source scripts\create_project.tcl
    start "" "%VIVADO_BIN%" vivado_project\DCD_Project.xpr
)

echo [SUCCESS] Vivado GUI launched!
echo In Vivado GUI, click "Run Behavioral Simulation" on the left Flow Navigator.
exit /b 0
