;
;   BP3D.asm
;   BP3D (short for BoilPlate3D) framework main base unit.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

; -----	MASM32 INCLUDES -----
include include\windows.inc

include include\gdi32.inc
includelib gdi32.lib
include include\glu32.inc
includelib glu32.lib
include include\kernel32.inc
includelib kernel32.lib
include include\masm32.inc
includelib masm32.lib
include include\msvcrt.inc
includelib msvcrt.lib
include include\opengl32.inc
includelib opengl32.lib
include include\user32.inc
includelib user32.lib
include include\winmm.inc
includelib winmm.lib


include macros\macros.asm

; -----	INTERFACE -----

IFDEF BP_TRACEABLE_HEAP					; Malloc macros for memory tracing
	bpFree		TEXTEQU <bpFreeProc>
	bpMalloc	TEXTEQU <bpMallocProc>
	bpReAlloc	TEXTEQU <bpReAllocProc>
ELSE
	bpFree		TEXTEQU <HeapFree>
	bpMalloc	TEXTEQU <HeapAlloc>
	bpReAlloc	TEXTEQU <HeapReAlloc>
ENDIF

; ----- TYPES -----
;   MASM has some bad headers, fixed redefinitions are here. The ones that have
; unions in them are the ones that are fucked, with the exception of the 
; joystick, ones which are of an entirely different size due to microcock 
; switching UINT size from WORD to DWORD (symbolic field prefixes are still w).
DEVMODEA STRUCT
	dmDeviceName	BYTE	CCHDEVICENAME dup(?)
	dmSpecVersion	WORD	?
	dmDriverVersion	WORD	?
	dmSize			WORD	?
	dmDriverExtra	WORD	?
	dmFields		DWORD	?
	union
		struct
			dmOrientation	WORD	?
			dmPaperSize 	WORD	?
			dmPaperLength	WORD	?
			dmPaperWidth	WORD	?
			dmScale			WORD	?
			dmCopies		WORD	?
			dmDefaultSource	WORD	?
			dmPrintQuality	WORD	?
		ends
		;dmPosition POINTL <>	; are Microsoft docs also tripping
		struct
			dmPosition				POINTL	<>
			dmDisplayOrientation	DWORD	?
			dmDisplayFixedOutput	DWORD	?
		ends
	ends
	dmColor			WORD	?
	dmDuplex		WORD	?
	dmYResolution	WORD	?
	dmTTOption		WORD	?
	dmCollate		WORD	?
	dmFormName		BYTE	CCHFORMNAME dup (?)
	dmLogPixels		WORD	?
	dmBitsPerPel	DWORD	?
	dmPelsWidth		DWORD	?
	dmPelsHeight	DWORD	?
	union
		dmDisplayFlags	DWORD	?
		dmNup			DWORD	?
	ends
	dmDisplayFrequency	DWORD	?
	dmICMMethod			DWORD	?
	dmICMIntent			DWORD	?
	dmMediaType			DWORD	?
	dmDitherType		DWORD	?
	dmReserved1			DWORD	?
	dmReserved2			DWORD	?
	dmPanningWidth		DWORD	?
	dmPanningHeight		DWORD	?
DEVMODEA ENDS

JOYCAPSAFIX STRUCT	; This redefinition isn't the same size, so another name
	wMid			WORD	?
	wPid			WORD	?
	szPname			BYTE	MAXPNAMELEN dup (?)
	wXmin			DWORD	?
	wXmax			DWORD	?
	wYmin			DWORD	?
	wYmax			DWORD	?
	wZmin			DWORD	?
	wZmax			DWORD	?
	wNumButtons		DWORD	?
	wPeriodMin		DWORD	?
	wPeriodMax		DWORD	?
	wRmin			DWORD	?
	wRmax			DWORD	?
	wUmin			DWORD	?
	wUmax			DWORD	?
	wVmin			DWORD	?
	wVmax			DWORD	?
	wCaps			DWORD	?
	wMaxAxes		DWORD	?
	wNumAxes		DWORD	?
	wMaxButtons		DWORD	?
	szRegKey		BYTE	MAXPNAMELEN dup(?)
	szOEMVxD		BYTE	MAX_JOYSTICKOEMVXDNAME dup(?)
JOYCAPSAFIX ENDS

JOYINFOFIX STRUCT
	wXpos		DWORD	?
	wYpos		DWORD	?
	wZpos		DWORD	?
	wButtons	DWORD	?
JOYINFOFIX ENDS

RAWINPUTHEADER  STRUCT 		; Just redefine all RAWINPUT while we're at it
	dwType      DWORD   ?
	dwSize      DWORD   ?
	hDevice     HANDLE  ?
	wParam      WPARAM  ?
RAWINPUTHEADER  ENDS
PRAWINPUTHEADER TYPEDEF PTR RAWINPUTHEADER

RAWMOUSE STRUCT 
	usFlags WORD    ?
	union
		ulButtons       DWORD   ?
		struct
			usButtonFlags   WORD    ?
			usButtonData    WORD    ?
		ends
	ends
	ulRawButtons        DWORD   ?
	lLastX              SDWORD  ?
	lLastY              SDWORD  ?
	ulExtraInformation  DWORD   ?
RAWMOUSE ENDS
PRAWMOUSE TYPEDEF PTR RAWMOUSE

RAWKEYBOARD STRUCT 
	MakeCode            WORD    ?
	Flags               WORD    ?
	Reserved            WORD    ?
	VKey                WORD    ?
	Message             DWORD   ?
	ExtraInformation    DWORD   ?
RAWKEYBOARD ENDS
PRAWKEYBOARD TYPEDEF PTR RAWKEYBOARD

RAWHID STRUCT 
	dwSizeHid           DWORD ?
	dwCount             DWORD ?
	bRawData            BYTE 1 dup (?)
RAWHID ENDS
PRAWHID TYPEDEF PTR RAWHID

RAWINPUT STRUCT 
	header  RAWINPUTHEADER <>
	union data
		mouse           RAWMOUSE    <>
		keyboard        RAWKEYBOARD <>
		hid             RAWHID      <>
	ends
RAWINPUT ENDS

IFDEF rax	; Cross-architecture compatibility (WIP)
	ECHO BP3D: Compiling in 64-bit mode.
	BPPtr		TYPEDEF QWORD	; Pointer type
	BPSPtr		TYPEDEF SQWORD	; Signed pointer type
	BPPtrShift	EQU 3			; Byte shift amount (to use instead of mul/div)
	
	; Pointer registers
	pax	EQU rax	
	pbx	EQU rbx
	pcx	EQU rcx
	pdx	EQU rdx
	pbp	EQU rbp
	psp	EQU rsp
ELSE
	ECHO BP3D: Compiling in 32-bit mode.
	BPPtr		TYPEDEF DWORD	; Pointer type
	BPSPtr		TYPEDEF SDWORD	; Signed pointer type
	BPPtrShift	EQU 2			; Byte shift amount (to use instead of mul/div)
	
	; Pointer registers
	pax	EQU eax
	pbx	EQU ebx
	pcx	EQU ecx
	pdx	EQU edx
	pbp	EQU ebp
	psp	EQU esp
ENDIF

; Miscellaneous types for argument generalization
BPBool TYPEDEF BYTE		; Boolean type
BPEnum TYPEDEF BYTE		; Enumerator type
	
BPForm STRUCT			; Windows form (window) structure
	Caption			BPPtr 0		; Form caption/title
	ClassName		BPPtr 0		; Form class name to register
	DefaultFlag		BPBool TRUE	; Flag to trigger default Win32/BP3D event proc
	DeviceContext	HDC 0		; Form device context
	GLContext		HANDLE 0	; Form OpenGL context
	InputFlags			BYTE BP_USE_RAW_MOUSE or BP_USE_JOYSTICK
	Handle			HWND 0		; Form window handle
	WndProc			BPPtr 0		; WndProc procedure offset
	
	; Read-only fields (set by internal BP3D or abstracted by procedures)
	Aspect			REAL4 0.0	; Form width divided by height (for GL viewport)
	Focused			BPBool TRUE	; Is the form in focus
	InputHeader		BPPtr 0
	MouseMode		BPEnum BP_MOUSE_MODE_VISIBLE		; Set with bpSetMouseMode
	WindowMode		BPEnum BP_WINDOW_MODE_WINDOWED	; Set with bpSetWindowMode
	ScreenCnt		POINT <0, 0>				; Global screen center
	ScreenPos		POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	ScreenSize		POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	WindowPos		POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	WindowSize		POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	
	; Event procedures
	OnCreate		BPPtr 0	; OnCreate PROC
	OnDestroy		BPPtr 0	; OnDestroy PROC
	OnFixed			BPPtr 0	; OnFixed PROC
	OnInput			BPPtr 0	; OnInput PROC BPInType:BPEnum, BPInStruct:BPPtr
	OnRender		BPPtr 0	; OnRender PROC
	OnResize		BPPtr 0	; OnResize PROC
BPForm ENDS

BPInJoyAxis STRUCT		; Joystick axis input structure
	JoyNum		DWORD ?
	Axis		BPPtr ?
	Position	REAL4 ?
BPInJoyAxis ENDS

BPInJoyButton STRUCT	; Joystick button input structure
	JoyNum		DWORD ?
	Button		BPPtr ?
	Pressed		BPBool ?
BPInJoyButton ENDS

BPInKey STRUCT			; Keyboard input structure
	Keycode		BPPtr ?
	Pressed		BPBool ?
BPInKey ENDS

BPInMouseButton STRUCT	; Mouse button input structure
	Button		BPPtr ?
	Pressed		BPBool ?
BPInMouseButton ENDS

BPInMouseMove STRUCT	; Mouse movement input structure
	Position	POINT <?, ?>
	Relative	POINT <?, ?>
BPInMouseMove ENDS

BPInTouch STRUCT		; Touch input structure
	Position	POINT <?, ?>
BPInTouch ENDS

BPJoystick STRUCT		; Joystick info abstraction structure (for bpJoysticks)
	Active		BPBool 		FALSE
	VendorId	WORD		?
	ProductId	WORD		?
	NumAxes		DWORD		?
	NumButtons	DWORD		?
	RawName		BYTE		MAXPNAMELEN dup (?)
BPJoystick ENDS

; ----- CONSTANTS -----
BP_FIXED_INTERVAL		EQU 1000 / 60	; OnFixed signal interval (ms)

; Input type constants (BPForm.OnInput)
BP_INPUT_JOY_AXIS		EQU 0	; Input structure is BPInJoyAxis
BP_INPUT_JOY_BUTTON		EQU 1	; Input structure is BPInJoyButton
BP_INPUT_KEY			EQU 2	; Input structure is BPInKey
BP_INPUT_MOUSE_BUTTON	EQU 3	; Input structure is BPInMouseButton
BP_INPUT_MOUSE_MOVE		EQU 4	; Input structure is BPInMouseMove
BP_INPUT_TOUCH			EQU 5	; Input structure is BPInTouch

; Joystick axes (BPInJoyAxis)
BP_JOY_AXIS_X	EQU 0	; (left stick horizontal)
BP_JOY_AXIS_Y	EQU 1	; (left stick vertical)
BP_JOY_AXIS_Z	EQU 2	; (right stick horizontal or analog shoulders)
BP_JOY_AXIS_R	EQU 3	; (right stick vertical)
BP_JOY_AXIS_U	EQU 4	; (right stick horizontal)
BP_JOY_AXIS_V	EQU 5

BP_JOY_DPAD_UP		EQU 32
BP_JOY_DPAD_RIGHT	EQU 33
BP_JOY_DPAD_DOWN	EQU 34
BP_JOY_DPAD_LEFT	EQU 35

; Mouse cursor mode constants (BPForm.MouseMode, bpSetMouseMode)
BP_MOUSE_MODE_VISIBLE	EQU 0	; Cursor is visible
BP_MOUSE_MODE_HIDDEN	EQU 1	; Cursor is invisible while above the form
BP_MOUSE_MODE_LOCKED	EQU 2	; Cursor is locked to the form center

;   Touch events through raw input seem to be sent with interpreted "mouse" 
; events. To combat that, a cooldown drops all mouse events after a touch event,
; until enough mouse events have been sent.
BP_MOUSE_TOUCH_COOLDOWN	EQU 10

; BPForm.InputFlags
BP_USE_RAW_MOUSE	EQU 1	; Register and use raw mouse instead of WM
BP_USE_JOYSTICK		EQU 2	; Use joysticks

; Form window mode constants (BPForm.WindowMode, bpSetWindowMode)
BP_WINDOW_MODE_WINDOWED			EQU 0	; Form is a draggable (sizeable) window
BP_WINDOW_MODE_MINIMIZED		EQU 1	; Form is minimized into tray
BP_WINDOW_MODE_MAXIMIZED		EQU 2	; Form is a maximized window
BP_WINDOW_MODE_FULLSCREEN		EQU 3	; Form is a 'fullscreen window'
BP_WINDOW_MODE_FULLSCREEN_EX	EQU 4	; Form uses exclusive fullscreen

.CONST
bpDefCaption	DB "BP3D", 0		; Default window caption
bpDefClassMain	DB "BPFMain", 0		; Default window class name
bpJoyMaxValue	DWORD 1191182336	; Value to divide the joystick DW by (32768)

.DATA
; Set to TRUE after first frame, then allows OnRender execution
bpFirstFrameSkipped BPBool FALSE

;   Delta time calculation variables (QueryPerformanceCounter uses
; LARGE_INTEGER, but one 32-bit portion of it is enough)
IFDEF BP_USE_LARGEINTEGER
	BPDelta TYPEDEF LARGE_INTEGER
	bpLastTick LARGE_INTEGER <0,0>
	bpPerfFreq LARGE_INTEGER <0,0>
	bpTick LARGE_INTEGER <0,0>
ELSE
	BPDelta TYPEDEF DWORD
	bpLastTick DWORD 0
	bpPerfFreq DWORD 0
	bpTick DWORD 0
ENDIF

bpDefHeap	HANDLE 0	; Default heap (to not GetProcessHeap every time)

bpJoyCount		DWORD 0					; Total amount of joysticks available
bpJoyInfoEx		JOYINFOEX 16 dup (<>)	; JOYINFOEX array for comparing states
bpJoysticks		BPJoystick 16 dup (<>)	; BPJoystick array to read info from
bpJoyThreshold	REAL4 0.06, 0.94		; Joystick axis threshold (min, max)

bpMouseClient 		SDWORD 0, 0	; Local mouse cursor position in the window
bpMouseClientPrev	SDWORD 0, 0	; Previous mouse cursor position (WM_MOUSEMOVE)
bpMouseScreen		SDWORD 0, 0	; On-screen global mouse cursor position

; See BP_MOUSE_TOUCH_COOLDOWN
bpMouseTouchCooldown	DWORD BP_MOUSE_TOUCH_COOLDOWN

deltaTime 		REAL4	0.0	; Scaled delta time, used for frame-independence
deltaScale 		REAL4	1.0	; Delta time scale mutiplier
deltaUnscaled 	REAL4	0.0	; Unscaled delta time
timeStart		REAL4	0.0	; Time since start (first OnCreate)

IFDEF BP_TRACEABLE_HEAP
	heapAllocated	DWORD	0	; Size of memory allocated on the heap
	IFDEF BP_TRACEABLE_HEAP_LIST
		heapList		BPPtr	0	; The list of all allocated memory blocks
		heapListSize	DWORD	0	; Size, in bytes, of the heap list
	ENDIF
ENDIF

; ----- IMPLEMENTATION -----
.CODE

; Prototype procedure declarations (for potential forward usage in unit)
IFDEF BP_TRACEABLE_HEAP
	bpFreeProc		PROTO :HANDLE, :DWORD, :LPVOID
	bpReAllocProc	PROTO :HANDLE, :DWORD, :LPVOID, :DWORD
	bpMallocProc	PROTO :HANDLE, :DWORD, :DWORD
	IFDEF BP_TRACEABLE_HEAP_LIST
		bpPrintHeapList PROTO
	ENDIF
ENDIF

bpCalculateDelta	PROTO :BPPtr, :BPPtr
bpCreateForm		PROTO :BPPtr
bpDestroyForm		PROTO :BPPtr
bpInitGLContext		PROTO :BPPtr
bpInJoyAxis			PROTO :BPPtr, :DWORD, :BPPtr, :REAL4
bpInJoyButton		PROTO :BPPtr, :DWORD, :BPPtr, :BOOL
bpInKey				PROTO :BPPtr, :WPARAM, :BOOL
bpInMouseButton		PROTO :BPPtr, :BPPtr, :BPBool
bpInRaw				PROTO :BPPtr, :LPARAM
bpReadJoysticks		PROTO :BPPtr
bpSetMouseMode		PROTO :BPPtr, :BPEnum
bpSetScreenCenter	PROTO :BPPtr
bpSetWindowMode		PROTO :BPPtr, :BPEnum
bpUpdateJoysticks	PROTO
bpUpdateWindowPos	PROTO :BPPtr
bpDefTimeProc		PROTO :UINT, :UINT, :DWORD, :DWORD, :DWORD
bpDefWndProc		PROTO :HWND, :UINT, :WPARAM, :LPARAM

;   32-bit m2m macro implementation that uses 64-bit values.
;   dst:REQ - mov destination.
;   src:REQ - mov source.
bpm2m64 MACRO dst:REQ, src:REQ
	IFDEF rax
		mov rax, src
		mov dst, rax
	ELSE
		mov eax, DWORD PTR src[0]
		mov DWORD PTR dst[0], eax
		mov eax, DWORD PTR src[4]
		mov DWORD PTR dst[4], eax
	ENDIF
ENDM

IFDEF BP_TRACEABLE_HEAP
;   Traceable memory free macro (maps to Win32 HeapFree).
bpFreeProc PROC EXPORT hHeap:HANDLE, dwFlags:DWORD, lpMem:LPVOID
	invoke HeapSize, hHeap, dwFlags, lpMem
	sub heapAllocated, eax
	invoke HeapFree, hHeap, dwFlags, lpMem
	
	IFDEF BP_TRACEABLE_HEAP_LIST
		push pbx
		xor pbx, pbx
		.WHILE (pbx < heapListSize)
			mov pcx, heapList
			mov pdx, lpMem
			.IF (BPPtr PTR [pcx+pbx] == pdx)
				add pcx, pbx
				mov pdx, pcx
				add pdx, SIZEOF BPPtr
				sub heapListSize, SIZEOF BPPtr
				.IF (pbx < heapListSize)
					push heapListSize
					sub heapListSize, pbx
					invoke RtlMoveMemory, pcx, pdx, heapListSize
					pop heapListSize
				.ENDIF
				mov heapList, rv(HeapReAlloc, hHeap, 0, heapList, heapListSize)
				.BREAK
			.ENDIF
			add pbx, SIZEOF BPPtr
		.ENDW
		pop pbx
	ENDIF
	
	IFDEF BP_TRACEABLE_HEAP_VERBOSE
		print "Freeing address "
		print uhex$(lpMem), 13, 10
	ENDIF
	ret
bpFreeProc ENDP

;   Traceable memory reallocation macro (maps to Win32 HeapReAlloc).
bpReAllocProc PROC EXPORT hHeap:HANDLE, dwFlags:DWORD, lpMem:LPVOID, \
dwBytes:DWORD
	invoke HeapSize, hHeap, dwFlags, lpMem
	sub heapAllocated, eax
	mov eax, dwBytes
	add heapAllocated, eax
	
	IFDEF BP_TRACEABLE_HEAP_VERBOSE
		print "Reallocating ", 9
		print udword$(dwBytes), 9
		print "from "
		print uhex$(lpMem), 32
	ENDIF
	
	invoke HeapReAlloc, hHeap, dwFlags, lpMem, dwBytes
	
	IFDEF BP_TRACEABLE_HEAP_LIST
		push pax
		push pbx
		xor pbx, pbx
		.WHILE (pbx < heapListSize)
			mov pcx, heapList
			mov pdx, lpMem
			.IF (BPPtr PTR [pcx+pbx] == pdx)
				mov BPPtr PTR [pcx+pbx], pax
				.BREAK
			.ENDIF
			add pbx, SIZEOF BPPtr
		.ENDW
		pop pbx
		pop pax
	ENDIF
	IFDEF BP_TRACEABLE_HEAP_VERBOSE
		push pax
		print "to "
		pop pax
		push pax
		print uhex$(pax), 13, 10
		pop pax
	ENDIF
	ret
bpReAllocProc ENDP

;   Traceable memory allocation macro (maps to Win32 HeapAlloc).
bpMallocProc PROC EXPORT hHeap:HANDLE, dwFlags:DWORD, dwBytes:DWORD
	mov eax, dwBytes
	add heapAllocated, eax
	
	IFDEF BP_TRACEABLE_HEAP_LIST
		add heapListSize, SIZEOF BPPtr
		.IF (heapList)
			mov heapList, rv(HeapReAlloc, hHeap, 0, heapList, heapListSize)
		.ELSE
			mov heapList, rv(HeapAlloc, hHeap, 0, heapListSize)
		.ENDIF
	ENDIF
	IFDEF BP_TRACEABLE_HEAP_VERBOSE
		print "Allocating ", 9
		print udword$(dwBytes), 9
	ENDIF
	
	invoke HeapAlloc, hHeap, dwFlags, dwBytes
	
	IFDEF BP_TRACEABLE_HEAP_LIST
		mov pcx, heapList
		mov pdx, heapListSize
		sub pdx, SIZEOF BPPtr
		mov BPPtr PTR [pcx+pdx], pax
	ENDIF
	IFDEF BP_TRACEABLE_HEAP_VERBOSE
		push pax
		print "on address "
		pop pax
		push pax
		print uhex$(pax), 13, 10
		pop pax
	ENDIF
	ret
bpMallocProc ENDP

IFDEF BP_TRACEABLE_HEAP_LIST
;   Print the list of allocated memory blocks.
bpPrintHeapList PROC EXPORT
	print "Allocated heap block count: "
	mov eax, heapListSize
	shr eax, BPPtrShift
	print str$(eax), 32, 40
	print udword$(heapAllocated)
	print " bytes", 41, 13, 10
	
	push pbx
	xor pbx, pbx
	.WHILE (pbx < heapListSize)
		push pbx
		add pbx, heapList
		print " ", 9
		print uhex$(BPPtr PTR [pbx]), 32
		print "size: "
		invoke HeapSize, bpDefHeap, 0, BPPtr PTR [pbx]
		print udword$(eax), 13, 10
		pop pbx
		add pbx, SIZEOF BPPtr
	.ENDW
	pop pbx
	ret
bpPrintHeapList ENDP
ENDIF

ENDIF


;   Calculate deltaTime. Done automatically in the message loop in bpCreateForm,
; if BPForm.DefaultFlag is TRUE (after OnRender callback).
bpCalculateDelta PROC EXPORT LastTick:BPPtr, DeltaPtr:BPPtr
	IFDEF BP_USE_LARGEINTEGER
		LOCAL diff:LARGE_INTEGER
		
		invoke QueryPerformanceCounter, ADDR bpTick
		IFDEF rax
			mov rax, bpTick
			mov rcx, LastTick
			sub rax, LARGE_INTEGER PTR [rcx]
			mov diff, rax
		
			.IF (!LARGE_INTEGER PTR [rcx])
				jmp bpCalculateDeltaSkip
			.ENDIF
		ELSE
			push ebx
			mov eax, bpTick.LowPart
			mov edx, bpTick.HighPart
			mov ecx, LastTick
			ASSUME ecx:PTR LARGE_INTEGER
			mov ebx, [ecx].LowPart
			mov ecx, [ecx].HighPart
			sub eax, ebx
			sbb edx, ecx
			mov diff.LowPart, eax
			mov diff[4].HighPart, edx
			pop ebx
			
			mov ecx, LastTick
			mov eax, [ecx].LowPart
			cmp eax, 0
			jne bpCalculateDeltaProcess
			mov eax, [ecx].HighPart
			cmp eax, 0
			jne bpCalculateDeltaProcess
			jmp bpCalculateDeltaSkip
		ENDIF
	ELSE
		LOCAL diff:DWORD, testTick:LARGE_INTEGER
		
		invoke QueryPerformanceCounter, ADDR testTick
		mov eax, testTick.LowPart
		mov bpTick, eax
		mov ecx, LastTick
		sub eax, DWORD PTR [ecx]
		mov diff, eax
		
		.IF (!DWORD PTR [ecx])
			jmp bpCalculateDeltaSkip
		.ENDIF
	ENDIF
	
	bpCalculateDeltaProcess:
	ASSUME ecx:nothing
	
	fild diff
	fild bpPerfFreq
	fdiv
	mov pax, DeltaPtr
	fstp REAL4 PTR [pax]
	
	bpCalculateDeltaSkip:
	mov pcx, LastTick
	IFDEF BP_USE_LARGEINTEGER
		bpm2m64 LARGE_INTEGER PTR [pcx], bpTick
	ELSE
		m2m DWORD PTR [pcx], bpTick
	ENDIF
	ret
bpCalculateDelta ENDP

;   Initialize form and create a window based on its parameters.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpCreateForm PROC EXPORT BPFormPtr:BPPtr
	LOCAL wc:WNDCLASSEX, msg:MSG, testFreq:LARGE_INTEGER, quitFlag:BPBool
	LOCAL ridMouse:RAWINPUTDEVICE
	ASSUME pcx:PTR BPForm
	
	.IF (!bpDefHeap)
		mov bpDefHeap, rv(GetProcessHeap)
	.ENDIF
	
	mov wc.cbSize, SIZEOF WNDCLASSEX
	mov wc.style, CS_HREDRAW or CS_VREDRAW
	mov wc.lpfnWndProc, OFFSET bpDefWndProc
	mov wc.cbClsExtra, NULL
	mov wc.cbWndExtra, NULL
	mov	wc.hbrBackground, COLOR_WINDOW
	mov wc.lpszMenuName, NULL
	
	mov pcx, BPFormPtr
	
	.IF (![pcx].Caption)
		mov [pcx].Caption, OFFSET bpDefCaption
	.ENDIF
	.IF (![pcx].ClassName)
		mov [pcx].ClassName, OFFSET bpDefClassMain
	.ENDIF
	
	mov pax, [pcx].ClassName
	mov wc.lpszClassName, pax	; Dubious, MSDN states it's a 32-bit pointer
	
	invoke GetModuleHandle, NULL
	mov	wc.hInstance, pax
	invoke LoadIcon, pax, 500
	mov wc.hIcon, pax
	mov wc.hIconSm, pax
	invoke LoadCursor, NULL, IDC_ARROW
	mov wc.hCursor, pax
	
	invoke RegisterClassEx, ADDR wc
	
	mov pcx, BPFormPtr
	invoke CreateWindowEx, 0, [pcx].ClassName, [pcx].Caption, \
	WS_OVERLAPPEDWINDOW or WS_SIZEBOX, \
	[pcx].ScreenPos.x,[pcx].ScreenPos.y, [pcx].ScreenSize.x,[pcx].ScreenSize.y,\
	NULL, NULL, wc.hInstance, NULL
	
	mov pcx, BPFormPtr
	mov [pcx].Handle, pax
	invoke SetWindowLong, pax, GWLP_USERDATA, BPFormPtr
	
	IFDEF BP_USE_LARGEINTEGER
		invoke QueryPerformanceFrequency, ADDR bpPerfFreq
	ELSE
		invoke QueryPerformanceFrequency, ADDR testFreq
		m2m bpPerfFreq, testFreq.LowPart
	ENDIF
	
	mov pcx, BPFormPtr
	mov [pcx].DefaultFlag, TRUE
	.IF ([pcx].OnCreate)
		call [pcx].OnCreate
	.ENDIF
	mov pcx, BPFormPtr
	.IF ([pcx].DefaultFlag)
		
		.IF ([pcx].InputFlags & BP_USE_JOYSTICK)
			call bpUpdateJoysticks
		.ENDIF
		
		mov pcx, BPFormPtr
		.IF ([pcx].InputFlags & BP_USE_RAW_MOUSE)
			mov pcx, BPFormPtr
			
			; Register raw mouse input (for no mouse lag on vsync)
			mov ridMouse.usUsagePage, 1		; Generic desktop
			mov ridMouse.usUsage, 2			; Mouse
			mov ridMouse.dwFlags, RIDEV_INPUTSINK
			m2m ridMouse.hwndTarget, [pcx].Handle
			
			invoke RegisterRawInputDevices, ADDR ridMouse, 1, \
			SIZEOF RAWINPUTDEVICE
		.ENDIF
		
		mov pcx, BPFormPtr
		.IF ([pcx].WindowMode)
			invoke bpSetWindowMode, pcx, [pcx].WindowMode
		.ENDIF
	.ENDIF
	
	; OnFixed
	mov pcx, BPFormPtr
	.IF ([pcx].OnFixed)
		;invoke SetTimer, [pcx].Handle, IDT_MOUSETRAP, BP_FIXED_INTERVAL, \
		;NULL	Non-functional ass
		invoke timeSetEvent, BP_FIXED_INTERVAL, 0, OFFSET bpDefTimeProc, \
		BPFormPtr, TIME_PERIODIC
	.ENDIF
	
	mov pcx, BPFormPtr
	invoke ShowWindow, [pcx].Handle, SW_SHOWDEFAULT
	
	ASSUME pcx:nothing
	
	mov quitFlag, 0
	.WHILE (!quitFlag)
		invoke MsgWaitForMultipleObjectsEx, 0, NULL, 12, QS_ALLINPUT, 0
		SWITCH eax
			CASE WAIT_OBJECT_0
				.WHILE TRUE
					invoke PeekMessage, ADDR msg, NULL, 0, 0, PM_REMOVE
					.IF (msg.message == WM_QUIT)
						mov quitFlag, 1
					.ENDIF
					;.BREAK .IF (!eax) Notepad++'s UDL freaks out because of this but I want to define .IF as blocks
					.IF (!eax)
						.BREAK
					.ENDIF
					invoke TranslateMessage, ADDR msg
					invoke DispatchMessage, ADDR msg
				.ENDW
		ENDSW
		;.BREAK .IF (quitFlag)
		.IF (quitFlag)
			.BREAK
		.ENDIF
	.ENDW
	
	ret
bpCreateForm ENDP

;   Destroy the window associated with a form.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpDestroyForm PROC EXPORT BPFormPtr:BPPtr
	ASSUME pcx:PTR BPForm
	
	mov pcx, BPFormPtr
	invoke DestroyWindow, [pcx].Handle
	
	ASSUME pcx:nothing
	ret
bpDestroyForm ENDP

;   Initialize OpenGL context in an existing form.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpInitGLContext PROC EXPORT BPFormPtr:BPPtr
	LOCAL pfd:PIXELFORMATDESCRIPTOR, pixelFormat:DWORD
	ASSUME pcx:PTR BPForm
	
	mov pcx, BPFormPtr
	invoke GetDC, [pcx].Handle
	mov pcx, BPFormPtr
	mov [pcx].DeviceContext, pax
	
	mov pfd.nSize, SIZEOF PIXELFORMATDESCRIPTOR
	mov pfd.nVersion, 1
	mov pfd.dwFlags, \
	PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER
	mov pfd.iPixelType, PFD_TYPE_RGBA
	mov pfd.cColorBits, 24
	mov pfd.cAccumBits, 0
	mov pfd.cStencilBits, 0
	mov pfd.iLayerType, PFD_MAIN_PLANE
	
	invoke ChoosePixelFormat, [pcx].DeviceContext, ADDR pfd
	mov pixelFormat, eax
	
	mov pcx, BPFormPtr
	invoke SetPixelFormat, [pcx].DeviceContext, pixelFormat, ADDR pfd
	
	mov pcx, BPFormPtr
	invoke wglCreateContext, [pcx].DeviceContext
	mov pcx, BPFormPtr
	mov [pcx].GLContext, pax
	
	invoke wglMakeCurrent, [pcx].DeviceContext, [pcx].GLContext
	
	invoke glEnable, GL_CULL_FACE
	invoke glShadeModel, GL_SMOOTH
	invoke glEnable, GL_DEPTH_TEST
	invoke glEnable, GL_TEXTURE_2D
	invoke glDepthFunc, GL_LEQUAL
	
	invoke glEnableClientState, GL_VERTEX_ARRAY
	invoke glEnableClientState, GL_TEXTURE_COORD_ARRAY
	invoke glEnableClientState, GL_NORMAL_ARRAY
	
	invoke glClearColor, 0, 0, 0, 0
	
	ASSUME pcx:nothing
	ret
bpInitGLContext ENDP

;   Send joystick axis input to form OnInput event as a struct.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   JoyNum:DWORD - number of the joystick sending input.
;   Axis:BPPtr - axis number (correspondent to BP_JOY_AXIS_? constants).
;   Position:REAL4 - axis position.
bpInJoyAxis PROC EXPORT BPFormPtr:BPPtr, JoyNum:DWORD, Axis:BPPtr, \
Position:REAL4
	LOCAL bpInStruct:BPInJoyAxis, pos:REAL4
	
	fld Position
	fabs
	fld bpJoyThreshold[0]
	fcomp
	fstsw ax
	bt ax, 8
	
	.IF (!Carry?)
		fstp st
		mov pos, 0
	.ELSE
		fld bpJoyThreshold[4]
		fcompp
		fstsw ax
		bt ax, 8
		
		.IF (Carry?)
			.IF (Position & 80000000h)
				mov pos, 3212836864
			.ELSE
				mov pos, 1065353216
			.ENDIF
		.ELSE
			m2m pos, Position
		.ENDIF
	.ENDIF
	
	m2m bpInStruct.JoyNum, JoyNum
	m2m bpInStruct.Axis, Axis
	m2m bpInStruct.Position, pos
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	lea pax, bpInStruct
	push pax
	push BP_INPUT_JOY_AXIS
	call [pcx].OnInput
	
	ASSUME pcx:nothing
	ret
bpInJoyAxis ENDP

;   Send joystick button input to form OnInput event as a struct.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   JoyNum:DWORD - number of the joystick sending input.
;   Button:BPPtr - number of the joystick button.
;   Pressed:BOOL - if the button has been pressed or released.
bpInJoyButton PROC EXPORT BPFormPtr:BPPtr, JoyNum:DWORD, Button:BPPtr, \
Pressed:BOOL
	LOCAL bpInStruct:BPInJoyButton
	
	m2m bpInStruct.JoyNum, JoyNum
	m2m bpInStruct.Button, Button
	.IF (Pressed)
		mov al, 1
	.ELSE
		xor al, al
	.ENDIF
	mov bpInStruct.Pressed, al
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	lea pax, bpInStruct
	push pax
	push BP_INPUT_JOY_BUTTON
	call [pcx].OnInput
	
	ASSUME pcx:nothing
	ret
bpInJoyButton ENDP

;   Send keyboard input to form OnInput event as a struct.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   Keycode:WPARAM - virtual-key code of the keyboard button.
;   Pressed:BOOL - if the key has been pressed or released.
bpInKey PROC EXPORT BPFormPtr:BPPtr, Keycode:WPARAM, Pressed:BOOL
	LOCAL bpInStruct:BPInKey
	
	m2m bpInStruct.Keycode, Keycode
	mov eax, Pressed
	mov bpInStruct.Pressed, al
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	lea pax, bpInStruct
	push pax
	push BP_INPUT_KEY
	call [pcx].OnInput
	
	ASSUME pcx:nothing
	ret
bpInKey ENDP

;   Send mouse button input to form OnInput event as a struct. Used to be sent
; from bpDefWndProc, but after switching to raw input, is sent from bpInMouse.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   Button:BPPtr - virtual-key code of the mouse button.
;   Pressed:BOOL - if the button has been pressed or released.
bpInMouseButton PROC EXPORT BPFormPtr:BPPtr, Button:BPPtr, Pressed:BPBool
	LOCAL bpInStruct:BPInMouseButton
	
	m2m bpInStruct.Button, Button
	mov al, Pressed
	mov bpInStruct.Pressed, al
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	lea pax, bpInStruct
	push pax
	push BP_INPUT_MOUSE_BUTTON
	call [pcx].OnInput
	
	ASSUME pcx:nothing
	ret
bpInMouseButton ENDP

;   Send mouse movement input to form OnInput event as a struct.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpInMouseMove PROC BPFormPtr:BPPtr
	LOCAL bpInStruct:BPInMouseMove
	
	m2m bpInStruct.Position.x, bpMouseClient
	m2m bpInStruct.Position.y, bpMouseClient[4]
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	mov eax, bpMouseClient
	sub eax, bpMouseClientPrev
	mov bpInStruct.Relative.x, eax
	mov eax, bpMouseClient[4]
	sub eax, bpMouseClientPrev[4]
	mov bpInStruct.Relative.y, eax
	
	m2m bpMouseClientPrev, bpMouseClient
	m2m bpMouseClientPrev[4], bpMouseClient[4]
	
	lea pax, bpInStruct
	push pax
	push BP_INPUT_MOUSE_MOVE
	call [pcx].OnInput
	
	ASSUME pcx:nothing
	ret
bpInMouseMove ENDP

;   Process raw input and send to form OnInput event as a struct.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   RawHandle:LPARAM - handle to RAWINPUT structure (lParam in WM_INPUT)
bpInRaw PROC EXPORT BPFormPtr:BPPtr, RawHandle:LPARAM
	LOCAL bpInMouseMoveStruct:BPInMouseMove
	LOCAL dwSize:DWORD, lpb:BPPtr
	
	; Get buffer size for RAWINPUT and allocate
	invoke GetRawInputData, RawHandle, RID_INPUT, NULL, ADDR dwSize, \
	SIZEOF RAWINPUTHEADER
	invoke bpMalloc, bpDefHeap, 0, dwSize
	mov lpb, pax
	
	; Read input data
	invoke GetRawInputData, RawHandle, RID_INPUT, lpb, ADDR dwSize, \
	SIZEOF RAWINPUTHEADER
	
	.IF (pax == dwSize)	; Check for valid input read
		mov pcx, lpb
		ASSUME pcx:PTR RAWINPUT
		
		.IF ([pcx].header.dwType == RIM_TYPEMOUSE)
			.IF (bpMouseTouchCooldown)
				dec bpMouseTouchCooldown
			.ELSE
				.IF ([pcx].data.mouse.usFlags & MOUSE_MOVE_ABSOLUTE)
					;TODO?
				.ELSE
					mov eax, [pcx].data.mouse.lLastX
					sar eax, 16
					mov bpInMouseMoveStruct.Relative.x, eax
					mov eax, [pcx].data.mouse.lLastY
					sar eax, 16
					mov bpInMouseMoveStruct.Relative.y, eax
				.ENDIF
				
				mov pcx, lpb
				xor pax, pax
				mov ax, [pcx].data.mouse.usButtonData
				.IF (ax)
					SWITCH pax
						CASE RI_MOUSE_BUTTON_1_DOWN
							invoke bpInMouseButton,BPFormPtr, VK_LBUTTON, TRUE
						CASE RI_MOUSE_BUTTON_1_UP
							invoke bpInMouseButton,BPFormPtr, VK_LBUTTON, FALSE
						CASE RI_MOUSE_BUTTON_2_DOWN
							invoke bpInMouseButton,BPFormPtr, VK_RBUTTON, TRUE
						CASE RI_MOUSE_BUTTON_2_UP
							invoke bpInMouseButton,BPFormPtr, VK_RBUTTON, FALSE
						CASE RI_MOUSE_BUTTON_3_DOWN
							invoke bpInMouseButton,BPFormPtr, VK_MBUTTON, TRUE
						CASE RI_MOUSE_BUTTON_3_UP
							invoke bpInMouseButton,BPFormPtr, VK_MBUTTON, FALSE
						CASE RI_MOUSE_BUTTON_4_DOWN
							invoke bpInMouseButton,BPFormPtr, VK_XBUTTON1, TRUE
						CASE RI_MOUSE_BUTTON_4_UP
							invoke bpInMouseButton,BPFormPtr, VK_XBUTTON1, FALSE
						CASE RI_MOUSE_BUTTON_5_DOWN
							invoke bpInMouseButton,BPFormPtr, VK_XBUTTON2, TRUE
						CASE RI_MOUSE_BUTTON_5_UP
							invoke bpInMouseButton,BPFormPtr, VK_XBUTTON2, FALSE
					ENDSW
				.ENDIF
				
				; Get global cursor coords
				invoke GetCursorPos, ADDR bpMouseScreen
				
				ASSUME pdx:PTR BPForm
				mov pdx, BPFormPtr
				
				m2m bpMouseClient[0], bpMouseScreen[0]
				m2m bpMouseClient[4], bpMouseScreen[4]
				invoke ScreenToClient, [pdx].Handle, ADDR bpMouseClient
				
				m2m bpInMouseMoveStruct.Position.x, bpMouseClient
				m2m bpInMouseMoveStruct.Position.y, bpMouseClient[4]
				
				mov pdx, BPFormPtr
				lea pax, bpInMouseMoveStruct
				push pax
				push BP_INPUT_MOUSE_MOVE
				call [pdx].OnInput
				
				ASSUME pdx:nothing
			.ENDIF
		.ELSEIF ([pcx].header.dwType == RIM_TYPEHID)
			; WIP (touch is vendor-specific, HidP doesn't work with it)
		.ENDIF
		ASSUME pcx:nothing
	.ENDIF
	invoke bpFree, bpDefHeap, 0, lpb
	ret
bpInRaw ENDP

;   Read and process all available joysticks for input.
;   BPFormPtr:BPPtr - pointer to a form structure to which input will be sent.
bpReadJoysticks PROC EXPORT BPFormPtr:BPPtr
	LOCAL joyInfoEx:JOYINFOEX, joyNum:DWORD, axisPos:REAL4, buttons:DWORD
	
	bpJoyAxisCheck MACRO Axis:REQ, AxisNum:REQ
		mov eax, joyInfoEx.Axis
		.IF (bpJoyInfoEx[pbx].Axis != eax)
			mov bpJoyInfoEx[pbx].Axis, eax
			fild bpJoyInfoEx[pbx].Axis
			fdiv bpJoyMaxValue
			fld1
			fsub
			fstp axisPos
			
			push pbx	; We'll still need it
			invoke bpInJoyAxis, BPFormPtr, joyNum, AxisNum, axisPos
			pop pbx
		.ENDIF
	ENDM
	
	mov joyInfoEx.dwSize, SIZEOF JOYINFOEX
	mov joyInfoEx.dwFlags, JOY_RETURNALL
	
	push pbx
	xor pbx, pbx
	.WHILE (pbx < bpJoyCount)
		mov pax, pbx
		mov pcx, SIZEOF BPJoystick
		mul pcx
		
		.IF (bpJoysticks[pax].Active)
			m2m buttons, bpJoysticks[pax].NumButtons
			
			invoke joyGetPosEx, pbx, ADDR joyInfoEx
			mov joyNum, pbx
			
			push pbx
			mov pax, pbx
			mov pcx, SIZEOF JOYINFOEX
			mul pcx
			mov pbx, pax
			
			bpJoyAxisCheck dwXpos, BP_JOY_AXIS_X
			bpJoyAxisCheck dwYpos, BP_JOY_AXIS_Y
			bpJoyAxisCheck dwZpos, BP_JOY_AXIS_Z
			bpJoyAxisCheck dwRpos, BP_JOY_AXIS_R
			bpJoyAxisCheck dwUpos, BP_JOY_AXIS_U
			bpJoyAxisCheck dwVpos, BP_JOY_AXIS_V
				
			mov eax, joyInfoEx.dwButtons
			.IF (bpJoyInfoEx[pbx].dwButtons != eax)
				xor pcx, pcx
				.WHILE (pcx < buttons)
					mov eax, 1
					shl eax, cl
					mov edx, bpJoyInfoEx[pbx].dwButtons
					and edx, eax
					and eax, joyInfoEx.dwButtons
					.IF (eax != edx)
						push pbx
						push pcx
						invoke bpInJoyButton, BPFormPtr, joyNum, pcx, eax
						pop pcx
						pop pbx
					.ENDIF
					inc pcx
				.ENDW
				
				m2m bpJoyInfoEx[pbx].dwButtons, joyInfoEx.dwButtons
			.ENDIF
			
			mov eax, joyInfoEx.dwPOV
			.IF (bpJoyInfoEx[pbx].dwPOV != eax)
				; Maybe .IF blocks is a better way overall
				.IF (eax == 65535)
					xor eax, eax
				.ELSE
					add eax, 4500
					.IF (eax >= 36000)
						sub eax, 36000
					.ENDIF
					
					mov edx, 8
					mul edx
					shr eax, 16
					
					mov cl, al
					mov eax, 1
					shl eax, cl
					
					push pax
					push pcx
					
					mov eax, joyInfoEx.dwPOV
					mov ecx, 9000
					xor edx, edx
					div ecx
					
					pop pcx
					pop pax
					
					.IF (edx)
						dec cl
						and cl, 3
						mov edx, 1
						shl edx, cl
						or eax, edx
					.ENDIF
				.ENDIF
				
				m2m bpJoyInfoEx[pbx].dwPOV, joyInfoEx.dwPOV
				
				mov joyInfoEx.dwReserved1, eax	; evil
				
				xor pcx, pcx
				.WHILE (pcx < 4)
					mov eax, 1
					shl eax, cl
					mov edx, bpJoyInfoEx[pbx].dwReserved1
					and edx, eax
					and eax, joyInfoEx.dwReserved1
					.IF (eax != edx)
						mov pdx, pcx
						add pdx, 32
						push pbx
						push pcx
						invoke bpInJoyButton, BPFormPtr, joyNum, pdx, eax
						pop pcx
						pop pbx
					.ENDIF
					inc pcx
				.ENDW
				
				m2m bpJoyInfoEx[pbx].dwReserved1, joyInfoEx.dwReserved1
			.ENDIF
			
			pop pbx
		.ENDIF
		
		inc pbx
	.ENDW
	pop pbx
	ret
bpReadJoysticks ENDP

;   Sets form's mouse mode.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   MouseMode:BPEnum - mouse mode, represented as a BPMSMODE constant.
bpSetMouseMode PROC EXPORT BPFormPtr:BPPtr, MouseMode:BPEnum
	LOCAL curInfo:CURSORINFO
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	mov al, MouseMode
	mov [pcx].MouseMode, al
	ASSUME pcx:nothing
	
	mov curInfo.cbSize, SIZEOF CURSORINFO
	invoke GetCursorInfo, ADDR curInfo
	
	.IF (MouseMode == BP_MOUSE_MODE_VISIBLE)
		.IF (curInfo.flags == 0)
			invoke ShowCursor, 1
		.ENDIF
	.ELSE
		.IF (curInfo.flags > 0)
			invoke ShowCursor, 0
		.ENDIF
	.ENDIF
	ret
bpSetMouseMode ENDP

;   Sets [BPFormPtr].ScreenCnt POINT structure to values that represent the
; form's global center coordinates on the screen (used for locking the cursor).
; Done automatically in bpDefSubclassProc - WM_MOVE & WM_SIZE, if 
; BPForm.DefaultFlag is TRUE.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpSetScreenCenter PROC EXPORT BPFormPtr:BPPtr
	LOCAL winW, winH:DWORD
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	m2m winW, [pcx].ScreenSize.x
	m2m winH, [pcx].ScreenSize.y
	
	mov ecx, 2
	
	mov eax, winW
	xor edx, edx
	div ecx
	mov winW, eax
	push eax
	mov eax, winH
	xor edx, edx
	div ecx
	mov winH, eax
	
	mov pcx, BPFormPtr
	add eax, [pcx].ScreenPos.y
	mov [pcx].ScreenCnt.y, eax
	pop eax
	add eax, [pcx].ScreenPos.x
	mov [pcx].ScreenCnt.x, eax
	
	ASSUME pcx:nothing
	ret
bpSetScreenCenter ENDP

;   Set form size and mode to fullscreen or windowed.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   WindowMode:BPEnum - window mode, represented as a BPWINMODE constant.
bpSetWindowMode PROC EXPORT BPFormPtr:BPPtr, WindowMode:BPEnum
	LOCAL devMode:DEVMODE
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	.IF ([pcx].WindowMode == BP_WINDOW_MODE_FULLSCREEN)
		; Dubiously necessary
		; I stole the modes from Godot but didn't even check how they work smh
		.IF (WindowMode == BP_WINDOW_MODE_MINIMIZED) || \
		(WindowMode == BP_WINDOW_MODE_MAXIMIZED)
			invoke bpSetWindowMode, pcx, BP_WINDOW_MODE_WINDOWED
			mov pcx, BPFormPtr
		.ENDIF
	.ELSEIF ([pcx].WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, WS_OVERLAPPEDWINDOW
		invoke ChangeDisplaySettingsA, NULL, 0
		mov pcx, BPFormPtr
	.ENDIF
	
	.IF (WindowMode == BP_WINDOW_MODE_WINDOWED)
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, WS_OVERLAPPEDWINDOW
		mov pcx, BPFormPtr
		invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, [pcx].WindowPos.x, \
		[pcx].WindowPos.y, [pcx].WindowSize.x, [pcx].WindowSize.y, \
		SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
	.ELSEIF (WindowMode == BP_WINDOW_MODE_MINIMIZED)
		invoke ShowWindow, [pcx].Handle, SW_MINIMIZE
	.ELSEIF (WindowMode == BP_WINDOW_MODE_MAXIMIZED)
		invoke ShowWindow, [pcx].Handle, SW_MAXIMIZE
	.ELSEIF (WindowMode == BP_WINDOW_MODE_FULLSCREEN)
		.IF ([pcx].WindowMode != BP_WINDOW_MODE_MAXIMIZED)
			invoke bpUpdateWindowPos, BPFormPtr
		.ENDIF
	
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, WS_POPUP
		invoke GetSystemMetrics, SM_CXSCREEN
		push eax
		invoke GetSystemMetrics, SM_CYSCREEN
		mov edx, eax
		pop eax
		mov pcx, BPFormPtr
		invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, 0, 0, eax, edx, \
		SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
	.ELSEIF (WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
		.IF ([pcx].WindowMode != BP_WINDOW_MODE_MAXIMIZED)
			invoke bpUpdateWindowPos, BPFormPtr
		.ENDIF
		
		mov devMode.dmSize, SIZEOF DEVMODE
		invoke EnumDisplaySettingsA, NULL, ENUM_CURRENT_SETTINGS, ADDR devMode
		mov pcx, BPFormPtr
		m2m devMode.dmPelsWidth, [pcx].ScreenSize.x
		m2m devMode.dmPelsHeight, [pcx].ScreenSize.y
		print str$(devMode.dmPelsWidth), 9
		print str$(devMode.dmPelsHeight), 13, 10
		invoke ChangeDisplaySettingsA, ADDR devMode, CDS_FULLSCREEN
		mov pcx, BPFormPtr
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, WS_POPUP
		mov pcx, BPFormPtr
		invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, 0, 0, \
		devMode.dmPelsWidth, devMode.dmPelsHeight, \
		SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
	.ENDIF
	
	mov pcx, BPFormPtr
	
	mov al, WindowMode
	mov [pcx].WindowMode, al
	ASSUME pcx:nothing
	ret
bpSetWindowMode ENDP

;   Update bpJoysticks (and respective bpJoyInfoEx) to then capture their input.
bpUpdateJoysticks PROC EXPORT
	LOCAL joyInfo:JOYINFOFIX, joyCaps:JOYCAPSAFIX
	mov bpJoyCount, rv(joyGetNumDevs)
	
	push pbx
	xor pbx, pbx
	.WHILE (pbx < bpJoyCount)
		invoke joyGetPos, pbx, ADDR joyInfo
		.IF (pax == JOYERR_NOERROR)
			mov pax, pbx
			mov pcx, SIZEOF BPJoystick
			mul pcx
			mov bpJoysticks[pax].Active, TRUE
			push pax
			invoke joyGetDevCapsA, pbx, ADDR joyCaps, SIZEOF JOYCAPSAFIX
			pop pax
			m2m bpJoysticks[pax].VendorId, joyCaps.wMid
			m2m bpJoysticks[pax].ProductId, joyCaps.wPid
			m2m bpJoysticks[pax].NumAxes, joyCaps.wNumAxes
			m2m bpJoysticks[pax].NumButtons, joyCaps.wNumButtons
			invoke RtlMoveMemory, ADDR joyCaps.szPname, \
			ADDR bpJoysticks[pax].RawName, MAXPNAMELEN
		.ELSE
			mov pax, pbx
			mov pcx, SIZEOF BPJoystick
			mul pcx
			mov bpJoysticks[pax].Active, FALSE
		.ENDIF
		inc pbx
	.ENDW
	pop pbx
	ret
bpUpdateJoysticks ENDP

;   Updates the BPForm window size and position parameters.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpUpdateWindowPos PROC EXPORT BPFormPtr: BPPtr
	LOCAL winRect:RECT
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	invoke GetWindowRect, [pcx].Handle, ADDR winRect
	mov eax, winRect.right
	mov ecx, winRect.left
	sub eax, ecx
	mov pcx, BPFormPtr
	mov [pcx].WindowSize.x, eax
	mov eax, winRect.bottom
	mov ecx, winRect.top
	sub eax, ecx
	mov pcx, BPFormPtr
	mov [pcx].WindowSize.y, eax
	
	m2m [pcx].WindowPos.x, winRect.left
	m2m [pcx].WindowPos.y, winRect.top

	ASSUME pcx:nothing
	ret
bpUpdateWindowPos ENDP

;   The default fixed timer callback procedure (TimeProc).
bpDefTimeProc PROC EXPORT uID:UINT, uMsg:UINT, dwUser:DWORD, dw1:DWORD, dw2:DWORD
	ASSUME pcx:PTR BPForm
	mov pcx, dwUser
	call [pcx].OnFixed
	ASSUME pcx:nothing
	ret
bpDefTimeProc ENDP

;   The default callback subclass procedure for processing form messages.
bpDefWndProc PROC EXPORT hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
	LOCAL dwRefData:BPPtr
	
	invoke GetWindowLong, hWnd, GWLP_USERDATA
	.IF (!pax)
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
		ret
	.ENDIF
	mov dwRefData, pax
	
	ASSUME pcx:PTR BPForm
	
	mov pcx, dwRefData
	mov [pcx].DefaultFlag, TRUE
	SWITCH uMsg
		CASE WM_DESTROY
			.IF ([pcx].OnDestroy)
				call [pcx].OnDestroy
			.ENDIF
			mov pcx, dwRefData
			.IF ([pcx].DefaultFlag)
				mov pcx, dwRefData
				.IF ([pcx].GLContext)
					invoke wglDeleteContext, [pcx].GLContext
				.ENDIF
				mov pcx, dwRefData
				.IF ([pcx].DeviceContext)
					invoke ReleaseDC, [pcx].Handle, [pcx].DeviceContext
				.ENDIF
				invoke PostQuitMessage, 0
			.ENDIF
		
		CASE WM_DEVICECHANGE
			.IF ([pcx].InputFlags & BP_USE_JOYSTICK)
				.IF (wParam == 7)	; DBT_DEVNODES_CHANGED
					call bpUpdateJoysticks
				.ENDIF
			.ENDIF
		
		CASE WM_INPUT
			.IF ([pcx].OnInput && [pcx].Focused)
				invoke bpInRaw, dwRefData, lParam
			.ENDIF
		
		CASE WM_KEYDOWN
			.IF ([pcx].OnInput)
				invoke bpInKey, dwRefData, wParam, TRUE
			.ENDIF
		CASE WM_KEYUP
			.IF ([pcx].OnInput)
				invoke bpInKey, dwRefData, wParam, FALSE
			.ENDIF
			
		CASE WM_KILLFOCUS
			mov [pcx].Focused, 0
		CASE WM_SETFOCUS
			mov [pcx].Focused, TRUE
			
		CASE WM_MOUSEMOVE
			.IF !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				.IF ([pcx].OnInput && [pcx].Focused)
					mov eax, lParam
					movsx eax, ax
					mov bpMouseClient, eax
					mov eax, lParam
					shr eax, 16
					movsx eax, ax
					mov bpMouseClient[4], eax
					invoke GetCursorPos, ADDR bpMouseScreen
					invoke bpInMouseMove, dwRefData
				.ENDIF
			.ENDIF
		
		CASE WM_MOVE
			mov eax, lParam
			movsx eax, ax
			mov [pcx].ScreenPos.x, eax
			mov eax, lParam
			shr eax, 16
			movsx eax, ax
			mov [pcx].ScreenPos.y, eax
			
			.IF ([pcx].DefaultFlag)
				invoke bpSetScreenCenter, dwRefData
			.ENDIF
			
		CASE WM_PAINT
			.IF (([pcx].MouseMode == BP_MOUSE_MODE_LOCKED) && [pcx].Focused)
				invoke SetCursorPos, [pcx].ScreenCnt.x, [pcx].ScreenCnt.y
				mov pcx, dwRefData
			.ENDIF
			
			invoke bpCalculateDelta, ADDR bpLastTick, ADDR deltaUnscaled
			fld deltaUnscaled
			fmul deltaScale
			fstp deltaTime

			fld deltaUnscaled
			fadd timeStart
			fstp timeStart
			
			mov pcx, dwRefData
			mov [pcx].DefaultFlag, TRUE
			.IF ([pcx].OnRender) && (bpFirstFrameSkipped)
				call [pcx].OnRender
			.ELSE
				mov bpFirstFrameSkipped, TRUE
			.ENDIF
			
			mov pcx, dwRefData
			.IF ([pcx].DefaultFlag)
				mov [pcx].DefaultFlag, FALSE
				invoke SwapBuffers, [pcx].DeviceContext
				invoke bpReadJoysticks, dwRefData
			.ENDIF
			
		CASE WM_SIZE
			SWITCH wParam
				CASE SIZE_RESTORED
					mov [pcx].WindowMode, BP_WINDOW_MODE_WINDOWED
				CASE SIZE_MINIMIZED
					mov [pcx].WindowMode, BP_WINDOW_MODE_MINIMIZED
				CASE SIZE_MAXIMIZED
					mov [pcx].WindowMode, BP_WINDOW_MODE_MAXIMIZED
			ENDSW
			mov eax, lParam
			movsx eax, ax
			mov [pcx].ScreenSize.x, eax
			mov eax, lParam
			shr eax, 16
			movsx eax, ax
			mov [pcx].ScreenSize.y, eax
			fild [pcx].ScreenSize.x
			fidiv [pcx].ScreenSize.y
			fstp [pcx].Aspect
			.IF ([pcx].OnResize)
				call [pcx].OnResize
			.ENDIF
			
			mov pcx, dwRefData
			.IF ([pcx].DefaultFlag)
				invoke glViewport, 0, 0, [pcx].ScreenSize.x, [pcx].ScreenSize.y
				invoke bpSetScreenCenter, dwRefData
			.ENDIF
			
		CASE WM_SYSKEYDOWN
			.IF ([pcx].OnInput)
				invoke bpInKey, dwRefData, wParam, TRUE
			.ENDIF
			
		CASE WM_SYSKEYUP
			.IF ([pcx].OnInput)
				invoke bpInKey, dwRefData, wParam, FALSE
			.ENDIF
			
			
		; This down here is fucking rancid but ReactOS compatibility I guess
		CASE WM_LBUTTONDOWN
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_LBUTTON, TRUE
			.ENDIF
		CASE WM_LBUTTONUP
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_LBUTTON, FALSE
			.ENDIF
		CASE WM_RBUTTONDOWN
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_RBUTTON, TRUE
			.ENDIF
		CASE WM_RBUTTONUP
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_RBUTTON, FALSE
			.ENDIF
		CASE WM_MBUTTONDOWN
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_MBUTTON, TRUE
			.ENDIF
		CASE WM_MBUTTONUP
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_MBUTTON, FALSE
			.ENDIF
		CASE WM_XBUTTONDOWN
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				mov eax, wParam
				shr eax, 16
				movsx eax, ax
				add eax, 4
				invoke bpInMouseButton, dwRefData, eax, TRUE
			.ENDIF
		CASE WM_XBUTTONUP
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_USE_RAW_MOUSE)
				mov eax, wParam
				shr eax, 16
				movsx eax, ax
				add eax, 4
				invoke bpInMouseButton, dwRefData, eax, FALSE
			.ENDIF
	ENDSW
	
	mov pcx, dwRefData
	.IF ([pcx].DefaultFlag)
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
	.ENDIF
	
	ASSUME pcx:nothing
	ret
bpDefWndProc ENDP
