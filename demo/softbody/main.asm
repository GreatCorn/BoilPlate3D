;
;   BP3D Softbody Demo
;
;   Demonstrates the usage of dynamic meshes and implements a sort of softbody
; physics object. Tests MSAA capabilities via ARB and, if available, applies it.
;   32-bit only.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

.386
.model flat, stdcall
option casemap:none

BP_COMPATIBILITY_W9X	EQU <1>	; Exclude unsupported APIs

; BP3D includes
include ..\..\src\BP3D.asm
include ..\..\src\BP3DMaths.inc
include ..\..\src\BP3DVectors.inc
include ..\..\src\BP3DAssets.inc
include ..\..\src\BP3DGLPlus.inc
include ..\..\src\BP3DText.inc

.CONST
AppName DB "BP3D Softbody Demo", 0	; Caption

.DATA
FMain	BPForm <>
; A dummy form to initialize OpenGL and enable the ARB extensions (MSAA)
FARB BPForm <>	

ARBPixelAttribs DWORD \
	2001h, GL_TRUE, \	; WGL_DRAW_TO_WINDOW_ARB = true
	2010h, GL_TRUE, \	; WGL_SUPPORT_OPENGL_ARB = true
	2011h, GL_TRUE, \	; WGL_DOUBLE_BUFFER_ARB = true
	2013h, 202Bh, \		; WGL_PIXEL_TYPE_ARB = WGL_TYPE_RGBA_ARB
	2014h, 24, \		; WGL_COLOR_BITS_ARB = 24
	2022h, 24, \		; WGL_DEPTH_BITS_ARB = 24
	2041h, 1, \			; WGL_SAMPLE_BUFFERS_ARB = 1 (multisample buffer)
	2042h, 4, \			; WGL_SAMPLES_ARB = 4 (4x MSAA?)
0						; null-terminated

ARB			BPBool FALSE	; Have ARB functions been imported

Model			BPMesh <>	; The initial model	
ModelDeformed	BPMesh <>	; The displayed deformed model
ModelRot	Vector3 <0.0, 0.0, 0.0>	; The models rotation (towards the cursor)

Dragging	BPBool FALSE	; Is the user dragging the cursor
MPos Vector3 <0.0, 0.0, 0.0>; Mouse position in world coordinates

.DATA?
wglChoosePixelFormatARB BPPtr ?	; Pointer to the ARB function

ModelTarget		BPPtr ?	; 
ModelVelocity	BPPtr ?
ModelTVelocity	BPPtr ?

ModelTexture	DWORD ?

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

InitARBContext PROC EXPORT
	LOCAL numFormats:UINT, pixelFormat:DWORD, pfd:PIXELFORMATDESCRIPTOR
	
	invoke GetDC, FMain.Handle
	mov FMain.DeviceContext, pax
	
	lea pdx, numFormats
	push pdx
	lea pdx, pixelFormat
	push pdx
	push 1
	push 0
	lea pdx, ARBPixelAttribs
	push pdx
	push FMain.DeviceContext
	call wglChoosePixelFormatARB
	
	invoke DescribePixelFormat, FMain.DeviceContext, pixelFormat, \
	SIZEOF PIXELFORMATDESCRIPTOR, ADDR pfd
	
	invoke SetPixelFormat, FMain.DeviceContext, pixelFormat, ADDR pfd
	invoke wglCreateContext, FMain.DeviceContext
	mov FMain.GraphicsContext, pax
	
	invoke wglMakeCurrent, FMain.DeviceContext, FMain.GraphicsContext
	
	invoke glEnable, GL_MULTISAMPLE
	
	invoke glEnable, GL_CULL_FACE
	invoke glShadeModel, GL_SMOOTH
	invoke glEnable, GL_DEPTH_TEST
	invoke glEnable, GL_TEXTURE_2D
	invoke glDepthFunc, GL_LEQUAL
	
	invoke glEnableClientState, GL_VERTEX_ARRAY
	invoke glEnableClientState, GL_TEXTURE_COORD_ARRAY
	invoke glEnableClientState, GL_NORMAL_ARRAY
	ret
InitARBContext ENDP

IntToStr PROC StrA:BPPtr, Val:SDWORD
	LOCAL Val1:DWORD, Ngtv:BYTE
	
	mov Ngtv, 0
	push ebx
	xor ebx, ebx
	bpMEM32 Val1, Val
	.IF (Val < 0)
		inc Ngtv
		mov eax, Val1
		sub eax, Val1
		sub eax, Val1
		mov Val1, eax
	.ENDIF
	.WHILE TRUE
		xor edx, edx
		mov eax, Val1
		mov ecx, 10
		div ecx
		mov Val1, eax
		add dl, 48
		
		push edx
		.IF (ebx)
			mov eax, StrA
			add eax, 1
			invoke RtlMoveMemory, eax, StrA, ebx
		.ENDIF
		pop edx
		mov eax, StrA
		mov BYTE PTR[eax], dl
		inc ebx
		.IF (!Val1)
			.BREAK
		.ENDIF
	.ENDW
	mov BYTE PTR[eax+ebx], 0
	.IF (Ngtv)
		mov eax, StrA
		add eax, 1
		invoke RtlMoveMemory, eax, StrA, ebx
		mov eax, StrA
		mov BYTE PTR[eax], 45
	.ENDIF
	mov eax, ebx
	pop ebx
	ret
IntToStr ENDP

ProcessPhysics PROC
	LOCAL velVector:Vector3, dist:REAL4, deltaP:REAL4, deltaQ:REAL4
	
	fld deltaTime
	fmul f(2.0)
	fst deltaTime
	fmul f(3.0)
	fst deltaP
	fmul f(2.0)
	fstp deltaQ
	
	; Processing
	xor pbx, pbx
	.WHILE (pbx < ModelDeformed.Count)
		mov pax, pbx
		mov pcx, 12
		mul pcx
		
		push pax
		.IF (Dragging)
			add pax, ModelDeformed.Vertices
			bpMPM MPos.Z, REAL4 PTR [pax+8]
			invoke Vector3DistanceSqr, ADDR MPos, pax
			mov dist, pax
			
			fld dist
			fsqrt
			fsqrt
			fmul f(0.5)
			fsubr f(0.75)
			fstp dist
			
			mov dist, r(flClamp, dist, 0, f(1.0))
			
			pop pax
			push pax
			
			add pax, Model.Vertices
			invoke Vector2Copy, ADDR velVector, pax
			invoke Vector2Lerp, ADDR velVector, ADDR MPos, dist
			
			pop pax
			push pax
			
			add pax, ModelTarget
			lea pcx, velVector
			push pcx
			push pax
			call Vector2Copy
			
			pop pax
			push pax
			mov pcx, pax
			add pcx, ModelTarget
			add pax, ModelDeformed.Vertices
			push deltaQ
			push pcx
			push pax
			call Vector2Lerp
			
			pop pax
			push pax
		.ENDIF
		
		push deltaP
		push f(2.0)
		push f(64.0)
		
		mov pcx, pax
		add pcx, ModelTarget
		push pcx
		
		mov pcx, pax
		add pcx, ModelDeformed.Vertices
		push pcx
		
		mov pcx, pax
		add pcx, ModelVelocity
		push pcx
		
		call Vector3DampedSpring
		pop pax
		push pax
		
		add pax, ModelVelocity
		invoke Vector3Copy, ADDR velVector, pax
		invoke Vector3MulF, ADDR velVector, deltaTime
		pop pax
		
		add pax, ModelDeformed.Vertices
		lea pcx, velVector
		push pcx
		push pax
		call Vector3Add
		
		
		mov pax, pbx
		mov pcx, 12
		mul pcx
		
		push pax
		
		push deltaP
		push f(2.0)
		push f(16.0)
		
		mov pcx, pax
		add pcx, Model.Vertices
		push pcx
		
		mov pcx, pax
		add pcx, ModelTarget
		push pcx
		
		mov pcx, pax
		add pcx, ModelTVelocity
		push pcx
		
		call Vector3DampedSpring
		pop pax
		
		push pax
		add pax, ModelTVelocity
		invoke Vector3Copy, ADDR velVector, pax
		invoke Vector3MulF, ADDR velVector, deltaQ
		pop pax
		
		add pax, ModelTarget
		lea pcx, velVector
		push pcx
		push pax
		call Vector3Add
		
		inc pbx
	.ENDW
	ret
ProcessPhysics ENDP

Vector3DampedSpring PROC EXPORT Velocity:BPPtr, Pos:BPPtr, PosTarget:BPPtr,
Stiffness:REAL4, Damping:REAL4, T:REAL4
	mov pcx, Pos
	mov pdx, PosTarget
	invoke FlDampedSpring, Velocity, REAL4 PTR [pcx], REAL4 PTR [pdx], \
	Stiffness, Damping, T
	add Velocity, SIZEOF REAL4
	invoke FlDampedSpring, Velocity, REAL4 PTR [pcx+4], REAL4 PTR [pdx+4], \
	Stiffness, Damping, T
	add Velocity, SIZEOF REAL4
	invoke FlDampedSpring, Velocity, REAL4 PTR [pcx+8], REAL4 PTR [pdx+8], \
	Stiffness, Damping, T
	ret
Vector3DampedSpring ENDP

; FMain bindings
OnCreate PROC EXPORT
	.IF (ARB)
		invoke InitARBContext ; Initialize ARB context
	.ELSE
		invoke bpInitGLContext, ADDR FMain
	.ENDIF
	
	LoadBPM ADDR Model, "gc.bpm"
	LoadBPM ADDR ModelDeformed, "gc.bpm"
	mov bpTextureFiltering, TRUE
	LoadBPT ADDR ModelTexture, "gc.bpt"
	mov bpTextureFiltering, FALSE
	
	LoadFont "..\font\"
	bpMEM32 bpFontWidth, f(16)
	bpMEM32 bpFontHeight, f(32)
	
	mov ModelTarget, r(bpMalloc, bpDefHeap, 0, ModelDeformed.V3Size)
	invoke RtlMoveMemory, ModelTarget, ModelDeformed.Vertices, ModelDeformed.V3Size
	mov ModelVelocity, r(bpMalloc, bpDefHeap, 0, ModelDeformed.V3Size)
	mov ModelTVelocity, r(bpMalloc, bpDefHeap, 0, ModelDeformed.V3Size)
	
	invoke glMaterialf, GL_FRONT, GL_SHININESS, f(64.0)
	invoke glMaterialfv, GL_FRONT, GL_AMBIENT, ADDR clBlack
	invoke glMaterialfv, GL_FRONT, GL_DIFFUSE, ADDR clWhite
	invoke glMaterialfv, GL_FRONT, GL_SPECULAR, ADDR clWhite
	
	invoke glEnable, GL_LIGHTING
	invoke glEnable, GL_LIGHT0
	
	invoke glClearColor3fv, ADDR clWhite
	ret
OnCreate ENDP

OnInput PROC EXPORT BPInType:BPEnum, BPInStruct:BPPtr	
	mov pbx, BPInStruct
	.IF (BPInType == BP_INPUT_MOUSE_BUTTON)
		ASSUME pbx:PTR BPInMouseButton
		
		.IF ([pbx].Pressed)
			mov Dragging, TRUE
		.ELSE
			mov Dragging, FALSE
		.ENDIF
	.ELSEIF (BPInType == BP_INPUT_MOUSE_MOVE)
		fild bpMouseClient
		fild FMain.ScreenSize.x
		fmul f(0.5)
		fsub
		fidiv FMain.ScreenSize.y
		fmul f(2.0)
		fstp MPos.X
		fild bpMouseClient[4]
		fidiv FMain.ScreenSize.y
		fmul f(2.0)
		fsub f(1.0)
		fchs
		fstp MPos.Y
	.ELSEIF (BPInType == BP_INPUT_JOY_AXIS)
		ASSUME pbx:PTR BPInJoyAxis
	
		.IF ([pbx].Axis == BP_JOY_AXIS_X)
			bpMEM32 MPos.X, [pbx].Position
		.ELSEIF ([pbx].Axis == BP_JOY_AXIS_Y)
			bpMEM32 MPos.Y, [pbx].Position
		.ENDIF
	.ELSEIF (BPInType == BP_INPUT_KEY)
		ASSUME pbx:PTR BPInKey
		
		.IF ([pbx].Pressed)
			.IF ([pbx].Keycode == 'F')
				.IF (FMain.WindowMode == BP_WINDOW_MODE_FULLSCREEN)
					invoke bpSetWindowMode, ADDR FMain, BP_WINDOW_MODE_WINDOWED
				.ELSE
					invoke bpSetWindowMode, ADDR FMain,BP_WINDOW_MODE_FULLSCREEN
				.ENDIF
			.ENDIF
		.ENDIF
	.ENDIF
	
	ASSUME pbx:nothing
	ret
OnInput ENDP

OnRender PROC EXPORT
	LOCAL vecVal:Vector3, deltaP:REAL4, FPS:DWORD, fpsStr[32]:BYTE
	
	call ProcessPhysics
	
	fld deltaTime
	fmul f(3.0)
	fstp deltaP
	
	; Drawing
	invoke glClear, GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
	
	invoke glMatrixMode, GL_PROJECTION
	call glLoadIdentity
	
	invoke gluPerspectivef, f(60.0), FMain.Aspect, f(0.01), f(1000.0)
	
	invoke glMatrixMode, GL_MODELVIEW
	call glLoadIdentity
	
	invoke glTranslatef, 0, 0, f(-2.0)
	invoke Vector2Copy, ADDR vecVal, ADDR MPos
	invoke Vector2MulF, ADDR vecVal, f(2.0)
	invoke Vector2Lerp, ADDR ModelRot, ADDR vecVal, deltaP
	invoke glRotatef, ModelRot.X, 0, f(1.0), 0
	invoke glRotatef, ModelRot.Y, f(-1.0), 0, 0
	invoke glBindTexture, GL_TEXTURE_2D, ModelTexture
	invoke bpDrawMesh, ADDR ModelDeformed
	
	invoke glMatrixMode, GL_PROJECTION
	call glLoadIdentity
	.IF (FMain.ScreenSize.x)
		invoke gluOrtho2Di, 0, FMain.ScreenSize.x, FMain.ScreenSize.y, 0
	.ENDIF
	
	invoke glMatrixMode, GL_MODELVIEW
	call glLoadIdentity
	
	invoke RtlZeroMemory, ADDR fpsStr, 32
	fld1
	fdiv deltaUnscaled
	fistp FPS
	invoke IntToStr, ADDR fpsStr, FPS
	
	invoke glEnable, GL_BLEND
	invoke glDisable, GL_LIGHTING
	; The blend mode behaves differently on ReactOS for some reason
	invoke glBlendFunc, GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_COLOR
	invoke glColor4fv, ADDR clWhite
	RenderText "FPS:"
	RenderText ADDR fpsStr, 74
	invoke glEnable, GL_LIGHTING
	invoke glDisable, GL_BLEND
	ret
OnRender ENDP

;   FARB bindings
FARBOnCreate PROC EXPORT
	invoke bpInitGLContext, ADDR FARB
	invoke wglGetProcAddress, s("wglChoosePixelFormatARB")
	.IF (pax)
		mov wglChoosePixelFormatARB, pax
		mov ARB, TRUE
	.ENDIF
	invoke bpDestroyForm, ADDR FARB
	mov FARB.DefaultFlag, FALSE
	ret
FARBOnCreate ENDP

start:
	mov FARB.OnCreate, OFFSET FARBOnCreate
	invoke bpCreateForm, ADDR FARB
	
	
	mov FMain.Caption,	OFFSET AppName
	
	mov FMain.OnCreate,	OFFSET OnCreate
	mov FMain.OnInput,	OFFSET OnInput
	mov FMain.OnRender,	OFFSET OnRender
	
	invoke bpCreateForm, ADDR FMain
	
	invoke TerminateProcess, r(GetCurrentProcess), 0
end start