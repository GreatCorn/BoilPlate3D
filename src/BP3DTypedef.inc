
IFNDEF BP3D_TYPEDEF_INC
BP3D_TYPEDEF_INC EQU <1>

IFDEF BP_64	; Cross-architecture compatibility (WIP)
	BPSPtr		TYPEDEF SQWORD	; Signed pointer type
	BPPtrShift	EQU 3			; Byte shift amount (to use instead of mul/div)
	
	; Pointer registers
	pax	EQU rax	
	pbx	EQU rbx
	pcx	EQU rcx
	pdx	EQU rdx
	pbp	EQU rbp
	psp	EQU rsp
ELSE
	BPSPtr		TYPEDEF SDWORD	; Signed pointer type
	BPPtrShift	EQU 2			; Byte shift amount (to use instead of mul/div)
	
	; Pointer registers
	pax	EQU eax
	pbx	EQU ebx
	pcx	EQU ecx
	pdx	EQU edx
	pbp	EQU ebp
	psp	EQU esp
ENDIF

;   Miscellaneous types for argument generalization
BPBool	TYPEDEF BYTE		; Boolean type
BPEnum	TYPEDEF BYTE		; Enumerator type
BPPtr	TYPEDEF PTR	; Pointer type

IFDEF BP_DOUBLE_PRECISION	; Floating-point type
	BPFloat	TYPEDEF REAL8
ELSE
	BPFloat	TYPEDEF REAL4
ENDIF

IFNDEF FALSE
	FALSE EQU 0
ENDIF
IFNDEF TRUE
	TRUE EQU 1
ENDIF

.CODE
IFNDEF RtlMoveMemory
	;   Simple stack-based overlappable RtlMoveMemory implementation, if not 
	;present. Assumes no alignment.
	RtlMoveMemory PROC EXPORT Dest:BPPtr, Src:BPPtr, SrcSize:BPPtr
		sub psp, SrcSize
		mov pdx, Src
		xor pcx, pcx
		.WHILE (pcx < SrcSize)
			mov al, BYTE PTR [pdx+pcx]
			mov BYTE PTR [psp+pcx], al
			inc pcx
		.ENDW
		mov pdx, Dest
		xor pcx, pcx
		.WHILE (pcx < SrcSize)
			mov al, BYTE PTR [psp+pcx]
			mov BYTE PTR [pdx+pcx], al
			inc pcx
		.ENDW
		add psp, SrcSize
		ret
	RtlMoveMemory ENDP
ENDIF

ELSE
	ECHO BP3D: Duplicate include file BP3DTypedef.inc
ENDIF