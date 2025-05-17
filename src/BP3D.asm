; -----	MASM32 INCLUDES -----
include include\windows.inc

include include\advapi32.inc
includelib advapi32.lib
include include\comctl32.inc
includelib comctl32.lib
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

BP3D_CLAMP_INTERPOLATION	EQU <1>
BP3D_FIXED_INTERVAL			EQU 1000 / 60
IFDEF BP3D_TRACEABLE_MALLOC
	bpFree		TEXTEQU <bpFreeProc>
	bpMalloc	TEXTEQU <bpMallocProc>
	bpRealloc	TEXTEQU <bpReallocProc>
ELSE
	bpFree		TEXTEQU <HeapFree>
	bpMalloc	TEXTEQU <HeapAlloc>
	bpRealloc	TEXTEQU <HeapReAlloc>
ENDIF

; ----- CONSTANTS -----
BPIN_JOYAXIS		EQU 0
BPIN_JOYBUTTON		EQU 1
BPIN_KEY			EQU 2
BPIN_MOUSEMOVE		EQU 3
BPIN_MOUSEBUTTON	EQU 4
BPIN_TOUCH			EQU 5

BPMSMODE_VISIBLE	EQU 0
BPMSMODE_HIDDEN		EQU 1
BPMSMODE_LOCKED		EQU 2

BPWINMODE_WINDOWED		EQU 0
BPWINMODE_MINIMIZED		EQU 1
BPWINMODE_MAXIMIZED		EQU 2
BPWINMODE_FULLSCREEN	EQU 3
BPWINMODE_FULLSCREEN_EX	EQU 4

; ----- TYPES -----
RAWINPUTHEADER  struct 
	dwType      DWORD   ?
	dwSize      DWORD   ?
	hDevice     HANDLE  ?
	wParam      WPARAM  ?
RAWINPUTHEADER  ends
PRAWINPUTHEADER typedef ptr RAWINPUTHEADER

RAWMOUSE struct 
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
RAWMOUSE ends
PRAWMOUSE typedef ptr RAWMOUSE

RAWKEYBOARD struct 
	MakeCode            WORD    ?
	Flags               WORD    ?
	Reserved            WORD    ?
	VKey                WORD    ?
	Message             DWORD   ?
	ExtraInformation    DWORD   ?
RAWKEYBOARD ends
PRAWKEYBOARD typedef ptr RAWKEYBOARD

RAWHID struct 
	dwSizeHid           DWORD ?
	dwCount             DWORD ?
	bRawData            BYTE 1 dup (?)
RAWHID ends
PRAWHID typedef ptr RAWHID

RAWINPUT struct 
	header  RAWINPUTHEADER <>
	union data
		mouse           RAWMOUSE    <>
		keyboard        RAWKEYBOARD <>
		hid             RAWHID      <>
	ends
RAWINPUT ends

IFDEF rax
	ECHO BP3D: Compiling in 64-bit mode.
	BPPtr TYPEDEF QWORD
	BPSPtr TYPEDEF SQWORD
	BPPtrWord TYPEDEF QWORD
	BPPtrInt TYPEDEF SQWORD
	pax EQU rax
	pbx EQU rbx
	pcx EQU rcx
	pdx EQU rdx
ELSE
	ECHO BP3D: Compiling in 32-bit mode.
	BPPtr TYPEDEF DWORD
	BPSPtr TYPEDEF SDWORD
	BPPtrWord TYPEDEF DWORD
	BPPtrInt TYPEDEF SDWORD
	pax EQU eax
	pbx EQU ebx
	pcx EQU ecx
	pdx EQU edx
ENDIF

BPBool TYPEDEF BYTE
BPEnum TYPEDEF BYTE
	
BPForm STRUCT
	Caption BPPtr 0
	ClassName BPPtr 0
	DeviceContext HDC 0
	GLContext HANDLE 0
	Handle HWND 0
	WndProc BPPtr 0
	ScreenPos POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	ScreenSize POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	
	; Read-only fields
	Aspect REAL4 0.0
	Focused BPBool TRUE
	MouseMode BPEnum BPMSMODE_VISIBLE
	WindowMode BPEnum BPWINMODE_WINDOWED
	ScreenCnt POINT <0, 0>
	WindowPos POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	WindowSize POINT <CW_USEDEFAULT, CW_USEDEFAULT>
	
	; OnCreate PROC
	OnCreate BPPtr 0
	; OnDestroy PROC
	OnDestroy BPPtr 0
	; OnFixed PROC
	OnFixed BPPtr 0
	; OnInput PROC BPInType:BPEnum, BPInStruct:BPPtr
	OnInput BPPtr 0
	; OnRender PROC
	OnRender BPPtr 0
	; OnResize PROC
	OnResize BPPtr 0
BPForm ENDS

BPInKey STRUCT
	Keycode BPPtr ?
	Pressed BPBool ?
BPInKey ENDS

BPInMouseButton STRUCT
	Button BPPtr ?
	Pressed BPBool ?
BPInMouseButton ENDS

BPInMouseMove STRUCT
	Position POINT <?, ?>
	Relative POINT <?, ?>
BPInMouseMove ENDS

.CONST
bpDefCaption DB "BP3D", 0
bpDefClassMain DB "BPFMain", 0

.DATA
bpDefaultFlag BPBool FALSE
bpFirstFrameSkipped BPBool FALSE
IFDEF BP3D_USELARGEINTEGER
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
bpMouseClient SDWORD 0, 0
bpMouseScreen SDWORD 0, 0

deltaTime 		REAL4	0.0
deltaScale 		REAL4	1.0
deltaUnscaled 	REAL4	0.0

heapAllocated	DWORD	0

timeStart		REAL4	0.0

; ----- IMPLEMENTATION -----
.CODE

bpInitContext PROTO :HWND
bpInMouseButton PROTO :BPPtr, :BPPtr, :BPBool
bpSetScreenCenter PROTO :BPPtr
bpDefTimeProc PROTO :UINT, :UINT, :DWORD, :DWORD, :DWORD
bpDefWndProc PROTO :HWND, :UINT, :WPARAM, :LPARAM
bpMallocProc PROTO :HANDLE, :DWORD, :DWORD

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

;   Calculate deltaTime. Done automatically in the message loop in bpCreateForm,
; if bpDefaultFlag is TRUE (after OnRender callback).
bpCalculateDelta PROC LastTick:BPPtr, DeltaPtr:BPPtr
	IFDEF BP3D_USELARGEINTEGER
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
	IFDEF BP3D_USELARGEINTEGER
		bpm2m64 LARGE_INTEGER PTR [pcx], bpTick
	ELSE
		m2m DWORD PTR [pcx], bpTick
	ENDIF
	ret
bpCalculateDelta ENDP

;   Initialize form and createa window based on its parameters.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpCreateForm PROC BPFormPtr:BPPtr
	LOCAL wc:WNDCLASSEX, msg:MSG, testFreq:LARGE_INTEGER, quitFlag:BPBool
	LOCAL rid:RAWINPUTDEVICE 
	ASSUME pcx:PTR BPForm
	
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
	
	IFDEF BP3D_USELARGEINTEGER
		invoke QueryPerformanceFrequency, ADDR bpPerfFreq
	ELSE
		invoke QueryPerformanceFrequency, ADDR testFreq
		m2m bpPerfFreq, testFreq.LowPart
	ENDIF
	
	mov bpDefaultFlag, TRUE
	mov pcx, BPFormPtr
	.IF ([pcx].OnCreate)
		call [pcx].OnCreate
	.ENDIF
	.IF (bpDefaultFlag)
		; Register raw mouse input (for best mouse control with lag and vsync)
		mov rid.usUsagePage, 01h	; Generic desktop
		mov rid.usUsage, 02h		; Mouse
		mov rid.dwFlags, RIDEV_INPUTSINK
		mov pcx, BPFormPtr
		m2m rid.hwndTarget, [pcx].Handle
		
		invoke RegisterRawInputDevices, ADDR rid, 1, SIZEOF RAWINPUTDEVICE
	.ENDIF
	
	; OnFixed
	mov pcx, BPFormPtr
	.IF ([pcx].OnFixed)
		;invoke SetTimer, [pcx].Handle, IDT_MOUSETRAP, BP3D_FIXED_INTERVAL, \
		;NULL	THIS FUCKING COCKSUCKER NEVER WORKED I FUCKING HATE IT
		invoke timeSetEvent, BP3D_FIXED_INTERVAL, 0, OFFSET bpDefTimeProc, \
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
	
	invoke GetCurrentProcess
	invoke TerminateProcess, pax, 0
	ret
bpCreateForm ENDP

bpFreeProc PROC hHeap:HANDLE, dwFlags:DWORD, lpMem:LPVOID
	invoke HeapSize, hHeap, dwFlags, lpMem
	sub heapAllocated, eax
	invoke HeapFree, hHeap, dwFlags, lpMem
	ret
bpFreeProc ENDP

;   Initialize OpenGL context in an existing form.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpInitGLContext PROC BPFormPtr:BPPtr
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

;   Send keyboard input to form OnInput event as a struct.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   Keycode:WPARAM - virtual-key code of the keyboard button.
;   Pressed:BOOL - if the key has been pressed or released.
bpInKey PROC BPFormPtr:BPPtr, Keycode:WPARAM, Pressed:BOOL
	LOCAL bpInStruct:BPInKey
	
	m2m bpInStruct.Keycode, Keycode
	mov eax, Pressed
	mov bpInStruct.Pressed, al
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	lea pax, bpInStruct
	push pax
	push BPIN_KEY
	call [pcx].OnInput
	
	ASSUME pcx:nothing
	ret
bpInKey ENDP

;   Send mouse input to form OnInput event as a struct.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpInMouse PROC BPFormPtr:BPPtr, lParam:LPARAM
	LOCAL bpInStruct:BPInMouseMove, dwSize:DWORD, lpb:BPPtr
	
	invoke GetRawInputData, lParam, RID_INPUT, NULL, ADDR dwSize, \
	SIZEOF RAWINPUTHEADER
	invoke bpMalloc, rv(GetProcessHeap), 0, dwSize
	mov lpb, pax
	
	invoke GetRawInputData, lParam, RID_INPUT, lpb, ADDR dwSize, \
	SIZEOF RAWINPUTHEADER
	
	.IF (pax == dwSize)
		mov pcx, lpb
		ASSUME pcx:PTR RAWINPUT
		.IF ([pcx].header.dwType != RIM_TYPEMOUSE)
			; This should always fail because we set to capture only raw mouse
			invoke bpFree, rv(GetProcessHeap), 0, lpb
			ret
		.ENDIF
		;.IF ([pcx].data.mouse.usFlags & MOUSE_MOVE_ABSOLUTE)
			;TODO?
		;.ELSE
			mov eax, [pcx].data.mouse.lLastX
			mov ecx, 65536
			cdq
			idiv ecx
			mov bpInStruct.Relative.x, eax
			mov pcx, lpb
			mov eax, [pcx].data.mouse.lLastY
			mov ecx, 65536
			cdq
			idiv ecx
			mov bpInStruct.Relative.y, eax
		;.ENDIF
		
		mov pcx, lpb
		xor pax, pax
		mov ax, [pcx].data.mouse.usButtonData
		.IF (ax)
			SWITCH pax
				CASE RI_MOUSE_BUTTON_1_DOWN
					invoke bpInMouseButton, BPFormPtr, VK_LBUTTON, TRUE
				CASE RI_MOUSE_BUTTON_1_UP
					invoke bpInMouseButton, BPFormPtr, VK_LBUTTON, FALSE
				CASE RI_MOUSE_BUTTON_2_DOWN
					invoke bpInMouseButton, BPFormPtr, VK_RBUTTON, TRUE
				CASE RI_MOUSE_BUTTON_2_UP
					invoke bpInMouseButton, BPFormPtr, VK_RBUTTON, FALSE
				CASE RI_MOUSE_BUTTON_3_DOWN
					invoke bpInMouseButton, BPFormPtr, VK_MBUTTON, TRUE
				CASE RI_MOUSE_BUTTON_3_UP
					invoke bpInMouseButton, BPFormPtr, VK_MBUTTON, FALSE
				CASE RI_MOUSE_BUTTON_4_DOWN
					invoke bpInMouseButton, BPFormPtr, VK_XBUTTON1, TRUE
				CASE RI_MOUSE_BUTTON_4_UP
					invoke bpInMouseButton, BPFormPtr, VK_XBUTTON1, FALSE
				CASE RI_MOUSE_BUTTON_5_DOWN
					invoke bpInMouseButton, BPFormPtr, VK_XBUTTON2, TRUE
				CASE RI_MOUSE_BUTTON_5_UP
					invoke bpInMouseButton, BPFormPtr, VK_XBUTTON2, FALSE
			ENDSW
		.ENDIF
		ASSUME pcx:nothing
	.ENDIF
	invoke bpFree, rv(GetProcessHeap), 0, lpb
	
	; Get global cursor coords
	invoke GetCursorPos, ADDR bpMouseScreen
	m2m bpInStruct.Position.x, bpMouseScreen
	m2m bpInStruct.Position.y, bpMouseScreen[4]
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	m2m bpMouseClient[0], bpMouseScreen[0]
	m2m bpMouseClient[4], bpMouseScreen[4]
	invoke ScreenToClient, [pcx].Handle, ADDR bpMouseClient
	
	mov pcx, BPFormPtr
	lea pax, bpInStruct
	push pax
	push BPIN_MOUSEMOVE
	call [pcx].OnInput
	
	ASSUME pcx:nothing
	ret
bpInMouse ENDP

bpInMouseButton PROC BPFormPtr:BPPtr, Button:BPPtr, Pressed:BPBool
	LOCAL bpInStruct:BPInMouseButton
	
	m2m bpInStruct.Button, Button
	mov al, Pressed
	mov bpInStruct.Pressed, al
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	lea pax, bpInStruct
	push pax
	push BPIN_MOUSEBUTTON
	call [pcx].OnInput
	
	ASSUME pcx:nothing
	ret
bpInMouseButton ENDP

bpMallocProc PROC hHeap:HANDLE, dwFlags:DWORD, dwBytes:DWORD
	mov eax, dwBytes
	add heapAllocated, eax
	invoke HeapAlloc, hHeap, dwFlags, dwBytes
	ret
bpMallocProc ENDP

bpReallocProc PROC hHeap:HANDLE, dwFlags:DWORD, lpMem:LPVOID, dwBytes:DWORD
	invoke HeapSize, hHeap, dwFlags, lpMem
	sub heapAllocated, eax
	mov eax, dwBytes
	add heapAllocated, eax
	invoke HeapReAlloc, hHeap, dwFlags, lpMem, dwBytes
	ret
bpReallocProc ENDP

;   Sets form's mouse mode.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   MouseMode:BPEnum - mouse mode, represented as a BPMSMODE constant.
bpSetMouseMode PROC BPFormPtr:BPPtr, MouseMode:BPEnum
	LOCAL curInfo:CURSORINFO
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	mov al, MouseMode
	mov [pcx].MouseMode, al
	ASSUME pcx:nothing
	
	mov curInfo.cbSize, SIZEOF CURSORINFO
	invoke GetCursorInfo, ADDR curInfo
	
	.IF (MouseMode == BPMSMODE_VISIBLE)
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
; Done automatically in bpDefSubclassProc - WM_MOVE & WM_SIZE, if bpDefaultFlag
; is TRUE.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpSetScreenCenter PROC BPFormPtr:BPPtr
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
bpSetWindowMode PROC BPFormPtr:BPPtr, WindowMode:BPEnum
	LOCAL winRect:RECT
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	mov al, WindowMode
	mov [pcx].WindowMode, al
	
	.IF (WindowMode == BPWINMODE_FULLSCREEN)
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
	
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, WS_POPUP
		invoke GetSystemMetrics, SM_CXSCREEN
		push eax
		invoke GetSystemMetrics, SM_CYSCREEN
		mov edx, eax
		pop eax
		mov pcx, BPFormPtr
		invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, 0, 0, eax, edx, \
		SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
	.ELSEIF (WindowMode == BPWINMODE_WINDOWED)
		invoke SetWindowLongA, [pcx].Handle, GWL_STYLE, WS_OVERLAPPEDWINDOW
		mov pcx, BPFormPtr
		invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, [pcx].WindowPos.x, \
		[pcx].WindowPos.y, [pcx].WindowSize.x, [pcx].WindowSize.y, \
		SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
	.ENDIF
	
	;mov pcx, BPFormPtr MAYBE THIS HAS TO BE DONE EVERYTIME SO I HAVE TO MAKE IT A GENERIC PROC
	;.IF ([pcx].LockCursor && [pcx].Focused)
	;	invoke bpSetScreenCenter, BPFormPtr
	;	invoke SetCursorPos, [pcx].ScreenCnt.x, [pcx].ScreenCnt.y
	;.ENDIF
	
	ASSUME pcx:nothing
	ret
bpSetWindowMode ENDP

;   Updates the window display according to the form's parameters (position,
; size).
;   BPFormPtr:BPPtr - pointer to a form structure.
bpUpdateForm PROC BPFormPtr: BPPtr
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	;invoke SetWindowPos, [pcx].Handle, NULL, HWND_TOPMOST, [pcx].ScreenPos.x, \
	;[pcx].ScreenPos.y, [pcx].ScreenSize.x, [pcx].ScreenSize.y,
	
	ASSUME pcx:nothing
	ret
bpUpdateForm ENDP

bpDefTimeProc PROC uID:UINT, uMsg:UINT, dwUser:DWORD, dw1:DWORD, dw2:DWORD
	ASSUME pcx:PTR BPForm
	mov pcx, dwUser
	call [pcx].OnFixed
	ASSUME pcx:nothing
	ret
bpDefTimeProc ENDP

;   The default callback subclass procedure for processing form messages.
bpDefWndProc PROC hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
	LOCAL dwRefData:BPPtr
	
	invoke GetWindowLong, hWnd, GWLP_USERDATA
	mov dwRefData, pax
	
	ASSUME pcx:PTR BPForm
	
	mov bpDefaultFlag, TRUE
	SWITCH uMsg
		CASE WM_DESTROY
			mov pcx, dwRefData
			.IF ([pcx].OnDestroy)
				call [pcx].OnDestroy
			.ENDIF
			.IF (bpDefaultFlag)
				invoke PostQuitMessage, 0
			.ENDIF
		
		CASE WM_INPUT
			mov pcx, dwRefData
			.IF ([pcx].OnInput && [pcx].Focused)				
				invoke bpInMouse, dwRefData, lParam
			.ENDIF
		
		CASE WM_KEYDOWN
			mov pcx, dwRefData
			.IF ([pcx].OnInput)
				invoke bpInKey, dwRefData, wParam, TRUE
			.ENDIF
		CASE WM_KEYUP
			mov pcx, dwRefData
			.IF ([pcx].OnInput)
				invoke bpInKey, dwRefData, wParam, FALSE
			.ENDIF
			
		CASE WM_KILLFOCUS
			mov pcx, dwRefData
			mov [pcx].Focused, 0
		CASE WM_SETFOCUS
			mov pcx, dwRefData
			mov [pcx].Focused, TRUE
			
		
		CASE WM_MOVE
			mov pcx, dwRefData
			mov eax, lParam
			movsx eax, ax
			mov [pcx].ScreenPos.x, eax
			mov eax, lParam
			shr eax, 16
			movsx eax, ax
			mov [pcx].ScreenPos.y, eax
			
			.IF (bpDefaultFlag)
				invoke bpSetScreenCenter, dwRefData
			.ENDIF
			
		CASE WM_PAINT
			mov pcx, dwRefData
			.IF (([pcx].MouseMode == BPMSMODE_LOCKED) && [pcx].Focused)
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
			
			mov bpDefaultFlag, TRUE
			mov pcx, dwRefData
			.IF ([pcx].OnRender) && (bpFirstFrameSkipped)
				call [pcx].OnRender
			.ELSE
				mov bpFirstFrameSkipped, TRUE
			.ENDIF
			
			.IF (bpDefaultFlag)
				mov pcx, dwRefData
				invoke SwapBuffers, [pcx].DeviceContext
				mov bpDefaultFlag, FALSE
			.ENDIF
			
		CASE WM_SIZE
			mov pcx, dwRefData
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
			.IF (bpDefaultFlag)
				mov pcx, dwRefData
				invoke glViewport, 0, 0, [pcx].ScreenSize.x, [pcx].ScreenSize.y
				invoke bpSetScreenCenter, dwRefData
			.ENDIF
	ENDSW
	
	.IF (bpDefaultFlag)
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
	.ENDIF
	
	ASSUME pcx:nothing
	ret
bpDefWndProc ENDP
