:: Batch is a fucking headache
@echo off

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
		) else if [%%~x] == [/c] (
			set _asm=asmc
			set _link=linkw
		) else if [%%~x] == [/d] (
			set _reading=drive
		) else if [%%~x] == [/i] (
			set _includes=custom
			set _reading=includes
		) else if [%%~x] == [/j] (
			set _asm=uasm
			set _link=jwlink
		) else if [%%~x] == [/p] (
			set _asm=poasm
			set _link=polink
		) else if [%%~x] == [/o] (
			set _reading=appName
		) else if [%%~x] == [/q] (
			set _quiet=1
		) else if [%%~x] == [/w] (
			set _includes=wininc
		) else if [%%~x] == [/64] (
			if !_asm!==masm (
				set _asm=ml64
			) else if !_asm!==asmc (
				set _asm=asmc64
			) else if !_asm!==uasm (
				set _asm=uasm64
			)
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
		echo /64		Use x64 compilation if available 
		echo /b		Build only, without running
		echo /c		Use ASMC and LINKW to compile and link
		echo /d		Specify drive when using default include paths
		echo /i [path]	Specify custom include path. Must have \lib
		echo /help		Print this help message
		echo /j		Use UASM and JWlink to compile and link
		echo /o [name]	Set executable output name
		echo /p		Use POASM and POLINK to compile and link
		echo /q		Quiet compilation and linking
		echo /w		Use WinInc includes instead of MASM
	)
	exit /b
)

if [%_quiet%] EQU [1] (
	if %_asm%==masm (
		set _asmArgs=%_asmArgs% /nologo
	) else if %_asm%==poasm (
		set _asmArgs=%_asmArgs% /V0
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
	) else if %_asm%==poasm (
		set _asmArgs=%_asmArgs% /DBP_WININC=1
	) else (
		set _asmArgs=%_asmArgs% -DBP_WININC=1
	)
)

if %_asm%==uasm (
	uasm32 -c -coff -I %_incpath% %_asmArgs% %_sourcefile%
) else if %_asm%==masm (
	ml /c /coff /I %_incpath% %_asmArgs% %_sourcefile%
) else if %_asm%==asmc (
	asmc -c -coff -I%_incpath% %_asmArgs% %_sourcefile%
) else if %_asm%==poasm (
	poasm /I %_incpath% %_asmArgs% %_sourcefile%
) else if %_asm%==asmc64 (
	asmc64 -c -coff -I%_incpath% %_asmArgs% %_sourcefile%
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
) else if %_link%==linkw (
	if [%_quiet%] EQU [1] (
		linkw /subsystem:WINDOWS /libpath:%_libpath% /entry:_start /out:"%_appName%" /nologo %_project%.obj 
	) else (
		linkw /subsystem:WINDOWS /libpath:%_libpath% /entry:_start /out:"%_appName%" %_project%.obj 
	)
) else if %_link%==polink (
	polink /subsystem:WINDOWS %_project%.obj /libpath:%_libpath% /entry:start /out:"%_appName%"
)
if [%_build%] NEQ [1] (
	%_project%.exe
)