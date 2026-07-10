;
;   BP3D.asm
;   Version 0.8ac1
;   BP3D (short for BoilPlate3D) framework main base unit.
;
;   Copyright (c) 2025-2026 Yevhenii Ionenko (aka GreatCorn).
;   All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

; ----- HEADER INCLUDES AND LIB -----
;   You will have to specify a path to a valid directory with an \include 
; subdirectory for the compiler and the direct lib path for the linker (e.g. 
; "C:\masm32" and "C:\masm32\lib", respectively). The separate direct lib path
; is necessary for the linker to find the files. The directory specified to the
; compiler not being a direct inc path is for MASM32 macros loading support.
IFDEF BP_WININC
	; ----- WININC INCLUDES -----
	ECHO BP3D: Compiling with WinInc includes.
	
	;   Remember to generate the .lib files.
	_WIN32_WINNT EQU <0502h>
	WINVER EQU <0502h>
	include include\windows.inc
	
	includelib gdi32.lib
	includelib kernel32.lib
	includelib hid.lib	; You will have to generate it yourself from hid.dll
	include include\gl\gl.inc
	includelib opengl32.lib
	includelib ntdll.lib
	include include\winuser.inc
	includelib user32.lib
	include include\mmsystem.inc
	includelib winmm.lib
ELSEIFNDEF BP_CUSTOM_INCLUDES
	; -----	MASM32 INCLUDES -----
	ECHO BP3D: Compiling with MASM32 includes.
	
	include include\windows.inc

	include include\gdi32.inc
	includelib gdi32.lib
	include include\kernel32.inc
	includelib kernel32.lib
	include include\opengl32.inc
	includelib opengl32.lib
	includelib hid.lib
	include include\user32.inc
	includelib user32.lib
	include include\winmm.inc
	includelib winmm.lib
ENDIF

; -----	INTERFACE -----
;   Available compile-time symbolic macros to define (EQU) before including 
; BP3D, for additional or alternative functionality in the build:
;
;   BP_COMPATIBILITY_W9X - Strict Windows 2000, ME, 98SE compatibility mode.
; Removes all calls of the APIs not supported on aforementioned systems to avoid
; static linking errors. Unsupported APIs that are used: GetRawInput*.
;
;   BP_CUSTOM_INCLUDES - Do not include MASM32 or WinInc headers and LIB files.
;
;   BP_ERROR_PASS - pass through errors and don't terminate the program.
;
;   BP_FIXED_BUSY - busy higher-precision OnFixed thread that uses 100% CPU.
;
;   BP_STATIC_LINK_XP - force static-linking of dynamically loaded procedures
; that start from XP by referencing them directly. Unsupported APIs that are
; used: GetRawInput*.
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
; debug information when calling bpFree, bpMalloc or bpReAlloc (provided a print
; macro is defined).
;
;   BP_USE_LARGE_INTEGER - use LARGE_INTEGER Windows structure when computing
; delta. This will ensure that all delta-related tick variables are of the type
; LARGE_INTEGER and the difference is computed in 64-bit mode.
;
;   BP_WININC - use WinInc Windows headers instead of MASM32 headers and LIB 
; files.

;   P.S. If you're aiming for Windows 98SE and ME compatibility, compiling with
; UASM is not advised, as it somehow makes CRTDLL unable to start.

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
;   Cross-architecture compatibility is possible but very shitty to pull off and
; may quickly become a terrible mess. For now I couldn't get JWlink to recognize
; the LIB files and ML64 is unusable with any kind of headers I threw at it. The
; attempted switch to support 64-bit Assembly made the code even more of a mess
; without register role standardization and bloated invokes here and there. Even
; so, there are some cases where STDCALL is used explicitly (BPForm.OnInput) and
; I get a head-splitting headache whenever I just try to decipher how exactly
; the x64 calling convention would work. 
;   P.S. FFS just use 32-bit as long as 32-bit binaries are supported on 64-bit
; systems.
;   P.P.S. The x64 calling convention was made by the devil himself.
IFDEF rax
	BP_64 EQU <1>
	ECHO BP3D: Compiling in 64-bit mode.
	ECHO BP3D: WARNING! BP3D is compileable, but untested on x64.
ELSE
	ECHO BP3D: Compiling in 32-bit mode.
ENDIF

;   Import common type definitions
IFNDEF BP3D_TYPEDEF_INC
	include BP3DTypedef.inc
ENDIF

BPDisplayDevice STRUCT	; Display device (monitor) structure
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
	DeviceContext	HDC 0		; Form device context (DC)
	GraphicsContext	BPPtr 0		; Form graphics context (GL)
	Handle			HWND 0		; Form window handle
	
	;   Input flags bitmask. See possible input flags at BP_IF_*. Set with
	; bpSetInputFlags or before calling bpCreateForm.
	InputFlags		BYTE 0
	
	WindowStyle		LONG WS_OVERLAPPEDWINDOW
	
	WndProc			BPPtr OFFSET bpDefWndProc	; WndProc procedure offset
	
	; Event procedures
	;   OnCreate	PROC STDCALL
	;   Gets called after the form has just been created (bpCreateForm).
	OnCreate		BPPtr 0
	
	;   OnDestroy	PROC STDCALL
	;   Gets called after the form has just been destroyed (WM_DESTROY).
	OnDestroy		BPPtr 0
	
	;   OnFixed		PROC STDCALL
	;   Gets called in a separate asynchronous thread every bpFixedInterval 
	; seconds (default 0.01666666 s = 60 times/s).
	OnFixed			BPPtr 0
	
	;   OnInput		PROC STDCALL BPInType:BPEnum, BPInStruct:BPPtr
	;   Gets called whenever captured input gets sent to the form (see 
	; InputFlags).
	;   BPInType:BPEnum - a BP_INPUT_* constant that signifies the type of input
	; sent to the callback function.
	;   BPInStruct:BPPtr - pointer to a BPIn* struct corresponding to BPInType.
	OnInput			BPPtr 0
	
	;   OnRender	PROC STDCALL
	;   Gets called whenever the form is drawn (WM_PAINT). If DefaultFlag is on,
	; doesn't send DefWindowProc to maintain a loop. For frame-independence
	; deltaTime should be used.
	OnRender		BPPtr 0
	
	;   OnResize	PROC STDCALL
	;   Gets called whenever the form is resized (WM_SIZE) or moved (WM_MOVE, if
	; BP_ONRESIZE_MOVE is defined). Window and client size and position are
	; returned in WindowSize, ScreenSize; WindowPos and ScreenPos, respectively.
	OnResize		BPPtr 0
	
	;   OnStart		PROC STDCALL
	;   Gets called on the first frame after form creation.
	OnStart			BPPtr 0
	
	
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
BPForm ENDS

BPInJoyAxis STRUCT		; Joystick axis input structure
	JoyNum		DWORD ?		; Joystick index
	Axis		DWORD ?		; Axis index (BP_JOY_AXIS_*)
	Position	REAL4 ?		; Axis position [-1.0 - 1.0]
BPInJoyAxis ENDS

BPInJoyButton STRUCT	; Joystick button input structure
	JoyNum		DWORD ?		; Joystick index
	Button		DWORD ?		; Button index
	Pressed		BPBool ?	; Is the button pressed or released
BPInJoyButton ENDS

BPInKey STRUCT			; Keyboard input structure
	Keycode		DWORD ?		; Virtual-key code
	Pressed		BPBool ?	; Is the key pressed or released
BPInKey ENDS

BPInMouseButton STRUCT	; Mouse button input structure
	Button		DWORD ?		; Mouse button (uses virtual-key constants)
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


;   MASM has some bad headers, fixed redefinitions are here. The ones that have
; unions in them are the ones that are messed up, with the exception of the 
; joystick, ones which are of an entirely different size due to Microsoft
; silently switching UINT size from WORD to DWORD (field prefixes are still w).
IFNDEF BP_CUSTOM_INCLUDES
DEVMODEAFIX STRUCT
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
DEVMODEAFIX ENDS
IFNDEF BP_WININC
;   Fixes for WinMM joystick structs
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

;   Raw input header fixes (same size, so same symbolic names)
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
ENDIF

;   HidP definitions (no structs defined in any headers, WinInc doesn't have HID
; at all). These definitions are limited only to the procedures and structs used
; in BP3D. God save you if you want to use other HID procedures for yourself.
IFNDEF HIDP_REPORT_TYPE
HIDP_REPORT_TYPE TYPEDEF DWORD
HidP_Input = 0
HidP_Output = 1
HidP_Feature = 2
ENDIF
IFNDEF USAGE
USAGE TYPEDEF USHORT
ENDIF

IFNDEF HIDP_CAPS
HIDP_CAPS STRUCT
	Usage						USAGE	?
	UsagePage					USAGE	?
	InputReportByteLength		USHORT	?
	OutputReportByteLength		USHORT	?
	FeatureReportByteLength		USHORT	?
	Reserved					USHORT	17 dup (?)
	NumberLinkCollectionNodes	USHORT	?
	NumberInputButtonCaps		USHORT	?
	NumberInputValueCaps		USHORT	?
	NumberInputDataIndices		USHORT	?
	NumberOutputButtonCaps		USHORT	?
	NumberOutputValueCaps		USHORT	?
	NumberOutputDataIndices		USHORT	?
	NumberFeatureButtonCaps		USHORT	?
	NumberFeatureValueCaps		USHORT	?
	NumberFeatureDataIndices	USHORT	?
HIDP_CAPS ENDS
ENDIF

IFNDEF HIDP_BUTTON_CAPS
HIDP_BUTTON_CAPS STRUCT
	UsagePage			USAGE	?
	ReportID			UCHAR	?
	IsAlias				BOOLEAN	?
	BitField			USHORT	?
	LinkCollection		USHORT	?
	LinkUsage			USAGE	?
	LinkUsagePage		USAGE	?
	IsRange				BOOLEAN	?
	IsStringRange		BOOLEAN	?
	IsDesignatorRange	BOOLEAN	?
	IsAbsolute			BOOLEAN	?
	ReportCount			USHORT	?
	Reserved2			USHORT	?
	Reserved			ULONG	9 DUP(?)

	UNION
		STRUCT Range
			UsageMin		USAGE	?
			UsageMax		USAGE	?
			StringMin		USHORT	?
			StringMax		USHORT	?
			DesignatorMin	USHORT	?
			DesignatorMax	USHORT	?
			DataIndexMin	USHORT	?
			DataIndexMax	USHORT	?
		ENDS

		STRUCT NotRange
			Usage			USAGE	?
			Reserved1		USAGE	?
			StringIndex		USHORT	?
			Reserved2		USHORT	?
			DesignatorIndex	USHORT	?
			Reserved3		USHORT	?
			DataIndex		USHORT	?
			Reserved4		USHORT	?
		ENDS
	ENDS
HIDP_BUTTON_CAPS ENDS
ENDIF

IFNDEF HIDP_VALUE_CAPS
HIDP_VALUE_CAPS	STRUCT 
	UsagePage			USAGE	?
	ReportID			BYTE	?
	IsAlias				BOOLEAN	?
	BitField			WORD	?
	LinkCollection		WORD	?
	LinkUsage			USAGE	?
	LinkUsagePage		USAGE	?
	IsRange				BOOLEAN	?
	IsStringRange		BOOLEAN	?
	IsDesignatorRange	BOOLEAN	?
	IsAbsolute			BOOLEAN	?
	HasNull				BOOLEAN	?
	Reserved			BYTE	?
	BitSize				WORD	?
	ReportCount			WORD	?
	Reserved2			WORD 5 dup (?)
	UnitsExp			DWORD	?
	Units				DWORD	?
	LogicalMin			SDWORD	?
	LogicalMax			SDWORD	?
	PhysicalMin			SDWORD	?
	PhysicalMax			SDWORD	?
	UNION
		STRUCT Range
			UsageMin		USAGE	?
			UsageMax		USAGE	?
			StringMin		WORD	?
			StringMax		WORD	?
			DesignatorMin	WORD	?
			DesignatorMax	WORD	?
			DataIndexMin	WORD	?
			DataIndexMax	WORD	?
		ENDS
		STRUCT NotRange
			Usage			USAGE	?
			Reserved1		USAGE	?
			StringIndex		WORD	?
			Reserved2		WORD	?
			DesignatorIndex	WORD	?
			Reserved3		WORD	?
			DataIndex		WORD	?
			Reserved4		WORD	?
		ENDS
	ENDS
HIDP_VALUE_CAPS	ENDS
ENDIF


IFNDEF HidP_GetButtonCaps
HidP_GetButtonCaps PROTO STDCALL :DWORD, :BPPtr, :BPPtr, :BPPtr
ENDIF
IFNDEF HidP_GetCaps
HidP_GetCaps PROTO STDCALL :BPPtr, :BPPtr
ENDIF
IFNDEF HidP_GetCaps
HidP_GetCaps PROTO STDCALL :BPPtr, :BPPtr
ENDIF
IFNDEF HidP_GetUsages
HidP_GetUsages PROTO STDCALL :DWORD, :USAGE, :USHORT, :BPPtr, :BPPtr, :BPPtr, \
:BPPtr, :ULONG
ENDIF
IFNDEF HidP_GetUsageValue
HidP_GetUsageValue PROTO STDCALL :DWORD, :USAGE, :USHORT, :USAGE, :BPPtr, \
:BPPtr, :BPPtr, :ULONG
ENDIF
IFNDEF HidP_GetValueCaps
HidP_GetValueCaps PROTO STDCALL :DWORD, :BPPtr, :BPPtr, :BPPtr
ENDIF

IFNDEF RIDEV_INPUTSINK
	RIDEV_INPUTSINK EQU 00000100h	; Thank you WinInc
ENDIF
ENDIF

; ----- CONSTANTS -----
BP_ORIENTATION_LANDSCAPE		EQU 0
BP_ORIENTATION_PORTRAIT			EQU 1
BP_ORIENTATION_LANDSCAPE_REV	EQU 2
BP_ORIENTATION_PORTRAIT_REV		EQU 3

BP_FIXED_INTERVAL		EQU 1000 / 60	; OnFixed signal interval (ms)

;   BPForm.InputFlags bits for configuring input. Can be set before form
; creation. To correctly set them after the form has been created, call 
; bpSetInputFlags.
BP_IF_RAW_MOUSE		EQU 1	; Register and use raw mouse input instead of cursor
BP_IF_JOYSTICK		EQU 2	; Register and use joystick input (BP_INPUT_JOY_*)
BP_IF_RAW_JOYSTICK	EQU 4	; Register and use raw joystick input

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
BP_JOY_AXIS_V	EQU 5	; (right stick vertical raw?)

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
VK_MWHEEL_UP	EQU 10
VK_MWHEEL_DOWN	EQU 11

.CONST
bpDefCaption	DB "BP3D", 0		; Default window caption
bpDefClassMain	DB "BPFMain", 0		; Default window class name
bpErrorCaption	DB "ERROR", 0
bpJoyMaxValue	DWORD 1191182336	; Value to divide the joystick DW by (32768)
bpRawJoyF128	REAL4 128.0
bpRawJoyFM128	REAL4 0.0078125	

; ----- DATA FIELDS -----
.DATA
;   So as dynamic procedure loading is supported on at least Windows 2000, it
; offers a possible compromise to ensure single-executable compatibility. This
; is implemented with the GetRawInput* functionality here, related to RAWINPUT.
; A major refactor is possible to implement old-fashioned raw input by SetupAPI
; (maybe CfgMgr32?), but needs more consideration and research.
bpRawInput	BPBool FALSE
BP_RAWINPUT_MAX EQU 3
IFDEF BP_STATIC_LINK_XP
bpGetRawInputData			TEXTEQU <GetRawInputData>
bpGetRawInputDeviceInfo		TEXTEQU <GetRawInputDeviceInfo>
bpRegisterRawInputDevices	TEXTEQU <RegisterRawInputDevices>
ELSE
BPTGetRawInputData TYPEDEF PROTO :DWORD, :DWORD, :LPVOID, :LPDWORD, :DWORD
BPPGetRawInputData TYPEDEF PTR BPTGetRawInputData
bpGetRawInputData BPPGetRawInputData 0

BPTGetRawInputDeviceInfo TYPEDEF PROTO :HANDLE, :UINT, :LPVOID, :PUINT
BPPGetRawInputDeviceInfo TYPEDEF PTR BPTGetRawInputDeviceInfo
bpGetRawInputDeviceInfo BPPGetRawInputDeviceInfo 0

BPTRegisterRawInputDevices TYPEDEF PROTO :BPPtr, :UINT, :UINT
BPPRegisterRawInputDevices TYPEDEF PTR BPTRegisterRawInputDevices
bpRegisterRawInputDevices BPPRegisterRawInputDevices 0
ENDIF


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
bpError					PROTO :BPPtr, :BPPtr
bpInitGLContext			PROTO :BPPtr
bpInJoyAxis				PROTO :BPPtr, :DWORD, :DWORD, :REAL4
bpInJoyButton			PROTO :BPPtr, :DWORD, :DWORD, :BOOL
bpInKey					PROTO :BPPtr, :WPARAM, :BOOL
bpInMouseButton			PROTO :BPPtr, :DWORD, :BPBool
bpInMouseMove 			PROTO :BPPtr
bpInRaw					PROTO :BPPtr, :LPARAM
bpInRawJoystick			PROTO :BPPtr, :BPPtr
bpReadJoysticks			PROTO :BPPtr
bpScreenToWindowPos		PROTO :BPPtr, :BPPtr
bpScreenToWindowSize	PROTO :BPPtr, :BPPtr
bpSetDisplayDevice		PROTO :BPPtr, :DWORD
bpSetInputFlags			PROTO :BPPtr, :BYTE
bpSetMouseMode			PROTO :BPPtr, :BPEnum
bpSetResolution			PROTO :BPPtr, :BPPtr, :BPBool
bpSetScreenCenter		PROTO :BPPtr
bpSetScreenSize			PROTO :BPPtr, :DWORD, :DWORD
bpSetWindowMode			PROTO :BPPtr, :BPEnum
bpSetWindowPos			PROTO :BPPtr, :SDWORD, :SDWORD
bpSetWindowSize			PROTO :BPPtr, :DWORD, :DWORD
bpUpdateDisplayDevices	PROTO
bpUpdateJoysticks		PROTO
bpUpdateWindowPos		PROTO :BPPtr
bpDefFixedProc			PROTO :LPVOID
bpDefWndProc			PROTO :HWND, :UINT, :WPARAM, :LPARAM

;   Memory to memory through stack macro (like MASM m2m).
bpMPM MACRO m1:REQ, m2:REQ
	push m2
	pop m1
ENDM

;   Memory to memory through 32-bit eax macro (like MASM mrm).
bpMEM32 MACRO m1:REQ, m2:REQ
	mov eax, m2
	mov m1, eax
ENDM

;   Pop 32-bit value (through rax-eax if 64-bit) macro.
bpPop32 MACRO m1:REQ
	IFDEF rax
		pop rax
		mov m1, eax
	ELSE
		pop m1
	ENDIF
ENDM

;   Push 32-bit value (through rax-eax if 64-bit) macro.
bpPush32 MACRO m1:REQ
	IFDEF rax
		mov eax, m1
		push rax
	ELSE
		push m1
	ENDIF
ENDM

;   Simple MASM rv replacement. Invokes a PROC and returns pax.
;   ProcName:PROC - procedure name.
;   Args:VARARG - procedure arguments.
bpR MACRO ProcName:REQ, Args:VARARG
	procCall EQU <invoke ProcName>
	FOR var,<Args>
		procCall CATSTR procCall,<, var>
	ENDM
	procCall
	EXITM <pax>
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
	IFDEF print
		print "Freeing address "
		print uhex$(lpMem), 13, 10
	ENDIF
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
	IFDEF print
		print "Reallocating ", 9
		print udword$(dwBytes), 9
		print "from "
		print uhex$(lpMem), 32
	ENDIF
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
	IFDEF print
		push pax
		print "to "
		pop pax
		push pax
		print uhex$(pax), 13, 10
		pop pax
	ENDIF
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
	IFDEF print
		print "Allocating ", 9
		print udword$(dwBytes), 9
	ENDIF
	ENDIF
	
	invoke HeapAlloc, hHeap, dwFlags, dwBytes
	
	IFDEF BP_TRACEABLE_HEAP_LIST
		mov pcx, heapList
		mov pdx, heapListSize
		sub pdx, SIZEOF BPPtr
		mov BPPtr PTR [pcx+pdx], pax
	ENDIF
	IFDEF BP_TRACEABLE_HEAP_VERBOSE
	IFDEF print
		push pax
		print "on address "
		pop pax
		push pax
		print uhex$(pax), 13, 10
		pop pax
	ENDIF
	ENDIF
	ret
bpMallocProc ENDP

IFDEF BP_TRACEABLE_HEAP_LIST
;   Print the list of allocated memory blocks.
bpPrintHeapList PROC EXPORT
	IFDEF print
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
	ENDIF
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
		
		mov pcx, LastTick
		.IF (!DWORD PTR [pcx])
			jmp bpCalculateDeltaSkip
		.ENDIF
		
		mov eax, tick.LowPart
		sub eax, DWORD PTR [pcx]
		mov diff, eax
	ENDIF
	
	bpCalculateDeltaProcess:
	ASSUME pcx:nothing
	
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
		bpMEM32 DWORD PTR [pcx], tick.LowPart
	ENDIF
	ret
bpCalculateDelta ENDP

;   Initialize form and create a window based on its parameters.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpCreateForm PROC EXPORT BPFormPtr:BPPtr
	LOCAL wc:WNDCLASSEX, msg:MSG, testFreq:LARGE_INTEGER, quitFlag:BPBool
	LOCAL ridMouse:RAWINPUTDEVICE, rect:RECT, pUser32:BPPtr
	push pbx
	ASSUME pbx:PTR BPForm
	mov pbx, BPFormPtr
	
	; BoilPlate3D system initialization
	
	; Get process heap as default heap to not call GetProcessHeap all the time.
	.IF (!bpDefHeap)
		call GetProcessHeap
		mov bpDefHeap, pax
	.ENDIF
	
	; LoadLibrary works on Windows 2000 after all, I guess. Needs more testing.
	.CONST
		bpUser32DLL				DB "user32.dll", 0
	.CODE
	mov pUser32, bpR(GetModuleHandle, OFFSET bpUser32DLL)
	.IF !(pax)
		mov pUser32, bpR(LoadLibrary, OFFSET bpUser32DLL)
	.ENDIF
	; Load stuff unsupported on Windows 2000 dynamically
	.IF (pax)
		IFNDEF BP_STATIC_LINK_XP
			.CONST
				bpGetRawInputDataS			DB "GetRawInputData", 0
				bpGetRawInputDeviceInfoS	DB "GetRawInputDeviceInfo", 0
				bpRegisterRawInputDevicesS	DB "RegisterRawInputDevices", 0
			.CODE
			mov bpGetRawInputData, \
			bpR(GetProcAddress, pUser32, OFFSET bpGetRawInputDataS)
			.IF (pax)
				inc bpRawInput
			.ENDIF
			mov bpGetRawInputDeviceInfo, \
			bpR(GetProcAddress, pUser32, OFFSET bpGetRawInputDeviceInfoS)
			.IF (pax)
				inc bpRawInput
			.ENDIF
			mov bpRegisterRawInputDevices, \
			bpR(GetProcAddress, pUser32, OFFSET bpRegisterRawInputDevicesS)
			.IF (pax)
				inc bpRawInput
			.ENDIF
		ENDIF
	.ENDIF
	
	; Disable DPI scaling if possible
	IFNDEF BP_DPI_UNAWARE
		IFNDEF SetProcessDPIAware
			.CONST
				bpSetProcessDPIAwareS	DB "SetProcessDPIAware", 0
			.CODE
			.IF (pUser32)
				invoke GetProcAddress, pUser32, OFFSET bpSetProcessDPIAwareS
				.IF (pax)
					call pax
				.ENDIF
			.ENDIF
		ELSE
			call SetProcessDPIAware
		ENDIF
	ENDIF
	
	invoke FreeLibrary, pUser32
	
	mov wc.cbSize, SIZEOF WNDCLASSEX
	mov wc.style, CS_HREDRAW or CS_VREDRAW
	mov wc.cbClsExtra, NULL
	mov wc.cbWndExtra, NULL
	mov	wc.hbrBackground, COLOR_WINDOW
	mov wc.lpszMenuName, NULL
	
	
	bpMPM wc.lpszClassName,	[pbx].ClassName	; MSDN says it's a 32-bit pointer ?
	bpMPM wc.lpfnWndProc,	[pbx].WndProc
	
	
	invoke GetModuleHandle, NULL
	mov	wc.hInstance, pax
	invoke LoadIcon, pax, 500
	mov wc.hIcon, pax
	mov wc.hIconSm, pax
	invoke LoadCursor, NULL, IDC_ARROW
	mov wc.hCursor, pax
	
	invoke RegisterClassEx, ADDR wc
	
	invoke CreateWindowEx, 0, [pbx].ClassName, [pbx].Caption, \
	[pbx].WindowStyle, [pbx].WindowPos.x, [pbx].WindowPos.y, \
	[pbx].WindowSize.x, [pbx].WindowSize.y, NULL, NULL, wc.hInstance, NULL
	
	mov [pbx].Handle, pax
	IFDEF SetWindowLongPtrA
		invoke SetWindowLongPtrA, pax, GWLP_USERDATA, BPFormPtr
	ELSE
		invoke SetWindowLongA, pax, GWLP_USERDATA, BPFormPtr
	ENDIF
	
	; Get some system info
	IFDEF BP_USE_LARGE_INTEGER
		invoke QueryPerformanceFrequency, ADDR bpPerfFreq
	ELSE
		invoke QueryPerformanceFrequency, ADDR testFreq
		bpMEM32 bpPerfFreq, testFreq.LowPart
	ENDIF
	call bpUpdateDisplayDevices
	
	; Populate WindowPos, WindowSize
	invoke GetWindowRect, [pbx].Handle, ADDR rect
	mov eax, rect.left
	mov [pbx].WindowPos.x, eax
	sub rect.right, eax
	bpMEM32 [pbx].WindowSize.x, rect.right
	mov eax, rect.top
	mov [pbx].WindowPos.y, eax
	sub rect.bottom, eax
	bpMEM32 [pbx].WindowSize.y, rect.bottom
	
	; Populate ScreenPos, ScreenSize
	invoke GetClientRect, [pbx].Handle, ADDR rect
	mov eax, rect.left
	mov [pbx].ScreenPos.x, eax
	sub rect.right, eax
	bpMEM32 [pbx].ScreenSize.x, rect.right
	mov eax, rect.top
	mov [pbx].ScreenPos.y, eax
	sub rect.bottom, eax
	bpMEM32 [pbx].ScreenSize.y, rect.bottom
	
	mov [pbx].DefaultFlag, TRUE
	.IF ([pbx].OnCreate)
		mov pax, pbx
		pop pbx
		ASSUME pax:PTR BPForm
		call [pax].OnCreate
		ASSUME pax:nothing
		push pbx
		mov pbx, BPFormPtr
	.ENDIF
	.IF ([pbx].DefaultFlag)		
		mov al, [pbx].InputFlags
		mov [pbx].InputFlags, 0
		invoke bpSetInputFlags, pbx, al
		
		mov pbx, BPFormPtr
		.IF ([pbx].WindowMode)
			invoke bpSetWindowMode, pbx, [pbx].WindowMode
		.ENDIF
	.ENDIF
	
	; OnFixed
	.IF ([pbx].OnFixed)
		; BSD's Wine port doesn't like WinMM (Linux's does, skill issue).
		;invoke timeSetEvent, BP_FIXED_INTERVAL, 0, OFFSET bpDefFixedProc, \
		;BPFormPtr, TIME_PERIODIC
		invoke CreateThread, NULL, 0, OFFSET bpDefFixedProc, BPFormPtr, 0, NULL 
	.ENDIF
	
	invoke ShowWindow, [pbx].Handle, SW_SHOWDEFAULT
	
	ASSUME pbx:nothing
	pop pbx
	
	mov quitFlag, 0
	.WHILE (!quitFlag)
		invoke MsgWaitForMultipleObjectsEx, 0, NULL, 12, QS_ALLINPUT, 0
		.IF (eax == WAIT_OBJECT_0)
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
		.ENDIF
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

;   Output an error message.
;   StringPtr:BPPtr - pointer to the error text string.
;   CaptionPtr:BPPtr - pointer to the error message caption (bpErrorCaption if 
; NULL).
bpError PROC EXPORT StringPtr:BPPtr, CaptionPtr:BPPtr
	LOCAL stdError:HANDLE
	
	; Get string length
	push pbx
	mov pbx, StringPtr
	.WHILE (BYTE PTR [pbx])
		inc pbx
	.ENDW
	sub pbx, StringPtr
	invoke GetStdHandle, STD_ERROR_HANDLE
	mov stdError, pax
	invoke WriteConsole, stdError, StringPtr, ebx, NULL, NULL
	pop pbx
	.IF !(CaptionPtr)
		lea pax, bpErrorCaption
		mov CaptionPtr, pax
	.ENDIF
	invoke MessageBox, NULL, StringPtr, CaptionPtr, MB_OK
	
	IFNDEF BP_ERROR_PASS
		invoke GetCurrentProcess
		invoke TerminateProcess, pax, 0
	ENDIF
	ret
bpError ENDP

;   Initialize OpenGL context in an existing form.
;   BPFormPtr:BPPtr - pointer to a form structure.
bpInitGLContext PROC EXPORT BPFormPtr:BPPtr
	LOCAL pfd:PIXELFORMATDESCRIPTOR, pixelFormat:DWORD
	push pbx
	ASSUME pbx:PTR BPForm
	mov pbx, BPFormPtr
	
	invoke GetDC, [pbx].Handle
	mov [pbx].DeviceContext, pax
	
	mov pfd.nSize, SIZEOF PIXELFORMATDESCRIPTOR
	mov pfd.nVersion, 1
	mov pfd.dwFlags, \
	PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER
	mov pfd.iPixelType, PFD_TYPE_RGBA
	mov pfd.cColorBits, 24
	mov pfd.cAccumBits, 0
	mov pfd.cStencilBits, 1
	mov pfd.iLayerType, PFD_MAIN_PLANE
	
	invoke ChoosePixelFormat, [pbx].DeviceContext, ADDR pfd
	mov pixelFormat, eax
	
	invoke SetPixelFormat, [pbx].DeviceContext, pixelFormat, ADDR pfd
	
	invoke wglCreateContext, [pbx].DeviceContext
	mov [pbx].GraphicsContext, pax
	
	invoke wglMakeCurrent, [pbx].DeviceContext, [pbx].GraphicsContext
	
	invoke glEnable, GL_CULL_FACE
	invoke glShadeModel, GL_SMOOTH
	invoke glEnable, GL_DEPTH_TEST
	invoke glEnable, GL_TEXTURE_2D
	invoke glDepthFunc, GL_LEQUAL
	
	invoke glEnableClientState, GL_VERTEX_ARRAY
	invoke glEnableClientState, GL_TEXTURE_COORD_ARRAY
	invoke glEnableClientState, GL_NORMAL_ARRAY
	
	invoke glClearColor, 0, 0, 0, 0
	
	ASSUME pbx:nothing
	pop pbx
	ret
bpInitGLContext ENDP

;   Send joystick axis input to form OnInput event as a struct.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   JoyNum:DWORD - number of the joystick sending input.
;   Axis:DWORD - axis number (correspondent to BP_JOY_AXIS_* constants).
;   Position:REAL4 - axis position.
bpInJoyAxis PROC EXPORT BPFormPtr:BPPtr, JoyNum:DWORD, Axis:DWORD, \
Position:REAL4
	LOCAL bpInStruct:BPInJoyAxis, pos:REAL4
	
	fld Position
	fabs
	fld bpJoyThreshold[0]
	IF @Cpu AND BP_CPU_686	; TODO test properly 
		fcomip st, st(1)
	ELSE
		fcomp
		fstsw ax
		bt ax, 8
	ENDIF
	
	.IF (!Carry?)
		fstp st
		mov pos, 0
	.ELSE
		fld bpJoyThreshold[4]
		IF @Cpu AND BP_CPU_686
			fcomip st, st(1)
			fstp st
		ELSE
			fcompp
			fstsw ax
			bt ax, 8
		ENDIF
		
		.IF (Carry?)
			.IF (Position & 80000000h)
				mov pos, 3212836864	; -1.0f
			.ELSE
				mov pos, 1065353216	; 1.0f
			.ENDIF
		.ELSE
			bpMEM32 pos, Position
		.ENDIF
	.ENDIF
	
	bpMEM32 bpInStruct.JoyNum, JoyNum
	bpMEM32 bpInStruct.Axis, Axis
	bpMEM32 bpInStruct.Position, pos
	
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
bpInJoyButton PROC EXPORT BPFormPtr:BPPtr, JoyNum:DWORD, Button:DWORD, \
Pressed:BOOL
	LOCAL bpInStruct:BPInJoyButton
	
	bpMEM32 bpInStruct.JoyNum, JoyNum
	bpMEM32 bpInStruct.Button, Button
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
	
	mov pax, Keycode
	mov bpInStruct.Keycode, eax
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
bpInMouseButton PROC EXPORT BPFormPtr:BPPtr, Button:DWORD, Pressed:BPBool
	LOCAL bpInStruct:BPInMouseButton
	
	bpMEM32 bpInStruct.Button, Button
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
	
	bpMEM32 bpInStruct.Position.x, bpMouseClient[0]
	bpMEM32 bpInStruct.Position.y, bpMouseClient[4]
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	mov eax, bpMouseClient[0]
	sub eax, bpMouseClientPrev[0]
	mov bpInStruct.Relative.x, eax
	mov eax, bpMouseClient[4]
	sub eax, bpMouseClientPrev[4]
	mov bpInStruct.Relative.y, eax
	
	bpMEM32 bpMouseClientPrev[0], bpMouseClient[0]
	bpMEM32 bpMouseClientPrev[4], bpMouseClient[4]
	
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
	IFNDEF BP_COMPATIBILITY_W9X
	LOCAL bpInMouseMoveStruct:BPInMouseMove
	LOCAL dwSize:DWORD, lpb:BPPtr
	
	IFNDEF BP_STATIC_LINK_XP
	.IF !(bpGetRawInputData)
		ret
	.ENDIF
	ENDIF
	
	; Get buffer size for RAWINPUT and allocate
	invoke bpGetRawInputData, RawHandle, RID_INPUT, NULL, ADDR dwSize, \
	SIZEOF RAWINPUTHEADER
	invoke bpMalloc, bpDefHeap, 0, dwSize
	mov lpb, pax
	
	; Read input data
	invoke bpGetRawInputData, RawHandle, RID_INPUT, lpb, ADDR dwSize, \
	SIZEOF RAWINPUTHEADER
	
	.IF (eax == dwSize)	; Check for valid input read
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
						; Broken on Wine, TODO
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
						; TODO I don't have a mouse with that
					.ENDIF
					.IF (pax == RI_MOUSE_BUTTON_1_DOWN)
						invoke bpInMouseButton,BPFormPtr, VK_LBUTTON, TRUE
					.ELSEIF (pax == RI_MOUSE_BUTTON_1_UP)
						invoke bpInMouseButton,BPFormPtr, VK_LBUTTON, FALSE
					.ELSEIF (pax == RI_MOUSE_BUTTON_2_DOWN)
						invoke bpInMouseButton,BPFormPtr, VK_RBUTTON, TRUE
					.ELSEIF (pax == RI_MOUSE_BUTTON_2_UP)
						invoke bpInMouseButton,BPFormPtr, VK_RBUTTON, FALSE
					.ELSEIF (pax == RI_MOUSE_BUTTON_3_DOWN)
						invoke bpInMouseButton,BPFormPtr, VK_MBUTTON, TRUE
					.ELSEIF (pax == RI_MOUSE_BUTTON_3_UP)
						invoke bpInMouseButton,BPFormPtr, VK_MBUTTON, FALSE
					.ELSEIF (pax == RI_MOUSE_BUTTON_4_DOWN)
						invoke bpInMouseButton,BPFormPtr, VK_XBUTTON1, TRUE
					.ELSEIF (pax == RI_MOUSE_BUTTON_4_UP)
						invoke bpInMouseButton,BPFormPtr, VK_XBUTTON1, FALSE
					.ELSEIF (pax == RI_MOUSE_BUTTON_5_DOWN)
						invoke bpInMouseButton,BPFormPtr, VK_XBUTTON2, TRUE
					.ELSEIF (pax == RI_MOUSE_BUTTON_5_UP)
						invoke bpInMouseButton,BPFormPtr, VK_XBUTTON2, FALSE
					.ENDIF
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
				
				;   Wine implements (implemented?) "raw mouse" through cursor.
				; There was a very specific problem, where clicking on a
				; fullscreen (BP_WINDOW_MODE_FULLSCREEN) window would make
				; SetCursorPos send WM_INPUT events due to that implementation.
				
				bpMEM32 bpMouseClient[0], bpMouseScreen[0]
				bpMEM32 bpMouseClient[4], bpMouseScreen[4]
				invoke ScreenToClient, [pdx].Handle, ADDR bpMouseClient
				
				bpMEM32 bpInMouseMoveStruct.Position.x, bpMouseClient
				bpMEM32 bpInMouseMoveStruct.Position.y, bpMouseClient[4]
				
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
			invoke bpInRawJoystick, BPFormPtr, lpb
		.ENDIF
		ASSUME pcx:nothing
	.ENDIF
	invoke bpFree, bpDefHeap, 0, lpb
	ENDIF
	ret
bpInRaw ENDP

;   Process raw joystick input and send to form OnInput event as structs. Satan
; himself endorsed this procedure and gave me only one gamepad to test with.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   InputDataPtr:BPPtr - handle to pre-read RAWINPUT structure.
bpInRawJoystick PROC EXPORT BPFormPtr:BPPtr, InputDataPtr:BPPtr
	IFNDEF BP_COMPATIBILITY_W9X
	MAX_BUTTONS EQU 32
	
	LOCAL dwSize:DWORD, prep:BPPtr, caps:HIDP_CAPS
	LOCAL pbCaps:BPPtr, pvCaps:BPPtr, capsLen:USHORT, usgLen:ULONG, btnCnt:DWORD
	LOCAL usg[MAX_BUTTONS]:USAGE, btns:DWORD, usgVal:ULONG
	
	IFNDEF BP_STATIC_LINK_XP
	.IF !(bpGetRawInputDeviceInfo)
		ret
	.ENDIF
	ENDIF
	
	; Get preparsed data block
	ASSUME pcx:PTR RAWINPUT
	mov pcx, InputDataPtr
	invoke bpGetRawInputDeviceInfo, [pcx].header.hDevice, RIDI_PREPARSEDDATA, \
	NULL, ADDR dwSize
	.IF !(eax)
		invoke bpMalloc, bpDefHeap, 0, dwSize
		mov prep, pax
		mov pcx, InputDataPtr
		invoke bpGetRawInputDeviceInfo, [pcx].header.hDevice, \
		RIDI_PREPARSEDDATA, prep, ADDR dwSize
		.IF (eax >= 0)
			; Button caps
			invoke HidP_GetCaps, prep, ADDR caps
			
			movzx eax, caps.NumberInputButtonCaps
			mov capsLen, ax
			mov cx, SIZEOF HIDP_BUTTON_CAPS
			mul cx
			invoke bpMalloc, bpDefHeap, 0, eax
			mov pbCaps, pax
			
			invoke HidP_GetButtonCaps, 0, pbCaps, ADDR capsLen, prep
			
			; Get number of buttons
			ASSUME pdx:PTR HIDP_BUTTON_CAPS
			mov pdx, pbCaps
			movzx eax, [pdx].Range.UsageMax
			sub ax, [pdx].Range.UsageMin
			inc ax
			mov btnCnt, eax
			mov bpJoysticks[0].NumButtons, eax
			
			; Value caps
			movzx eax, caps.NumberInputValueCaps
			mov bpJoysticks[0].NumAxes, eax
			dec bpJoysticks[0].NumAxes
			mov capsLen, ax
			mov cx, SIZEOF HIDP_VALUE_CAPS
			mul cx
			invoke bpMalloc, bpDefHeap, 0, eax
			mov pvCaps, pax
			
			invoke HidP_GetValueCaps, HidP_Input, pvCaps, ADDR capsLen, prep
			
			bpMEM32 usgLen, btnCnt
			mov pcx, InputDataPtr
			mov pdx, pbCaps
			mov eax, [pcx].data.hid.dwSizeHid	; you absolute fucking fool
			invoke HidP_GetUsages, HidP_Input, [pdx].UsagePage, 0, ADDR usg, \
			ADDR usgLen, prep, ADDR [pcx].data.hid.bRawData, ax
			
			; Set buttons DWORD (reimplementing WinMM huh)
			mov btns, 0
			xor pcx, pcx
			.WHILE (ecx < usgLen)
				mov pax, pcx
				shl pax, 1	; *2
				movzx pax, usg[pax]
				mov pdx, pbCaps
				sub ax, [pdx].Range.UsageMin
				
				push pcx
					mov cl, al
					mov eax, 1
					shl eax, cl
					or btns, eax
				pop pcx
				
				inc pcx
			.ENDW
			
			; Send buttons by comparing DWORD
			mov eax, btns
			.IF (bpJoyInfoEx[0].dwButtons != eax)
				xor ecx, ecx
				.WHILE (ecx < btnCnt)
					mov eax, 1
					shl eax, cl
					mov edx, bpJoyInfoEx[0].dwButtons
					and edx, eax
					and eax, btns
					.IF (eax != edx)
						push pbx
						push pcx
						mov ebx, ecx
						invoke bpInJoyButton, BPFormPtr, 0, ebx, eax
						pop pcx
						pop pbx
					.ENDIF
					inc pcx
				.ENDW
				
				bpMEM32 bpJoyInfoEx[0].dwButtons, btns
			.ENDIF
			
			; Get value states
			xor pcx, pcx
			.WHILE (cx < capsLen)
				mov pax, pcx
				mov edx, SIZEOF HIDP_VALUE_CAPS
				mul edx
				add pax, pvCaps
				mov pdx, pax
				
				push pcx
				push pdx
				mov pcx, InputDataPtr
				mov eax, [pcx].data.hid.dwSizeHid
				ASSUME pdx:PTR HIDP_VALUE_CAPS
				invoke HidP_GetUsageValue, HidP_Input, [pdx].UsagePage, 0, \
				[pdx].Range.UsageMin, ADDR usgVal, prep, \
				ADDR [pcx].data.hid.bRawData, ax
				pop pdx
				
				.IF ([pdx].Range.UsageMin == 39h)
					mov eax, usgVal
					.IF (bpJoysticks[0].NumAxes == 4)	; Different D-Pad
						; Bad practice?
						.IF (eax == 8)
							xor eax, eax
						.ELSE
							inc eax
						.ENDIF
					.ENDIF
					.IF (bpJoyInfoEx[0].dwPOV != eax)
						mov bpJoyInfoEx[0].dwPOV, eax
						.IF !(eax)
							mov usgVal, 0
						.ELSE
							mov ecx, eax
							dec cl
							shr cl, 1
							mov eax, 1
							shl eax, cl
							mov ecx, usgVal
							mov usgVal, eax
							
							push pcx
							xor edx, edx
							mov eax, ecx
							dec eax
							mov ecx, 2
							div ecx
							pop pcx
							.IF (edx)
								.IF (cl == 8)
									mov cl, 1
								.ENDIF
								shr cl, 1
								mov eax, 1
								shl eax, cl
								or usgVal, eax
							.ENDIF
						.ENDIF
						xor pcx, pcx
						.WHILE (pcx < 4)
							mov eax, 1
							shl eax, cl
							mov edx, bpJoyInfoEx[0].dwReserved1
							and edx, eax
							and eax, usgVal
							.IF (eax != edx)
								mov pdx, pcx
								add pdx, 32
								push pbx
								push pcx
								mov ebx, edx
								invoke bpInJoyButton, BPFormPtr, 0, ebx, eax
								pop pcx
								pop pbx
							.ENDIF
							inc pcx
						.ENDW
						bpMEM32 bpJoyInfoEx[0].dwReserved1, usgVal
					.ENDIF
				.ELSE
					movzx pcx, [pdx].Range.UsageMin
					sub pcx, 30h
					mov pdx, pcx
					shl pdx, 2
					add pdx, 8
					mov eax, usgVal
					.IF (DWORD PTR bpJoyInfoEx[pdx] != eax)
						mov DWORD PTR bpJoyInfoEx[pdx], eax
						fild usgVal
						.IF (bpJoysticks[0].NumAxes == 5)
							fdiv bpJoyMaxValue
							fld1
							fsub
							.IF (ecx == 4)	; worst practice
								mov ecx, 3
							.ELSEIF (ecx == 3)
								mov ecx, 4
							.ENDIF
						.ELSE
							fsub bpRawJoyF128
							fmul bpRawJoyFM128
						.ENDIF
						fstp usgVal
						mov eax, ecx
						invoke bpInJoyAxis, BPFormPtr, 0, eax, usgVal
					.ENDIF
				.ENDIF
				ASSUME pdx:nothing
				
				pop pcx
				inc pcx
			.ENDW
			invoke bpFree, bpDefHeap, 0, pvCaps
			invoke bpFree, bpDefHeap, 0, pbCaps
		.ENDIF
		invoke bpFree, bpDefHeap, 0, prep
	.ENDIF
	ENDIF
	ret
bpInRawJoystick ENDP

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
	xor ebx, ebx
	.WHILE (ebx < bpJoyCount)
		mov pax, pbx
		mov pcx, SIZEOF BPJoystick
		mul pcx
		
		.IF (bpJoysticks[pax].Active)
			mov ecx, bpJoysticks[pax].NumButtons
			mov buttons, ecx
			
			invoke joyGetPosEx, ebx, ADDR joyInfoEx
			mov joyNum, ebx
			
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
				xor ecx, ecx
				.WHILE (ecx < buttons)
					mov eax, 1
					shl eax, cl
					mov edx, bpJoyInfoEx[pbx].dwButtons
					and edx, eax
					and eax, joyInfoEx.dwButtons
					.IF (eax != edx)
						push pbx
						push pcx
						mov ebx, ecx
						invoke bpInJoyButton, BPFormPtr, joyNum, ebx, eax
						pop pcx
						pop pbx
					.ENDIF
					inc pcx
				.ENDW
				
				bpMEM32 bpJoyInfoEx[pbx].dwButtons, joyInfoEx.dwButtons
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
				
				mov joyInfoEx.dwReserved1, eax	; evil
				bpMEM32 bpJoyInfoEx[pbx].dwPOV, joyInfoEx.dwPOV
				
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
						mov ebx, edx
						invoke bpInJoyButton, BPFormPtr, joyNum, ebx, eax
						pop pcx
						pop pbx
					.ENDIF
					inc pcx
				.ENDW
				
				bpMEM32 bpJoyInfoEx[pbx].dwReserved1, joyInfoEx.dwReserved1
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
	
	mov pcx, PosPtr
	bpMEM32 rect.left,	DWORD PTR [pcx]
	bpMEM32 rect.top,	DWORD PTR [pcx+4]
	mov rect.right,		0
	mov rect.bottom,	0
	
	ASSUME pax:PTR BPForm
	mov pax, BPFormPtr
	invoke AdjustWindowRect, ADDR rect, [pax].WindowStyle, 0
	ASSUME pax:nothing
	
	mov pcx, PosPtr
	bpMEM32 DWORD PTR [pcx], 	rect.left
	bpMEM32 DWORD PTR [pcx+4], 	rect.top
	ret
bpScreenToWindowPos ENDP

;   Converts screen (client area) size to the window size required to contain 
; that area, with proper border and caption adjustments.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   SizePtr:BPPtr - pointer to the DWORD screen width and height stored 
; consecutively. The resulting window size will be returned into this pointer.
bpScreenToWindowSize PROC EXPORT BPFormPtr:BPPtr, SizePtr:BPPtr
	LOCAL rect:RECT
	
	mov pcx, SizePtr
	mov rect.top,		0
	mov rect.left,		0
	bpMEM32 rect.right,		DWORD PTR [pcx]
	bpMEM32 rect.bottom,	DWORD PTR [pcx+4]
	
	ASSUME pax:PTR BPForm
	mov pax, BPFormPtr
	invoke AdjustWindowRect, ADDR rect, [pax].WindowStyle, 0
	ASSUME pax:nothing
	
	mov ecx, rect.right
	sub ecx, rect.left
	mov pax, SizePtr
	mov DWORD PTR [pax], ecx
	mov ecx, rect.bottom
	sub ecx, rect.top
	mov DWORD PTR [pax+4], ecx
	
	ret
bpScreenToWindowSize ENDP

;   Set the display device for the form and move it to that display device.
; Updates the form by setting its WindowMode with bpSetWindowMode.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   DisplayDevice:DWORD - display device index (from bpDisplayDevices).
bpSetDisplayDevice PROC EXPORT BPFormPtr:BPPtr, DisplayDevice:DWORD
	LOCAL winMode:BPEnum
	
	push pbx
	ASSUME pbx:PTR BPForm
	mov pbx, BPFormPtr
	
	mov eax, DisplayDevice
	mov edx, SIZEOF BPDisplayDevice
	mul edx
	mov edx, eax
	
	.IF !(bpDisplayDevices[pdx].Active)
		ret
	.ENDIF
	
	bpMEM32 [pbx].DisplayDevice, DisplayDevice
	
	
	mov al, [pbx].WindowMode
	mov winMode, al
	push pdx
	; This horrid random bullshit is necessary to make it work with Xorg
	invoke bpSetWindowMode, BPFormPtr, BP_WINDOW_MODE_WINDOWED
	invoke bpSetWindowMode, BPFormPtr, BP_WINDOW_MODE_MINIMIZED
	pop pax
	
	invoke bpSetWindowPos, pbx, bpDisplayDevices[pax].ScreenPos.x, \
	bpDisplayDevices[pax].ScreenPos.y
	
	invoke ShowWindow, [pbx].Handle, SW_RESTORE
	invoke bpSetWindowMode, BPFormPtr, winMode
	
	ASSUME pbx:nothing
	pop pbx
	ret
bpSetDisplayDevice ENDP

;   Update input configurations for a BPForm according to passed InputFlags and
; set the form's InputFlags to that. See possible input flags at BP_IF_*.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   InputFlags:BYTE - bitmask of input flags of BP_IF_*.
bpSetInputFlags PROC EXPORT BPFormPtr:BPPtr, InputFlags:BYTE
	LOCAL rid:RAWINPUTDEVICE
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	
	; Forgive me
	IFNDEF BP_STATIC_LINK_XP
	.IF (bpRegisterRawInputDevices)
	ENDIF
		; Raw mouse flag (no lag raw mouse input, useless? on Wine)
		mov al, [pcx].InputFlags
		and al, BP_IF_RAW_MOUSE
		mov ah, InputFlags
		and ah, BP_IF_RAW_MOUSE
		.IF (al) != (ah)
			mov rid.usUsagePage, 1		; Generic desktop
			mov rid.usUsage, 2			; Mouse
			.IF (ah)
				mov rid.dwFlags, RIDEV_INPUTSINK
				bpMPM rid.hwndTarget, [pcx].Handle
			.ELSE
				mov rid.dwFlags, RIDEV_REMOVE
				mov rid.hwndTarget, 0
			.ENDIF
			invoke bpRegisterRawInputDevices, ADDR rid, 1, SIZEOF RAWINPUTDEVICE
			mov pcx, BPFormPtr
		.ENDIF
	IFNDEF BP_STATIC_LINK_XP
	.ENDIF
	ENDIF
	
	; Raw joystick
	mov al, [pcx].InputFlags
	and al, BP_IF_RAW_JOYSTICK
	mov ah, InputFlags
	and ah, BP_IF_RAW_JOYSTICK
	.IF ((al) != (ah))
		IFNDEF BP_STATIC_LINK_XP
		.IF (bpRegisterRawInputDevices)
		ENDIF
			mov rid.usUsagePage, 1		; Generic desktop
			mov rid.usUsage, 4			; Joystick (directinput I think)
			.IF (ah)
				mov rid.dwFlags, RIDEV_INPUTSINK
				bpMPM rid.hwndTarget, [pcx].Handle
			.ELSE
				mov rid.dwFlags, RIDEV_REMOVE
				mov rid.hwndTarget, 0
			.ENDIF
			invoke bpRegisterRawInputDevices, ADDR rid, 1, SIZEOF RAWINPUTDEVICE
			mov pcx, BPFormPtr
			
			mov rid.usUsage, 5			; Joystick (XInput)
			mov ah, InputFlags
			and ah, BP_IF_RAW_JOYSTICK
			.IF (ah)
				mov rid.dwFlags, RIDEV_INPUTSINK
			.ELSE
				mov rid.dwFlags, RIDEV_REMOVE
			.ENDIF
			invoke bpRegisterRawInputDevices, ADDR rid, 1, SIZEOF RAWINPUTDEVICE
			mov pcx, BPFormPtr
		IFNDEF BP_STATIC_LINK_XP
		.ENDIF
		ENDIF
	.ELSEIF !(ah)
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
	
	push pbx
	ASSUME pbx:PTR BPForm
	mov pbx, BPFormPtr
	
	mov al, MouseMode
	mov [pbx].MouseMode, al
	
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
			invoke SetCursorPos, [pbx].ScreenCnt.x, [pbx].ScreenCnt.y
		.ENDIF
	.ENDIF
	ASSUME pbx:nothing
	pop pbx
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
	IFDEF DEVMODEAFIX
		LOCAL devMode:DEVMODEAFIX, best:DEVMODEAFIX
	ELSE
		LOCAL devMode:DEVMODEA, best:DEVMODEA
	ENDIF
	LOCAL sizeDiff[2]:DWORD, aspect:REAL4, aspectDiff:DWORD, bestScore:DWORD
	LOCAL found:BPBool, namePtr:BPPtr
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	mov eax, [pcx].DisplayDevice
	mov ecx, SIZEOF BPDisplayDevice
	mul ecx
	lea pax, bpDisplayDevices[pax].RawName
	mov namePtr, pax
	ASSUME pcx:nothing
	
	
	IFDEF DEVMODEAFIX
		mov devMode.dmSize, SIZEOF DEVMODEAFIX
	ELSE
		mov devMode.dmSize, SIZEOF DEVMODEA
	ENDIF
	invoke EnumDisplaySettingsA, namePtr, ENUM_CURRENT_SETTINGS, ADDR devMode
	mov pcx, ResPtr
	bpMEM32 devMode.dmPelsWidth, DWORD PTR [pcx]
	bpMEM32 devMode.dmPelsHeight, DWORD PTR [pcx+4]
	
	
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
				fimul DWORD PTR [psp] ;?
				add psp, SIZEOF BPPtr
				fistp aspectDiff
			
				mov eax, aspectDiff
				add eax, sizeDiff[0]
			.ELSE
				mov eax, sizeDiff[0]
			.ENDIF
			add eax, sizeDiff[4]
			
			.IF (!found || eax < bestScore)
				mov bestScore, eax
				IFDEF DEVMODEAFIX
					invoke RtlMoveMemory, ADDR best, ADDR devMode, \
					SIZEOF DEVMODEAFIX
				ELSE
					invoke RtlMoveMemory, ADDR best, ADDR devMode, \
					SIZEOF DEVMODEA
				ENDIF
				mov found, TRUE
			.ENDIF
			
			inc ebx
			jmp bpSetResolutionEnum
		.ENDIF
		pop pbx
		
		mov pcx, ResPtr
		bpMEM32 DWORD PTR [pcx], best.dmPelsWidth
		bpMEM32 DWORD PTR [pcx+4], best.dmPelsHeight
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
	bpMEM32 winW, [pcx].ScreenSize.x
	bpMEM32 winH, [pcx].ScreenSize.y
	
	mov ecx, 2
	
	mov eax, winW
	xor edx, edx
	div ecx
	mov winW, eax
	push pax
	mov eax, winH
	xor edx, edx
	div ecx
	mov winH, eax
	
	mov pcx, BPFormPtr
	add eax, [pcx].ScreenPos.y
	mov [pcx].ScreenCnt.y, eax
	pop pax
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
	push pbx
	ASSUME pbx:PTR BPForm
	mov pbx, BPFormPtr
	
	.IF ([pbx].WindowMode == BP_WINDOW_MODE_FULLSCREEN)
		; Dubiously necessary
		; I stole the modes from Godot but didn't even check how they work smh
		.IF (WindowMode != BP_WINDOW_MODE_WINDOWED)
			invoke bpSetWindowMode, pbx, BP_WINDOW_MODE_WINDOWED
		.ENDIF
	.ELSEIF ([pbx].WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
		invoke SetWindowLongA, [pbx].Handle, GWL_STYLE, [pbx].WindowStyle
		invoke ChangeDisplaySettingsA, NULL, 0
		; the proper? way to change back would be:
		;mov pcx, BPFormPtr
		;mov pax, [pbx].DisplayDevice
		;mov pcx, SIZEOF BPDisplayDevice
		;mul pcx
		;lea pax, bpDisplayDevices[pax].ScreenSize
		;invoke bpSetResolution, BPFormPtr, pax, FALSE
	.ENDIF
	
	mov al, WindowMode
	mov [pbx].WindowMode, al
	
	.IF (WindowMode == BP_WINDOW_MODE_WINDOWED)
		invoke SetWindowLongA, [pbx].Handle, GWL_STYLE, [pbx].WindowStyle
		
		invoke SetWindowPos, [pbx].Handle, HWND_TOPMOST, [pbx].WindowPos.x, \
		[pbx].WindowPos.y, [pbx].WindowSize.x, [pbx].WindowSize.y, \
		SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
		
		invoke ShowWindow, [pbx].Handle, SW_RESTORE
	.ELSEIF (WindowMode == BP_WINDOW_MODE_MINIMIZED)
		invoke ShowWindow, [pbx].Handle, SW_MINIMIZE
	.ELSEIF (WindowMode == BP_WINDOW_MODE_MAXIMIZED)
		invoke ShowWindow, [pbx].Handle, SW_MAXIMIZE
	.ELSEIF (WindowMode == BP_WINDOW_MODE_FULLSCREEN) || \
	(WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
		.IF ([pbx].WindowMode != BP_WINDOW_MODE_MAXIMIZED)
			invoke bpUpdateWindowPos, BPFormPtr
		.ENDIF
		
		.IF (WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
			invoke bpSetResolution, pbx, ADDR [pbx].ScreenSize, FALSE
		.ENDIF
	
		bpMEM32 scrSize.x, [pbx].ScreenSize.x
		bpMEM32 scrSize.y, [pbx].ScreenSize.y
		; This here sends a WM_SIZE with weird additions
		invoke SetWindowLongA, [pbx].Handle, GWL_STYLE, WS_POPUP
		
		mov eax, [pbx].DisplayDevice
		mov edx, SIZEOF BPDisplayDevice
		mul edx
		.IF (WindowMode == BP_WINDOW_MODE_FULLSCREEN)
			mov ecx, bpDisplayDevices[pax].ScreenSize.x
			mov scrSize.x, ecx
			mov ecx, bpDisplayDevices[pax].ScreenSize.y
			mov scrSize.y, ecx
		.ENDIF
		
		invoke SetWindowPos, [pbx].Handle, HWND_TOPMOST, \
		bpDisplayDevices[pax].ScreenPos.x, bpDisplayDevices[pax].ScreenPos.y, \
		scrSize.x, scrSize.y, SWP_NOZORDER or SWP_FRAMECHANGED or SWP_SHOWWINDOW
	.ENDIF
	
	invoke UpdateWindow, [pbx].Handle
	
	ASSUME pbx:nothing
	pop pbx
	ret
bpSetWindowMode ENDP

;   Set window position (unadjusted for client) of a form to specified value.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   X:DWORD - new window X (left) position.
;   Y:DWORD - new window Y (top) position.
bpSetWindowPos PROC EXPORT BPFormPtr:BPPtr, X:SDWORD, Y:SDWORD
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	bpMEM32 [pcx].WindowPos.x, X
	bpMEM32 [pcx].WindowPos.y, Y
	
	mov pcx, BPFormPtr
	invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, X, Y, 0, 0, \
	SWP_NOSIZE or SWP_NOZORDER or SWP_SHOWWINDOW
	
	ASSUME pcx:nothing
	ret
bpSetWindowPos ENDP

;   Sets window size (unadjusted for client) of a form to specified value.
;   BPFormPtr:BPPtr - pointer to a form structure.
;   X:DWORD - new window width.
;   Y:DWORD - new window height.
bpSetWindowSize PROC EXPORT BPFormPtr:BPPtr, X:DWORD, Y:DWORD
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	bpMEM32 [pcx].WindowSize.x, X
	bpMEM32 [pcx].WindowSize.y, Y
	
	mov pcx, BPFormPtr
	; Just don't call this asshole in OnCreate
	invoke SetWindowPos, [pcx].Handle, HWND_TOPMOST, 0, 0, X, Y, \
	SWP_NOMOVE or SWP_NOZORDER or SWP_SHOWWINDOW
	
	ASSUME pcx:nothing
	ret
bpSetWindowSize ENDP

;   Update bpDisplayDevices.
bpUpdateDisplayDevices PROC EXPORT
	IFDEF DEVMODEAFIX
		LOCAL devMode:DEVMODEAFIX
	ELSE
		LOCAL devMode:DEVMODEA
	ENDIF
	LOCAL dispDev:DISPLAY_DEVICEA
	
	mov bpDisplayDeviceCount, 0
	IFDEF DEVMODEAFIX
		mov devMode.dmSize, SIZEOF DEVMODEAFIX
	ELSE
		mov devMode.dmSize, SIZEOF DEVMODEA
	ENDIF
	mov dispDev.cb, SIZEOF DISPLAY_DEVICEA
	
	bpUpdateDisplayDevicesEnum:
	invoke EnumDisplayDevicesA, NULL, bpDisplayDeviceCount, ADDR dispDev, 0 
	.IF (al)
		.IF (dispDev.StateFlags & DISPLAY_DEVICE_ACTIVE)
			invoke EnumDisplaySettingsA, ADDR dispDev.DeviceName, \
			ENUM_REGISTRY_SETTINGS, ADDR devMode
			
			mov eax, bpDisplayDeviceCount
			mov ecx, SIZEOF BPDisplayDevice
			mul ecx
			mov bpDisplayDevices[pax].Active, TRUE
			
			; Need a portrait-default monitor to test this, but should be ok
			mov ecx, devMode.dmPelsWidth
			.IF (ecx > devMode.dmPelsHeight)
				mov bpDisplayDevices[pax].Orientation, BP_ORIENTATION_LANDSCAPE
			.ELSE
				mov bpDisplayDevices[pax].Orientation, BP_ORIENTATION_PORTRAIT
			.ENDIF
			IFNDEF DMDO_180
				DMDO_180 EQU 2
			ENDIF
			.IF (devMode.dmDisplayOrientation == DMDO_180)
				add bpDisplayDevices[pax].Orientation, 2
			.ENDIF
			
			mov pcx, pax
			bpMEM32 bpDisplayDevices[pcx].RefreshRate, devMode.dmDisplayFrequency
			bpMEM32 bpDisplayDevices[pcx].ScreenPos.x, devMode.dmPosition.x
			bpMEM32 bpDisplayDevices[pcx].ScreenPos.y, devMode.dmPosition.y
			bpMEM32 bpDisplayDevices[pcx].ScreenSize.x, devMode.dmPelsWidth
			bpMEM32 bpDisplayDevices[pcx].ScreenSize.y, devMode.dmPelsHeight
			lea pcx, bpDisplayDevices[pcx].RawName
			invoke RtlMoveMemory, pcx, ADDR dispDev.DeviceName, 32
		.ELSE
			mov eax, bpDisplayDeviceCount
			mov ecx, SIZEOF BPDisplayDevice
			mul ecx
			mov bpDisplayDevices[pax].Active, FALSE
		.ENDIF
		inc bpDisplayDeviceCount
		jmp bpUpdateDisplayDevicesEnum
	.ENDIF
	ret
bpUpdateDisplayDevices ENDP

;   Update bpJoysticks to then capture their input.
bpUpdateJoysticks PROC EXPORT
	IFDEF JOYINFOFIX
		LOCAL joyInfo:JOYINFOFIX
	ELSE
		LOCAL joyInfo:JOYINFO
	ENDIF
	IFDEF JOYCAPSAFIX
		LOCAL joyCaps:JOYCAPSAFIX
	ELSE
		LOCAL joyCaps:JOYCAPS
	ENDIF
	
	IFDEF joyConfigChanged
		invoke joyConfigChanged, 0
	ENDIF
	
	call joyGetNumDevs
	mov bpJoyCount, eax
	
	push pbx
	xor ebx, ebx
	.WHILE (ebx < bpJoyCount)
		invoke joyGetPos, ebx, ADDR joyInfo
		.IF (pax == JOYERR_NOERROR)
			IFDEF JOYCAPSAFIX
				invoke joyGetDevCaps, ebx, ADDR joyCaps, SIZEOF JOYCAPSAFIX
			ELSE
				invoke joyGetDevCaps, ebx, ADDR joyCaps, SIZEOF JOYCAPS
			ENDIF
			
			mov pax, pbx
			mov pcx, SIZEOF BPJoystick
			mul pcx
			mov pcx, pax
			mov bpJoysticks[pcx].Active, TRUE
			bpMPM bpJoysticks[pcx].VendorId, joyCaps.wMid
			bpMPM bpJoysticks[pcx].ProductId, joyCaps.wPid
			bpMEM32 bpJoysticks[pcx].NumAxes, joyCaps.wNumAxes
			bpMEM32 bpJoysticks[pcx].NumButtons, joyCaps.wNumButtons
			invoke RtlMoveMemory, ADDR bpJoysticks[pcx].RawName, \
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
	
	bpMEM32 [pcx].WindowPos.x, winRect.left
	bpMEM32 [pcx].WindowPos.y, winRect.top

	ASSUME pcx:nothing
	ret
bpUpdateWindowPos ENDP

;   The default fixed timer callback procedure (TimeProc).
bpDefFixedProc PROC EXPORT lpParameter:LPVOID
	IFDEF BP_FIXED_BUSY
		LOCAL threadTimer:REAL4, lastTick:BPDelta, deltaFixed:REAL4
		LOCAL tick:LARGE_INTEGER
		mov threadTimer, 0
	ENDIF
	
	ASSUME pcx:PTR BPForm
	.WHILE (TRUE)
		IFDEF BP_FIXED_BUSY
			invoke bpCalculateDelta, ADDR lastTick, ADDR deltaFixed
			
			fld threadTimer
			fadd deltaFixed
			fld bpFixedInterval
			
			IF @Cpu and BP_CPU_686
				fcomip st, st(1)
			ELSE
				fcom
				fnstsw ax
				bt ax, 8
			ENDIF
			.IF (Carry?)
				fsub
				fstp threadTimer
		ELSE
			push 1000
			fild BPPtr PTR [psp]
			fmul bpFixedInterval
			fistp DWORD PTR [psp]
			call Sleep
		ENDIF
			mov pcx, lpParameter
			call [pcx].OnFixed
		IFDEF BP_FIXED_BUSY
			.ELSE
				fstp st(0)
				fstp threadTimer
			.ENDIF
		ENDIF
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
	
	;   pbx needs to be preserved and as such bloats the code on bound procedure
	; calls. pax is, well, pax. pcx and pdx are used in the dreaded x64 calling
	; convention. I don't even know anymore.
	ASSUME pax:PTR BPForm
	ASSUME pcx:PTR BPForm
	
	mov pcx, dwRefData
	mov [pcx].DefaultFlag, TRUE
	.IF (uMsg == WM_DESTROY)
		.IF ([pcx].OnDestroy)
			call [pcx].OnDestroy
			mov pcx, dwRefData
		.ENDIF
		.IF ([pcx].DefaultFlag)
			.IF ([pcx].WindowMode == BP_WINDOW_MODE_FULLSCREEN_EX)
				invoke bpSetWindowMode, dwRefData, BP_WINDOW_MODE_WINDOWED
				mov pcx, dwRefData
			.ENDIF
			.IF ([pcx].GraphicsContext)
				invoke wglDeleteContext, [pcx].GraphicsContext
				mov pcx, dwRefData
			.ENDIF
			.IF ([pcx].DeviceContext)
				mov pax, pcx
				invoke ReleaseDC, [pax].Handle, [pax].DeviceContext
			.ENDIF
			invoke PostQuitMessage, 0
		.ENDIF
		
	.ELSEIF (uMsg == WM_DEVICECHANGE)
		.IF ([pcx].InputFlags & BP_IF_JOYSTICK)
			.IF (wParam == 7)	; DBT_DEVNODES_CHANGED
				call bpUpdateDisplayDevices
				call bpUpdateJoysticks
			.ENDIF
		.ELSEIF ([pcx].InputFlags & BP_IF_RAW_JOYSTICK)
			mov al, [pcx].InputFlags
			and al, not BP_IF_RAW_JOYSTICK
			invoke bpSetInputFlags, pcx, al
			mov pcx, dwRefData
			mov al, [pcx].InputFlags
			or al, BP_IF_RAW_JOYSTICK
			invoke bpSetInputFlags, pcx, al
		.ENDIF
	
	.ELSEIF (uMsg == WM_INPUT)
		.IF ([pcx].OnInput && [pcx].Focused)
			invoke bpInRaw, dwRefData, lParam
		.ENDIF
	
	.ELSEIF (uMsg == WM_KEYDOWN)
		.IF ([pcx].OnInput)
			invoke bpInKey, dwRefData, wParam, TRUE
		.ENDIF
	.ELSEIF (uMsg == WM_KEYUP)
		.IF ([pcx].OnInput)
			invoke bpInKey, dwRefData, wParam, FALSE
		.ENDIF
		
	.ELSEIF (uMsg == WM_KILLFOCUS)
		mov [pcx].Focused, FALSE
	.ELSEIF (uMsg == WM_SETFOCUS)
		mov [pcx].Focused, TRUE
		
	.ELSEIF (uMsg == WM_MOVE)
		.IF ([pcx].WindowMode == BP_WINDOW_MODE_WINDOWED)
			invoke bpUpdateWindowPos, dwRefData
		.ENDIF
		mov pax, lParam
		movsx eax, ax
		mov [pcx].ScreenPos.x, eax
		mov pax, lParam
		shr eax, 16
		movsx eax, ax
		mov [pcx].ScreenPos.y, eax
		
		IFDEF BP_ONRESIZE_MOVE
		.IF ([pcx].OnResize)
			call [pcx].OnResize
			mov pcx, dwRefData
		.ENDIF
		ENDIF
		
		.IF ([pcx].DefaultFlag)
			invoke bpSetScreenCenter, dwRefData
		.ENDIF
		
	.ELSEIF (uMsg == WM_PAINT)		
		.IF !([pcx].InputFlags & BP_IF_RAW_MOUSE) && ([pcx].Focused)
			.IF ([pcx].OnInput)
				invoke GetCursorPos, ADDR bpMouseScreen
				mov eax, bpMouseScreenPrev[0]
				mov edx, bpMouseScreenPrev[4]
				.IF (bpMouseScreen[0] != eax) || (bpMouseScreen[4] != edx)
					bpMEM32 bpMouseClient[0], bpMouseScreen[0]
					bpMEM32 bpMouseClient[4], bpMouseScreen[4]
					mov pcx, dwRefData
					invoke ScreenToClient, [pcx].Handle, ADDR bpMouseClient
					
					invoke bpInMouseMove, dwRefData
				.ENDIF
				mov pcx, dwRefData
			.ENDIF
			.IF ([pcx].MouseMode == BP_MOUSE_MODE_LOCKED)
				mov pax, pcx
				invoke SetCursorPos, [pax].ScreenCnt.x, [pax].ScreenCnt.y
				mov pcx, dwRefData
				bpMEM32 bpMouseScreenPrev[0], [pcx].ScreenCnt.x
				bpMEM32 bpMouseScreenPrev[4], [pcx].ScreenCnt.y
				bpMEM32 bpMouseClientPrev[0], [pcx].ScreenCnt.x
				bpMEM32 bpMouseClientPrev[4], [pcx].ScreenCnt.y
				invoke ScreenToClient, [pcx].Handle, ADDR bpMouseClientPrev
				mov pcx, dwRefData
			.ELSE
				bpMEM32 bpMouseScreenPrev[0], bpMouseScreen[0]
				bpMEM32 bpMouseScreenPrev[4], bpMouseScreen[4]
			.ENDIF
		.ENDIF
		
		invoke bpCalculateDelta, ADDR bpLastTick, ADDR deltaUnscaled
		fld deltaUnscaled
		fld st
		fmul deltaScale
		fstp deltaTime

		fadd timeStart
		fstp timeStart
		
		mov pcx, dwRefData
		mov [pcx].DefaultFlag, TRUE
		.IF ([pcx].OnRender) && (bpFirstFrameSkipped)
			call [pcx].OnRender
			mov pcx, dwRefData
		.ELSE
			mov bpFirstFrameSkipped, TRUE
			.IF ([pcx].OnStart)
				call [pcx].OnStart
				mov pcx, dwRefData
			.ENDIF
		.ENDIF
		
		.IF ([pcx].DefaultFlag)
			mov [pcx].DefaultFlag, FALSE
			invoke SwapBuffers, [pcx].DeviceContext
			mov pcx, dwRefData
			.IF ([pcx].InputFlags & BP_IF_JOYSTICK)
				invoke bpReadJoysticks, dwRefData
			.ENDIF
		.ENDIF
		
	.ELSEIF (uMsg == WM_SIZE)
		.IF ([pcx].WindowMode != BP_WINDOW_MODE_FULLSCREEN) && \
		([pcx].WindowMode != BP_WINDOW_MODE_FULLSCREEN_EX)
			.IF (wParam == SIZE_RESTORED)
				mov [pcx].WindowMode, BP_WINDOW_MODE_WINDOWED
			.ELSEIF (wParam == SIZE_MINIMIZED)
				mov [pcx].WindowMode, BP_WINDOW_MODE_MINIMIZED
			.ELSEIF (wParam == SIZE_MAXIMIZED)
				mov [pcx].WindowMode, BP_WINDOW_MODE_MAXIMIZED
			.ENDIF
		.ELSEIF ([pcx].WindowMode == BP_WINDOW_MODE_WINDOWED)
			invoke bpUpdateWindowPos, dwRefData	; will have dwRefData in pcx
		.ENDIF
		
		mov pax, lParam
		movsx eax, ax
		mov [pcx].ScreenSize.x, eax
		mov pax, lParam
		shr eax, 16
		movsx eax, ax
		mov [pcx].ScreenSize.y, eax
		.IF ([pcx].ScreenSize.y)	; Some basic invalid operation prevention
			fild [pcx].ScreenSize.x
			fidiv [pcx].ScreenSize.y
			fstp [pcx].Aspect
		.ENDIF
		
		.IF ([pcx].OnResize)
			call [pcx].OnResize
			mov pcx, dwRefData
		.ENDIF
		
		.IF ([pcx].DefaultFlag)
			.IF ([pcx].GraphicsContext)
				mov pax, pcx
				invoke glViewport, 0, 0, [pax].ScreenSize.x, [pax].ScreenSize.y
			.ENDIF
			invoke bpSetScreenCenter, dwRefData
		.ENDIF
		
	.ELSEIF (uMsg == WM_SYSKEYDOWN)
		.IF ([pcx].OnInput)
			invoke bpInKey, dwRefData, wParam, TRUE
		.ENDIF
		
	.ELSEIF (uMsg == WM_SYSKEYUP)
		.IF ([pcx].OnInput)
			invoke bpInKey, dwRefData, wParam, FALSE
		.ENDIF
		
		
	; This down here is rancid but compatibility I guess
	.ELSEIF (uMsg == WM_LBUTTONDOWN)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			invoke bpInMouseButton, dwRefData, VK_LBUTTON, TRUE
		.ENDIF
	.ELSEIF (uMsg == WM_LBUTTONUP)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			invoke bpInMouseButton, dwRefData, VK_LBUTTON, FALSE
		.ENDIF
	.ELSEIF (uMsg == WM_RBUTTONDOWN)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			invoke bpInMouseButton, dwRefData, VK_RBUTTON, TRUE
		.ENDIF
	.ELSEIF (uMsg == WM_RBUTTONUP)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			invoke bpInMouseButton, dwRefData, VK_RBUTTON, FALSE
		.ENDIF
	.ELSEIF (uMsg == WM_MBUTTONDOWN)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			invoke bpInMouseButton, dwRefData, VK_MBUTTON, TRUE
		.ENDIF
	.ELSEIF (uMsg == WM_MBUTTONUP)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			invoke bpInMouseButton, dwRefData, VK_MBUTTON, FALSE
		.ENDIF
	.ELSEIF (uMsg == WM_XBUTTONDOWN)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			mov pax, wParam
			shr eax, 16
			movsx eax, ax
			add eax, 4
			invoke bpInMouseButton, dwRefData, eax, TRUE
		.ENDIF
	.ELSEIF (uMsg == WM_XBUTTONUP)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			mov pax, wParam
			shr eax, 16
			movsx eax, ax
			add eax, 4
			invoke bpInMouseButton, dwRefData, eax, FALSE
		.ENDIF
	.ELSEIF (uMsg == WM_MOUSEWHEEL)
		.IF ([pcx].OnInput) && !([pcx].InputFlags & BP_IF_RAW_MOUSE)
			mov pax, wParam
			shr eax, 16
			movsx eax, ax
			.IF (SDWORD PTR eax > 0)
				invoke bpInMouseButton, pcx, VK_MWHEEL_UP, TRUE
			.ELSE
				invoke bpInMouseButton, pcx, VK_MWHEEL_DOWN, TRUE
			.ENDIF
		.ENDIF
	;.ELSEIF (uMsg == WM_ERASEBKGND)
		;mov pax, 1
		;mov [pcx].DefaultFlag, FALSE
	.ENDIF

	mov pcx, dwRefData
	.IF ([pcx].DefaultFlag)
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
	.ENDIF
	
	ASSUME pcx:nothing
	ASSUME pax:nothing
	ret
bpDefWndProc ENDP
