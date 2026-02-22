;
;   BP3DAssets.inc
;   Version 0.5ac1
;   BP3D raw asset format importers (animations, GL lists, dynamic meshes, 
; textures) extension.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;


IFNDEF BP3D_ASSETS_INC
BP3D_ASSETS_INC EQU <1>

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
	ECHO BP3D: WARNING! BP3DAssets.inc GLU calls are invalid and untested on x64.
ENDIF

; ----- INTERFACE -----

; ----- TYPES -----

BPMesh STRUCT
	Count		DWORD 0	; How many vertex objects are there
	Vertices	BPPtr 0	; Pointer to a Vector3[Count] array of mesh vertices
	TexCoords	BPPtr 0	; Pointer to a Vector2[Count] array of mesh UVs
	Normals		BPPtr 0	; Pointer to a Vector3[Count] array of mesh normals
	V2Size		BPPtr 0	; The size, in bytes, of the TexCoords array
	V3Size		BPPtr 0	; The size, in bytes, of the Vertices and Normals arrays
BPMesh ENDS

BPAnimTrack STRUCT
	ByteSize	DWORD 0		; The size, in bytes, of Frames
	Frames		BPPtr ?		; Pointer to an array of abstract frames
	Looping		BPBool FALSE; If the animation restart when its end is reached
BPAnimTrack ENDS

;   Every BPAnimFrame type has a Time DWORD at the start, which contains the
; frame number.
BPAnimFramePRS STRUCT		; (Position:Vector, Rotation:Vector3, Scale:Vector3)
	Time		DWORD ?
	Position	Vector3 <?, ?, ?>
	Rotation	Vector3 <?, ?, ?>
	Scale		Vector3 <?, ?, ?>
BPAnimFramePRS ENDS

BPAnimFrameMatrix STRUCT	; (Matrix[16]:REAL4)
	Time		DWORD ?
	Matrix		REAL4 16 DUP(?)
BPAnimFrameMatrix ENDS

; (Vertex[Mesh.Count]:Vector3, <Normals[Mesh.Count]:Vector3>)
BPAnimFrameVertex STRUCT
	Time		DWORD ?
;	Vertex		Vector3 Mesh.Count DUP (<?, ?, ?>)
;	IF MeshUseNormals
;		Normals		Vector3 Mesh.Count DUP (<?, ?, ?>)
;	ENDIF
BPAnimFrameVertex ENDS

BPAnimPlayer STRUCT			; Animation player
	TrackPtr	BPPtr 0		; Pointer to a BPAnimTrack
	FrameOffset	BPPtr 0		; Pointer offset to add to TrackPtr of current frame
	
	Timer		REAL4 0.0	; The timer that updates FrameOffset
	Speed		REAL4 1.0	; Playback speed (1.0 = 100%)
	
	Interpolation	BPEnum BP_INTERPOLATE_LINEAR	; Frame interpolation type
	
	FrameType	BPEnum BPA_FRAME_PRS	; Frame data type
	FrameSize	BPPtr 0					; Size of individual frame 
	
	; Animation properties binds
	; Case FrameType of BPA_FRAME_PRS
	;UNION
		Position	BPPtr 0		; Pointer to :Vector3
		Rotation	BPPtr 0		; Pointer to :Vector3 (Euler)
		Scale 		BPPtr 0		; Pointer to :Vector3
	;ENDS
	
	; Case FrameType of BPA_FRAME_MATRIX
	;UNION
		Matrix		BPPtr 0		; Pointer to :REAL4[16]
	;ENDS
	
	; Case FrameType of BPA_FRAME_VERTEX
	;UNION
		Mesh			BPPtr 0		; Pointer to BPMesh
		MeshUseNormals	BPBool TRUE	; If normals are included in the frame data
	;ENDS
BPAnimPlayer ENDS


; ----- CONSTANTS -----
;   BP animation interpolation types
;   No interpolation (doesn't copy vertex data and simply changes the BPMesh 
; pointer value if BPAnimPlayer.FrameType is BPA_FRAME_VERTEX and
; BPL_INTERPOLATION_DYNAMIC is not defined).
BP_INTERPOLATE_CONSTANT	EQU 0
;   True linear interpolation. Sets value to interpolated between previous and
; next frame.
BP_INTERPOLATE_LINEAR	EQU 1
;   Speed-based linear interpolation. Calculates amount to move from previous 
; frame value to next frame value in set amount of time. Allows smoothing 
; between animations.
BP_INTERPOLATE_LINEAR_S	EQU 2
BP_INTERPOLATE_LOG		EQU 3	; Logarithmic interpolation (WIP)

; BP animation frame data types
BPA_FRAME_PRS		EQU 0	; BPAnimFramePRS
BPA_FRAME_MATRIX	EQU 1	; BPAnimFrameMatrix
BPA_FRAME_VERTEX	EQU 2	; BPAnimFrameVertex

BPT_HEADER EQU 9	; BP texture header size, in bytes

; BP texture color and data formats
BPT_RGB8	EQU 0	; (R8, G8, B8)		24-bit
BPT_RGBA8	EQU 1	; (R8, G8, B8, A8)	32-bit
BPT_RGB565	EQU 2	; (R5, G6, B5)		16-bit
BPT_RGB5A1	EQU 3	; (R5, G5, B5, A1)	16-bit
BPT_RGBA4	EQU 4	; (R4, G4, B4, A4)	16-bit
BPT_RGB332	EQU 5	; (R3, G3, B2)		8-bit
BPT_L8		EQU 6	; (L8)				8-bit (monochrome, luminance)

.CONST

; ----- DATA FIELDS -----
.DATA
bpAnimationFPS			REAL4 30.0		; Exported FPS for speed calculation
bpAnimInterpolateSpeed	REAL4 1.0		; Linear interpolation factor
bpTextureFiltering		BPBool FALSE	; Enable texture filtering on import

; ----- IMPLEMENTATION -----
.CODE
bpLoadFile PROTO :BPPtr, :BPPtr
bpTexImage2D PROTO :DWORD, :DWORD, :BYTE, :BPPtr

bpCheckFileInvalid MACRO
	.IF (pax == INVALID_HANDLE_VALUE)
		IFDEF BP_IMPORTERS_VERBOSE
		IFDEF print
			print "File "
			print FilePath
			print " not found!", 13, 10
		ENDIF
		ENDIF
		xor pax, pax
		ret
	.ENDIF
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

;   Load abstract animation track data that can be interpreted by a BPAnimPlayer
; based on BPAnimPlayer.FrameType.
LoadBPA MACRO BPAnimPTR:REQ, FilePath:REQ
	invoke bpLoadBPA, BPAnimPTR, s(FilePath)
ENDM

;   Load a file storing interleaved sequences of UV (x, y), normal (x, y, z) and
; vertex (x, y, z) REAL4 values as a GL list. Rendered using glCallList.
;   GLListPtr:BPPtr - pointer to an uninitialized OpenGL list.
;   FilePath:String - quoted file path string.
LoadBPL MACRO GLListPtr:REQ, FilePath:REQ
	invoke bpLoadBPL, GLListPtr, s(FilePath)
ENDM

;   Load a file storing sequences of vertex (x, y, z), UV (x, y), and normal
; (x, y, z) REAL4 values as a BPMesh struct. Rendered using bpDrawMesh 
; (subsequent glDrawArrays calls).
;   BPMeshPtr:BPPtr - pointer to a BPMesh structure.
;   FilePath:String - quoted file path string.
LoadBPM MACRO BPMeshPtr:REQ, FilePath:REQ
	invoke bpLoadBPM, BPMeshPtr, s(FilePath)
ENDM

;   Load a BoilPlate texture - a raw image file with a BPT_HEADER-byte header
; which specifies its color format and dimensions.
;   TexturePtr:BPPtr - pointer to an uninitialized OpenGL texture.
;   FilePath:String - quoted file path string.
LoadBPT MACRO TexturePtr:REQ, FilePath:REQ
	invoke bpLoadBPT, TexturePtr, s(FilePath)
ENDM

;   Load a file's entire contents and return the allocated buffer in pax. 
; Returns 0 if file is not found.
;   FilePath:String - quoted file path string.
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
	
	push pbx
	mov pbx, [pcx].Frames
	invoke ReadFile, hFile, pbx, dwFileSize, ADDR dwBytesRead, 0
	pop pbx
	
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
	LOCAL buffer:BPPtr, listIndex:DWORD, dwFileSize:DWORD
	
	invoke bpLoadFile, FilePath, ADDR dwFileSize
	mov buffer, pax
	
	invoke glGenLists, 1
	mov listIndex, eax
	invoke glNewList, listIndex, GL_COMPILE
	invoke glBegin, GL_TRIANGLES
	
	push pbx	; Preserve pbx
	xor pbx, pbx
	.WHILE (ebx < dwFileSize)
		add pbx, buffer
		
		; Get the UV data
		invoke glTexCoord2fv, pbx
		add pbx, 8
		
		; Get the normals
		invoke glNormal3fv, pbx
		add pbx, 12
		
		; Get the vertices
		invoke glVertex3fv, pbx
		add pbx, 12
		
		sub pbx, buffer
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
	LOCAL v3Size:DWORD, v2Size:DWORD, dwBytesRead:DWORD
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
	mov v3Size, eax
	invoke bpMalloc, bpDefHeap, 0, v3Size
	mov [pbx].Vertices, pax
	mov eax, v3Size
	mov [pbx].V3Size, pax
	
	mov eax, dwArraySize	; Allocate the TexCoords array
	mov ecx, 2
	mul ecx
	mov v2Size, eax
	invoke bpMalloc, bpDefHeap, 0, v2Size
	mov [pbx].TexCoords, pax
	mov eax, v2Size
	mov [pbx].V2Size, pax
	
	invoke bpMalloc, bpDefHeap, 0, v3Size	; Allocate the Normals array
	mov [pbx].Normals, pax
	
    invoke ReadFile, hFile, [pbx].Vertices, v3Size, ADDR dwBytesRead, 0
    invoke ReadFile, hFile, [pbx].TexCoords, v2Size, ADDR dwBytesRead, 0
    invoke ReadFile, hFile, [pbx].Normals, v3Size, ADDR dwBytesRead, 0	
	
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
		.IF (texFormat == GL_RGBA)
			mov eax, 4
		.ELSEIF (texFormat == GL_LUMINANCE)
			mov eax, 1
		.ELSE
			mov eax, 3
		.ENDIF
		
		; Fuck you x64
		invoke gluBuild2DMipmaps, GL_TEXTURE_2D, eax, texW, texH, texFormat, \
		texDataType, buffer
		
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
	invoke gluBuild2DMipmaps, GL_TEXTURE_2D, edx, TextureWidth, TextureHeight, \
	eax, GL_UNSIGNED_BYTE, parsed
	
	invoke bpFree, bpDefHeap, 0, parsed
	ret
bpTexImage2D ENDP

IFDEF BP3D_MATHS_INC
IFDEF BP3D_VECTORS_INC
bpAnimPlay PROC EXPORT BPAnimPlrPtr:BPPtr, BPAnimTrackPtr:BPPtr
	mov pax, BPAnimPlrPtr
	ASSUME pax:PTR BPAnimPlayer
	.IF ([pax].Speed & FLT_NEG)
		; Set FrameOffset to last frame OFFSET
		ASSUME pdx:PTR BPAnimTrack
		mov pdx, BPAnimTrackPtr
		; Get framesize
		ASSUME pcx:PTR BPMesh
		mov pcx, [pax].Mesh
		mov pcx, [pcx].V3Size	; Get vector3 array size (vert,norm)
		.IF ([pax].MeshUseNormals)
			add pcx, pcx
		.ENDIF
		neg pcx
		add pcx, [pdx].ByteSize
		mov [pax].FrameOffset, pcx
		add pcx, [pdx].Frames
		mov ecx, DWORD PTR [pcx]
		push pcx
		fild DWORD PTR [psp]
		fstp [pax].Timer
		add psp, SIZEOF BPPtr
		ASSUME pdx:nothing
	.ELSE
		mov [pax].FrameOffset, 0
		mov [pax].Timer, 0
	.ENDIF
	bpMPM [pax].TrackPtr, BPAnimTrackPtr
	ASSUME pax:nothing
	ret
bpAnimPlay ENDP

bpProcessAnimPlayer PROC EXPORT BPAnimPlrPtr:BPPtr, Delta:REAL4
	LOCAL floatVal:REAL4, animSpd:REAL4, fact:REAL4
	LOCAL frameAddr:BPPtr
	LOCAL timeOffset:BPPtr, intFrameSize:BPPtr, intStructSize:BPPtr
	LOCAL resFrame:BPPtr
	
	mov resFrame, FALSE
	
	ASSUME pcx:PTR BPAnimPlayer
	mov pcx, BPAnimPlrPtr
	.IF ([pcx].TrackPtr)
		; Get frame size
		.IF !([pcx].FrameSize)
			.IF ([pcx].FrameType == BPA_FRAME_PRS)
				mov [pcx].FrameSize, SIZEOF BPAnimFramePRS
			.ELSEIF ([pcx].FrameType == BPA_FRAME_MATRIX)
				mov [pcx].FrameSize, SIZEOF BPAnimFrameMatrix
			.ELSEIF ([pcx].FrameType == BPA_FRAME_VERTEX)
				mov pax, [pcx].Mesh
				ASSUME pax:PTR BPMesh
				mov eax, [pax].V3Size	; Get vector3 array size (vert,norm)
				.IF ([pcx].MeshUseNormals)
					add eax, eax
				.ENDIF
				add eax, 4	; This is the time DWORD
				mov [pcx].FrameSize, pax
			.ENDIF
		.ENDIF
	
		ASSUME pdx:PTR BPAnimTrack
		
		; Get animation speed
		fld [pcx].Speed
		fmul bpAnimationFPS
		fmul Delta
		fstp animSpd
		
		bpAnimate:
		
		fld [pcx].Timer
		fistp floatVal	; Round timer for comparing with frame numbers
		
		mov pdx, [pcx].TrackPtr		; Get the current track
		mov pax, [pdx].Frames		; Get the track's frames
		add pax, [pcx].FrameOffset	; Get current pointer offset in Frames
		mov frameAddr, pax
		
		push pbx	; We will be using pbx, so we'll pop it at the end
		mov eax, DWORD PTR [pax]	; Get current frame's time (first 4 bytes)
		.IF ([pcx].Speed & FLT_NEG)	; Negative speed
			.WHILE (SDWORD PTR floatVal <= eax); Progress frame (if needed)
				mov resFrame, TRUE
				.IF ([pcx].FrameType == BPA_FRAME_PRS)
					sub [pcx].FrameOffset, SIZEOF BPAnimFramePRS
					sub frameAddr, SIZEOF BPAnimFramePRS
				.ELSEIF ([pcx].FrameType == BPA_FRAME_MATRIX)
					sub [pcx].FrameOffset, SIZEOF BPAnimFrameMatrix
					sub frameAddr, SIZEOF BPAnimFrameMatrix
				.ELSEIF ([pcx].FrameType == BPA_FRAME_VERTEX)
					mov pax, [pcx].FrameSize
					sub [pcx].FrameOffset, pax
					sub frameAddr, pax
				.ENDIF
				.IF (SDWORD PTR [pcx].FrameOffset < 0)	; End frame
					.IF ([pdx].Looping)
						; Set FrameOffset to last frame OFFSET
						mov pax, [pdx].ByteSize
						sub pax, [pcx].FrameSize	
						mov [pcx].FrameOffset, pax
						add pax, [pdx].Frames
						
						; Get last frame index and add to timer
						mov eax, DWORD PTR [pax]
						push pax
						fld [pcx].Timer
						fiadd DWORD PTR [psp]
						fstp [pcx].Timer
						add psp, SIZEOF BPPtr
						jmp bpAnimate
					.ELSE
						mov [pcx].TrackPtr, 0
						jmp bpAnimExit
					.ENDIF
				.ENDIF
				mov pax, frameAddr
				mov eax, DWORD PTR [pax]
			.ENDW
		.ELSE						; Positive speed
			.WHILE (SDWORD PTR floatVal >= eax); Progress frame
				mov resFrame, TRUE
				.IF ([pcx].FrameType == BPA_FRAME_PRS)
					add [pcx].FrameOffset, SIZEOF BPAnimFramePRS
					add frameAddr, SIZEOF BPAnimFramePRS
				.ELSEIF ([pcx].FrameType == BPA_FRAME_MATRIX)
					add [pcx].FrameOffset, SIZEOF BPAnimFrameMatrix
					add frameAddr, SIZEOF BPAnimFrameMatrix
				.ELSEIF ([pcx].FrameType == BPA_FRAME_VERTEX)
					mov pax, [pcx].FrameSize
					add [pcx].FrameOffset, pax
					add frameAddr, pax
				.ENDIF
				mov eax, [pdx].ByteSize
				.IF (SDWORD PTR [pcx].FrameOffset >= pax)	; End frame
					.IF ([pdx].Looping)
						; Get last frame's index to subtract from timer
						add pax, [pdx].Frames
						sub pax, [pcx].FrameSize
						mov eax, DWORD PTR [pax]
						push pax
						fld [pcx].Timer
						fisub DWORD PTR [psp]
						fstp [pcx].Timer
						add psp, SIZEOF BPPtr
						
						; FrameOffset from beginning
						mov [pcx].FrameOffset, 0
						;mov [pcx].Timer, 0
						jmp bpAnimate
					.ELSE
						mov [pcx].TrackPtr, 0
						jmp bpAnimExit
					.ENDIF
				.ENDIF
				mov pax, frameAddr
				mov eax, DWORD PTR [pax]
			.ENDW
		.ENDIF
		
		; Interpolate different frame types
		.IF ([pcx].FrameType == BPA_FRAME_PRS)
			mov intStructSize, SIZEOF Vector3
			mov intFrameSize, SIZEOF BPAnimFramePRS
			
			;pop pbx	; Pop current frame
			mov pbx, frameAddr
			add pbx, 4	; Now pbx is Value
			.IF ([pcx].Position)
				.IF ([pcx].Interpolation == BP_INTERPOLATE_CONSTANT)
					invoke Vector3Copy, [pcx].Position, pbx
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR) \
				|| ([pcx].Interpolation == BP_INTERPOLATE_LINEAR_S)
					mov timeOffset, 4			; Byte offset from Frame.Time
					mov pcx, [pcx].Position		; Output to this address
					push bpAnimInterpolatePositionEnd	; To avoid ret
					.IF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR)
						jmp bpAnimInterpolateLinear
					.ELSE
						jmp bpAnimInterpolateLinearS
					.ENDIF
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LOG)
				
				.ENDIF
			.ENDIF
			bpAnimInterpolatePositionEnd:
			
			add pbx, SIZEOF Vector3	; Now pbx is Rotation:Vector3
			mov pcx, BPAnimPlrPtr
			.IF ([pcx].Rotation)
				.IF ([pcx].Interpolation == BP_INTERPOLATE_CONSTANT)
					invoke Vector3Copy, [pcx].Rotation, pbx
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR) \
				|| ([pcx].Interpolation == BP_INTERPOLATE_LINEAR_S)
					mov timeOffset, 4+SIZEOF Vector3
					mov pcx, [pcx].Rotation
					push bpAnimInterpolateRotationEnd
					.IF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR)
						jmp bpAnimInterpolateLinear
					.ELSE
						jmp bpAnimInterpolateLinearS
					.ENDIF
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LOG)
				
				.ENDIF
			.ENDIF
			bpAnimInterpolateRotationEnd:
			
			add pbx, SIZEOF Vector3	; Now pbx is Scale:Vector3
			mov pcx, BPAnimPlrPtr
			.IF ([pcx].Scale)
				.IF ([pcx].Interpolation == BP_INTERPOLATE_CONSTANT)
					invoke Vector3Copy, [pcx].Scale, pbx
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR) \
				|| ([pcx].Interpolation == BP_INTERPOLATE_LINEAR_S)
					mov timeOffset, 4+SIZEOF Vector3*2
					mov pcx, [pcx].Scale
					push bpAnimInterpolateEnd
					.IF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR)
						jmp bpAnimInterpolateLinear
					.ELSE
						jmp bpAnimInterpolateLinearS
					.ENDIF
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LOG)
				
				.ENDIF
			.ENDIF
		.ELSEIF ([pcx].FrameType == BPA_FRAME_MATRIX)
			mov pbx, frameAddr
			add pbx, 4
			
			.IF ([pcx].Matrix)
				.IF ([pcx].Interpolation == BP_INTERPOLATE_CONSTANT)
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
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR) \
				|| ([pcx].Interpolation == BP_INTERPOLATE_LINEAR_S)
					mov intStructSize, SIZEOF REAL4 * 16
					mov intFrameSize, SIZEOF BPAnimFrameMatrix
					
					mov timeOffset, 4
					mov pcx, [pcx].Matrix
					push bpAnimInterpolateEnd
					.IF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR)
						jmp bpAnimInterpolateLinear
					.ELSE
						jmp bpAnimInterpolateLinearS
					.ENDIF
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LOG)
					
				.ENDIF
			.ENDIF
		.ELSEIF ([pcx].FrameType == BPA_FRAME_VERTEX)
			mov pbx, frameAddr
			add pbx, 4
			
			.IF ([pcx].Mesh)
				bpMPM intStructSize, [pcx].FrameSize	; The mesh itself
				sub intStructSize, 4
				.IF ([pcx].MeshUseNormals)	; The frame data is twice as large
					mov pax, intStructSize
					shr pax, 1	; /2
					mov intStructSize, pax
				.ENDIF
				.IF ([pcx].Interpolation == BP_INTERPOLATE_CONSTANT)
					mov pax, [pcx].Mesh
					ASSUME pax:PTR BPMesh
					; Move frame vertices to the mesh
					IFDEF BP_INTERPOLATION_DYNAMIC
						invoke RtlMoveMemory, [pax].Vertices, pbx, \
						intStructSize
						mov pcx, BPAnimPlrPtr
					ELSE	
						mov [pax].Vertices, pbx
					ENDIF
					.IF ([pcx].MeshUseNormals)
						add pbx, intStructSize
						mov pax, [pcx].Mesh
						; Move frame normals to the mesh
						IFDEF BP_INTERPOLATION_DYNAMIC
							invoke RtlMoveMemory, [pax].Normals, pbx, \
							intStructSize
							mov pcx, BPAnimPlrPtr
						ELSE	
							mov [pax].Normals, pbx
						ENDIF
					.ENDIF
					ASSUME pax:nothing
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR) \
				|| ([pcx].Interpolation == BP_INTERPOLATE_LINEAR_S)
					bpMPM intFrameSize, [pcx].FrameSize	; Time + mesh
					
					mov timeOffset, 4
					mov pcx, [pcx].Mesh
					ASSUME pcx:PTR BPMesh
					mov pcx, [pcx].Vertices
					ASSUME pcx:PTR BPAnimPlayer
					push bpAnimInterpolateVerticesEnd
					.IF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR)
						jmp bpAnimInterpolateLinear
					.ELSE
						jmp bpAnimInterpolateLinearS
					.ENDIF
					bpAnimInterpolateVerticesEnd:
					
					mov pcx, BPAnimPlrPtr
					.IF ([pcx].MeshUseNormals)
						mov pax, intStructSize
						add pbx, pax
						add timeOffset, pax
						mov pcx, [pcx].Mesh
						ASSUME pcx:PTR BPMesh
						mov pcx, [pcx].Normals
						ASSUME pcx:PTR BPAnimPlayer
						push bpAnimInterpolateEnd
						.IF ([pcx].Interpolation == BP_INTERPOLATE_LINEAR)
							jmp bpAnimInterpolateLinear
						.ELSE
							jmp bpAnimInterpolateLinearS
						.ENDIF					
					.ENDIF
				.ELSEIF ([pcx].Interpolation == BP_INTERPOLATE_LOG)
					
				.ENDIF
			.ENDIF
		.ENDIF
		bpAnimInterpolateEnd:
		
		mov pcx, BPAnimPlrPtr
		fld animSpd		; Inc timer, for some reason deltaTime doesn't really work and is shit
		fadd [pcx].Timer	; Tested on other stuff, really takes a toll on animation only
		fstp [pcx].Timer
		
		pop pbx
		ASSUME pdx:nothing
	.ENDIF
	
	bpAnimExit:
	
	mov pax, resFrame
	ret
	
	bpAnimInterpolateLinear:
		mov pdx, pbx			; pbx is the current frame's value
		.IF (animSpd & FLT_NEG)	; Get previous frame value in pdx
			add pbx, intFrameSize	
		.ELSE
			sub pdx, intFrameSize
		.ENDIF
		; Calculate lerp factor based on Timer position between frames
		push pbx			; Get frame indexes (time values)
		push pcx
		push pdx
		sub pbx, timeOffset	; The offset from first 4 bytes = Frame.Time
		sub pdx, timeOffset
		mov pcx, BPAnimPlrPtr
		fld [pcx].Timer
		fisub DWORD PTR [pdx]
		fild DWORD PTR [pbx]
		fisub DWORD PTR [pdx]
		fdiv
		fstp floatVal
		pop pdx
		pop pcx
		pop pbx
			
		xor pax, pax
		.WHILE(pax < intStructSize)
			fld REAL4 PTR [pbx+pax]	; B value (current frame)
			fsub REAL4 PTR [pdx+pax]; A value
			
			fmul floatVal
			fadd REAL4 PTR [pdx+pax]
			fstp REAL4 PTR [pcx]
			
			add pcx, 4	; Output offset
			add pax, 4	; i++
		.ENDW
		pop pax	; pop label from stack
		jmp pax
	
	bpAnimInterpolateLinearS:
		mov pdx, pbx			; pbx is the current frame's value
		.IF (animSpd & FLT_NEG)	; Get previous (or next) frame value in pdx
			add pdx, intFrameSize	
		.ELSE
			sub pdx, intFrameSize
		.ENDIF
		push pbx			; Calculate time distance between two frames
		push pdx
		sub pbx, timeOffset	; The offset from first 4 bytes = Frame.Time
		sub pdx, timeOffset
		fild DWORD PTR [pbx]
		.IF (animSpd & FLT_NEG)
			fisubr DWORD PTR [pdx]
		.ELSE
			fisub DWORD PTR [pdx]
		.ENDIF
		pop pdx
		pop pbx
		fstp floatVal
		
		; Calculate lerp factor based on speed and distance between frames
		fld animSpd
		fabs
		fdiv floatVal
		fmul bpAnimInterpolateSpeed
		fstp fact
		IFNDEF BP_INTERPOLATION_UNCLAMPED
			push pax
			invoke flClamp, fact, 0, 1065353216	; fact, 0, 1.0
			mov fact, eax
			pop pax
		ENDIF
			
		xor pax, pax
		.WHILE(pax < intStructSize)
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
		
	ASSUME pcx:nothing
bpProcessAnimPlayer ENDP
ENDIF
ENDIF

ELSE
	ECHO BP3D: Duplicate include file BP3DImporters.inc
ENDIF
