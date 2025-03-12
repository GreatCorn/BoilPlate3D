IFNDEF BP3DIMPORTERS_INC
BP3DIMPORTERS_INC equ <1>
; ----- INTERFACE -----

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

; ----- TYPES -----

BPMesh STRUCT
	Count		DWORD 0
	Vertices	BPPtr 0
	TexCoords	BPPtr 0
	Normals		BPPtr 0
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
	Position	BPPtr 0
	Rotation	BPPtr 0
	Scale 		BPPtr 0
	
	; Case FrameType of BPFRAME_MATRIX
	Matrix		BPPtr 0
	
	; Case FrameType of BPFRAME_VERTEX
	Mesh		BPPtr 0
	MeshFrameSize BPPtr 0
	;MeshInterpolate BPEnum BPMESH_INTERPOLATE_VERTEX ; the product of an insane man
	MeshUseNormals BPBool TRUE
BPAnimPlayer ENDS

.DATA
AnimationFPS	REAL4 30.0

; ----- IMPLEMENTATION -----
.CODE
bpLoadFile PROTO :BPPtr, :BPPtr

bpCheckFileInvalid MACRO
	.IF (pax == INVALID_HANDLE_VALUE)
		;print "File "
		;print FilePath
		;print " not found!", 13, 10
		xor pax, pax
		ret
	.ENDIF
ENDM

;   Load barebones animation track implementation - sequence of 28-byte frames: WRONGr 
; Time:DWORD, Position:Vector3, Rotation:Vector3.
LoadBPA MACRO BPAnimPTR:REQ, FilePath:REQ
	invoke bpLoadBPA, BPAnimPTR, expand_prefix(reparg(FilePath))
ENDM

;   Load a file storing interleaved sequences of UV (x, y), normal (x, y, z) and
; vertex (x, y, z) REAL4 values as a GL list. Rendered using glCallList.
;   GLListPTR - pointer to an uninitialized OpenGL list.
;   FilePath - quoted file path string.
LoadBPL MACRO GLListPTR:REQ, FilePath:REQ
	invoke bpLoadBPL, GLListPTR, expand_prefix(reparg(FilePath))
ENDM

;   Load a file storing sequences of vertex (x, y, z), UV (x, y), and normal
; (x, y, z) REAL4 values as a BPMesh struct. Rendered using bpDrawMesh 
; (subsequent glDrawArrays calls).
;   BPMeshPTR - pointer to a BPMesh structure.
;   FilePath - quoted file path string.
LoadBPM MACRO BPMeshPTR:REQ, FilePath:REQ
	invoke bpLoadBPM, BPMeshPTR, expand_prefix(reparg(FilePath))
ENDM

;   Load a Boil Plate texture - a raw image file with a BPT_HEADER-byte header
; which specifies its color format and dimensions.
;   TexturePTR - pointer to an uninitialized OpenGL texture.
;   FilePath - quoted file path string.
LoadBPT MACRO TexturePTR:REQ, FilePath:REQ
	invoke bpLoadBPT, TexturePTR, expand_prefix(reparg(FilePath))
ENDM

;   Load a file's entire contents and return the allocated buffer in pax. 
; Returns 0 if file is not found.
;   FilePath - quoted file path string.
LoadFile MACRO FilePath:REQ
	invoke bpLoadFile, expand_prefix(reparg(FilePath)), 0
ENDM

;   Unified vertex, texcoord and normal drawing procedure for BPMesh structure.
;   BPMeshPTR - pointer to a BPMesh structure.
bpDrawMesh PROC BPMeshPTR:BPPtr
	ASSUME pcx:PTR BPMesh
	
	mov pcx, BPMeshPTR
	invoke glVertexPointer, 3, GL_FLOAT, 0, [pcx].Vertices
	mov pcx, BPMeshPTR
	invoke glTexCoordPointer, 2, GL_FLOAT, 0, [pcx].TexCoords
	mov pcx, BPMeshPTR
	invoke glNormalPointer, GL_FLOAT, 0, [pcx].Normals
	mov pcx, BPMeshPTR
	invoke glDrawArrays, GL_TRIANGLES, 0, [pcx].Count
	mov pcx, BPMeshPTR
	
	ASSUME pcx:nothing
	ret
bpDrawMesh ENDP

bpFreeBPM PROC BPMeshPTR:BPPtr
	push pbx
	ASSUME pbx:PTR BPMesh
	mov pbx, BPMeshPTR
	
	invoke bpFree, rv(GetProcessHeap), 0, [pbx].Vertices
	invoke bpFree, rv(GetProcessHeap), 0, [pbx].TexCoords
	invoke bpFree, rv(GetProcessHeap), 0, [pbx].Normals
	ASSUME pbx:nothing
	pop pbx
	ret
bpFreeBPM ENDP

bpLoadBPA PROC BPAnimPTR:BPPtr, FilePath:BPPtr
	LOCAL hFile:HANDLE, dwHighSize:DWORD, dwFileSize:DWORD, dwArraySize:DWORD
	LOCAL dwBytesRead:DWORD
	ASSUME pcx:PTR BPAnimTrack
	
	invoke CreateFile, FilePath, GENERIC_READ, FILE_SHARE_READ, 0, \
	OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0
    mov hFile, pax
	
	bpCheckFileInvalid

    invoke GetFileSize, hFile, ADDR dwHighSize
    mov dwFileSize, eax
	invoke bpMalloc, rv(GetProcessHeap), 0, dwFileSize
	mov pcx, BPAnimPTR
	mov [pcx].Frames, pax
	m2m [pcx].ByteSize, dwFileSize

	invoke ReadFile, hFile, [pcx].Frames, dwFileSize, ADDR dwBytesRead, 0
	pusha
	print FilePath, 9
	print "ReadFile value:", 32
	popa
	pusha
	print str$(eax), 9
	popa
	.IF !(eax)
		print "ERROR:"
		invoke GetLastError
		print str$(eax), 9
	.ENDIF
	print "bytes read:", 32
	print str$(dwBytesRead), 9
	print "file size:", 32
	print str$(dwFileSize), 13, 10
	
    invoke CloseHandle, hFile
	
	ASSUME pcx:nothing
	ret
bpLoadBPA ENDP

bpLoadBPL PROC GLListPTR:BPPtr, FilePath:BPPtr
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
		invoke glTexCoord2f, eax, ecx
		add pbx, 8
		
		mov pax, buffer	; Get the normals
		mov edx, DWORD PTR [pax+pbx+8]
		mov ecx, DWORD PTR [pax+pbx+4]
		mov eax, DWORD PTR [pax+pbx]
		invoke glNormal3f, eax, ecx, edx
		add pbx, 12
		
		mov pax, buffer	; Get the vertices
		mov edx, DWORD PTR [pax+pbx+8]
		mov ecx, DWORD PTR [pax+pbx+4]
		mov eax, DWORD PTR [pax+pbx]
		invoke glVertex3f, eax, ecx, edx
		add pbx, 12
	.ENDW
	pop pbx
	
	invoke glEnd
	invoke glEndList
	
    invoke bpFree, rv(GetProcessHeap), 0, buffer
	
	mov pax, GLListPTR
	mov ecx, listIndex
	mov DWORD PTR [pax], ecx
	ret
bpLoadBPL ENDP

bpLoadBPM PROC BPMeshPTR:BPPtr, FilePath:BPPtr
	LOCAL hFile:HANDLE, dwHighSize:DWORD, dwFileSize:DWORD, dwArraySize:DWORD
	LOCAL v3Size:DWORD, v2Size:DWORD, dwBytesRead:DWORD
	ASSUME pcx:PTR BPMesh
	
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
	push eax
	
	mov ecx, 4
	div ecx
	mov pcx, BPMeshPTR
	mov [pcx].Count, eax
	
	pop eax
	mov ecx, 3				; Allocate the Vertices array
	mul ecx
	mov v3Size, eax
	invoke bpMalloc, rv(GetProcessHeap), 0, eax
	mov pcx, BPMeshPTR
	mov [pcx].Vertices, pax
	
	mov eax, dwArraySize	; Allocate the TexCoords array
	mov ecx, 2
	mul ecx
	mov v2Size, eax
	invoke bpMalloc, rv(GetProcessHeap), 0, eax
	mov pcx, BPMeshPTR
	mov [pcx].TexCoords, pax
	
	invoke bpMalloc, rv(GetProcessHeap), 0, v3Size	; Allocate the Normals array
	mov pcx, BPMeshPTR
	mov [pcx].Normals, pax
	
    invoke ReadFile, hFile, [pcx].Vertices, v3Size, ADDR dwBytesRead, 0
	mov pcx, BPMeshPTR
    invoke ReadFile, hFile, [pcx].TexCoords, v2Size, ADDR dwBytesRead, 0
	mov pcx, BPMeshPTR
    invoke ReadFile, hFile, [pcx].Normals, v3Size, ADDR dwBytesRead, 0
    invoke CloseHandle, hFile
	
	ASSUME pcx:nothing
	ret
bpLoadBPM ENDP

bpLoadBPT PROC TexturePTR:BPPtr, FilePath:BPPtr
	LOCAL buffer:BPPtr, texIndex:DWORD, texType:BYTE, texW:DWORD, texH:DWORD
	
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
	
	;print "Texture "
	;print FilePath
	;print " type: "
	;print sbyte$(texType),
	;print ", size: "
	;print str$(texW)
	;print "x"
	;print str$(texH), 13, 10
	
	add buffer, 4
	
	invoke glGenTextures, 1, ADDR texIndex
	invoke glBindTexture, GL_TEXTURE_2D, texIndex
	invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST
	invoke glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST
	
	; On some devices the OpenGL implementation behaves weirdly with mipmaps and
	; tries to build its own, even when it's not specified in code. This may
	; result in a lot of lag whenever there are many instances of a texture 
	; being used. On other devices, however, gluBuild#DMipmaps may not recognize
	; the extended texture color formats and will result in a GLU_INVALID_ENUM
	; error. Best-case approach is to parse formats to RGB(A)8, but I'm lazy.
	.IF (texType == BPT_RGB8)
		invoke gluBuild2DMipmaps, GL_TEXTURE_2D, 3, texW, texH, GL_RGB, \
		GL_UNSIGNED_BYTE, buffer
		.IF (eax)	; Shouldn't really happen as it's within support
			invoke glTexImage2D, GL_TEXTURE_2D, 0, GL_RGB, texW, texH, 0, \
			GL_RGB, GL_UNSIGNED_BYTE, buffer
		.ENDIF
	.ELSEIF (texType == BPT_RGBA8)
		invoke gluBuild2DMipmaps, GL_TEXTURE_2D, 4, texW, texH, GL_RGBA, \
		GL_UNSIGNED_BYTE, buffer
		.IF (eax)	; Shouldn't really happen either
			invoke glTexImage2D, GL_TEXTURE_2D, 0, GL_RGBA, texW, texH, 0, \
			GL_RGBA, GL_UNSIGNED_BYTE, buffer
		.ENDIF
	.ELSEIF (texType == BPT_RGB565)
		invoke gluBuild2DMipmaps, GL_TEXTURE_2D, 3, texW, texH, GL_RGB, \
		8363h, buffer	; GL_UNSIGNED_SHORT_5_6_5
		.IF (eax)
			invoke glTexImage2D, GL_TEXTURE_2D, 0, GL_RGB, texW, texH, 0, \
			GL_RGB, 8363h, buffer	; GL_UNSIGNED_SHORT_5_6_5
		.ENDIF
	.ELSEIF (texType == BPT_RGB5A1)
		invoke gluBuild2DMipmaps, GL_TEXTURE_2D, 4, texW, texH, GL_RGBA, 8034h,\
		buffer	; GL_UNSIGNED_SHORT_5_5_5_1
		.IF (eax)
			invoke glTexImage2D, GL_TEXTURE_2D, 0, GL_RGBA, texW, texH, 0, \
			GL_RGBA, 8034h, buffer	; GL_UNSIGNED_SHORT_5_5_5_1
		.ENDIF
	.ELSEIF (texType == BPT_RGBA4)
		invoke gluBuild2DMipmaps, GL_TEXTURE_2D, 4, texW, texH, GL_RGBA, 8033h,\
		buffer	; GL_UNSIGNED_SHORT_4_4_4_4
		.IF (eax)
			invoke glTexImage2D, GL_TEXTURE_2D, 0, GL_RGBA, texW, texH, 0, \
			GL_RGBA, 8033h, buffer	; GL_UNSIGNED_SHORT_4_4_4_4
		.ENDIF
	.ELSEIF (texType == BPT_RGB332)
		invoke gluBuild2DMipmaps, GL_TEXTURE_2D, 3, texW, texH, GL_RGB, \
		8032h, buffer	; GL_UNSIGNED_BYTE_3_3_2
		.IF (eax)
			invoke glTexImage2D, GL_TEXTURE_2D, 0, GL_RGB, texW, texH, 0, \
			GL_RGB, 8032h, buffer	; GL_UNSIGNED_BYTE_3_3_2
		.ENDIF
	.ELSEIF (texType == BPT_L8)
		invoke gluBuild2DMipmaps, GL_TEXTURE_2D, 1, texW, texH, GL_LUMINANCE, \
		GL_UNSIGNED_BYTE, buffer
		.IF (eax) ; Shouldn't really happen too
			invoke glTexImage2D, GL_TEXTURE_2D, 0, GL_LUMINANCE, texW, texH, 0,\
			GL_LUMINANCE, GL_UNSIGNED_BYTE, buffer
		.ENDIF
	.ENDIF
	
	sub buffer, 9
    invoke bpFree, rv(GetProcessHeap), 0, buffer
	
	mov pax, TexturePTR
	mov ecx, texIndex
	mov DWORD PTR [pax], ecx
	ret
bpLoadBPT ENDP

bpLoadFile PROC FilePath:BPPtr, FileSizePtr:BPPtr
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
	invoke bpMalloc, rv(GetProcessHeap), 0, dwFileSize
	mov buffer, pax

    invoke ReadFile, hFile, buffer, dwFileSize, ADDR dwBytesRead, 0
    invoke CloseHandle, hFile
	
	mov pax, buffer
	ret
bpLoadFile ENDP

IFDEF BP3DMATHS_INC AND BP3DVECTORS_INC
bpProcessAnimPlayer PROC BPAnimPlrPTR:BPPtr
	LOCAL floatVal:REAL4, animSpd:REAL4, fact:REAL4
	LOCAL frameAddr:BPPtr
	LOCAL timeOffset:BPPtr, intFrameSize:BPPtr, intStructSize:BPPtr
	LOCAL resFrame:BPBool
	
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
			mov [pcx].MeshFrameSize, eax	; BAD CODE BAD CODE BUT I FORGOT HOW TO MOVE EXTEND
		.ENDIF
	
		ASSUME pdx:PTR BPAnimTrack
		
		fld [pcx].Speed
		fmul AnimationFPS
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
			.IF ([pcx].FrameOffset >= eax)
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
			pop pbx
			add pbx, 4
			
			.IF ([pcx].Matrix)
				.IF ([pcx].Interpolation == BPINTERPOLATION_CONSTANT)
					mov pcx, [pcx].Matrix
					xor pax, pax
					.WHILE (pax < SIZEOF REAL4 * 16)
						m2m REAL4 PTR [pcx+pax], REAL4 PTR [pbx+pax]
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
			pop pbx
			add pbx, 4
			
			.IF ([pcx].Mesh)
				m2m intStructSize, [pcx].MeshFrameSize	; The mesh itself
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
					m2m intFrameSize, [pcx].MeshFrameSize	; Time + mesh
					
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
	
	mov al, resFrame
	ret
	
	bpAnimInterpolateLinear:
		mov pdx, pbx	; pbx is the current frame's value
		sub pdx, intFrameSize	; Get previous frame value in pdx
		
		push pbx	; Calculate time distance between two frames
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
			IFDEF BP3D_CLAMP_INTERPOLATION
				push pax
				invoke flClamp, fact, 0, fl1
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

ELSE
	ECHO BP3D: Duplicate include file BP3DImporters.inc
ENDIF
