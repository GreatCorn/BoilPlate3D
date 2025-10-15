IFNDEF BP3DIMPORTERS_INC
BP3DIMPORTERS_INC EQU <1>

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

BP_CLAMP_INTERPOLATION	EQU <1>	; makes no sense to put it here

; ----- INTERFACE -----

; ----- TYPES -----

BPMesh STRUCT
	Count		DWORD 0	; How many vertex objects are there
	Vertices	BPPtr 0
	TexCoords	BPPtr 0
	Normals		BPPtr 0
	V2Size		BPPtr 0
	V3Size		BPPtr 0
BPMesh ENDS

BPAnimTrack STRUCT
	ByteSize	DWORD 0
	Frames		BPPtr ?
	Looping		BPBool FALSE
BPAnimTrack ENDS

BPAnimFramePRS STRUCT
	Time		DWORD ?
	Position	Vector3 <?, ?, ?>
	Rotation	Vector3 <?, ?, ?>
	Scale		Vector3 <?, ?, ?>
BPAnimFramePRS ENDS

BPAnimFrameMatrix STRUCT
	Time		DWORD ?
	Matrix		REAL4 16 DUP(?)
BPAnimFrameMatrix ENDS

BPAnimFrameMesh STRUCT
	Time		DWORD ?
	Mesh		BPMesh <>
BPAnimFrameMesh ENDS

BPAnimPlayer STRUCT
	TrackPtr	BPPtr 0
	FrameOffset	BPPtr 0
	
	Timer		REAL4 0.0
	Speed		REAL4 1.0
	
	Interpolation	BPEnum BPINTERPOLATION_LINEAR
	
	FrameType BPEnum BPFRAME_PRS
	
	; Case FrameType of BPFRAME_PRS
	;UNION
		Position	BPPtr 0
		Rotation	BPPtr 0
		Scale 		BPPtr 0
	;ENDS
	
	; Case FrameType of BPFRAME_MATRIX
	;UNION
		Matrix		BPPtr 0
	;ENDS
	
	; Case FrameType of BPFRAME_VERTEX
	;UNION
		Mesh		BPPtr 0
		MeshFrameSize BPPtr 0
		MeshUseNormals BPBool TRUE
	;ENDS
BPAnimPlayer ENDS


; ----- CONSTANTS -----

BPT_HEADER EQU 9

BPT_RGB8	EQU 0
BPT_RGBA8	EQU 1
BPT_RGB565	EQU 2
BPT_RGB5A1	EQU 3
BPT_RGBA4	EQU 4
BPT_RGB332	EQU 5
BPT_L8		EQU 6

BPFRAME_PRS		EQU 0
BPFRAME_MATRIX	EQU 1
BPFRAME_VERTEX	EQU 2

BPINTERPOLATION_CONSTANT	EQU 0
BPINTERPOLATION_LINEAR		EQU 1
BPINTERPOLATION_LOGARITHMIC	EQU 2

BPMESH_INTERPOLATE_VERTEX EQU 1
BPMESH_INTERPOLATE_TEXCOORD EQU 2
BPMESH_INTERPOLATE_NORMAL EQU 4

.CONST

.DATA
bpAnimationFPS		REAL4 30.0
bpTextureFiltering	BPBool FALSE

; ----- IMPLEMENTATION -----
.CODE
bpLoadFile PROTO :BPPtr, :BPPtr
bpTexImage2D PROTO :DWORD, :DWORD, :BYTE, :BPPtr

bpCheckFileInvalid MACRO
	.IF (pax == INVALID_HANDLE_VALUE)
		IFDEF print
			print "File "
			print FilePath
			print " not found!", 13, 10
		ENDIF
		xor pax, pax
		ret
	.ENDIF
ENDM

s MACRO qStr:REQ
	LOCAL strDb
	.DATA
		strDb DB qStr,0
	.CODE
	EXITM <ADDR strDb>
ENDM

;   Load barebones animation track implementation - sequence of 28-byte frames: WRONGr 
; Time:DWORD, Position:Vector3, Rotation:Vector3.
LoadBPA MACRO BPAnimPTR:REQ, FilePath:REQ
	invoke bpLoadBPA, BPAnimPTR, s(FilePath)
ENDM

;   Load a file storing interleaved sequences of UV (x, y), normal (x, y, z) and
; vertex (x, y, z) REAL4 values as a GL list. Rendered using glCallList.
;   GLListPTR - pointer to an uninitialized OpenGL list.
;   FilePath - quoted file path string.
LoadBPL MACRO GLListPTR:REQ, FilePath:REQ
	invoke bpLoadBPL, GLListPTR, s(FilePath)
ENDM

;   Load a file storing sequences of vertex (x, y, z), UV (x, y), and normal
; (x, y, z) REAL4 values as a BPMesh struct. Rendered using bpDrawMesh 
; (subsequent glDrawArrays calls).
;   BPMeshPTR - pointer to a BPMesh structure.
;   FilePath - quoted file path string.
LoadBPM MACRO BPMeshPTR:REQ, FilePath:REQ
	invoke bpLoadBPM, BPMeshPTR, s(FilePath)
ENDM

;   Load a Boil Plate texture - a raw image file with a BPT_HEADER-byte header
; which specifies its color format and dimensions.
;   TexturePTR - pointer to an uninitialized OpenGL texture.
;   FilePath - quoted file path string.
LoadBPT MACRO TexturePTR:REQ, FilePath:REQ
	invoke bpLoadBPT, TexturePTR, s(FilePath)
ENDM

;   Load a file's entire contents and return the allocated buffer in pax. 
; Returns 0 if file is not found.
;   FilePath - quoted file path string.
LoadFile MACRO FilePath:REQ
	invoke bpLoadFile, s(FilePath), 0
ENDM

;   Unified vertex, texcoord and normal drawing procedure for BPMesh structure.
;   BPMeshPtr - pointer to a BPMesh structure.
bpDrawMesh PROC EXPORT BPMeshPtr:BPPtr
	push pbx
	ASSUME pbx:PTR BPMesh
	mov pbx, BPMeshPtr
	
	invoke glVertexPointer, 3, GL_FLOAT, 0, [pbx].Vertices
	invoke glTexCoordPointer, 2, GL_FLOAT, 0, [pbx].TexCoords
	invoke glNormalPointer, GL_FLOAT, 0, [pbx].Normals
	invoke glDrawArrays, GL_TRIANGLES, 0, [pbx].Count
	
	;push BPMeshPtr
	;call bpDrawNormals
	
	ASSUME pbx:nothing
	pop pbx
	ret
bpDrawMesh ENDP

;   Debug utility to draw normal vector lines of a mesh.
bpDrawNormals PROC EXPORT BPMeshPtr:BPPtr
	LOCAL lighting:BPBool, col:Vector4, tex:DWORD, vertex:Vector3
	
	invoke glGetBooleanv, GL_LIGHTING, ADDR lighting
	invoke glGetFloatv, GL_CURRENT_COLOR, ADDR col
	invoke glGetIntegerv, GL_TEXTURE_BINDING_2D, ADDR tex
	
	invoke glDisable, GL_LIGHTING
	invoke glColor3f, 1065353216, 0, 0	; 1.0, 0, 0
	invoke glBindTexture, GL_TEXTURE_2D, 0
	
	invoke glBegin, GL_LINES
	
	push pbx
	xor pbx, pbx
	ASSUME pdx:PTR BPMesh
	mov pdx, BPMeshPtr
	.WHILE (pbx < [pdx].V3Size)
		mov pax, pbx
		add pax, [pdx].Vertices
		invoke Vector3Copy, ADDR vertex, pax
		invoke glVertex3fv, ADDR vertex
		mov pax, pbx
		mov pdx, BPMeshPtr
		add pax, [pdx].Normals
		invoke Vector3Add, ADDR vertex, pax
		invoke glVertex3fv, ADDR vertex
		
		mov pdx, BPMeshPtr
		add pbx, SIZEOF Vector3
	.ENDW
	ASSUME pdx:nothing
	pop pbx
	invoke glEnd
	
	invoke glColor3fv, ADDR col
	.IF (lighting)
		invoke glEnable, GL_LIGHTING
	.ENDIF
	invoke glBindTexture, GL_TEXTURE_2D, tex
	
	ret
bpDrawNormals ENDP

bpFreeBPA PROC EXPORT BPAnimPTR:BPPtr
	ASSUME pax:PTR BPAnimTrack
	
	mov pax, BPAnimPTR
	invoke bpFree, bpDefHeap, 0, [pax].Frames
	
	ASSUME pax:nothing
	ret
bpFreeBPA ENDP

bpFreeBPM PROC EXPORT BPMeshPTR:BPPtr
	push pbx
	ASSUME pbx:PTR BPMesh
	mov pbx, BPMeshPTR
	
	invoke bpFree, bpDefHeap, 0, [pbx].Vertices
	invoke bpFree, bpDefHeap, 0, [pbx].TexCoords
	invoke bpFree, bpDefHeap, 0, [pbx].Normals
	ASSUME pbx:nothing
	pop pbx
	ret
bpFreeBPM ENDP

bpLoadBPA PROC EXPORT BPAnimPTR:BPPtr, FilePath:BPPtr
	LOCAL hFile:HANDLE, dwHighSize:DWORD, dwFileSize:DWORD, dwArraySize:DWORD
	LOCAL dwBytesRead:DWORD
	ASSUME pcx:PTR BPAnimTrack
	
	invoke CreateFile, FilePath, GENERIC_READ, FILE_SHARE_READ, 0, \
	OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0
    mov hFile, pax
	
	bpCheckFileInvalid

    invoke GetFileSize, hFile, ADDR dwHighSize
    mov dwFileSize, eax
	invoke bpMalloc, bpDefHeap, 0, dwFileSize
	mov pcx, BPAnimPTR
	mov [pcx].Frames, pax
	bpMEM32 [pcx].ByteSize, dwFileSize
	
	push 0
	lea pax, dwBytesRead
	push pax
	bpPush32 dwFileSize
	push [pcx].Frames
	push hFile
	call ReadFile
		
	IFDEF BP_IMPORTERS_VERBOSE
	IFDEF print
		push pax
		print FilePath, 9
		print "ReadFile value:", 32
		pop pax
		push pax
		print str$(eax), 9
		pop pax
		push pax
		print "bytes read:", 32
		print str$(dwBytesRead), 9
		print "file size:", 32
		print str$(dwFileSize), 13, 10
		pop pax
	ENDIF
	ENDIF
	
    invoke CloseHandle, hFile
	
	ASSUME pcx:nothing
	ret
bpLoadBPA ENDP

bpLoadBPL PROC EXPORT GLListPTR:BPPtr, FilePath:BPPtr
	LOCAL buffer:BPPtr, listIndex:DWORD, dwFileSize: DWORD
	
	invoke bpLoadFile, FilePath, ADDR dwFileSize
	mov buffer, pax
	
	invoke glGenLists, 1
	mov listIndex, eax
	invoke glNewList, listIndex, GL_COMPILE
	invoke glBegin, GL_TRIANGLES
	
	push pbx	; Preserve ebx
	xor pbx, pbx
	.WHILE (ebx < dwFileSize)
		mov pax, buffer	; Get the UV data
		mov ecx, DWORD PTR [pax+pbx+4]
		mov eax, DWORD PTR [pax+pbx]
		push pcx
		push pax
		call glTexCoord2f
		add pbx, 8
		
		mov pax, buffer	; Get the normals
		mov edx, DWORD PTR [pax+pbx+8]
		mov ecx, DWORD PTR [pax+pbx+4]
		mov eax, DWORD PTR [pax+pbx]
		push pdx
		push pcx
		push pax
		call glNormal3f
		add pbx, 12
		
		mov pax, buffer	; Get the vertices
		mov edx, DWORD PTR [pax+pbx+8]
		mov ecx, DWORD PTR [pax+pbx+4]
		mov eax, DWORD PTR [pax+pbx]
		push pdx
		push pcx
		push pax
		call glVertex3f
		add pbx, 12
	.ENDW
	pop pbx
	
	invoke glEnd
	invoke glEndList
	
    invoke bpFree, bpDefHeap, 0, buffer
	
	mov pax, GLListPTR
	mov ecx, listIndex
	mov DWORD PTR [pax], ecx
	ret
bpLoadBPL ENDP

bpLoadBPM PROC EXPORT BPMeshPTR:BPPtr, FilePath:BPPtr
	LOCAL hFile:HANDLE, dwHighSize:DWORD, dwFileSize:DWORD, dwArraySize:DWORD
	LOCAL v3Size:BPPtr, v2Size:BPPtr, dwBytesRead:DWORD
	push pbx
	ASSUME pbx:PTR BPMesh
	mov pbx, BPMeshPTR
	
	invoke CreateFile, FilePath, GENERIC_READ, FILE_SHARE_READ, 0, \
	OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0
    mov hFile, pax
	
	bpCheckFileInvalid

    invoke GetFileSize, hFile, ADDR dwHighSize
    mov dwFileSize, eax
	
	mov eax, dwFileSize
	mov ecx, 8
	xor edx, edx
	div ecx
	mov dwArraySize, eax
	push pax
	
	mov ecx, 4
	div ecx
	mov [pbx].Count, eax
	
	pop pax
	mov ecx, 3				; Allocate the Vertices array
	mul ecx
	mov v3Size, pax
	invoke bpMalloc, bpDefHeap, 0, v3Size
	mov [pbx].Vertices, pax
	bpMPM [pbx].V3Size, v3Size
	
	mov eax, dwArraySize	; Allocate the TexCoords array
	mov ecx, 2
	mul ecx
	mov v2Size, pax
	invoke bpMalloc, bpDefHeap, 0, v2Size
	mov [pbx].TexCoords, pax
	bpMPM [pbx].V2Size, v2Size
	
	invoke bpMalloc, bpDefHeap, 0, v3Size	; Allocate the Normals array
	mov [pbx].Normals, pax
	
	push 0
	lea pax, dwBytesRead
	push pax
	push v3Size
	push [pbx].Vertices
	push hFile
    call ReadFile
	
	push 0
	lea pax, dwBytesRead
	push pax
	push v2Size
	push [pbx].TexCoords
	push hFile
    call ReadFile
	
	push 0
	lea pax, dwBytesRead
	push pax
	push v3Size
	push [pbx].Normals
	push hFile
    call ReadFile
	
	
	IFDEF BP_IMPORTERS_VERBOSE
	IFDEF print
		pushad
		print FilePath, 9
		print "ReadFile value:", 32
		popad
		pushad
		print str$(eax), 9
		popad
		print "bytes read:", 32
		print str$(dwBytesRead), 9
		print "file size:", 32
		print str$(dwFileSize), 13, 10
	ENDIF
	ENDIF
	
    invoke CloseHandle, hFile
	
	ASSUME pbx:nothing
	pop pbx
	ret
bpLoadBPM ENDP

bpLoadBPT PROC EXPORT TexturePTR:BPPtr, FilePath:BPPtr
	LOCAL buffer:BPPtr, texIndex:DWORD, texType:BYTE, texW:DWORD, texH:DWORD
	LOCAL texFormat:DWORD, texDataType:DWORD
	
	invoke bpLoadFile, FilePath, 0
	.IF (!pax)
		ret
	.ENDIF
	mov buffer, pax
	
	mov al, BYTE PTR [pax]
	mov texType, al
	
	add buffer, 1
	mov pax, buffer
	mov eax, DWORD PTR [pax]
	mov texW, eax
	
	add buffer, 4
	mov pax, buffer
	mov eax, DWORD PTR [pax]
	mov texH, eax
	
	add buffer, 4
	
	invoke glGenTextures, 1, ADDR texIndex
	invoke glBindTexture, GL_TEXTURE_2D, texIndex
	.IF (bpTextureFiltering)
		invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR
		invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR
	.ELSE
		invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST
		invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST
	.ENDIF
	
	.IF (texType == BPT_RGB8)
		mov texFormat, GL_RGB
		mov texDataType, GL_UNSIGNED_BYTE
	.ELSEIF (texType == BPT_RGBA8)
		mov texFormat, GL_RGBA
		mov texDataType, GL_UNSIGNED_BYTE
	.ELSEIF (texType == BPT_RGB565)
		mov texFormat, GL_RGB
		mov texDataType, 8363h	; GL_UNSIGNED_SHORT_5_6_5
	.ELSEIF (texType == BPT_RGB5A1)
		mov texFormat, GL_RGBA
		mov texDataType, 8034h	; GL_UNSIGNED_SHORT_5_5_5_1
	.ELSEIF (texType == BPT_RGBA4)
		mov texFormat, GL_RGBA
		mov texDataType, 8033h	; GL_UNSIGNED_SHORT_4_4_4_4
	.ELSEIF (texType == BPT_RGB332)
		mov texFormat, GL_RGB
		mov texDataType, 8032h	; GL_UNSIGNED_BYTE_3_3_2
	.ELSEIF (texType == BPT_L8)
		mov texFormat, GL_LUMINANCE
		mov texDataType, GL_UNSIGNED_BYTE
	.ENDIF
	
	;   On some devices the OpenGL implementation behaves weirdly with mipmaps
	; and tries to build its own, even when it's not specified in code. This may
	; result in a lot of lag whenever there are many instances of a texture 
	; being used. On other devices, however, gluBuild#DMipmaps may not recognize
	; the extended texture color formats and will result in a GLU_INVALID_ENUM
	; error. On some older ones, neither gluBuild#DMipmaps or glTexImage2D will
	; be able to use the formats, so manual parsing must be done instead.
	IFDEF BP_FORCE_MANUAL_TEXTURE
		invoke bpTexImage2D, texW, texH, texType, buffer
	ELSE
		push buffer
		bpPush32 texDataType
		bpPush32 texFormat
		bpPush32 texH
		bpPush32 texW
		.IF (texFormat == GL_RGBA)
			mov eax, 4
		.ELSEIF (texFormat == GL_LUMINANCE)
			mov eax, 1
		.ELSE
			mov eax, 3
		.ENDIF
		push pax
		push GL_TEXTURE_2D
		call gluBuild2DMipmaps
		
		push pax
		invoke glGetError
		pop pcx
		.IF (eax || ecx)
			invoke glTexImage2D, GL_TEXTURE_2D, 0, texFormat, texW, texH, 0, \
			texFormat, texDataType, buffer
			call glGetError
			.IF (eax)
				; Fine, I'll do it myself
				invoke bpTexImage2D, texW, texH, texType, buffer
			.ENDIF
		.ENDIF
	ENDIF
	
	sub buffer, 9
    invoke bpFree, bpDefHeap, 0, buffer
	
	mov pax, TexturePTR
	mov ecx, texIndex
	mov DWORD PTR [pax], ecx
	ret
bpLoadBPT ENDP

bpLoadFile PROC EXPORT FilePath:BPPtr, FileSizePtr:BPPtr
	LOCAL hFile:HANDLE, dwFileSize:DWORD, dwBytesRead:DWORD, dwHighSize:DWORD
	LOCAL buffer:BPPtr
	
	invoke CreateFile, FilePath, GENERIC_READ, FILE_SHARE_READ, 0, \
	OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0
    mov hFile, pax
	
	bpCheckFileInvalid

    invoke GetFileSize, hFile, ADDR dwHighSize
    mov dwFileSize, eax
	.IF (FileSizePtr)
		mov pcx, FileSizePtr
		mov DWORD PTR [pcx], eax
	.ENDIF
	invoke bpMalloc, bpDefHeap, 0, dwFileSize
	mov buffer, pax

    invoke ReadFile, hFile, buffer, dwFileSize, ADDR dwBytesRead, 0
	
	IFDEF BP_IMPORTERS_VERBOSE
	IFDEF print
		pushad
		print FilePath, 9
		print "ReadFile value:", 32
		popad
		pushad
		print str$(eax), 9
		popad
		print "bytes read:", 32
		print str$(dwBytesRead), 9
		print "file size:", 32
		print str$(dwFileSize), 13, 10
	ENDIF
	ENDIF
	
    invoke CloseHandle, hFile
	
	mov pax, buffer
	ret
bpLoadFile ENDP

bpTexImage2D PROC EXPORT TextureWidth:DWORD, TextureHeight:DWORD, \
TextureType:BYTE, Buffer:BPPtr
	LOCAL area:BPPtr, parsed:BPPtr, parsedSize:BPPtr
	LOCAL col[4]:BYTE, hasAlpha:BPBool
	
	mov eax, TextureWidth
	mov ecx, TextureHeight
	mul ecx
	mov area, pax
	; RGBA
	.IF (TextureType == BPT_RGB5A1) || (TextureType == BPT_RGBA4)
		shl eax, 2	; * 4
		mov hasAlpha, TRUE
	.ELSE
		mov ecx, 3
		mul ecx
		mov hasAlpha, FALSE
	.ENDIF
	mov parsedSize, pax
	
	invoke bpMalloc, bpDefHeap, 0, parsedSize
	mov parsed, pax
	push pbx
	xor pbx, pbx
	.WHILE (pbx < area)
		mov pcx, pbx
		.IF (TextureType == BPT_RGB565) || (TextureType == BPT_RGB5A1) || \
		(TextureType == BPT_RGBA4)
			shl pcx, 1	; * 2
		.ENDIF
		add pcx, Buffer
		
		.IF (TextureType == BPT_RGB565)
			mov al, BYTE PTR [pcx+1]	; Red
			shr al, 3
			;and al, 00011111b
			shl al, 3	; * 8
			mov col[0], al
			
			mov ax, WORD PTR [pcx]	; Green
			shr ax, 5
			and al, 00111111b
			shl al, 2	; * 4
			mov col[1], al
			
			mov al, BYTE PTR [pcx]	; Blue
			and al, 00011111b
			shl al, 3	; * 8
			mov col[2], al
		.ELSEIF (TextureType == BPT_RGB5A1)
			mov al, BYTE PTR [pcx+1]	; Red
			shr al, 3
			;and al, 00011111b
			shl al, 3	; * 8
			mov col[0], al
			
			mov ax, WORD PTR [pcx]	; Green
			shr ax, 6
			and al, 00011111b
			shl al, 3	; * 4
			mov col[1], al
			
			mov al, BYTE PTR [pcx]	; Blue
			shr al, 1
			and al, 00011111b
			shl al, 3	; * 8
			mov col[2], al
			
			mov al, BYTE PTR [pcx]	; Alpha
			shl al, 7
			mov col[3], al
		.ELSEIF (TextureType == BPT_RGBA4)
			mov al, BYTE PTR [pcx+1]	; Red
			shr al, 4
			;and al, 00001111b
			shl al, 4	; * 16
			mov col[0], al
			
			mov al, BYTE PTR [pcx+1]	; Green
			shl al, 4	; * 16
			mov col[1], al
			
			mov al, BYTE PTR [pcx]	; Blue
			shr al, 4
			;and al, 00001111b
			shl al, 4	; * 16
			mov col[2], al
			
			mov al, BYTE PTR [pcx]	; Alpha
			shl al, 4	; * 16
			mov col[3], al
		.ELSEIF (TextureType == BPT_RGB332)
			mov al, BYTE PTR [pcx]	; Red
			shr al, 5
			;and al, 00000111b
			shl al, 5	; * 32
			mov col[0], al
			
			mov al, BYTE PTR [pcx]	; Green
			shr al, 2
			and al, 00000111b
			shl al, 5	; * 32
			mov col[1], al
			
			mov al, BYTE PTR [pcx]	; Blue
			shl al, 6	; * 64
			mov col[2], al
		.ENDIF
		
		mov pax, pbx
		.IF (hasAlpha)
			shl eax, 2	; * 4
		.ELSE
			mov ecx, 3
			mul ecx
		.ENDIF
		add pax, parsed
		mov cx, WORD PTR col[0]
		mov BYTE PTR [pax], cl
		mov BYTE PTR [pax+1], ch
		mov cx, WORD PTR col[2]
		mov BYTE PTR [pax+2], cl
		.IF (hasAlpha)
			mov BYTE PTR [pax+3], ch
		.ENDIF
		
		inc pbx
	.ENDW
	pop pbx
	
	.IF (hasAlpha)
		mov eax, GL_RGBA
		mov edx, 4
	.ELSE
		mov eax, GL_RGB
		mov edx, 3
	.ENDIF
	push parsed
	push GL_UNSIGNED_BYTE
	push pax
	bpPush32 TextureHeight
	bpPush32 TextureWidth
	push pdx
	push GL_TEXTURE_2D
	call gluBuild2DMipmaps
	
	invoke bpFree, bpDefHeap, 0, parsed
	ret
bpTexImage2D ENDP

IFDEF BP3D_MATHS_INC
IFDEF BP3DVECTORS_INC 
bpProcessAnimPlayer PROC EXPORT BPAnimPlrPTR:BPPtr
	LOCAL floatVal:REAL4, animSpd:REAL4, fact:REAL4
	LOCAL frameAddr:BPPtr
	LOCAL timeOffset:BPPtr, intFrameSize:BPPtr, intStructSize:BPPtr
	LOCAL resFrame:BPPtr
	
	mov resFrame, FALSE
	
	ASSUME pcx:PTR BPAnimPlayer
	mov pcx, BPAnimPlrPTR
	.IF ([pcx].TrackPtr)
		.IF (([pcx].FrameType == BPFRAME_VERTEX) && !([pcx].MeshFrameSize))
			mov pax, [pcx].Mesh			; Get frame size
			mov eax, DWORD PTR [pax]	; Get count of vertices
			.IF ([pcx].MeshUseNormals)
				add eax, eax
			.ENDIF
			mov edx, 12
			mul edx
			add eax, 4	; This is the time DWORD
			mov [pcx].MeshFrameSize, pax
		.ENDIF
	
		ASSUME pdx:PTR BPAnimTrack
		
		fld [pcx].Speed
		fmul bpAnimationFPS
		fmul deltaTime
		fstp animSpd
		
		fld [pcx].Timer
		fistp floatVal	; Round timer for comparing
		
		mov pdx, [pcx].TrackPtr		; Get the current track
		mov pax, [pdx].Frames		; Get the track's frames
		add pax, [pcx].FrameOffset	; Get current pointer offset in Frames
		mov frameAddr, pax
		
		push pbx	; We will be using pbx, so we'll pop it at the end
		
		mov eax, DWORD PTR [pax]	; Get current frame's time (first 4 bytes)
		.WHILE (floatVal >= eax)
			mov resFrame, TRUE
			.IF ([pcx].FrameType == BPFRAME_PRS)
				add [pcx].FrameOffset, SIZEOF BPAnimFramePRS
				add frameAddr, SIZEOF BPAnimFramePRS
			.ELSEIF ([pcx].FrameType == BPFRAME_MATRIX)
				add [pcx].FrameOffset, SIZEOF BPAnimFrameMatrix
				add frameAddr, SIZEOF BPAnimFrameMatrix
			.ELSEIF ([pcx].FrameType == BPFRAME_VERTEX)
				mov pax, [pcx].MeshFrameSize
				add [pcx].FrameOffset, pax
				add frameAddr, pax
			.ENDIF
			mov eax, [pdx].ByteSize
			.IF ([pcx].FrameOffset >= pax)
				.IF ([pdx].Looping)
					mov [pcx].FrameOffset, 0
					mov [pcx].Timer, 0 ; Should be sub (-) framecount*FPS or smth
					jmp bpAnimExit
				.ELSE
					mov [pcx].TrackPtr, 0
					jmp bpAnimExit
				.ENDIF
			.ENDIF
			mov pax, frameAddr
			mov eax, DWORD PTR [pax]
		.ENDW
		.IF ([pcx].FrameType == BPFRAME_PRS)
			mov intStructSize, SIZEOF Vector3
			mov intFrameSize, SIZEOF BPAnimFramePRS
			
			;pop pbx	; Pop current frame
			mov pbx, frameAddr
			add pbx, 4	; Now pbx is Value
			.IF ([pcx].Position)
				.IF ([pcx].Interpolation == BPINTERPOLATION_CONSTANT)
					invoke Vector3Copy, [pcx].Position, pbx
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LINEAR)
					mov timeOffset, 4			; Byte offset from Frame.Time
					mov pcx, [pcx].Position		; Output to this address
					push bpAnimInterpolatePositionEnd	; To avoid ret
					jmp bpAnimInterpolateLinear
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LOGARITHMIC)
				
				.ENDIF
			.ENDIF
			bpAnimInterpolatePositionEnd:
			
			add pbx, SIZEOF Vector3	; Now pbx is Rotation:Vector3
			mov pcx, BPAnimPlrPTR
			.IF ([pcx].Rotation)
				.IF ([pcx].Interpolation == BPINTERPOLATION_CONSTANT)
					invoke Vector3Copy, [pcx].Rotation, pbx
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LINEAR)
					mov timeOffset, 4+SIZEOF Vector3
					mov pcx, [pcx].Rotation
					push bpAnimInterpolateRotationEnd
					jmp bpAnimInterpolateLinear
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LOGARITHMIC)
				
				.ENDIF
			.ENDIF
			bpAnimInterpolateRotationEnd:
			
			add pbx, SIZEOF Vector3	; Now pbx is Scale:Vector3
			mov pcx, BPAnimPlrPTR
			.IF ([pcx].Scale)
				.IF ([pcx].Interpolation == BPINTERPOLATION_CONSTANT)
					invoke Vector3Copy, [pcx].Scale, pbx
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LINEAR)
					mov timeOffset, 4+SIZEOF Vector3*2
					mov pcx, [pcx].Scale
					push bpAnimInterpolateEnd
					jmp bpAnimInterpolateLinear
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LOGARITHMIC)
				
				.ENDIF
			.ENDIF
		.ELSEIF ([pcx].FrameType == BPFRAME_MATRIX)
			mov pbx, frameAddr
			add pbx, 4
			
			.IF ([pcx].Matrix)
				.IF ([pcx].Interpolation == BPINTERPOLATION_CONSTANT)
					mov pcx, [pcx].Matrix
					xor pax, pax
					.WHILE (pax < SIZEOF REAL4 * 16)
						IFDEF rax
							fld REAL4 PTR [pbx+pax]
							fstp REAL4 PTR [pcx+pax]
						ELSE
							bpMPM REAL4 PTR [pcx+pax], REAL4 PTR [pbx+pax]
						ENDIF
						add pax, 4
					.ENDW
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LINEAR)
					mov intStructSize, SIZEOF REAL4 * 16
					mov intFrameSize, SIZEOF BPAnimFrameMatrix
					
					mov timeOffset, 4
					mov pcx, [pcx].Matrix
					push bpAnimInterpolateEnd
					jmp bpAnimInterpolateLinear
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LOGARITHMIC)
					
				.ENDIF
			.ENDIF
		.ELSEIF ([pcx].FrameType == BPFRAME_VERTEX)
			mov pbx, frameAddr
			add pbx, 4
			
			.IF ([pcx].Mesh)
				bpMPM intStructSize, [pcx].MeshFrameSize	; The mesh itself
				sub intStructSize, 4
				.IF ([pcx].MeshUseNormals)	; The frame data is twice as large
					push pcx
					mov pax, intStructSize
					xor pdx, pdx
					mov pcx, 2
					div pcx
					mov intStructSize, pax
					pop pcx
				.ENDIF
				.IF ([pcx].Interpolation == BPINTERPOLATION_CONSTANT)
					mov pax, [pcx].Mesh
					mov BPPtr PTR [pax+4], pbx	; The pointer to vertices
					.IF ([pcx].MeshUseNormals)
						add pbx, intStructSize
						mov pax, [pcx].Mesh
						mov BPPtr PTR [pax+4+SIZEOF BPPtr*2], pbx	; Normals
					.ENDIF
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LINEAR)
					bpMPM intFrameSize, [pcx].MeshFrameSize	; Time + mesh
					
					mov timeOffset, 4
					mov pcx, [pcx].Mesh
					mov pcx, BPPtr PTR [pcx+4]	; Vertices pointer
					push bpAnimInterpolateVerticesEnd
					jmp bpAnimInterpolateLinear
					bpAnimInterpolateVerticesEnd:
					
					mov pcx, BPAnimPlrPTR
					.IF ([pcx].MeshUseNormals)
						mov pax, intStructSize
						add pbx, pax
						add timeOffset, pax
						mov pcx, [pcx].Mesh
						mov pcx, BPPtr PTR [pcx+4+SIZEOF BPPtr*2]	; Normals
						push bpAnimInterpolateEnd
						jmp bpAnimInterpolateLinear						
					.ENDIF
				.ELSEIF ([pcx].Interpolation == BPINTERPOLATION_LOGARITHMIC)
					
				.ENDIF
			.ENDIF
		.ENDIF
		bpAnimInterpolateEnd:
		
		mov pcx, BPAnimPlrPTR
		fld animSpd		; Inc timer, for some reason deltaTime doesn't really work and is shit
		fadd [pcx].Timer	; Tested on other stuff, really takes a toll on animation only
		fstp [pcx].Timer
		
		pop pbx
		ASSUME pdx:nothing
	.ENDIF
	
	bpAnimExit:
	ASSUME pcx:nothing
	
	mov pax, resFrame
	ret
	
	bpAnimInterpolateLinear:
		mov pdx, pbx			; pbx is the current frame's value
		sub pdx, intFrameSize	; Get previous frame value in pdx
		
		push pbx			; Calculate time distance between two frames
		push pdx
		sub pbx, timeOffset	; The offset from first 4 bytes = Frame.Time
		sub pdx, timeOffset
		fild DWORD PTR [pbx]
		fisub DWORD PTR [pdx]
		pop pdx
		pop pbx
		fstp floatVal
			
		xor pax, pax
		.WHILE(pax < intStructSize)
			fld animSpd
			fdiv floatVal
			fstp fact
			IFDEF BP_CLAMP_INTERPOLATION
				push pax
				invoke flClamp, fact, 0, 1065353216	; fact, 0, 1.0
				mov fact, eax
				pop pax
			ENDIF
			fld REAL4 PTR [pbx+pax]	; Desired value (current frame)
			fsub REAL4 PTR [pcx]	; Current value
			
			fmul fact
			fadd REAL4 PTR [pcx]
			fstp REAL4 PTR [pcx]
			
			add pcx, 4	; Output offset
			add pax, 4	; i++
		.ENDW
		pop pax	; pop label from stack
		jmp pax
bpProcessAnimPlayer ENDP
ENDIF
ENDIF

ELSE
	ECHO BP3D: Duplicate include file BP3DImporters.inc
ENDIF
