;
;   BP3D Transparent Demo
;
;   Is supposed to demonstrate form transformation and use some specific Win32
; functions to make it transparent. Doesn't work with Wine.
;
;   Copyright (c) 2026 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

.386
.model flat, stdcall
option casemap:none

include ..\..\src\BP3D.asm

include include\masm32.inc
includelib masm32.lib
include include\msvcrt.inc
includelib msvcrt.lib

include macros\macros.asm

include ..\..\src\BP3DMaths.inc
include ..\..\src\BP3DVectors.inc
include ..\..\src\BP3DAssets.inc
include ..\..\src\BP3DGLPlus.inc
.DATA
FMain BPForm <>

Dragging BPBool FALSE

Model BPMesh <>
ModelTexture DWORD 0
ModelRot Vector2 <>

WindowPos Vector2 <0.0, 0.0>
WindowVel Vector2 <256.0, 256.0>
WindowVelT Vector2 <256.0, 256.0>

.CODE

FlDampedSpring PROC EXPORT Velocity:BPPtr, Val:REAL4, ValTarget:REAL4,
Stiffness:REAL4, Damping:REAL4, T:REAL4
	fld ValTarget
	fsub Val
	fmul Stiffness
	mov pax, Velocity
	fld REAL4 PTR [pax]
	fmul Damping
	fsub
	fmul T
	fadd REAL4 PTR [pax]
	fstp REAL4 PTR [pax]
	ret
FlDampedSpring ENDP

OnCreate PROC EXPORT
	invoke bpInitGLContext, ADDR FMain
	
	
	LoadBPM ADDR Model, "gc.bpm"
	mov bpTextureFiltering, TRUE
	LoadBPT ADDR ModelTexture, "gc.bpt"
	mov bpTextureFiltering, FALSE
	ret
OnCreate ENDP

OnInput PROC EXPORT BPInType:BYTE, BPInStruct:BPPtr
	mov pbx, BPInStruct
	.IF (BPInType == BP_INPUT_MOUSE_MOVE)
		ASSUME pbx:PTR BPInMouseMove
		
	.ELSEIF (BPInType == BP_INPUT_KEY) || (BPInType == BP_INPUT_MOUSE_BUTTON)
		ASSUME pbx:PTR BPInKey
		.IF ([pbx].Pressed)
			.IF ([pbx].Keycode == VK_LBUTTON)
				mov Dragging, TRUE
			.ELSEIF ([pbx].Keycode == VK_RBUTTON)
				invoke bpDestroyForm, ADDR FMain
			.ENDIF
		.ENDIF
	.ENDIF
	ASSUME pbx:nothing
	ret
OnInput ENDP

OnRender PROC EXPORT
	LOCAL scrHalf:Vector2, flVal:REAL4
	
	mov eax, FMain.ScreenSize.x
	shr eax, 1
	mov scrHalf.X, eax
	mov eax, FMain.ScreenSize.y
	shr eax, 1
	mov scrHalf.Y, eax
	
	fild scrHalf.X
	fiadd FMain.WindowPos.x
	fild bpDisplayDevices[0].ScreenSize.x
	fmul f(0.5)
	fsub
	fmul f(0.05)
	fstp ModelRot.X
	fild scrHalf.Y
	fiadd FMain.WindowPos.y
	fild bpDisplayDevices[0].ScreenSize.y
	fmul f(0.5)
	fsubr
	fmul f(0.05)
	fstp ModelRot.Y
	
	.IF (Dragging)
		fild bpMouseScreen[0]
		fisub scrHalf.X
		fstp flVal
		invoke FlDampedSpring, ADDR WindowVel.X, WindowPos.X, flVal, \
		f(64.0), f(2.0), deltaTime
		fild bpMouseScreen[4]
		fisub scrHalf.Y
		fstp flVal
		invoke FlDampedSpring, ADDR WindowVel.Y, WindowPos.Y, flVal, \
		f(64.0), f(2.0), deltaTime
		
		invoke GetAsyncKeyState, VK_LBUTTON
		.IF !(eax & 8000h)
			mov Dragging, FALSE
		.ENDIF
	.ELSE
		
		invoke Vector2Lerp, ADDR WindowVel, ADDR WindowVelT, deltaTime
	.ENDIF
	
	fld WindowVel.X
	fmul deltaTime
	fadd WindowPos.X
	fstp WindowPos.X
	fld WindowVel.Y
	fmul deltaTime
	fadd WindowPos.Y
	fstp WindowPos.Y
	
	fild bpDisplayDevices[0].ScreenSize.x
	fisub FMain.WindowSize.x
	fstp flVal
	.IF !(bpR(flInRange, WindowPos.X, 0, flVal))
		xor WindowVel.X, FLT_NEG
		xor WindowVelT.X, FLT_NEG
		mov WindowPos.X, bpR(flClamp, WindowPos.X, 0, flVal)
	.ENDIF
	fild bpDisplayDevices[0].ScreenSize.y
	fisub FMain.WindowSize.y
	fstp flVal
	.IF !(bpR(flInRange, WindowPos.Y, 0, flVal))
		xor WindowVel.Y, FLT_NEG
		xor WindowVelT.Y, FLT_NEG
		mov WindowPos.Y, bpR(flClamp, WindowPos.Y, 0, flVal)
	.ENDIF
	
	invoke Vector2Copy, ADDR FMain.WindowPos, ADDR WindowPos
	invoke Vector2RoundInt, ADDR FMain.WindowPos
	
	invoke bpSetWindowPos, ADDR FMain, FMain.WindowPos.x, FMain.WindowPos.y

	invoke glClear, GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
	invoke glClearColor3fv, ADDR clRed
	
	invoke glMatrixMode, GL_PROJECTION
	call glLoadIdentity
	
	invoke gluPerspectivef, f(60.0), FMain.Aspect, f(0.01), f(1000.0)
	
	invoke glMatrixMode, GL_MODELVIEW
	call glLoadIdentity
	
	invoke glTranslatef, 0, 0, f(-2.0)
	invoke glRotatef, ModelRot.X, 0, f(1.0), 0
	invoke glRotatef, ModelRot.Y, f(-1.0), 0, 0
	invoke glBindTexture, GL_TEXTURE_2D, ModelTexture
	invoke bpDrawMesh, ADDR Model
	ret
OnRender ENDP

OnStart PROC EXPORT
	invoke SetWindowLongA, FMain.Handle, GWL_EXSTYLE, WS_EX_LAYERED
	invoke SetWindowLongA, FMain.Handle, GWL_STYLE, WS_POPUP
	invoke SetWindowPos, FMain.Handle, HWND_TOPMOST, 0, 0, 256, 256, 0
	
	invoke SetLayeredWindowAttributes, FMain.Handle, 000000ffh, 0, LWA_COLORKEY
	ret
OnStart ENDP

start:
	mov FMain.OnCreate, OFFSET OnCreate
	mov FMain.OnInput, OFFSET OnInput
	mov FMain.OnRender, OFFSET OnRender
	mov FMain.OnStart, OFFSET OnStart
	mov FMain.WindowSize.x, 800
	mov FMain.WindowSize.y, 600
	invoke bpCreateForm, ADDR FMain
	
	; Form processing exited, safely terminate process
	invoke TerminateProcess, bpR(GetCurrentProcess), 0
end start