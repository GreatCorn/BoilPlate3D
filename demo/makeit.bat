:: Batch was created by the devil himself
::@echo off

setlocal EnableDelayedExpansion
set _argCnt=0
set _help=0
set _build=0
set _asm=masm
set _link=link
set _project="main"
set _sourcefile="main.asm"
set _drive=C
set _reading=args
set _includes=masm

set _quiet=0
set "_asmArgs="

set _project=%~n1
set _appName=%_project%.exe
if /i "%~x1" == ".asm" (set _sourcefile=%1) else (set "_sourcefile=%~1.asm")

for %%x in (%*) do (
	if !_reading!==appName (
		set _appName=%%~x
		set _reading=args
	) else if !_reading!==drive (
		set _drive=%%~x
		set _reading=args
	) else if !_reading!==includes (
		set _incpath="%%~x"
		set _libpath="%%~x\lib"
		set _reading=args
	) else (
		if [%%~x] == [/b] (
			set _build=1
		) else if [%%~x] == [/d] (
			set _reading=drive
		) else if [%%~x] == [/i] (
			set _includes=custom
			set _reading=includes
		) else if [%%~x] == [/j] (
			set _asm=uasm
			set _link=jwlink
		) else if [%%~x] == [/o] (
			set _reading=appName
		) else if [%%~x] == [/q] (
			set _quiet=1
		) else if [%%~x] == [/w] (
			set _includes=wininc
		) else if [%%~x] == [/64] (
			set _asm=uasm64
		) else if "%%~x"=="/help" (
			set _argCnt=0
			set _help=1
			goto :endArgs
		)
	)
	set /a _argCnt+=1
)

:endArgs

if %_argCnt%==0 (
	echo Usage: MAKEIT [sourcepath] ^<options^>
	if %_help%==0 (
		echo For more info run MAKEIT /help
	) else (
		echo /64		Use ML64 to compile
		echo /b		Build only, without running
		echo /d		Specify drive when using default include paths
		echo /i [path]	Specify custom include path. Must have \lib
		echo /help		Print this help message
		echo /j		Use UASM and JWlink to compile and link
		echo /o [name]	Set executable output name
		echo /q		Quiet compilation and linking
		echo /w		Use WinInc includes instead of MASM
	)
	exit /b
)

if [%_quiet%] EQU [1] (
	if %_asm%==masm (
		set _asmArgs=%_asmArgs% /nologo
	) else (
		set _asmArgs=%_asmArgs% -q
	)
)

if %_includes%==masm (
	set _incpath="%_drive%:\masm32"
	set _libpath="%_drive%:\masm32\lib"
) else if %_includes%==wininc (
	set _incpath="%_drive%:\WinInc"
	if %_asm%==uasm64 (
		set _libpath="%_drive%:\WinInc\Lib64"
	) else (
		set _libpath="%_drive%:\WinInc\Lib"
	)
	
	if %_asm%==masm (
		set _asmArgs=%_asmArgs% /DBP_WININC=1
	) else (
		set _asmArgs=%_asmArgs% -DBP_WININC=1
	)
)

if %_asm%==uasm (
	uasm32 -c -coff -I %_incpath% %_asmArgs% %_sourcefile%
) else if %_asm%==masm (
	ml /c /coff /I %_incpath% %_asmArgs% %_sourcefile%
) else if %_asm%==uasm64 (
	uasm64 -c -win64 -I %_incpath% %_asmArgs% %_sourcefile%
)

if %_link%==jwlink (
	if [%_quiet%] EQU [1] (
		JWlink RUNTIME WINDOWS FILE %_project%.obj LIBPATH %_libpath% OP START=_start NAME "%_appName%" OPTION QUIET OPTION NOLARGE
	) else (
		JWlink RUNTIME WINDOWS FILE %_project%.obj LIBPATH %_libpath% OP START=_start NAME "%_appName%" OPTION NOLARGE
	)
) else if %_link%==link (
	if [%_quiet%] EQU [1] (
		link /subsystem:WINDOWS %_project%.obj /libpath:%_libpath% /entry:start /out:"%_appName%" /nologo
	) else (
		link /subsystem:WINDOWS %_project%.obj /libpath:%_libpath% /entry:start /out:"%_appName%"
	)
)
if [%_build%] NEQ [1] (
	%_project%.exe
)