IFNDEF BP_LIB_CPU
	BP_LIB_CPU EQU		0001000b	; .386
ENDIF

IF BP_LIB_CPU EQ 		0001000b	; .386
	.386
	ECHO BP3DLibrary: Compiling in 80386 mode.
ELSEIF BP_LIB_CPU EQ	0010000b	; .486
	.486
	ECHO BP3DLibrary: Compiling in 80486 mode.
ELSEIF BP_LIB_CPU EQ	0100000b	; .586
	.586
	ECHO BP3DLibrary: Compiling in 80586 mode.
ELSE BP_LIB_CPU EQ 		1000000b	; .686
	.686
	ECHO BP3DLibrary: Compiling in 80686 mode.
ENDIF
.model flat, stdcall
option casemap:none

include ..\src\BP3D.asm
include ..\src\BP3DVectors.inc

ENUML MACRO
	enumlval_ = 0
ENDM

E MACRO earg:REQ
	earg EQU enumlval_
	enumlval_ = enumlval_ +1
ENDM

swCases	= 0
ESWITCH MACRO VarName:REQ
	mov al, VarName
	swCases = 0
ENDM
ECASE MACRO VarName:REQ
	IF swCases EQ 0
		.IF (al == VarName)
		swCases = 1
	ELSE
		.ELSEIF (al == VarName)
	ENDIF
ENDM
ENDESW MACRO
	.ENDIF
ENDM

ENUML
	E BP_DEFHEAP				; BPPtr
	E BP_DISPLAYDEVICECOUNT		; DWORD
	E BP_DISPLAYDEVICES			; BPDisplayDevice[16]
	E BP_FIRSTFRAMESKIPPED		; BPBool
	E BP_FIXEDINTERVAL			; REAL4
	E BP_JOYCOUNT				; DWORD
	E BP_JOYSTICKS				; BPJoystick[16]
	E BP_JOYTHRESHOLD			; REAL4
	E BP_MOUSECLIENT 			; SDWORD[2]
	E BP_MOUSECLIENTPREV		; SDWORD[2]
	E BP_MOUSESCREEN			; SDWORD[2]
	E BP_MOUSESCREENPREV		; SDWORD[2]
	E BP_DELTATIME				; REAL4
	E BP_DELTASCALE				; REAL4
	E BP_DELTAUNSCALED			; REAL4
	E BP_TIMESTART				; REAL4
	IFDEF BP_TRACEABLE_HEAP
		E BP_HEAPALLOCATED		; DWORD
		IFDEF BP_TRACEABLE_HEAP_LIST
			E BP_HEAPLIST		; BPPtr
			E BP_HEAPLISTSIZE	; DWORD
		ENDIF
	ENDIF

.CODE

bpFormDefault PROC BPFormPtr:BPPtr
	mov pax, BPFormPtr
	ASSUME pax:PTR BPForm
	
	mov [pax].Caption, OFFSET bpDefCaption
	mov [pax].ClassName, OFFSET bpDefClassMain
	mov [pax].DefaultFlag, 0
	mov [pax].DeviceContext, 0
	mov [pax].GraphicsContext, 0
	mov [pax].Handle, 0
	mov [pax].InputFlags, 0
	
	mov [pax].WindowStyle, WS_OVERLAPPEDWINDOW
	mov [pax].WndProc, OFFSET bpDefWndProc
	
	mov [pax].OnCreate, 0
	mov [pax].OnDestroy, 0
	mov [pax].OnFixed, 0
	mov [pax].OnInput, 0
	mov [pax].OnRender, 0
	mov [pax].OnResize, 0
	mov [pax].OnStart, 0
	
	mov [pax].Aspect, 0
	mov [pax].DisplayDevice, 0
	mov [pax].Focused, TRUE
	mov [pax].MouseMode, BP_MOUSE_MODE_VISIBLE
	mov [pax].WindowMode, BP_WINDOW_MODE_WINDOWED
	
	mov [pax].ScreenCnt.x, 0
	mov [pax].ScreenCnt.y, 0
	mov [pax].ScreenPos.x, CW_USEDEFAULT
	mov [pax].ScreenPos.y, CW_USEDEFAULT
	mov [pax].ScreenSize.x, CW_USEDEFAULT
	mov [pax].ScreenSize.y, CW_USEDEFAULT
	mov [pax].WindowPos.x, CW_USEDEFAULT
	mov [pax].WindowPos.y, CW_USEDEFAULT
	mov [pax].WindowSize.x, CW_USEDEFAULT
	mov [pax].WindowSize.y, CW_USEDEFAULT
	
	ASSUME pax:nothing
	ret
bpFormDefault ENDP

bpGetAddress PROC BPVal:BPEnum, BPOutPtr:BPPtr
	mov pcx, BPOutPtr
	ESWITCH BPVal
		ECASE BP_DEFHEAP
			mov BPPtr PTR [pcx],	OFFSET bpDefHeap
		ECASE BP_DISPLAYDEVICECOUNT
			mov BPPtr PTR [pcx],	OFFSET bpDisplayDeviceCount
		ECASE BP_DISPLAYDEVICES
			mov BPPtr PTR [pcx],	OFFSET bpDisplayDevices
		ECASE BP_FIRSTFRAMESKIPPED
			mov BPPtr PTR [pcx],	OFFSET bpFirstFrameSkipped
		ECASE BP_FIXEDINTERVAL
			mov BPPtr PTR [pcx],	OFFSET bpFixedInterval
		ECASE BP_JOYCOUNT
			mov BPPtr PTR [pcx],	OFFSET bpJoyCount
		ECASE BP_JOYSTICKS
			mov BPPtr PTR [pcx],	OFFSET bpJoysticks
		ECASE BP_JOYTHRESHOLD
			mov BPPtr PTR [pcx],	OFFSET bpJoyThreshold
		ECASE BP_MOUSECLIENT
			mov BPPtr PTR [pcx],	OFFSET bpMouseClient
		ECASE BP_MOUSECLIENTPREV
			mov BPPtr PTR [pcx],	OFFSET bpMouseClientPrev
		ECASE BP_MOUSESCREEN
			mov BPPtr PTR [pcx],	OFFSET bpMouseScreen
		ECASE BP_MOUSESCREENPREV
			mov BPPtr PTR [pcx],	OFFSET bpMouseScreenPrev
		ECASE BP_DELTATIME
			mov BPPtr PTR [pcx],	OFFSET deltaTime
		ECASE BP_DELTASCALE
			mov BPPtr PTR [pcx],	OFFSET deltaScale
		ECASE BP_DELTAUNSCALED
			mov BPPtr PTR [pcx],	OFFSET deltaUnscaled
		ECASE BP_TIMESTART
			mov BPPtr PTR [pcx],	OFFSET timeStart
	ENDESW
	ret
bpGetAddress ENDP

start PROC hInstDLL:DWORD, reason:DWORD, unused:DWORD
	;.IF (reason == DLL_PROCESS_ATTACH)
		mov eax, TRUE
	;.ELSEIF (reason == DLL_PROCESS_DETACH)

	;.ELSEIF (reason == DLL_THREAD_ATTACH)

	;.ELSEIF (reason == DLL_THREAD_DETACH)

	;.ENDIF
	ret
start ENDP
end
