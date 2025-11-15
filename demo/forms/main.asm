;
;   BP3D Forms Demo
;
;   Demonstrates the usage of multiple asynchronous forms. Might not work well
; with X11.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

.386
.model flat, stdcall
option casemap:none

BP_COMPATIBILITY_W9X	EQU <1>	; Exclude unsupported APIs
BP_ONRESIZE_MOVE		EQU <1>	; Call OnResize on WM_MOVE

; BP3D includes
include ..\..\src\BP3D.asm
include ..\..\src\BP3DMaths.inc
include ..\..\src\BP3DGLPlus.inc

.CONST
Form1C DB "Form 1", 0	; FPrimary caption
Form2C DB "Form 2", 0	; FSecondary caption

LightDir REAL4 0.707, 0.707, 0.707, 0.0

.DATA
FPrimary	BPForm <>
FSecondary	BPForm <>

Sphere	BPPtr 0

QuitFlag	BPBool FALSE

;   Simple MASM rv replacement. Calls a PROC and returns pax.
;   ProcName:PROC - procedure name.
;   Args:VARARG - procedure arguments.
r MACRO ProcName:REQ,Args:VARARG
	procCall EQU <invoke ProcName>
	FOR var,<Args>
		procCall CATSTR procCall,<, var>
	ENDM
	procCall
	EXITM <pax>
ENDM

;   Simple MASM SADD replacement. Declares a string and returns its ADDR in pax.
;   qStr:String - quoted string.
s MACRO qStr:REQ
	LOCAL strDb
	.DATA
		strDb DB qStr,0
	.CODE
	EXITM <ADDR strDb>
ENDM


.CODE
; Clear buffers and setup projection (+viewport)
ClearProject PROC EXPORT BPFormPtr:BPPtr
	LOCAL aspect:REAL4
	
	ASSUME pcx:PTR BPForm
	mov pcx, BPFormPtr
	mov eax, [pcx].ScreenPos.x
	neg eax
	mov edx, [pcx].ScreenPos.y
	mov ecx, [pcx].ScreenSize.y
	add edx, ecx
	sub edx, bpDisplayDevices[0].ScreenSize.y
	invoke glViewport, eax, edx, bpDisplayDevices[0].ScreenSize.x, \
	bpDisplayDevices[0].ScreenSize.y
	ASSUME pcx:nothing
	
	invoke glClear, GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
	
	invoke glMatrixMode, GL_PROJECTION
	call glLoadIdentity
	
	fild bpDisplayDevices[0].ScreenSize.x
	fidiv bpDisplayDevices[0].ScreenSize.y
	fstp aspect
	invoke gluPerspectivef, f(60.0), aspect, f(0.01), f(1000.0)
	
	invoke glMatrixMode, GL_MODELVIEW
	call glLoadIdentity
	ret
ClearProject ENDP

; Setup GL parameters (light, material)
SetupGL PROC EXPORT
	invoke glMaterialf, GL_FRONT, GL_SHININESS, f(64.0)
	invoke glMaterialfv, GL_FRONT, GL_AMBIENT, ADDR clBlack
	invoke glMaterialfv, GL_FRONT, GL_DIFFUSE, ADDR clWhite
	invoke glMaterialfv, GL_FRONT, GL_SPECULAR, ADDR clWhite
	
	invoke glEnable, GL_LIGHTING
	invoke glEnable, GL_LIGHT0
	invoke glLightfv, GL_LIGHT0, GL_POSITION, ADDR LightDir
	ret
SetupGL ENDP

; Mutual bindings
OnResize PROC EXPORT
	; pcx is supposed to store the caller form
	ASSUME pcx:PTR BPForm
	mov [pcx].DefaultFlag, FALSE
	call [pcx].OnRender
	ASSUME pcx:nothing
	ret
OnResize ENDP

; FPrimary bindings
FPrimary_OnCreate PROC EXPORT
	invoke bpInitGLContext, ADDR FPrimary
	
	mov Sphere, r(gluNewQuadric)
	
	call SetupGL
	ret
FPrimary_OnCreate ENDP

FPrimary_OnFixed PROC EXPORT
	mov FSecondary.Caption,		OFFSET Form2C
	
	mov FSecondary.OnResize,	OFFSET OnResize
	mov FSecondary.OnCreate,	OFFSET FSecondary_OnCreate
	mov FSecondary.OnRender,	OFFSET FSecondary_OnRender
	
	invoke bpCreateForm, ADDR FSecondary	; Create form, block loop
	; FSecondary execution ended
	mov QuitFlag, TRUE
	ret
FPrimary_OnFixed ENDP

FPrimary_OnRender PROC EXPORT
	.IF (QuitFlag)
		invoke bpDestroyForm, ADDR FPrimary
		ret
	.ENDIF
	
	; Drawing
	invoke ClearProject, ADDR FPrimary
	invoke glTranslatef, 0, 0, f(-4)
	invoke gluSpheref, Sphere, f(1), 24, 48
	ret
FPrimary_OnRender ENDP

; FSecondary bindings
FSecondary_OnCreate PROC EXPORT	
	invoke bpInitGLContext, ADDR FSecondary
	call SetupGL
	ret
FSecondary_OnCreate ENDP

FSecondary_OnRender PROC EXPORT
	; Drawing
	invoke ClearProject, ADDR FSecondary
	invoke glTranslatef, 0, 0, f(-4)
	invoke gluSpheref, Sphere, f(1), 24, 48
	ret
FSecondary_OnRender ENDP

start:
	mov FPrimary.Caption,		OFFSET Form1C
	
	mov FPrimary.OnResize,		OFFSET OnResize
	mov FPrimary.OnCreate,		OFFSET FPrimary_OnCreate
	mov FPrimary.OnFixed,		OFFSET FPrimary_OnFixed
	mov FPrimary.OnRender,		OFFSET FPrimary_OnRender
	
	invoke bpCreateForm, ADDR FPrimary

	; This code is reached when forms' execution is done
	invoke TerminateProcess, r(GetCurrentProcess), 0
end start