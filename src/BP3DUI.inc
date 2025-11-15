;
;   BP3DText.inc
;   Version 0.5ac1
;   BP3D user interface API extension.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

IFNDEF BP3D_UI_INC
BP3D_TEXT_INC EQU <1>

BP_ALIGN_LEFT	EQU 0
BP_ALIGN_CENTER	EQU 1
BP_ALIGN_RIGHT	EQU 2
BP_ALIGN_TOP	EQU BP_ALIGN_LEFT
BP_ALIGN_BOTTOM	EQU BP_ALIGN_RIGHT

.DATA
bpCurrentFont	BPPtr OFFSET bpDefaultFont
bpDefaultFont	DWORD 127 dup (0)

bpFontWidth		REAL4 8.0
bpFontHeight	REAL4 16.0
bpFontSpacing	REAL4 1.15
bpFontQuad		DWORD 0
bpTextNL		BYTE 0
bpUIItems		DWORD 0

.DATA?

.CODE

IFDEF BP3D_IMPORTERS_INC
LoadFont MACRO DirPath:REQ, FontPTR
	IFB <FontPTR>
		invoke bpLoadFont, s(DirPath), OFFSET bpDefaultFont
	ELSE
		invoke bpLoadFont, s(DirPath), FontPTR
	ENDIF
ENDM

RenderText MACRO TextString:REQ, X:=<0>, Y:=<0>, \
HorizontalAlign:=<BP_ALIGN_LEFT>, VerticalAlign:=<BP_ALIGN_TOP>
	LOCAL qot
	qot INSTR <TextString>,<">; "
	IFE qot
		qot INSTR <TextString>,<'>; '
	ENDIF
	IF qot
		invoke bpRenderText, s(TextString), X, Y, \
		HorizontalAlign, VerticalAlign
	ELSE
		invoke bpRenderText, TextString, X, Y, \
		HorizontalAlign, VerticalAlign
	ENDIF
ENDM
ENDIF


bpBuildFontQuad PROC EXPORT
	invoke glGenLists, 1
	mov bpFontQuad, eax
	invoke glNewList, bpFontQuad, GL_COMPILE
	invoke glBegin, GL_QUADS
		invoke glTexCoord2i, 0, 1
		invoke glVertex2i, 0, 1
		invoke glTexCoord2i, 1, 1
		invoke glVertex2i, 1, 1
		invoke glTexCoord2i, 1, 0
		invoke glVertex2i, 1, 0
		invoke glTexCoord2i, 0, 0
		invoke glVertex2i, 0, 0
	invoke glEnd
	invoke glEndList
	ret
bpBuildFontQuad ENDP

IFDEF BP3D_IMPORTERS_INC
bpLoadFont PROC EXPORT DirPath:BPPtr, FontPTR:BPPtr
	LOCAL dirLen:BPPtr, stringBuf:BPPtr
	
	mov pax, DirPath
	.WHILE (BYTE PTR [pax])
		inc pax
	.ENDW
	sub pax, DirPath
	mov dirLen, pax
	
	add pax, 8
	invoke bpMalloc, bpDefHeap, HEAP_ZERO_MEMORY, pax
	mov stringBuf, pax
	
	invoke RtlMoveMemory, stringBuf, DirPath, dirLen
	
	push pbx
	mov pbx, dirLen
	
	mov pax, stringBuf
	mov BYTE PTR [pax+pbx+3], "."
	mov BYTE PTR [pax+pbx+4], "b"
	mov BYTE PTR [pax+pbx+5], "p"
	mov BYTE PTR [pax+pbx+6], "t"
	
	xor pbx, pbx
	.WHILE (pbx < 128)
		; Convert pbx to string
		mov pax, dirLen
		add pax, stringBuf
		.IF (pbx >= 100)
			mov BYTE PTR [pax], "1"
		.ELSE
			mov BYTE PTR [pax], "0"
		.ENDIF
		mov pax, pbx
		mov pcx, 10
		xor pdx, pdx
		div pcx
		xor pdx, pdx
		div pcx
		add pdx, 48
		
		mov pax, dirLen
		add pax, stringBuf
		inc pax
		mov BYTE PTR [pax], dl
		
		mov pax, pbx
		mov pcx, 10
		xor pdx, pdx
		div pcx
		add pdx, 48
		
		mov pax, dirLen
		add pax, stringBuf
		add pax, 2
		mov BYTE PTR [pax], dl
		
		mov pax, pbx
		mov pcx, 4
		mul pcx
		add pax, FontPTR
		invoke bpLoadBPT, pax, stringBuf
		invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP 
		invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP 
		
		inc pbx
	.ENDW
	pop pbx
	
	invoke bpFree, bpDefHeap, 0, stringBuf
	
	.IF (!bpFontQuad)
		call bpBuildFontQuad
	.ENDIF
	ret
bpLoadFont ENDP
ENDIF

bpRenderText PROC EXPORT TextString:BPPtr, X:SDWORD, Y:SDWORD, \
HorizontalAlign:BPEnum, VerticalAlign:BPEnum
	LOCAL pos[2]:REAL4, strLength:BPPtr, lines:DWORD
	
	mov strLength, 0
	mov lines, 1
	push pbx
	mov pbx, TextString
	.WHILE (BYTE PTR [pbx])
		mov al, BYTE PTR [pbx]
		.IF (al == bpTextNL)
			inc lines
		.ENDIF
		.IF (lines == 1)
			inc strLength
		.ENDIF
		inc pbx
	.ENDW
	pop pbx
	
	call glPushMatrix
	fild X
	fstp pos[0]
	fild Y
	fstp pos[4]
	invoke glTranslatef, pos[0], pos[4], 0
	invoke glScalef, bpFontWidth, bpFontHeight, 1065353216	; 1.0
	.IF (HorizontalAlign)
		fild strLength
		fmul bpFontSpacing
		.IF (HorizontalAlign == BP_ALIGN_CENTER)
			push 1056964608	; 0.5
			fmul REAL4 PTR [psp]
			pop pax
		.ENDIF
		fchs
		fstp pos[0]
		invoke glTranslatef, pos[0], 0, 0
	.ENDIF
	.IF (VerticalAlign)
		fild lines
		.IF (VerticalAlign == BP_ALIGN_CENTER)
			push 3204448256	; -0.5
			fmul REAL4 PTR [esp]
			add esp, 4
			fstp pos[4]
		.ELSEIF (VerticalAlign == BP_ALIGN_BOTTOM)
			fchs
			fstp pos[4]
		.ENDIF
		invoke glTranslatef, 0, pos[4], 0
	.ENDIF
	
	call glPushMatrix
	push pbx
	xor pbx, pbx
	.WHILE (pbx < strLength)
		mov pcx, TextString
		xor pax, pax
		mov al, BYTE PTR [pcx+pbx]
		
		shl pax, 2
		
		mov pcx, bpCurrentFont
		.IF (DWORD PTR [pcx+pax])
			invoke glBindTexture, GL_TEXTURE_2D, DWORD PTR [pcx+pax]
			invoke glCallList, bpFontQuad
		.ENDIF
		
		invoke glTranslatef, bpFontSpacing, 0, 0
		inc pbx
	.ENDW
	pop pbx
	call glPopMatrix
	call glPopMatrix
	
	.IF (lines > 1)
		fld bpFontHeight
		fiadd Y
		.IF (VerticalAlign)
			fld pos[4]
			fmul bpFontHeight
			fadd
		.ELSE
		.ENDIF
		fistp Y
		mov pax, strLength
		inc pax
		add TextString, pax
		invoke bpRenderText, TextString, X, Y, HorizontalAlign, 0
	.ENDIF
	ret
bpRenderText ENDP

bpUIReset PROC EXPORT
	mov bpUIItems, 0
	ret
bpUIReset ENDP

ELSE
	ECHO BP3D: Duplicate include file BP3DUI.inc
ENDIF
	