@echo off
title Flangx Desktop Widgets - Initializing...
cd /d "%~dp0"

:: Check if the executable is already built
if exist Flangx.exe (
    echo Launching Flangx...
    start Flangx.exe
    exit
)

:: If not found, attempt to compile using the built-in .NET compiler
echo [INFO] Flangx.exe not found. Attempting to compile from source...
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:Flangx.exe core\*.cs /reference:System.Windows.Forms.dll,System.Drawing.dll,System.Core.dll,System.Data.dll,System.Xml.dll /win32icon:assets\app.ico /platform:x64

if exist Flangx.exe (
    echo [SUCCESS] Compilation complete. Launching...
    start Flangx.exe
) else (
    echo [ERROR] Failed to compile Flangx.
    echo Ensure you are on a Windows machine with .NET 4.0 installed.
    pause
)
exit
