;   Create 1D array of length ArrayLength, for elements of size DataSize.
;   DataSize:BPPtr - SIZEOF the data type in the array.
;   ArrayLength:BPPtr - length of the array to create.
bpCreate1DArray PROC DataSize:BPPtr, ArrayLength:BPPtr
	call GetProcessHeap
	push pax
	mov pax, ArrayLength
	mov pcx, DataSize
	mul pcx
	pop pcx
	invoke bpMalloc, pcx, HEAP_ZERO_MEMORY, pax
	ret
bpCreate1DArray ENDP

;   Create 2D array of dimensions ArrayWidth x ArrayHeight, for elements of size
; DataSize.
;   DataSize:BPPtr - SIZEOF the data type in the array.
;   ArrayWidth:BPPtr - width of the array to create.
;   ArrayHeight:BPPtr - height of the array to create.
bpCreate2DArray PROC DataSize:BPPtr, ArrayWidth:BPPtr, ArrayHeight:BPPtr
	call GetProcessHeap
	push pax
	mov pax, ArrayWidth
	mov pcx, ArrayHeight
	mul pcx
	mov pcx, DataSize
	mul pcx
	pop pcx
	invoke bpMalloc, pcx, HEAP_ZERO_MEMORY, pax
	ret
bpCreate2DArray ENDP

;   Calculate the offset (index * DataSize) in 1D array by position X and return
; it in pax.
;   X:BPPtr - position in 1D array.
;   DataSize - SIZEOF the data type in the array.
bp1DArrayGetOffset PROC X:BPPtr, DataSize:BPPtr
	mov pax, X
	mov pcx, DataSize
	mul pcx
	ret
bp1DArrayGetOffset ENDP

;   Calculate the offset (index * DataSize) in 2D array by position [X, Y] and
; return it in pax.
;   X:BPPtr - X position in 2D array.
;   Y:BPPtr - Y position in 2D array.
;   ArrayWidth - the width of the array to calculate offset with Y.
;   DataSize - SIZEOF the data type in the array.
bp2DArrayGetOffset PROC X:BPPtr, Y:BPPtr, ArrayWidth:BPPtr, DataSize:BPPtr
	mov pax, Y
	mov pcx, ArrayWidth
	mul pcx
	add pax, X
	mov pcx, DataSize
	mul pcx
	ret
bp2DArrayGetOffset ENDP

;   Calculate the position [X, Y] in 2D array by offset (index * DataSize) and
; return it as [pdx, pax].
;   ArrayOffset:BPPtr - the array data block offset to calculate position from.
;   ArrayWidth - the width of the array to calculate Y position.
;   DataSize - SIZEOF the data type in the array.
bp2DArrayGetPosition PROC ArrayOffset:BPPtr, ArrayWidth:BPPtr, DataSize:BPPtr
	mov pax, ArrayOffset
	mov pcx, DataSize
	xor pdx, pdx
	div pcx
	mov pcx, ArrayWidth
	;xor pdx, pdx	; ArrayOffset should be a multiple of DataSize
	div pcx
	ret
bp2DArrayGetPosition ENDP
