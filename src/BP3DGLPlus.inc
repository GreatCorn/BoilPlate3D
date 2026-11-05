;
;   BP3DGLPlus.inc
;   Version 0.9ac1
;   BP3D helper function additions to the OpenGL & GLU APIs extension.
;   Fundamentally built around the stdcall calling convention, but contains
; nonetheless useful data.
;   Is available for independent importing without main BP3D.
;
;   Copyright (c) 2025-2026 Yevhenii Ionenko (aka GreatCorn).
;   All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

IFNDEF BP3D_GLPLUS_INC
BP3D_GLPLUS_INC EQU <1>


IFNDEF BP3D_TYPEDEF_INC
	include BP3DTypedef.inc
	; Also import OpenGL headers
	IFDEF BP_WININC
		include include\gl\gl.inc
		includelib opengl32.lib
	ELSEIFNDEF BP_CUSTOM_INCLUDES
		include include\opengl32.inc
		includelib opengl32.lib
	ENDIF
ENDIF

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

; ----- INTERFACE -----

; ----- CONSTANTS -----
;   These constants don't exist in 1.1 specification, but may be supported if
; supplied to the functions they're used in.
GL_BGR						EQU 32992
GL_BGRA						EQU 32993
GL_CLAMP_TO_EDGE			EQU 33071
GL_MULTISAMPLE				EQU 32925
GL_SAMPLE_ALPHA_TO_COVERAGE	EQU 32926
GL_UNSIGNED_BYTE_3_3_2		EQU 32818
GL_UNSIGNED_SHORT_5_6_5		EQU 33635

.CONST
;   Radians to degrees multiplier
IFDEF R2D
bpGLPlusR2D	TEXTEQU <R2D>
ELSE
bpGLPlusR2D	REAL4 57.29578
ENDIF

;   Some usual float (REAL4) colors in RGBA
clBlack		REAL4	0.0,  0.0,  0.0,  1.0
clBlue		REAL4	0.0,  0.0,  1.0,  1.0
clBrown		REAL4	0.5,  0.2,  0.0,  1.0
clCyan		REAL4	0.0,  1.0,  1.0,  1.0
clDarkGray	REAL4	0.25, 0.25, 0.25, 1.0
clGray		REAL4	0.5,  0.5,  0.5,  1.0
clGreen		REAL4	0.0,  1.0,  0.0,  1.0
clLightGray	REAL4	0.75, 0.75, 0.75, 1.0
clMagenta	REAL4   1.0,  0.0,  1.0,  1.0
clOrange	REAL4   1.0,  0.65, 0.0,  1.0
clPink		REAL4	1.0,  0.75, 0.8,  1.0
clPurple	REAL4	0.5,  0.0,  0.5,  1.0
clRed		REAL4	1.0,  0.0,  0.0,  1.0
clYellow	REAL4	1.0,  1.0,  0.0,  1.0
clWhite		REAL4	1.0,  1.0,  1.0,  1.0

;   Alpha colors
clHalf			REAL4	1.0,  1.0,  1.0,  0.5
clTransparent	REAL4	1.0,  1.0,  1.0,  0.0

; ----- IMPLEMENTATION -----
.CODE

;   Push Float as Double macro. Converts a float (single-precision/REAL4) value
; to a double-precision floating point value (REAL8) and pushes onto the stack.
pfad MACRO Single:REQ
	fld Single
	sub psp, 8
	fstp REAL8 PTR [psp]
ENDM

;   Push Integer as Double macro. Converts an integer (SDWORD) value to a 
; double-precision floating point value (REAL8) and pushes onto the stack.
piad MACRO Integer:REQ
	fild Integer
	sub psp, 8
	fstp REAL8 PTR [psp]
ENDM


;   The functions follow the usual OpenGL naming conventions: a number specifies
; the amount of parameters; 'f' means float, as opposed to double or integer; 
; 'v' means vector, a pointer to an array of values; 'i' means integer.

; ----- Basic OpenGL functions -----
glClearColor3fv BPPROC v:BPPtr
	mov pax, v
	invoke glClearColor, REAL4 PTR [pax], REAL4 PTR [pax+4], REAL4 PTR [pax+8],\
	clWhite[12]
	ret
glClearColor3fv ENDP

glClearColor4fv BPPROC v:BPPtr
	mov pax, v
	invoke glClearColor, REAL4 PTR [pax], REAL4 PTR [pax+4], REAL4 PTR [pax+8],\
	REAL4 PTR [pax+12]
	ret
glClearColor4fv ENDP

IFNDEF glClearDepthf
glClearDepthf BPPROC depth:REAL4
	pfad depth
	call glClearDepth
	ret
glClearDepthf ENDP
ENDIF

IFNDEF glDepthRangef
glDepthRangef BPPROC zNear:REAL4, zFar:REAL4
	pfad zFar
	pfad zNear
	call glDepthRange
	ret
glDepthRangef ENDP
ENDIF

IFNDEF glFrustumf
glFrustumf BPPROC left:REAL4, right:REAL4, bottom:REAL4, top:REAL4, \
zNear:REAL4, zFar:REAL4
	pfad zFar
	pfad zNear
	pfad top
	pfad bottom
	pfad right
	pfad left
	call glFrustum
	ret
glFrustumf ENDP
ENDIF

glFrustumfv BPPROC plane:BPPtr, zNear:REAL4, zFar:REAL4
	pfad zFar
	pfad zNear
	mov pax, plane
	pfad REAL4 PTR [pax+12]
	pfad REAL4 PTR [pax+8]
	pfad REAL4 PTR [pax+4]
	pfad REAL4 PTR [pax]
	call glFrustum
	ret
glFrustumfv ENDP

IFNDEF glOrthof
glOrthof BPPROC left:REAL4, right:REAL4, bottom:REAL4, top:REAL4, \
nearVal:REAL4, farVal:REAL4
	pfad farVal
	pfad nearVal
	pfad top
	pfad bottom
	pfad right
	pfad left
	call glOrtho
	ret
glOrthof ENDP
ENDIF

glOrthofv BPPROC plane:BPPtr, nearVal:REAL4, farVal:REAL4
	pfad farVal
	pfad nearVal
	mov pax, plane
	pfad REAL4 PTR [pax+12]
	pfad REAL4 PTR [pax+8]
	pfad REAL4 PTR [pax+4]
	pfad REAL4 PTR [pax]
	call glOrtho
	ret
glOrthofv ENDP

;   The following functions have a radians variant, labeled with an 'r'.
;   Rotate the current transformation matrix in XY (extrinsic) order.
glRotate2fv BPPROC v:BPPtr
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+4], 0, 1065353216, 0
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax], 1065353216, 0, 0
	ret
glRotate2fv ENDP

glRotate2fvr BPPROC v:BPPtr
	LOCAL _Val:REAL4
	mov pax, v
	fld REAL4 PTR [pax+4]
	fmul bpGLPlusR2D
	fstp _Val
	invoke glRotatef, _Val, 0, 1065353216, 0
	mov pax, v
	fld REAL4 PTR [pax]
	fmul bpGLPlusR2D
	fstp _Val
	invoke glRotatef, _Val, 1065353216, 0, 0
	ret
glRotate2fvr ENDP

;   Rotate the current transformation matrix in YXZ (extrinsic) order.
glRotate3fv BPPROC v:BPPtr
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+8], 0, 0, 1065353216
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax], 1065353216, 0, 0
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+4], 0, 1065353216, 0
	ret
glRotate3fv ENDP

glRotate3fvr BPPROC v:BPPtr
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

glRotatefr BPPROC angle:REAL4, x:REAL4, y:REAL4, z:REAL4
	fld angle
	fmul bpGLPlusR2D
	fstp angle
	invoke glRotatef, angle, x, y, z
	ret
glRotatefr ENDP

glRotatei BPPROC angle:SDWORD, x:SDWORD, y:SDWORD, z:SDWORD
	sub esp, 16
	fild z
	fstp REAL4 PTR [esp+12]
	fild y
	fstp REAL4 PTR [esp+8]
	fild x
	fstp REAL4 PTR [esp+4]
	fild angle
	fstp REAL4 PTR [esp]
	call glRotatef
	ret
glRotatei ENDP

glScale2fv BPPROC v:BPPtr
	mov pax, v
	invoke glScalef, REAL4 PTR [pax], REAL4 PTR [pax+4], 1065353216	; 1.0
	ret
glScale2fv ENDP

glScale3fv BPPROC v:BPPtr
	mov pax, v
	invoke glScalef, REAL4 PTR [pax], REAL4 PTR [pax+4], REAL4 PTR [pax+8]
	ret
glScale3fv ENDP

glScalei BPPROC x:SDWORD, y:SDWORD, z:SDWORD
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

glTranslate2fv BPPROC v:BPPtr
	mov pax, v
	invoke glTranslatef, REAL4 PTR [pax], REAL4 PTR [pax+4], 0
	ret
glTranslate2fv ENDP

glTranslate3fv BPPROC v:BPPtr
	mov pax, v
	invoke glTranslatef, REAL4 PTR [pax], REAL4 PTR [pax+4], REAL4 PTR [pax+8]
	ret
glTranslate3fv ENDP

glTranslate32Dfv BPPROC v:BPPtr
	mov pax, v
	invoke glTranslatef, REAL4 PTR [pax], 0, REAL4 PTR [pax+8]
	ret
glTranslate32Dfv ENDP

glTranslatei BPPROC x:SDWORD, y:SDWORD, z:SDWORD
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


; ----- Utility (GLU) functions -----
gluCylinderf BPPROC quad:BPPtr, base:REAL4, top:REAL4, height:REAL4, \
slices:SDWORD, stacks:SDWORD
	push stacks
	push slices
	pfad height
	pfad top
	pfad base
	push quad
	call gluCylinder
	ret
gluCylinderf ENDP

gluDiskf BPPROC quad:BPPtr, inner:REAL4, outer:REAL4, slices:SDWORD, \
loops:SDWORD
	push loops
	push slices
	pfad outer
	pfad inner
	push quad
	call gluDisk
	ret
gluDiskf ENDP

gluLookAtf BPPROC eyeX:REAL4, eyeY:REAL4, eyeZ:REAL4, centerX:REAL4, \
centerY:REAL4, centerZ:REAL4, upX:REAL4, upY:REAL4, upZ:REAL4
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
	ret
gluLookAtf ENDP

gluLookAtfv BPPROC eyePos:BPPtr, centerPos:BPPtr, upVector:BPPtr
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
	ret
gluLookAtfv ENDP

gluOrtho2Df BPPROC left:REAL4, right:REAL4, bottom:REAL4, top:REAL4
	pfad top
	pfad bottom
	pfad right
	pfad left
	call gluOrtho2D
	ret
gluOrtho2Df ENDP

gluOrtho2Dfv BPPROC plane:BPPtr
	mov pax, plane
	pfad REAL4 PTR [pax+12]
	pfad REAL4 PTR [pax+8]
	pfad REAL4 PTR [pax+4]
	pfad REAL4 PTR [pax]
	call gluOrtho2D
	ret
gluOrtho2Dfv ENDP

gluOrtho2Di BPPROC left:SDWORD, right:SDWORD, bottom:SDWORD, top:SDWORD
	piad top
	piad bottom
	piad right
	piad left
	call gluOrtho2D
	ret
gluOrtho2Di ENDP

gluPartialDiskf BPPROC quad:BPPtr, inner:REAL4, outer:REAL4, slices:SDWORD, \
loops:SDWORD, start:REAL4, sweep:REAL4
	pfad sweep
	pfad start
	push loops
	push slices
	pfad outer
	pfad inner
	push quad
	call gluPartialDisk
	ret
gluPartialDiskf ENDP

gluPerspectivef BPPROC fovy:REAL4, aspect:REAL4, zNear:REAL4, zFar:REAL4
	pfad zFar
	pfad zNear
	pfad aspect
	pfad fovy
	call gluPerspective
	ret
gluPerspectivef ENDP

gluProjectf BPPROC objX:REAL4, objY:REAL4, objZ:REAL4, model:BPPtr, proj:BPPtr,\
view:BPPtr, winX:BPPtr, winY:BPPtr, winZ:BPPtr
	LOCAL dVal[3]:REAL8
	lea pax, dVal[16]
	push pax
	lea pax, dVal[8]
	push pax
	lea pax, dVal[0]
	push pax
	push view
	push proj
	push model
	pfad objZ
	pfad objY
	pfad objX
	call gluProject
	push pax
	mov pax, winX
	fld dVal[0]
	fstp REAL4 PTR [pax]
	mov pax, winY
	fld dVal[8]
	fstp REAL4 PTR [pax]
	mov pax, winZ
	fld dVal[16]
	fstp REAL4 PTR [pax]
	pop pax
	ret
gluProjectf ENDP

gluProjectfd BPPROC objX:REAL4, objY:REAL4, objZ:REAL4, model:BPPtr, proj:BPPtr,\
view:BPPtr, winX:BPPtr, winY:BPPtr, winZ:BPPtr
	push winZ
	push winY
	push winX
	push view
	push proj
	push model
	pfad objZ
	pfad objY
	pfad objX
	call gluProject
	ret
gluProjectfd ENDP

gluProjectfv BPPROC objPos:BPPtr, model:BPPtr, proj:BPPtr,\
view:BPPtr, winPos:BPPtr
	LOCAL dVal[3]:REAL8
	lea pax, dVal[16]
	push pax
	lea pax, dVal[8]
	push pax
	lea pax, dVal[0]
	push pax
	push view
	push proj
	push model
	mov pax, objPos
	pfad REAL4 PTR [pax+8]
	pfad REAL4 PTR [pax+4]
	pfad REAL4 PTR [pax]
	call gluProject
	push pax
	mov pax, winPos
	fld dVal[0]
	fstp REAL4 PTR [pax]
	fld dVal[8]
	fstp REAL4 PTR [pax+4]
	fld dVal[16]
	fstp REAL4 PTR [pax+8]
	pop pax
	ret
gluProjectfv ENDP

gluSpheref BPPROC quad:BPPtr, radius:REAL4, slices:SDWORD, stacks:SDWORD
	push stacks
	push slices
	pfad radius
	push quad
	call gluSphere
	ret
gluSpheref ENDP

gluUnProjectf BPPROC winX:REAL4, winY:REAL4, winZ:REAL4, model:BPPtr, \
proj:BPPtr, view:BPPtr, objX:BPPtr, objY:BPPtr, objZ:BPPtr
	LOCAL dVal[3]:REAL8
	lea pax, dVal[16]
	push pax
	lea pax, dVal[8]
	push pax
	lea pax, dVal[0]
	push pax
	push view
	push proj
	push model
	pfad winZ
	pfad winY
	pfad winX
	call gluUnProject
	push pax
	mov pax, objX
	fld dVal[0]
	fstp REAL4 PTR [pax]
	mov pax, objY
	fld dVal[8]
	fstp REAL4 PTR [pax]
	mov pax, objZ
	fld dVal[16]
	fstp REAL4 PTR [pax]
	pop pax
	ret
gluUnProjectf ENDP

gluUnProjectfd BPPROC winX:REAL4, winY:REAL4, winZ:REAL4, model:BPPtr, \
proj:BPPtr, view:BPPtr, objX:BPPtr, objY:BPPtr, objZ:BPPtr
	push winZ
	push winY
	push winX
	push view
	push proj
	push model
	pfad winZ
	pfad winY
	pfad winX
	call gluUnProject
	ret
gluUnProjectfd ENDP
ELSE
	ECHO BP3D: Duplicate include file BP3DGLPlus.inc
ENDIF
