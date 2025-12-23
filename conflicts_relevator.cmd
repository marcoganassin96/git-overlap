@echo off
:: Windows shim to run the POSIX shell script using an available bash (Git Bash)
:: It forwards all arguments to the bundled bin/conflicts_relevator.sh script
:: Try to find bash in PATHwhere bash >nul 2>&1
if %errorlevel%==0 (    set "BASH=bash") else (    if exist "%ProgramFiles%\Git\bin\bash.exe" (        set "BASH=%ProgramFiles%\Git\bin\bash.exe"    ) else if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (        set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"    ) else (        echo Error: bash not found. Please install Git for Windows (Git Bash) and ensure bash is available in PATH.        exit /b 1    )):: Invoke the bundled POSIX script located relative to this shim"%BASH%" "%~dp0bin/conflicts_relevator.sh" %*