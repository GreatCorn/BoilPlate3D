;
;   BP3DArrays.inc
;   Version 0.7ac1
;   BP3D array helper functions extension.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

; ----- INTERFACE -----
.DATA
IFDEF BP_ARRAY_USE_ORDER
;   Array structuring orders, from most to least significant axes. Generally, 
; most significant axes get iterated first, inside their iterations are then the
; lesser-significance axes. X may represent rows, Y columns and Z depth.
bp2DArrayOrder	DB "YX"		; Order of 2D arrays
bp3DArrayOrder	DB "ZYX"	; Order of 3D arrays
ENDIF

; ----- IMPLEMENTATION -----
.CODE

;   Calculate the offset (index * DataSize) in 1D array by position X and return
; it in pax.
;   X:BPPtr - position in 1D array.
;   DataSize - SIZEOF the data type in the array.
bp1DArrayGetOffset PROC EXPORT X:BPPtr, DataSize:BPPtr
	mov pax, X
	mov pcx, DataSize
	mul pcx
	ret
bp1DArrayGetOffset ENDP

;   Calculate the position in 1D array by offset (index * DataSize) and return
; it in pax.
;   ArrayOffset:BPPtr - the array data block offset to calculate position from.
;   DataSize - SIZEOF the data type in the array.
bp1DArrayGetPosition PROC EXPORT ArrayOffset:BPPtr, DataSize:BPPtr
	mov pax, ArrayOffset
	xor pdx, pdx
	mov pcx, DataSize
	div pcx
	ret
bp1DArrayGetPosition ENDP

;   Calculate the offset (index * DataSize) in 2D array by position [X, Y] and
; return it in pax.
;   X:BPPtr - X position in 2D array.
;   Y:BPPtr - Y position in 2D array.
;   ArrayWidth - the width (or height) of the array to calculate offset.
;   DataSize - SIZEOF the data type in the array.
bp2DArrayGetOffset PROC EXPORT X:BPPtr, Y:BPPtr, ArrayWidth:BPPtr, \
DataSize:BPPtr
	IFDEF BP_ARRAY_USE_ORDER
	.IF (bp2DArrayOrder[0] == 'Y')
	ENDIF
		mov pax, Y
		mov pcx, ArrayWidth
		mul pcx
		add pax, X
	IFDEF BP_ARRAY_USE_ORDER
	.ELSE
		mov pax, X
		mov pcx, ArrayWidth
		mul pcx
		add pax, Y
	.ENDIF
	ENDIF
	.IF (DataSize > 1)
		mov pcx, DataSize
		mul pcx
	.ENDIF
	ret
bp2DArrayGetOffset ENDP

;   Calculate the position [X, Y] in 2D array by offset (index * DataSize) and
; return it as [pdx, pax] or [pax, pdx] (bp2DArrayOrder == "XY").
;   ArrayOffset:BPPtr - the array data block offset to calculate position from.
;   ArrayWidth - the width of the array to calculate Y position.
;   DataSize - SIZEOF the data type in the array.
bp2DArrayGetPosition PROC EXPORT ArrayOffset:BPPtr, ArrayWidth:BPPtr, \
DataSize:BPPtr
	mov pax, ArrayOffset
	xor pdx, pdx
	.IF (DataSize > 1)
		mov pcx, DataSize
		div pcx
	.ENDIF
	mov pcx, ArrayWidth
	;xor pdx, pdx	; ArrayOffset should be a multiple of DataSize
	div pcx
	IFDEF BP_ARRAY_USE_ORDER
	.IF (bp2DArrayOrder[0] == 'X')
		xchg
	.ENDIF
	ENDIF
	ret
bp2DArrayGetPosition ENDP

;   Append data to end of an array and return new reallocated array pointer in 
; pax (mov pax to [ArrayPtr] after calling).
bpArrayAppend PROC EXPORT ArrayPtr:BPPtr, DataPtr:BPPtr, DataSize:BPPtr
	LOCAL retVal:BPPtr
	.IF (ArrayPtr)
		invoke HeapSize, bpDefHeap, 0, ArrayPtr
		push pax
		add pax, DataSize
		invoke bpReAlloc, bpDefHeap, 0, ArrayPtr, pax
		mov retVal, pax
		pop pax
		add pax, retVal
	.ELSE
		invoke bpMalloc, bpDefHeap, 0, DataSize
		mov retVal, pax
	.ENDIF
	invoke RtlMoveMemory, pax, DataPtr, DataSize
	mov pax, retVal
	
	ret
bpArrayAppend ENDP

;   Create 1D array of length ArrayLength, for elements of size DataSize and 
; return the pointer in pax.
;   DataSize:BPPtr - SIZEOF the data type in the array.
;   ArrayLength:BPPtr - length of the array to create.
bpCreate1DArray PROC EXPORT DataSize:BPPtr, ArrayLength:BPPtr
	mov pax, ArrayLength
	.IF (DataSize > 1)
		mov pcx, DataSize
		mul pcx
	.ENDIF
	push pax
	invoke bpMalloc, bpDefHeap, HEAP_ZERO_MEMORY, pax
	pop pcx
	ret
bpCreate1DArray ENDP

;   Create 2D array of dimensions ArrayWidth x ArrayHeight, for elements of size
; DataSize, return the pointer in pax and resulting size in pcx.
;   DataSize:BPPtr - SIZEOF the data type in the array.
;   ArrayWidth:BPPtr - width of the array to create.
;   ArrayHeight:BPPtr - height of the array to create.
bpCreate2DArray PROC EXPORT DataSize:BPPtr, ArrayWidth:BPPtr, ArrayHeight:BPPtr
	mov pax, ArrayWidth
	mov pcx, ArrayHeight
	mul pcx
	.IF (DataSize > 1)
		mov pcx, DataSize
		mul pcx
	.ENDIF
	push pax
	invoke bpMalloc, bpDefHeap, HEAP_ZERO_MEMORY, pax
	pop pcx
	ret
bpCreate2DArray ENDP
