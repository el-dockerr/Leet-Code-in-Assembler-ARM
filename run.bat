@echo off
rem ==========================================================================
rem  run.bat - build & run LeetCode solutions
rem     ASM -> bare-metal AArch64 ELF, executed in qemu-system-aarch64
rem     C++ -> native executable (g++)
rem
rem  run.bat help    for usage. Tools can be overridden with environment
rem  variables: QEMU, CLANG, CXX, LLDB, QEMU_CPU, ARCH, GDB_PORT
rem ==========================================================================
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "BUILD=%ROOT%\build"

if not defined QEMU_CPU set "QEMU_CPU=max"
if not defined ARCH     set "ARCH=armv9-a"
if not defined GDB_PORT set "GDB_PORT=1234"

set "CMD=%~1"
if "%CMD%"==""          goto :usage
if /i "%CMD%"=="help"   goto :usage
if /i "%CMD%"=="-h"     goto :usage
if /i "%CMD%"=="/?"     goto :usage
if /i "%CMD%"=="doctor" goto :doctor
if /i "%CMD%"=="new"    goto :new
if /i "%CMD%"=="all"    goto :all
if /i "%CMD%"=="clean"  goto :clean

set "TARGET=%~2"
set "BREAK=%~3"
for %%C in (asm cpp test debug) do if /i "%CMD%"=="%%C" goto :have_cmd
rem  "run.bat 0001" == "run.bat test 0001"
set "TARGET=%~1"
set "CMD=test"
:have_cmd
if "%TARGET%"=="" goto :usage
call :resolve_dir "%TARGET%" || exit /b 2

if /i "%CMD%"=="asm"   ( call :run_asm  & goto :done )
if /i "%CMD%"=="cpp"   ( call :run_cpp  & goto :done )
if /i "%CMD%"=="test"  ( call :run_both & goto :done )
if /i "%CMD%"=="debug" ( call :debug    & goto :done )
:done
exit /b %ERRORLEVEL%


rem ==========================================================================
:usage
echo Usage: run.bat ^<command^> [problem]
echo.
echo   asm   ^<problem^>   build the .S/.c files, run them in QEMU (AArch64)
echo   cpp   ^<problem^>   build solution.cc natively and run it
echo   test  ^<problem^>   asm + cpp  (also: run.bat ^<problem^>)
echo   debug ^<problem^> [func]   start QEMU halted, attach gdb, break at func ^(main^)
echo   all               run asm + cpp for every folder in problems\
echo   new   ^<name^>      create problems\^<name^> from templates\problem
echo   doctor            check that all required tools are installed
echo   clean             delete build\
echo.
echo   ^<problem^> is a path (tests\qemu-smoke), a folder name in problems\
echo   (0001-two-sum) or its prefix (0001).
echo.
echo   Quit a hanging QEMU with Ctrl+A then X.
exit /b 0


rem ==========================================================================
rem  :resolve_dir <arg>   ->  DIR, NAME
:resolve_dir
set "DIR="
if exist "%~f1\" set "DIR=%~f1"
if not defined DIR if exist "%ROOT%\%~1\" set "DIR=%ROOT%\%~1"
if not defined DIR if exist "%ROOT%\problems\%~1\" set "DIR=%ROOT%\problems\%~1"
if not defined DIR for /d %%D in ("%ROOT%\problems\%~1*") do if not defined DIR set "DIR=%%~fD"
if not defined DIR (
    echo error: problem "%~1" not found ^(looked in . and problems\^)
    exit /b 2
)
for %%D in ("%DIR%") do set "NAME=%%~nxD"
exit /b 0


rem ==========================================================================
rem  tool discovery
:find_qemu
if defined QEMU exit /b 0
for %%X in (qemu-system-aarch64.exe) do set "QEMU=%%~$PATH:X"
for %%P in ("%USERPROFILE%\scoop\apps\qemu\current" "%ProgramFiles%\qemu" "C:\msys64\ucrt64\bin" "C:\msys64\mingw64\bin") do (
    if not defined QEMU if exist "%%~P\qemu-system-aarch64.exe" set "QEMU=%%~P\qemu-system-aarch64.exe"
)
if defined QEMU exit /b 0
echo error: qemu-system-aarch64 not found.  Install:  scoop install qemu   ^(or set QEMU=path^)
exit /b 1

:find_clang
if defined CLANG exit /b 0
for %%X in (clang.exe) do set "CLANG=%%~$PATH:X"
if not defined CLANG if exist "%ProgramFiles%\LLVM\bin\clang.exe" set "CLANG=%ProgramFiles%\LLVM\bin\clang.exe"
if defined CLANG exit /b 0
echo error: clang not found.  Install:  winget install LLVM.LLVM   ^(or set CLANG=path^)
exit /b 1

:find_cxx
if defined CXX exit /b 0
for %%X in (g++.exe) do set "CXX=%%~$PATH:X"
for %%P in ("C:\msys64\ucrt64\bin" "C:\msys64\mingw64\bin") do (
    if not defined CXX if exist "%%~P\g++.exe" set "CXX=%%~P\g++.exe"
)
if defined CXX exit /b 0
echo error: g++ not found.  Install MSYS2 + mingw-w64-ucrt-x86_64-gcc   ^(or set CXX=path^)
exit /b 1

:find_gdb
if defined GDB exit /b 0
for %%X in (gdb-multiarch.exe) do set "GDB=%%~$PATH:X"
for %%P in ("C:\msys64\ucrt64\bin" "C:\msys64\mingw64\bin") do (
    if not defined GDB if exist "%%~P\gdb-multiarch.exe" set "GDB=%%~P\gdb-multiarch.exe"
)
if defined GDB exit /b 0
exit /b 1

:find_lldb
if defined LLDB exit /b 0
for %%X in (lldb.exe) do set "LLDB=%%~$PATH:X"
if not defined LLDB if exist "%ProgramFiles%\LLVM\bin\lldb.exe" set "LLDB=%ProgramFiles%\LLVM\bin\lldb.exe"
if defined LLDB exit /b 0
exit /b 1


rem ==========================================================================
rem  :build_asm   DIR, NAME -> build\NAME\asm.elf
:build_asm
call :find_clang || exit /b 1
set "SRCS="
for %%F in ("%DIR%\*") do (
    if /i "%%~xF"==".s" set SRCS=!SRCS! "%%~fF"
    if /i "%%~xF"==".c" set SRCS=!SRCS! "%%~fF"
)
if not defined SRCS (
    echo error: no .S / .c files in "%DIR%"
    exit /b 1
)
set "OUT=%BUILD%\%NAME%"
if not exist "%OUT%" mkdir "%OUT%"
"%CLANG%" --target=aarch64-none-elf -march=%ARCH% -ffreestanding -nostdlib ^
    -fno-unwind-tables -fno-asynchronous-unwind-tables -O2 -g -Wall -Wextra ^
    -I"%ROOT%\boot" -fuse-ld=lld -Wl,-T,"%ROOT%\boot\linker.ld" -Wl,-Map,"%OUT%\asm.map" ^
    "%ROOT%\boot\start.S" "%ROOT%\boot\runtime.c" %SRCS% -o "%OUT%\asm.elf"
exit /b %ERRORLEVEL%

:run_asm
echo ==== %NAME% [asm, qemu -cpu %QEMU_CPU%] ====
call :build_asm || exit /b 1
call :find_qemu || exit /b 1
"%QEMU%" -M virt -cpu %QEMU_CPU% -m 256M -nographic -monitor none ^
    -semihosting -no-reboot -kernel "%OUT%\asm.elf"
set "RC=%ERRORLEVEL%"
if "%RC%"=="99" echo ^(CPU exception - see the report above; disassemble with: llvm-objdump -d "%OUT%\asm.elf"^)
exit /b %RC%


rem ==========================================================================
:run_cpp
echo ==== %NAME% [cpp] ====
call :find_cxx || exit /b 1
set "SRCS="
for %%F in ("%DIR%\*.cc") do set SRCS=!SRCS! "%%~fF"
if not defined SRCS (
    echo error: no .cc files in "%DIR%"
    exit /b 1
)
set "OUT=%BUILD%\%NAME%"
if not exist "%OUT%" mkdir "%OUT%"
"%CXX%" -std=c++20 -O2 -g -Wall -Wextra -static -I"%ROOT%\cpp" %SRCS% -o "%OUT%\cpp.exe" || exit /b 1
"%OUT%\cpp.exe"
exit /b %ERRORLEVEL%


rem ==========================================================================
rem  :run_both   runs whatever exists (asm and/or cpp); appends to FAILS
:run_both
set "RC=0"
set "RAN="
if exist "%DIR%\*.S" (
    set "RAN=1"
    call :run_asm
    if errorlevel 1 ( set "RC=1" & set "FAILS=!FAILS! %NAME%[asm]" )
)
if exist "%DIR%\*.cc" (
    set "RAN=1"
    call :run_cpp
    if errorlevel 1 ( set "RC=1" & set "FAILS=!FAILS! %NAME%[cc]" )
)
if not defined RAN echo ==== %NAME%: nothing to run ^(no .S or .cc^) ====
exit /b %RC%


rem ==========================================================================
:all
set "FAILS="
set /a COUNT=0
for /d %%D in ("%ROOT%\problems\*") do (
    set "DIR=%%~fD"
    set "NAME=%%~nxD"
    set /a COUNT+=1
    call :run_both
    echo.
)
if defined FAILS (
    echo FAILED:%FAILS%
    exit /b 1
)
echo All %COUNT% problems passed.
exit /b 0


rem ==========================================================================
:debug
call :build_asm || exit /b 1
call :find_qemu || exit /b 1
echo Starting QEMU halted at _start, GDB stub on localhost:%GDB_PORT% ...
start "qemu %NAME% (close to stop)" "%QEMU%" -M virt -cpu %QEMU_CPU% -m 256M -nographic ^
    -monitor none -semihosting -no-reboot -S -gdb tcp::%GDB_PORT% -kernel "%OUT%\asm.elf"
if not defined BREAK set "BREAK=main"
call :find_gdb
if defined GDB (
    echo.
    echo   gdb cheat sheet:  c ^| si ^| ni ^| b ^<func^> ^| info registers ^| x/8dw $x0 ^| bt ^| q
    echo.
    "%GDB%" -q -x "%ROOT%\boot\debug.gdb" -ex "target remote localhost:%GDB_PORT%" ^
        -ex "break %BREAK%" -ex "continue" "%OUT%\asm.elf"
    taskkill /fi "WINDOWTITLE eq qemu %NAME%*" >nul 2>&1
    exit /b 0
)
call :find_lldb
if defined LLDB (
    echo.
    echo   lldb cheat sheet:  c ^| si ^| ni ^| b ^<func^> ^| register read ^| dis ^| q
    echo.
    "%LLDB%" "%OUT%\asm.elf" -o "gdb-remote localhost:%GDB_PORT%" -o "b %BREAK%" -o "c"
    taskkill /fi "WINDOWTITLE eq qemu %NAME%*" >nul 2>&1
    exit /b 0
)
echo No debugger found. Install gdb-multiarch ^(MSYS2: pacman -S mingw-w64-ucrt-x86_64-gdb-multiarch^)
echo and attach it to localhost:%GDB_PORT% with "%OUT%\asm.elf".
exit /b 0


rem ==========================================================================
:new
if "%~2"=="" (
    echo usage: run.bat new 0042-trapping-rain-water
    exit /b 2
)
set "DEST=%ROOT%\problems\%~2"
if exist "%DEST%" (
    echo error: "%DEST%" already exists
    exit /b 1
)
xcopy /e /i /q "%ROOT%\templates\problem" "%DEST%" >nul || exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$num, $slug = '%~2' -split '-', 2; if (-not $slug) { $slug = $num };" ^
  "$title = (Get-Culture).TextInfo.ToTitleCase($slug.Replace('-', ' '));" ^
  "Get-ChildItem -LiteralPath '%DEST%' -File | ForEach-Object {" ^
  "  $t = [IO.File]::ReadAllText($_.FullName);" ^
  "  $t = $t.Replace('NNNN', $num).Replace('<slug>', $slug).Replace('Title', $title);" ^
  "  [IO.File]::WriteAllText($_.FullName, $t) }"
echo Created problems\%~2
echo   edit   problems\%~2\solution.S, test.c, solution.cc
echo   run    run.bat %~2
exit /b 0


rem ==========================================================================
:clean
if exist "%BUILD%" rmdir /s /q "%BUILD%"
echo build\ removed
exit /b 0


rem ==========================================================================
:doctor
set "MISSING=0"
call :find_qemu  && ( echo [ok] qemu  : !QEMU! & "!QEMU!" --version | findstr /b QEMU ) || set "MISSING=1"
call :find_clang && ( echo [ok] clang : !CLANG! & "!CLANG!" --version | findstr /b clang ) || set "MISSING=1"
call :find_cxx   && ( echo [ok] c++   : !CXX! ) || set "MISSING=1"
call :find_gdb   && ( echo [ok] gdb   : !GDB! ) || echo [--] gdb   : gdb-multiarch not found ^(optional, for run.bat debug^)
if "%MISSING%"=="1" (
    echo.
    echo Some required tools are missing - see the messages above.
    exit /b 1
)
echo.
echo Running QEMU smoke test ...
set "DIR=%ROOT%\tests\qemu-smoke"
set "NAME=qemu-smoke"
call :run_asm
exit /b %ERRORLEVEL%
