;
;   BP3D.asm
;   Version 0.7ac1
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

include macros\macros.asm	; Should it be rewritten to omit MASM's macros?

; -----	INTERFACE -----

;   Available compile-time symbolic macros to define (EQU) before including 
; BP3D, for additional or alternative functionality in the build:
;
;   BP_COMPATIBILITY_W2K - Windows 2000, ME, 98SE compatibility mode. Removes
; all calls of the APIs not supported on aforementioned systems to avoid DLL
; errors. Unsupported APIs: RAWINPUT.
;
;   BP_TRACEABLE_HEAP - BP3D defines symbolic TEXTEQUs for memory management:
; bpFree, bpMalloc and bpReAlloc. When this macro is defined, they will be
; replaced with designated functions (bpFreeProc, bpMallocProc, bpReAllocProc), 
; which argument-wise map onto Windows' heap managing functions, while also
; keeping track of the allocated memory amount. When this macro isn't defined,
; they will map onto Windows' heap managing functions directly.
;
;   BP_TRACEABLE_HEAP_LIST - an extension of BP_TRACEABLE_HEAP, meaning that in
; order for it to work, BP_TRACEABLE_HEAP must be defined. Forms a list of all 
; the memory addresses allocated with bpMalloc that can be printed with
; bpPrintHeapList.
;
;   BP_TRACEABLE_HEAP_VERBOSE - an extension of BP_TRACEABLE_HEAP, meaning that
; in order for it to work, BP_TRACEABLE_HEAP must be defined. Prints verbose 
; debug information when calling bpFree, bpMalloc or bpReAlloc.
;
;   BP_USE_LARGE_INTEGER - use LARGE_INTEGER Windows structure when computing
; delta. This will ensure that all delta-related tick variables are of the type
; LARGE_INTEGER and the difference is computed in 64-bit mode.

IFDEF BP_TRACEABLE_HEAP		; Malloc macros for memory tracing
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
; unions in them are the ones that are messed up, with the exception of the 
; joystick, ones which are of an entirely different size due to Microsoft 
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

JOYINFOFIX STRUCT	; Same here
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

RAWMOUSE STRUCT 			; Doesn't exist at all in windows.inc
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

RAWKEYBOARD STRUCT 
	MakeCode            WORD    ?
	Flags               WORD    ?
	Reserved            WORD    ?
	VKey                WORD    ?
	Message             DWORD   ?
	ExtraInformation    DWORD   ?
RAWKEYBOARD ENDS

RAWHID STRUCT 
	dwSizeHid           DWORD ?
	dwCount             DWORD ?
	bRawData            BYTE 1 dup (?)
RAWHID ENDS

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

BPDisplayDevice STRUCT
	Active		BPBool FALSE
	DPI			DWORD ?
	Orientation	BPEnum ?
	RefreshRate	DWORD ?
	ScreenPos	POINT <?, ?>
	ScreenSize	POINT <?, ?>
	RawName		BYTE 32 dup (?)
BPDisplayDevice ENDS

BPForm STRUCT			; Windows form (window) structure
	Caption			BPPtr OFFSET bpDefCaption		; Form caption/title
	ClassName		BPPtr OFFSET bpDefClassMain		; Form registered class name
	DefaultFlag		BPBool 0	; Flag to trigger default Win32/BP3D event proc
	DeviceContext	HDC 0		; Form device context
	GLContext		HANDLE 0	; Form OpenGL context
	Handle			HWND 0		; Form window handle
	
	;   Input flags bitmask. See possible input flags at BP_IF_*.
	InputFlags		BYTE 0
	
	WindowStyle		LONG WS_OVERLAPPEDWINDOW
	
	WndProc			BPPtr OFFSET bpDefWndProc	; WndProc procedure offset
	
	; Read-only fields (set by internal BP3D or abstracted by procedures)
	Aspect			REAL4 0.0	; Form width divided by height (for GL viewport)
	DisplayDevice	DWORD 0		; Display device, set with bpSetDisplayDevice
	Focused			BPBool TRUE	; Is the form in focus
	MouseMode		BPEnum BP_MOUSE_MODE_VISIBLE	; Set with bpSetMouseMode
	WindowMode		BPEnum BP_WINDOW_MODE_WINDOWED	; Set with bpSetWindowMode
	
	ScreenCnt		POINT <0, 0>					; Global screen center
	ScreenPos		POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	ScreenSize		POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	WindowPos		POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	WindowSize		POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	
	; Event procedures
	;   OnCreate PROC
	;   Gets called after the form has just been created (bpCreateForm).
	OnCreate		BPPtr 0
	
	;   OnDestroy	PROC
	;   Gets called after the form has just been destroyed (WM_DESTROY).
	OnDestroy		BPPtr 0
	
	;   OnFixed		PROC
	;   Gets called in a separate asynchronous thread every bpFixedInterval 
	; seconds (default 0.01666666 s = 60 times/s).
	OnFixed			BPPtr 0
	
	;   OnInput		PROC BPInType:BPEnum, BPInStruct:BPPtr
	;   Gets called whenever captured input gets sent to the form (see 
	; InputFlags).
	;   BPInType:BPEnum - a BP_INPUT_* constant that signifies the type of input
	; sent to the callback function.
	;   BPInStruct:BPPtr - pointer to a BPIn* struct corresponding to BPInType.
	OnInput			BPPtr 0
	
	;   OnRender	PROC
	;   Gets called whenever the form is drawn (WM_PAINT). If DefaultFlag is on,
	; doesn't send DefWindowProc to maintain a loop. For frame-independence
	; deltaTime should be used.
	OnRender		BPPtr 0
	
	;   OnResize	PROC
	;   Gets called whenever the form is resized (WM_SIZE). Window size and
	; client size are return in WindowSize and ScreenSize respectively.
	OnResize		BPPtr 0
	
	;   OnStart		PROC
	;   Gets called after one frame has passed after form creation.
	OnStart			BPPtr 0	; OnStart	PROC
BPForm ENDS

BPInJoyAxis STRUCT		; Joystick axis input structure
	JoyNum		DWORD ?		; Joystick index
	Axis		BPPtr ?		; Axis index (BP_JOY_AXIS_*)
	Position	REAL4 ?		; Axis position [-1.0 - 1.0]
BPInJoyAxis ENDS

BPInJoyButton STRUCT	; Joystick button input structure
	JoyNum		DWORD ?		; Joystick index
	Button		BPPtr ?		; Button index
	Pressed		BPBool ?	; Is the button pressed or released
BPInJoyButton ENDS

BPInKey STRUCT			; Keyboard input structure
	Keycode		BPPtr ?		; Virtual-key code
	Pressed		BPBool ?	; Is the key pressed or released
BPInKey ENDS

BPInMouseButton STRUCT	; Mouse button input structure
	Button		BPPtr ?		; Mouse button (uses virtual-key constants)
	Pressed		BPBool ?	; Is the button pressed or released
BPInMouseButton ENDS

BPInMouseMove STRUCT	; Mouse movement input structure
	Position	POINT <?, ?>	; Absolute on-screen mouse cursor position
	Relative	POINT <?, ?>	; Relative mouse movement
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
	RawName		BYTE		32 dup (?)
BPJoystick ENDS

; ----- CONSTANTS -----
BP_ORIENTATION_LANDSCAPE		EQU 0
BP_ORIENTATION_PORTRAIT			EQU 1
BP_ORIENTATION_LANDSCAPE_REV	EQU 2
BP_ORIENTATION_PORTRAIT_REV		EQU 3

BP_FIXED_INTERVAL		EQU 1000 / 60	; OnFixed signal interval (ms)

;   BPForm.InputFlags bits for configuring input. Can be set before form
; creation. To correctly set them after the form has been created, call 
; bpSetInputFlags.
BP_IF_RAW_MOUSE	EQU 1	; Register and use raw mouse input instead of cursor
BP_IF_JOYSTICK	EQU 2	; Register and use joystick input (BP_INPUT_JOY_*)

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

; Joystick D-pad (returned in BP_INPUT_JOY_BUTTON)
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

; Form window mode constants (BPForm.WindowMode, bpSetWindowMode)
BP_WINDOW_MODE_WINDOWED			EQU 0	; Form is a draggable (sizeable) window
BP_WINDOW_MODE_MINIMIZED		EQU 1	; Form is minimized into tray
BP_WINDOW_MODE_MAXIMIZED		EQU 2	; Form is a maximized window
BP_WINDOW_MODE_FULLSCREEN		EQU 3	; Form is a 'fullscreen window'
BP_WINDOW_MODE_FULLSCREEN_EX	EQU 4	; Form uses exclusive fullscreen,
										; display resolution will be set to
										; BPForm.ScreenSize.

; Mouse wheel virtual-key codes (returned in BP_INPUT_MOUSE_BUTTON)
VK_MWHEEL_UP	EQU 7
VK_MWHEEL_DOWN	EQU 8

.CONST
bpDefCaption	DB "BP3D", 0		; Default window caption
bpDefClassMain	DB "BPFMain", 0		; Default window class name
bpJoyMaxValue	DWORD 1191182336	; Value to divide the joystick DW by (32768)

.DATA
bpDefHeap	HANDLE 0	; Default heap (to not GetProcessHeap every time)

;   Delta time calculation variables (QueryPerformanceCounter uses
; LARGE_INTEGER, but one 32-bit portion of it is enough)
IFDEF BP_USE_LARGE_INTEGER
	BPDelta TYPEDEF LARGE_INTEGER
	bpLastTick BPDelta <<0,0>>
	bpPerfFreq BPDelta <<0,0>>
ELSE
	BPDelta TYPEDEF DWORD
	bpLastTick BPDelta 0
	bpPerfFreq BPDelta 0
ENDIF

bpDisplayDeviceCount	DWORD 0
bpDisplayDevices		BPDisplayDevice 16 dup (<>)

; Set to TRUE after first frame, then allows OnRender execution
bpFirstFrameSkipped BPBool FALSE

bpFixedInterval REAL4 0.01666666	; BPForm OnFixed interval (in seconds)

bpJoyCount		DWORD 0					; Total amount of joysticks available
bpJoyInfoEx		JOYINFOEX 16 dup (<>)	; JOYINFOEX array for comparing states
bpJoysticks		BPJoystick 16 dup (<>)	; BPJoystick array to read info from
bpJoyThreshold	REAL4 0.06, 0.94		; Joystick axis threshold (min, max)

bpMouseClient 		SDWORD 0, 0	; Local mouse cursor position in the window
bpMouseClientPrev	SDWORD 0, 0	; Previous mouse cursor position (cursor input)
bpMouseScreen		SDWORD 0, 0	; On-screen global mouse cursor position
bpMouseScreenPrev	SDWORD 0, 0	; Previous global cursor position (cursor input)

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

bpCalculateDelta		PROTO :BPPtr, :BPPtr
bpCreateForm			PROTO :BPPtr
bpDestroyForm			PROTO :BPPtr
bpInitGLContext			PROTO :BPPtr
bpInJoyAxis				PROTO :BPPtr, :DWORD, :BPPtr, :REAL4
bpInJoyButton			PROTO :BPPtr, :DWORD, :BPPtr, :BOOL
bpInKey					PROTO :BPPtr, :WPARAM, :BOOL
bpInMouseButton			PROTO :BPPtr, :BPPtr, :BPBool
bpInRaw					PROTO :BPPtr, :LPARAM
bpReadJoysticks			PROTO :BPPtr
bpScreenToWindowSize	PROTO :BPPtr, :BPPtr
bpSetInputFlags			PROTO :BPPtr, :BYTE
bpSetMouseMode			PROTO :BPPtr, :BPEnum
bpSetScreenCenter		PROTO :BPPtr
bpSetWindowMode			PROTO :BPPtr, :BPEnum
bpSetWindowPos			PROTO :BPPtr, :SDWORD, :SDWORD
bpSetWindowSize			PROTO :BPPtr, :DWORD, :DWORD
bpUpdateJoysticks		PROTO
bpUpdateWindowPos		PROTO :BPPtr
bpDefFixedProc			PROTO :LPVOID
bpDefWndProc			PROTO :HWND, :UINT, :WPARAM, :LPARAM

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
	LOCAL tick:LARGE_INTEGER
	IFDEF BP_USE_LARGE_INTEGER
		LOCAL diff:LARGE_INTEGER
		
		invoke QueryPerformanceCounter, ADDR tick
		IFDEF rax
			mov rcx, LastTick
			ASSUME rcx:PTR LARGE_INTEGER
		
			.IF (![rcx].QuadPart)
				jmp bpCalculateDeltaSkip
			.ENDIF
			
			mov rax, tick.QuadPart
			sub rax, [rcx].QuadPart
			mov diff, rax
		ELSE
			push ebx
			mov eax, tick.LowPart
			mov edx, tick.HighPart
			mov ecx, LastTick
			ASSUME ecx:PTR LARGE_INTEGER
			mov ebx, [ecx].LowPart
			mov ecx, [ecx].HighPart
			sub eax, ebx
			sbb edx, ecx
			mov diff.LowPart, eax
			mov diff.HighPart, edx
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
		LOCAL diff:DWORD
		
		invoke QueryPerformanceCounter, ADDR tick
		
		mov ecx, LastTick
		.IF (!DWORD PTR [ecx])
			jmp bpCalculateDeltaSkip
		.ENDIF
		
		mov eax, tick.LowPart
		sub eax, DWORD PTR [ecx]
		mov diff, eax
	ENDIF
	
	bpCalculateDeltaProcess:
	ASSUME ecx:nothing
	
	IFDEF BP_USE_LARGE_INTEGER
		IFDEF rax
			fild diff.QuadPart
		ELSE
			fild QWORD PTR diff
		ENDIF
	ELSE
		fild diff
	ENDIF
	fild bpPerfFreq
	fdiv
	mov pax, DeltaPtr
	fstp REAL4 PTR [pax]
	
	bpCalculateDeltaSkip:
	IFDEF BP_USE_LARGE_INTEGER
		invoke RtlMoveMemory, LastTick, ADDR tick, SIZEOF LARGE_INTEGER
	ELSE
		mov pcx, LastTick
		m2m DWORD PTR [pcx], tick.LowPart
	ENDIF
	ret
bpCalculateDelta ENDP

;   Initialize form and create a window based on its parameters.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpCreateForm PROC EXPORT BPFormPtr:BPPtr
	LOCAL wc:WNDCLASSEX, msg:MSG, testFreq:LARGE_INTEGER, quitFlag:BPBool
	LOCAL ridMouse:RAWINPUTDEVICE, rect:RECT
	ASSUME pcx:PTR BPForm
	
	.IF (!bpDefHeap)
		mov bpDefHeap, rv(GetProcessHeap)
	.ENDIF
	
	mov wc.cbSize, SIZEOF WNDCLASSEX
	mov wc.style, CS_HREDRAW or CS_VREDRAW
	mov wc.cbClsExtra, NULL
	mov wc.cbWndExtra, NULL
	mov	wc.hbrBackground, COLOR_WINDOW
	mov wc.lpszMenuName, NULL
	
	mov pcx, BPFormPtr
	
	m2m wc.lpszClassName, [pcx].ClassName	; MSDN says it's a 32-bit pointer ?
	m2m wc.lpfnWndProc, [pcx].WndProc
	
	
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
	[pcx].WindowStyle, \
	[pcx].WindowPos.x,[pcx].WindowPos.y, [pcx].WindowSize.x,[pcx].WindowSize.y,\
	NULL, NULL, wc.hInstance, NULL
	
	mov pcx, BPFormPtr
	mov [pcx].Handle, pax
	invoke SetWindowLong, pax, GWLP_USERDATA, BPFormPtr
	
	; Get some system info
	IFDEF BP_USE_LARGE_INTEGER
		invoke QueryPerformanceFrequency, ADDR bpPerfFreq
	ELSE
		invoke QueryPerformanceFrequency, ADDR testFreq
		m2m bpPerfFreq, testFreq.LowPart
	ENDIF
	call bpUpdateDisplayDevices
	
	; Populate WindowPos, WindowSize
	mov pcx, BPFormPtr
	invoke GetWindowRect, [pcx].Handle, ADDR rect
	mov pcx, BPFormPtr
	mov eax, rect.left
	mov [pcx].WindowPos.x, eax
	sub rect.right, eax
	m2m [pcx].WindowSize.x, rect.right
	mov eax, rect.top
	mov [pcx].WindowPos.y, eax
	sub rect.bottom, eax
	m2m [pcx].WindowSize.y, rect.bottom
	
	; Populate ScreenPos, ScreenSize
	invoke GetClientRect, [pcx].Handle, ADDR rect
	mov pcx, BPFormPtr
	mov eax, rect.left
	mov [pcx].ScreenPos.x, eax
	sub rect.right, eax
	m2m [pcx].ScreenSize.x, rect.right
	mov eax, rect.top
	mov [pcx].ScreenPos.y, eax
	sub rect.bottom, eax
	m2m [pcx].ScreenSize.y, rect.bottom
	
	mov pcx, BPFormPtr
	mov [pcx].DefaultFlag, TRUE
	.IF ([pcx].OnCreate)
		call [pcx].OnCreate
	.ENDIF
	mov pcx, BPFormPtr
	.IF ([pcx].DefaultFlag)
		mov al, [pcx].InputFlags
		mov [pcx].InputFlags, 0
		invoke bpSetInputFlags, pcx, al
		
		mov pcx, BPFormPtr
		.IF ([pcx].WindowMode)
			invoke bpSetWindowMode, pcx, [pcx].WindowMode
		.ENDIF
	.ENDIF
	
	; OnFixed
	mov pcx, BPFormPtr
	.IF ([pcx].OnFixed)
		; BSD's Wine port doesn't like WinMM (Linux's does, skill issue).
		;invoke timeSetEvent, BP_FIXED_INTERVAL, 0, OFFSET bpDefFixedProc, \
		;BPFormPtr, TIME_PERIODIC
		invoke CreateThread, NULL, 0, OFFSET bpDefFixedProc, BPFormPtr, 0, NULL 
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
	mov pfd.cStencilBits, 1
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
;   Axis:BPPtr - axis number (correspondent to BP_JOY_AXIS_* constants).
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
				mov pos, 3212836864	; -1.0f
			.ELSE
				mov pos, 1065353216	; 1.0f
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
	
	m2m bpInStruct.Position.x, bpMouseClient[0]
	m2m bpInStruct.Position.y, bpMouseClient[4]
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	mov eax, bpMouseClient[0]
	sub eax, bpMouseClientPrev[0]
	mov bpInStruct.Relative.x, eax
	mov eax, bpMouseClient[4]
	sub eax, bpMouseClientPrev[4]
	mov bpInStruct.Relative.y, eax
	
	m2m bpMouseClientPrev[0], bpMouseClient[0]
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
;   RawHandle:LPARAM - handle to RAWINPUT structure (lParam in WM_INPUT).
bpInRaw PROC EXPORT BPFormPtr:BPPtr, RawHandle:LPARAM
	IFNDEF BP_COMPATIBILITY_W2K
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
				mov pcx, lpb
				movzx pax, [pcx].data.mouse.usButtonData
				.IF (pax)
					.IF (pax & RI_MOUSE_WHEEL)
						; Idk how to read this, just pray
						mov edx, [pcx].data.mouse.ulRawButtons
						push pcx
						push pax
						.IF (pdx == 78h)
							invoke bpInMouseButton, BPFormPtr, VK_MWHEEL_DOWN, \
							TRUE
						.ELSEIF (pdx == 0FF88h)
							invoke bpInMouseButton, BPFormPtr, VK_MWHEEL_UP, \
							TRUE
						.ENDIF
						pop pax
						push pcx
					.ELSEIF (pax & 800h)	; RI_MOUSE_HWHEEL
					
					.ENDIF
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
				
				mov pcx, lpb
				.IF ([pcx].data.mouse.usFlags & MOUSE_MOVE_ABSOLUTE)
					;TODO?
				.ELSE
					.IF !([pcx].data.mouse.lLastX) && !([pcx].data.mouse.lLastY)
						invoke bpFree, bpDefHeap, 0, lpb
						ret
					.ENDIF
					mov eax, [pcx].data.mouse.lLastX
					sar eax, 16
					mov bpInMouseMoveStruct.Relative.x, eax
					mov eax, [pcx].data.mouse.lLastY
					sar eax, 16
					mov bpInMouseMoveStruct.Relative.y, eax
				.ENDIF
				
				; Get global cursor coords
				invoke GetCursorPos, ADDR bpMouseScreen
				
				ASSUME pdx:PTR BPForm
				mov pdx, BPFormPtr
				
				mov eax, [pdx].ScreenCnt.x
				mov ecx, [pdx].ScreenCnt.y
				
				;   Wine implements (implemented?) "raw mouse" through cursor.
				; There was a very specific problem, where clicking on a
				; fullscreen (BP_WINDOW_MODE_FULLSCREEN) window would make
				; SetCursorPos send WM_INPUT events due to that implementation.
				
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
				
				mov pdx, BPFormPtr
				.IF (([pdx].MouseMode == BP_MOUSE_MODE_LOCKED) && [pdx].Focused)
					invoke SetCursorPos, [pdx].ScreenCnt.x, [pdx].ScreenCnt.y
				.ENDIF
				
				ASSUME pdx:nothing
			.ENDIF
		.ELSEIF ([pcx].header.dwType == RIM_TYPEHID)
			; WIP (touch is vendor-specific, HidP doesn't work with it)
		.ENDIF
		ASSUME pcx:nothing
	.ENDIF
	invoke bpFree, bpDefHeap, 0, lpb
	ENDIF
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

;   Converts screen (client area) position to the window position with proper 
; border and caption adjustments.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   PosPtr:BPPtr - pointer to the DWORD screen X and Y stored consecutively. 
; The resulting window position will be returned into this pointer.
bpScreenToWindowPos PROC EXPORT BPFormPtr:BPPtr, PosPtr:BPPtr
	LOCAL rect:RECT
	ASSUME pcx:PTR BPForm
	
	mov pax, PosPtr
	m2m rect.left,		DWORD PTR [pax]
	m2m rect.top,		DWORD PTR [pax+4]
	mov rect.right,		0
	mov rect.bottom,	0
	
	mov pcx, BPFormPtr
	invoke AdjustWindowRect, ADDR rect, [pcx].WindowStyle, 0
	mov pax, PosPtr
	m2m DWORD PTR [pax], 	rect.left
	m2m DWORD PTR [pax+4], 	rect.top
	
	ASSUME pcx:nothing
	ret
bpScreenToWindowPos ENDP

;   Converts screen (client area) size to the window size required to contain 
; that area, with proper border and caption adjustments.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   SizePtr:BPPtr - pointer to the DWORD screen width and height stored 
; consecutively. The resulting window size will be returned into this pointer.
bpScreenToWindowSize PROC EXPORT BPFormPtr:BPPtr, SizePtr:BPPtr
	LOCAL rect:RECT
	ASSUME pcx:PTR BPForm
	
	mov pax, SizePtr
	mov rect.top,		0
	mov rect.left,		0
	m2m rect.right,		DWORD PTR [pax]
	m2m rect.bottom,	DWORD PTR [pax+4]
	
	mov pcx, BPFormPtr
	invoke AdjustWindowRect, ADDR rect, [pcx].WindowStyle, 0
	mov ecx, rect.right
	sub ecx, rect.left
	mov pax, SizePtr
	mov DWORD PTR [pax], ecx
	mov ecx, rect.bottom
	sub ecx, rect.top
	mov DWORD PTR [pax+4], ecx
	
	ASSUME pcx:nothing
	ret
bpScreenToWindowSize ENDP

bpSetDisplayDevice PROC EXPORT BPFormPtr:BPPtr, DisplayDevice:DWORD
	LOCAL winMode:BPEnum
	
	ASSUME pcx:PTR BPForm
	
	mov pax, DisplayDevice
	mov pdx, SIZEOF BPDisplayDevice
	mul pdx
	mov pdx, pax
	
	.IF !(bpDisplayDevices[pdx].Active)
		ret
	.ENDIF
	
	mov pcx, BPFormPtr
	m2m [pcx].DisplayDevice, DisplayDevice
	
	
	mov pcx, BPFormPtr
	mov al, [pcx].WindowMode
	mov winMode, al
	push pdx
	; This horrid random bullshit is neccessary to make it work with Xorg
	invoke bpSetWindowMode, BPFormPtr, BP_WINDOW_MODE_WINDOWED
	invoke bpSetWindowMode, BPFormPtr, BP_WINDOW_MODE_MINIMIZED
	pop pdx
	
	mov pcx, BPFormPtr
	invoke bpSetWindowPos, pcx, \
	bpDisplayDevices[pdx].ScreenPos.x, bpDisplayDevices[pdx].ScreenPos.y
	
	mov pcx, BPFormPtr
	invoke ShowWindow, [pcx].Handle, SW_RESTORE
	invoke bpSetWindowMode, BPFormPtr, winMode
	
	ASSUME pcx:nothing
	ret
bpSetDisplayDevice ENDP

;   Update input configurations for a BPForm according to passed InputFlags and
; set the form's InputFlags to that. See possible input flags at BP_IF_*.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   InputFlags:BYTE - bitmask of input flags of BP_IF_*.
bpSetInputFlags PROC EXPORT BPFormPtr:BPPtr, InputFlags:BYTE
	LOCAL ridMouse:RAWINPUTDEVICE
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	IFNDEF BP_COMPATIBILITY_W2K
	; Raw mouse flag (no lag raw mouse input, useless on Wine)
	mov al, [pcx].InputFlags
	and al, BP_IF_RAW_MOUSE
	mov ah, InputFlags
	and ah, BP_IF_RAW_MOUSE
	.IF (al) != (ah)
		mov ridMouse.usUsagePage, 1		; Generic desktop
		mov ridMouse.usUsage, 2			; Mouse
		m2m ridMouse.hwndTarget, [pcx].Handle
		.IF (ah)
			mov ridMouse.dwFlags, RIDEV_INPUTSINK
		.ELSE
			mov ridMouse.dwFlags, RIDEV_REMOVE
		.ENDIF
		invoke RegisterRawInputDevices, ADDR ridMouse, 1, \
		SIZEOF RAWINPUTDEVICE
		mov pcx, BPFormPtr
	.ENDIF
	ENDIF
	
	mov al, [pcx].InputFlags
	and al, BP_IF_JOYSTICK
	mov ah, InputFlags
	and ah, BP_IF_JOYSTICK
	.IF (al) != (ah)
		.IF (ah)
			call bpUpdateJoysticks
			mov pcx, BPFormPtr
		.ENDIF
	.ENDIF
	
	mov al, InputFlags
	mov [pcx].InputFlags, al
	ASSUME pcx:nothing
	ret
bpSetInputFlags ENDP

;   Sets form's mouse mode.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   MouseMode:BPEnum - mouse mode, represented as a BPMSMODE constant.
bpSetMouseMode PROC EXPORT BPFormPtr:BPPtr, MouseMode:BPEnum
	LOCAL curInfo:CURSORINFO
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	mov al, MouseMode
	mov [pcx].MouseMode, al
	
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
		.IF (MouseMode == BP_MOUSE_MODE_LOCKED)
			mov pcx, BPFormPtr
			invoke SetCursorPos, [pcx].ScreenCnt.x, [pcx].ScreenCnt.y
		.ENDIF
	.ENDIF
	ASSUME pcx:nothing
	ret
bpSetMouseMode ENDP

;   Sets form's current display's resolution to specified values in a DWORD[2] 
; pointer, or to the closest available resolution. Returns TRUE, if the exact 
; resolution was set, FALSE if the closest available had to be picked.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   ResPtr:BPPtr - pointer to the new DWORD width and height values stored 
; consecutively. If these exact values cannot be used, the closest available
; resolution will be picked and the width and height will be returned into this
; pointer.
;   CmpAspect:BPBool - compare aspect when picking best available resolution.
bpSetResolution PROC EXPORT BPFormPtr:BPPtr, ResPtr:BPPtr, CmpAspect:BPBool
	LOCAL devMode:DEVMODEA, namePtr:BPPtr
	LOCAL sizeDiff[2]:DWORD, aspect:REAL4, aspectDiff:DWORD, bestScore:DWORD
	LOCAL found:BPBool, best:DEVMODEA
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	mov pax, [pcx].DisplayDevice
	mov pcx, SIZEOF BPDisplayDevice
	mul pcx
	lea pax, bpDisplayDevices[pax].RawName
	mov namePtr, pax
	ASSUME pcx:nothing
	
	
	mov devMode.dmSize, SIZEOF DEVMODEA
	invoke EnumDisplaySettingsA, namePtr, ENUM_CURRENT_SETTINGS, ADDR devMode
	mov pax, ResPtr
	m2m devMode.dmPelsWidth, DWORD PTR [pax]
	m2m devMode.dmPelsHeight, DWORD PTR [pax+4]
	
	
	invoke ChangeDisplaySettingsExA, namePtr, ADDR devMode, NULL, \
	CDS_FULLSCREEN, NULL
	.IF (eax != DISP_CHANGE_SUCCESSFUL)
		; Change unsuccessfull, pick closest best resolution
		.IF (CmpAspect)	; Get desired aspect
			mov pax, ResPtr
			fild DWORD PTR [pax]
			fidiv DWORD PTR [pax+4]
			fstp aspect
		.ENDIF
		
		mov found, FALSE
		
		push pbx
		xor ebx, ebx
		bpSetResolutionEnum:
		invoke EnumDisplaySettingsA, namePtr, ebx, ADDR devMode
		.IF (eax)
			; Resolution difference
			mov pcx, ResPtr
			mov eax, devMode.dmPelsWidth
			sub eax, DWORD PTR [pcx]
			.IF (SDWORD PTR eax < 0)
				neg eax
			.ENDIF
			mov sizeDiff[0], eax
			mov eax, devMode.dmPelsHeight
			sub eax, DWORD PTR [pcx+4]
			.IF (SDWORD PTR eax < 0)
				neg eax
			.ENDIF
			mov sizeDiff[4], eax
			
			.IF (CmpAspect)
				fild devMode.dmPelsWidth
				fidiv devMode.dmPelsHeight
				fsub aspect
				fabs
				push 1000
				fimul BPPtr PTR [psp]
				pop eax
				fistp aspectDiff
			
				mov eax, aspectDiff
				add eax, sizeDiff[0]
			.ELSE
				mov eax, sizeDiff[0]
			.ENDIF
			add eax, sizeDiff[4]
			
			.IF (!found || eax < bestScore)
				mov bestScore, eax
				invoke RtlMoveMemory, ADDR best, ADDR devMode, SIZEOF DEVMODEA
				mov found, TRUE
			.ENDIF
			
			inc ebx
			jmp bpSetResolutionEnum
		.ENDIF
		pop pbx
		
		mov pax, ResPtr
		m2m DWORD PTR [pax], best.dmPelsWidth
		m2m DWORD PTR [pax+4], best.dmPelsHeight
		invoke ChangeDisplaySettingsExA, namePtr, ADDR best, NULL, \
		CDS_FULLSCREEN, NULL
		
		;print namePtr, 13, 10
		mov pax, FALSE
		ret
	.ENDIF
	mov pax, TRUE
	ret
bpSetResolution ENDP

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

;   Sets screen size (window client area) of a form to specified value. Calls
; bpSetWindowSize with adjusted size.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   X:DWORD - new screen width.
;   Y:DWORD - new screen height.
bpSetScreenSize PROC EXPORT BPFormPtr:BPPtr, X:DWORD, Y:DWORD	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	.IF ([pcx].WindowMode != BP_WINDOW_MODE_FULLSCREEN) && \
	([pcx].WindowMode != BP_WINDOW_MODE_FULLSCREEN_EX)
		invoke bpScreenToWindowSize, BPFormPtr, ADDR X
	.ENDIF
	invoke bpSetWindowSize, BPFormPtr, X, Y
	mov pcx, BPFormPtr
	.IF ([pcx].WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
		invoke bpSetWindowMode, pcx, BP_WINDOW_MODE_FULLSCREEN_EX
	.ENDIF
	ASSUME pcx:nothing
	ret
bpSetScreenSize ENDP

;   Set form size and mode to fullscreen or windowed.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   WindowMode:BPEnum - window mode, represented as a BPWINMODE constant.
bpSetWindowMode PROC EXPORT BPFormPtr:BPPtr, WindowMode:BPEnum
	LOCAL scrSize:POINT
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	.IF ([pcx].WindowMode == BP_WINDOW_MODE_FULLSCREEN)
		; Dubiously necessary
		; I stole the modes from Godot but didn't even check how they work smh
		.IF (WindowMode != BP_WINDOW_MODE_WINDOWED)
			invoke bpSetWindowMode, pcx, BP_WINDOW_MODE_WINDOWED
			mov pcx, BPFormPtr
		.ENDIF
	.ELSEIF ([pcx].WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, [pcx].WindowStyle
		invoke ChangeDisplaySettingsA, NULL, 0
		; the proper? way to change back would be:
		;mov pcx, BPFormPtr
		;mov pax, [pcx].DisplayDevice
		;mov pcx, SIZEOF BPDisplayDevice
		;mul pcx
		;lea pax, bpDisplayDevices[pax].ScreenSize
		;invoke bpSetResolution, BPFormPtr, pax, FALSE
		mov pcx, BPFormPtr
	.ENDIF
	
	mov al, WindowMode
	mov [pcx].WindowMode, al
	
	.IF (WindowMode == BP_WINDOW_MODE_WINDOWED)
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, [pcx].WindowStyle
		mov pcx, BPFormPtr
		invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, [pcx].WindowPos.x, \
		[pcx].WindowPos.y, [pcx].WindowSize.x, [pcx].WindowSize.y, \
		SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
		mov pcx, BPFormPtr
		invoke ShowWindow, [pcx].Handle, SW_RESTORE
	.ELSEIF (WindowMode == BP_WINDOW_MODE_MINIMIZED)
		invoke ShowWindow, [pcx].Handle, SW_MINIMIZE
	.ELSEIF (WindowMode == BP_WINDOW_MODE_MAXIMIZED)
		invoke ShowWindow, [pcx].Handle, SW_MAXIMIZE
	.ELSEIF (WindowMode == BP_WINDOW_MODE_FULLSCREEN) || \
	(WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
		.IF ([pcx].WindowMode != BP_WINDOW_MODE_MAXIMIZED)
			invoke bpUpdateWindowPos, BPFormPtr	; pcx still is BPFormPtr
		.ENDIF
		
		.IF (WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
			invoke bpSetResolution, BPFormPtr, ADDR [pcx].ScreenSize, FALSE
			mov pcx, BPFormPtr
		.ENDIF
	
		m2m scrSize.x, [pcx].ScreenSize.x
		m2m scrSize.y, [pcx].ScreenSize.y
		; This here sends a WM_SIZE with weird additions
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, WS_POPUP
		
		mov pcx, BPFormPtr
		mov pax, [pcx].DisplayDevice
		mov pdx, SIZEOF BPDisplayDevice
		mul pdx
		
		.IF (WindowMode == BP_WINDOW_MODE_FULLSCREEN)
			m2m scrSize.x, bpDisplayDevices[pax].ScreenSize.x
			m2m scrSize.y, bpDisplayDevices[pax].ScreenSize.y
		.ENDIF
		
		invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, \
		bpDisplayDevices[pax].ScreenPos.x, bpDisplayDevices[pax].ScreenPos.y, \
		scrSize.x, scrSize.y, SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
	.ENDIF
	
	mov pcx, BPFormPtr
	invoke UpdateWindow, [pcx].Handle
	
	ASSUME pcx:nothing
	ret
bpSetWindowMode ENDP

bpSetWindowPos PROC EXPORT BPFormPtr:BPPtr, X:SDWORD, Y:SDWORD
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	m2m [pcx].WindowPos.x, X
	m2m [pcx].WindowPos.y, Y
	
	mov pcx, BPFormPtr
	invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, X, Y, 0, 0, \
	SWP_NOSIZE or SWP_NOZORDER or SWP_SHOWWINDOW
	
	ASSUME pcx:nothing
	ret
bpSetWindowPos ENDP

;   Sets window size (unadjusted for client) of a form to specified value.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   X:DWORD - new screen width.
;   Y:DWORD - new screen height.
bpSetWindowSize PROC EXPORT BPFormPtr:BPPtr, X:DWORD, Y:DWORD
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	m2m [pcx].WindowSize.x, X
	m2m [pcx].WindowSize.y, Y
	
	mov pcx, BPFormPtr
	; Just don't call this asshole in OnCreate
	invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, 0, 0, X, Y, \
	SWP_NOMOVE or SWP_NOZORDER or SWP_SHOWWINDOW
	
	ASSUME pcx:nothing
	ret
bpSetWindowSize ENDP

;   Update bpDisplayDevices.
bpUpdateDisplayDevices PROC EXPORT
	LOCAL devMode:DEVMODEA, dispDev:DISPLAY_DEVICEA
	
	mov bpDisplayDeviceCount, 0
	mov devMode.dmSize, SIZEOF DEVMODEA
	mov dispDev.cb, SIZEOF DISPLAY_DEVICEA
	
	bpUpdateDisplayDevicesEnum:
	invoke EnumDisplayDevicesA, NULL, bpDisplayDeviceCount, ADDR dispDev, \
	EDD_GET_DEVICE_INTERFACE_NAME 
	.IF (al)
		.IF (dispDev.StateFlags & DISPLAY_DEVICE_ACTIVE)
			invoke EnumDisplaySettingsA, ADDR dispDev.DeviceName, \
			ENUM_REGISTRY_SETTINGS, ADDR devMode
			
			mov pax, bpDisplayDeviceCount
			mov pcx, SIZEOF BPDisplayDevice
			mul pcx
			mov bpDisplayDevices[pax].Active, TRUE
			
			; Need a portrait-default monitor to test this, but should be ok
			mov ecx, devMode.dmPelsWidth
			.IF (ecx > devMode.dmPelsHeight)
				mov bpDisplayDevices[pax].Orientation, BP_ORIENTATION_LANDSCAPE
			.ELSE
				mov bpDisplayDevices[pax].Orientation, BP_ORIENTATION_PORTRAIT
			.ENDIF
			.IF (devMode.dmDisplayOrientation == DMDO_180)
				add bpDisplayDevices[pax].Orientation, 2
			.ENDIF
			
			m2m bpDisplayDevices[pax].RefreshRate, devMode.dmDisplayFrequency
			m2m bpDisplayDevices[pax].ScreenPos.x, devMode.dmPosition.x
			m2m bpDisplayDevices[pax].ScreenPos.y, devMode.dmPosition.y
			m2m bpDisplayDevices[pax].ScreenSize.x, devMode.dmPelsWidth
			m2m bpDisplayDevices[pax].ScreenSize.y, devMode.dmPelsHeight
			lea pcx, bpDisplayDevices[pax].RawName
			invoke RtlMoveMemory, pcx, ADDR dispDev.DeviceName, 32
		.ELSE
			mov pax, bpDisplayDeviceCount
			mov pcx, SIZEOF BPDisplayDevice
			mul pcx
			mov bpDisplayDevices[pax].Active, FALSE
		.ENDIF
		inc bpDisplayDeviceCount
		jmp bpUpdateDisplayDevicesEnum
	.ENDIF
	ret
bpUpdateDisplayDevices ENDP

;   Update bpJoysticks (and respective bpJoyInfoEx) to then capture their input.
bpUpdateJoysticks PROC EXPORT
	LOCAL joyInfo:JOYINFOFIX, joyCaps:JOYCAPSAFIX
	
	mov bpJoyCount, rv(joyGetNumDevs)
	
	push pbx
	xor pbx, pbx
	.WHILE (pbx < bpJoyCount)
		invoke joyGetPos, pbx, ADDR joyInfo
		.IF (pax == JOYERR_NOERROR)
			invoke joyGetDevCapsA, pbx, ADDR joyCaps, SIZEOF JOYCAPSAFIX
			
			mov pax, pbx
			mov pcx, SIZEOF BPJoystick
			mul pcx
			mov bpJoysticks[pax].Active, TRUE
			m2m bpJoysticks[pax].VendorId, joyCaps.wMid
			m2m bpJoysticks[pax].ProductId, joyCaps.wPid
			m2m bpJoysticks[pax].NumAxes, joyCaps.wNumAxes
			m2m bpJoysticks[pax].NumButtons, joyCaps.wNumButtons
			invoke RtlMoveMemory, ADDR bpJoysticks[pax].RawName, \
			ADDR joyCaps.szPname, 32
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
bpUpdateWindowPos PROC EXPORT BPFormPtr:BPPtr
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
bpDefFixedProc PROC EXPORT lpParameter:LPVOID
	LOCAL threadTimer:REAL4, lastTick:BPDelta, deltaFixed:REAL4
	
	ASSUME pcx:PTR BPForm
	mov threadTimer, 0
	.WHILE (TRUE)
		invoke bpCalculateDelta, ADDR lastTick, ADDR deltaFixed
		
		fld threadTimer
		fadd deltaFixed
		fld bpFixedInterval
		
		fcom
		fstsw ax
		bt ax, 8
		.IF (Carry?)
			fsub
			fstp threadTimer
			mov pcx, lpParameter
			call [pcx].OnFixed
		.ELSE
			fstp st
			fstp threadTimer
		.ENDIF
	.ENDW
	ASSUME pcx:nothing
	ret
bpDefFixedProc ENDP

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
			.IF ([pcx].InputFlags & BP_IF_JOYSTICK)
				.IF (wParam == 7)	; DBT_DEVNODES_CHANGED
					call bpUpdateDisplayDevices
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
			mov [pcx].Focused, FALSE
		CASE WM_SETFOCUS
			mov [pcx].Focused, TRUE
			
		CASE WM_MOVE
			.IF ([pcx].WindowMode == BP_WINDOW_MODE_WINDOWED)
				invoke bpUpdateWindowPos, dwRefData
			.ENDIF
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
			.IF !([pcx].InputFlags & BP_IF_RAW_MOUSE) && ([pcx].Focused)
				.IF ([pcx].OnInput)
					invoke GetCursorPos, ADDR bpMouseScreen
					mov eax, bpMouseScreenPrev[0]
					mov edx, bpMouseScreenPrev[4]
					.IF (bpMouseScreen[0] != eax) || (bpMouseScreen[4] != edx)
						m2m bpMouseClient[0], bpMouseScreen[0]
						m2m bpMouseClient[4], bpMouseScreen[4]
						mov pcx, dwRefData
						invoke ScreenToClient, [pcx].Handle, ADDR bpMouseClient
						
						invoke bpInMouseMove, dwRefData
					.ENDIF
					mov pcx, dwRefData
				.ENDIF
				.IF ([pcx].MouseMode == BP_MOUSE_MODE_LOCKED)
					invoke SetCursorPos, [pcx].ScreenCnt.x, [pcx].ScreenCnt.y
					mov pcx, dwRefData
					m2m bpMouseScreenPrev[0], [pcx].ScreenCnt.x
					m2m bpMouseScreenPrev[4], [pcx].ScreenCnt.y
					m2m bpMouseClientPrev[0], [pcx].ScreenCnt.x
					m2m bpMouseClientPrev[4], [pcx].ScreenCnt.y
					invoke ScreenToClient, [pcx].Handle, ADDR bpMouseClientPrev
					mov pcx, dwRefData
				.ELSE
					m2m bpMouseScreenPrev[0], bpMouseScreen[0]
					m2m bpMouseScreenPrev[4], bpMouseScreen[4]
				.ENDIF
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
				.IF ([pcx].OnStart)
					call [pcx].OnStart
				.ENDIF
			.ENDIF
			
			mov pcx, dwRefData
			.IF ([pcx].DefaultFlag)
				mov [pcx].DefaultFlag, FALSE
				invoke SwapBuffers, [pcx].DeviceContext
				invoke bpReadJoysticks, dwRefData
			.ENDIF
			
		CASE WM_SIZE
			.IF ([pcx].WindowMode != BP_WINDOW_MODE_FULLSCREEN) && \
			([pcx].WindowMode != BP_WINDOW_MODE_FULLSCREEN_EX)
				SWITCH wParam
					CASE SIZE_RESTORED
						mov [pcx].WindowMode, BP_WINDOW_MODE_WINDOWED
					CASE SIZE_MINIMIZED
						mov [pcx].WindowMode, BP_WINDOW_MODE_MINIMIZED
					CASE SIZE_MAXIMIZED
						mov [pcx].WindowMode, BP_WINDOW_MODE_MAXIMIZED
				ENDSW
			.ELSEIF ([pcx].WindowMode == BP_WINDOW_MODE_WINDOWED)
				invoke bpUpdateWindowPos, dwRefData
			.ENDIF
			
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
				.IF ([pcx].GLContext)
					invoke glViewport, 0, 0, [pcx].ScreenSize.x, [pcx].ScreenSize.y
				.ENDIF
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
			
			
		; This down here is rancid but compatibility I guess
		CASE WM_LBUTTONDOWN
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_LBUTTON, TRUE
			.ENDIF
		CASE WM_LBUTTONUP
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_LBUTTON, FALSE
			.ENDIF
		CASE WM_RBUTTONDOWN
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_RBUTTON, TRUE
			.ENDIF
		CASE WM_RBUTTONUP
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_RBUTTON, FALSE
			.ENDIF
		CASE WM_MBUTTONDOWN
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_MBUTTON, TRUE
			.ENDIF
		CASE WM_MBUTTONUP
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
				invoke bpInMouseButton, dwRefData, VK_MBUTTON, FALSE
			.ENDIF
		CASE WM_XBUTTONDOWN
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
				mov eax, wParam
				shr eax, 16
				movsx eax, ax
				add eax, 4
				invoke bpInMouseButton, dwRefData, eax, TRUE
			.ENDIF
		CASE WM_XBUTTONUP
			.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
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
