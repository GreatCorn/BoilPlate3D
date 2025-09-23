BPTEXTALIGN_LEFT EQU 0
BPTEXTALIGN_CENTER EQU 1
BPTEXTALIGN_RIGHT EQU 2
BPTEXTALIGN_TOP EQU BPTEXTALIGN_LEFT
BPTEXTALIGN_BOTTOM EQU BPTEXTALIGN_RIGHT

.DATA
bpCurrentFont BPPtr OFFSET bpDefaultFont
bpDefaultFont DWORD 127 dup (0) 

bpFontWidth REAL4 8.0
bpFontHeight REAL4 16.0
bpFontSpacing REAL4 1.25

.DATA?
bpFontQuad DWORD ?

.CODE

IFDEF BP3DIMPORTERS_INC

LoadFont MACRO DirPath:REQ, FontPTR
	IFB <FontPTR>
		invoke bpLoadFont, expand_prefix(reparg(DirPath)), OFFSET bpDefaultFont
	ELSE
		invoke bpLoadFont, expand_prefix(reparg(DirPath)), FontPTR
	ENDIF
ENDM
RenderText MACRO TextString:REQ, X:=<0>, Y:=<0>, \
HorizontalAlign:=<BPTEXTALIGN_LEFT>, VerticalAlign:=<BPTEXTALIGN_TOP>
	invoke bpRenderText, expand_prefix(reparg(TextString)), X, Y, \
	HorizontalAlign, VerticalAlign
ENDM


bpBuildFontQuad PROC EXPORT
	mov bpFontQuad, rv(glGenLists, 1)
	invoke glNewList, bpFontQuad, GL_COMPILE_AND_EXECUTE
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

bpLoadFont PROC EXPORT DirPath:BPPtr, FontPTR:BPPtr
	LOCAL dirLen:BPPtr, stringBuf:BPPtr
	
	print "Loading font from "
	print DirPath, 13, 10
	
	invoke StrLen, DirPath
	mov dirLen, pax
	add pax, 7
	invoke bpMalloc, rv(GetProcessHeap), HEAP_ZERO_MEMORY, pax
	mov stringBuf, pax
	
	push pbx
	xor pbx, pbx
	mov pcx, DirPath
	.WHILE (pbx <= dirLen)
		mov dl, BYTE PTR [pcx+pbx]
		mov BYTE PTR [pax+pbx], dl
		inc pbx
	.ENDW
	
	mov BYTE PTR [pax+pbx+2], "."
	mov BYTE PTR [pax+pbx+3], "b"
	mov BYTE PTR [pax+pbx+4], "p"
	mov BYTE PTR [pax+pbx+5], "t"
	
	print stringBuf, 13, 10
	
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
		
		inc pbx
	.ENDW
	pop pbx
	
	invoke bpFree, rv(GetProcessHeap), 0, stringBuf
	
	.IF (!bpFontQuad)
		call bpBuildFontQuad
	.ENDIF
	ret
bpLoadFont ENDP

bpRenderText PROC EXPORT TextString:DWORD, X:SDWORD, Y:SDWORD, HorizontalAlign:BPEnum,\
VerticalAlign:BPEnum
	LOCAL strLength:BPPtr
	
	mov strLength, rv(StrLen, TextString)

	call glPushMatrix
	fild X
	fstp X
	fild Y
	fstp Y
	invoke glTranslatef, X, Y, 0
	invoke glScalef, bpFontWidth, bpFontHeight, 1065353216	; 1.0
	.IF (HorizontalAlign)
		fild strLength
		fmul bpFontSpacing
		.IF (HorizontalAlign == BPTEXTALIGN_CENTER)
			push 1056964608	; 0.5
			fmul REAL4 PTR [psp]
			pop pax
		.ENDIF
		fchs
		fstp X
		invoke glTranslatef, X, 0, 0
	.ENDIF
	.IF (VerticalAlign == BPTEXTALIGN_CENTER)
		invoke glTranslatef, 0, 3204448256, 0	; -0.5
	.ELSEIF (VerticalAlign == BPTEXTALIGN_BOTTOM)
		invoke glTranslatef, 0, 3212836864, 0	; -1.0
	.ENDIF
	
	push pbx
	xor pbx, pbx
	.WHILE (pbx < strLength)
		mov pcx, TextString
		xor pax, pax
		mov al, BYTE PTR [pcx+pbx]
		
		mov pcx, 4
		mul pcx
		
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
	ret
bpRenderText ENDP
ENDIF
