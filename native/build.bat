@echo off
REM Builds the dnsolve_native library for Windows.
REM
REM Usage:
REM   build.bat            - Release build
REM   build.bat --debug    - Debug build
REM
REM Output: target\release\dnsolve_native.dll

setlocal

cd /d "%~dp0"

set PROFILE=release
if "%~1"=="--debug" set PROFILE=debug

echo Building dnsolve_native (%PROFILE%)...
cargo build --profile %PROFILE%

if %ERRORLEVEL% NEQ 0 (
    echo Build failed.
    exit /b 1
)

set LIB_PATH=target\%PROFILE%\dnsolve_native.dll

if exist "%LIB_PATH%" (
    echo.
    echo Build successful: %LIB_PATH%
    echo.
    echo To use with Dart, copy dnsolve_native.dll next to your Dart executable
    echo or add the directory to your PATH.
) else (
    echo Build failed: %LIB_PATH% not found.
    exit /b 1
)
