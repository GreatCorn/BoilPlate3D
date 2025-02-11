GL_CLAMP_TO_EDGE EQU 33071
GL_MULTISAMPLE EQU 32925
GL_UNSIGNED_BYTE_3_3_2 EQU 32818
GL_UNSIGNED_SHORT_5_6_5 EQU 33635

.CONST
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

.DATA?
bp3DDbl REAL8 ?

.CODE

pfad MACRO Single:REQ
	fld Single
	fstp bp3DDbl
	push DWORD PTR bp3DDbl+4
	push DWORD PTR bp3DDbl
ENDM
piad MACRO Integer:REQ
	fild Integer
	fstp bp3DDbl
	push DWORD PTR bp3DDbl+4
	push DWORD PTR bp3DDbl
ENDM

glClearDepthf PROC depth:REAL4
	IFDEF rax
	
	ELSE
		pfad depth
		call glClearDepth
	ENDIF
	ret
glClearDepthf ENDP

glClearColor3fv PROC v:BPPtr
	mov pax, v
	push clWhite[12]
	push REAL4 PTR [pax+8]
	push REAL4 PTR [pax+4]
	push REAL4 PTR [pax]
	call glClearColor
	ret
glClearColor3fv ENDP

glClearColor4fv PROC v:BPPtr
	mov pax, v
	push REAL4 PTR [pax+12]
	push REAL4 PTR [pax+8]
	push REAL4 PTR [pax+4]
	push REAL4 PTR [pax]
	call glClearColor
	ret
glClearColor4fv ENDP

glOrthof PROC left:REAL4, right:REAL4, bottom:REAL4, top:REAL4, nearVal:REAL4,\
farVal:REAL4
	IFDEF rax
	
	ELSE
		pfad farVal
		pfad nearVal
		pfad top
		pfad bottom
		pfad right
		pfad left
		call glOrtho
	ENDIF
	ret
glOrthof ENDP

glScalei PROC x:SDWORD, y:SDWORD, z:SDWORD
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

glTranslatei PROC x:SDWORD, y:SDWORD, z:SDWORD
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

gluLookAtf PROC eyeX:REAL4, eyeY:REAL4, eyeZ:REAL4, centerX:REAL4, \
centerY:REAL4, centerZ:REAL4, upX:REAL4, upY:REAL4, upZ:REAL4
	IFDEF rax
		
	ELSE
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
	ENDIF
gluLookAtf ENDP

gluPerspectivef PROC fovy:REAL4, aspect:REAL4, zNear:REAL4, zFar:REAL4
	IFDEF rax
	
	ELSE
		pfad zFar
		pfad zNear
		pfad aspect
		pfad fovy
		call gluPerspective
	ENDIF
	ret
gluPerspectivef ENDP

gluOrtho2Df PROC left:REAL4, right:REAL4, bottom:REAL4, top:REAL4
	IFDEF rax
	
	ELSE
		pfad top
		pfad bottom
		pfad right
		pfad left
		call gluOrtho2D
	ENDIF
	ret
gluOrtho2Df ENDP

gluOrtho2Dui PROC left:DWORD, right:DWORD, bottom:DWORD, top:DWORD
	IFDEF rax
	
	ELSE
		piad top
		piad bottom
		piad right
		piad left
		call gluOrtho2D
	ENDIF
	ret
gluOrtho2Dui ENDP

IFDEF BP3DMATHS_INC
glRotatefr PROC angle:REAL4, x:REAL4, y:REAL4, z:REAL4
	fld angle
	fmul R2D
	fstp angle
	invoke glRotatef, angle, x, y, z
	ret
glRotatefr ENDP
ENDIF

IFDEF BP3DVECTORS_INC
glRotate2fv PROC v:BPPtr
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax], 1065353216, 0, 0
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+4], 0, 1065353216, 0
	ret
glRotate2fv ENDP

glRotate3fv PROC v:BPPtr
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+8], 0, 0, 1065353216
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax], 1065353216, 0, 0
	mov pax, v
	invoke glRotatef, REAL4 PTR [pax+4], 0, 1065353216, 0
	ret
glRotate3fv ENDP

IFDEF BP3DMATHS_INC
glRotate3fvr PROC v:BPPtr
	LOCAL _Val:REAL4
	mov pax, v
	fld REAL4 PTR [pax+8]
	fmul R2D
	fstp _Val
	invoke glRotatef, _Val, 0, 0, 1065353216
	mov pax, v
	fld REAL4 PTR [pax]
	fmul R2D
	fstp _Val
	invoke glRotatef, _Val, 1065353216, 0, 0
	mov pax, v
	fld REAL4 PTR [pax+4]
	fmul R2D
	fstp _Val
	invoke glRotatef, _Val, 0, 1065353216, 0
	ret
glRotate3fvr ENDP
ENDIF

glTranslate3fv PROC v:BPPtr
	mov pax, v
	invoke glTranslatef, REAL4 PTR [pax], REAL4 PTR [pax+4], REAL4 PTR [pax+8]
	ret
glTranslate3fv ENDP
ENDIF
