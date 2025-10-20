;
;   BP3DGLPlus.inc
;   Version 0.5ac1
;   BP3D logical helper function additions to the OpenGL & GLU APIs extension.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

IFNDEF BP3D_GLPLUS_INC
BP3D_GLPLUS_INC EQU <1>

IFNDEF BP_GLU
BP_GLU EQU <1>
IFDEF BP_WININC
	include include\gl\glu.inc
	includelib glu32.lib
ELSEIFNDEF BP_CUSTOM_INCLUDES
	include include\glu32.inc
	includelib glu32.lib
ENDIF
ENDIF

IFDEF rax
	ECHO BP3D: WARNING! BP3DGLPlus.inc now only supports stdcall and is untested on x64.
ENDIF

GL_CLAMP_TO_EDGE			EQU 33071
GL_MULTISAMPLE				EQU 32925
GL_SAMPLE_ALPHA_TO_COVERAGE	EQU 32926
GL_UNSIGNED_BYTE_3_3_2		EQU 32818
GL_UNSIGNED_SHORT_5_6_5		EQU 33635

.CONST
bpGLPlusR2D	REAL4 57.29578

clBlack		REAL4	0.0,  0.0,  0.0,  1.0		; Some GL 0.0-1.0 colors
clBlue		REAL4	0.0,  0.0,  1.0,  1.0
clBrown		REAL4	0.5,  0.2,  0.0,  1.0
clDarkGray	REAL4	0.25, 0.25, 0.25, 1.0
clGray		REAL4	0.5,  0.5,  0.5,  1.0
clGreen		REAL4	0.0,  1.0,  0.0,  1.0
clLightGray	REAL4	0.75, 0.75, 0.75, 1.0
clRed		REAL4	1.0,  0.0,  0.0,  1.0
clYellow	REAL4	1.0,  1.0,  0.0,  1.0
clWhite		REAL4	1.0,  1.0,  1.0,  1.0

clHalf		REAL4	1.0,  1.0,  1.0,  0.5		; Alpha colors

.DATA?
IFNDEF BP_MULTITHREADED_CONTEXT
	bp3DDbl REAL8 ?
ENDIF

.CODE

;   Push Float as Double macro. Converts a float (single-precision/REAL4) value
; to a double-precision floating point value (REAL8) and pushes onto the stack,
; splitting it into two, if the stack is 32-bit.
pfad MACRO Single:REQ
	fld Single
	fstp bp3DDbl
	
	IFDEF rax
		push bp3DDbl
	ELSE
		push DWORD PTR bp3DDbl+4
		push DWORD PTR bp3DDbl
	ENDIF
ENDM

;   Push Integer as Double macro. Converts an integer (SDWORD) value to a 
; double-precision floating point value (REAL8) and pushes onto the stack, 
; splitting it into two, if the stack is 32-bit.
piad MACRO Integer:REQ
	fild Integer
	fstp bp3DDbl
	
	IFDEF rax
		push bp3DDbl
	ELSE
		push DWORD PTR bp3DDbl+4
		push DWORD PTR bp3DDbl
	ENDIF
ENDM

glClearDepthf PROC EXPORT depth:REAL4
	IFDEF BP_MULTITHREADED_CONTEXT
		LOCAL bp3DDbl:REAL8
	ENDIF
	pfad depth
	call glClearDepth
	ret
glClearDepthf ENDP

glClearColor3fv PROC EXPORT v:BPPtr
	mov pcx, v
	bpPush32 clWhite[12]
	bpPush32 REAL4 PTR [pcx+8]
	bpPush32 REAL4 PTR [pcx+4]
	bpPush32 REAL4 PTR [pcx]
	call glClearColor
	ret
glClearColor3fv ENDP

glClearColor4fv PROC EXPORT v:BPPtr
	mov pcx, v
	bpPush32 REAL4 PTR [pcx+12]
	bpPush32 REAL4 PTR [pcx+8]
	bpPush32 REAL4 PTR [pcx+4]
	bpPush32 REAL4 PTR [pcx]
	call glClearColor
	ret
glClearColor4fv ENDP

glOrthof PROC EXPORT left:REAL4, right:REAL4, bottom:REAL4, top:REAL4, \
nearVal:REAL4, farVal:REAL4
	IFDEF BP_MULTITHREADED_CONTEXT
		LOCAL bp3DDbl:REAL8
	ENDIF
	pfad farVal
	pfad nearVal
	pfad top
	pfad bottom
	pfad right
	pfad left
	call glOrtho
	ret
glOrthof ENDP

glScalei PROC EXPORT x:SDWORD, y:SDWORD, z:SDWORD
	sub esp, 12
	fild z
	fstp REAL4 PTR [esp+8]
	fild y
	fstp REAL4 PTR [esp+4]
	fild x
	fstp REAL4 PTR [esp]
	call glScalef
	ret
glScalei ENDP

glTranslatei PROC EXPORT x:SDWORD, y:SDWORD, z:SDWORD
	sub esp, 12
	fild z
	fstp REAL4 PTR [esp+8]
	fild y
	fstp REAL4 PTR [esp+4]
	fild x
	fstp REAL4 PTR [esp]
	call glTranslatef
	ret
glTranslatei ENDP

gluLookAtf PROC EXPORT eyeX:REAL4, eyeY:REAL4, eyeZ:REAL4, centerX:REAL4, \
centerY:REAL4, centerZ:REAL4, upX:REAL4, upY:REAL4, upZ:REAL4
	IFDEF BP_MULTITHREADED_CONTEXT
		LOCAL bp3DDbl:REAL8
	ENDIF
	pfad upZ
	pfad upY
	pfad upX
	pfad centerZ
	pfad centerY
	pfad centerX
	pfad eyeZ
	pfad eyeY
	pfad eyeX
	call gluLookAt
gluLookAtf ENDP

gluLookAtfv PROC EXPORT eyePos:BPPtr, centerPos:BPPtr, upVector:BPPtr
	IFDEF BP_MULTITHREADED_CONTEXT
		LOCAL bp3DDbl:REAL8
	ENDIF
	mov pax, upVector
	pfad REAL4 PTR [pax+8]
	pfad REAL4 PTR [pax+4]
	pfad REAL4 PTR [pax]
	mov pax, centerPos
	pfad REAL4 PTR [pax+8]
	pfad REAL4 PTR [pax+4]
	pfad REAL4 PTR [pax]
	mov pax, eyePos
	pfad REAL4 PTR [pax+8]
	pfad REAL4 PTR [pax+4]
	pfad REAL4 PTR [pax]
	call gluLookAt
gluLookAtfv ENDP

gluPerspectivef PROC EXPORT fovy:REAL4, aspect:REAL4, zNear:REAL4, zFar:REAL4
	IFDEF BP_MULTITHREADED_CONTEXT
		LOCAL bp3DDbl:REAL8
	ENDIF
	pfad zFar
	pfad zNear
	pfad aspect
	pfad fovy
	call gluPerspective
	ret
gluPerspectivef ENDP

gluOrtho2Df PROC EXPORT left:REAL4, right:REAL4, bottom:REAL4, top:REAL4
	IFDEF BP_MULTITHREADED_CONTEXT
		LOCAL bp3DDbl:REAL8
	ENDIF
	pfad top
	pfad bottom
	pfad right
	pfad left
	call gluOrtho2D
	ret
gluOrtho2Df ENDP

gluOrtho2Di PROC EXPORT left:SDWORD, right:SDWORD, bottom:SDWORD, top:SDWORD
	IFDEF BP_MULTITHREADED_CONTEXT
		LOCAL bp3DDbl:REAL8
	ENDIF
	piad top
	piad bottom
	piad right
	piad left
	call gluOrtho2D
	ret
gluOrtho2Di ENDP

glRotatefr PROC EXPORT angle:REAL4, x:REAL4, y:REAL4, z:REAL4
	fld angle
	fmul bpGLPlusR2D
	fstp angle
	invoke glRotatef, angle, x, y, z
	ret
glRotatefr ENDP

glRotate2fv PROC EXPORT v:BPPtr
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax], 1065353216, 0, 0
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+4], 0, 1065353216, 0
	ret
glRotate2fv ENDP

glRotate2fvr PROC EXPORT v:BPPtr
	LOCAL _Val:REAL4
	mov pax, v
	fld REAL4 PTR [pax]
	fmul bpGLPlusR2D
	fstp _Val
	invoke glRotatef, _Val, 1065353216, 0, 0
	mov pax, v
	fld REAL4 PTR [pax+4]
	fmul bpGLPlusR2D
	fstp _Val
	invoke glRotatef, _Val, 0, 1065353216, 0
	ret
glRotate2fvr ENDP

glRotate3fv PROC EXPORT v:BPPtr
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+8], 0, 0, 1065353216
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax], 1065353216, 0, 0
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+4], 0, 1065353216, 0
	ret
glRotate3fv ENDP

glRotate3fvr PROC EXPORT v:BPPtr
	LOCAL _Val:REAL4
	mov pax, v
	fld REAL4 PTR [pax+8]
	fmul bpGLPlusR2D
	fstp _Val
	invoke glRotatef, _Val, 0, 0, 1065353216
	mov pax, v
	fld REAL4 PTR [pax]
	fmul bpGLPlusR2D
	fstp _Val
	invoke glRotatef, _Val, 1065353216, 0, 0
	mov pax, v
	fld REAL4 PTR [pax+4]
	fmul bpGLPlusR2D
	fstp _Val
	invoke glRotatef, _Val, 0, 1065353216, 0
	ret
glRotate3fvr ENDP

glTranslate3fv PROC EXPORT v:BPPtr
	mov pax, v
	invoke glTranslatef, REAL4 PTR [pax], REAL4 PTR [pax+4], REAL4 PTR [pax+8]
	ret
glTranslate3fv ENDP
ELSE
	ECHO BP3D: Duplicate include file BP3DGLPlus.inc
ENDIF
