;
;   BP3D Software Demo
;
;   Attempts to use pure Win32 GDI for rendering, but doesn't do double-
; buffering. Results may vary from system to system, FLASHING LIGHTS WARNING.
;
;   Copyright (c) 2026 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;


.386
.model flat, stdcall
option casemap:none

include ..\..\src\BP3D.asm
include ..\..\src\BP3DMaths.inc
include ..\..\src\BP3DVectors.inc

CUBE_SHADOW_COUNT	EQU 16
CUBE_SHADOW_DECAY	EQU 255/CUBE_SHADOW_COUNT

.DATA
Rendering BPBool FALSE
FMain BPForm <>

CubePos Vector2 <250.0, 250.0>
CubeRot REAL4 0.0
CubeVel Vector2 <160.0, 160.0>
CubeVer	Vector2	<-1.0, -1.0>,\
				<1.0,  -1.0>,\
				<1.0,   1.0>,\
				<-1.0,  1.0>
CubeShadow Vector3 CUBE_SHADOW_COUNT DUP (<250.0, 250.0, 0.0>)

.CODE
DrawCube PROC EXPORT Context:HDC, Pos:BPPtr, Angle:REAL4, Scale:DWORD, \
Process:BPBool
	LOCAL sinCos:Vector2, drawPos:Vector2
	
	fld Angle
	fsincos
	fimul Scale
	fstp sinCos.Y	; cos
	fimul Scale
	fstp sinCos.X	; sin
	
	push pbx
	xor pbx, pbx
	.WHILE (pbx <= SIZEOF CubeVer)
		mov pax, Pos
		
		.IF (pbx == SIZEOF CubeVer)
			mov pcx, 0
		.ELSE
			mov pcx, pbx
		.ENDIF
		
		fld CubeVer[pcx].X
		fld st
		fmul sinCos.Y
		fld CubeVer[pcx].Y
		fmul sinCos.X
		fsub
		fadd REAL4 PTR [pax]
		fistp drawPos.X
		fmul sinCos.X
		fld CubeVer[pcx].Y
		fmul sinCos.Y
		fadd
		fadd REAL4 PTR [pax+4]
		fistp drawPos.Y
		
		.IF (Process)
			.IF !(bpR(intInRange, drawPos.X, 0, FMain.ScreenSize.x))
				.IF (SDWORD PTR drawPos.X < 0)
					mov eax, drawPos.X
					neg eax
				.ELSE
					mov eax, FMain.ScreenSize.x
					sub eax, drawPos.X
				.ENDIF
				
				push pax
				fild SDWORD PTR [psp]
				fadd CubePos.X
				fstp CubePos.X
				pop pax
				xor CubeVel.X, FLT_NEG
			.ENDIF
			
			.IF !(bpR(intInRange, drawPos.Y, 0, FMain.ScreenSize.y))
				.IF (SDWORD PTR drawPos.Y < 0)
					mov eax, drawPos.Y
					neg eax
				.ELSE
					mov eax, FMain.ScreenSize.y
					sub eax, drawPos.Y
				.ENDIF
				
				push pax
				fild SDWORD PTR [psp]
				fadd CubePos.Y
				fstp CubePos.Y
				pop pax
				xor CubeVel.Y, FLT_NEG
			.ENDIF
		.ENDIF
		
		.IF (pbx)
			invoke LineTo, Context, drawPos.X, drawPos.Y
		.ELSE
			invoke MoveToEx, Context, drawPos.X, drawPos.Y, NULL
		.ENDIF
		
		add pbx, SIZEOF Vector2
	.ENDW
	pop pbx
	
	ret
DrawCube ENDP

OnCreate PROC EXPORT
	ret
OnCreate ENDP

OnFixed PROC EXPORT
	.IF (!Rendering)
		invoke InvalidateRect, FMain.Handle, NULL, FALSE
		invoke UpdateWindow, FMain.Handle
	.ENDIF
	ret
OnFixed ENDP

OnInput PROC EXPORT BPInType:BYTE, BPInStruct:BPPtr
	mov pbx, BPInStruct
	.IF (BPInType == BP_INPUT_MOUSE_MOVE)
		ASSUME pbx:PTR BPInMouseMove
		
	.ELSEIF (BPInType == BP_INPUT_KEY) || (BPInType == BP_INPUT_MOUSE_BUTTON)
		ASSUME pbx:PTR BPInKey
		
	.ENDIF
	ASSUME pbx:nothing
	ret
OnInput ENDP

OnRender PROC EXPORT
	LOCAL ps:PAINTSTRUCT, hdc:HDC, penOld:HPEN, pen:HPEN, rect:RECT, shCol:DWORD
	
	mov Rendering, TRUE
	
	; Processing
	mov pdx, (CUBE_SHADOW_COUNT-1)*SIZEOF Vector3
	.WHILE (pdx)
		invoke Vector3Copy, ADDR CubeShadow[pdx], \
		ADDR CubeShadow[pdx-SIZEOF Vector3]
		sub pdx, SIZEOF Vector3
	.ENDW
	invoke Vector3Copy, ADDR CubeShadow, ADDR CubePos	; <X, Y, Rot>
	
	fld CubeVel.X
	fmul deltaTime
	fadd CubePos.X
	fstp CubePos.X
	fld CubeVel.Y
	fmul deltaTime
	fadd CubePos.Y
	fstp CubePos.Y
	bpMEM32 CubeRot, timeStart
	
	; Rendering
	; Setup paint
	mov hdc, bpR(BeginPaint, FMain.Handle, ADDR ps)
	
	; Draw stuff
	invoke GetClientRect, FMain.Handle, ADDR rect
	invoke CreateSolidBrush, 0
	invoke FillRect, hdc, ADDR rect, pax
	
	push pbx
	mov pbx, (CUBE_SHADOW_COUNT-1)*SIZEOF Vector3
	mov shCol, 0
	.WHILE (pbx)
		mov eax, shCol
		shl eax, 16
		mov pen, bpR(CreatePen, PS_SOLID, 7, eax)
		mov penOld, bpR(SelectObject, hdc, pen)
		invoke DrawCube, hdc, ADDR CubeShadow[pbx], CubeShadow[pbx].Z, 64, FALSE
		invoke SelectObject, hdc, penOld
		invoke DeleteObject, pen
		
		sub pbx, SIZEOF Vector3
		add shCol, CUBE_SHADOW_DECAY
	.ENDW
	pop pbx
	mov pen, bpR(CreatePen, PS_SOLID, 7, 00ff0000h)
	mov penOld, bpR(SelectObject, hdc, pen)
	invoke DrawCube, hdc, ADDR CubePos, CubeRot, 64, TRUE
	
	invoke SelectObject, hdc, penOld
	
	invoke DeleteObject, pen
	invoke EndPaint, FMain.Handle, ADDR ps
	
	mov Rendering, FALSE
	ret
OnRender ENDP

start:
	mov FMain.OnCreate, OFFSET OnCreate
	mov FMain.OnFixed, OFFSET OnFixed
	mov FMain.OnInput, OFFSET OnInput
	mov FMain.OnRender, OFFSET OnRender
	mov FMain.WindowSize.x, 800
	mov FMain.WindowSize.y, 600
	invoke bpCreateForm, ADDR FMain
	
	; Form processing exited, safely terminate process
	invoke TerminateProcess, bpR(GetCurrentProcess), 0
end start