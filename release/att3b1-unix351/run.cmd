@echo off
rem AT&T UNIX PC (3B1 / PC 7300) with UNIX System V 3.51m, on the FreeBee
rem emulator. See README.txt.
rem   run.cmd              boot disk\hd.img; log in as tenox or root
rem   run.cmd 4x           CPU speed: 1x is a real 3B1 (10 MHz), up to 32x;
rem                        default 10x. The clock stays real
rem   set ZOOM=2           each 3B1 pixel 2x2 (1440x696); default 1: no zoom
rem   set COLOR=white      green (default), white or amber screen
rem   set MOUSE=grab       F10 grabs the mouse for the 3B1 and lets it go;
rem                        default seamless: the 3B1's pointer follows yours
rem                        over the window, with no grab
rem   set FLOPPY=file      a floppy image for the drive (F11 puts it in and
rem                        takes it out)
rem   set HD2=file         a second hard disk image
rem   set NET=none         no network: the Ethernet board with no cable
setlocal
cd /d "%~dp0"
if not exist disk\hd.img (
	echo run.cmd: no disk\hd.img
	exit /b 1
)
set T=10
if not "%~1"=="" set T=%~1
set T=%T:x=%
set T=%T:X=%
set N=0
set /a N=%T% 2>nul
if not "%N%"=="%T%" goto badspeed
if %N% LSS 1 goto badspeed
if %N% GTR 32 goto badspeed
if "%ZOOM%"=="" set ZOOM=1
echo %ZOOM%| findstr /r "^[1-9]$" >nul || (
	echo run.cmd: ZOOM must be 1 ^(no zoom^) to 9
	exit /b 1
)
if "%NET%"=="" set NET=slirp
if not "%NET%"=="slirp" if not "%NET%"=="none" (
	echo run.cmd: NET must be slirp or none
	exit /b 1
)
set R=0x33
set G=0xFF
set B=0x66
if /i "%COLOR%"=="white" (
	set R=0xFF
	set G=0xFF
	set B=0xFF
)
if /i "%COLOR%"=="amber" (
	set R=0xFF
	set G=0xB0
	set B=0x00
)
if "%MOUSE%"=="" set MOUSE=seamless
set SEAMLESS=
if /i "%MOUSE%"=="seamless" set SEAMLESS=true
if /i "%MOUSE%"=="grab" set SEAMLESS=false
if "%SEAMLESS%"=="" (
	echo run.cmd: MOUSE must be seamless or grab
	exit /b 1
)
rem FreeBee reads .freebee.toml. run.cmd writes it at every start: change
rem the variables, not that file. 'quotes' keep the backslashes of paths.
>.freebee.toml echo # made by run.cmd - edit run.cmd, not this file
>>.freebee.toml echo [floppy]
>>.freebee.toml echo disk = '%FLOPPY%'
>>.freebee.toml echo [hard_disk]
>>.freebee.toml echo disk1 = 'disk\hd.img'
>>.freebee.toml echo disk2 = '%HD2%'
>>.freebee.toml echo [display]
>>.freebee.toml echo x_scale = %ZOOM%
>>.freebee.toml echo y_scale = %ZOOM%
>>.freebee.toml echo scale_quality = "nearest"
>>.freebee.toml echo red = %R%
>>.freebee.toml echo green = %G%
>>.freebee.toml echo blue = %B%
>>.freebee.toml echo [roms]
>>.freebee.toml echo rom_14c = 'roms\14c.bin'
>>.freebee.toml echo rom_15c = 'roms\15c.bin'
>>.freebee.toml echo [cpu]
>>.freebee.toml echo turbo = %N%
>>.freebee.toml echo [mouse]
>>.freebee.toml echo seamless = %SEAMLESS%
>>.freebee.toml echo [memory]
>>.freebee.toml echo base_memory = 2048
>>.freebee.toml echo extended_memory = 2048
>>.freebee.toml echo [beeper]
>>.freebee.toml echo volume = 40
>>.freebee.toml echo [network]
>>.freebee.toml echo enabled = true
>>.freebee.toml echo backend = "%NET%"
>>.freebee.toml echo hostfwd = "tcp:127.0.0.1:35123-:23, tcp:127.0.0.1:35121-:21, tcp:127.0.0.1:35514-:514"
echo run.cmd: CPU %N%x. After the login prompt: telnet localhost 35123
bin\windows-x86_64\freebee.exe
exit /b %errorlevel%
:badspeed
echo run.cmd: the speed must be 1x to 32x (got %~1)
exit /b 1
