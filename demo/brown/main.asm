;
;   BP3D Brown Demo
;
;   Demonstrates the usage of importers, maths, vectors and implements a basic
; particle system. Tests the basic audio capabilities of the system (MCI).
;   64-bit compileable (UASM, untested).
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;


IFNDEF rax
.386
.model flat, stdcall
ENDIF
option casemap:none

BP_COMPATIBILITY_W9X	EQU <1>	; Exclude unsupported APIs

; BP3D includes
include ..\..\src\BP3D.asm
include ..\..\src\BP3DMaths.inc
include ..\..\src\BP3DVectors.inc
include ..\..\src\BP3DImporters.inc
include ..\..\src\BP3DGLPlus.inc

PARTICLE_AMOUNT EQU 255	; The amount of particles to render and process

.CONST
AppName DB "BP3D Brown Demo", 0			; Caption

Gravity				REAL4 -9.8			; Absolute gravity
ParticleColor1		REAL4 0.7, 0.4, 0.1	; First particle gradient color
ParticleColor2		REAL4 0.4, 0.1, 0.0	; Second particle gradient color
ParticleDamp		REAL4 0.99			; Particle velocity damping (1.0 - none)
ParticleLifetime	REAL4 2.0			; Particle lifetime in seconds
ParticleScale		REAL4 0.06			; Absolute particle scale

.DATA
FMain			BPForm <>	; Main form

CamPos	Vector3 <0.0, 3.5, 2.5>	; In-world camera position
Rotation		REAL4 0.0		; Rotation of camera around world center

; Particles and their arrays
Particles		BPBool FALSE	; Are particles being rendered
ParticleAlpha	REAL4 PARTICLE_AMOUNT dup (1.0)		; Alpha array
ParticlePos		REAL4 PARTICLE_AMOUNT * 3 dup (0.0)	; Positions array
ParticleVel		REAL4 PARTICLE_AMOUNT * 3 dup (0.0)	; Velocities array

.DATA?
; Resources
MdlParticle	DWORD ?	; Particle model, a quad generated at runtime
MdlToilet	DWORD ?	; Toilet model, loaded from toilet.bpl
TexParticle	DWORD ?	; Particle texture, a radial gradient generated at runtime
TexToilet	DWORD ?	; Toilet texture, loaded from toilet.bpt

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
; Render and process particles.
RenderParticles PROC
	LOCAL rot:REAL4
	invoke glBindTexture, GL_TEXTURE_2D, TexParticle
	invoke glDisable, GL_LIGHTING
	invoke glEnable, GL_BLEND
	invoke glBlendFunc, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA
	invoke glDepthMask, GL_FALSE	; To prevent depth alpha fighting
	
	; Iterate through the particles, draw and process them
	xor pbx, pbx
	.WHILE (pbx < PARTICLE_AMOUNT*SIZEOF Vector3)
		
		xor pdx, pdx
		mov pax, pbx
		mov pcx, 3
		div pcx
		fld deltaTime
		fdiv ParticleLifetime
		fsubr ParticleAlpha[pax]
		fstp ParticleAlpha[pax]
		invoke glColor4f, f(1), f(1), f(1), ParticleAlpha[pax]
		
		call glPushMatrix
			fld Rotation
			fchs
			fadd f(180)
			fstp rot
			invoke glTranslate3fv, ADDR ParticlePos[pbx]
			invoke glRotatef, rot, 0, f(1), 0
			invoke glRotatef, f(32), f(1), 0, 0
			invoke glScalef, ParticleScale, ParticleScale, ParticleScale
			invoke glTranslatef, 0, f(1), 0
			invoke glCallList, MdlParticle
		call glPopMatrix
		
		fld ParticleVel[pbx]
		fmul ParticleDamp
		fst ParticleVel[pbx]
		fmul deltaTime
		fadd ParticlePos[pbx]
		fstp ParticlePos[pbx]
		
		fld deltaTime
		fmul Gravity
		fadd ParticleVel[pbx+4]
		fst ParticleVel[pbx+4]
		fmul deltaTime
		fadd ParticlePos[pbx+4]
		fstp ParticlePos[pbx+4]
		
		fld ParticleVel[pbx+8]
		fmul ParticleDamp
		fst ParticleVel[pbx+8]
		fmul deltaTime
		fadd ParticlePos[pbx+8]
		fstp ParticlePos[pbx+8]
		
		add pbx, 12
	.ENDW
	
	fcmp ParticleAlpha[0]
	.IF (Carry?)
		mov Particles, FALSE
	.ENDIF
	
	invoke glDisable, GL_BLEND
	invoke glEnable, GL_LIGHTING
	invoke glDepthMask, GL_TRUE
	ret
RenderParticles ENDP

; Reset particles to their original position & alpha, apply random velocities.
ResetParticles PROC
	xor pbx, pbx
	.WHILE (pbx < PARTICLE_AMOUNT * SIZEOF Vector3)
		mov ParticlePos[pbx], 0
		bpMEM32 ParticlePos[pbx+4], f(1)
		bpMEM32 ParticlePos[pbx+8], f(0.5)
		invoke flRandRange, f(-2), f(2)
		mov ParticleVel[pbx], eax
		invoke flRandRange, f(4), f(8)
		mov ParticleVel[pbx+4], eax
		invoke flRandRange, f(-2), f(2)
		mov ParticleVel[pbx+8], eax
		
		xor pdx, pdx
		mov pax, pbx
		mov pcx, 3
		div pcx
		mov ecx, f(1)
		mov ParticleAlpha[pax], ecx
		add pbx, 12
	.ENDW
	
	invoke PlaySound, s("particles.wav"), NULL, SND_FILENAME or SND_ASYNC
	ret
ResetParticles ENDP

;   FMain bindings
OnCreate PROC STDCALL
	LOCAL texPixels:BPPtr, colLerp:REAL4
	invoke bpInitGLContext, ADDR FMain
	
	LoadBPL ADDR MdlToilet, "toilet.bpl"
	mov bpTextureFiltering, TRUE
	LoadBPT ADDR TexToilet, "toilet.bpt"
	
	invoke glGenLists, 1
	mov MdlParticle, eax
	invoke glNewList, MdlParticle, GL_COMPILE
		invoke glBegin, GL_QUADS
		invoke glTexCoord2i, 0, 0
		invoke glVertex2i, -1, 1
		invoke glTexCoord2i, 1, 0
		invoke glVertex2i, 1, 1
		invoke glTexCoord2i, 1, 1
		invoke glVertex2i, 1, -1
		invoke glTexCoord2i, 0, 1
		invoke glVertex2i, -1, -1
		call glEnd
	call glEndList
	
	;   Create the particle texture - a radial gradient from ParticleColor1 to
	; ParticleColor2 with radial alpha cutoff.
	mov texPixels, r(bpMalloc, bpDefHeap, 0, 64*64*4*4)
	xor pbx, pbx
	.WHILE (pbx < 64)
		xor pcx, pcx
		.WHILE (pcx < 64)
			invoke intDistance, ebx, 32
			mov pdx, pax
			imul pdx
			push pax
			invoke intDistance, ecx, 32
			mov pdx, pax
			imul pdx
			pop pdx
			add pax, pdx
			
			push pax
			fild REAL4 PTR [psp]
			add psp, 4
			fdiv f(2048)
			fstp colLerp
			
			mov pax, pbx
			shl pax, 6	; *64
			add pax, pcx
			shl pax, 4	; *4*4
			add pax, texPixels
			mov pdx, pax
			invoke flLerp, ParticleColor1[0], ParticleColor2[0], colLerp
			mov REAL4 PTR [pdx], eax
			invoke flLerp, ParticleColor1[4], ParticleColor2[4], colLerp
			mov REAL4 PTR [pdx+4], eax
			invoke flLerp, ParticleColor1[8], ParticleColor2[8], colLerp
			mov REAL4 PTR [pdx+8], eax
			
			fcmp colLerp, f(0.5)
			.IF (Carry?)
				bpMEM32 REAL4 PTR [pdx+12], f(1)
			.ELSE
				mov REAL4 PTR [pdx+12], 0
			.ENDIF
			
			inc pcx
		.ENDW
		inc pbx
	.ENDW
	invoke glGenTextures, 1, OFFSET TexParticle
	invoke glBindTexture, GL_TEXTURE_2D, TexParticle
	invoke glTexImage2D, GL_TEXTURE_2D, 0, GL_RGBA8, 64, 64, 0, GL_RGBA, \
	GL_FLOAT, texPixels
	invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR
	invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR
	
	; Initialize OpenGL stuff
	invoke glClearColor4fv, ADDR clBrown
	
	invoke glEnable, GL_LIGHTING
	invoke glEnable, GL_LIGHT0
	invoke glLightfv, GL_LIGHT0, GL_DIFFUSE, ADDR clWhite
	invoke glLightf, GL_LIGHT0, GL_CONSTANT_ATTENUATION, 0
	invoke glLightf, GL_LIGHT0, GL_QUADRATIC_ATTENUATION, f(0.1)
	
	invoke glMaterialf, GL_FRONT, GL_SHININESS, f(20)
	invoke glMaterialfv, GL_FRONT, GL_SPECULAR, ADDR clWhite
	
	invoke mciSendString, s("play music.mp3"), NULL, 0, 0
	ret
OnCreate ENDP

OnInput PROC STDCALL BPInType:BYTE, BPInStruct:BPPtr
	.IF (BPInType == BP_INPUT_KEY)
		ASSUME pbx:PTR BPInKey
		mov pbx, BPInStruct
		.IF ([pbx].Pressed)
			.IF ([pbx].Keycode == VK_SPACE)
				mov Particles, TRUE
				call ResetParticles
				
			.ELSEIF ([pbx].Keycode == VK_ESCAPE)
				invoke bpDestroyForm, ADDR FMain
				
			.ELSEIF ([pbx].Keycode == 'F')
				.IF (FMain.WindowMode == BP_WINDOW_MODE_FULLSCREEN)
					invoke bpSetWindowMode, ADDR FMain, BP_WINDOW_MODE_WINDOWED
				.ELSE
					invoke bpSetWindowMode, ADDR FMain,BP_WINDOW_MODE_FULLSCREEN
				.ENDIF
			.ENDIF
		.ENDIF
		ASSUME pbx:nothing
	.ENDIF
	ret
OnInput ENDP

OnRender PROC STDCALL
	invoke glClear, GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
	
	invoke glMatrixMode, GL_PROJECTION
	call glLoadIdentity
	invoke gluPerspectivef, f(90), FMain.Aspect, f(0.01), f(100)
	
	invoke glMatrixMode, GL_MODELVIEW
	call glLoadIdentity
	
	invoke glRotatef, f(30), f(1), 0, 0
	Vector3Push CamPos
	invoke Vector3Negate, ADDR CamPos
	invoke glTranslate3fv, ADDR CamPos
	Vector3Pop CamPos
	invoke glRotatef, Rotation, 0, f(1), 0
	
	invoke glBindTexture, GL_TEXTURE_2D, TexToilet
	invoke glCallList, MdlToilet
	
	.IF (Particles)
		call RenderParticles
	.ENDIF
	
	fld deltaTime
	fmul f(180)
	fadd Rotation
	fstp Rotation
	ret
OnRender ENDP

start:
	call nRandomize		; Set random seed
	
	; Bind callback procedures
	mov pax, OFFSET AppName
	mov FMain.Caption,	pax
	mov pax, OFFSET OnCreate
	mov FMain.OnCreate,	pax
	mov pax, OFFSET OnInput
	mov FMain.OnInput,	pax
	mov pax, OFFSET OnRender
	mov FMain.OnRender,	pax
	
	invoke bpCreateForm, ADDR FMain	; Create form
	
	; This code is reached when form's execution is done
	invoke TerminateProcess, r(GetCurrentProcess), 0
end start